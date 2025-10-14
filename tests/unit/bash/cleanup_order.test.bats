#!/usr/bin/env bats

# Unit tests for Cleanup Order and Dependencies
# Test file: cleanup_order.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-10-13

load "../../test_helper.bash"

setup() {
  # Set script base directory
  SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  
  # Don't source the script as it auto-executes
  # Instead, we'll read the file content directly for validation
}

@test "cleanupAll should have correct script execution order" {
  # Read the BASE_SCRIPTS array definition from cleanupAll.sh
  SCRIPT_CONTENT=$(grep -A 10 "local BASE_SCRIPTS=" "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh")
  
  # Check that Generic Objects comes before Base Tables
  GENERIC_LINE=$(echo "$SCRIPT_CONTENT" | grep -n "Generic Objects" | cut -d: -f1)
  BASE_LINE=$(echo "$SCRIPT_CONTENT" | grep -n "Base Tables" | cut -d: -f1)
  
  # Generic Objects should come before Base Tables to avoid dependency issues
  [ -n "$GENERIC_LINE" ] && [ -n "$BASE_LINE" ]
  [ "$GENERIC_LINE" -lt "$BASE_LINE" ]
}

@test "dropBaseTables script should use CASCADE for dependent types" {
  # Check that the script uses CASCADE for dropping types
  grep -q "DROP TYPE.*note_event_enum CASCADE" "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql"
  grep -q "DROP TYPE.*note_status_enum CASCADE" "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql"
}

@test "dropGenericObjects script should drop insert_note_comment procedure" {
  # Check that the script drops the procedure that depends on the enum
  grep -q "DROP PROCEDURE.*insert_note_comment" "${SCRIPT_BASE_DIRECTORY}/sql/consolidated_cleanup.sql"
}

@test "cleanup scripts should exist and be readable" {
  # Verify all cleanup scripts exist
  [ -f "${SCRIPT_BASE_DIRECTORY}/sql/consolidated_cleanup.sql" ]
  [ -r "${SCRIPT_BASE_DIRECTORY}/sql/consolidated_cleanup.sql" ]
  
  [ -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql" ]
  [ -r "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql" ]
}

@test "SQL scripts should have valid syntax" {
  # Basic syntax check for the drop scripts
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"
  
  # Validate Generic Objects script
  run __validate_sql_structure "${SCRIPT_BASE_DIRECTORY}/sql/consolidated_cleanup.sql"
  [ "$status" -eq 0 ]
  
  # Validate Base Tables script
  run __validate_sql_structure "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql"
  [ "$status" -eq 0 ]
}

@test "cleanupAll should handle dependency order correctly" {
  # Test that the cleanup order addresses the dependency issue
  # Check that functions are dropped before types they depend on
  
  # Extract the order from cleanupAll.sh
  CLEANUP_ORDER=$(grep -A 10 "local BASE_SCRIPTS=" "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh" | grep -E "(Generic Objects|Base Tables)" | cat -n)
  
  # Generic Objects should come first (contains functionsProcess_12_dropGenericObjects)
  GENERIC_ORDER=$(echo "$CLEANUP_ORDER" | grep "Generic Objects" | awk '{print $1}')
  BASE_ORDER=$(echo "$CLEANUP_ORDER" | grep "Base Tables" | awk '{print $1}')
  
  [ -n "$GENERIC_ORDER" ] && [ -n "$BASE_ORDER" ]
  [ "$GENERIC_ORDER" -lt "$BASE_ORDER" ]
}

@test "dependency issue should be resolved" {
  # The original error was:
  # ERROR: no se puede eliminar tipo note_event_enum porque otros objetos dependen de él
  # DETALLE: función insert_note_comment(integer,note_event_enum,timestamp with time zone,integer,character varying,integer) depende de tipo note_event_enum
  
  # This should now be resolved by:
  # 1. Correct execution order (functions before types)
  # 2. CASCADE option on DROP TYPE
  
  # Check both solutions are in place
  
  # Solution 1: Correct order
  SCRIPT_CONTENT=$(grep -A 10 "local BASE_SCRIPTS=" "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh")
  GENERIC_LINE=$(echo "$SCRIPT_CONTENT" | grep -n "Generic Objects" | cut -d: -f1)
  BASE_LINE=$(echo "$SCRIPT_CONTENT" | grep -n "Base Tables" | cut -d: -f1)
  [ -n "$GENERIC_LINE" ] && [ -n "$BASE_LINE" ]
  [ "$GENERIC_LINE" -lt "$BASE_LINE" ]
  
  # Solution 2: CASCADE option
  grep -q "DROP TYPE.*note_event_enum CASCADE" "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql"
}



