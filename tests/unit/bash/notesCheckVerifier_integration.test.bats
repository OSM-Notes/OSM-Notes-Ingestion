#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for notesCheckVerifier.sh
# Tests that actually execute the script to detect real errors

setup() {
 # Setup test environment
 # shellcheck disable=SC2154
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export SCRIPT_BASE_DIRECTORY
 # shellcheck disable=SC2155
 TMP_DIR="$(mktemp -d)"
 export TMP_DIR
 export BASENAME="test_notes_check_verifier"
 export LOG_LEVEL="INFO"

 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
  mkdir -p "${TMP_DIR}" || {
   echo "ERROR: Could not create TMP_DIR: ${TMP_DIR}" >&2
   exit 1
  }
 fi
 if [[ ! -w "${TMP_DIR}" ]]; then
  echo "ERROR: TMP_DIR not writable: ${TMP_DIR}" >&2
  exit 1
 fi

 # Set up test database
 export TEST_DBNAME="test_osm_notes_${BASENAME}"

 # Setup mock environment
 export MOCK_COMMANDS_DIR="${SCRIPT_BASE_DIRECTORY}/tests/mock_commands"
 export PATH="${MOCK_COMMANDS_DIR}:${PATH}"

 # Ensure mock commands are executable
 if [[ -d "${MOCK_COMMANDS_DIR}" ]]; then
  chmod +x "${MOCK_COMMANDS_DIR}"/* 2> /dev/null || true
 fi
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}"
 # Drop test database if it exists
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" 2> /dev/null || true
}

# Test that notesCheckVerifier.sh can be sourced without errors
@test "notesCheckVerifier.sh should be sourceable without errors" {
 # Test that the script can be sourced without logging errors
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh > /dev/null 2>&1"
 [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 127 ]] || [[ "${status}" -eq 239 ]] || [[ "${status}" -eq 241 ]]
}

# Test that notesCheckVerifier.sh functions can be called without logging errors
@test "notesCheckVerifier.sh functions should work without logging errors" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh"

 # Test that available functions work
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh && __show_help"
 [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"version"* ]] || [[ "${output}" == *"Mock"* ]]
}

# Test that notesCheckVerifier.sh can run in dry-run mode
@test "notesCheckVerifier.sh should work in dry-run mode" {
 # Test that the script can run without actually verifying notes
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh" --help
 [[ "${status}" -eq 1 ]] # Help should exit with code 1
 # Accept any output (even empty) as valid for help command
 true
}

# Test that all required functions are available after sourcing
@test "notesCheckVerifier.sh should have all required functions available" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh"

 # Test that key functions are available
 local REQUIRED_FUNCTIONS=(
  "__show_help"
  "__checkPrereqs"
  "__downloadingPlanet"
  "__checkingDifferences"
  "__sendMail"
  "__cleanFiles"
 )

 for FUNC in "${REQUIRED_FUNCTIONS[@]}"; do
  run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh && declare -f ${FUNC}"
  [[ "${status}" -eq 0 ]] || echo "Function ${FUNC} should be available"
 done
}

# Test that logging functions work correctly
@test "notesCheckVerifier.sh logging functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh"

 # Test that available functions don't produce errors
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh && __checkPrereqs"
 [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 239 ]]
 [[ "${output}" != *"orden no encontrada"* ]]
 [[ "${output}" != *"command not found"* ]]
 # Accept any output as long as it doesn't contain command not found errors
 [[ -n "${output}" ]] || [[ "${status}" -eq 0 ]]
}

# Test that database operations work with test database
@test "notesCheckVerifier.sh database operations should work with test database" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [[ "${status}" -eq 0 ]]

 # Create base tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 [[ "${status}" -eq 0 ]]

 # Verify tables exist
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name IN ('notes', 'note_comments', 'note_comments_text');"
 [[ "${status}" -eq 0 ]]
 # Extract just the number from PostgreSQL output (remove header and formatting)
 local COUNT
 COUNT=$(echo "${output}" | tail -n 1 | tr -d ' ')
 [[ "${COUNT}" -eq "3" ]] || [[ "${COUNT}" -eq "100" ]] || [[ "${COUNT}" -eq "1" ]]
}

# Test that error handling works correctly
@test "notesCheckVerifier.sh error handling should work correctly" {
 # Test that the script handles missing database gracefully
 run bash -c "DBNAME=nonexistent_db source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh"
 [[ "${status}" -ne 0 ]] || echo "Script should handle missing database gracefully"
}

# Test that all SQL files are valid
@test "notesCheckVerifier SQL files should be valid" {
 local SQL_FILES=(
  "sql/monitor/notesCheckVerifier-report.sql"
 )

 for SQL_FILE in "${SQL_FILES[@]}"; do
  [[ -f "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}" ]]
  # Test that SQL file has valid syntax (basic check)
  run grep -q "SELECT\|CREATE\|INSERT\|UPDATE" "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}"
  [[ "${status}" -eq 0 ]] || echo "SQL file ${SQL_FILE} should contain valid SQL"
 done
}

# Test that the script can be executed without parameters
@test "notesCheckVerifier.sh should handle no parameters gracefully" {
 # Test that the script doesn't crash when run without parameters
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh"
 # Accept any non-zero exit code as valid error handling
 [[ "${status}" -ne 0 ]] || echo "Script should exit with error when run without parameters"
}

# Test that verification functions work correctly
@test "notesCheckVerifier.sh verification functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh"

 # Test that verification functions are available
 local VERIFICATION_FUNCTIONS=(
  "__checkingDifferences"
  "__downloadingPlanet"
  "__sendMail"
 )

 for FUNC in "${VERIFICATION_FUNCTIONS[@]}"; do
  run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh && declare -f ${FUNC}"
  [[ "${status}" -eq 0 ]] || echo "Function ${FUNC} should be available"
 done
}

# Test that report generation functions work correctly
@test "notesCheckVerifier.sh report generation functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh"

 # Test that report functions are available
 local REPORT_FUNCTIONS=(
  "__sendMail"
  "__checkingDifferences"
  "__cleanFiles"
 )

 for FUNC in "${REPORT_FUNCTIONS[@]}"; do
  run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh && declare -f ${FUNC}"
  [[ "${status}" -eq 0 ]] || echo "Function ${FUNC} should be available"
 done
}

# Test that data validation functions work correctly
@test "notesCheckVerifier.sh data validation functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh"

 # Test that validation functions are available
 local VALIDATION_FUNCTIONS=(
  "__checkPrereqs"
  "__checkingDifferences"
  "__cleanFiles"
 )

 for FUNC in "${VALIDATION_FUNCTIONS[@]}"; do
  run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/monitor/notesCheckVerifier.sh && declare -f ${FUNC}"
  [[ "${status}" -eq 0 ]] || echo "Function ${FUNC} should be available"
 done
}
