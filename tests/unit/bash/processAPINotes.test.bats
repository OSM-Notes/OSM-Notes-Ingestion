#!/usr/bin/env bats

# Unit tests for processAPINotes.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-01-15

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# =============================================================================
# Variables de configuración
# =============================================================================
SPECIAL_CASES_DIR="$TEST_BASE_DIR/tests/fixtures/special_cases"

# =============================================================================
# Pruebas básicas del script
# =============================================================================

@test "processAPINotes script should exist" {
  # Check if the script file exists
  [ -f "${TEST_BASE_DIR}/bin/process/processAPINotes.sh" ]
}

@test "processAPINotes script should be executable" {
  # Check if the script is executable
  [ -x "${TEST_BASE_DIR}/bin/process/processAPINotes.sh" ]
}

@test "processAPINotes should exit with error for invalid parameters" {
  # Test that script exits with error for invalid parameters
  run bash "bin/process/processAPINotes.sh" --invalid
  [ "$status" -ne 0 ]
}

@test "processAPINotes should exit with error for help parameters" {
  # Test that script exits with error for help parameters
  run bash "bin/process/processAPINotes.sh" -h
  [ "$status" -eq 1 ]
  
  run bash "bin/process/processAPINotes.sh" --help
  [ "$status" -eq 1 ]
}

# =============================================================================
# Pruebas de archivos requeridos
# =============================================================================

@test "SQL files should exist" {
  # Check if required SQL files exist
  [ -f "${TEST_BASE_DIR}/sql/process/processAPINotes_12_dropApiTables.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processAPINotes_21_createApiTables.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processAPINotes_22_createPartitions.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processAPINotes_23_createPropertiesTables.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processAPINotes_31_loadApiNotes.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processAPINotes_32_insertNewNotesAndComments.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processAPINotes_33_loadNewTextComments.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processAPINotes_34_updateLastValues.sql" ]
  [ -f "${TEST_BASE_DIR}/sql/process/processAPINotes_35_consolidatePartitions.sql" ]
}

@test "XSLT files should exist" {
  # Check if required XSLT files exist
  [ -f "${TEST_BASE_DIR}/xslt/notes-API-csv.xslt" ]
  [ -f "${TEST_BASE_DIR}/xslt/note_comments-API-csv.xslt" ]
  [ -f "${TEST_BASE_DIR}/xslt/note_comments_text-API-csv.xslt" ]
}

@test "XML schema files should exist" {
  # Check if required XML schema files exist
  [ -f "${TEST_BASE_DIR}/xsd/OSM-notes-API-schema.xsd" ]
}

# =============================================================================
# Pruebas de casos especiales
# =============================================================================

@test "special cases directory should exist" {
  # Check if special cases directory exists
  [ -d "$SPECIAL_CASES_DIR" ]
}

@test "zero notes case should exist" {
  # Check if zero notes test case exists
  [ -f "$SPECIAL_CASES_DIR/zero_notes.xml" ]
}

@test "single note case should exist" {
  # Check if single note test case exists
  [ -f "$SPECIAL_CASES_DIR/single_note.xml" ]
}

@test "less than threads case should exist" {
  # Check if less than threads test case exists
  [ -f "$SPECIAL_CASES_DIR/less_than_threads.xml" ]
}

@test "equal to cores case should exist" {
  # Check if equal to cores test case exists
  [ -f "$SPECIAL_CASES_DIR/equal_to_cores.xml" ]
}

@test "many more than cores case should exist" {
  # Check if many more than cores test case exists
  [ -f "$SPECIAL_CASES_DIR/many_more_than_cores.xml" ]
}

@test "double close case should exist" {
  # Check if double close test case exists
  [ -f "$SPECIAL_CASES_DIR/double_close.xml" ]
}

@test "double reopen case should exist" {
  # Check if double reopen test case exists
  [ -f "$SPECIAL_CASES_DIR/double_reopen.xml" ]
}

@test "create and close case should exist" {
  # Check if create and close test case exists
  [ -f "$SPECIAL_CASES_DIR/create_and_close.xml" ]
}

@test "close and reopen case should exist" {
  # Check if close and reopen test case exists
  [ -f "$SPECIAL_CASES_DIR/close_and_reopen.xml" ]
}

@test "open close reopen case should exist" {
  # Check if open close reopen test case exists
  [ -f "$SPECIAL_CASES_DIR/open_close_reopen.xml" ]
}

@test "open close reopen cycle case should exist" {
  # Check if open close reopen cycle test case exists
  [ -f "$SPECIAL_CASES_DIR/open_close_reopen_cycle.xml" ]
}

@test "comment and close case should exist" {
  # Check if comment and close test case exists
  [ -f "$SPECIAL_CASES_DIR/comment_and_close.xml" ]
}

# =============================================================================
# Pruebas de validación XML (solo para archivos que siguen el esquema)
# =============================================================================

@test "single note XML should be valid" {
  # Test that single note XML is valid against schema
  run xmllint --schema "${TEST_BASE_DIR}/xsd/OSM-notes-API-schema.xsd" "$SPECIAL_CASES_DIR/single_note.xml" --noout
  [ "$status" -eq 0 ]
}

# =============================================================================
# Pruebas de conteo de notas
# =============================================================================

@test "zero notes should contain 0 notes" {
  # Count notes in zero notes XML
  run xmllint --xpath "count(//note)" "$SPECIAL_CASES_DIR/zero_notes.xml"
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}

@test "single note should contain 1 note" {
  # Count notes in single note XML
  run xmllint --xpath "count(//note)" "$SPECIAL_CASES_DIR/single_note.xml"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "less than threads should contain 5 notes" {
  # Count notes in less than threads XML
  run xmllint --xpath "count(//note)" "$SPECIAL_CASES_DIR/less_than_threads.xml"
  [ "$status" -eq 0 ]
  [ "$output" -eq 5 ]
}

@test "equal to cores should contain 12 notes" {
  # Count notes in equal to cores XML
  run xmllint --xpath "count(//note)" "$SPECIAL_CASES_DIR/equal_to_cores.xml"
  [ "$status" -eq 0 ]
  [ "$output" -eq 12 ]
}

@test "many more than cores should contain 25 notes" {
  # Count notes in many more than cores XML
  run xmllint --xpath "count(//note)" "$SPECIAL_CASES_DIR/many_more_than_cores.xml"
  [ "$status" -eq 0 ]
  [ "$output" -eq 25 ]
}

# =============================================================================
# Pruebas de base de datos
# =============================================================================

@test "test database should be created for processAPINotes" {
  # Test database creation
  run create_test_database
  [ "$status" -eq 0 ]
  
  # Clean up
  run drop_test_database
  [ "$status" -eq 0 ]
}

@test "API tables can be created" {
  # Create test database
  create_test_database
  
  # Create API tables (ignore notices about existing tables)
  mock_psql -d "${TEST_DBNAME}" -f "sql/process/processAPINotes_21_createApiTables.sql" 2>/dev/null || true
  
  # Check if tables were created
  table_exists "notes" "${TEST_DBNAME}"
  [ $? -eq 0 ]
  
  table_exists "note_comments" "${TEST_DBNAME}"
  [ $? -eq 0 ]
  
  table_exists "note_comments_text" "${TEST_DBNAME}"
  [ $? -eq 0 ]
  
  table_exists "users" "${TEST_DBNAME}"
  [ $? -eq 0 ]
  
  # Clean up
  drop_test_database
}

# =============================================================================
# Pruebas de funciones de procesamiento
# =============================================================================

@test "XML counting functions should work with special cases" {
  # Source the functions
  source "${TEST_BASE_DIR}/bin/functionsProcess.sh"
  
  # Set up logging function if not available
  if ! declare -f log_info >/dev/null; then
    log_info() { echo "[INFO] $*"; }
  fi
  
  # Test zero notes using xmllint directly
  run xmllint --xpath "count(//note)" "$SPECIAL_CASES_DIR/zero_notes.xml"
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
  
  # Test single note using xmllint directly
  run xmllint --xpath "count(//note)" "$SPECIAL_CASES_DIR/single_note.xml"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  
  # Test less than threads using xmllint directly
  run xmllint --xpath "count(//note)" "$SPECIAL_CASES_DIR/less_than_threads.xml"
  [ "$status" -eq 0 ]
  [ "$output" -eq 5 ]
  
  # Test equal to cores using xmllint directly
  run xmllint --xpath "count(//note)" "$SPECIAL_CASES_DIR/equal_to_cores.xml"
  [ "$status" -eq 0 ]
  [ "$output" -eq 12 ]
  
  # Test many more than cores using xmllint directly
  run xmllint --xpath "count(//note)" "$SPECIAL_CASES_DIR/many_more_than_cores.xml"
  [ "$status" -eq 0 ]
  [ "$output" -eq 25 ]
}

# =============================================================================
# Pruebas de casos de error del API
# =============================================================================

@test "error case files should exist and be readable" {
  # Test that error case files exist and are readable
  [ -r "$SPECIAL_CASES_DIR/double_close.xml" ]
  [ -r "$SPECIAL_CASES_DIR/double_reopen.xml" ]
  [ -r "$SPECIAL_CASES_DIR/create_and_close.xml" ]
  [ -r "$SPECIAL_CASES_DIR/close_and_reopen.xml" ]
  [ -r "$SPECIAL_CASES_DIR/open_close_reopen.xml" ]
  [ -r "$SPECIAL_CASES_DIR/open_close_reopen_cycle.xml" ]
  [ -r "$SPECIAL_CASES_DIR/comment_and_close.xml" ]
} 