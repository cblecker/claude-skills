#!/bin/bash
# Unit tests for helper scripts (parse-git-status.sh, categorize-files.sh)

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_ROOT="$(dirname "$SCRIPT_DIR")"

# Source test framework
source "$TEST_ROOT/test-framework.sh"

# Path to scripts
PARSE_STATUS_SCRIPT="$TEST_ROOT/../scripts/parse-git-status.sh"
CATEGORIZE_FILES_SCRIPT="$TEST_ROOT/../scripts/categorize-files.sh"

# ===== TESTS FOR parse-git-status.sh =====

test_parse_status_clean() {
  local input=""
  local output
  output=$(echo "$input" | "$PARSE_STATUS_SCRIPT")

  assert_json_field "$output" ".is_clean" "true" "Clean working tree should have is_clean=true" || return 1
  assert_json_field "$output" ".staged | length" "0" "Clean working tree should have no staged files" || return 1
  assert_json_field "$output" ".unstaged | length" "0" "Clean working tree should have no unstaged files" || return 1
  assert_json_field "$output" ".untracked | length" "0" "Clean working tree should have no untracked files" || return 1
}

test_parse_status_staged_only() {
  local input="M  staged-file.txt
A  new-file.txt"

  local output
  output=$(echo "$input" | "$PARSE_STATUS_SCRIPT")

  assert_json_field "$output" ".is_clean" "false" "Staged files should make is_clean=false" || return 1
  assert_json_field "$output" ".staged | length" "2" "Should have 2 staged files" || return 1
  assert_json_field "$output" ".staged[0].status" "M" "First staged file should have status M" || return 1
  assert_json_field "$output" ".staged[0].path" "staged-file.txt" "First staged file path" || return 1
  assert_json_field "$output" ".staged[1].status" "A" "Second staged file should have status A" || return 1
  assert_json_field "$output" ".unstaged | length" "0" "Should have no unstaged files" || return 1
}

test_parse_status_unstaged_only() {
  local input=" M unstaged-file.txt
 D deleted-file.txt"

  local output
  output=$(echo "$input" | "$PARSE_STATUS_SCRIPT")

  assert_json_field "$output" ".is_clean" "false" "Unstaged files should make is_clean=false" || return 1
  assert_json_field "$output" ".staged | length" "0" "Should have no staged files" || return 1
  assert_json_field "$output" ".unstaged | length" "2" "Should have 2 unstaged files" || return 1
  assert_json_field "$output" ".unstaged[0].status" "M" "First unstaged file should have status M" || return 1
  assert_json_field "$output" ".unstaged[1].status" "D" "Second unstaged file should have status D" || return 1
}

test_parse_status_untracked_only() {
  local input="?? untracked-file.txt
?? another-untracked.log"

  local output
  output=$(echo "$input" | "$PARSE_STATUS_SCRIPT")

  assert_json_field "$output" ".is_clean" "false" "Untracked files should make is_clean=false" || return 1
  assert_json_field "$output" ".staged | length" "0" "Should have no staged files" || return 1
  assert_json_field "$output" ".unstaged | length" "0" "Should have no unstaged files" || return 1
  assert_json_field "$output" ".untracked | length" "2" "Should have 2 untracked files" || return 1
  assert_json_field "$output" ".untracked[0]" "untracked-file.txt" "First untracked file" || return 1
}

test_parse_status_mixed() {
  local input="M  staged-file.txt
 M unstaged-file.txt
MM both-modified.txt
?? untracked.log"

  local output
  output=$(echo "$input" | "$PARSE_STATUS_SCRIPT")

  assert_json_field "$output" ".is_clean" "false" "Mixed changes should make is_clean=false" || return 1
  assert_json_field "$output" ".staged | length" "2" "Should have 2 staged files (staged-file and both-modified)" || return 1
  assert_json_field "$output" ".unstaged | length" "2" "Should have 2 unstaged files (unstaged-file and both-modified)" || return 1
  assert_json_field "$output" ".untracked | length" "1" "Should have 1 untracked file" || return 1
}

test_parse_status_renamed() {
  local input="R  old-name.txt -> new-name.txt"

  local output
  output=$(echo "$input" | "$PARSE_STATUS_SCRIPT")

  assert_json_field "$output" ".staged | length" "1" "Renamed file should be staged" || return 1
  assert_json_field "$output" ".staged[0].status" "R" "Renamed file should have status R" || return 1
}

# ===== TESTS FOR categorize-files.sh =====

test_categorize_code_files() {
  local input="src/main.ts
src/utils.js
lib/parser.go
app.py"

  local output
  output=$(echo "$input" | "$CATEGORIZE_FILES_SCRIPT")

  assert_json_field "$output" ".code | length" "4" "Should categorize 4 code files" || return 1
  assert_json_field "$output" ".tests | length" "0" "Should have no test files" || return 1
  assert_json_field "$output" ".docs | length" "0" "Should have no doc files" || return 1
  assert_json_field "$output" ".config | length" "0" "Should have no config files" || return 1
}

test_categorize_test_files() {
  local input="src/utils.test.ts
src/parser_test.go
tests/integration.spec.js
__tests__/component.test.tsx"

  local output
  output=$(echo "$input" | "$CATEGORIZE_FILES_SCRIPT")

  assert_json_field "$output" ".tests | length" "4" "Should categorize 4 test files" || return 1
  assert_json_field "$output" ".code | length" "0" "Test files should not be in code category" || return 1
}

test_categorize_doc_files() {
  local input="README.md
CHANGELOG.md
LICENSE
docs/guide.rst
CONTRIBUTING.txt"

  local output
  output=$(echo "$input" | "$CATEGORIZE_FILES_SCRIPT")

  assert_json_field "$output" ".docs | length" "5" "Should categorize 5 doc files" || return 1
  assert_json_field "$output" ".code | length" "0" "Docs should not be in code category" || return 1
}

test_categorize_config_files() {
  local input="package.json
tsconfig.json
.eslintrc.json
config/settings.yaml
Dockerfile
Makefile
go.mod"

  local output
  output=$(echo "$input" | "$CATEGORIZE_FILES_SCRIPT")

  assert_json_field "$output" ".config | length" "7" "Should categorize 7 config files" || return 1
}

test_categorize_mixed_files() {
  local input="src/main.ts
src/main.test.ts
README.md
package.json
debug.log"

  local output
  output=$(echo "$input" | "$CATEGORIZE_FILES_SCRIPT")

  assert_json_field "$output" ".code | length" "1" "Should have 1 code file" || return 1
  assert_json_field "$output" ".tests | length" "1" "Should have 1 test file" || return 1
  assert_json_field "$output" ".docs | length" "1" "Should have 1 doc file" || return 1
  assert_json_field "$output" ".config | length" "1" "Should have 1 config file" || return 1
  assert_json_field "$output" ".other | length" "1" "Should have 1 other file (debug.log)" || return 1
}

test_categorize_test_directory() {
  local input="test/integration.js
tests/unit.py
spec/feature.rb"

  local output
  output=$(echo "$input" | "$CATEGORIZE_FILES_SCRIPT")

  assert_json_field "$output" ".tests | length" "3" "Files in test directories should be categorized as tests" || return 1
}

test_categorize_src_directory() {
  local input="src/component.tsx
lib/helper.go"

  local output
  output=$(echo "$input" | "$CATEGORIZE_FILES_SCRIPT")

  assert_json_field "$output" ".code | length" "2" "Files in src/lib directories should be categorized as code" || return 1
}

test_categorize_empty_input() {
  local input=""

  local output
  output=$(echo "$input" | "$CATEGORIZE_FILES_SCRIPT")

  assert_json_field "$output" ".code | length" "0" "Empty input should produce empty categories" || return 1
  assert_json_field "$output" ".tests | length" "0" || return 1
  assert_json_field "$output" ".docs | length" "0" || return 1
  assert_json_field "$output" ".config | length" "0" || return 1
  assert_json_field "$output" ".other | length" "0" || return 1
}

# ===== RUN ALL TESTS =====

echo "========================================"
echo "Running Helper Script Tests"
echo "========================================"
echo ""

echo "parse-git-status.sh Tests"
echo "-------------------------"
run_test "parse-git-status: Clean working tree" test_parse_status_clean
run_test "parse-git-status: Staged only" test_parse_status_staged_only
run_test "parse-git-status: Unstaged only" test_parse_status_unstaged_only
run_test "parse-git-status: Untracked only" test_parse_status_untracked_only
run_test "parse-git-status: Mixed changes" test_parse_status_mixed
run_test "parse-git-status: Renamed files" test_parse_status_renamed

echo ""
echo "categorize-files.sh Tests"
echo "-------------------------"
run_test "categorize-files: Code files" test_categorize_code_files
run_test "categorize-files: Test files" test_categorize_test_files
run_test "categorize-files: Doc files" test_categorize_doc_files
run_test "categorize-files: Config files" test_categorize_config_files
run_test "categorize-files: Mixed files" test_categorize_mixed_files
run_test "categorize-files: Test directories" test_categorize_test_directory
run_test "categorize-files: Src directories" test_categorize_src_directory
run_test "categorize-files: Empty input" test_categorize_empty_input

echo ""
report_test_results
