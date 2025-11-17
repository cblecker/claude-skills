#!/usr/bin/env bash
#
# Git Workflows UserPromptSubmit Hook
#
# Detects git/GitHub operations in user prompts and augments them with skill guidance.
# This hook fires on every user prompt to redirect git operations toward git-workflows skills
# instead of direct bash/git tool usage.
#
# Input: JSON on stdin with format: {"prompt": "user's message", "session_id": "...", ...}
# Output:
#   - If matched: JSON with additionalContext to guide Claude toward skills
#   - If not matched: Exit 0 with no output (minimal latency impact)
#

set -euo pipefail

# Read JSON input from stdin
input=$(cat)

# Extract the prompt field from JSON
# Using jq if available, otherwise fall back to grep
if command -v jq &> /dev/null; then
    prompt=$(echo "$input" | jq -r '.prompt // empty')
else
    # Fallback: basic extraction (works for simple cases)
    prompt=$(echo "$input" | grep -o '"prompt":"[^"]*"' | cut -d'"' -f4 || echo "")
fi

# Exit early if prompt is empty
if [[ -z "$prompt" ]]; then
    exit 0
fi

# Convert prompt to lowercase for case-insensitive matching
prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

# Skill pattern definitions
# Each skill has trigger patterns that should invoke it
# Patterns are matched case-insensitively against the user's prompt

# Pattern: creating-commit skill
# Triggers: commit, save changes, create commit, check in, git commit, git add
commit_patterns=(
    "commit"
    "save changes"
    "save my changes"
    "create commit"
    "check in"
    "git commit"
    "git add"
)

# Pattern: creating-pull-request skill
# Triggers: PR, pull request, create PR, open PR, gh pr
pr_patterns=(
    " pr"
    "pull request"
    "create pr"
    "open pr"
    "submit pr"
    "gh pr"
    "commit and pr"
)

# Pattern: creating-branch skill
# Triggers: create branch, new branch, start branch, git checkout, git branch
branch_patterns=(
    "create branch"
    "new branch"
    "start branch"
    "make a branch"
    "git checkout -b"
    "git branch"
)

# Pattern: syncing-branch skill
# Triggers: sync, pull latest, fetch, get latest, git pull, git fetch
sync_patterns=(
    "sync"
    "pull latest"
    "fetch"
    "get latest"
    "git pull"
    "git fetch"
    "update branch"
)

# Pattern: rebasing-branch skill
# Triggers: rebase, git rebase, rebase on, rebase onto
rebase_patterns=(
    "rebase"
    "git rebase"
)

# Function to check if prompt matches any pattern in an array
# Returns 0 (success) if match found, 1 otherwise
matches_pattern() {
    local patterns=("$@")
    for pattern in "${patterns[@]}"; do
        if [[ "$prompt_lower" == *"$pattern"* ]]; then
            return 0
        fi
    done
    return 1
}

# Check patterns in priority order (most specific first)
# PR skill first (can orchestrate commits, so takes precedence)
if matches_pattern "${pr_patterns[@]}"; then
    skill_name="creating-pull-request"
    skill_desc="pull request creation with end-to-end orchestration"
    operation="pull request operations"

# Rebase skill (specific git operation)
elif matches_pattern "${rebase_patterns[@]}"; then
    skill_name="rebasing-branch"
    skill_desc="rebasing with conflict handling and safety checks"
    operation="rebase operations"

# Branch creation skill
elif matches_pattern "${branch_patterns[@]}"; then
    skill_name="creating-branch"
    skill_desc="branch creation with mainline sync"
    operation="branch creation"

# Sync skill
elif matches_pattern "${sync_patterns[@]}"; then
    skill_name="syncing-branch"
    skill_desc="branch synchronization with fork/origin detection"
    operation="sync operations"

# Commit skill (most common, check last to avoid false positives from "commit and PR")
elif matches_pattern "${commit_patterns[@]}"; then
    skill_name="creating-commit"
    skill_desc="atomic commits with code review and validation"
    operation="commit operations"

# No git/GitHub pattern matched
else
    # Exit silently - no need to augment non-git prompts
    exit 0
fi

# Pattern matched - output JSON with additionalContext to guide Claude toward the skill
# The additionalContext appears in Claude's context and influences skill selection
cat <<EOF
{
  "decision": "approve",
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "[SYSTEM CONTEXT: This request matches the git-workflows/${skill_name} skill. The ${skill_name} skill is the standard workflow for all ${operation}, replacing manual git commands. Evaluate this skill before considering bash/git tools.]"
  }
}
EOF

exit 0
