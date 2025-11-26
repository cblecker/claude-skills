#!/usr/bin/env bash
# Detect if repository uses Conventional Commits
# Usage: ./detect-conventions.sh

set -euo pipefail

# Check for required dependencies
if ! command -v jq &> /dev/null; then
  echo '{"success": false, "error_type": "missing_dependency", "message": "jq is required but not installed"}' >&2
  exit 1
fi

# Conventional Commits pattern
CONVENTIONAL_PATTERN='^(feat|fix|docs|style|refactor|perf|test|chore|build|ci|revert)(\(.+\))?!?: .+'

# Function to check for commitlint config files
check_commitlint_config() {
  local config_files=(
    ".commitlintrc.json"
    ".commitlintrc.js"
    ".commitlintrc.yml"
    ".commitlintrc.yaml"
    "commitlint.config.js"
    "commitlint.config.cjs"
  )

  for config_file in "${config_files[@]}"; do
    if [ -f "$config_file" ]; then
      echo "commitlint_config"
      echo "high"
      echo "$config_file"
      return 0
    fi
  done

  return 1
}

# Function to check CONTRIBUTING.md for Conventional Commits mentions
check_contributing_md() {
  local contributing_files=(
    "CONTRIBUTING.md"
    "CONTRIBUTING.rst"
    "CONTRIBUTING.txt"
    ".github/CONTRIBUTING.md"
    "docs/CONTRIBUTING.md"
  )

  for contributing_file in "${contributing_files[@]}"; do
    if [ -f "$contributing_file" ]; then
      # Check for mentions of "Conventional Commits" or "conventional commit"
      if grep -qi "conventional commit" "$contributing_file"; then
        echo "contributing_md"
        echo "high"
        echo "$contributing_file"
        return 0
      fi
    fi
  done

  return 1
}

# Function to analyze commit history
analyze_commit_history() {
  local sample_size=10

  # Get recent commit messages (subject lines only)
  local commits
  if ! commits=$(git log --format=%s -n "$sample_size" 2>/dev/null); then
    return 1
  fi

  # Count total commits
  local total_count=0
  local match_count=0

  while IFS= read -r commit_msg; do
    [ -z "$commit_msg" ] && continue
    ((total_count++))

    # Check if commit message matches Conventional Commits pattern
    if echo "$commit_msg" | grep -qE "$CONVENTIONAL_PATTERN"; then
      ((match_count++))
    fi
  done <<< "$commits"

  # Calculate match rate
  if [ $total_count -eq 0 ]; then
    return 1
  fi

  local match_rate=$((match_count * 100 / total_count))

  # Determine confidence based on match rate
  # >= 60% = high confidence (threshold from refactor plan)
  # >= 40% = medium confidence
  # < 40% = low confidence (return false)

  if [ $match_rate -ge 60 ]; then
    echo "commit_history"
    echo "high"
    echo "$match_rate"
    echo "$total_count"
    return 0
  elif [ $match_rate -ge 40 ]; then
    echo "commit_history"
    echo "medium"
    echo "$match_rate"
    echo "$total_count"
    return 0
  else
    # Too low to consider conventional commits
    return 1
  fi
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

  local uses_conventional=false
  local detection_method=""
  local confidence=""
  local config_file=""
  local pattern_match_rate=0
  local sample_size=0

  # Try detection methods in order of confidence

  # 1. Check for commitlint config (highest confidence)
  if result=$(check_commitlint_config); then
    uses_conventional=true
    {
      read -r detection_method
      read -r confidence
      read -r config_file
    } <<< "$result"
  # 2. Check CONTRIBUTING.md (high confidence)
  elif result=$(check_contributing_md); then
    uses_conventional=true
    {
      read -r detection_method
      read -r confidence
      read -r config_file
    } <<< "$result"
  # 3. Analyze commit history (variable confidence)
  elif result=$(analyze_commit_history); then
    uses_conventional=true
    {
      read -r detection_method
      read -r confidence
      read -r pattern_match_rate
      read -r sample_size
    } <<< "$result"
  else
    # No detection
    uses_conventional=false
    detection_method="none"
    confidence="none"
  fi

  # Build JSON output
  if [ "$detection_method" = "commitlint_config" ]; then
      jq -n \
        --argjson uses_conventional "$uses_conventional" \
        --arg detection_method "$detection_method" \
        --arg confidence "$confidence" \
        --arg config_file "$config_file" \
        '{
          success: true,
          uses_conventional_commits: $uses_conventional,
          detection_method: $detection_method,
          confidence: $confidence,
          config_file: $config_file
        }'
    elif [ "$detection_method" = "contributing_md" ]; then
      jq -n \
        --argjson uses_conventional "$uses_conventional" \
        --arg detection_method "$detection_method" \
        --arg confidence "$confidence" \
        --arg config_file "$config_file" \
        '{
          success: true,
          uses_conventional_commits: $uses_conventional,
          detection_method: $detection_method,
          confidence: $confidence,
          contributing_file: $config_file
        }'
    elif [ "$detection_method" = "commit_history" ]; then
      # Convert match rate to float for jq
      local match_rate_float
      match_rate_float=$(jq -n --argjson rate "$pattern_match_rate" '$rate / 100')
      jq -n \
        --argjson uses_conventional "$uses_conventional" \
        --arg detection_method "$detection_method" \
        --arg confidence "$confidence" \
        --argjson pattern_match_rate "$match_rate_float" \
        --argjson sample_size "$sample_size" \
        '{
          success: true,
          uses_conventional_commits: $uses_conventional,
          detection_method: $detection_method,
          confidence: $confidence,
          pattern_match_rate: $pattern_match_rate,
          sample_size: $sample_size
        }'
    else
      # No detection
      jq -n \
        '{
          success: true,
          uses_conventional_commits: false,
          detection_method: "none",
          confidence: "none"
        }'
    fi
}

# Run main function
main
