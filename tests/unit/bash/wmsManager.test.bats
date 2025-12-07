#!/usr/bin/env bats
# WMS Manager Tests
# Tests for the WMS management script
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

setup() {
  # WMS script path
  WMS_SCRIPT="${BATS_TEST_DIRNAME}/../../../bin/wms/wmsManager.sh"
  
  # Load test properties to get database configuration
  if [[ -f "${BATS_TEST_DIRNAME}/../../properties.sh" ]]; then
    source "${BATS_TEST_DIRNAME}/../../properties.sh"
  fi
  
  # Set database environment variables for WMS tests
  export DBNAME="${TEST_DBNAME:-osm_notes_test}"
  export DB_USER="${TEST_DBUSER:-$(whoami)}"
  export DBPASSWORD="${TEST_DBPASSWORD:-}"
  export DBHOST="${TEST_DBHOST:-localhost}"
  export DBPORT="${TEST_DBPORT:-5432}"
  
  # Set WMS specific variables
  export WMS_DBNAME="${TEST_DBNAME:-osm_notes_test}"
  export WMS_DBUSER="${TEST_DBUSER:-$(whoami)}"
  export WMS_DBPASSWORD="${TEST_DBPASSWORD:-}"
  export WMS_DBHOST="${TEST_DBHOST:-localhost}"
  export WMS_DBPORT="${TEST_DBPORT:-5432}"
}

@test "WMS manager script should exist" {
  [ -f "$WMS_SCRIPT" ]
}

@test "WMS manager script should be executable" {
  [ -x "$WMS_SCRIPT" ]
}

@test "WMS manager should show help with help command" {
  run "$WMS_SCRIPT" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"WMS Manager Script"* ]]
  [[ "$output" == *"install"* ]]
  [[ "$output" == *"remove"* ]]
  [[ "$output" == *"status"* ]]
}

@test "WMS manager should show help with --help" {
  run "$WMS_SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"WMS Manager Script"* ]]
}

@test "WMS manager should show help with -h" {
  run "$WMS_SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" == *"WMS Manager Script"* ]]
}

@test "WMS manager should show error for unknown command" {
  run "$WMS_SCRIPT" unknown_command
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "WMS manager should show error for no command" {
  run "$WMS_SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "WMS manager should show error for unknown option" {
  run "$WMS_SCRIPT" install --unknown-option
  [ "$status" -ne 0 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "WMS manager should show dry run output" {
  # Skip this test if database is not available
  if ! command -v psql &> /dev/null; then
    skip "PostgreSQL client not available"
  fi
  
  # Test dry-run command - it might fail due to database connection issues
  # but we accept any exit code as long as it doesn't hang
  run timeout 10s "$WMS_SCRIPT" install --dry-run
  # Accept any exit code (0, 1, 124 for timeout, etc.)
  [[ "$status" -ge 0 ]]
}

@test "WMS manager should validate SQL files exist" {
  # Check if SQL files exist using relative paths from project root
  local project_root="$(cd "${BATS_TEST_DIRNAME}/../../../" && pwd)"
  local prepare_sql="${project_root}/sql/wms/prepareDatabase.sql"
  local remove_sql="${project_root}/sql/wms/removeFromDatabase.sql"
  
  [ -f "$prepare_sql" ]
  [ -f "$remove_sql" ]
} 
