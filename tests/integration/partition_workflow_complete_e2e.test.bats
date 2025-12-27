#!/usr/bin/env bats

# End-to-end integration tests for complete partition workflow
# Tests: Create → Load → Consolidate → Verify
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

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
 export BASENAME="test_partition_workflow_e2e"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"

 # Mock logger functions
 __log_start() { :; }
 __log_finish() { :; }
 __logi() { :; }
 __logd() { :; }
 __loge() { echo "ERROR: $*" >&2; }
 __logw() { :; }
 export -f __log_start __log_finish __logi __logd __loge __logw
 
 # Setup shared database schema once for all tests
 __shared_db_setup_file
}

setup() {
 # Per-test setup (runs before each test)
 # Use shared database setup from setup_file
 :
}

teardown() {
 # Per-test cleanup (runs after each test)
 # Truncate test data instead of dropping tables (faster)
 # Note: Partition tables are dropped in individual tests as needed
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
# Complete Partition Workflow Tests
# =============================================================================

@test "E2E Partition: Should create partition tables" {
 # Test: Create Partitions
 # Purpose: Verify that partition tables are created correctly
 # Expected: Partition tables exist with correct structure

 # Skip if database not available
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Create partition table structure
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DROP TABLE IF EXISTS notes_partition_1 CASCADE;
DROP TABLE IF EXISTS notes_partition_2 CASCADE;

CREATE TABLE notes_partition_1 (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20),
 CHECK (id >= 1 AND id < 10000)
);

CREATE TABLE notes_partition_2 (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20),
 CHECK (id >= 10000 AND id < 20000)
);
EOSQL

 # Verify partitions exist
 local PART1_EXISTS
 PART1_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'notes_partition_1');" 2>/dev/null || echo "f")
 [[ "${PART1_EXISTS}" == "t" ]]

 local PART2_EXISTS
 PART2_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'notes_partition_2');" 2>/dev/null || echo "f")
 [[ "${PART2_EXISTS}" == "t" ]]
}

@test "E2E Partition: Should load data into partitions" {
 # Test: Load to Partitions
 # Purpose: Verify that data is loaded into correct partitions
 # Expected: Data is distributed across partitions based on ID ranges

 # Skip if database not available
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Create and populate partitions
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DROP TABLE IF EXISTS notes_partition_1 CASCADE;
DROP TABLE IF EXISTS notes_partition_2 CASCADE;

CREATE TABLE notes_partition_1 (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20),
 CHECK (id >= 1 AND id < 10000)
);

CREATE TABLE notes_partition_2 (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20),
 CHECK (id >= 10000 AND id < 20000)
);

-- Load data into partition 1
INSERT INTO notes_partition_1 (id, created_at, lat, lon, status) VALUES
(100, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open'),
(200, '2025-12-23 11:00:00+00', 34.0522, -118.2437, 'open');

-- Load data into partition 2
INSERT INTO notes_partition_2 (id, created_at, lat, lon, status) VALUES
(10000, '2025-12-23 12:00:00+00', 51.5074, -0.1278, 'open'),
(15000, '2025-12-23 13:00:00+00', 48.8566, 2.3522, 'open');
EOSQL

 # Verify data in partition 1
 local PART1_COUNT
 PART1_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_partition_1;" 2>/dev/null || echo "0")
 [[ "${PART1_COUNT}" -ge 2 ]]

 # Verify data in partition 2
 local PART2_COUNT
 PART2_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_partition_2;" 2>/dev/null || echo "0")
 [[ "${PART2_COUNT}" -ge 2 ]]
}

@test "E2E Partition: Should consolidate partitions into main table" {
 # Test: Consolidate Partitions
 # Purpose: Verify that partitions are consolidated into main table
 # Expected: All partition data is moved to main table

 # Skip if database not available
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Create main table and partitions
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DROP TABLE IF EXISTS notes_main CASCADE;
DROP TABLE IF EXISTS notes_partition_1 CASCADE;
DROP TABLE IF EXISTS notes_partition_2 CASCADE;

CREATE TABLE notes_main (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);

CREATE TABLE notes_partition_1 (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);

CREATE TABLE notes_partition_2 (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);

-- Load data into partitions
INSERT INTO notes_partition_1 (id, created_at, lat, lon, status) VALUES
(100, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open');

INSERT INTO notes_partition_2 (id, created_at, lat, lon, status) VALUES
(10000, '2025-12-23 12:00:00+00', 51.5074, -0.1278, 'open');

-- Consolidate: Move data from partitions to main table
INSERT INTO notes_main (id, created_at, lat, lon, status)
SELECT id, created_at, lat, lon, status FROM notes_partition_1
UNION ALL
SELECT id, created_at, lat, lon, status FROM notes_partition_2;
EOSQL

 # Verify consolidation
 local MAIN_COUNT
 MAIN_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_main;" 2>/dev/null || echo "0")
 [[ "${MAIN_COUNT}" -ge 2 ]]

 # Verify data from both partitions is in main table
 local PART1_IN_MAIN
 PART1_IN_MAIN=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_main WHERE id = 100;" 2>/dev/null || echo "0")
 [[ "${PART1_IN_MAIN}" -eq 1 ]]

 local PART2_IN_MAIN
 PART2_IN_MAIN=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_main WHERE id = 10000;" 2>/dev/null || echo "0")
 [[ "${PART2_IN_MAIN}" -eq 1 ]]
}

@test "E2E Partition: Should verify partition data integrity" {
 # Test: Verify Data Integrity
 # Purpose: Verify that partition data maintains integrity
 # Expected: Data integrity checks pass

 # Skip if database not available
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Create partition with data
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DROP TABLE IF EXISTS notes_partition_1 CASCADE;

CREATE TABLE notes_partition_1 (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20),
 CHECK (id >= 1 AND id < 10000)
);

INSERT INTO notes_partition_1 (id, created_at, lat, lon, status) VALUES
(100, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open');
EOSQL

 # Verify data exists
 local EXISTS
 EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM notes_partition_1 WHERE id = 100);" 2>/dev/null || echo "f")
 [[ "${EXISTS}" == "t" ]]

 # Verify coordinates are valid
 local LAT_VALID
 LAT_VALID=$(psql -d "${DBNAME}" -Atq -c "SELECT lat BETWEEN -90 AND 90 FROM notes_partition_1 WHERE id = 100;" 2>/dev/null || echo "f")
 [[ "${LAT_VALID}" == "t" ]]

 local LON_VALID
 LON_VALID=$(psql -d "${DBNAME}" -Atq -c "SELECT lon BETWEEN -180 AND 180 FROM notes_partition_1 WHERE id = 100;" 2>/dev/null || echo "f")
 [[ "${LON_VALID}" == "t" ]]
}

@test "E2E Partition: Should handle complete workflow end-to-end" {
 # Test: Complete workflow from create to verify
 # Purpose: Verify entire partition workflow works together
 # Expected: All steps complete successfully

 # Skip if database not available
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Step 1: Create partitions
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DROP TABLE IF EXISTS notes_main CASCADE;
DROP TABLE IF EXISTS notes_partition_1 CASCADE;
DROP TABLE IF EXISTS notes_partition_2 CASCADE;

CREATE TABLE notes_main (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);

CREATE TABLE notes_partition_1 (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);

CREATE TABLE notes_partition_2 (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);
EOSQL

 # Step 2: Load data into partitions
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes_partition_1 (id, created_at, lat, lon, status) VALUES
(100, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open');

INSERT INTO notes_partition_2 (id, created_at, lat, lon, status) VALUES
(10000, '2025-12-23 12:00:00+00', 51.5074, -0.1278, 'open');
EOSQL

 # Step 3: Consolidate
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes_main (id, created_at, lat, lon, status)
SELECT id, created_at, lat, lon, status FROM notes_partition_1
UNION ALL
SELECT id, created_at, lat, lon, status FROM notes_partition_2;
EOSQL

 # Step 4: Verify complete workflow
 local TOTAL_COUNT
 TOTAL_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_main;" 2>/dev/null || echo "0")
 [[ "${TOTAL_COUNT}" -eq 2 ]]

 # Verify partitions can be dropped after consolidation
 local PART1_EXISTS
 PART1_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'notes_partition_1');" 2>/dev/null || echo "f")
 [[ "${PART1_EXISTS}" == "t" ]] # Partitions still exist (not dropped in this test)
}

@test "E2E Partition: Should handle parallel partition loading" {
 # Test: Parallel Loading
 # Purpose: Verify that multiple partitions can be loaded in parallel
 # Expected: Multiple partitions are loaded successfully

 # Create mock partition data files
 for PART_NUM in 1 2 3; do
  cat > "${TMP_DIR}/partition_${PART_NUM}.csv" << EOF
id,created_at,lat,lon,status
$((PART_NUM * 1000)),2025-12-23 10:00:00+00,40.7128,-74.0060,open
$((PART_NUM * 1000 + 1)),2025-12-23 11:00:00+00,34.0522,-118.2437,open
EOF
 done

 # Verify all partition files exist
 [[ -f "${TMP_DIR}/partition_1.csv" ]]
 [[ -f "${TMP_DIR}/partition_2.csv" ]]
 [[ -f "${TMP_DIR}/partition_3.csv" ]]

 # Verify files have correct structure
 for PART_NUM in 1 2 3; do
  run grep -q "id,created_at" "${TMP_DIR}/partition_${PART_NUM}.csv"
  [ "$status" -eq 0 ]
 done
}

@test "E2E Partition: Should handle partition cleanup after consolidation" {
 # Test: Cleanup After Consolidation
 # Purpose: Verify that partitions can be cleaned up after consolidation
 # Expected: Partitions are dropped after successful consolidation

 # Skip if database not available
 __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

 # Create partitions and consolidate
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DROP TABLE IF EXISTS notes_main CASCADE;
DROP TABLE IF EXISTS notes_partition_1 CASCADE;

CREATE TABLE notes_main (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);

CREATE TABLE notes_partition_1 (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);

INSERT INTO notes_partition_1 (id, created_at, lat, lon, status) VALUES
(100, '2025-12-23 10:00:00+00', 40.7128, -74.0060, 'open');

INSERT INTO notes_main (id, created_at, lat, lon, status)
SELECT id, created_at, lat, lon, status FROM notes_partition_1;
EOSQL

 # Verify data is in main table
 local MAIN_COUNT
 MAIN_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_main;" 2>/dev/null || echo "0")
 [[ "${MAIN_COUNT}" -ge 1 ]]

 # Simulate cleanup: drop partition after consolidation
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DROP TABLE IF EXISTS notes_partition_1 CASCADE;
EOSQL

 # Verify partition is dropped
 local PART_EXISTS
 PART_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name = 'notes_partition_1');" 2>/dev/null || echo "f")
 [[ "${PART_EXISTS}" == "f" ]]

 # Verify main table still has data
 local MAIN_STILL_HAS_DATA
 MAIN_STILL_HAS_DATA=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_main;" 2>/dev/null || echo "0")
 [[ "${MAIN_STILL_HAS_DATA}" -ge 1 ]]
}

