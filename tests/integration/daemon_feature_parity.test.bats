#!/usr/bin/env bats

# Integration tests for daemon feature parity with processAPINotes.sh
# Verifies that the daemon has all critical functions from processAPINotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
 # Setup test environment
 # TEST_BASE_DIR is set by test_helper.bash
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_feature_parity"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}"
}

# =============================================================================
# Tests for Critical Functions Presence
# =============================================================================

@test "Daemon should source processAPINotes.sh to get all functions" {
 # Verify that daemon sources processAPINotes.sh
 run grep -q "source.*processAPINotes\.sh\|\. processAPINotes\.sh" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should have XML validation function" {
 # Verify that daemon has XML validation (__validateApiNotesXMLFileComplete)
 run grep -q "__validateApiNotesXMLFileComplete\|__validateApiNotesFile" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should have XML counting function" {
 # Verify that daemon has XML counting (__countXmlNotesAPI)
 run grep -q "__countXmlNotesAPI" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should have XML processing function" {
 # Verify that daemon has XML processing (__processXMLorPlanet)
 run grep -q "__processXMLorPlanet" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should have notes and comments insertion function" {
 # Verify that daemon has insertion function (__insertNewNotesAndComments)
 run grep -q "__insertNewNotesAndComments" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should have text comments loading function" {
 # Verify that daemon has text comments loading (__loadApiTextComments)
 run grep -q "__loadApiTextComments" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should have gap recovery function" {
 # Verify that daemon has gap recovery (__recover_from_gaps)
 run grep -q "__recover_from_gaps" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should have gap checking function" {
 # Verify that daemon has gap checking (__check_and_log_gaps equivalent)
 run grep -q "Checking and logging gaps\|__check_and_log_gaps" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should have API download function" {
 # Verify that daemon has API download (__getNewNotesFromApi)
 run grep -q "__getNewNotesFromApi" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should have timestamp update function" {
 # Verify that daemon has timestamp update (__updateLastValue)
 run grep -q "__updateLastValue" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

# =============================================================================
# Tests for Processing Flow
# =============================================================================

@test "Daemon should validate XML file before processing" {
 # Verify that daemon validates XML file
 run grep -q "__validateApiNotesFile\|__validateApiNotesXMLFileComplete" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should count XML notes before processing" {
 # Verify that daemon counts XML notes
 run grep -q "__countXmlNotesAPI\|TOTAL_NOTES" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should process XML or trigger Planet sync" {
 # Verify that daemon processes XML or triggers Planet sync
 run grep -q "__processXMLorPlanet\|processPlanetNotes\.sh" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should insert notes and comments" {
 # Verify that daemon inserts notes and comments
 run grep -q "__insertNewNotesAndComments" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should load text comments" {
 # Verify that daemon loads text comments
 run grep -q "__loadApiTextComments" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should check gaps after processing" {
 # Verify that daemon checks gaps after processing
 run grep -q "Checking and logging gaps\|__check_and_log_gaps" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should clean API tables after processing" {
 # Verify that daemon cleans API tables (__prepareApiTables)
 run grep -q "__prepareApiTables" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should update timestamp after processing" {
 # Verify that daemon updates timestamp
 run grep -q "__updateLastValue\|UPDATE.*max_note_timestamp" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

# =============================================================================
# Tests for Error Handling
# =============================================================================

@test "Daemon should handle Planet sync trigger" {
 # Verify that daemon triggers Planet sync when too many notes
 run grep -q "MAX_NOTES\|Too many notes.*triggering Planet sync" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should handle processing errors" {
 # Verify that daemon handles processing errors
 run grep -q "Processing failed\|ERROR\|failed with exit code" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should handle empty database" {
 # Verify that daemon handles empty database
 run grep -q "Database appears to be empty\|processPlanetNotes\.sh.*--base" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

# =============================================================================
# Tests for Configuration and Environment
# =============================================================================

@test "Daemon should use same environment variables as processAPINotes.sh" {
 # Verify that daemon uses same environment variables
 # Check for common variables
 run grep -q "DBNAME\|LOG_LEVEL\|SKIP_XML_VALIDATION" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ]
}

@test "Daemon should have same SQL script paths" {
 # Verify that daemon uses same SQL script paths
 # The daemon sources processAPINotes.sh which defines these variables
 # Check that daemon uses SQL scripts (they're loaded from processAPINotes.sh)
 run grep -q "\.sql\|POSTGRES.*\.sql" \
  "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
 [ "$status" -eq 0 ] || {
  # Alternative: Check that daemon sources processAPINotes.sh which has SQL paths
  run grep -q "source.*processAPINotes\.sh" \
   "${TEST_BASE_DIR}/bin/process/processAPINotesDaemon.sh"
  [ "$status" -eq 0 ]
 }
}

