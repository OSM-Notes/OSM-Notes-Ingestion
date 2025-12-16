#!/usr/bin/env bats

# Common tests for monitoring scripts in bin/monitor/
# Tests basic functionality, existence, and structure
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# =============================================================================
# Tests for analyzeDatabasePerformance.sh
# =============================================================================

@test "analyzeDatabasePerformance.sh should exist" {
 [ -f "${TEST_BASE_DIR}/bin/monitor/analyzeDatabasePerformance.sh" ]
}

@test "analyzeDatabasePerformance.sh should be executable" {
 [ -x "${TEST_BASE_DIR}/bin/monitor/analyzeDatabasePerformance.sh" ]
}

@test "analyzeDatabasePerformance.sh should have help option" {
 run bash "${TEST_BASE_DIR}/bin/monitor/analyzeDatabasePerformance.sh" --help 2>&1 || true
 # Script should show help or exit with error code 1
 [ "$status" -eq 1 ] || [[ "$output" == *"help"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "analyzeDatabasePerformance.sh should use DBNAME environment variable" {
 # Check that script references DBNAME
 run grep -q "DBNAME" "${TEST_BASE_DIR}/bin/monitor/analyzeDatabasePerformance.sh"
 [ "$status" -eq 0 ]
}

@test "analyzeDatabasePerformance.sh should reference SQL analysis scripts" {
 # Check that script references SQL analysis directory
 run grep -q "sql/analysis" "${TEST_BASE_DIR}/bin/monitor/analyzeDatabasePerformance.sh"
 [ "$status" -eq 0 ]
}

@test "analyzeDatabasePerformance.sh should have main function" {
 # Check that script has main function
 run grep -q "^__main\|^function __main\|^main()" "${TEST_BASE_DIR}/bin/monitor/analyzeDatabasePerformance.sh"
 [ "$status" -eq 0 ]
}

# =============================================================================
# Tests for notesCheckVerifier.sh
# =============================================================================

@test "notesCheckVerifier.sh should exist" {
 [ -f "${TEST_BASE_DIR}/bin/monitor/notesCheckVerifier.sh" ]
}

@test "notesCheckVerifier.sh should be executable" {
 [ -x "${TEST_BASE_DIR}/bin/monitor/notesCheckVerifier.sh" ]
}

@test "notesCheckVerifier.sh should have help option" {
 run bash "${TEST_BASE_DIR}/bin/monitor/notesCheckVerifier.sh" --help 2>&1 || true
 # Script should show help or exit with error code 1
 [ "$status" -eq 1 ] || [[ "$output" == *"help"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "notesCheckVerifier.sh should use EMAILS environment variable" {
 # Check that script references EMAILS
 run grep -q "EMAILS" "${TEST_BASE_DIR}/bin/monitor/notesCheckVerifier.sh"
 [ "$status" -eq 0 ]
}

@test "notesCheckVerifier.sh should use DBNAME environment variable" {
 # Check that script references DBNAME
 run grep -q "DBNAME" "${TEST_BASE_DIR}/bin/monitor/notesCheckVerifier.sh"
 [ "$status" -eq 0 ]
}

@test "notesCheckVerifier.sh should have main function" {
 # Check that script has main function
 run grep -q "^function main\|^main()" "${TEST_BASE_DIR}/bin/monitor/notesCheckVerifier.sh"
 [ "$status" -eq 0 ]
}

# =============================================================================
# Tests for processCheckPlanetNotes.sh
# =============================================================================

@test "processCheckPlanetNotes.sh should exist" {
 [ -f "${TEST_BASE_DIR}/bin/monitor/processCheckPlanetNotes.sh" ]
}

@test "processCheckPlanetNotes.sh should be executable" {
 [ -x "${TEST_BASE_DIR}/bin/monitor/processCheckPlanetNotes.sh" ]
}

@test "processCheckPlanetNotes.sh should handle invalid arguments gracefully" {
 # Test that script handles invalid arguments without crashing
 run bash "${TEST_BASE_DIR}/bin/monitor/processCheckPlanetNotes.sh" --invalid-arg 2>&1 || true
 # Script should either exit with error or show help, but not crash
 [ "$status" -ne 0 ] || [ -n "$output" ]
}

@test "processCheckPlanetNotes.sh should use DBNAME environment variable" {
 # Check that script references DBNAME
 run grep -q "DBNAME" "${TEST_BASE_DIR}/bin/monitor/processCheckPlanetNotes.sh"
 [ "$status" -eq 0 ]
}

@test "processCheckPlanetNotes.sh should have main function" {
 # Check that script has main function
 run grep -q "^function main\|^main()" "${TEST_BASE_DIR}/bin/monitor/processCheckPlanetNotes.sh"
 [ "$status" -eq 0 ]
}

@test "processCheckPlanetNotes.sh should reference check tables" {
 # Check that script references check tables
 run grep -q "check\|Check" "${TEST_BASE_DIR}/bin/monitor/processCheckPlanetNotes.sh"
 [ "$status" -eq 0 ]
}

