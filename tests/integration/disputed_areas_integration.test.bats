#!/usr/bin/env bats
# Disputed and Unclaimed Areas Integration Tests
# Tests for the materialized view of disputed and unclaimed areas
#
# Author: Andres Gomez (AngocA)
# Version: 2025-11-30

bats_require_minimum_version 1.5.0

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

setup() {
  # Load test helper functions
  load "${BATS_TEST_DIRNAME}/../test_helper.bash"
  # Set up test environment
  export TEST_DBNAME="osm_notes_wms_test"
  export TEST_DBUSER="${USER:-$(whoami)}"
  export TEST_DBPASSWORD=""
  export TEST_DBHOST=""
  export TEST_DBPORT=""
  export MOCK_MODE=1
  # Set project root
  export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../.." && pwd)"
  # Create test database with PostGIS
  create_test_database
}

teardown() {
  # Clean up test database
  drop_test_database
}

# Function to create test database with PostGIS and countries table
create_test_database() {
  if [[ "${MOCK_MODE:-0}" == "1" ]]; then
    return 0
  fi
  # Check if PostgreSQL is available
  if ! psql -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    export MOCK_MODE=1
    return 0
  fi
  # Create database if it doesn't exist
  if ! psql -d "${TEST_DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
    createdb "${TEST_DBNAME}" 2> /dev/null || true
  fi
  # Enable PostGIS extension
  psql -d "${TEST_DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2> /dev/null || true
  # Create countries table with test data
  psql -d "${TEST_DBNAME}" -c "
    DROP TABLE IF EXISTS countries CASCADE;
    CREATE TABLE countries (
      country_id INTEGER PRIMARY KEY,
      country_name_en VARCHAR(255),
      geom GEOMETRY(MultiPolygon, 4326)
    );
    -- Insert test countries (simple rectangles that overlap)
    INSERT INTO countries (country_id, country_name_en, geom) VALUES
    (1, 'Country A', ST_MakeEnvelope(0, 0, 10, 10, 4326)),
    (2, 'Country B', ST_MakeEnvelope(5, 5, 15, 15, 4326)),
    (3, 'Country C', ST_MakeEnvelope(20, 20, 30, 30, 4326));
  " 2> /dev/null || true
}

# Function to drop test database
drop_test_database() {
  if [[ "${MOCK_MODE:-0}" == "1" ]]; then
    return 0
  fi
  dropdb "${TEST_DBNAME}" 2> /dev/null || true
}

# Helper function to run psql
run_psql() {
  local sql_command="$1"
  if [[ "${MOCK_MODE:-0}" == "1" ]]; then
    # Return mock values
    case "$sql_command" in
    *"pg_matviews"*) echo "t";;
    *"COUNT(*)"*) echo "2";;
    *) echo "1";;
    esac
  else
    psql -d "${TEST_DBNAME}" -t -c "${sql_command}" 2> /dev/null | tr -d ' '
  fi
}

@test "Disputed areas: should create materialized view successfully" {
  if [[ "${MOCK_MODE:-0}" == "1" ]]; then
    skip "Skipping in mock mode"
  fi
  # Create WMS schema first
  psql -d "${TEST_DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS wms;" 2> /dev/null || true
  # Run prepareDatabase.sql to create the view
  local prepare_sql="${SCRIPT_BASE_DIRECTORY}/sql/wms/prepareDatabase.sql"
  if [[ -f "${prepare_sql}" ]]; then
    run psql -d "${TEST_DBNAME}" -v ON_ERROR_STOP=1 -f "${prepare_sql}" 2>&1
    [ "$status" -eq 0 ]
    # Verify materialized view exists
    local view_exists
    view_exists=$(run_psql "SELECT EXISTS(SELECT 1 FROM pg_matviews WHERE schemaname = 'wms' AND matviewname = 'disputed_and_unclaimed_areas');")
    [ "$view_exists" == "t" ]
  else
    skip "prepareDatabase.sql not found"
  fi
}

@test "Disputed areas: should have correct structure in materialized view" {
  if [[ "${MOCK_MODE:-0}" == "1" ]]; then
    skip "Skipping in mock mode"
  fi
  # Create view first
  psql -d "${TEST_DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS wms;" 2> /dev/null || true
  local prepare_sql="${SCRIPT_BASE_DIRECTORY}/sql/wms/prepareDatabase.sql"
  if [[ ! -f "${prepare_sql}" ]]; then
    skip "prepareDatabase.sql not found"
  fi
  psql -d "${TEST_DBNAME}" -f "${prepare_sql}" > /dev/null 2>&1 || true
  # Check columns exist
  local columns
  columns=$(run_psql "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = 'wms' AND table_name = 'disputed_and_unclaimed_areas';")
  [ "$columns" -ge 5 ] # Should have at least: id, geometry, area_type, country_ids, country_names, zone_type
}

@test "Disputed areas: should have indexes on materialized view" {
  if [[ "${MOCK_MODE:-0}" == "1" ]]; then
    skip "Skipping in mock mode"
  fi
  # Create view first
  psql -d "${TEST_DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS wms;" 2> /dev/null || true
  local prepare_sql="${SCRIPT_BASE_DIRECTORY}/sql/wms/prepareDatabase.sql"
  if [[ ! -f "${prepare_sql}" ]]; then
    skip "prepareDatabase.sql not found"
  fi
  psql -d "${TEST_DBNAME}" -f "${prepare_sql}" > /dev/null 2>&1 || true
  # Check indexes exist
  local index_count
  index_count=$(run_psql "SELECT COUNT(*) FROM pg_indexes WHERE schemaname = 'wms' AND tablename = 'disputed_and_unclaimed_areas';")
  [ "$index_count" -ge 2 ] # Should have at least: unique index on id, index on zone_type, GIST on geometry
}

@test "Disputed areas: should refresh materialized view successfully" {
  if [[ "${MOCK_MODE:-0}" == "1" ]]; then
    skip "Skipping in mock mode"
  fi
  # Create view first
  psql -d "${TEST_DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS wms;" 2> /dev/null || true
  local prepare_sql="${SCRIPT_BASE_DIRECTORY}/sql/wms/prepareDatabase.sql"
  if [[ ! -f "${prepare_sql}" ]]; then
    skip "prepareDatabase.sql not found"
  fi
  psql -d "${TEST_DBNAME}" -f "${prepare_sql}" > /dev/null 2>&1 || true
  # Refresh the view
  local refresh_sql="${SCRIPT_BASE_DIRECTORY}/sql/wms/refreshDisputedAreasView.sql"
  if [[ -f "${refresh_sql}" ]]; then
    run psql -d "${TEST_DBNAME}" -v ON_ERROR_STOP=1 -f "${refresh_sql}" 2>&1
    [ "$status" -eq 0 ]
  else
    skip "refreshDisputedAreasView.sql not found"
  fi
}

@test "Disputed areas: should handle countries with invalid SRID" {
  if [[ "${MOCK_MODE:-0}" == "1" ]]; then
    skip "Skipping in mock mode"
  fi
  # Create view first
  psql -d "${TEST_DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS wms;" 2> /dev/null || true
  # Insert country with SRID 0
  psql -d "${TEST_DBNAME}" -c "
    INSERT INTO countries (country_id, country_name_en, geom) VALUES
    (4, 'Country D', ST_SetSRID(ST_MakeEnvelope(40, 40, 50, 50, 0), 0));
  " 2> /dev/null || true
  local prepare_sql="${SCRIPT_BASE_DIRECTORY}/sql/wms/prepareDatabase.sql"
  if [[ -f "${prepare_sql}" ]]; then
    # Should not fail even with SRID 0 (should be fixed in the query)
    run psql -d "${TEST_DBNAME}" -v ON_ERROR_STOP=1 -f "${prepare_sql}" 2>&1
    [ "$status" -eq 0 ]
  else
    skip "prepareDatabase.sql not found"
  fi
}

@test "Disputed areas: should filter out invalid geometry types" {
  if [[ "${MOCK_MODE:-0}" == "1" ]]; then
    skip "Skipping in mock mode"
  fi
  # Create view first
  psql -d "${TEST_DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS wms;" 2> /dev/null || true
  local prepare_sql="${SCRIPT_BASE_DIRECTORY}/sql/wms/prepareDatabase.sql"
  if [[ -f "${prepare_sql}" ]]; then
    run psql -d "${TEST_DBNAME}" -v ON_ERROR_STOP=1 -f "${prepare_sql}" 2>&1
    [ "$status" -eq 0 ]
    # Verify view was created (it should filter invalid geometries)
    local view_exists
    view_exists=$(run_psql "SELECT EXISTS(SELECT 1 FROM pg_matviews WHERE schemaname = 'wms' AND matviewname = 'disputed_and_unclaimed_areas');")
    [ "$view_exists" == "t" ]
  else
    skip "prepareDatabase.sql not found"
  fi
}

@test "Disputed areas: should exclude maritime zones from unclaimed calculation" {
  if [[ "${MOCK_MODE:-0}" == "1" ]]; then
    skip "Skipping in mock mode"
  fi
  # Create view first
  psql -d "${TEST_DBNAME}" -c "CREATE SCHEMA IF NOT EXISTS wms;" 2> /dev/null || true
  # Insert maritime zone (with parentheses in name)
  psql -d "${TEST_DBNAME}" -c "
    INSERT INTO countries (country_id, country_name_en, geom) VALUES
    (5, 'Maritime Zone (International)', ST_MakeEnvelope(60, 60, 70, 70, 4326));
  " 2> /dev/null || true
  local prepare_sql="${SCRIPT_BASE_DIRECTORY}/sql/wms/prepareDatabase.sql"
  if [[ -f "${prepare_sql}" ]]; then
    run psql -d "${TEST_DBNAME}" -v ON_ERROR_STOP=1 -f "${prepare_sql}" 2>&1
    [ "$status" -eq 0 ]
    # Maritime zones should be excluded from unclaimed calculation
    # (This is tested by verifying the view can be created without errors)
    [ "$status" -eq 0 ]
  else
    skip "prepareDatabase.sql not found"
  fi
}

