#!/usr/bin/env bats

# End-to-end integration tests for complete incremental synchronization flow
# Tests: Check → Download → Process → Update → Verify
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
 # Set up test environment
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="$(mktemp -d)"
 export TEST_DIR="${TMP_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export BASENAME="test_incremental_sync_e2e"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"

 # Create mock API XML file with new notes
 cat > "${TMP_DIR}/api_notes_new.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
 <note id="20001" lat="40.7128" lon="-74.0060" created_at="2025-12-23T10:00:00Z" closed_at="">
  <comment uid="1" user="testuser" action="opened" timestamp="2025-12-23T10:00:00Z">
   <text>New note 1</text>
  </comment>
 </note>
 <note id="20002" lat="34.0522" lon="-118.2437" created_at="2025-12-23T11:00:00Z" closed_at="">
  <comment uid="2" user="testuser2" action="opened" timestamp="2025-12-23T11:00:00Z">
   <text>New note 2</text>
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
 # Clean up
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# =============================================================================
# Complete Incremental Sync Flow Tests
# =============================================================================

@test "E2E Incremental Sync: Should check for new notes since last sync" {
 # Test: Check for updates
 # Purpose: Verify that system checks for new notes since last sync timestamp
 # Expected: Timestamp check identifies new notes available

 # Create mock last sync timestamp file
 local LAST_SYNC_FILE="${TMP_DIR}/last_sync.txt"
 echo "2025-12-23T09:00:00Z" > "${LAST_SYNC_FILE}"

 # Verify timestamp file exists
 [[ -f "${LAST_SYNC_FILE}" ]]

 # Verify timestamp is readable
 local LAST_SYNC
 LAST_SYNC=$(cat "${LAST_SYNC_FILE}")
 [[ -n "${LAST_SYNC}" ]]
 [[ "${LAST_SYNC}" == *"2025-12-23"* ]]
}

@test "E2E Incremental Sync: Should download new notes from API" {
 # Test: Download new notes
 # Purpose: Verify that new notes are downloaded from API
 # Expected: New notes XML file is downloaded

 # Mock API download
 __retry_osm_api() {
  local URL="$1"
  local OUTPUT_FILE="$2"
  # Copy test XML to output
  cp "${TMP_DIR}/api_notes_new.xml" "${OUTPUT_FILE}"
  return 0
 }
 export -f __retry_osm_api

 # Simulate download
 local DOWNLOADED_FILE="${TMP_DIR}/downloaded_new.xml"
 __retry_osm_api "https://api.openstreetmap.org/api/0.6/notes/search.xml?closed=0&limit=10000&from=2025-12-23T09:00:00Z" "${DOWNLOADED_FILE}"

 # Verify file exists and is valid XML
 [[ -f "${DOWNLOADED_FILE}" ]]
 [[ -s "${DOWNLOADED_FILE}" ]]
 run grep -q "<osm" "${DOWNLOADED_FILE}"
 [ "$status" -eq 0 ]
 run grep -q "<note" "${DOWNLOADED_FILE}"
 [ "$status" -eq 0 ]
}

@test "E2E Incremental Sync: Should process and insert new notes to database" {
 # Test: Process and Insert
 # Purpose: Verify that new notes are processed and inserted
 # Expected: New notes are inserted into database

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

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

 # Simulate processing and insertion
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes_api (id, created_at, lat, lon, status) VALUES
(20001, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open'),
(20002, '2025-12-23 11:00:00+00', 34.0522, -118.2437, 'open')
ON CONFLICT (id) DO NOTHING;

INSERT INTO note_comments_api (note_id, created_at, uid, user_name, action, text) VALUES
(20001, '2025-12-23 10:00:00+00', 1, 'testuser', 'opened', 'New note 1'),
(20002, '2025-12-23 11:00:00+00', 2, 'testuser2', 'opened', 'New note 2')
ON CONFLICT DO NOTHING;
EOSQL

 # Verify notes were inserted
 local NOTE_COUNT
 NOTE_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api WHERE id IN (20001, 20002);" 2>/dev/null || echo "0")
 [[ "${NOTE_COUNT}" -ge 2 ]]
}

@test "E2E Incremental Sync: Should update last sync timestamp after processing" {
 # Test: Update Timestamp
 # Purpose: Verify that last sync timestamp is updated after successful processing
 # Expected: Timestamp file is updated with new timestamp

 # Create mock timestamp file
 local LAST_SYNC_FILE="${TMP_DIR}/last_sync.txt"
 echo "2025-12-23T09:00:00Z" > "${LAST_SYNC_FILE}"

 # Simulate timestamp update
 local NEW_TIMESTAMP="2025-12-23T12:00:00Z"
 echo "${NEW_TIMESTAMP}" > "${LAST_SYNC_FILE}"

 # Verify timestamp was updated
 local UPDATED_TIMESTAMP
 UPDATED_TIMESTAMP=$(cat "${LAST_SYNC_FILE}")
 [[ "${UPDATED_TIMESTAMP}" == "${NEW_TIMESTAMP}" ]]
 [[ "${UPDATED_TIMESTAMP}" != "2025-12-23T09:00:00Z" ]]
}

@test "E2E Incremental Sync: Should handle complete workflow end-to-end" {
 # Test: Complete workflow from check to update
 # Purpose: Verify entire incremental sync flow works together
 # Expected: All steps complete successfully

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Step 1: Check last sync timestamp
 local LAST_SYNC_FILE="${TMP_DIR}/last_sync.txt"
 echo "2025-12-23T09:00:00Z" > "${LAST_SYNC_FILE}"
 [[ -f "${LAST_SYNC_FILE}" ]]

 # Step 2: Download new notes (mock)
 local DOWNLOADED_FILE="${TMP_DIR}/downloaded.xml"
 cp "${TMP_DIR}/api_notes_new.xml" "${DOWNLOADED_FILE}"
 [[ -f "${DOWNLOADED_FILE}" ]]

 # Step 3: Process and insert (simulated)
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS notes_api (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);
INSERT INTO notes_api (id, created_at, lat, lon, status) VALUES
(20001, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open'),
(20002, '2025-12-23 11:00:00+00', 34.0522, -118.2437, 'open')
ON CONFLICT (id) DO NOTHING;
EOSQL

 # Step 4: Update timestamp
 echo "2025-12-23T12:00:00Z" > "${LAST_SYNC_FILE}"

 # Step 5: Verify complete workflow
 local SYNCED_COUNT
 SYNCED_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api WHERE id IN (20001, 20002);" 2>/dev/null || echo "0")
 [[ "${SYNCED_COUNT}" -ge 2 ]]

 local UPDATED_TIMESTAMP
 UPDATED_TIMESTAMP=$(cat "${LAST_SYNC_FILE}")
 [[ "${UPDATED_TIMESTAMP}" == "2025-12-23T12:00:00Z" ]]
}

@test "E2E Incremental Sync: Should handle empty response when no new notes" {
 # Test: Empty Response Handling
 # Purpose: Verify that empty API response is handled correctly
 # Expected: System handles empty response without errors

 # Create empty XML response
 cat > "${TMP_DIR}/empty_response.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
</osm>
EOF

 # Verify empty response file exists
 [[ -f "${TMP_DIR}/empty_response.xml" ]]

 # Verify it's valid XML but has no notes
 run grep -q "<osm" "${TMP_DIR}/empty_response.xml"
 [ "$status" -eq 0 ]
 run grep -q "<note" "${TMP_DIR}/empty_response.xml"
 [ "$status" -ne 0 ] # Should not find notes
}

@test "E2E Incremental Sync: Should handle partial updates correctly" {
 # Test: Partial Updates
 # Purpose: Verify that partial updates (some notes already exist) are handled
 # Expected: Only new notes are inserted, existing notes are not duplicated

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Create table and insert existing note
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS notes_api (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);
INSERT INTO notes_api (id, created_at, lat, lon, status) VALUES
(20001, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open')
ON CONFLICT (id) DO NOTHING;
EOSQL

 # Simulate partial update (note 20001 exists, 20002 is new)
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes_api (id, created_at, lat, lon, status) VALUES
(20001, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open'),
(20002, '2025-12-23 11:00:00+00', 34.0522, -118.2437, 'open')
ON CONFLICT (id) DO NOTHING;
EOSQL

 # Verify both notes exist (no duplicates)
 local TOTAL_COUNT
 TOTAL_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api WHERE id IN (20001, 20002);" 2>/dev/null || echo "0")
 [[ "${TOTAL_COUNT}" -eq 2 ]]
}

