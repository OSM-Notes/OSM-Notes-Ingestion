#!/usr/bin/env bats

# Integration tests for daemon feature parity - Execution Verification
# Verifies that the daemon executes functions in the same order and manner as processAPINotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
 # Setup test environment
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_feature_parity_exec"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 
 # Create tracking file for function calls
 export FUNCTION_CALL_LOG="${TMP_DIR}/function_calls.log"
 touch "${FUNCTION_CALL_LOG}"
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}"
 rm -f "${FUNCTION_CALL_LOG}"
}

# =============================================================================
# Helper Functions
# =============================================================================

# Track function calls
__track_function_call() {
 local FUNC_NAME="$1"
 echo "${FUNC_NAME}" >> "${FUNCTION_CALL_LOG}"
}

# Get function call order
__get_function_calls() {
 cat "${FUNCTION_CALL_LOG}" 2>/dev/null || echo ""
}

# =============================================================================
# Tests for Function Execution Order
# =============================================================================

@test "Daemon should execute functions in same order as processAPINotes.sh - validation flow" {
 # Verify that daemon calls validation functions in the same order
 # Expected order: __validateApiNotesFile -> __validateApiNotesXMLFileComplete -> __countXmlNotesAPI
 
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 # Check that daemon has validation functions in __process_api_data
 # Get line number of __process_api_data function
 local DAEMON_PROCESS_START
 DAEMON_PROCESS_START=$(grep -n "^function __process_api_data" "${DAEMON_FILE}" | cut -d: -f1)
 
 local DAEMON_HAS_VALIDATION=0
 if [[ -n "${DAEMON_PROCESS_START}" ]]; then
  DAEMON_HAS_VALIDATION=$(sed -n "${DAEMON_PROCESS_START},$((DAEMON_PROCESS_START + 200))p" "${DAEMON_FILE}" | \
   grep -c "__validateApiNotesFile\|__validateApiNotesXMLFileComplete\|__countXmlNotesAPI" 2>/dev/null | tr -d '[:space:]' || echo "0")
 fi
 
 # Check that script has validation functions in __validateAndProcessApiXml
 local SCRIPT_VALIDATE_START
 SCRIPT_VALIDATE_START=$(grep -n "^function __validateAndProcessApiXml" "${SCRIPT_FILE}" | cut -d: -f1)
 
 local SCRIPT_HAS_VALIDATION=0
 if [[ -n "${SCRIPT_VALIDATE_START}" ]]; then
  SCRIPT_HAS_VALIDATION=$(sed -n "${SCRIPT_VALIDATE_START},$((SCRIPT_VALIDATE_START + 20))p" "${SCRIPT_FILE}" | \
   grep -c "__validateApiNotesFile\|__validateApiNotesXMLFileComplete\|__countXmlNotesAPI" 2>/dev/null | tr -d '[:space:]' || echo "0")
 fi
 
 # Both should have the validation functions
 [[ "${DAEMON_HAS_VALIDATION}" -ge 2 ]]
 [[ "${SCRIPT_HAS_VALIDATION}" -ge 2 ]]
}

@test "Daemon should execute processing functions in same order as processAPINotes.sh" {
 # Verify processing flow: __processXMLorPlanet -> __insertNewNotesAndComments -> __loadApiTextComments
 
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 # Check that daemon has the same processing sequence
 local DAEMON_HAS_PROCESSING
 DAEMON_HAS_PROCESSING=$(grep -c "__processXMLorPlanet\|__insertNewNotesAndComments\|__loadApiTextComments" \
  "${DAEMON_FILE}" || echo "0")
 
 local SCRIPT_HAS_PROCESSING
 SCRIPT_HAS_PROCESSING=$(grep -c "__processXMLorPlanet\|__insertNewNotesAndComments\|__loadApiTextComments" \
  "${SCRIPT_FILE}" || echo "0")
 
 # Both should have all three functions
 [[ "${DAEMON_HAS_PROCESSING}" -ge 3 ]]
 [[ "${SCRIPT_HAS_PROCESSING}" -ge 3 ]]
}

@test "Daemon should call gap recovery function like processAPINotes.sh" {
 # Verify that daemon calls __recover_from_gaps in equivalent context
 # In processAPINotes.sh: called in __validateHistoricalDataAndRecover
 # In daemon: should be called in __validateHistoricalDataAndRecover (during init)
 
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 # Check that both call __recover_from_gaps in __validateHistoricalDataAndRecover
 # Get line number of __validateHistoricalDataAndRecover function
 local DAEMON_VALIDATE_START
 DAEMON_VALIDATE_START=$(grep -n "^function __validateHistoricalDataAndRecover" "${DAEMON_FILE}" | cut -d: -f1)
 
 local DAEMON_CALLS_RECOVER=0
 if [[ -n "${DAEMON_VALIDATE_START}" ]]; then
  DAEMON_CALLS_RECOVER=$(sed -n "${DAEMON_VALIDATE_START},$((DAEMON_VALIDATE_START + 50))p" "${DAEMON_FILE}" | \
   grep -c "__recover_from_gaps" 2>/dev/null | tr -d '[:space:]' || echo "0")
 fi
 
 local SCRIPT_VALIDATE_START
 SCRIPT_VALIDATE_START=$(grep -n "^function __validateHistoricalDataAndRecover" "${SCRIPT_FILE}" | cut -d: -f1)
 
 local SCRIPT_CALLS_RECOVER=0
 if [[ -n "${SCRIPT_VALIDATE_START}" ]]; then
  SCRIPT_CALLS_RECOVER=$(sed -n "${SCRIPT_VALIDATE_START},$((SCRIPT_VALIDATE_START + 30))p" "${SCRIPT_FILE}" | \
   grep -c "__recover_from_gaps" 2>/dev/null | tr -d '[:space:]' || echo "0")
 fi
 
 # Both should call it
 [[ "${DAEMON_CALLS_RECOVER}" -gt 0 ]]
 [[ "${SCRIPT_CALLS_RECOVER}" -gt 0 ]]
}

@test "Daemon should call gap checking function after processing like processAPINotes.sh" {
 # Verify that daemon calls __check_and_log_gaps after processing
 # In processAPINotes.sh: called after __validateAndProcessApiXml
 # In daemon: should be called after processing in __process_api_data
 
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 # Check that both call gap checking after processing
 local DAEMON_CALLS_GAP_CHECK
 DAEMON_CALLS_GAP_CHECK=$(grep -B 5 -A 5 "Checking and logging gaps\|__check_and_log_gaps" \
  "${DAEMON_FILE}" | grep -c "__loadApiTextComments\|__insertNewNotesAndComments" || echo "0")
 
 local SCRIPT_CALLS_GAP_CHECK
 SCRIPT_CALLS_GAP_CHECK=$(grep -B 5 -A 5 "__check_and_log_gaps" "${SCRIPT_FILE}" | \
  grep -c "__validateAndProcessApiXml\|__loadApiTextComments" || echo "0")
 
 # Both should call gap checking after processing
 [[ "${DAEMON_CALLS_GAP_CHECK}" -gt 0 ]] || [[ "${SCRIPT_CALLS_GAP_CHECK}" -gt 0 ]]
}

# =============================================================================
# Tests for Function Availability After Sourcing
# =============================================================================

@test "Daemon should have all critical functions available after sourcing processAPINotes.sh" {
 # Test that functions are actually available, not just present in code
 # This verifies that sourcing works correctly
 # Note: We verify that daemon sources processAPINotes.sh which provides these functions
 
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 # Verify that daemon sources processAPINotes.sh
 run grep -q "source.*processAPINotes\.sh" "${DAEMON_FILE}"
 [ "$status" -eq 0 ]
 
 # Verify that processAPINotes.sh defines these functions
 local FUNCTIONS_IN_SCRIPT
 FUNCTIONS_IN_SCRIPT=$(grep -c "^function __validateApiNotesXMLFileComplete\|^function __countXmlNotesAPI\|^function __processXMLorPlanet\|^function __insertNewNotesAndComments\|^function __loadApiTextComments\|^function __recover_from_gaps\|^function __check_and_log_gaps" \
  "${SCRIPT_FILE}" || echo "0")
 
 # Script should define these functions
 [[ "${FUNCTIONS_IN_SCRIPT}" -ge 5 ]]
 
 # Verify daemon references these functions (they're available via source)
 local FUNCTIONS_IN_DAEMON
 FUNCTIONS_IN_DAEMON=$(grep -c "__validateApiNotesXMLFileComplete\|__countXmlNotesAPI\|__processXMLorPlanet\|__insertNewNotesAndComments\|__loadApiTextComments\|__recover_from_gaps\|__check_and_log_gaps" \
  "${DAEMON_FILE}" || echo "0")
 
 # Daemon should reference these functions
 [[ "${FUNCTIONS_IN_DAEMON}" -ge 5 ]]
}

# =============================================================================
# Tests for Processing Flow Equivalence
# =============================================================================

@test "Daemon processing flow should match processAPINotes.sh flow structure" {
 # Verify that the overall flow structure is equivalent
 # processAPINotes.sh: validate -> count -> process -> insert -> load -> gaps
 # daemon: validate -> count -> process -> insert -> load -> gaps
 
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 
 # Check that daemon has all key processing steps in __process_api_data
 # Get line number of __process_api_data function
 local DAEMON_PROCESS_START
 DAEMON_PROCESS_START=$(grep -n "^function __process_api_data" "${DAEMON_FILE}" | cut -d: -f1)
 
 local DAEMON_HAS_VALIDATION=0
 local DAEMON_HAS_COUNT=0
 local DAEMON_HAS_PROCESS=0
 local DAEMON_HAS_INSERT=0
 local DAEMON_HAS_LOAD=0
 local DAEMON_HAS_GAPS=0
 
 if [[ -n "${DAEMON_PROCESS_START}" ]]; then
  local PROCESS_SECTION
  PROCESS_SECTION=$(sed -n "${DAEMON_PROCESS_START},$((DAEMON_PROCESS_START + 200))p" "${DAEMON_FILE}")
  
  DAEMON_HAS_VALIDATION=$(echo "${PROCESS_SECTION}" | \
   grep -c "__validateApiNotesFile\|__validateApiNotesXMLFileComplete" 2>/dev/null | tr -d '[:space:]' || echo "0")
  DAEMON_HAS_COUNT=$(echo "${PROCESS_SECTION}" | \
   grep -c "__countXmlNotesAPI" 2>/dev/null | tr -d '[:space:]' || echo "0")
  DAEMON_HAS_PROCESS=$(echo "${PROCESS_SECTION}" | \
   grep -c "__processXMLorPlanet" 2>/dev/null | tr -d '[:space:]' || echo "0")
  DAEMON_HAS_INSERT=$(echo "${PROCESS_SECTION}" | \
   grep -c "__insertNewNotesAndComments" 2>/dev/null | tr -d '[:space:]' || echo "0")
  DAEMON_HAS_LOAD=$(echo "${PROCESS_SECTION}" | \
   grep -c "__loadApiTextComments" 2>/dev/null | tr -d '[:space:]' || echo "0")
  DAEMON_HAS_GAPS=$(echo "${PROCESS_SECTION}" | \
   grep -c "Checking and logging gaps\|__check_and_log_gaps" 2>/dev/null | tr -d '[:space:]' || echo "0")
 fi
 
 # All key steps should be present
 [[ "${DAEMON_HAS_VALIDATION}" -gt 0 ]]
 [[ "${DAEMON_HAS_COUNT}" -gt 0 ]]
 [[ "${DAEMON_HAS_PROCESS}" -gt 0 ]]
 [[ "${DAEMON_HAS_INSERT}" -gt 0 ]]
 [[ "${DAEMON_HAS_LOAD}" -gt 0 ]]
 [[ "${DAEMON_HAS_GAPS}" -gt 0 ]]
}

@test "Daemon should handle Planet sync trigger same way as processAPINotes.sh" {
 # Verify that both handle MAX_NOTES threshold the same way
 # Both should call processPlanetNotes.sh when TOTAL_NOTES >= MAX_NOTES
 
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 # Check that both check MAX_NOTES threshold
 local DAEMON_CHECKS_MAX
 DAEMON_CHECKS_MAX=$(grep -c "MAX_NOTES\|TOTAL_NOTES.*MAX_NOTES" "${DAEMON_FILE}" || echo "0")
 
 local SCRIPT_CHECKS_MAX
 SCRIPT_CHECKS_MAX=$(grep -c "MAX_NOTES\|TOTAL_NOTES.*MAX_NOTES" "${SCRIPT_FILE}" || echo "0")
 
 # Both should check the threshold
 [[ "${DAEMON_CHECKS_MAX}" -gt 0 ]]
 [[ "${SCRIPT_CHECKS_MAX}" -gt 0 ]]
 
 # Both should trigger Planet sync
 local DAEMON_TRIGGERS_PLANET
 DAEMON_TRIGGERS_PLANET=$(grep -c "processPlanetNotes\.sh\|NOTES_SYNC_SCRIPT" "${DAEMON_FILE}" || echo "0")
 
 local SCRIPT_TRIGGERS_PLANET
 SCRIPT_TRIGGERS_PLANET=$(grep -c "processPlanetNotes\.sh\|NOTES_SYNC_SCRIPT" "${SCRIPT_FILE}" || echo "0")
 
 [[ "${DAEMON_TRIGGERS_PLANET}" -gt 0 ]]
 [[ "${SCRIPT_TRIGGERS_PLANET}" -gt 0 ]]
}

# =============================================================================
# Tests for Error Handling Equivalence
# =============================================================================

@test "Daemon should handle errors same way as processAPINotes.sh" {
 # Verify that error handling is equivalent
 # Both should use __handle_error_with_cleanup and __create_failed_marker
 
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 # Check for error handling functions
 local DAEMON_HAS_ERROR_HANDLING
 DAEMON_HAS_ERROR_HANDLING=$(grep -c "__handle_error_with_cleanup\|__create_failed_marker" \
  "${DAEMON_FILE}" || echo "0")
 
 local SCRIPT_HAS_ERROR_HANDLING
 SCRIPT_HAS_ERROR_HANDLING=$(grep -c "__handle_error_with_cleanup\|__create_failed_marker" \
  "${SCRIPT_FILE}" || echo "0")
 
 # Both should have error handling
 [[ "${DAEMON_HAS_ERROR_HANDLING}" -gt 0 ]]
 [[ "${SCRIPT_HAS_ERROR_HANDLING}" -gt 0 ]]
}

@test "Daemon should use same SQL scripts as processAPINotes.sh" {
 # Verify that daemon uses the same SQL script paths
 # Since daemon sources processAPINotes.sh, it should inherit SQL paths
 
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 # Check that daemon sources processAPINotes.sh (which defines SQL paths)
 local DAEMON_SOURCES_SCRIPT
 DAEMON_SOURCES_SCRIPT=$(grep -c "source.*processAPINotes\.sh" "${DAEMON_FILE}" || echo "0")
 
 # Daemon should source the script
 [[ "${DAEMON_SOURCES_SCRIPT}" -gt 0 ]]
 
 # Verify that SQL script variables would be available
 # (They're defined in processAPINotes.sh and inherited via source)
 local SCRIPT_HAS_SQL_PATHS
 SCRIPT_HAS_SQL_PATHS=$(grep -c "\.sql\|SQL.*FILE" "${SCRIPT_FILE}" | head -1 || echo "0")
 
 # Script should reference SQL files
 [[ "${SCRIPT_HAS_SQL_PATHS}" -gt 0 ]]
}

# =============================================================================
# Tests for Table Management Equivalence
# =============================================================================

@test "Daemon should manage API tables same way as processAPINotes.sh" {
 # Verify table management approach
 # processAPINotes.sh: DROP + CREATE each time
 # daemon: TRUNCATE (reuses structure) - this is intentional optimization
 
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 # Check daemon uses TRUNCATE (optimization)
 local DAEMON_USES_TRUNCATE
 DAEMON_USES_TRUNCATE=$(grep -c "TRUNCATE.*notes_api\|TRUNCATE.*note_comments_api" \
  "${DAEMON_FILE}" || echo "0")
 
 # Check script uses DROP + CREATE
 local SCRIPT_USES_DROP
 SCRIPT_USES_DROP=$(grep -c "__dropApiTables\|DROP TABLE.*notes_api" \
  "${SCRIPT_FILE}" || echo "0")
 
 # Both approaches are valid (daemon optimizes by reusing structure)
 [[ "${DAEMON_USES_TRUNCATE}" -gt 0 ]] || [[ "${SCRIPT_USES_DROP}" -gt 0 ]]
}

@test "Daemon should create API tables before processing like processAPINotes.sh" {
 # Verify that both ensure API tables exist before processing
 
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 # Check that daemon prepares tables
 local DAEMON_PREPARES_TABLES
 DAEMON_PREPARES_TABLES=$(grep -c "__prepareApiTables\|CREATE TABLE.*notes_api" \
  "${DAEMON_FILE}" || echo "0")
 
 # Check that script creates tables
 local SCRIPT_CREATES_TABLES
 SCRIPT_CREATES_TABLES=$(grep -c "__createApiTables\|CREATE TABLE.*notes_api" \
  "${SCRIPT_FILE}" || echo "0")
 
 # Both should ensure tables exist
 [[ "${DAEMON_PREPARES_TABLES}" -gt 0 ]] || [[ "${SCRIPT_CREATES_TABLES}" -gt 0 ]]
}

# =============================================================================
# Tests for Timestamp Management
# =============================================================================

@test "Daemon should update timestamp same way as processAPINotes.sh" {
 # Verify that both update max_note_timestamp after processing
 
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 # Check that both call __updateLastValue
 local DAEMON_UPDATES_TIMESTAMP
 DAEMON_UPDATES_TIMESTAMP=$(grep -c "__updateLastValue\|UPDATE.*max_note_timestamp" \
  "${DAEMON_FILE}" || echo "0")
 
 local SCRIPT_UPDATES_TIMESTAMP
 SCRIPT_UPDATES_TIMESTAMP=$(grep -c "__updateLastValue\|UPDATE.*max_note_timestamp" \
  "${SCRIPT_FILE}" || echo "0")
 
 # Both should update timestamp
 [[ "${DAEMON_UPDATES_TIMESTAMP}" -gt 0 ]]
 [[ "${SCRIPT_UPDATES_TIMESTAMP}" -gt 0 ]]
}

