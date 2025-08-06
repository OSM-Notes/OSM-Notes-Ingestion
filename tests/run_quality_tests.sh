#!/bin/bash

# Quality tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== RUNNING QUALITY TESTS ==="
echo "Testing code quality..."

# Format and lint tests
echo "1. Testing code formatting and linting..."
bats unit/bash/format_and_lint.test.bats

# Function naming convention tests
echo "2. Testing function naming conventions..."
bats unit/bash/function_naming_convention.test.bats

# Variable naming convention tests
echo "3. Testing variable naming conventions..."
bats unit/bash/variable_naming_convention.test.bats

# Variable duplication tests
echo "4. Testing variable duplication detection..."
bats unit/bash/variable_duplication.test.bats
bats unit/bash/variable_duplication_detection.test.bats

# Script help validation tests
echo "5. Testing script help validation..."
bats unit/bash/script_help_validation.test.bats

# SQL validation tests
echo "6. Testing SQL validation..."
bats unit/bash/sql_validation_integration.test.bats
bats unit/bash/sql_constraints_validation.test.bats

echo "=== QUALITY TESTS COMPLETED ===" 