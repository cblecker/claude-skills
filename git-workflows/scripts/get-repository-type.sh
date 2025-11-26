#!/bin/bash
# Detect fork vs origin repository and extract owner/repo metadata
# Usage: ./get-repository-type.sh

set -euo pipefail

# Function to parse GitHub URL and extract owner/repo
parse_github_url() {
  local url="$1"
  local owner=""
  local repo=""

  # Remove .git suffix if present
  url="${url%.git}"

  # Handle different URL formats:
  # - https://github.com/owner/repo
  # - git@github.com:owner/repo
  # - git://github.com/owner/repo
  # - ssh://git@github.com/owner/repo

  if [[ "$url" =~ github\.com[:/]([^/]+)/([^/]+)$ ]]; then
    owner="${BASH_REMATCH[1]}"
    repo="${BASH_REMATCH[2]}"
  else
    return 1
  fi

  echo "$owner"
  echo "$repo"
}

# Function to build remote object
build_remote_json() {
  local url="$1"

  # Parse URL to get owner and repo
  local parse_result
  if ! parse_result=$(parse_github_url "$url"); then
    return 1
  fi

  # Read owner and repo from parse result
  local owner
  local repo
  owner=$(echo "$parse_result" | sed -n '1p')
  repo=$(echo "$parse_result" | sed -n '2p')

  if [ -z "$owner" ] || [ -z "$repo" ]; then
    return 1
  fi

  # Build JSON object
  if command -v jq &> /dev/null; then
    jq -n \
      --arg url "$url" \
      --arg owner "$owner" \
      --arg repo "$repo" \
      '{
        url: $url,
        owner: $owner,
        repo: $repo
      }'
  else
    cat <<EOF
{
  "url": "$url",
  "owner": "$owner",
  "repo": "$repo"
}
EOF
  fi
}

# Main execution
main() {
  # Check if we're in a git repository
  if ! git rev-parse --git-dir &>/dev/null; then
    if command -v jq &> /dev/null; then
      jq -n \
        --arg error_type "not_git_repo" \
        --arg message "Not in a git repository" \
        --arg suggested_action "Run this command from within a git repository" \
        '{
          success: false,
          error_type: $error_type,
          message: $message,
          suggested_action: $suggested_action
        }'
    else
      cat <<'EOF'
{
  "success": false,
  "error_type": "not_git_repo",
  "message": "Not in a git repository",
  "suggested_action": "Run this command from within a git repository"
}
EOF
    fi
    exit 1
  fi

  # Get origin remote URL
  local origin_url
  if ! origin_url=$(git remote get-url origin 2>/dev/null); then
    if command -v jq &> /dev/null; then
      jq -n \
        --arg error_type "no_remote" \
        --arg message "No origin remote found" \
        --arg suggested_action "Ensure you're in a git repository with a remote configured" \
        '{
          success: false,
          error_type: $error_type,
          message: $message,
          suggested_action: $suggested_action
        }'
    else
      cat <<'EOF'
{
  "success": false,
  "error_type": "no_remote",
  "message": "No origin remote found",
  "suggested_action": "Ensure you're in a git repository with a remote configured"
}
EOF
    fi
    exit 1
  fi

  # Build origin object
  local origin_json
  if ! origin_json=$(build_remote_json "$origin_url"); then
    if command -v jq &> /dev/null; then
      jq -n \
        --arg error_type "invalid_url" \
        --arg message "Could not parse origin remote URL: $origin_url" \
        --arg suggested_action "Ensure origin points to a GitHub repository" \
        '{
          success: false,
          error_type: $error_type,
          message: $message,
          suggested_action: $suggested_action
        }'
    else
      cat <<EOF
{
  "success": false,
  "error_type": "invalid_url",
  "message": "Could not parse origin remote URL: $origin_url",
  "suggested_action": "Ensure origin points to a GitHub repository"
}
EOF
    fi
    exit 1
  fi

  # Check for upstream remote
  local upstream_url
  local is_fork=false
  local upstream_json="null"

  if upstream_url=$(git remote get-url upstream 2>/dev/null); then
    is_fork=true
    if ! upstream_json=$(build_remote_json "$upstream_url"); then
      # If upstream URL is invalid, treat as warning but continue
      upstream_json="null"
      is_fork=false
    fi
  fi

  # Build final JSON output
  if command -v jq &> /dev/null; then
    jq -n \
      --argjson is_fork "$is_fork" \
      --argjson origin "$origin_json" \
      --argjson upstream "$upstream_json" \
      '{
        success: true,
        is_fork: $is_fork,
        upstream: $upstream,
        origin: $origin
      }'
  else
    if [ "$is_fork" = "true" ]; then
      cat <<EOF
{
  "success": true,
  "is_fork": true,
  "upstream": $upstream_json,
  "origin": $origin_json
}
EOF
    else
      cat <<EOF
{
  "success": true,
  "is_fork": false,
  "upstream": null,
  "origin": $origin_json
}
EOF
    fi
  fi
}

# Run main function
main
