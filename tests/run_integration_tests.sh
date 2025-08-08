#!/bin/bash

# Integration tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-07

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== RUNNING INTEGRATION TESTS ==="
echo "Testing integration functionality..."

# Change to tests directory for proper relative paths
cd "${TESTS_DIRECTORY}"

# Helper function to run tests safely
run_test_file() {
    local test_file="$1"
    local test_name="$2"
    
    if [[ -f "${test_file}" ]]; then
        echo "Running ${test_name}..."
        if bats "${test_file}"; then
            echo "✅ ${test_name} passed"
        else
            echo "❌ ${test_name} failed"
            return 1
        fi
    else
        echo "ℹ️  ${test_name} not found, skipping: ${test_file}"
    fi
}

# Process integration tests
echo "1. Testing process integration..."
run_test_file "unit/bash/processAPINotes_integration.test.bats" "processAPINotes integration tests"
run_test_file "unit/bash/processPlanetNotes_integration.test.bats" "processPlanetNotes integration tests"

# ETL integration tests
echo "2. Testing ETL integration..."
run_test_file "unit/bash/ETL_integration.test.bats" "ETL integration tests"

# Datamart integration tests
echo "3. Testing datamart integration..."
run_test_file "unit/bash/datamartCountries_integration.test.bats" "datamartCountries integration tests"
run_test_file "unit/bash/datamartUsers_integration.test.bats" "datamartUsers integration tests"

# WMS integration tests
echo "4. Testing WMS integration..."
run_test_file "unit/bash/wmsManager_integration.test.bats" "wmsManager integration tests"
run_test_file "unit/bash/wmsConfigExample_integration.test.bats" "wmsConfigExample integration tests"
run_test_file "unit/bash/geoserverConfig_integration.test.bats" "geoserverConfig integration tests"

# Cleanup integration tests
echo "5. Testing cleanup integration..."
run_test_file "unit/bash/cleanupAll_integration.test.bats" "cleanupAll integration tests"

echo "=== INTEGRATION TESTS COMPLETED ==="