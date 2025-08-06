#!/bin/bash

# Core tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== RUNNING CORE TESTS ==="
echo "Testing basic functionality..."

# Change to tests directory for proper relative paths
cd "${TESTS_DIRECTORY}"

# Core function tests
echo "1. Testing core functions..."
bats unit/bash/functionsProcess.test.bats

# Basic validation tests
echo "2. Testing basic validation..."
bats unit/bash/error_handling.test.bats

# XSLT tests (our recent improvements)
echo "3. Testing XSLT improvements..."
bats unit/bash/xslt_enum_validation.test.bats
bats unit/bash/xslt_csv_format.test.bats

# Parallel processing tests (our recent improvements)
echo "4. Testing parallel processing improvements..."
bats unit/bash/parallel_failed_file.test.bats

# Basic XML validation
echo "5. Testing XML validation..."
bats unit/bash/xml_validation_simple.test.bats

echo "=== CORE TESTS COMPLETED ===" 