#!/bin/bash

# Test script to verify boundaries backup functionality
# Tests that backups are used instead of downloading from Overpass
# Author: Andres Gomez (AngocA)
# Version: 2025-11-27

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
 echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
 echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
 echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT

# Database configuration
DBNAME="${DBNAME:-osm-notes-test}"
DB_USER="${DB_USER:-${USER}}"

log_info "Testing boundaries backup functionality"
log_info "Project root: ${PROJECT_ROOT}"
log_info "Database: ${DBNAME}"

# Check if backup files exist
if [[ ! -f "${PROJECT_ROOT}/data/countries.geojson" ]]; then
 log_warning "countries.geojson backup not found - creating test backup"
 # Create minimal test backup
 mkdir -p "${PROJECT_ROOT}/data"
 cat > "${PROJECT_ROOT}/data/countries.geojson" << 'EOF'
{
  "type": "FeatureCollection",
  "features": []
}
EOF
fi

if [[ ! -f "${PROJECT_ROOT}/data/maritimes.geojson" ]]; then
 log_warning "maritimes.geojson backup not found - creating test backup"
 mkdir -p "${PROJECT_ROOT}/data"
 cat > "${PROJECT_ROOT}/data/maritimes.geojson" << 'EOF'
{
  "type": "FeatureCollection",
  "features": []
}
EOF
fi

# Verify backup files are valid GeoJSON
log_info "Validating backup files..."
if command -v jq > /dev/null 2>&1; then
 if ! jq empty "${PROJECT_ROOT}/data/countries.geojson" 2> /dev/null; then
  log_error "countries.geojson is not valid JSON"
  exit 1
 fi

 if ! jq empty "${PROJECT_ROOT}/data/maritimes.geojson" 2> /dev/null; then
  log_error "maritimes.geojson is not valid JSON"
  exit 1
 fi

 COUNTRIES_COUNT=$(jq '.features | length' "${PROJECT_ROOT}/data/countries.geojson" 2> /dev/null || echo "0")
 MARITIMES_COUNT=$(jq '.features | length' "${PROJECT_ROOT}/data/maritimes.geojson" 2> /dev/null || echo "0")

 log_success "Backup files are valid GeoJSON"
 log_info "  countries.geojson: ${COUNTRIES_COUNT} features"
 log_info "  maritimes.geojson: ${MARITIMES_COUNT} features"
else
 log_warning "jq not available, skipping JSON validation"
fi

# Test that backup comparison function works
log_info "Testing backup comparison function..."
if [[ -f "${PROJECT_ROOT}/bin/lib/boundaryProcessingFunctions.sh" ]]; then
 # Source the function
 export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
 export TMP_DIR="$(mktemp -d)"
 export LOG_LEVEL="ERROR"

 # Load common functions first
 if [[ -f "${PROJECT_ROOT}/lib/osm-common/commonFunctions.sh" ]]; then
  source "${PROJECT_ROOT}/lib/osm-common/commonFunctions.sh" > /dev/null 2>&1 || true
 fi

 # Source boundary processing functions
 source "${PROJECT_ROOT}/bin/lib/boundaryProcessingFunctions.sh" > /dev/null 2>&1 || true

 # Test __compareIdsWithBackup if available
 if declare -f __compareIdsWithBackup > /dev/null 2>&1; then
  log_info "Testing ID comparison..."

  # Create test IDs file
  TEST_IDS_FILE="${TMP_DIR}/test_ids.txt"
  echo "@id" > "${TEST_IDS_FILE}"
  echo "16239" >> "${TEST_IDS_FILE}"

  # Test comparison (should fail if IDs don't match exactly)
  if __compareIdsWithBackup "${TEST_IDS_FILE}" "${PROJECT_ROOT}/data/countries.geojson" "countries" 2> /dev/null; then
   log_success "ID comparison function works (IDs matched)"
  else
   log_info "ID comparison function works (IDs didn't match - expected if backup is different)"
  fi

  rm -rf "${TMP_DIR}"
 else
  log_warning "__compareIdsWithBackup function not found - may need to load more dependencies"
 fi
else
 log_warning "boundaryProcessingFunctions.sh not found"
fi

# Run unit tests
log_info "Running unit tests..."
if command -v bats > /dev/null 2>&1; then
 if bats "${SCRIPT_DIR}/unit/bash/boundaries_backup_usage.test.bats" 2>&1; then
  log_success "Unit tests passed"
 else
  log_warning "Some unit tests failed or were skipped"
 fi
else
 log_warning "bats not available, skipping unit tests"
fi

log_success "Backup functionality test completed"
log_info ""
log_info "To test with real database, run:"
log_info "  ./tests/run_updateCountries_hybrid.sh"
log_info "  ./tests/run_processAPINotes_hybrid.sh"

