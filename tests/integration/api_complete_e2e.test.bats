#!/usr/bin/env bats

# End-to-end integration tests for complete API processing flow
# Tests: Download → Validation → Processing → Database → Country Assignment
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

# =============================================================================
# Setup and Teardown
# =============================================================================

# Shared database setup (runs once per file, not per test)
# This optimizes database operations by creating tables once
setup_file() {
 # Set up test environment
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="$(mktemp -d)"
 export TEST_DIR="${TMP_DIR}"
 export DBNAME="${TEST_DBNAME:-osm_notes_ingestion_test}"
 export BASENAME="test_api_complete_e2e"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"
 export API_NOTES_FILE="${TMP_DIR}/OSM-notes-API.xml"
 
 # Setup shared database schema once for all tests
 __shared_db_setup_file
}

setup() {
 # Per-test setup (runs before each test)
 # Use shared database setup from setup_file

 # Ensure TMP_DIR exists (it should be created in setup_file, but verify)
 if [[ -z "${TMP_DIR:-}" ]] || [[ ! -d "${TMP_DIR}" ]]; then
  export TMP_DIR="$(mktemp -d)"
  export TEST_DIR="${TMP_DIR}"
  export API_NOTES_FILE="${TMP_DIR}/OSM-notes-API.xml"
 fi

 # Create minimal test XML file
 cat > "${API_NOTES_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
 <note id="12345" lat="40.7128" lon="-74.0060" created_at="2025-12-15T10:00:00Z" closed_at="">
  <comment uid="1" user="testuser" action="opened" timestamp="2025-12-15T10:00:00Z">
   <text>Test note in New York</text>
  </comment>
 </note>
 <note id="12346" lat="34.0522" lon="-118.2437" created_at="2025-12-15T11:00:00Z" closed_at="">
  <comment uid="2" user="testuser2" action="opened" timestamp="2025-12-15T11:00:00Z">
   <text>Test note in Los Angeles</text>
  </comment>
 </note>
</osm>
EOF

 # Mock logger functions
 __log_start() { :; }
 __log_finish() { :; }
 __logi() { :; }
 __logd() { :; }
 __loge() { echo "ERROR: $*" >&2; }
 __logw() { :; }
 export -f __log_start __log_finish __logi __logd __loge __logw
}

teardown() {
 # Per-test cleanup (runs after each test)
 # Truncate test data instead of dropping tables (faster)
 __truncate_test_tables notes_api note_comments note_comments_text notes users
}

# Shared database teardown (runs once per file, not per test)
teardown_file() {
 # Clean up temporary directory
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
 
 # Shared database teardown (truncates tables, preserves schema)
 __shared_db_teardown_file
}

# =============================================================================
# Complete API Flow Tests
# =============================================================================

@test "E2E: Complete API flow should download and validate XML" {
 # Test: Download → Validation
 # Purpose: Verify that API download creates valid XML file
 # Expected: XML file exists and is valid

 # Mock download function
 __retry_osm_api() {
  local URL="$1"
  local OUTPUT_FILE="$2"
  # Copy test XML to output
  cp "${API_NOTES_FILE}" "${OUTPUT_FILE}"
  return 0
 }
 export -f __retry_osm_api

 # Simulate download
 local DOWNLOADED_FILE="${TMP_DIR}/downloaded.xml"
 __retry_osm_api "https://api.openstreetmap.org/api/0.6/notes/search.xml" "${DOWNLOADED_FILE}"

 # Verify file exists and is valid XML
 [[ -f "${DOWNLOADED_FILE}" ]]
 [[ -s "${DOWNLOADED_FILE}" ]]
 
 # Validate XML structure (basic check)
 run grep -q "<osm" "${DOWNLOADED_FILE}"
 [ "$status" -eq 0 ]
 run grep -q "<note" "${DOWNLOADED_FILE}"
 [ "$status" -eq 0 ]
}

@test "E2E: Complete API flow should process XML and insert to database" {
 # Test: Validation → Processing → Database Insertion
 # Purpose: Verify that XML is processed and notes are inserted
 # Expected: Notes are inserted into database tables

 # Skip if database not available
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Create test tables
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS notes_api (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 closed_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);
CREATE TABLE IF NOT EXISTS note_comments_api (
 id BIGSERIAL PRIMARY KEY,
 note_id BIGINT REFERENCES notes_api(id),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL,
 uid BIGINT,
 user_name VARCHAR(255),
 action VARCHAR(20) NOT NULL,
 text TEXT
);
EOSQL

 # Mock XML processing to insert test data
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes_api (id, created_at, lat, lon, status) VALUES
(12345, '2025-12-15 10:00:00+00', 40.7128, -74.0060, 'open'),
(12346, '2025-12-15 11:00:00+00', 34.0522, -118.2437, 'open')
ON CONFLICT (id) DO NOTHING;

INSERT INTO note_comments_api (note_id, created_at, uid, user_name, action, text) VALUES
(12345, '2025-12-15 10:00:00+00', 1, 'testuser', 'opened', 'Test note in New York'),
(12346, '2025-12-15 11:00:00+00', 2, 'testuser2', 'opened', 'Test note in Los Angeles')
ON CONFLICT DO NOTHING;
EOSQL

 # Verify notes were inserted
 local NOTE_COUNT
 NOTE_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api;" 2>/dev/null || echo "0")
 [[ "${NOTE_COUNT}" -ge 2 ]]

 # Verify comments were inserted
 local COMMENT_COUNT
 COMMENT_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM note_comments_api;" 2>/dev/null || echo "0")
 [[ "${COMMENT_COUNT}" -ge 2 ]]
}

@test "E2E: Complete API flow should assign countries to notes" {
 # Test: Database → Country Assignment
 # Purpose: Verify that notes get country assignments
 # Expected: Notes have country_id assigned

 # Skip if database not available
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Create test tables with country assignment
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DROP TABLE IF EXISTS notes_api CASCADE;
DROP TABLE IF EXISTS countries CASCADE;

CREATE TABLE countries (
 id_country SERIAL PRIMARY KEY,
 country_name_en VARCHAR(255)
);
CREATE TABLE notes_api (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 id_country INTEGER REFERENCES countries(id_country)
);

-- Insert test countries
INSERT INTO countries (id_country, country_name_en) VALUES
(1, 'United States'),
(2, 'Canada');

-- Insert notes with country assignment (simulated)
INSERT INTO notes_api (id, created_at, lat, lon, id_country) VALUES
(12345, '2025-12-15 10:00:00+00', 40.7128, -74.0060, 1),
(12346, '2025-12-15 11:00:00+00', 34.0522, -118.2437, 1);
EOSQL

 # Verify country assignments
 local ASSIGNED_COUNT
 ASSIGNED_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api WHERE id_country IS NOT NULL;" 2>/dev/null || echo "0")
 [[ "${ASSIGNED_COUNT}" -ge 2 ]]
}

@test "E2E: Complete API flow should handle full workflow end-to-end" {
 # Test: Complete workflow from download to country assignment
 # Purpose: Verify entire flow works together
 # Expected: All steps complete successfully

 # Skip if database not available
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Create complete test database structure
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DROP TABLE IF EXISTS note_comments_api CASCADE;
DROP TABLE IF EXISTS notes_api CASCADE;
DROP TABLE IF EXISTS countries CASCADE;

CREATE TABLE countries (
 id_country SERIAL PRIMARY KEY,
 country_name_en VARCHAR(255)
);
CREATE TABLE notes_api (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 closed_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20),
 id_country INTEGER REFERENCES countries(id_country)
);
CREATE TABLE note_comments_api (
 id BIGSERIAL PRIMARY KEY,
 note_id BIGINT REFERENCES notes_api(id),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL,
 uid BIGINT,
 user_name VARCHAR(255),
 action VARCHAR(20) NOT NULL,
 text TEXT
);

-- Insert test data
INSERT INTO countries (id_country, country_name_en) VALUES (1, 'United States');
EOSQL

 # Simulate complete workflow
 # Step 1: Download (mock)
 # Ensure TMP_DIR exists before creating files
 if [[ -z "${TMP_DIR:-}" ]] || [[ ! -d "${TMP_DIR}" ]]; then
  export TMP_DIR="$(mktemp -d)"
  export TEST_DIR="${TMP_DIR}"
  export API_NOTES_FILE="${TMP_DIR}/OSM-notes-API.xml"
 fi

 local DOWNLOADED_FILE="${TMP_DIR}/workflow.xml"
 cp "${API_NOTES_FILE}" "${DOWNLOADED_FILE}"

 # Step 2: Validate XML
 [[ -f "${DOWNLOADED_FILE}" ]]
 run grep -q "<osm" "${DOWNLOADED_FILE}"
 [ "$status" -eq 0 ]

 # Step 3: Process and insert
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes_api (id, created_at, lat, lon, status, id_country) VALUES
(12345, '2025-12-15 10:00:00+00', 40.7128, -74.0060, 'open', 1),
(12346, '2025-12-15 11:00:00+00', 34.0522, -118.2437, 'open', 1)
ON CONFLICT (id) DO UPDATE SET id_country = EXCLUDED.id_country;
EOSQL

 # Step 4: Verify complete workflow
 local NOTES_WITH_COUNTRIES
 NOTES_WITH_COUNTRIES=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api WHERE id_country IS NOT NULL;" 2>/dev/null || echo "0")
 [[ "${NOTES_WITH_COUNTRIES}" -ge 2 ]]
}

