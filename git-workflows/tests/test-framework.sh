#!/bin/bash
# Test Framework for git-workflows Scripts
# Provides utilities for testing bash scripts with JSON output

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Track temp directories for cleanup
declare -a TEMP_DIRS=()

# Check for required dependencies
check_dependencies() {
  local missing_deps=()

  if ! command -v jq &> /dev/null; then
    missing_deps+=("jq")
  fi

  if ! command -v git &> /dev/null; then
    missing_deps+=("git")
  fi

  if [ ${#missing_deps[@]} -ne 0 ]; then
    echo -e "${RED}ERROR: Missing required dependencies: ${missing_deps[*]}${NC}" >&2
    echo "Please install missing dependencies and try again." >&2
    exit 1
  fi
}

# Logging function
log() {
  if [ "${VERBOSE:-0}" = "1" ]; then
    echo "[TEST] $*" >&2
  fi
}

# Error logging
error() {
  echo -e "${RED}$*${NC}" >&2
}

# Success logging
success() {
  echo -e "${GREEN}$*${NC}" >&2
}

# Warning logging
warning() {
  echo -e "${YELLOW}$*${NC}" >&2
}

# ===== ASSERTION FUNCTIONS =====

# Assert two values are equal
assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="${3:-Assertion failed}"

  log "assert_equals: expected='$expected', actual='$actual'"

  if [ "$expected" = "$actual" ]; then
    return 0
  else
    error "  $message"
    error "  Expected: $expected"
    error "  Actual:   $actual"
    return 1
  fi
}

# Assert JSON documents are equal (deep comparison)
assert_json_equals() {
  local expected_json="$1"
  local actual_json="$2"
  local message="${3:-JSON documents not equal}"

  log "assert_json_equals: comparing JSON documents"

  # Normalize JSON (sort keys, compact format)
  local expected_normalized
  local actual_normalized

  expected_normalized=$(echo "$expected_json" | jq -S -c '.')
  actual_normalized=$(echo "$actual_json" | jq -S -c '.')

  if [ "$expected_normalized" = "$actual_normalized" ]; then
    return 0
  else
    error "  $message"
    error "  Expected: $expected_normalized"
    error "  Actual:   $actual_normalized"
    return 1
  fi
}

# Assert a specific field in JSON has expected value
assert_json_field() {
  local json="$1"
  local field_path="$2"
  local expected_value="$3"
  local message="${4:-JSON field assertion failed}"

  log "assert_json_field: path='$field_path', expected='$expected_value'"

  # Extract field value using jq
  local actual_value
  if ! actual_value=$(echo "$json" | jq -r "$field_path"); then
    error "  $message"
    error "  Failed to extract field: $field_path"
    return 1
  fi

  if [ "$actual_value" = "$expected_value" ]; then
    return 0
  else
    error "  $message"
    error "  Field: $field_path"
    error "  Expected: $expected_value"
    error "  Actual:   $actual_value"
    return 1
  fi
}

# Assert JSON indicates success
assert_success() {
  local json="$1"
  local message="${2:-Expected success=true}"

  log "assert_success: checking JSON success field"

  assert_json_field "$json" ".success" "true" "$message"
}

# Assert JSON indicates failure
assert_failure() {
  local json="$1"
  local expected_error_type="${2:-}"
  local message="${3:-Expected success=false}"

  log "assert_failure: checking JSON failure field"

  if ! assert_json_field "$json" ".success" "false" "$message"; then
    return 1
  fi

  # Optionally verify error_type
  if [ -n "$expected_error_type" ]; then
    assert_json_field "$json" ".error_type" "$expected_error_type" "Expected error_type=$expected_error_type"
  fi
}

# ===== MOCK REPOSITORY SETUP =====

# Create a temporary mock git repository
setup_mock_repo() {
  local repo_type="${1:-origin}"  # "origin" | "fork" | "empty"

  log "setup_mock_repo: type=$repo_type"

  # Create temp directory
  local temp_dir
  temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/git-workflows-test.XXXXXX")
  TEMP_DIRS+=("$temp_dir")

  cd "$temp_dir"

  # Initialize git repo
  git init -q
  git config user.name "Test User"
  git config user.email "test@example.com"

  # Create initial commit
  echo "# Test Repository" > README.md
  git add README.md
  git commit -q -m "Initial commit"

  # Configure remotes based on type
  case "$repo_type" in
    origin)
      git remote add origin "https://github.com/testuser/testrepo.git"
      ;;
    fork)
      git remote add origin "https://github.com/testuser/testrepo.git"
      git remote add upstream "https://github.com/upstream/testrepo.git"
      ;;
    empty)
      # No remotes
      ;;
    *)
      error "Unknown repo_type: $repo_type"
      return 1
      ;;
  esac

  log "Mock repo created at: $temp_dir"
  echo "$temp_dir"
}

# Create mock commits in current repository
setup_mock_commits() {
  local commit_style="${1:-standard}"  # "conventional" | "standard"
  local count="${2:-5}"

  log "setup_mock_commits: style=$commit_style, count=$count"

  local messages=()

  if [ "$commit_style" = "conventional" ]; then
    messages=(
      "feat: add new feature"
      "fix: resolve bug in parser"
      "docs: update README"
      "test: add unit tests"
      "refactor: improve code structure"
      "chore: update dependencies"
      "style: fix formatting"
      "perf: optimize algorithm"
    )
  else
    messages=(
      "Add new feature"
      "Fix bug in parser"
      "Update documentation"
      "Add tests"
      "Refactor code"
      "Update dependencies"
      "Fix formatting"
      "Optimize performance"
    )
  fi

  for i in $(seq 1 "$count"); do
    local idx=$((i % ${#messages[@]}))
    local msg="${messages[$idx]}"

    # Make a change
    echo "Change $i" >> "test-file-$i.txt"
    git add "test-file-$i.txt"
    git commit -q -m "$msg"
  done

  log "Created $count commits with $commit_style style"
}

# Create mock file changes in working tree
setup_mock_changes() {
  local change_type="${1:-mixed}"  # "staged" | "unstaged" | "untracked" | "mixed"

  log "setup_mock_changes: type=$change_type"

  case "$change_type" in
    staged)
      echo "Staged change" > staged.txt
      git add staged.txt
      ;;
    unstaged)
      echo "Unstaged change" > tracked.txt
      git add tracked.txt
      git commit -q -m "Add tracked file"
      echo "Modified" > tracked.txt
      ;;
    untracked)
      echo "Untracked" > untracked.txt
      ;;
    mixed)
      # Unstaged (create and commit first, then modify)
      echo "Tracked" > tracked.txt
      git add tracked.txt
      git commit -q -m "Add tracked file"
      echo "Modified" > tracked.txt

      # Staged (create after commit so it doesn't get committed)
      echo "Staged change" > staged.txt
      git add staged.txt

      # Untracked
      echo "Untracked" > untracked.txt
      ;;
    clean)
      # No changes
      ;;
    *)
      error "Unknown change_type: $change_type"
      return 1
      ;;
  esac
}

# Cleanup mock repository
cleanup_mock_repo() {
  log "cleanup_mock_repo: cleaning up temp directories"

  if [ ${#TEMP_DIRS[@]} -gt 0 ]; then
    for dir in "${TEMP_DIRS[@]}"; do
      if [ -d "$dir" ]; then
        log "Removing: $dir"
        rm -rf "$dir"
      fi
    done
  fi

  TEMP_DIRS=()
}

# ===== TEST EXECUTION =====

# Run a test function
run_test() {
  local test_name="$1"
  local test_function="$2"

  log "Running test: $test_name"

  # Run test function and capture result
  if $test_function; then
    success "✓ $test_name"
    ((TESTS_PASSED++))
  else
    error "✗ $test_name"
    ((TESTS_FAILED++))
  fi

  # Cleanup after each test
  cleanup_mock_repo
}

# ===== REPORTING =====

# Print test summary
report_test_results() {
  local total=$((TESTS_PASSED + TESTS_FAILED))

  echo ""
  echo "========================================="
  echo "Test Summary"
  echo "========================================="
  echo -e "${GREEN}Passed: $TESTS_PASSED/$total${NC}"

  if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED/$total${NC}"
  else
    echo -e "${GREEN}Failed: $TESTS_FAILED/$total${NC}"
  fi

  if [ $total -gt 0 ]; then
    local success_rate=$((TESTS_PASSED * 100 / total))
    echo "Success Rate: $success_rate%"
  fi
  echo "========================================="

  # Machine-readable summary for test runner parsing
  echo "TEST_SUMMARY:passed=$TESTS_PASSED,failed=$TESTS_FAILED"

  # Return non-zero if any tests failed
  if [ $TESTS_FAILED -gt 0 ]; then
    return 1
  else
    return 0
  fi
}

# ===== MAIN EXECUTION =====

# If sourced, don't run anything
# If executed directly, check dependencies and provide help
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  check_dependencies

  cat <<EOF
git-workflows Test Framework

This script is meant to be sourced by individual test files.

Usage:
  source ./test-framework.sh

  test_my_feature() {
    # Test implementation
    assert_equals "expected" "actual"
  }

  run_test "My Feature" test_my_feature
  report_test_results

Available Functions:
  Assertions:
    - assert_equals expected actual [message]
    - assert_json_equals expected_json actual_json [message]
    - assert_json_field json field_path expected_value [message]
    - assert_success json [message]
    - assert_failure json [expected_error_type] [message]

  Mock Setup:
    - setup_mock_repo [origin|fork|empty]
    - setup_mock_commits [conventional|standard] [count]
    - setup_mock_changes [staged|unstaged|untracked|mixed|clean]
    - cleanup_mock_repo

  Test Execution:
    - run_test "Test Name" test_function
    - report_test_results

Environment Variables:
  VERBOSE=1  Enable verbose logging

EOF
fi
