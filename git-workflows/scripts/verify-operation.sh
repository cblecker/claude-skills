#!/bin/bash
# Verify operation success and generate standardized reports
# Usage: ./verify-operation.sh <operation_type> [additional_args...]

set -euo pipefail

# Operation type
OPERATION_TYPE="${1:-}"

if [ -z "$OPERATION_TYPE" ]; then
  jq -n \
    --arg error_type "invalid_usage" \
    --arg message "Operation type required" \
    --arg suggested_action "Usage: verify-operation.sh <commit|branch|sync|rebase|pr> [args...]" \
    '{
      success: false,
      error_type: $error_type,
      message: $message,
      suggested_action: $suggested_action
    }'
  exit 1
fi

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

# Function to verify commit operation
verify_commit() {
  # Get the last commit
  local commit_info
  if ! commit_info=$(git log -1 --format='{"hash": "%H", "subject": "%s", "author": "%an", "date": "%ai"}' 2>/dev/null); then
    jq -n \
      --arg error_type "no_commits" \
      --arg message "No commits found" \
      '{
        success: false,
        error_type: $error_type,
        message: $message
      }'
    return 1
  fi

  # Parse commit info
  local commit_hash
  local subject
  local author
  local date
  commit_hash=$(echo "$commit_info" | jq -r '.hash')
  subject=$(echo "$commit_info" | jq -r '.subject')
  author=$(echo "$commit_info" | jq -r '.author')
  date=$(echo "$commit_info" | jq -r '.date')

  # Get current branch
  local branch
  branch=$(git branch --show-current 2>/dev/null || echo "HEAD")

  # Get stats using --shortstat for cleaner parsing
  local shortstat_output
  local files_changed=0
  local insertions=0
  local deletions=0

  if shortstat_output=$(git show --shortstat --format= --no-color "$commit_hash"); then
    # Parse shortstat line: "N file(s) changed, M insertion(s)(+), P deletion(s)(-)"
    if [[ "$shortstat_output" =~ ([0-9]+)\ file ]]; then
      files_changed="${BASH_REMATCH[1]}"
    fi
    if [[ "$shortstat_output" =~ ([0-9]+)\ insertion ]]; then
      insertions="${BASH_REMATCH[1]}"
    fi
    if [[ "$shortstat_output" =~ ([0-9]+)\ deletion ]]; then
      deletions="${BASH_REMATCH[1]}"
    fi
  else
    echo "Warning: Failed to get commit stats for $commit_hash" >&2
  fi

  # Build formatted report
  local report
  report=$(cat <<EOF
✓ Commit Completed Successfully

**Commit:** ${commit_hash:0:7}\\
**Branch:** $branch\\
**Subject:** $subject\\
**Author:** $author\\
**Files Changed:** $files_changed
EOF
)

  # Build JSON output
  jq -n \
    --arg operation "commit" \
    --arg commit_hash "$commit_hash" \
    --arg short_hash "${commit_hash:0:7}" \
    --arg branch "$branch" \
    --arg subject "$subject" \
    --arg author "$author" \
    --arg date "$date" \
    --argjson files_changed "$files_changed" \
    --arg formatted_report "$report" \
    '{
      success: true,
      operation: $operation,
      details: {
        commit_hash: $commit_hash,
        short_hash: $short_hash,
        branch: $branch,
        subject: $subject,
        author: $author,
        date: $date,
        files_changed: $files_changed
      },
      formatted_report: $formatted_report
    }'
}

# Function to verify branch operation
verify_branch() {
  local branch_name="${2:-}"

  # Get current branch if not specified
  if [ -z "$branch_name" ]; then
    branch_name=$(git branch --show-current 2>/dev/null || echo "HEAD")
  fi

  # Verify branch exists
  if ! git rev-parse --verify "$branch_name" &>/dev/null; then
    jq -n \
      --arg error_type "branch_not_found" \
      --arg message "Branch not found: $branch_name" \
      --arg branch "$branch_name" \
      '{
        success: false,
        error_type: $error_type,
        message: $message,
        branch: $branch
      }'
    return 1
  fi

  # Get branch creation point (try to find where it diverged)
  local base_branch="${3:-main}"
  local diverged_from=""
  if git rev-parse --verify "$base_branch" &>/dev/null; then
    diverged_from=$(git merge-base "$branch_name" "$base_branch" 2>/dev/null || echo "")
  fi

  # Build formatted report
  local report
  if [ -n "$diverged_from" ]; then
    report=$(cat <<EOF
✓ Branch Operation Completed Successfully

**Branch:** $branch_name\\
**Base Branch:** $base_branch\\
**Diverged From:** ${diverged_from:0:7}
EOF
)
  else
    report=$(cat <<EOF
✓ Branch Operation Completed Successfully

**Branch:** $branch_name
EOF
)
  fi

  # Build JSON output
  jq -n \
    --arg operation "branch" \
    --arg branch "$branch_name" \
    --arg base_branch "$base_branch" \
    --arg diverged_from "$diverged_from" \
    --arg formatted_report "$report" \
    '{
      success: true,
      operation: $operation,
      details: {
        branch: $branch,
        base_branch: $base_branch,
        diverged_from: $diverged_from
      },
      formatted_report: $formatted_report
    }'
}

# Function to verify sync operation
verify_sync() {
  local branch="${2:-}"

  # Get current branch if not specified
  if [ -z "$branch" ]; then
    branch=$(git branch --show-current 2>/dev/null || echo "HEAD")
  fi

  # Check working tree status
  local is_clean=true
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    is_clean=false
  fi

  # Get recent commits (capture once, derive both JSON and formatted from same output)
  local git_log_output
  local recent_commits
  local formatted_commits

  if git_log_output=$(git log --oneline -5 2>/dev/null); then
    recent_commits=$(echo "$git_log_output" | jq -R '.' | jq -s '.')
    formatted_commits=$(echo "$git_log_output" | sed 's/^/  /')
  else
    recent_commits="[]"
    formatted_commits="  (no commits)"
  fi

  # Build formatted report
  local report
  report=$(cat <<EOF
✓ Sync Operation Completed Successfully

**Branch:** $branch\\
**Status:** $([ "$is_clean" = "true" ] && echo "Clean" || echo "Has uncommitted changes")\\
**Recent Commits:**
$formatted_commits
EOF
)

  # Build JSON output
  jq -n \
    --arg operation "sync" \
    --arg branch "$branch" \
    --argjson is_clean "$is_clean" \
    --argjson recent_commits "$recent_commits" \
    --arg formatted_report "$report" \
    '{
      success: true,
      operation: $operation,
      details: {
        branch: $branch,
        is_clean: $is_clean,
        recent_commits: $recent_commits
      },
      formatted_report: $formatted_report
    }'
}

# Function to verify PR operation
verify_pr() {
  local pr_url="${2:-}"

  if [ -z "$pr_url" ]; then
    jq -n \
      --arg error_type "invalid_usage" \
      --arg message "PR URL required for verification" \
      '{
        success: false,
        error_type: $error_type,
        message: $message
      }'
    return 1
  fi

  # Build formatted report
  local report
  report=$(cat <<EOF
✓ Pull Request Created Successfully

**PR URL:** $pr_url
EOF
)

  # Build JSON output
  jq -n \
    --arg operation "pr" \
    --arg pr_url "$pr_url" \
    --arg formatted_report "$report" \
    '{
      success: true,
      operation: $operation,
      details: {
        pr_url: $pr_url
      },
      formatted_report: $formatted_report
    }'
}

# Main execution
case "$OPERATION_TYPE" in
  commit)
    verify_commit "$@"
    ;;
  branch)
    verify_branch "$@"
    ;;
  sync)
    verify_sync "$@"
    ;;
  rebase)
    # Rebase is similar to sync
    verify_sync "$@"
    ;;
  pr)
    verify_pr "$@"
    ;;
  *)
    jq -n \
      --arg error_type "invalid_operation" \
      --arg message "Unknown operation type: $OPERATION_TYPE" \
      --arg suggested_action "Valid operations: commit, branch, sync, rebase, pr" \
      '{
        success: false,
        error_type: $error_type,
        message: $message,
        suggested_action: $suggested_action
      }'
    exit 1
    ;;
esac
