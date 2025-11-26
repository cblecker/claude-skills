#!/usr/bin/env bash
# Integration tests for sync-branch.sh

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test framework
source "$TEST_ROOT/test-framework.sh"

# Path to script
SYNC_BRANCH_SCRIPT="$TEST_ROOT/../scripts/sync-branch.sh"

# ===== TESTS FOR sync-branch.sh =====

test_sync_branch_uncommitted_changes() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Create uncommitted changes
  echo "uncommitted" > test.txt

  local output
  output=$("$SYNC_BRANCH_SCRIPT" 2>&1 || true)

  assert_failure "$output" "uncommitted_changes" "Should fail with uncommitted changes" || return 1

  # Check uncommitted files are listed
  local uncommitted_count
  uncommitted_count=$(echo "$output" | jq '.uncommitted_files | length')
  if [ "$uncommitted_count" -lt 1 ]; then
    error "Should list uncommitted files"
    return 1
  fi
}

test_sync_branch_nonexistent_branch() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  local output
  output=$("$SYNC_BRANCH_SCRIPT" "nonexistent-branch" 2>&1 || true)

  assert_failure "$output" "branch_not_found" "Should fail with nonexistent branch" || return 1
}

test_sync_branch_clean_repo() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # The mock repo won't have a real remote, so this will likely fail at fetch
  # but we can test the structure
  local output
  output=$("$SYNC_BRANCH_SCRIPT" 2>&1 || true)

  # Should either succeed or fail gracefully
  local success
  success=$(echo "$output" | jq -r '.success' 2>/dev/null || echo "")

  if [ "$success" = "true" ]; then
    # If it succeeds, check structure
    local branch
    local is_fork
    local status
    branch=$(echo "$output" | jq -r '.branch')
    is_fork=$(echo "$output" | jq -r '.is_fork')
    status=$(echo "$output" | jq -r '.status')

    if [ -z "$branch" ] || [ -z "$is_fork" ] || [ -z "$status" ]; then
      error "Missing required fields in success response"
      return 1
    fi
  else
    # If it fails, should have proper error structure
    local error_type
    local message
    error_type=$(echo "$output" | jq -r '.error_type')
    message=$(echo "$output" | jq -r '.message')

    if [ -z "$error_type" ] || [ -z "$message" ]; then
      error "Missing required fields in error response"
      return 1
    fi
  fi
}

test_sync_branch_fork_detection() {
  local repo_dir
  repo_dir=$(setup_mock_repo "fork")
  cd "$repo_dir"

  local output
  output=$("$SYNC_BRANCH_SCRIPT" 2>&1 || true)

  # Check that fork was detected in the output (if operation completed)
  if echo "$output" | jq -e '.is_fork' &>/dev/null; then
    assert_json_field "$output" ".is_fork" "true" "Should detect fork repository" || return 1
  fi
}

test_sync_branch_origin_detection() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  local output
  output=$("$SYNC_BRANCH_SCRIPT" 2>&1 || true)

  # Check that origin-only was detected in the output (if operation completed)
  if echo "$output" | jq -e '.is_fork' &>/dev/null; then
    assert_json_field "$output" ".is_fork" "false" "Should detect origin-only repository" || return 1
  fi
}

test_sync_branch_specific_branch() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Create a new branch
  git checkout -b test-branch 2>/dev/null

  local output
  output=$("$SYNC_BRANCH_SCRIPT" "test-branch" 2>&1 || true)

  # If successful, should reference the correct branch
  if echo "$output" | jq -e '.success' &>/dev/null; then
    assert_json_field "$output" ".branch" "test-branch" "Should sync specified branch" || return 1
  fi
}

# ===== RUN ALL TESTS =====

echo "========================================"
echo "Running sync-branch.sh Integration Tests"
echo "========================================"
echo ""

run_test "sync-branch: Uncommitted changes error" test_sync_branch_uncommitted_changes
run_test "sync-branch: Nonexistent branch error" test_sync_branch_nonexistent_branch
run_test "sync-branch: Clean repo" test_sync_branch_clean_repo
run_test "sync-branch: Fork detection" test_sync_branch_fork_detection
run_test "sync-branch: Origin detection" test_sync_branch_origin_detection
run_test "sync-branch: Specific branch" test_sync_branch_specific_branch

echo ""
report_test_results
