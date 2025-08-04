#!/bin/bash

# XML and XSLT tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== RUNNING XML AND XSLT TESTS ==="
echo "Testing XML and XSLT functionality..."

# XML processing tests
echo "1. Testing XML processing..."
bats tests/unit/bash/xml_processing_enhanced.test.bats

# XML validation tests
echo "2. Testing XML validation..."
bats tests/unit/bash/xml_validation_functions.test.bats
bats tests/unit/bash/xml_validation_enhanced.test.bats
bats tests/unit/bash/xml_validation_large_files.test.bats

# XSLT tests
echo "3. Testing XSLT functionality..."
bats tests/unit/bash/xslt_simple.test.bats
bats tests/unit/bash/xslt_csv_format.test.bats
bats tests/unit/bash/xslt_enum_validation.test.bats

# Large file validation tests
echo "4. Testing large file validation..."
bats tests/unit/bash/xml_validation_large_files.test.bats

echo "=== XML AND XSLT TESTS COMPLETED ===" 