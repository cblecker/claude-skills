#!/usr/bin/env bash
# Integration tests for context gatherer scripts

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test framework
source "$TEST_ROOT/test-framework.sh"

# Path to scripts
GATHER_COMMIT_SCRIPT="$TEST_ROOT/../scripts/gather-commit-context.sh"
GATHER_PR_SCRIPT="$TEST_ROOT/../scripts/gather-pr-context.sh"

# ===== TESTS FOR gather-commit-context.sh =====

test_gather_commit_context_clean_tree() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Clean working tree (should error)
  local output
  output=$("$GATHER_COMMIT_SCRIPT" 2>&1 || true)

  assert_failure "$output" "clean_working_tree" "Should fail with clean working tree" || return 1
  assert_json_field "$output" ".message" "No changes to commit" || return 1
}

test_gather_commit_context_staged_changes() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Create staged changes
  setup_mock_changes "staged"

  local output
  output=$("$GATHER_COMMIT_SCRIPT")

  assert_success "$output" "Should succeed with staged changes" || return 1

  # Check current branch is not empty
  local current_branch
  current_branch=$(echo "$output" | jq -r '.current_branch')
  if [ -z "$current_branch" ]; then
    error "Should have current branch"
    return 1
  fi

  assert_json_field "$output" ".working_tree_status.has_staged" "true" "Should have staged changes" || return 1
  assert_json_field "$output" ".working_tree_status.is_clean" "false" "Should not be clean" || return 1
}

test_gather_commit_context_mixed_changes() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Create mixed changes
  setup_mock_changes "mixed"

  local output
  output=$("$GATHER_COMMIT_SCRIPT")

  assert_success "$output" "Should succeed with mixed changes" || return 1
  assert_json_field "$output" ".working_tree_status.has_staged" "true" "Should have staged" || return 1
  assert_json_field "$output" ".working_tree_status.has_unstaged" "true" "Should have unstaged" || return 1
  assert_json_field "$output" ".working_tree_status.has_untracked" "true" "Should have untracked" || return 1

  # Check that file categorization happened
  local code_count
  code_count=$(echo "$output" | jq '.file_categories.code | length')
  log "Code files count: $code_count"
}

test_gather_commit_context_conventional_commits() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Add conventional commits
  setup_mock_commits "conventional" 10

  # Create some changes
  setup_mock_changes "staged"

  local output
  output=$("$GATHER_COMMIT_SCRIPT")

  assert_success "$output" || return 1
  assert_json_field "$output" ".uses_conventional_commits" "true" "Should detect conventional commits" || return 1
  assert_json_field "$output" ".conventional_commits_confidence" "high" "Should have high confidence" || return 1

  # Check recent commits exist
  local recent_count
  recent_count=$(echo "$output" | jq '.recent_commits | length')
  if [ "$recent_count" -lt 1 ]; then
    error "Should have recent commits"
    return 1
  fi
}

test_gather_commit_context_diff_summary() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Create multiple file changes
  echo "content1" > file1.txt
  echo "content2" > file2.txt
  echo "content3" > file3.txt
  git add file1.txt file2.txt file3.txt

  local output
  output=$("$GATHER_COMMIT_SCRIPT")

  assert_success "$output" || return 1

  # Check diff summary
  local files_changed
  files_changed=$(echo "$output" | jq '.diff_summary.files_changed')
  if [ "$files_changed" -lt 1 ]; then
    error "Should have files changed in diff summary"
    return 1
  fi
}

# ===== TESTS FOR gather-pr-context.sh =====

test_gather_pr_context_on_base_branch() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Try to create PR from main branch (should error)
  # First detect what branch we're on
  local current_branch
  current_branch=$(git branch --show-current)

  local output
  output=$("$GATHER_PR_SCRIPT" "$current_branch" 2>&1 || true)

  assert_failure "$output" "on_base_branch" "Should fail when on base branch" || return 1
}

test_gather_pr_context_no_commits() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Create feature branch with no new commits
  git checkout -b feature-branch 2>/dev/null

  local output
  output=$("$GATHER_PR_SCRIPT" "main" 2>&1 || true)

  assert_failure "$output" "no_commits" "Should fail with no commits" || return 1

  # Check message contains "No commits found"
  local message
  message=$(echo "$output" | jq -r '.message')
  if [[ ! "$message" =~ "No commits found" ]]; then
    error "Message should contain 'No commits found', got: $message"
    return 1
  fi
}

test_gather_pr_context_with_commits() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Create feature branch
  git checkout -b feature-branch 2>/dev/null

  # Add commits
  setup_mock_commits "conventional" 3

  # Determine the base branch
  local base_branch="main"
  if git rev-parse --verify master &>/dev/null; then
    base_branch="master"
  fi

  local output
  output=$("$GATHER_PR_SCRIPT" "$base_branch")

  assert_success "$output" "Should succeed with commits" || return 1
  assert_json_field "$output" ".current_branch" "feature-branch" || return 1
  assert_json_field "$output" ".base_branch" "$base_branch" || return 1
  assert_json_field "$output" ".branch_validation.is_feature_branch" "true" || return 1

  # Check commit history
  local commit_count
  commit_count=$(echo "$output" | jq '.commit_history | length')
  if [ "$commit_count" -lt 3 ]; then
    error "Should have at least 3 commits in history"
    return 1
  fi
}

test_gather_pr_context_fork_repo() {
  local repo_dir
  repo_dir=$(setup_mock_repo "fork")
  cd "$repo_dir"

  # Create feature branch
  git checkout -b feature-branch 2>/dev/null

  # Add commits
  setup_mock_commits "standard" 2

  local base_branch="main"
  if git rev-parse --verify master &>/dev/null; then
    base_branch="master"
  fi

  local output
  output=$("$GATHER_PR_SCRIPT" "$base_branch")

  assert_success "$output" "Should succeed with fork" || return 1
  assert_json_field "$output" ".is_fork" "true" "Should detect fork" || return 1
  assert_json_field "$output" ".repository.upstream_owner" "upstream" || return 1
  assert_json_field "$output" ".repository.origin_owner" "testuser" || return 1
}

test_gather_pr_context_uncommitted_changes() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Create feature branch
  git checkout -b feature-branch 2>/dev/null

  # Add commits
  setup_mock_commits "standard" 1

  # Create uncommitted changes
  echo "uncommitted" > uncommitted.txt

  local base_branch="main"
  if git rev-parse --verify master &>/dev/null; then
    base_branch="master"
  fi

  local output
  output=$("$GATHER_PR_SCRIPT" "$base_branch")

  assert_success "$output" "Should succeed even with uncommitted changes" || return 1
  assert_json_field "$output" ".branch_validation.has_uncommitted_changes" "true" || return 1

  # Check uncommitted files list
  local uncommitted_count
  uncommitted_count=$(echo "$output" | jq '.uncommitted_files | length')
  if [ "$uncommitted_count" -lt 1 ]; then
    error "Should list uncommitted files"
    return 1
  fi
}

test_gather_pr_context_diff_summary() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Create feature branch
  git checkout -b feature-branch 2>/dev/null

  # Add multiple commits with changes
  for i in {1..3}; do
    echo "content $i" > "file$i.txt"
    git add "file$i.txt"
    git commit -q -m "Add file $i"
  done

  local base_branch="main"
  if git rev-parse --verify master &>/dev/null; then
    base_branch="master"
  fi

  local output
  output=$("$GATHER_PR_SCRIPT" "$base_branch")

  assert_success "$output" || return 1

  # Check diff summary
  local files_changed
  files_changed=$(echo "$output" | jq '.diff_summary.files_changed')
  if [ "$files_changed" -lt 3 ]; then
    error "Should have at least 3 files changed"
    return 1
  fi
}

# ===== RUN ALL TESTS =====

echo "========================================"
echo "Running Context Gatherer Integration Tests"
echo "========================================"
echo ""

echo "gather-commit-context.sh Tests"
echo "-------------------------------"
run_test "gather-commit: Clean tree error" test_gather_commit_context_clean_tree
run_test "gather-commit: Staged changes" test_gather_commit_context_staged_changes
run_test "gather-commit: Mixed changes" test_gather_commit_context_mixed_changes
run_test "gather-commit: Conventional commits" test_gather_commit_context_conventional_commits
run_test "gather-commit: Diff summary" test_gather_commit_context_diff_summary

echo ""
echo "gather-pr-context.sh Tests"
echo "--------------------------"
run_test "gather-pr: On base branch error" test_gather_pr_context_on_base_branch
run_test "gather-pr: No commits error" test_gather_pr_context_no_commits
run_test "gather-pr: With commits" test_gather_pr_context_with_commits
run_test "gather-pr: Fork repository" test_gather_pr_context_fork_repo
run_test "gather-pr: Uncommitted changes" test_gather_pr_context_uncommitted_changes
run_test "gather-pr: Diff summary" test_gather_pr_context_diff_summary

echo ""
report_test_results
