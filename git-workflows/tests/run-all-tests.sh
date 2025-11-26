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
      echo "✓ $(basename "$test_file") completed"
    else
      echo "✗ $(basename "$test_file") failed"
    fi
    # Parse machine-readable summary line (no sed - use awk instead)
    if summary=$(echo "$output" | grep "^TEST_SUMMARY:"); then
      passed=$(echo "$summary" | awk -F'[=,]' '{print $2}')
      failed=$(echo "$summary" | awk -F'[=,]' '{print $4}')
      total_passed=$((total_passed + passed))
      total_failed=$((total_failed + failed))
    fi
    echo ""
  fi
done

# Run integration tests
for test_file in "$SCRIPT_DIR"/integration/test-*.sh; do
  if [ -f "$test_file" ]; then
    echo "Running $(basename "$test_file")..."
    if output=$("$test_file" 2>&1); then
      echo "✓ $(basename "$test_file") completed"
    else
      echo "✗ $(basename "$test_file") failed"
    fi
    # Parse machine-readable summary line (no sed - use awk instead)
    if summary=$(echo "$output" | grep "^TEST_SUMMARY:"); then
      passed=$(echo "$summary" | awk -F'[=,]' '{print $2}')
      failed=$(echo "$summary" | awk -F'[=,]' '{print $4}')
      total_passed=$((total_passed + passed))
      total_failed=$((total_failed + failed))
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
