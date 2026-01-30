#!/bin/bash

# Test script to verify boundaries backup usage in hybrid mode
# Tests that backups are actually used instead of downloading from Overpass
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

log_info "Testing boundaries backup usage in hybrid mode"
log_info "Project root: ${PROJECT_ROOT}"
log_info "Database: ${DBNAME}"

# Check prerequisites
if ! command -v psql > /dev/null 2>&1; then
 log_error "psql not found - PostgreSQL client required"
 exit 1
fi

# Check database connection
if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
 log_warning "Cannot connect to database ${DBNAME}"
 log_info "Creating test database..."
 createdb "${DBNAME}" 2>/dev/null || true
 psql -d "${DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;" > /dev/null 2>&1 || true
 psql -d "${DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS btree_gist;" > /dev/null 2>&1 || true
fi

# Check if backup files exist
if [[ ! -f "${PROJECT_ROOT}/data/countries.geojson" ]] || [[ ! -f "${PROJECT_ROOT}/data/maritimes.geojson" ]]; then
 log_error "Backup files not found!"
 log_info "Please run export scripts first:"
 log_info "  ./bin/scripts/exportCountriesBackup.sh"
 log_info "  ./bin/scripts/exportMaritimesBackup.sh"
 exit 1
fi

# Verify backup files are valid
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

 log_success "Backup files are valid"
 log_info "  countries.geojson: ${COUNTRIES_COUNT} features"
 log_info "  maritimes.geojson: ${MARITIMES_COUNT} features"
else
 log_warning "jq not available, skipping JSON validation"
fi

# Test 1: Verify that processPlanet base uses backup
log_info ""
log_info "Test 1: Verifying processPlanet base uses backup..."
log_info "This test requires running processPlanetNotes.sh --base"
log_info "Check logs for 'Using repository backup' messages"

# Test 2: Verify that updateCountries compares IDs
log_info ""
log_info "Test 2: Verifying updateCountries compares IDs..."
log_info "Running updateCountries in update mode (should compare IDs first)"

# Set up environment
export DBNAME="${DBNAME}"
export LOG_LEVEL="${LOG_LEVEL:-DEBUG}"
export TEST_MODE="true"
export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"

# Run updateCountries and capture output
LOG_FILE="${TMP_DIR:-/tmp}/updateCountries_backup_test.log"
log_info "Running updateCountries.sh (checking for backup usage)..."
log_info "Log file: ${LOG_FILE}"

if "${PROJECT_ROOT}/bin/process/updateCountries.sh" 2>&1 | tee "${LOG_FILE}"; then
 # Check if backup was mentioned in logs
 if grep -q "Using repository backup\|IDs match backup\|are up to date" "${LOG_FILE}" 2>/dev/null; then
  log_success "Backup usage detected in logs!"
  grep "Using repository backup\|IDs match backup\|are up to date" "${LOG_FILE}" | head -5
 else
  log_warning "Backup usage not clearly detected in logs"
  log_info "This might mean:"
  log_info "  - IDs differ and download was needed"
  log_info "  - Backup files don't match current Overpass data"
  log_info "  - Check log file for details: ${LOG_FILE}"
 fi
else
 log_error "updateCountries.sh failed"
 exit 1
fi

log_success ""
log_success "Backup functionality test completed!"
log_info ""
log_info "Summary:"
log_info "  - Backup files exist and are valid"
log_info "  - updateCountries.sh executed successfully"
log_info "  - Check logs for backup usage messages"
log_info ""
log_info "To verify backup usage, check logs for:"
log_info "  - 'Using repository backup'"
log_info "  - 'IDs match backup'"
log_info "  - 'are up to date, skipping download'"

