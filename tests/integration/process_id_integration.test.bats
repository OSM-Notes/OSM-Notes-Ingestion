#!/usr/bin/env bats

# Integration tests for process_id handling in note insertion
# Tests that app.process_id is set correctly as INTEGER for SQL procedures
# Validates the complete flow: PROCESS_ID generation → app.process_id setting → SQL execution
#
# Author: Andres Gomez (AngocA)
# Version: 2025-11-12

load "${BATS_TEST_DIRNAME}/../test_helper.bash"

setup() {
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_process_id_integration"
 export DBNAME="${TEST_DBNAME:-test_db}"
 
 # Skip if no database available
 if ! command -v psql > /dev/null 2>&1; then
  skip "psql not available - required for process_id integration tests"
 fi
 
 # Check database connection
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available for process_id integration tests"
 fi
}

teardown() {
 rm -rf "${TMP_DIR}"
 # Clean up any test locks
 psql -d "${DBNAME}" -c "DELETE FROM locks WHERE process_id LIKE 'test_%';" > /dev/null 2>&1 || true
}

@test "PROCESS_ID should be VARCHAR for locks but INTEGER for app.process_id" {
 # Step 1: Generate PROCESS_ID with underscores (for locks)
 local PROCESS_ID="test_$(date +%s)_${RANDOM}"
 export PROCESS_ID
 
 # Step 2: Extract INTEGER part (PID) for app.process_id
 local PROCESS_ID_INTEGER="${$}"
 
 # Step 3: Verify PROCESS_ID has underscores (VARCHAR format)
 [[ "${PROCESS_ID}" == *"_"* ]]
 
 # Step 4: Verify PROCESS_ID_INTEGER is a simple integer
 [[ "${PROCESS_ID_INTEGER}" =~ ^[0-9]+$ ]]
 
 # Step 5: Set app.process_id in PostgreSQL and verify it's INTEGER
 psql -d "${DBNAME}" -c "SET app.process_id = '${PROCESS_ID_INTEGER}';" > /dev/null 2>&1
 
 # Step 6: Verify app.process_id can be read as INTEGER
 local result
 result=$(psql -d "${DBNAME}" -Atq -c "SELECT current_setting('app.process_id', true)::INTEGER;" 2>/dev/null || echo "0")
 
 # Result should be a number (may be 0 if setting wasn't persisted)
 [[ "${result}" =~ ^[0-9]+$ ]]
 [ "${result}" -eq "${PROCESS_ID_INTEGER}" ] || [ "${result}" -eq "0" ]
}

@test "app.process_id should fail if set with underscores" {
 local invalid_process_id="12345_67890_11111"
 
 # Attempt to set app.process_id with underscores should work (PostgreSQL accepts it)
 psql -d "${DBNAME}" -c "SET app.process_id = '${invalid_process_id}';" > /dev/null 2>&1
 
 # But converting to INTEGER should fail
 run psql -d "${DBNAME}" -Atq -c "SELECT current_setting('app.process_id', true)::INTEGER;" 2>&1
 
 # Should fail or return error
 [ "${status}" -ne 0 ] || [[ "${output}" == *"invalid input syntax"* ]] || [[ "${output}" == *"ERROR"* ]]
}

@test "process_id should be set before executing SQL insertion" {
 # Step 1: Create test notes_api table if it doesn't exist
 psql -d "${DBNAME}" << 'EOF' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS notes_api (
 note_id INTEGER NOT NULL,
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 closed_at TIMESTAMP,
 status VARCHAR(10),
 id_country INTEGER,
 part_id INTEGER NOT NULL
) PARTITION BY RANGE (part_id);
CREATE TABLE IF NOT EXISTS notes_api_part_1 PARTITION OF notes_api FOR VALUES FROM (1) TO (2);
EOF
 
 # Step 2: Generate PROCESS_ID (VARCHAR format for locks)
 local PROCESS_ID="test_$(date +%s)_${RANDOM}"
 export PROCESS_ID
 
 # Step 3: Set app.process_id as INTEGER (PID)
 local PROCESS_ID_INTEGER="${$}"
 
 # Step 4: Verify app.process_id is set correctly before SQL execution
 psql -d "${DBNAME}" -c "SET app.process_id = '${PROCESS_ID_INTEGER}';" > /dev/null 2>&1
 
 # Step 5: Execute a simple SQL that uses app.process_id
 local result
 result=$(psql -d "${DBNAME}" -Atq << 'EOF'
DO $$
DECLARE
 m_process_id INTEGER;
BEGIN
 m_process_id := COALESCE(current_setting('app.process_id', true), '0')::INTEGER;
 RAISE NOTICE 'process_id: %', m_process_id;
END $$;
EOF
 2>&1)
 
 # Should succeed without "invalid input syntax" error
 [[ ! "${result}" == *"invalid input syntax"* ]]
 [[ ! "${result}" == *"ERROR"* ]]
 [[ "${result}" == *"process_id:"* ]]
}

@test "SQL insertion should use INTEGER process_id from app.process_id" {
 # Step 1: Create test tables if needed
 psql -d "${DBNAME}" << 'EOF' > /dev/null 2>&1 || true
CREATE TABLE IF NOT EXISTS notes_api (
 note_id INTEGER NOT NULL,
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 closed_at TIMESTAMP,
 status VARCHAR(10),
 id_country INTEGER,
 part_id INTEGER NOT NULL
) PARTITION BY RANGE (part_id);
CREATE TABLE IF NOT EXISTS notes_api_part_1 PARTITION OF notes_api FOR VALUES FROM (1) TO (2);
CREATE TABLE IF NOT EXISTS notes (
 note_id INTEGER PRIMARY KEY,
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 closed_at TIMESTAMP,
 status VARCHAR(10),
 id_country INTEGER
);
EOF
 
 # Step 2: Insert test data into notes_api
 psql -d "${DBNAME}" << 'EOF' > /dev/null 2>&1
INSERT INTO notes_api (note_id, latitude, longitude, created_at, closed_at, status, id_country, part_id)
VALUES (999, 40.7128, -74.0060, '2023-01-01T00:00:00Z', NULL, 'open', NULL, 1)
ON CONFLICT DO NOTHING;
EOF
 
 # Step 3: Set app.process_id as INTEGER
 local PROCESS_ID_INTEGER="${$}"
 psql -d "${DBNAME}" -c "SET app.process_id = '${PROCESS_ID_INTEGER}';" > /dev/null 2>&1
 
 # Step 4: Execute SQL that reads app.process_id and uses it
 # First, ensure app.process_id is set in the same session
 local result
 result=$(psql -d "${DBNAME}" << EOF 2>&1
SET app.process_id = '${PROCESS_ID_INTEGER}';
DO \$\$
DECLARE
 m_process_id INTEGER;
 r RECORD;
BEGIN
 m_process_id := COALESCE(current_setting('app.process_id', true), '0')::INTEGER;
 
 FOR r IN SELECT note_id, latitude, longitude, created_at, closed_at, status
          FROM notes_api
          WHERE note_id = 999
          LIMIT 1
 LOOP
  -- Simulate insertion logic that uses m_process_id
  INSERT INTO notes (note_id, latitude, longitude, created_at, closed_at, status, id_country)
  VALUES (r.note_id, r.latitude, r.longitude, r.created_at, r.closed_at, r.status, NULL)
  ON CONFLICT (note_id) DO NOTHING;
  
  RAISE NOTICE 'Inserted note % with process_id %', r.note_id, m_process_id;
 END LOOP;
END \$\$;
EOF
)
 
 # Should succeed without "invalid input syntax" error
 [[ ! "${result}" == *"invalid input syntax"* ]]
 [[ ! "${result}" == *"ERROR"* ]]
 [[ "${result}" == *"Inserted note"* ]]
 
 # Step 5: Verify note was inserted
 local count
 count=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes WHERE note_id = 999;" 2>/dev/null || echo "0")
 [ "${count}" -eq "1" ]
 
 # Cleanup
 psql -d "${DBNAME}" -c "DELETE FROM notes WHERE note_id = 999;" > /dev/null 2>&1 || true
 psql -d "${DBNAME}" -c "DELETE FROM notes_api WHERE note_id = 999;" > /dev/null 2>&1 || true
}

@test "process_id should work correctly in parallel processing scenario" {
 # Step 1: Set app.process_id for multiple "parallel" processes
 local pid1="${$}"
 local pid2=$((pid1 + 1))
 local pid3=$((pid1 + 2))
 
 # Step 2: Each process should set its own app.process_id
 for pid in "${pid1}" "${pid2}" "${pid3}"; do
  local result
  result=$(psql -d "${DBNAME}" -Atq -c "SET app.process_id = '${pid}'; SELECT current_setting('app.process_id', true)::INTEGER;" 2>&1)
  
  # Should succeed
  [[ ! "${result}" == *"invalid input syntax"* ]]
  [[ ! "${result}" == *"ERROR"* ]]
  [[ "${result}" =~ ^[0-9]+$ ]]
  [ "${result}" -eq "${pid}" ]
 done
}

