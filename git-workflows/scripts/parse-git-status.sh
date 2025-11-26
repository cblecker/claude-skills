#!/usr/bin/env bash
# Parse git status --porcelain output into structured JSON
# Usage: git status --porcelain | ./parse-git-status.sh

set -euo pipefail

# Check for required jq dependency
if ! command -v jq &> /dev/null; then
  echo '{"success": false, "error_type": "missing_dependency", "message": "jq is required but not installed", "suggested_action": "Install jq: brew install jq (macOS) or apt-get install jq (Linux)"}' >&2
  exit 1
fi

# Arrays to hold files
declare -a staged_files=()
declare -a unstaged_files=()
declare -a untracked_files=()

# Read stdin line by line
while IFS= read -r line; do
  # Skip empty lines
  [ -z "$line" ] && continue

  # Extract status codes and path
  # Format: XY PATH where X is staged, Y is unstaged
  status_codes="${line:0:2}"
  path="${line:3}"

  # Extract individual status codes
  staged_status="${status_codes:0:1}"
  unstaged_status="${status_codes:1:1}"

  # Untracked files
  if [ "$status_codes" = "??" ]; then
    untracked_files+=("$path")
    continue
  fi

  # Staged files (X is not space or ?)
  if [ "$staged_status" != " " ] && [ "$staged_status" != "?" ]; then
    # Build JSON object for staged file using jq for proper escaping
    staged_files+=("$(jq -n --arg status "$staged_status" --arg path "$path" '{status: $status, path: $path}')")
  fi

  # Unstaged files (Y is not space or ?)
  if [ "$unstaged_status" != " " ] && [ "$unstaged_status" != "?" ]; then
    # Build JSON object for unstaged file using jq for proper escaping
    unstaged_files+=("$(jq -n --arg status "$unstaged_status" --arg path "$path" '{status: $status, path: $path}')")
  fi
done

# Check if working tree is clean
is_clean=true
if [ ${#staged_files[@]} -gt 0 ] || [ ${#unstaged_files[@]} -gt 0 ] || [ ${#untracked_files[@]} -gt 0 ]; then
  is_clean=false
fi

# Build JSON output
# Build arrays with jq (handle empty arrays)
if [ ${#staged_files[@]} -gt 0 ]; then
  staged_json=$(printf '%s\n' "${staged_files[@]}" | jq -s '.')
else
  staged_json="[]"
fi

if [ ${#unstaged_files[@]} -gt 0 ]; then
  unstaged_json=$(printf '%s\n' "${unstaged_files[@]}" | jq -s '.')
else
  unstaged_json="[]"
fi

if [ ${#untracked_files[@]} -gt 0 ]; then
  untracked_json=$(printf '%s\n' "${untracked_files[@]}" | jq -R '.' | jq -s '.')
else
  untracked_json="[]"
fi

# Build final object
jq -n \
  --argjson is_clean "$is_clean" \
  --argjson staged "$staged_json" \
  --argjson unstaged "$unstaged_json" \
  --argjson untracked "$untracked_json" \
  '{
    is_clean: $is_clean,
    staged: $staged,
    unstaged: $unstaged,
    untracked: $untracked
  }'
