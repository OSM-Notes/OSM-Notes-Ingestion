#!/usr/bin/env bats
# WMS Integration Tests
# Tests for the WMS manager script with actual database operations
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

setup() {
  # Load test helper functions
  load "${BATS_TEST_DIRNAME}/../test_helper.bash"
  
  # Set up test environment
  export TEST_DBNAME="osm_notes_wms_test"
  export TEST_DBUSER="testuser"
  export TEST_DBPASSWORD="testpass"
  export TEST_DBHOST="localhost"
  export TEST_DBPORT="5432"
  
  # WMS script path
  WMS_SCRIPT="${BATS_TEST_DIRNAME}/../../bin/wms/wmsManager.sh"
  
  # Create test database with required extensions
  create_wms_test_database
}

teardown() {
  # Clean up test database
  drop_wms_test_database
}

# Function to create WMS test database with PostGIS
create_wms_test_database() {
  echo "Creating WMS test database..."
  
  # Create database
  createdb -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" "${TEST_DBNAME}" 2>/dev/null || true
  
  # Enable PostGIS extension
  psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>/dev/null || true
  
  # Create basic notes table structure
  psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    CREATE TABLE IF NOT EXISTS notes (
      note_id INTEGER PRIMARY KEY,
      created_at TIMESTAMP,
      closed_at TIMESTAMP,
      lon DOUBLE PRECISION,
      lat DOUBLE PRECISION
    );
  " 2>/dev/null || true
  
  # Insert test data
  psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
    INSERT INTO notes (note_id, created_at, closed_at, lon, lat) VALUES
    (1, '2023-01-01 10:00:00', NULL, -74.006, 40.7128),
    (2, '2023-02-01 11:00:00', '2023-02-15 12:00:00', -118.2437, 34.0522),
    (3, '2023-03-01 09:00:00', NULL, 2.3522, 48.8566)
    ON CONFLICT (note_id) DO NOTHING;
  " 2>/dev/null || true
}

# Function to drop WMS test database
drop_wms_test_database() {
  echo "Dropping WMS test database..."
  dropdb -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" "${TEST_DBNAME}" 2>/dev/null || true
}

@test "WMS integration: should install WMS components successfully" {
  # Set database environment variables
  export DBNAME="${TEST_DBNAME}"
  export DBUSER="${TEST_DBUSER}"
  export DBPASSWORD="${TEST_DBPASSWORD}"
  export DBHOST="${TEST_DBHOST}"
  export DBPORT="${TEST_DBPORT}"
  export PGPASSWORD="${TEST_DBPASSWORD}"
  
  # Install WMS
  run "$WMS_SCRIPT" install
  [ "$status" -eq 0 ]
  [[ "$output" == *"installation completed successfully"* ]]
  
  # Verify WMS schema exists
  local schema_exists
  schema_exists=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'wms');" | tr -d ' ')
  [ "$schema_exists" == "t" ]
  
  # Verify WMS table exists
  local table_exists
  table_exists=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'wms' AND table_name = 'notes_wms');" | tr -d ' ')
  [ "$table_exists" == "t" ]
  
  # Verify triggers exist
  local trigger_count
  trigger_count=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_name IN ('insert_new_notes', 'update_notes');" | tr -d ' ')
  [ "$trigger_count" -eq 2 ]
}

@test "WMS integration: should show correct status after installation" {
  # Set database environment variables
  export DBNAME="${TEST_DBNAME}"
  export DBUSER="${TEST_DBUSER}"
  export DBPASSWORD="${TEST_DBPASSWORD}"
  export DBHOST="${TEST_DBHOST}"
  export DBPORT="${TEST_DBPORT}"
  export PGPASSWORD="${TEST_DBPASSWORD}"
  
  # Install WMS first
  "$WMS_SCRIPT" install > /dev/null
  
  # Check status
  run "$WMS_SCRIPT" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"WMS is installed"* ]]
  [[ "$output" == *"WMS Statistics"* ]]
  
  # Verify note count
  local note_count
  note_count=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM wms.notes_wms;" | tr -d ' ')
  [ "$note_count" -eq 3 ]  # Should have 3 notes from test data
}

@test "WMS integration: should not install twice without force" {
  # Set database environment variables
  export DBNAME="${TEST_DBNAME}"
  export DBUSER="${TEST_DBUSER}"
  export DBPASSWORD="${TEST_DBPASSWORD}"
  export DBHOST="${TEST_DBHOST}"
  export DBPORT="${TEST_DBPORT}"
  export PGPASSWORD="${TEST_DBPASSWORD}"
  
  # Install WMS first
  "$WMS_SCRIPT" install > /dev/null
  
  # Try to install again
  run "$WMS_SCRIPT" install
  [ "$status" -eq 0 ]
  [[ "$output" == *"already installed"* ]]
  [[ "$output" == *"Use --force"* ]]
}

@test "WMS integration: should force reinstall with --force" {
  # Set database environment variables
  export DBNAME="${TEST_DBNAME}"
  export DBUSER="${TEST_DBUSER}"
  export DBPASSWORD="${TEST_DBPASSWORD}"
  export DBHOST="${TEST_DBHOST}"
  export DBPORT="${TEST_DBPORT}"
  export PGPASSWORD="${TEST_DBPASSWORD}"
  
  # Install WMS first
  "$WMS_SCRIPT" install > /dev/null
  
  # Force reinstall
  run "$WMS_SCRIPT" install --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"Forcing reinstallation"* ]]
  [[ "$output" == *"installation completed successfully"* ]]
}

@test "WMS integration: should deinstall WMS components successfully" {
  # Set database environment variables
  export DBNAME="${TEST_DBNAME}"
  export DBUSER="${TEST_DBUSER}"
  export DBPASSWORD="${TEST_DBPASSWORD}"
  export DBHOST="${TEST_DBHOST}"
  export DBPORT="${TEST_DBPORT}"
  export PGPASSWORD="${TEST_DBPASSWORD}"
  
  # Install WMS first
  "$WMS_SCRIPT" install > /dev/null
  
  # Deinstall WMS
  run "$WMS_SCRIPT" deinstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"removal completed successfully"* ]]
  
  # Verify WMS schema is removed
  local schema_exists
  schema_exists=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'wms');" | tr -d ' ')
  [ "$schema_exists" == "f" ]
}

@test "WMS integration: should handle deinstall when not installed" {
  # Set database environment variables
  export DBNAME="${TEST_DBNAME}"
  export DBUSER="${TEST_DBUSER}"
  export DBPASSWORD="${TEST_DBPASSWORD}"
  export DBHOST="${TEST_DBHOST}"
  export DBPORT="${TEST_DBPORT}"
  export PGPASSWORD="${TEST_DBPASSWORD}"
  
  # Try to deinstall when not installed
  run "$WMS_SCRIPT" deinstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"not installed"* ]]
  [[ "$output" == *"Nothing to remove"* ]]
}

@test "WMS integration: should show dry run output" {
  # Set database environment variables
  export DBNAME="${TEST_DBNAME}"
  export DBUSER="${TEST_DBUSER}"
  export DBPASSWORD="${TEST_DBPASSWORD}"
  export DBHOST="${TEST_DBHOST}"
  export DBPORT="${TEST_DBPORT}"
  export PGPASSWORD="${TEST_DBPASSWORD}"
  
  # Test dry run
  run "$WMS_SCRIPT" install --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"DRY RUN"* ]]
  [[ "$output" == *"Would execute"* ]]
}

@test "WMS integration: should validate PostGIS requirement" {
  # Set database environment variables
  export DBNAME="${TEST_DBNAME}"
  export DBUSER="${TEST_DBUSER}"
  export DBPASSWORD="${TEST_DBPASSWORD}"
  export DBHOST="${TEST_DBHOST}"
  export DBPORT="${TEST_DBPORT}"
  export PGPASSWORD="${TEST_DBPASSWORD}"
  
  # Remove PostGIS extension temporarily
  psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "DROP EXTENSION IF EXISTS postgis;" 2>/dev/null || true
  
  # Try to install WMS
  run "$WMS_SCRIPT" install
  [ "$status" -eq 1 ]
  [[ "$output" == *"PostGIS extension is required"* ]]
  
  # Restore PostGIS
  psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>/dev/null || true
}

@test "WMS integration: should handle database connection errors" {
  # Test with invalid database
  export DBNAME="nonexistent_db"
  export DBUSER="${TEST_DBUSER}"
  export DBPASSWORD="${TEST_DBPASSWORD}"
  export DBHOST="${TEST_DBHOST}"
  export DBPORT="${TEST_DBPORT}"
  export PGPASSWORD="${TEST_DBPASSWORD}"
  
  run "$WMS_SCRIPT" install
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" == *"Cannot connect to database"* ]] || [[ "$output" == *"PostGIS extension is not installed"* ]]
}

@test "WMS integration: should handle missing required columns" {
  # Set database environment variables
  export DBNAME="${TEST_DBNAME}"
  export DBUSER="${TEST_DBUSER}"
  export DBPASSWORD="${TEST_DBPASSWORD}"
  export DBHOST="${TEST_DBHOST}"
  export DBPORT="${TEST_DBPORT}"
  export PGPASSWORD="${TEST_DBPASSWORD}"
  
  # Drop notes table to simulate missing columns
  psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "DROP TABLE IF EXISTS notes;" 2>/dev/null || true
  
  # Try to install WMS
  run "$WMS_SCRIPT" install
  [ "$status" -eq 1 ]
  [[ "$output" == *"Required columns"* ]]
  [[ "$output" == *"not found in notes table"* ]]
  
  # Restore notes table
  create_wms_test_database
} 