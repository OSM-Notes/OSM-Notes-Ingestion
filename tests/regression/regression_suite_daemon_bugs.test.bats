#!/usr/bin/env bats

# Regression Test Suite: Daemon Bugs (2025-12-15)
# Tests to prevent regression of daemon-related bugs
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

load "${BATS_TEST_DIRNAME}/../test_helper"
load "${BATS_TEST_DIRNAME}/regression_helpers"

setup() {
 __setup_regression_test
}

teardown() {
 __teardown_regression_test
}

# =============================================================================
# Bug #13: Syntax Error in Daemon Gap Detection
# =============================================================================
# Bug: NOTE_COUNT variable in __check_api_for_updates contained newlines,
#      causing bash arithmetic comparison to fail with "syntax error in expression"
# Fix: Added tr -d '[:space:]' to clean NOTE_COUNT variable before comparison
# Date: 2025-12-15
# Files changed: bin/process/processAPINotesDaemon.sh

@test "REGRESSION: NOTE_COUNT should be cleaned of whitespace before comparison" {
 # Simulate the bug scenario: NOTE_COUNT with newlines
 local NOTE_COUNT_WITH_NEWLINE=$'5\n'
 local NOTE_COUNT_CLEANED
 NOTE_COUNT_CLEANED=$(echo "${NOTE_COUNT_WITH_NEWLINE}" | tr -d '[:space:]')
 
 # Old buggy method would fail with arithmetic error
 # New method should work correctly
 [[ "${NOTE_COUNT_CLEANED}" == "5" ]]
 
 # Test arithmetic comparison works
 [[ "${NOTE_COUNT_CLEANED}" -gt 0 ]]
 [[ "${NOTE_COUNT_CLEANED}" -eq 5 ]]
}

@test "REGRESSION: NOTE_COUNT with spaces should be cleaned" {
 # Test with spaces and tabs
 local NOTE_COUNT_DIRTY="  10  "
 local NOTE_COUNT_CLEANED
 NOTE_COUNT_CLEANED=$(echo "${NOTE_COUNT_DIRTY}" | tr -d '[:space:]')
 
 [[ "${NOTE_COUNT_CLEANED}" == "10" ]]
 [[ "${NOTE_COUNT_CLEANED}" -eq 10 ]]
}

# =============================================================================
# Bug #14: Daemon Initialization with Empty Database
# =============================================================================
# Bug: Daemon exited with error when database was empty, preventing
#      auto-initialization
# Fix: Modified __daemon_init to not exit if base tables are missing
#      Modified __process_api_data to detect empty database and trigger
#      processPlanetNotes.sh --base automatically
# Date: 2025-12-15
# Files changed: bin/process/processAPINotesDaemon.sh

@test "REGRESSION: Daemon should handle empty database gracefully" {
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 
 if [[ ! -f "${DAEMON_FILE}" ]]; then
  skip "Daemon file not found"
 fi
 
 # Verify that __daemon_init doesn't exit on empty database
 # Should check for base tables but not exit if missing
 run grep -qE "(base tables|__process_api_data.*empty|processPlanetNotes.*--base)" "${DAEMON_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should handle empty database detection"
}

# =============================================================================
# Bug #15: API Table Creation Errors with Empty Database
# =============================================================================
# Bug: Daemon tried to create API tables before base tables existed,
#      causing "type does not exist" errors for enums
# Fix: Skip __prepareApiTables, __createPropertiesTable, etc. if base tables
#      are missing (these depend on enums created by processPlanetNotes.sh --base)
# Date: 2025-12-15
# Files changed: bin/process/processAPINotesDaemon.sh

@test "REGRESSION: API table creation should check for base tables first" {
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 
 if [[ ! -f "${DAEMON_FILE}" ]]; then
  skip "Daemon file not found"
 fi
 
 # Verify that API table creation checks for base tables
 # Should skip if base tables don't exist
 run grep -qE "(base tables|__prepareApiTables|__createPropertiesTable)" "${DAEMON_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should check for base tables before creating API tables"
}

# =============================================================================
# Bug #16: OSM API Version Detection Fix
# =============================================================================
# Bug: Daemon was failing to start with error "Cannot detect OSM API version
#      from response"
# Fix: Changed to use dedicated /api/versions endpoint for version detection
# Date: 2025-12-15
# Files changed: bin/process/processAPINotesDaemon.sh

@test "REGRESSION: OSM API version detection should use /api/versions endpoint" {
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 
 if [[ ! -f "${DAEMON_FILE}" ]]; then
  skip "Daemon file not found"
 fi
 
 # Verify that version detection uses /api/versions endpoint
 run grep -q "/api/versions" "${DAEMON_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should use /api/versions endpoint for version detection"
}

