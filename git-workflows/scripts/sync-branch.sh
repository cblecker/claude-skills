#!/usr/bin/env bash
# Execute fork-aware branch synchronization
# Usage: ./sync-branch.sh [branch_name]
#
# Exit codes:
#   0 - Success, or expected conditions (uncommitted_changes)
#   1 - Actual errors (missing_dependency, not_git_repo, branch_not_found, repo_type_detection_failed, sync_conflict, sync_failed, branch_diverged)

set -euo pipefail

# Check for required dependencies
if ! command -v jq &> /dev/null; then
  echo '{"success": false, "error_type": "missing_dependency", "message": "jq is required but not installed"}' >&2
  exit 1
fi

# Get the script directory, resolving symlinks
_source="${BASH_SOURCE[0]}"
while [ -L "$_source" ]; do
  _dir="$(cd -P "$(dirname "$_source")" && pwd)"
  _source="$(readlink "$_source")"
  [[ $_source != /* ]] && _source="$_dir/$_source"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_source")" && pwd)"
unset _source _dir

# Function to get current branch
get_current_branch() {
  git branch --show-current 2>/dev/null || echo "HEAD"
}

# Function to check if branch has uncommitted changes
check_uncommitted_changes() {
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    return 0  # Has uncommitted changes
  else
    return 1  # Clean
  fi
}

# Function to sync origin-only repository
sync_origin() {
  local branch="$1"

  # Fetch from origin
  if ! git fetch --prune origin >/dev/null 2>&1; then
    return 1
  fi

  # Check if branch tracks a remote
  local upstream_branch
  upstream_branch=$(git rev-parse --abbrev-ref --symbolic-full-name "$branch@{u}" 2>/dev/null || echo "")

  if [ -z "$upstream_branch" ]; then
    # No upstream tracking, just fetch
    echo '{"operations": ["fetched_origin"], "commits_pulled": 0, "status": "no_upstream"}'
    return 0
  fi

  # Try fast-forward merge
  local before_hash
  before_hash=$(git rev-parse HEAD)

  if git merge --ff-only "$upstream_branch" >/dev/null 2>&1; then
    local after_hash
    after_hash=$(git rev-parse HEAD)

    # Count commits pulled
    local commits_pulled=0
    if [ "$before_hash" != "$after_hash" ]; then
      commits_pulled=$(git rev-list --count "$before_hash..$after_hash")
    fi

    echo "{\"operations\": [\"fetched_origin\", \"merged_fast_forward\"], \"commits_pulled\": $commits_pulled, \"status\": \"up_to_date\"}"
    return 0
  else
    # Fast-forward failed, might need rebase or has diverged
    echo '{"operations": ["fetched_origin"], "commits_pulled": 0, "status": "diverged"}'
    return 1
  fi
}

# Function to sync forked repository
sync_fork() {
  local branch="$1"

  # Fetch from all remotes
  if ! git fetch --prune --all >/dev/null 2>&1; then
    return 1
  fi

  # Check if upstream has the branch
  if ! git rev-parse --verify "upstream/$branch" &>/dev/null; then
    # Upstream doesn't have this branch, just sync with origin
    echo '{"operations": ["fetched_all"], "commits_pulled": 0, "status": "upstream_missing_branch"}'
    return 0
  fi

  # Get current commit
  local before_hash
  before_hash=$(git rev-parse HEAD)

  # Rebase on upstream
  if git pull --stat --rebase upstream "$branch" >/dev/null 2>&1; then
    local after_hash
    after_hash=$(git rev-parse HEAD)

    # Count commits pulled
    local commits_pulled=0
    if [ "$before_hash" != "$after_hash" ]; then
      commits_pulled=$(git rev-list --count "$before_hash..$after_hash")
    fi

    # Push to origin
    local push_result="success"
    if ! git push origin "$branch" >/dev/null 2>&1; then
      push_result="failed"
    fi

    if [ "$push_result" = "success" ]; then
      echo "{\"operations\": [\"fetched_all\", \"rebased_on_upstream\", \"pushed_to_origin\"], \"commits_pulled\": $commits_pulled, \"status\": \"up_to_date\"}"
    else
      echo "{\"operations\": [\"fetched_all\", \"rebased_on_upstream\"], \"commits_pulled\": $commits_pulled, \"status\": \"push_failed\"}"
    fi
    return 0
  else
    # Rebase failed - likely conflicts
    # Abort the rebase
    git rebase --abort 2>/dev/null || true

    echo '{"operations": ["fetched_all"], "commits_pulled": 0, "status": "sync_conflict"}'
    return 1
  fi
}

# Main execution
main() {
  local branch="${1:-}"

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

  # Get current branch if not specified
  if [ -z "$branch" ]; then
    branch=$(get_current_branch)
  fi

  # Validate branch exists
  if ! git rev-parse --verify "$branch" &>/dev/null; then
    jq -n \
      --arg error_type "branch_not_found" \
      --arg message "Branch not found: $branch" \
      --arg suggested_action "Ensure the branch exists before syncing" \
      --arg branch "$branch" \
      '{
        success: false,
        error_type: $error_type,
        message: $message,
        suggested_action: $suggested_action,
        branch: $branch
      }'
    exit 1
  fi

  # Check for uncommitted changes (expected condition - not an error)
  if check_uncommitted_changes; then
    # Get list of uncommitted files (use cut -c4- to preserve spaces in filenames)
    local uncommitted_files
    uncommitted_files=$(git status --porcelain | cut -c4- | jq -R '.' | jq -s '.')

    jq -n \
      --arg error_type "uncommitted_changes" \
      --arg message "Cannot sync with uncommitted changes" \
      --arg suggested_action "Commit or stash your changes before syncing" \
      --argjson uncommitted_files "$uncommitted_files" \
      '{
        success: false,
        error_type: $error_type,
        message: $message,
        suggested_action: $suggested_action,
        uncommitted_files: $uncommitted_files
      }'
    exit 0
  fi

  # Get repository type
  local repo_info
  if ! repo_info=$("$SCRIPT_DIR/get-repository-type.sh" 2>/dev/null); then
    jq -n \
      --arg error_type "repo_type_detection_failed" \
      --arg message "Could not detect repository type" \
      --arg suggested_action "Ensure git remotes are configured correctly" \
      '{
        success: false,
        error_type: $error_type,
        message: $message,
        suggested_action: $suggested_action
      }'
    exit 1
  fi

  local is_fork
  is_fork=$(echo "$repo_info" | jq -r '.is_fork')

  # Perform sync based on repository type
  local sync_result
  if [ "$is_fork" = "true" ]; then
    if ! sync_result=$(sync_fork "$branch"); then
      # Extract error information from sync result
      local status
      status=$(echo "$sync_result" | jq -r '.status')

      if [ "$status" = "sync_conflict" ]; then
        jq -n \
          --arg error_type "sync_conflict" \
          --arg message "Merge conflict during sync" \
          --arg suggested_action "Resolve conflicts manually and retry sync" \
          --arg branch "$branch" \
          '{
            success: false,
            error_type: $error_type,
            message: $message,
            suggested_action: $suggested_action,
            branch: $branch
          }'
        exit 1
      else
        jq -n \
          --arg error_type "sync_failed" \
          --arg message "Sync operation failed" \
          --arg suggested_action "Check git status and try again" \
          --arg branch "$branch" \
          '{
            success: false,
            error_type: $error_type,
            message: $message,
            suggested_action: $suggested_action,
            branch: $branch
          }'
        exit 1
      fi
    fi
  else
    if ! sync_result=$(sync_origin "$branch"); then
      local status
      status=$(echo "$sync_result" | jq -r '.status')

      if [ "$status" = "diverged" ]; then
        jq -n \
          --arg error_type "branch_diverged" \
          --arg message "Local branch has diverged from remote" \
          --arg suggested_action "Use rebase or merge to reconcile changes" \
          --arg branch "$branch" \
          '{
            success: false,
            error_type: $error_type,
            message: $message,
            suggested_action: $suggested_action,
            branch: $branch
          }'
        exit 1
      else
        jq -n \
          --arg error_type "sync_failed" \
          --arg message "Sync operation failed" \
          --arg suggested_action "Check git status and try again" \
          --arg branch "$branch" \
          '{
            success: false,
            error_type: $error_type,
            message: $message,
            suggested_action: $suggested_action,
            branch: $branch
          }'
        exit 1
      fi
    fi
  fi

  # Parse sync result
  local operations
  local commits_pulled
  local status
  operations=$(echo "$sync_result" | jq -c '.operations')
  commits_pulled=$(echo "$sync_result" | jq -r '.commits_pulled')
  status=$(echo "$sync_result" | jq -r '.status')

  # Build final JSON output
  jq -n \
    --arg branch "$branch" \
    --argjson is_fork "$is_fork" \
    --argjson operations "$operations" \
    --argjson commits_pulled "$commits_pulled" \
    --arg status "$status" \
    '{
      success: true,
      branch: $branch,
      is_fork: $is_fork,
      operations_performed: $operations,
      commits_pulled: $commits_pulled,
      status: $status
    }'
}

# Run main function
main "$@"
