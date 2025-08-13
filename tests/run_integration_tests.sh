#!/bin/bash

# Integration tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to show usage
show_usage() {
 echo "Usage: $0 [OPTIONS]"
 echo ""
 echo "Options:"
 echo "  --all              Run all integration tests"
 echo "  --process-api      Run only process API tests"
 echo "  --process-planet   Run only process Planet tests"
 echo "  --cleanup          Run only cleanup tests"
 echo "  --wms              Run only WMS tests"
 echo "  --etl              Run only ETL tests"
 echo "  --help, -h         Show this help message"
 echo ""
 echo "If no options are provided, runs all tests"
}

# Parse command line arguments
RUN_ALL=false
RUN_PROCESS_API=false
RUN_PROCESS_PLANET=false
RUN_CLEANUP=false
RUN_WMS=false
RUN_ETL=false

while [[ $# -gt 0 ]]; do
 case $1 in
 --all)
  RUN_ALL=true
  shift
  ;;
 --process-api)
  RUN_PROCESS_API=true
  shift
  ;;
 --process-planet)
  RUN_PROCESS_PLANET=true
  shift
  ;;
 --cleanup)
  RUN_CLEANUP=true
  shift
  ;;
 --wms)
  RUN_WMS=true
  shift
  ;;
 --etl)
  RUN_ETL=true
  shift
  ;;
 --help | -h)
  show_usage
  exit 0
  ;;
 *)
  echo "Unknown option: $1"
  show_usage
  exit 1
  ;;
 esac
done

# If no specific options, run all
if [[ "$RUN_ALL" == "false" && "$RUN_PROCESS_API" == "false" && "$RUN_PROCESS_PLANET" == "false" && "$RUN_CLEANUP" == "false" && "$RUN_WMS" == "false" && "$RUN_ETL" == "false" ]]; then
 RUN_ALL=true
fi

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
if [[ "$RUN_ALL" == "true" || "$RUN_PROCESS_API" == "true" ]]; then
 echo "1. Testing process API integration..."
 run_test_file "unit/bash/processAPINotes_integration.test.bats" "processAPINotes integration tests"
fi

if [[ "$RUN_ALL" == "true" || "$RUN_PROCESS_PLANET" == "true" ]]; then
 echo "2. Testing process Planet integration..."
 # Use the corrected version that works in CI
 if [[ -f "unit/bash/processPlanetNotes_integration_fixed.test.bats" ]]; then
  run_test_file "unit/bash/processPlanetNotes_integration_fixed.test.bats" "processPlanetNotes integration tests (fixed)"
 else
  echo "ℹ️  processPlanetNotes_integration_fixed.test.bats not found, using original (may fail in CI)"
  run_test_file "unit/bash/processPlanetNotes_integration.test.bats" "processPlanetNotes integration tests"
 fi
fi

# ETL integration tests
if [[ "$RUN_ALL" == "true" || "$RUN_ETL" == "true" ]]; then
 echo "3. Testing ETL integration..."
 run_test_file "unit/bash/ETL_integration.test.bats" "ETL integration tests"
fi

# Datamart integration tests
if [[ "$RUN_ALL" == "true" ]]; then
 echo "4. Testing datamart integration..."
 run_test_file "unit/bash/datamartCountries_integration.test.bats" "datamartCountries integration tests"
 run_test_file "unit/bash/datamartUsers_integration.test.bats" "datamartUsers integration tests"
fi

# WMS integration tests
if [[ "$RUN_ALL" == "true" || "$RUN_WMS" == "true" ]]; then
 echo "5. Testing WMS integration..."
 run_test_file "unit/bash/wmsManager_integration.test.bats" "wmsManager integration tests"
 run_test_file "unit/bash/wmsConfigExample_integration.test.bats" "wmsConfigExample integration tests"
 run_test_file "unit/bash/geoserverConfig_integration.test.bats" "geoserverConfig integration tests"
fi

# Cleanup integration tests
if [[ "$RUN_ALL" == "true" || "$RUN_CLEANUP" == "true" ]]; then
 echo "6. Testing cleanup integration..."
 run_test_file "unit/bash/cleanupAll_integration.test.bats" "cleanupAll integration tests"
fi

echo "=== INTEGRATION TESTS COMPLETED ==="
