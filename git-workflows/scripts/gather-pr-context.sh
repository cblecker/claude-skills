#!/bin/bash
# Gather all context needed for PR title/description generation
# Usage: ./gather-pr-context.sh <base_branch>

set -euo pipefail

# Get the script directory for calling other scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to get current branch
get_current_branch() {
  git branch --show-current 2>/dev/null || echo "HEAD"
}

# Function to check for uncommitted changes
check_uncommitted_changes() {
  git status --porcelain 2>/dev/null
}

# Function to get commit history between branches
get_commit_history() {
  local base_branch="$1"
  local commits_json='[]'

  # Get commits between base and HEAD
  local commits
  if commits=$(git log --pretty=format:'{"hash": "%H", "subject": "%s", "body": "%b"}' "$base_branch..HEAD" 2>/dev/null); then
    if [ -n "$commits" ]; then
      # Wrap in array and parse
      commits_json=$(echo "$commits" | jq -s '.')
    fi
  fi

  echo "$commits_json"
}

# Function to get diff summary between branches
get_diff_summary() {
  local base_branch="$1"
  local diff_output

  diff_output=$(git diff --shortstat "$base_branch...HEAD" 2>/dev/null || echo "")

  if [ -z "$diff_output" ]; then
    echo '{"files_changed": 0, "insertions": 0, "deletions": 0}'
    return
  fi

  # Parse the output: " 5 files changed, 150 insertions(+), 25 deletions(-)"
  local files_changed=0
  local insertions=0
  local deletions=0

  if [[ "$diff_output" =~ ([0-9]+)\ file ]]; then
    files_changed="${BASH_REMATCH[1]}"
  fi
  if [[ "$diff_output" =~ ([0-9]+)\ insertion ]]; then
    insertions="${BASH_REMATCH[1]}"
  fi
  if [[ "$diff_output" =~ ([0-9]+)\ deletion ]]; then
    deletions="${BASH_REMATCH[1]}"
  fi

  jq -n \
    --argjson files "$files_changed" \
    --argjson insertions "$insertions" \
    --argjson deletions "$deletions" \
    '{files_changed: $files, insertions: $insertions, deletions: $deletions}'
}

# Main execution
main() {
  local base_branch="${1:-}"

  # Check if we're in a git repository
  if ! git rev-parse --git-dir &>/dev/null; then
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
    exit 1
  fi

  # Get current branch
  local current_branch
  current_branch=$(get_current_branch)

  # If no base branch specified, try to detect mainline
  if [ -z "$base_branch" ]; then
    local mainline_info
    if mainline_info=$("$SCRIPT_DIR/get-mainline-branch.sh" 2>/dev/null); then
      base_branch=$(echo "$mainline_info" | jq -r '.mainline_branch')
    else
      # Default to main if detection fails
      base_branch="main"
    fi
  fi

  # Check if current branch is the base branch (error condition)
  if [ "$current_branch" = "$base_branch" ]; then
    jq -n \
      --arg error_type "on_base_branch" \
      --arg message "Cannot create PR from base branch: $base_branch" \
      --arg suggested_action "Create a feature branch first" \
      --arg base_branch "$base_branch" \
      '{
        success: false,
        error_type: $error_type,
        message: $message,
        suggested_action: $suggested_action,
        current_branch: $base_branch
      }'
    exit 1
  fi

  # Check for uncommitted changes
  local uncommitted_changes
  uncommitted_changes=$(check_uncommitted_changes)

  local has_uncommitted_changes=false
  local uncommitted_files=[]

  if [ -n "$uncommitted_changes" ]; then
    has_uncommitted_changes=true
    # Extract file paths (use cut -c4- to preserve spaces in filenames)
    uncommitted_files=$(echo "$uncommitted_changes" | cut -c4- | jq -R '.' | jq -s '.')
  fi

  # Get repository type (fork vs origin)
  local repo_info
  if ! repo_info=$("$SCRIPT_DIR/get-repository-type.sh" 2>/dev/null); then
    # If detection fails, continue with defaults
    repo_info=$(jq -n '{
      success: true,
      is_fork: false,
      upstream: null,
      origin: {
        url: "",
        owner: "",
        repo: ""
      }
    }')
  fi

  local is_fork
  local repository
  is_fork=$(echo "$repo_info" | jq -r '.is_fork')

  if [ "$is_fork" = "true" ]; then
    local upstream_owner
    local upstream_repo
    local origin_owner
    local origin_repo
    upstream_owner=$(echo "$repo_info" | jq -r '.upstream.owner')
    upstream_repo=$(echo "$repo_info" | jq -r '.upstream.repo')
    origin_owner=$(echo "$repo_info" | jq -r '.origin.owner')
    origin_repo=$(echo "$repo_info" | jq -r '.origin.repo')

    repository=$(jq -n \
      --arg upstream_owner "$upstream_owner" \
      --arg upstream_repo "$upstream_repo" \
      --arg origin_owner "$origin_owner" \
      --arg origin_repo "$origin_repo" \
      '{
        upstream_owner: $upstream_owner,
        upstream_repo: $upstream_repo,
        origin_owner: $origin_owner,
        origin_repo: $origin_repo
      }')
  else
    local origin_owner
    local origin_repo
    origin_owner=$(echo "$repo_info" | jq -r '.origin.owner')
    origin_repo=$(echo "$repo_info" | jq -r '.origin.repo')

    repository=$(jq -n \
      --arg origin_owner "$origin_owner" \
      --arg origin_repo "$origin_repo" \
      '{
        origin_owner: $origin_owner,
        origin_repo: $origin_repo
      }')
  fi

  # Validate branch is a feature branch (not HEAD/detached)
  local is_feature_branch=true
  if [ "$current_branch" = "HEAD" ]; then
    is_feature_branch=false
  fi

  # Get commit history
  local commit_history
  if ! commit_history=$(get_commit_history "$base_branch"); then
    commit_history='[]'
  fi

  # Check if there are any commits (error condition)
  local commit_count
  commit_count=$(echo "$commit_history" | jq 'length')

  if [ "$commit_count" -eq 0 ]; then
    jq -n \
      --arg error_type "no_commits" \
      --arg message "No commits found between $base_branch and $current_branch" \
      --arg suggested_action "Make commits on your feature branch before creating a PR" \
      --arg base_branch "$base_branch" \
      --arg current_branch "$current_branch" \
      '{
        success: false,
        error_type: $error_type,
        message: $message,
        suggested_action: $suggested_action,
        base_branch: $base_branch,
        current_branch: $current_branch
      }'
    exit 1
  fi

  # Get diff summary
  local diff_summary
  if ! diff_summary=$(get_diff_summary "$base_branch"); then
    diff_summary='{"files_changed": 0, "insertions": 0, "deletions": 0}'
  fi

  # Detect conventions
  local conventions_info
  if ! conventions_info=$("$SCRIPT_DIR/detect-conventions.sh" 2>/dev/null); then
    conventions_info=$(jq -n '{
      success: true,
      uses_conventional_commits: false
    }')
  fi

  local uses_conventional_commits
  uses_conventional_commits=$(echo "$conventions_info" | jq -r '.uses_conventional_commits')

  # Build comprehensive JSON output
  jq -n \
    --arg current_branch "$current_branch" \
    --arg base_branch "$base_branch" \
    --argjson is_fork "$is_fork" \
    --argjson repository "$repository" \
    --argjson is_feature_branch "$is_feature_branch" \
    --argjson has_uncommitted "$has_uncommitted_changes" \
    --argjson uncommitted_files "$uncommitted_files" \
    --argjson commit_history "$commit_history" \
    --argjson diff_summary "$diff_summary" \
    --argjson uses_conventional "$uses_conventional_commits" \
    '{
      success: true,
      current_branch: $current_branch,
      base_branch: $base_branch,
      is_fork: $is_fork,
      repository: $repository,
      branch_validation: {
        is_feature_branch: $is_feature_branch,
        has_uncommitted_changes: $has_uncommitted
      },
      uncommitted_files: $uncommitted_files,
      commit_history: $commit_history,
      diff_summary: $diff_summary,
      uses_conventional_commits: $uses_conventional
    }'
}

# Run main function
main "$@"
