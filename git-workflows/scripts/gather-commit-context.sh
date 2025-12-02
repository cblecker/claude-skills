#!/usr/bin/env bash
# Gather all context needed for commit message generation
# Usage: ./gather-commit-context.sh

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

# Function to parse git status
parse_git_status() {
  git status --porcelain | "$SCRIPT_DIR/parse-git-status.sh"
}

# Function to get recent commits (with proper JSON escaping)
get_recent_commits() {
  local count=${1:-5}
  local commits='[]'

  # Use null-delimited format for safe parsing of special characters
  # Format: HASH\0SUBJECT\0\n per commit, so we read null-delimited and trim newlines
  while IFS= read -r -d '' hash && IFS= read -r -d '' subject; do
    # Remove any leading/trailing whitespace from hash (handles newline between records)
    hash="${hash#"${hash%%[![:space:]]*}"}"
    commits=$(echo "$commits" | jq --arg h "$hash" --arg s "$subject" '. + [{hash: $h, subject: $s}]')
  done < <(git log --format='%H%x00%s%x00' -n "$count" 2>/dev/null)

  echo "$commits"
}

# Function to get diff summary
get_diff_summary() {
  local diff_output
  diff_output=$(git diff --shortstat HEAD 2>/dev/null || echo "")

  if [ -z "$diff_output" ]; then
    echo '{"files_changed": 0, "insertions": 0, "deletions": 0}'
    return
  fi

  # Parse the output: " 3 files changed, 45 insertions(+), 12 deletions(-)"
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

  # Get mainline branch info
  local mainline_info
  if ! mainline_info=$("$SCRIPT_DIR/get-mainline-branch.sh" "$current_branch" 2>/dev/null); then
    # If mainline detection fails, continue with defaults
    mainline_info=$(jq -n \
      --arg current "$current_branch" \
      '{
        success: true,
        mainline_branch: "main",
        comparison_branch: $current,
        is_mainline: false
      }')
  fi

  local mainline_branch
  local is_mainline
  mainline_branch=$(echo "$mainline_info" | jq -r '.mainline_branch')
  is_mainline=$(echo "$mainline_info" | jq -r '.is_mainline')

  # Detect conventions
  local conventions_info
  if ! conventions_info=$("$SCRIPT_DIR/detect-conventions.sh" 2>/dev/null); then
    # If detection fails, assume no conventions
    conventions_info=$(jq -n '{
      success: true,
      uses_conventional_commits: false,
      detection_method: "none",
      confidence: "none"
    }')
  fi

  local uses_conventional_commits
  local conventional_commits_confidence
  uses_conventional_commits=$(echo "$conventions_info" | jq -r '.uses_conventional_commits')
  conventional_commits_confidence=$(echo "$conventions_info" | jq -r '.confidence')

  # Parse git status
  local status_info
  if ! status_info=$(parse_git_status); then
    jq -n \
      --arg error_type "git_status_failed" \
      --arg message "Failed to parse git status" \
      --arg suggested_action "Check git repository status" \
      '{
        success: false,
        error_type: $error_type,
        message: $message,
        suggested_action: $suggested_action
      }'
    exit 1
  fi

  local is_clean
  is_clean=$(echo "$status_info" | jq -r '.is_clean')

  # Check if working tree is clean (error condition for commit)
  if [ "$is_clean" = "true" ]; then
    jq -n \
      --arg error_type "clean_working_tree" \
      --arg message "No changes to commit" \
      --arg suggested_action "Make changes before creating a commit" \
      '{
        success: false,
        error_type: $error_type,
        message: $message,
        suggested_action: $suggested_action
      }'
    exit 1
  fi

  # Extract file lists from status
  local staged_files
  local unstaged_files
  local untracked_files
  staged_files=$(echo "$status_info" | jq -c '.staged')
  unstaged_files=$(echo "$status_info" | jq -c '.unstaged')
  untracked_files=$(echo "$status_info" | jq -c '.untracked')

  # Determine working tree status flags
  local has_staged
  local has_unstaged
  local has_untracked
  has_staged=$(echo "$staged_files" | jq 'length > 0')
  has_unstaged=$(echo "$unstaged_files" | jq 'length > 0')
  has_untracked=$(echo "$untracked_files" | jq 'length > 0')

  # Categorize all files (staged + unstaged + untracked)
  local all_files
  all_files=$(echo "$status_info" | jq -r '(.staged[].path, .unstaged[].path, .untracked[])')

  local file_categories
  if [ -n "$all_files" ]; then
    file_categories=$(echo "$all_files" | "$SCRIPT_DIR/categorize-files.sh")
  else
    file_categories='{"code": [], "tests": [], "docs": [], "config": [], "other": []}'
  fi

  # Get recent commits
  local recent_commits
  if ! recent_commits=$(get_recent_commits 5); then
    recent_commits='[]'
  fi

  # Get diff summary
  local diff_summary
  if ! diff_summary=$(get_diff_summary); then
    diff_summary='{"files_changed": 0, "insertions": 0, "deletions": 0}'
  fi

  # Build comprehensive JSON output
  jq -n \
    --arg current_branch "$current_branch" \
    --arg mainline_branch "$mainline_branch" \
    --argjson is_mainline "$is_mainline" \
    --argjson uses_conventional "$uses_conventional_commits" \
    --arg conventional_confidence "$conventional_commits_confidence" \
    --argjson is_clean "$is_clean" \
    --argjson has_staged "$has_staged" \
    --argjson has_unstaged "$has_unstaged" \
    --argjson has_untracked "$has_untracked" \
    --argjson staged "$staged_files" \
    --argjson unstaged "$unstaged_files" \
    --argjson untracked "$untracked_files" \
    --argjson file_categories "$file_categories" \
    --argjson recent_commits "$recent_commits" \
    --argjson diff_summary "$diff_summary" \
    '{
      success: true,
      current_branch: $current_branch,
      mainline_branch: $mainline_branch,
      is_mainline: $is_mainline,
      uses_conventional_commits: $uses_conventional,
      conventional_commits_confidence: $conventional_confidence,
      working_tree_status: {
        is_clean: $is_clean,
        has_staged: $has_staged,
        has_unstaged: $has_unstaged,
        has_untracked: $has_untracked
      },
      staged_files: $staged,
      unstaged_files: $unstaged,
      untracked_files: $untracked,
      file_categories: $file_categories,
      recent_commits: $recent_commits,
      diff_summary: $diff_summary
    }'
}

# Run main function
main
