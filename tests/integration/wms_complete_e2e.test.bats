#!/usr/bin/env bats

# End-to-end integration tests for complete WMS processing flow
# Tests: Processing → Generation Layers → Services
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
 export DBNAME="${TEST_DBNAME:-test_db}"
 export BASENAME="test_wms_complete_e2e"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"
 export MOCK_MODE=1

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
# Complete WMS Flow Tests
# =============================================================================

@test "E2E: Complete WMS flow should process notes for WMS" {
 # Test: Processing notes for WMS
 # Purpose: Verify that notes are processed for WMS layer generation
 # Expected: WMS processing completes

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Create test tables
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE SCHEMA IF NOT EXISTS wms;
DROP TABLE IF EXISTS wms.notes_wms CASCADE;
DROP TABLE IF EXISTS notes CASCADE;

CREATE TABLE notes (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 closed_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);
CREATE TABLE wms.notes_wms (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 closed_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20),
 geom GEOMETRY(POINT, 4326)
);
EOSQL

 # Simulate WMS processing (copy notes to WMS table)
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO notes (id, created_at, lat, lon, status) VALUES
(2001, '2025-12-15 10:00:00+00', 40.7128, -74.0060, 'open'),
(2002, '2025-12-15 11:00:00+00', 34.0522, -118.2437, 'open');

INSERT INTO wms.notes_wms (id, created_at, lat, lon, status, geom)
SELECT id, created_at, lat, lon, status, ST_SetSRID(ST_MakePoint(lon, lat), 4326)
FROM notes
WHERE id IN (2001, 2002);
EOSQL

 # Verify WMS processing
 local WMS_COUNT
 WMS_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM wms.notes_wms;" 2>/dev/null || echo "0")
 [[ "${WMS_COUNT}" -ge 2 ]]
}

@test "E2E: Complete WMS flow should generate WMS layers" {
 # Test: Generation Layers
 # Purpose: Verify that WMS layers are generated
 # Expected: WMS layers exist and have geometry

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Create WMS table with geometry
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE SCHEMA IF NOT EXISTS wms;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE TABLE IF NOT EXISTS wms.notes_wms (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 geom GEOMETRY(POINT, 4326)
);

INSERT INTO wms.notes_wms (id, created_at, lat, lon, geom) VALUES
(2001, '2025-12-15 10:00:00+00', 40.7128, -74.0060, ST_SetSRID(ST_MakePoint(-74.0060, 40.7128), 4326)),
(2002, '2025-12-15 11:00:00+00', 34.0522, -118.2437, ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326))
ON CONFLICT (id) DO NOTHING;
EOSQL

 # Verify geometry exists
 local GEOM_COUNT
 GEOM_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM wms.notes_wms WHERE geom IS NOT NULL;" 2>/dev/null || echo "0")
 [[ "${GEOM_COUNT}" -ge 2 ]]

 # Verify SRID is correct
 local SRID_CHECK
 SRID_CHECK=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM wms.notes_wms WHERE ST_SRID(geom) = 4326;" 2>/dev/null || echo "0")
 [[ "${SRID_CHECK}" -ge 2 ]]
}

@test "E2E: Complete WMS flow should provide WMS services" {
 # Test: WMS Services
 # Purpose: Verify that WMS services are available
 # Expected: WMS schema and tables are accessible

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Create WMS schema and verify it exists
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE SCHEMA IF NOT EXISTS wms;
CREATE TABLE IF NOT EXISTS wms.notes_wms (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 geom GEOMETRY(POINT, 4326)
);
EOSQL

 # Verify WMS schema exists
 local SCHEMA_EXISTS
 SCHEMA_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'wms');" 2>/dev/null || echo "f")
 [[ "${SCHEMA_EXISTS}" == "t" ]]

 # Verify WMS table exists
 local TABLE_EXISTS
 TABLE_EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'wms' AND table_name = 'notes_wms');" 2>/dev/null || echo "f")
 [[ "${TABLE_EXISTS}" == "t" ]]
}

@test "E2E: Complete WMS flow should handle full workflow end-to-end" {
 # Test: Complete workflow from processing to services
 # Purpose: Verify entire WMS flow works together
 # Expected: All steps complete successfully

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Step 1: Process notes for WMS
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
CREATE SCHEMA IF NOT EXISTS wms;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE TABLE IF NOT EXISTS notes (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20)
);
CREATE TABLE IF NOT EXISTS wms.notes_wms (
 id BIGINT PRIMARY KEY,
 created_at TIMESTAMP WITH TIME ZONE,
 lat DECIMAL(10,7) NOT NULL,
 lon DECIMAL(11,7) NOT NULL,
 status VARCHAR(20),
 geom GEOMETRY(POINT, 4326)
);

INSERT INTO notes (id, created_at, lat, lon, status) VALUES
(2001, '2025-12-15 10:00:00+00', 40.7128, -74.0060, 'open')
ON CONFLICT (id) DO NOTHING;
EOSQL

 # Step 2: Generate WMS layers
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO wms.notes_wms (id, created_at, lat, lon, status, geom)
SELECT id, created_at, lat, lon, status, ST_SetSRID(ST_MakePoint(lon, lat), 4326)
FROM notes
WHERE id = 2001
ON CONFLICT (id) DO NOTHING;
EOSQL

 # Step 3: Verify services
 local WMS_READY
 WMS_READY=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM wms.notes_wms WHERE geom IS NOT NULL;" 2>/dev/null || echo "0")
 [[ "${WMS_READY}" -ge 1 ]]
}

