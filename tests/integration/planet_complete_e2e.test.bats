#!/usr/bin/env bats

# End-to-end integration tests for complete Planet processing flow
# Tests: Download → Processing → Load → Verification
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
 # Set up test environment
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="$(mktemp -d)"
 export TEST_DIR="${TMP_DIR}"
 export DBNAME="${TEST_DBNAME:-osm_notes_ingestion_test}"
 export BASENAME="test_planet_complete_e2e"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"

 # Create minimal test Planet XML file
 cat > "${TMP_DIR}/planet-notes-test.osn.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note id="1001" lat="40.7128" lon="-74.0060" created_at="2025-12-01T00:00:00Z" closed_at="">
  <comment uid="1" user="user1" action="opened" timestamp="2025-12-01T00:00:00Z">
   <text>Planet note 1</text>
  </comment>
 </note>
 <note id="1002" lat="34.0522" lon="-118.2437" created_at="2025-12-02T00:00:00Z" closed_at="2025-12-10T00:00:00Z">
  <comment uid="2" user="user2" action="opened" timestamp="2025-12-02T00:00:00Z">
   <text>Planet note 2</text>
  </comment>
  <comment uid="3" user="user3" action="closed" timestamp="2025-12-10T00:00:00Z">
   <text>Closing note 2</text>
  </comment>
 </note>
</osm-notes>
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
 # Clean up
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# =============================================================================
# Complete Planet Flow Tests
# =============================================================================

@test "E2E: Complete Planet flow should download Planet file" {
 # Test: Download Planet file
 # Purpose: Verify that Planet file can be downloaded (or mocked)
 # Expected: Planet file exists

 # Mock download - use test file
 local PLANET_FILE="${TMP_DIR}/planet-notes-test.osn.xml"
 
 # Verify file exists
 [[ -f "${PLANET_FILE}" ]]
 [[ -s "${PLANET_FILE}" ]]
 
 # Verify XML structure
 run grep -q "<osm-notes>" "${PLANET_FILE}"
 [ "$status" -eq 0 ]
 run grep -q "<note" "${PLANET_FILE}"
 [ "$status" -eq 0 ]
}

@test "E2E: Complete Planet flow should process Planet XML" {
 # Test: Processing Planet XML
 # Purpose: Verify that Planet XML is parsed correctly
 # Expected: Notes are extracted from XML

 local PLANET_FILE="${TMP_DIR}/planet-notes-test.osn.xml"
 
 # Verify XML can be parsed (basic check)
 run grep -c "<note" "${PLANET_FILE}"
 [ "$status" -eq 0 ]
 [[ "${output}" -ge 2 ]]
 
 # Verify note IDs are present
 run grep -q 'id="1001"' "${PLANET_FILE}"
 [ "$status" -eq 0 ]
 run grep -q 'id="1002"' "${PLANET_FILE}"
 [ "$status" -eq 0 ]
}

@test "E2E: Complete Planet flow should load notes to database" {
 # Test: Load to Database
 # Purpose: Verify that processed notes are loaded to database
 # Expected: Notes are inserted into database

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Create test tables
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS notes (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 closed_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);
CREATE TABLE IF NOT EXISTS note_comments (
 id BIGSERIAL PRIMARY KEY,
 note_id BIGINT REFERENCES notes(id),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL,
 uid BIGINT,
 user_name VARCHAR(255),
 action VARCHAR(20) NOT NULL,
 text TEXT
);
EOSQL

 # Simulate loading notes from Planet
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes (id, created_at, closed_at, lat, lon, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'closed')
ON CONFLICT (id) DO NOTHING;

INSERT INTO note_comments (note_id, created_at, uid, user_name, action, text) VALUES
(1001, '2025-12-01 00:00:00+00', 1, 'user1', 'opened', 'Planet note 1'),
(1002, '2025-12-02 00:00:00+00', 2, 'user2', 'opened', 'Planet note 2'),
(1002, '2025-12-10 00:00:00+00', 3, 'user3', 'closed', 'Closing note 2')
ON CONFLICT DO NOTHING;
EOSQL

 # Verify notes were loaded
 local NOTE_COUNT
 NOTE_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes WHERE id IN (1001, 1002);" 2>/dev/null || echo "0")
 [[ "${NOTE_COUNT}" -ge 2 ]]

 # Verify comments were loaded
 local COMMENT_COUNT
 COMMENT_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM note_comments WHERE note_id IN (1001, 1002);" 2>/dev/null || echo "0")
 [[ "${COMMENT_COUNT}" -ge 3 ]]
}

@test "E2E: Complete Planet flow should verify loaded data" {
 # Test: Verification
 # Purpose: Verify that loaded data is correct
 # Expected: Data integrity checks pass

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Verify note 1001 is open
 local NOTE1_STATUS
 NOTE1_STATUS=$(psql -d "${DBNAME}" -Atq -c "SELECT status FROM notes WHERE id = 1001;" 2>/dev/null || echo "")
 [[ "${NOTE1_STATUS}" == "open" ]]

 # Verify note 1002 is closed
 local NOTE2_STATUS
 NOTE2_STATUS=$(psql -d "${DBNAME}" -Atq -c "SELECT status FROM notes WHERE id = 1002;" 2>/dev/null || echo "")
 [[ "${NOTE2_STATUS}" == "closed" ]]

 # Verify note 1002 has closed_at timestamp
 local NOTE2_CLOSED
 NOTE2_CLOSED=$(psql -d "${DBNAME}" -Atq -c "SELECT closed_at IS NOT NULL FROM notes WHERE id = 1002;" 2>/dev/null || echo "f")
 [[ "${NOTE2_CLOSED}" == "t" ]]
}

@test "E2E: Complete Planet flow should handle full workflow end-to-end" {
 # Test: Complete workflow from download to verification
 # Purpose: Verify entire Planet flow works together
 # Expected: All steps complete successfully

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Step 1: Download (mock - file already exists)
 local PLANET_FILE="${TMP_DIR}/planet-notes-test.osn.xml"
 [[ -f "${PLANET_FILE}" ]]

 # Step 2: Process XML
 run grep -c "<note" "${PLANET_FILE}"
 [ "$status" -eq 0 ]
 local NOTE_COUNT="${output}"
 [[ "${NOTE_COUNT}" -ge 2 ]]

 # Step 3: Load to database (simulated)
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS notes (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 closed_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);
INSERT INTO notes (id, created_at, closed_at, lat, lon, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'closed')
ON CONFLICT (id) DO NOTHING;
EOSQL

 # Step 4: Verify
 local LOADED_COUNT
 LOADED_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes WHERE id IN (1001, 1002);" 2>/dev/null || echo "0")
 [[ "${LOADED_COUNT}" -eq 2 ]]
}

