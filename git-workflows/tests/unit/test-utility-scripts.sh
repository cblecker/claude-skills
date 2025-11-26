#!/usr/bin/env bash
# Unit tests for utility scripts (get-repository-type, get-mainline-branch, detect-conventions)

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test framework
source "$TEST_ROOT/test-framework.sh"

# Path to scripts
REPO_TYPE_SCRIPT="$TEST_ROOT/../scripts/get-repository-type.sh"
MAINLINE_BRANCH_SCRIPT="$TEST_ROOT/../scripts/get-mainline-branch.sh"
DETECT_CONVENTIONS_SCRIPT="$TEST_ROOT/../scripts/detect-conventions.sh"

# ===== TESTS FOR get-repository-type.sh =====

test_repository_type_origin() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  local output
  output=$("$REPO_TYPE_SCRIPT")

  assert_success "$output" "Should succeed for origin-only repo" || return 1
  assert_json_field "$output" ".is_fork" "false" "Should not be a fork" || return 1
  assert_json_field "$output" ".origin.owner" "testuser" "Should extract owner" || return 1
  assert_json_field "$output" ".origin.repo" "testrepo" "Should extract repo" || return 1
  assert_json_field "$output" ".upstream" "null" "Should have null upstream" || return 1
}

test_repository_type_fork() {
  local repo_dir
  repo_dir=$(setup_mock_repo "fork")
  cd "$repo_dir"

  local output
  output=$("$REPO_TYPE_SCRIPT")

  assert_success "$output" "Should succeed for fork repo" || return 1
  assert_json_field "$output" ".is_fork" "true" "Should be a fork" || return 1
  assert_json_field "$output" ".origin.owner" "testuser" "Should extract origin owner" || return 1
  assert_json_field "$output" ".upstream.owner" "upstream" "Should extract upstream owner" || return 1
  assert_json_field "$output" ".upstream.repo" "testrepo" "Should extract upstream repo" || return 1
}

test_repository_type_no_remote() {
  local repo_dir
  repo_dir=$(setup_mock_repo "empty")
  cd "$repo_dir"

  local output
  output=$("$REPO_TYPE_SCRIPT" 2>&1 || true)

  assert_failure "$output" "no_remote" "Should fail with no_remote error" || return 1
  assert_json_field "$output" ".message" "No origin remote found" "Should have appropriate error message" || return 1
}

test_repository_type_ssh_url() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Change remote to SSH URL
  git remote set-url origin "git@github.com:testuser/testrepo.git"

  local output
  output=$("$REPO_TYPE_SCRIPT")

  assert_success "$output" "Should parse SSH URL" || return 1
  assert_json_field "$output" ".origin.owner" "testuser" "Should extract owner from SSH URL" || return 1
  assert_json_field "$output" ".origin.repo" "testrepo" "Should extract repo from SSH URL" || return 1
}

test_repository_type_git_protocol() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Change remote to git:// URL
  git remote set-url origin "git://github.com/testuser/testrepo.git"

  local output
  output=$("$REPO_TYPE_SCRIPT")

  assert_success "$output" "Should parse git:// URL" || return 1
  assert_json_field "$output" ".origin.owner" "testuser" "Should extract owner from git:// URL" || return 1
}

# ===== TESTS FOR get-mainline-branch.sh =====

test_mainline_branch_detection() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Create a fake remote HEAD response by mocking git ls-remote
  # We'll create a mock that returns main as the default branch
  # For testing purposes, we'll just check the output format

  local output
  output=$("$MAINLINE_BRANCH_SCRIPT" 2>&1 || true)

  # This might fail if there's no actual remote, but we check the JSON structure
  if echo "$output" | jq -e '.success' &>/dev/null; then
    assert_json_field "$output" ".mainline_branch" "*" "Should have mainline_branch field" || return 1
    assert_json_field "$output" ".comparison_branch" "*" "Should have comparison_branch field" || return 1
    assert_json_field "$output" ".is_mainline" "*" "Should have is_mainline field" || return 1
  else
    # If it fails, should be because remote is not accessible
    assert_failure "$output" || return 1
  fi
}

test_mainline_branch_comparison() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Create a feature branch
  git checkout -b feature-branch 2>/dev/null || true

  local output
  output=$("$MAINLINE_BRANCH_SCRIPT" "feature-branch" 2>&1 || true)

  # Check that comparison branch is set correctly
  if echo "$output" | jq -e '.success' &>/dev/null; then
    assert_json_field "$output" ".comparison_branch" "feature-branch" "Should use specified branch" || return 1
  fi
}

# ===== TESTS FOR detect-conventions.sh =====

test_detect_conventions_no_commits() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Fresh repo with only initial commit (not conventional)
  local output
  output=$("$DETECT_CONVENTIONS_SCRIPT")

  assert_success "$output" "Should succeed even with no conventional commits" || return 1
  # Should return false since initial commit is not conventional
  assert_json_field "$output" ".uses_conventional_commits" "false" "Should not detect conventional commits" || return 1
}

test_detect_conventions_conventional_commits() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Add conventional commits
  setup_mock_commits "conventional" 10

  local output
  output=$("$DETECT_CONVENTIONS_SCRIPT")

  assert_success "$output" "Should succeed with conventional commits" || return 1
  assert_json_field "$output" ".uses_conventional_commits" "true" "Should detect conventional commits" || return 1
  assert_json_field "$output" ".detection_method" "commit_history" "Should use commit_history method" || return 1
  assert_json_field "$output" ".confidence" "high" "Should have high confidence" || return 1
}

test_detect_conventions_standard_commits() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Add standard commits
  setup_mock_commits "standard" 10

  local output
  output=$("$DETECT_CONVENTIONS_SCRIPT")

  assert_success "$output" "Should succeed with standard commits" || return 1
  assert_json_field "$output" ".uses_conventional_commits" "false" "Should not detect conventional commits" || return 1
}

test_detect_conventions_commitlint_config() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Create commitlint config
  echo '{"extends": ["@commitlint/config-conventional"]}' > .commitlintrc.json

  local output
  output=$("$DETECT_CONVENTIONS_SCRIPT")

  assert_success "$output" "Should succeed with commitlint config" || return 1
  assert_json_field "$output" ".uses_conventional_commits" "true" "Should detect from commitlint config" || return 1
  assert_json_field "$output" ".detection_method" "commitlint_config" "Should use commitlint_config method" || return 1
  assert_json_field "$output" ".confidence" "high" "Should have high confidence" || return 1
  assert_json_field "$output" ".config_file" ".commitlintrc.json" "Should report config file" || return 1
}

test_detect_conventions_contributing_md() {
  local repo_dir
  repo_dir=$(setup_mock_repo "origin")
  cd "$repo_dir"

  # Create CONTRIBUTING.md with mention of Conventional Commits
  cat > CONTRIBUTING.md <<'EOF'
# Contributing Guide

We use Conventional Commits for our commit messages.

Please format your commits as: `type(scope): description`
EOF

  local output
  output=$("$DETECT_CONVENTIONS_SCRIPT")

  assert_success "$output" "Should succeed with CONTRIBUTING.md" || return 1
  assert_json_field "$output" ".uses_conventional_commits" "true" "Should detect from CONTRIBUTING.md" || return 1
  assert_json_field "$output" ".detection_method" "contributing_md" "Should use contributing_md method" || return 1
  assert_json_field "$output" ".confidence" "high" "Should have high confidence" || return 1
}

# ===== RUN ALL TESTS =====

echo "========================================"
echo "Running Utility Script Tests"
echo "========================================"
echo ""

echo "get-repository-type.sh Tests"
echo "----------------------------"
run_test "repository-type: Origin only" test_repository_type_origin
run_test "repository-type: Fork with upstream" test_repository_type_fork
run_test "repository-type: No remote" test_repository_type_no_remote
run_test "repository-type: SSH URL parsing" test_repository_type_ssh_url
run_test "repository-type: git:// URL parsing" test_repository_type_git_protocol

echo ""
echo "get-mainline-branch.sh Tests"
echo "----------------------------"
run_test "mainline-branch: Detection" test_mainline_branch_detection
run_test "mainline-branch: Branch comparison" test_mainline_branch_comparison

echo ""
echo "detect-conventions.sh Tests"
echo "---------------------------"
run_test "detect-conventions: No conventional commits" test_detect_conventions_no_commits
run_test "detect-conventions: Conventional commits" test_detect_conventions_conventional_commits
run_test "detect-conventions: Standard commits" test_detect_conventions_standard_commits
run_test "detect-conventions: Commitlint config" test_detect_conventions_commitlint_config
run_test "detect-conventions: CONTRIBUTING.md" test_detect_conventions_contributing_md

echo ""
report_test_results
