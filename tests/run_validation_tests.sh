#!/bin/bash

# Validation tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== RUNNING VALIDATION TESTS ==="
echo "Testing validation functionality..."

# Input validation tests
echo "1. Testing input validation..."
bats unit/bash/input_validation.test.bats

# Date validation tests
echo "2. Testing date validation..."
bats unit/bash/date_validation.test.bats
bats unit/bash/date_validation_utc.test.bats

# XML validation tests
echo "3. Testing XML validation..."
bats unit/bash/xml_validation_functions.test.bats
bats unit/bash/xml_validation_enhanced.test.bats

# Extended validation tests
echo "4. Testing extended validation..."
bats unit/bash/extended_validation.test.bats

# Checksum validation tests
echo "5. Testing checksum validation..."
bats unit/bash/checksum_validation.test.bats

# Boundary validation tests
echo "6. Testing boundary validation..."
bats unit/bash/boundary_validation.test.bats

echo "=== VALIDATION TESTS COMPLETED ===" 