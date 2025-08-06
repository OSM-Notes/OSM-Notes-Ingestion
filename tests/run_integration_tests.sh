#!/bin/bash

# Integration tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== RUNNING INTEGRATION TESTS ==="
echo "Testing integration functionality..."

# Change to tests directory for proper relative paths
cd "${TESTS_DIRECTORY}"

# Process integration tests
echo "1. Testing process integration..."
bats unit/bash/processAPINotes_integration.test.bats
bats unit/bash/processPlanetNotes_integration.test.bats

# ETL integration tests
echo "2. Testing ETL integration..."
bats unit/bash/ETL_integration.test.bats

# Datamart integration tests
echo "3. Testing datamart integration..."
bats unit/bash/datamartCountries_integration.test.bats
bats unit/bash/datamartUsers_integration.test.bats

# WMS integration tests
echo "4. Testing WMS integration..."
bats unit/bash/wmsManager_integration.test.bats
bats unit/bash/wmsConfigExample_integration.test.bats
bats unit/bash/geoserverConfig_integration.test.bats

# Cleanup integration tests
echo "5. Testing cleanup integration..."
bats unit/bash/cleanupAll_integration.test.bats

echo "=== INTEGRATION TESTS COMPLETED ===" 