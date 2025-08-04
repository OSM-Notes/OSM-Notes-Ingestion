#!/bin/bash

# Quick error handling tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-04

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== RUNNING QUICK ERROR HANDLING TESTS ==="
echo "Testing error handling functionality (quick version)..."

# Basic error handling tests (fast)
echo "1. Testing basic error handling..."
bats tests/unit/bash/error_handling.test.bats
bats tests/unit/bash/error_handling_simple.test.bats

# Enhanced error handling tests (fast)
echo "2. Testing enhanced error handling..."
bats tests/unit/bash/error_handling_enhanced.test.bats

# Process error handling tests (fast)
echo "3. Testing process error handling..."
bats tests/unit/bash/processAPINotes_error_handling_improved.test.bats

# Edge cases tests (fast)
echo "4. Testing edge cases..."
bats tests/unit/bash/edge_cases_integration.test.bats

# Quick performance tests (fast)
echo "5. Testing quick performance edge cases..."
bats tests/unit/bash/performance_edge_cases_quick.test.bats

echo "=== QUICK ERROR HANDLING TESTS COMPLETED ==="
echo "Note: Full performance tests skipped for speed. Run run_error_handling_tests.sh for full suite." 