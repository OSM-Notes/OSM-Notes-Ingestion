#!/bin/bash

# Error handling tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== RUNNING ERROR HANDLING TESTS ==="
echo "Testing error handling functionality..."

# Change to tests directory for proper relative paths
cd "${TESTS_DIRECTORY}"

# Basic error handling tests
echo "1. Testing basic error handling..."
bats unit/bash/error_handling.test.bats
bats unit/bash/error_handling_simple.test.bats

# Enhanced error handling tests
echo "2. Testing enhanced error handling..."
bats unit/bash/error_handling_enhanced.test.bats

# Process error handling tests
echo "3. Testing process error handling..."
bats unit/bash/processAPINotes_error_handling_improved.test.bats
bats unit/bash/processAPINotes_parallel_error.test.bats

# Edge cases tests
echo "4. Testing edge cases..."
bats unit/bash/edge_cases_integration.test.bats

# Performance edge cases
echo "5. Testing performance edge cases..."
bats unit/bash/performance_edge_cases.test.bats

echo "=== ERROR HANDLING TESTS COMPLETED ===" 