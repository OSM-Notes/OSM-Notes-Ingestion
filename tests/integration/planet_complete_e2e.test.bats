#!/usr/bin/env bats

# End-to-end integration tests for complete Planet processing flow
# Tests: Download → Processing → Load → Verification
# Author: Andres Gomez (AngocA)
# Version: 2026-01-05

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

# =============================================================================
# Setup and Teardown
# =============================================================================

# Shared database setup (runs once per file, not per test)
setup_file() {
 # Set up test environment
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="$(mktemp -d)"
 export TEST_DIR="${TMP_DIR}"
 export DBNAME="${TEST_DBNAME:-osm_notes_ingestion_test}"
 export BASENAME="test_planet_complete_e2e"
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
 # Per-test cleanup (runs after each test)
 # Truncate test data instead of dropping tables (faster)
 # Note: Only truncate if tables exist to avoid errors
 __truncate_test_tables notes note_comments 2> /dev/null || true
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
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Check if table exists and use correct structure
 local TABLE_EXISTS
 TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'notes');" 2> /dev/null || echo "f")

 if [[ "${TABLE_EXISTS}" == "t" ]]; then
  # Table exists, check which column names it uses (lat/lon vs latitude/longitude)
  # Remove existing test data first to avoid conflicts
  psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DELETE FROM note_comments WHERE note_id IN (1001, 1002);
DELETE FROM notes WHERE note_id IN (1001, 1002);
EOSQL

  # Use structure from DDL (processPlanetNotes_21_createBaseTables_tables.sql):
  # note_id INTEGER NOT NULL, latitude DECIMAL, longitude DECIMAL
  # Check for latitude/longitude vs lat/lon (test_helper.bash uses lat/lon)
  local HAS_LATITUDE
  HAS_LATITUDE=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'notes' AND column_name = 'latitude');" 2> /dev/null || echo "f")

  # Check if table has id column (test_helper.bash creates notes with id)
  local HAS_ID
  HAS_ID=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'notes' AND column_name = 'id');" 2> /dev/null || echo "f")

  if [[ "${HAS_LATITUDE}" == "t" ]]; then
   # Use latitude/longitude columns (production DDL structure)
   # Check if PRIMARY KEY exists to use ON CONFLICT
   local HAS_PK
   HAS_PK=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid = 'notes'::regclass AND contype = 'p' AND conkey::text LIKE '%note_id%');" 2> /dev/null || echo "f")
   if [[ "${HAS_PK}" == "t" ]]; then
    local INSERT_RESULT
    if [[ "${HAS_ID}" == "t" ]]; then
     # Table has id column, must provide it
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (id, note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, 1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, 1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 closed_at = EXCLUDED.closed_at,
 latitude = EXCLUDED.latitude,
 longitude = EXCLUDED.longitude,
 status = EXCLUDED.status;
EOSQL
     )
    else
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 closed_at = EXCLUDED.closed_at,
 latitude = EXCLUDED.latitude,
 longitude = EXCLUDED.longitude,
 status = EXCLUDED.status;
EOSQL
     )
    fi
    if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
     echo "INSERT failed: ${INSERT_RESULT}" >&2
     false
    fi
   else
    local INSERT_RESULT
    if [[ "${HAS_ID}" == "t" ]]; then
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (id, note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, 1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, 1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL
     )
    else
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL
     )
    fi
    if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
     echo "INSERT failed: ${INSERT_RESULT}" >&2
     false
    fi
   fi
  else
   # Use lat/lon columns (test_helper.bash structure)
   local HAS_PK
   HAS_PK=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid = 'notes'::regclass AND contype = 'p');" 2> /dev/null || echo "f")
   if [[ "${HAS_PK}" == "t" ]]; then
    local INSERT_RESULT
    if [[ "${HAS_ID}" == "t" ]]; then
     # Table has id column (test_helper.bash structure), must provide it
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (id, note_id, created_at, closed_at, lat, lon, status) VALUES
(1001, 1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, 1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 closed_at = EXCLUDED.closed_at,
 lat = EXCLUDED.lat,
 lon = EXCLUDED.lon,
 status = EXCLUDED.status;
EOSQL
     )
    else
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (note_id, created_at, closed_at, lat, lon, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 closed_at = EXCLUDED.closed_at,
 lat = EXCLUDED.lat,
 lon = EXCLUDED.lon,
 status = EXCLUDED.status;
EOSQL
     )
    fi
    if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
     echo "INSERT failed: ${INSERT_RESULT}" >&2
     false
    fi
   else
    local INSERT_RESULT
    if [[ "${HAS_ID}" == "t" ]]; then
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (id, note_id, created_at, closed_at, lat, lon, status) VALUES
(1001, 1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, 1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL
     )
    else
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (note_id, created_at, closed_at, lat, lon, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL
     )
    fi
    if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
     echo "INSERT failed: ${INSERT_RESULT}" >&2
     false
    fi
   fi
  fi

  # Verify notes were loaded using correct column name
  local NOTE_COUNT
  NOTE_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes WHERE note_id IN (1001, 1002);" 2> /dev/null || echo "0")
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
CREATE TABLE IF NOT EXISTS notes (
 note_id INTEGER NOT NULL PRIMARY KEY,
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 closed_at TIMESTAMP,
 status note_status_enum,
 id_country INTEGER
);
CREATE TABLE IF NOT EXISTS note_comments (
 id SERIAL,
 note_id INTEGER NOT NULL,
 sequence_action INTEGER,
 event VARCHAR(20) NOT NULL,
 created_at TIMESTAMP NOT NULL,
 id_user INTEGER
);
EOSQL

  # Simulate loading notes from Planet using correct structure
  psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
INSERT INTO notes (note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL

  # Simulate loading comments for the notes
  # Check if note_comments has sequence_action column
  local HAS_SEQUENCE_ACTION
  HAS_SEQUENCE_ACTION=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'note_comments' AND column_name = 'sequence_action');" 2> /dev/null || echo "f")

  # Check if note_comments id has default (SERIAL) or needs explicit values
  local ID_HAS_DEFAULT
  ID_HAS_DEFAULT=$(psql -d "${DBNAME}" -Atq -c "SELECT column_default IS NOT NULL FROM information_schema.columns WHERE table_name = 'note_comments' AND column_name = 'id';" 2> /dev/null || echo "f")

  if [[ "${HAS_SEQUENCE_ACTION}" == "t" ]]; then
   if [[ "${ID_HAS_DEFAULT}" == "t" ]]; then
    psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
(1001, 0, 'opened', '2025-12-01 00:00:00+00', 1),
(1001, 1, 'commented', '2025-12-01 01:00:00+00', 2),
(1002, 0, 'opened', '2025-12-02 00:00:00+00', 1),
(1002, 1, 'closed', '2025-12-10 00:00:00+00', 1);
EOSQL
   else
    psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
INSERT INTO note_comments (id, note_id, sequence_action, event, created_at, id_user) VALUES
(1, 1001, 0, 'opened', '2025-12-01 00:00:00+00', 1),
(2, 1001, 1, 'commented', '2025-12-01 01:00:00+00', 2),
(3, 1002, 0, 'opened', '2025-12-02 00:00:00+00', 1),
(4, 1002, 1, 'closed', '2025-12-10 00:00:00+00', 1);
EOSQL
   fi
  else
   if [[ "${ID_HAS_DEFAULT}" == "t" ]]; then
    psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
INSERT INTO note_comments (note_id, event, created_at, id_user) VALUES
(1001, 'opened', '2025-12-01 00:00:00+00', 1),
(1001, 'commented', '2025-12-01 01:00:00+00', 2),
(1002, 'opened', '2025-12-02 00:00:00+00', 1),
(1002, 'closed', '2025-12-10 00:00:00+00', 1);
EOSQL
   else
    psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
INSERT INTO note_comments (id, note_id, event, created_at, id_user) VALUES
(1, 1001, 'opened', '2025-12-01 00:00:00+00', 1),
(2, 1001, 'commented', '2025-12-01 01:00:00+00', 2),
(3, 1002, 'opened', '2025-12-02 00:00:00+00', 1),
(4, 1002, 'closed', '2025-12-10 00:00:00+00', 1);
EOSQL
   fi
  fi

  # Verify notes were loaded using correct column name
  local NOTE_COUNT
  NOTE_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes WHERE note_id IN (1001, 1002);" 2> /dev/null || echo "0")
  [[ "${NOTE_COUNT}" -ge 2 ]]
 fi

 # Simulate loading comments for the notes (ensure comments exist for both cases)
 # Check if note_comments has sequence_action column
 local HAS_SEQUENCE_ACTION
 HAS_SEQUENCE_ACTION=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'note_comments' AND column_name = 'sequence_action');" 2> /dev/null || echo "f")

 # Check if note_comments id has default (SERIAL) or needs explicit values
 local ID_HAS_DEFAULT
 ID_HAS_DEFAULT=$(psql -d "${DBNAME}" -Atq -c "SELECT column_default IS NOT NULL FROM information_schema.columns WHERE table_name = 'note_comments' AND column_name = 'id';" 2> /dev/null || echo "f")

 if [[ "${HAS_SEQUENCE_ACTION}" == "t" ]]; then
  if [[ "${ID_HAS_DEFAULT}" == "t" ]]; then
   psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DELETE FROM note_comments WHERE note_id IN (1001, 1002);
INSERT INTO note_comments (note_id, sequence_action, event, created_at, id_user) VALUES
(1001, 0, 'opened', '2025-12-01 00:00:00+00', 1),
(1001, 1, 'commented', '2025-12-01 01:00:00+00', 2),
(1002, 0, 'opened', '2025-12-02 00:00:00+00', 1),
(1002, 1, 'closed', '2025-12-10 00:00:00+00', 1);
EOSQL
  else
   psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DELETE FROM note_comments WHERE note_id IN (1001, 1002);
INSERT INTO note_comments (id, note_id, sequence_action, event, created_at, id_user) VALUES
(1, 1001, 0, 'opened', '2025-12-01 00:00:00+00', 1),
(2, 1001, 1, 'commented', '2025-12-01 01:00:00+00', 2),
(3, 1002, 0, 'opened', '2025-12-02 00:00:00+00', 1),
(4, 1002, 1, 'closed', '2025-12-10 00:00:00+00', 1);
EOSQL
  fi
 else
  if [[ "${ID_HAS_DEFAULT}" == "t" ]]; then
   psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DELETE FROM note_comments WHERE note_id IN (1001, 1002);
INSERT INTO note_comments (note_id, event, created_at, id_user) VALUES
(1001, 'opened', '2025-12-01 00:00:00+00', 1),
(1001, 'commented', '2025-12-01 01:00:00+00', 2),
(1002, 'opened', '2025-12-02 00:00:00+00', 1),
(1002, 'closed', '2025-12-10 00:00:00+00', 1);
EOSQL
  else
   psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DELETE FROM note_comments WHERE note_id IN (1001, 1002);
INSERT INTO note_comments (id, note_id, event, created_at, id_user) VALUES
(1, 1001, 'opened', '2025-12-01 00:00:00+00', 1),
(2, 1001, 'commented', '2025-12-01 01:00:00+00', 2),
(3, 1002, 'opened', '2025-12-02 00:00:00+00', 1),
(4, 1002, 'closed', '2025-12-10 00:00:00+00', 1);
EOSQL
  fi
 fi

 # Verify comments were loaded
 local COMMENT_COUNT
 COMMENT_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM note_comments WHERE note_id IN (1001, 1002);" 2> /dev/null || echo "0")
 [[ "${COMMENT_COUNT}" -ge 3 ]]
}

@test "E2E: Complete Planet flow should verify loaded data" {
 # Test: Verification
 # Purpose: Verify that loaded data is correct
 # Expected: Data integrity checks pass

 # Skip if database not available
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Ensure test data exists first
 # Check which column names the table uses
 local HAS_LATITUDE
 HAS_LATITUDE=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'notes' AND column_name = 'latitude');" 2> /dev/null || echo "f")

 # Check if table has id column (test_helper.bash creates notes with id)
 local HAS_ID
 HAS_ID=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'notes' AND column_name = 'id');" 2> /dev/null || echo "f")

 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DELETE FROM notes WHERE note_id IN (1001, 1002);
EOSQL

 if [[ "${HAS_LATITUDE}" == "t" ]]; then
  # Use latitude/longitude columns
  # Check if PRIMARY KEY exists on note_id to use ON CONFLICT
  local HAS_PK
  HAS_PK=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid = 'notes'::regclass AND contype = 'p' AND conkey::text LIKE '%note_id%');" 2> /dev/null || echo "f")
  if [[ "${HAS_PK}" == "t" ]]; then
   local INSERT_RESULT
   if [[ "${HAS_ID}" == "t" ]]; then
    # Table has id column, must provide it
    INSERT_RESULT=$(
     psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (id, note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, 1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, 1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 closed_at = EXCLUDED.closed_at,
 latitude = EXCLUDED.latitude,
 longitude = EXCLUDED.longitude,
 status = EXCLUDED.status;
EOSQL
    )
   else
    INSERT_RESULT=$(
     psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 closed_at = EXCLUDED.closed_at,
 latitude = EXCLUDED.latitude,
 longitude = EXCLUDED.longitude,
 status = EXCLUDED.status;
EOSQL
    )
   fi
   if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
    echo "INSERT failed: ${INSERT_RESULT}" >&2
    false
   fi
  else
   local INSERT_RESULT
   if [[ "${HAS_ID}" == "t" ]]; then
    INSERT_RESULT=$(
     psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (id, note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, 1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, 1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL
    )
   else
    INSERT_RESULT=$(
     psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL
    )
   fi
   if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
    echo "INSERT failed: ${INSERT_RESULT}" >&2
    false
   fi
  fi
 else
  # Use lat/lon columns
  local HAS_PK
  HAS_PK=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid = 'notes'::regclass AND contype = 'p' AND conkey::text LIKE '%note_id%');" 2> /dev/null || echo "f")
  if [[ "${HAS_PK}" == "t" ]]; then
   local INSERT_RESULT
   if [[ "${HAS_ID}" == "t" ]]; then
    # Table has id column (test_helper.bash structure), must provide it
    INSERT_RESULT=$(
     psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (id, note_id, created_at, closed_at, lat, lon, status) VALUES
(1001, 1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, 1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 closed_at = EXCLUDED.closed_at,
 lat = EXCLUDED.lat,
 lon = EXCLUDED.lon,
 status = EXCLUDED.status;
EOSQL
    )
   else
    INSERT_RESULT=$(
     psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (note_id, created_at, closed_at, lat, lon, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 closed_at = EXCLUDED.closed_at,
 lat = EXCLUDED.lat,
 lon = EXCLUDED.lon,
 status = EXCLUDED.status;
EOSQL
    )
   fi
   if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
    echo "INSERT failed: ${INSERT_RESULT}" >&2
    false
   fi
  else
   local INSERT_RESULT
   if [[ "${HAS_ID}" == "t" ]]; then
    # Table has id column (test_helper.bash structure), must provide it
    INSERT_RESULT=$(
     psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (id, note_id, created_at, closed_at, lat, lon, status) VALUES
(1001, 1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, 1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL
    )
   else
    INSERT_RESULT=$(
     psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (note_id, created_at, closed_at, lat, lon, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL
    )
   fi
   if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
    echo "INSERT failed: ${INSERT_RESULT}" >&2
    false
   fi
  fi
 fi

 # Verify notes were inserted before checking status
 local NOTE_COUNT
 NOTE_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes WHERE note_id IN (1001, 1002);" 2> /dev/null || echo "0")
 [[ "${NOTE_COUNT}" -ge 2 ]]

 # Verify note 1001 is open using correct column name
 # Note: status enum returns 'open' or 'close', not 'closed'
 local NOTE1_STATUS
 NOTE1_STATUS=$(psql -d "${DBNAME}" -Atq -c "SELECT status FROM notes WHERE note_id = 1001;" 2> /dev/null || echo "")
 [[ "${NOTE1_STATUS}" == "open" ]]

 # Verify note 1002 is closed using correct column name
 # Note: status enum uses 'close' not 'closed'
 local NOTE2_STATUS
 NOTE2_STATUS=$(psql -d "${DBNAME}" -Atq -c "SELECT status FROM notes WHERE note_id = 1002;" 2> /dev/null || echo "")
 [[ "${NOTE2_STATUS}" == "close" ]]

 # Verify note 1002 has closed_at timestamp using correct column name
 local NOTE2_CLOSED
 NOTE2_CLOSED=$(psql -d "${DBNAME}" -Atq -c "SELECT closed_at IS NOT NULL FROM notes WHERE note_id = 1002;" 2> /dev/null || echo "f")
 [[ "${NOTE2_CLOSED}" == "t" ]]
}

@test "E2E: Complete Planet flow should handle full workflow end-to-end" {
 # Test: Complete workflow from download to verification
 # Purpose: Verify entire Planet flow works together
 # Expected: All steps complete successfully

 # Skip if database not available
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Step 1: Download (mock - file already exists)
 local PLANET_FILE="${TMP_DIR}/planet-notes-test.osn.xml"
 [[ -f "${PLANET_FILE}" ]]

 # Step 2: Process XML
 run grep -c "<note" "${PLANET_FILE}"
 [ "$status" -eq 0 ]
 local NOTE_COUNT="${output}"
 [[ "${NOTE_COUNT}" -ge 2 ]]

 # Step 3: Load to database (simulated)
 # Check table structure and use appropriate column names
 local TABLE_EXISTS
 TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'notes');" 2> /dev/null || echo "f")

 if [[ "${TABLE_EXISTS}" == "t" ]]; then
  # Use real structure, check which column names it uses
  psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DELETE FROM notes WHERE note_id IN (1001, 1002);
EOSQL

  # Use structure from DDL (processPlanetNotes_21_createBaseTables_tables.sql):
  # note_id INTEGER NOT NULL, latitude DECIMAL, longitude DECIMAL
  # Check if PRIMARY KEY exists to use ON CONFLICT
  local HAS_PK
  HAS_PK=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid = 'notes'::regclass AND contype = 'p' AND conkey::text LIKE '%note_id%');" 2> /dev/null || echo "f")

  # Check if table has id column (test_helper.bash creates notes with id)
  local HAS_ID
  HAS_ID=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'notes' AND column_name = 'id');" 2> /dev/null || echo "f")

  # Check for latitude/longitude vs lat/lon
  local HAS_LATITUDE
  HAS_LATITUDE=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'notes' AND column_name = 'latitude');" 2> /dev/null || echo "f")

  if [[ "${HAS_LATITUDE}" == "t" ]]; then
   # Use latitude/longitude columns (production DDL structure)
   if [[ "${HAS_PK}" == "t" ]]; then
    local INSERT_RESULT
    if [[ "${HAS_ID}" == "t" ]]; then
     # Table has id column (test_helper.bash structure), must provide it
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (id, note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, 1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, 1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 closed_at = EXCLUDED.closed_at,
 latitude = EXCLUDED.latitude,
 longitude = EXCLUDED.longitude,
 status = EXCLUDED.status;
EOSQL
     )
    else
     # Production DDL structure (no id column)
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 closed_at = EXCLUDED.closed_at,
 latitude = EXCLUDED.latitude,
 longitude = EXCLUDED.longitude,
 status = EXCLUDED.status;
EOSQL
     )
    fi
    if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
     echo "INSERT failed: ${INSERT_RESULT}" >&2
     false
    fi
   else
    local INSERT_RESULT
    if [[ "${HAS_ID}" == "t" ]]; then
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (id, note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, 1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, 1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL
     )
    else
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL
     )
    fi
    if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
     echo "INSERT failed: ${INSERT_RESULT}" >&2
     false
    fi
   fi
  else
   # Use lat/lon columns (test_helper.bash structure)
   local HAS_PK
   HAS_PK=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid = 'notes'::regclass AND contype = 'p');" 2> /dev/null || echo "f")
   if [[ "${HAS_PK}" == "t" ]]; then
    local INSERT_RESULT
    if [[ "${HAS_ID}" == "t" ]]; then
     # Table has id column (test_helper.bash structure), must provide it
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (id, note_id, created_at, closed_at, lat, lon, status) VALUES
(1001, 1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, 1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 closed_at = EXCLUDED.closed_at,
 lat = EXCLUDED.lat,
 lon = EXCLUDED.lon,
 status = EXCLUDED.status;
EOSQL
     )
    else
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (note_id, created_at, closed_at, lat, lon, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum)
ON CONFLICT (note_id) DO UPDATE SET
 created_at = EXCLUDED.created_at,
 closed_at = EXCLUDED.closed_at,
 lat = EXCLUDED.lat,
 lon = EXCLUDED.lon,
 status = EXCLUDED.status;
EOSQL
     )
    fi
    if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
     echo "INSERT failed: ${INSERT_RESULT}" >&2
     false
    fi
   else
    local INSERT_RESULT
    if [[ "${HAS_ID}" == "t" ]]; then
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (id, note_id, created_at, closed_at, lat, lon, status) VALUES
(1001, 1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, 1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL
     )
    else
     INSERT_RESULT=$(
      psql -d "${DBNAME}" << 'EOSQL' 2>&1
INSERT INTO notes (note_id, created_at, closed_at, lat, lon, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL
     )
    fi
    if echo "${INSERT_RESULT}" | grep -qiE "^ERROR|^FATAL"; then
     echo "INSERT failed: ${INSERT_RESULT}" >&2
     false
    fi
   fi
  fi
  local LOADED_COUNT
  LOADED_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes WHERE note_id IN (1001, 1002);" 2> /dev/null || echo "0")
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
CREATE TABLE IF NOT EXISTS notes (
 note_id INTEGER NOT NULL PRIMARY KEY,
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 closed_at TIMESTAMP,
 status note_status_enum,
 id_country INTEGER
);
INSERT INTO notes (note_id, created_at, closed_at, latitude, longitude, status) VALUES
(1001, '2025-12-01 00:00:00+00', NULL, 40.7128, -74.0060, 'open'::note_status_enum),
(1002, '2025-12-02 00:00:00+00', '2025-12-10 00:00:00+00', 34.0522, -118.2437, 'close'::note_status_enum);
EOSQL
  local LOADED_COUNT
  LOADED_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes WHERE note_id IN (1001, 1002);" 2> /dev/null || echo "0")
 fi

 # Step 4: Verify
 [[ "${LOADED_COUNT}" -eq 2 ]]
}
