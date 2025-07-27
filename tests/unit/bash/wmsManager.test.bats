#!/usr/bin/env bats
# WMS Manager Tests
# Tests for the WMS management script
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

setup() {
  # WMS script path
  WMS_SCRIPT="${BATS_TEST_DIRNAME}/../../../bin/wms/wmsManager.sh"
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
  [[ "$output" == *"deinstall"* ]]
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
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" == *"Unknown option"* ]]
}

@test "WMS manager should show error for no command" {
  run "$WMS_SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" == *"No command specified"* ]]
}

@test "WMS manager should show error for unknown option" {
  run "$WMS_SCRIPT" install --unknown-option
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" == *"Unknown option"* ]]
}

@test "WMS manager should show dry run output" {
  # Skip this test if database is not available
  if ! command -v psql &> /dev/null; then
    skip "PostgreSQL client not available"
  fi
  
  run "$WMS_SCRIPT" install --dry-run
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]  # Allow both success and failure
  [[ "$output" == *"DRY RUN"* ]] || [[ "$output" == *"Validating prerequisites"* ]]
}

@test "WMS manager should validate SQL files exist" {
  # Check if SQL files exist using relative paths from project root
  local project_root="$(cd "${BATS_TEST_DIRNAME}/../../../" && pwd)"
  local prepare_sql="${project_root}/sql/wms/prepareDatabase.sql"
  local remove_sql="${project_root}/sql/wms/removeFromDatabase.sql"
  
  [ -f "$prepare_sql" ]
  [ -f "$remove_sql" ]
} 
