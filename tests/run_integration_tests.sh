#!/bin/bash

# Integration tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== RUNNING INTEGRATION TESTS ==="
echo "Testing integration functionality..."

# Process integration tests
echo "1. Testing process integration..."
bats tests/unit/bash/processAPINotes_integration.test.bats
bats tests/unit/bash/processPlanetNotes_integration.test.bats

# ETL integration tests
echo "2. Testing ETL integration..."
bats tests/unit/bash/ETL_integration.test.bats

# Datamart integration tests
echo "3. Testing datamart integration..."
bats tests/unit/bash/datamartCountries_integration.test.bats
bats tests/unit/bash/datamartUsers_integration.test.bats

# WMS integration tests
echo "4. Testing WMS integration..."
bats tests/unit/bash/wmsManager_integration.test.bats
bats tests/unit/bash/wmsConfigExample_integration.test.bats
bats tests/unit/bash/geoserverConfig_integration.test.bats

# Cleanup integration tests
echo "5. Testing cleanup integration..."
bats tests/unit/bash/cleanupAll_integration.test.bats
echo "5. Testing cleanup integration..."
bats tests/unit/bash/cleanupAll_integration.test.bats

echo "=== INTEGRATION TESTS COMPLETED ===" 