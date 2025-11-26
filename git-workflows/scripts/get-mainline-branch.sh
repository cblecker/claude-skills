#!/bin/bash
# Detect mainline branch and optionally compare against a specified branch
# Usage: ./get-mainline-branch.sh [branch_name]

set -euo pipefail

# Function to detect mainline branch
detect_mainline() {
  # Try to get the default branch from remote HEAD
  local mainline
  mainline=$(git ls-remote --exit-code --symref origin HEAD 2>/dev/null | \
    awk '/^ref:/ {sub("refs/heads/", "", $2); print $2}')

  if [ -z "$mainline" ]; then
    return 1
  fi

  echo "$mainline"
}

# Main execution
main() {
  local comparison_branch="${1:-}"

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

  # Detect mainline branch
  local mainline_branch
  if ! mainline_branch=$(detect_mainline); then
    if command -v jq &> /dev/null; then
      jq -n \
        --arg error_type "remote_head_not_found" \
        --arg message "Could not detect remote HEAD" \
        --arg suggested_action "Ensure origin remote is configured and accessible" \
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
  "error_type": "remote_head_not_found",
  "message": "Could not detect remote HEAD",
  "suggested_action": "Ensure origin remote is configured and accessible"
}
EOF
    fi
    exit 1
  fi

  # If no comparison branch specified, use current branch
  if [ -z "$comparison_branch" ]; then
    comparison_branch=$(git branch --show-current)
    if [ -z "$comparison_branch" ]; then
      # Detached HEAD state
      comparison_branch="HEAD"
    fi
  fi

  # Compare branches
  local is_mainline=false
  if [ "$comparison_branch" = "$mainline_branch" ]; then
    is_mainline=true
  fi

  # Build JSON output
  if command -v jq &> /dev/null; then
    jq -n \
      --arg mainline "$mainline_branch" \
      --arg comparison "$comparison_branch" \
      --argjson is_mainline "$is_mainline" \
      '{
        success: true,
        mainline_branch: $mainline,
        comparison_branch: $comparison,
        is_mainline: $is_mainline
      }'
  else
    cat <<EOF
{
  "success": true,
  "mainline_branch": "$mainline_branch",
  "comparison_branch": "$comparison_branch",
  "is_mainline": $is_mainline
}
EOF
  fi
}

# Run main function
main "$@"
