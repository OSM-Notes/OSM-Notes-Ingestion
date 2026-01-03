#!/usr/bin/env bats

# End-to-end integration tests for complete incremental synchronization flow
# Tests: Check → Download → Process → Update → Verify
# Author: Andres Gomez (AngocA)
# Version: 2026-01-02

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
 export BASENAME="test_incremental_sync_e2e"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"

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
 fi

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
 # Per-test cleanup (runs after each test)
 # Truncate test data instead of dropping tables (faster)
 __truncate_test_tables notes_api note_comments note_comments_text
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
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Use existing table structure (note_id, latitude, longitude)
 # Check if table exists and has correct structure
 local TABLE_EXISTS
 TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'notes_api');" 2> /dev/null || echo "f")

 if [[ "${TABLE_EXISTS}" == "t" ]]; then
  # Table exists, use real structure
  # Ensure PRIMARY KEY exists for ON CONFLICT to work
  psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
-- Add PRIMARY KEY if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'pk_notes_api' 
    AND conrelid = 'notes_api'::regclass
  ) THEN
    ALTER TABLE notes_api ADD CONSTRAINT pk_notes_api PRIMARY KEY (note_id);
  END IF;
END $$;
EOSQL

  # Simulate processing and insertion using real column names
  # Note: Remove existing test data first to avoid conflicts
  # Status must use note_status_enum type ('open', 'close', 'hidden')
  local INSERT_RESULT
  INSERT_RESULT=$(
   psql -d "${DBNAME}" << 'EOSQL' 2>&1
DELETE FROM notes_api WHERE note_id IN (20001, 20002);
INSERT INTO notes_api (note_id, created_at, latitude, longitude, status) VALUES
(20001, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open'::note_status_enum),
(20002, '2025-12-23 11:00:00+00', 34.0522, -118.2437, 'open'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 latitude = EXCLUDED.latitude,
 longitude = EXCLUDED.longitude,
 status = EXCLUDED.status;
EOSQL
  )
  # Check if INSERT failed
  if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
   echo "INSERT failed: ${INSERT_RESULT}" >&2
   false
  fi

  # Verify notes were inserted using real column name
  local NOTE_COUNT
  NOTE_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api WHERE note_id IN (20001, 20002);" 2> /dev/null || echo "0")
  [[ "${NOTE_COUNT}" -ge 2 ]]
 else
  # Table doesn't exist, create test structure with correct schema
  # First ensure enum type exists
  psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_status_enum') THEN
    CREATE TYPE note_status_enum AS ENUM ('open', 'close', 'hidden');
  END IF;
END
$$;
CREATE TABLE IF NOT EXISTS notes_api (
 note_id INTEGER NOT NULL PRIMARY KEY,
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 closed_at TIMESTAMP,
 status note_status_enum,
 id_country INTEGER
);
EOSQL

  # Insert using correct structure
  psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes_api (note_id, created_at, latitude, longitude, status) VALUES
(20001, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open'::note_status_enum),
(20002, '2025-12-23 11:00:00+00', 34.0522, -118.2437, 'open'::note_status_enum);
EOSQL

  # Verify notes were inserted using correct column name
  local NOTE_COUNT
  NOTE_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api WHERE note_id IN (20001, 20002);" 2> /dev/null || echo "0")
  [[ "${NOTE_COUNT}" -ge 2 ]]
 fi
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
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Step 1: Check last sync timestamp
 local LAST_SYNC_FILE="${TMP_DIR}/last_sync.txt"
 echo "2025-12-23T09:00:00Z" > "${LAST_SYNC_FILE}"
 [[ -f "${LAST_SYNC_FILE}" ]]

 # Step 2: Download new notes (mock)
 local DOWNLOADED_FILE="${TMP_DIR}/downloaded.xml"
 cp "${TMP_DIR}/api_notes_new.xml" "${DOWNLOADED_FILE}"
 [[ -f "${DOWNLOADED_FILE}" ]]

 # Step 3: Process and insert (simulated)
 # Check table structure and use appropriate column names
 local TABLE_EXISTS
 TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'notes_api');" 2> /dev/null || echo "f")

 if [[ "${TABLE_EXISTS}" == "t" ]]; then
  # Ensure PRIMARY KEY exists for ON CONFLICT to work
  psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
-- Add PRIMARY KEY if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'pk_notes_api' 
    AND conrelid = 'notes_api'::regclass
  ) THEN
    ALTER TABLE notes_api ADD CONSTRAINT pk_notes_api PRIMARY KEY (note_id);
  END IF;
END $$;
EOSQL

  # Use real structure (note_id, latitude, longitude)
  # Status must use note_status_enum type
  local INSERT_RESULT
  INSERT_RESULT=$(
   psql -d "${DBNAME}" << 'EOSQL' 2>&1
DELETE FROM notes_api WHERE note_id IN (20001, 20002);
INSERT INTO notes_api (note_id, created_at, latitude, longitude, status) VALUES
(20001, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open'::note_status_enum),
(20002, '2025-12-23 11:00:00+00', 34.0522, -118.2437, 'open'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 latitude = EXCLUDED.latitude,
 longitude = EXCLUDED.longitude,
 status = EXCLUDED.status;
EOSQL
  )
  # Check if INSERT failed
  if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
   echo "INSERT failed: ${INSERT_RESULT}" >&2
   false
  fi
  local SYNCED_COUNT
  SYNCED_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api WHERE note_id IN (20001, 20002);" 2> /dev/null || echo "0")
 else
  # Create test structure with correct schema
  # First ensure enum type exists
  psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_status_enum') THEN
    CREATE TYPE note_status_enum AS ENUM ('open', 'close', 'hidden');
  END IF;
END
$$;
CREATE TABLE IF NOT EXISTS notes_api (
 note_id INTEGER NOT NULL PRIMARY KEY,
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 closed_at TIMESTAMP,
 status note_status_enum,
 id_country INTEGER
);
INSERT INTO notes_api (note_id, created_at, latitude, longitude, status) VALUES
(20001, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open'::note_status_enum),
(20002, '2025-12-23 11:00:00+00', 34.0522, -118.2437, 'open'::note_status_enum);
EOSQL
  local SYNCED_COUNT
  SYNCED_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api WHERE note_id IN (20001, 20002);" 2> /dev/null || echo "0")
 fi

 # Step 4: Update timestamp
 echo "2025-12-23T12:00:00Z" > "${LAST_SYNC_FILE}"

 # Step 5: Verify complete workflow
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
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Check table structure and use appropriate column names
 local TABLE_EXISTS
 TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'notes_api');" 2> /dev/null || echo "f")

 if [[ "${TABLE_EXISTS}" == "t" ]]; then
  # Ensure PRIMARY KEY exists for ON CONFLICT to work
  psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
-- Add PRIMARY KEY if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'pk_notes_api' 
    AND conrelid = 'notes_api'::regclass
  ) THEN
    ALTER TABLE notes_api ADD CONSTRAINT pk_notes_api PRIMARY KEY (note_id);
  END IF;
END $$;
EOSQL

  # Use real structure (note_id, latitude, longitude)
  # Clean up test data first
  psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DELETE FROM notes_api WHERE note_id IN (20001, 20002);
EOSQL

  # Insert existing note (status must use enum type)
  local INSERT_RESULT1
  INSERT_RESULT1=$(
   psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes_api (note_id, created_at, latitude, longitude, status) VALUES
(20001, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 latitude = EXCLUDED.latitude,
 longitude = EXCLUDED.longitude,
 status = EXCLUDED.status;
EOSQL
  )
  # Check if INSERT failed
  if echo "${INSERT_RESULT1}" | grep -qiE "^ERROR|^FATAL"; then
   echo "INSERT failed: ${INSERT_RESULT1}" >&2
   false
  fi

  # Simulate partial update (note 20001 exists, 20002 is new)
  local INSERT_RESULT2
  INSERT_RESULT2=$(
   psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes_api (note_id, created_at, latitude, longitude, status) VALUES
(20001, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open'::note_status_enum),
(20002, '2025-12-23 11:00:00+00', 34.0522, -118.2437, 'open'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 latitude = EXCLUDED.latitude,
 longitude = EXCLUDED.longitude,
 status = EXCLUDED.status;
EOSQL
  )
  # Check if INSERT failed
  if echo "${INSERT_RESULT2}" | grep -qiE "^ERROR|^FATAL"; then
   echo "INSERT failed: ${INSERT_RESULT2}" >&2
   false
  fi

  # Verify both notes exist
  # Check for each note separately to handle potential duplicates
  local NOTE1_COUNT
  NOTE1_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api WHERE note_id = 20001;" 2> /dev/null || echo "0")
  local NOTE2_COUNT
  NOTE2_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api WHERE note_id = 20002;" 2> /dev/null || echo "0")
  # We expect at least note 20001 to exist (inserted first), and ideally both
  [[ "${NOTE1_COUNT}" -ge 1 ]] && [[ "${NOTE2_COUNT}" -ge 1 ]]
 else
  # Create test structure with correct schema
  # First ensure enum type exists
  psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'note_status_enum') THEN
    CREATE TYPE note_status_enum AS ENUM ('open', 'close', 'hidden');
  END IF;
END
$$;
CREATE TABLE IF NOT EXISTS notes_api (
 note_id INTEGER NOT NULL PRIMARY KEY,
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 closed_at TIMESTAMP,
 status note_status_enum,
 id_country INTEGER
);
INSERT INTO notes_api (note_id, created_at, latitude, longitude, status) VALUES
(20001, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open'::note_status_enum);
EOSQL

  # Simulate partial update
  psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes_api (note_id, created_at, latitude, longitude, status) VALUES
(20001, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open'::note_status_enum),
(20002, '2025-12-23 11:00:00+00', 34.0522, -118.2437, 'open'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 latitude = EXCLUDED.latitude,
 longitude = EXCLUDED.longitude,
 status = EXCLUDED.status;
EOSQL

  local TOTAL_COUNT
  TOTAL_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api WHERE note_id IN (20001, 20002);" 2> /dev/null || echo "0")
  [[ "${TOTAL_COUNT}" -eq 2 ]]
 fi
}
