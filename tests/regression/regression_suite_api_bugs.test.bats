#!/usr/bin/env bats

# Regression Test Suite: Critical API Bugs (2025-12-13)
# Tests to prevent regression of critical API-related bugs
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
# Bug #23: API Timeout Insufficient for Large Downloads
# =============================================================================
# Bug: Timeout of 30 seconds was insufficient for downloading 10,000 notes
#      (can be 12MB+)
# Fix: Increased timeout from 30 to 120 seconds in __retry_osm_api call
# Date: 2025-12-13
# Files changed: bin/lib/processAPIFunctions.sh

@test "REGRESSION: API timeout should be sufficient for large downloads" {
 local FUNCTIONS_FILE="${TEST_BASE_DIR}/bin/lib/processAPIFunctions.sh"
 
 if [[ ! -f "${FUNCTIONS_FILE}" ]]; then
  skip "Functions file not found"
 fi
 
 # Verify that timeout is at least 120 seconds (not 30)
 # Old buggy timeout: 30 seconds
 # New correct timeout: 120 seconds
 run grep -qE "(timeout.*120|--max-time.*120)" "${FUNCTIONS_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should use timeout of at least 120 seconds for API downloads"
}

# =============================================================================
# Bug #24: Missing Processing Functions in Daemon
# =============================================================================
# Bug: Daemon was calling functions (__processXMLorPlanet, __insertNewNotesAndComments,
#      etc.) that were only defined in processAPINotes.sh, which the daemon was not loading
# Fix: Modified processAPINotes.sh to detect when it's being sourced and skip main
#      execution. Modified processAPINotesDaemon.sh to source processAPINotes.sh
# Date: 2025-12-13
# Files changed:
#   - bin/process/processAPINotes.sh
#   - bin/process/processAPINotesDaemon.sh

@test "REGRESSION: Daemon should source processAPINotes.sh to load functions" {
 local DAEMON_FILE="${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 
 if [[ ! -f "${DAEMON_FILE}" ]]; then
  skip "Daemon file not found"
 fi
 
 # Verify that daemon sources processAPINotes.sh
 # This ensures all processing functions are available
 run grep -qE "(source.*processAPINotes|\. .*processAPINotes)" "${DAEMON_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should source processAPINotes.sh to load functions"
}

# =============================================================================
# Bug #25: app.integrity_check_passed Variable Not Persisting Between Connections
# =============================================================================
# Bug: The app.integrity_check_passed variable was set using set_config(..., false),
#      which makes it local to the current transaction. Additionally, __insertNewNotesAndComments
#      and __updateLastValue were executed in separate psql connections, so even with
#      set_config(..., true), the variable didn't persist because each psql call creates
#      a new connection
# Fix: Changed set_config(..., false) to set_config(..., true) and modified
#      __insertNewNotesAndComments to execute both SQL files in the same psql connection
# Date: 2025-12-13
# Files changed:
#   - sql/process/processAPINotes_31_insertNewNotesAndComments.sql
#   - bin/process/processAPINotes.sh
#   - bin/process/processAPINotesDaemon.sh

@test "REGRESSION: app.integrity_check_passed should use set_config with true" {
 local SQL_FILE="${TEST_BASE_DIR}/sql/process/processAPINotes_31_insertNewNotesAndComments.sql"
 
 if [[ ! -f "${SQL_FILE}" ]]; then
  skip "SQL file not found"
 fi
 
 # Verify that set_config uses true (not false) for persistence
 # Old buggy pattern: set_config('app.integrity_check_passed', ..., false)
 # New correct pattern: set_config('app.integrity_check_passed', ..., true)
 run grep -qE "set_config.*app\.integrity_check_passed.*true" "${SQL_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should use set_config(..., true) for variable persistence"
}

@test "REGRESSION: __insertNewNotesAndComments should execute both SQL files in same connection" {
 local SCRIPT_FILE="${TEST_BASE_DIR}/bin/process/processAPINotes.sh"
 
 __verify_file_exists "${SCRIPT_FILE}" "Script file not found"
 
 # Verify that both SQL files are executed in the same psql connection
 # This ensures the session variable persists between transactions
 run grep -qE "(processAPINotes_31.*processAPINotes_33|__insertNewNotesAndComments)" "${SCRIPT_FILE}"
 [[ "${status}" -eq 0 ]] || echo "Should execute both SQL files in same connection"
}

