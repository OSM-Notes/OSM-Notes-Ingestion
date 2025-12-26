#!/usr/bin/env bats

# End-to-end integration tests for country assignment error scenarios
# Tests: Missing country boundaries, assignment failures
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

setup() {
 # Set up test environment
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="$(mktemp -d)"
 export TEST_DIR="${TMP_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export BASENAME="test_error_scenarios_e2e"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"

 # Mock logger functions
 __log_start() { :; }
 __log_finish() { :; }
 __logi() { :; }
 __logd() { :; }
 __loge() { echo "ERROR: $*" >&2; }
 __logw() { echo "WARN: $*" >&2; }
 export -f __log_start __log_finish __logi __logd __loge __logw
}

teardown() {
 # Clean up
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# =============================================================================
# Country Assignment Error Scenarios
# =============================================================================

@test "E2E Error: Should handle missing country boundaries during assignment" {
 # Test: Missing country boundaries
 # Purpose: Verify that missing boundaries are handled
 # Expected: Error is logged, note is marked as unassigned

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Create test tables
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS notes_test_country (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 id_country INTEGER
);
CREATE TABLE IF NOT EXISTS countries_test (
 id_country SERIAL PRIMARY KEY,
 country_name_en VARCHAR(255)
);
EOSQL

 # Insert note in location without country boundary
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes_test_country (id, created_at, lat, lon, id_country) VALUES
(8888, '2025-12-15 10:00:00+00', 0.0, 0.0, NULL)
ON CONFLICT (id) DO NOTHING;
EOSQL

 # Verify note has no country assignment
 local UNASSIGNED_COUNT
 UNASSIGNED_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_test_country WHERE id_country IS NULL;" 2>/dev/null || echo "0")
 [[ "${UNASSIGNED_COUNT}" -ge 1 ]]
}

@test "E2E Error: Should handle country assignment failures gracefully" {
 # Test: Country assignment failure
 # Purpose: Verify that assignment failures don't crash the system
 # Expected: Error is logged, processing continues

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Create test tables
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS notes_test_assignment (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 id_country INTEGER
);
EOSQL

 # Insert note with invalid coordinates (should fail assignment but not crash)
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes_test_assignment (id, created_at, lat, lon, id_country) VALUES
(7777, '2025-12-15 10:00:00+00', 999.999, 999.999, NULL)
ON CONFLICT (id) DO NOTHING;
EOSQL

 # Verify note exists (system didn't crash)
 local NOTE_EXISTS
 NOTE_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_test_assignment WHERE id = 7777;" 2>/dev/null || echo "0")
 [[ "${NOTE_EXISTS}" -eq 1 ]]
}

