#!/usr/bin/env bats

# Simple test for cleanup dependency fix
# Test file: cleanup_dependency_fix.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

load "../../test_helper.bash"

@test "cleanup order should be correct - Generic Objects before Base Tables" {
  # Extract just the relevant lines from cleanupAll.sh
  CLEANUP_SECTION=$(grep -A 10 "local BASE_SCRIPTS=" "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh")
  
  # Find line numbers for each script
  GENERIC_LINE=$(echo "$CLEANUP_SECTION" | grep -n "consolidated_cleanup.sql:Generic Objects" | cut -d: -f1)
  BASE_LINE=$(echo "$CLEANUP_SECTION" | grep -n "processPlanetNotes_13_dropBaseTables.sql:Base Tables" | cut -d: -f1)
  
  # Generic Objects should come before Base Tables
  [ ! -z "$GENERIC_LINE" ]
  [ ! -z "$BASE_LINE" ]
  [ "$GENERIC_LINE" -lt "$BASE_LINE" ]
}

@test "DROP TYPE statements should use CASCADE" {
  # Check that both enum types use CASCADE
  grep -q "DROP TYPE IF EXISTS note_event_enum CASCADE" "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql"
  grep -q "DROP TYPE IF EXISTS note_status_enum CASCADE" "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql"
}

@test "insert_note_comment procedure should be dropped in Generic Objects" {
  # Verify the dependent procedure is dropped
  grep -q "DROP PROCEDURE IF EXISTS insert_note_comment" "${SCRIPT_BASE_DIRECTORY}/sql/consolidated_cleanup.sql"
}

@test "dependency error scenario should be resolved" {
  # Original error: "no se puede eliminar tipo note_event_enum porque otros objetos dependen de él"
  # This test verifies both solutions are in place:
  
  # Solution 1: Correct execution order
  CLEANUP_SECTION=$(grep -A 10 "local BASE_SCRIPTS=" "${SCRIPT_BASE_DIRECTORY}/bin/cleanupAll.sh")
  echo "$CLEANUP_SECTION" | grep -B1 -A1 "consolidated_cleanup.sql:Generic Objects"
  echo "$CLEANUP_SECTION" | grep -B1 -A1 "processPlanetNotes_13_dropBaseTables.sql:Base Tables"
  
  # Verify Generic Objects comes before Base Tables
  GENERIC_LINE=$(echo "$CLEANUP_SECTION" | grep -n "consolidated_cleanup.sql:Generic Objects" | cut -d: -f1)
  BASE_LINE=$(echo "$CLEANUP_SECTION" | grep -n "processPlanetNotes_13_dropBaseTables.sql:Base Tables" | cut -d: -f1)
  [ "$GENERIC_LINE" -lt "$BASE_LINE" ]
  
  # Solution 2: CASCADE handles remaining dependencies automatically
  grep -q "CASCADE" "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_13_dropBaseTables.sql"
}



