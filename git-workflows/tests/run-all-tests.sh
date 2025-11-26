#!/bin/bash
# Run all tests (unit and integration)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Running All git-workflows Tests"
echo "========================================"
echo ""

total_passed=0
total_failed=0

# Run each test file
for test_file in "$SCRIPT_DIR"/unit/test-*.sh; do
  if [ -f "$test_file" ]; then
    echo "Running $(basename "$test_file")..."
    if output=$("$test_file" 2>&1); then
      # Strip ANSI escape codes before parsing
      clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
      # Extract pass/fail counts from output
      if passed=$(echo "$clean_output" | grep "^Passed:" | awk '{print $2}' | cut -d'/' -f1); then
        if failed=$(echo "$clean_output" | grep "^Failed:" | awk '{print $2}' | cut -d'/' -f1); then
          total_passed=$((total_passed + passed))
          total_failed=$((total_failed + failed))
        fi
      fi
      echo "✓ $(basename "$test_file") completed"
    else
      echo "✗ $(basename "$test_file") failed"
      # Strip ANSI escape codes before parsing
      clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
      # Still try to extract counts
      if passed=$(echo "$clean_output" | grep "^Passed:" | awk '{print $2}' | cut -d'/' -f1 2>/dev/null); then
        if failed=$(echo "$clean_output" | grep "^Failed:" | awk '{print $2}' | cut -d'/' -f1 2>/dev/null); then
          total_passed=$((total_passed + passed))
          total_failed=$((total_failed + failed))
        fi
      fi
    fi
    echo ""
  fi
done

# Run integration tests
for test_file in "$SCRIPT_DIR"/integration/test-*.sh; do
  if [ -f "$test_file" ]; then
    echo "Running $(basename "$test_file")..."
    if output=$("$test_file" 2>&1); then
      # Strip ANSI escape codes before parsing
      clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
      # Extract pass/fail counts from output
      if passed=$(echo "$clean_output" | grep "^Passed:" | awk '{print $2}' | cut -d'/' -f1); then
        if failed=$(echo "$clean_output" | grep "^Failed:" | awk '{print $2}' | cut -d'/' -f1); then
          total_passed=$((total_passed + passed))
          total_failed=$((total_failed + failed))
        fi
      fi
      echo "✓ $(basename "$test_file") completed"
    else
      echo "✗ $(basename "$test_file") failed"
      # Strip ANSI escape codes before parsing
      clean_output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')
      # Still try to extract counts
      if passed=$(echo "$clean_output" | grep "^Passed:" | awk '{print $2}' | cut -d'/' -f1 2>/dev/null); then
        if failed=$(echo "$clean_output" | grep "^Failed:" | awk '{print $2}' | cut -d'/' -f1 2>/dev/null); then
          total_passed=$((total_passed + passed))
          total_failed=$((total_failed + failed))
        fi
      fi
    fi
    echo ""
  fi
done

# Print summary
echo "========================================"
echo "Overall Test Summary"
echo "========================================"
echo "Total Passed: $total_passed"
echo "Total Failed: $total_failed"
total=$((total_passed + total_failed))
if [ $total -gt 0 ]; then
  success_rate=$((total_passed * 100 / total))
  echo "Success Rate: $success_rate%"
fi
echo "========================================"

# Exit with failure if any tests failed
if [ $total_failed -gt 0 ]; then
  exit 1
fi

exit 0
