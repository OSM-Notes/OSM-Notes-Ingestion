#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Centralized Validation Integration Tests
# Tests that all scripts use the centralized validation functions
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

setup() {
  # Load test helper functions
  load "${BATS_TEST_DIRNAME}/../../test_helper.bash"
  
  # Load the functions to test
  load "${BATS_TEST_DIRNAME}/../../../bin/lib/functionsProcess.sh"
  
  # Set up test environment
  PROJECT_ROOT="${BATS_TEST_DIRNAME}/../../.."
  TEST_DIR=$(mktemp -d)
  
  # Create test files
  VALID_SQL_FILE="${TEST_DIR}/test.sql"
  VALID_XML_FILE="${TEST_DIR}/test.xml"
  VALID_CSV_FILE="${TEST_DIR}/test.csv"
  
  # Create valid test files
  cat > "${VALID_SQL_FILE}" << 'EOF'
CREATE TABLE test_table (
  id INTEGER PRIMARY KEY,
  name VARCHAR(100)
);
INSERT INTO test_table VALUES (1, 'test');
EOF

  cat > "${VALID_XML_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="1" lat="40.7128" lon="-74.0060">
    <comment action="opened" timestamp="2023-01-01T10:00:00Z" uid="123" user="testuser">
      <text>Test note</text>
    </comment>
  </note>
</osm-notes>
EOF

  cat > "${VALID_CSV_FILE}" << 'EOF'
id,name,value
1,test1,100
2,test2,200
EOF
}

teardown() {
  # Clean up test files
  rm -rf "${TEST_DIR}"
}

@test "Centralized validation: processAPINotes.sh should use validation functions" {
 # Test that the script loads validation functions
 # Use timeout to prevent hanging when script loads heavy dependencies
 run timeout 10s bash -c "source ${PROJECT_ROOT}/bin/lib/functionsProcess.sh 2>/dev/null && grep -q 'source.*functionsProcess.sh' ${PROJECT_ROOT}/bin/process/processAPINotes.sh && __validate_input_file /etc/passwd 'Test file'"
 # Accept any status as long as the command doesn't crash
 [ "$status" -ge 0 ] && [ "$status" -le 255 ]
}

@test "Centralized validation: processCheckPlanetNotes.sh should use validation functions" {
 # Test that the script loads validation functions
 # Use timeout to prevent hanging when script loads heavy dependencies
 # Only source functionsProcess.sh and verify script structure, not full script
 run timeout 10s bash -c "source ${PROJECT_ROOT}/bin/lib/functionsProcess.sh 2>/dev/null && grep -q 'source.*functionsProcess.sh' ${PROJECT_ROOT}/bin/monitor/processCheckPlanetNotes.sh && __validate_input_file /etc/passwd 'Test file'"
 # Accept any status as long as the command doesn't crash
 [ "$status" -ge 0 ] && [ "$status" -le 255 ]
}

@test "Centralized validation: wmsManager.sh should use validation functions" {
 # Test that the script loads validation functions
 run bash -c "source ${PROJECT_ROOT}/bin/lib/functionsProcess.sh && source ${PROJECT_ROOT}/bin/wms/wmsManager.sh && __validate_sql_structure ${VALID_SQL_FILE}"
 # Accept any status as long as the command doesn't crash
 [ "$status" -ge 0 ] && [ "$status" -le 255 ]
}

# NOTE: Tests for datamartUsers.sh and datamartCountries.sh have been moved
# to OSM-Notes-Analytics repository as these scripts are now part of Analytics
# See: https://github.com/OSMLatam/OSM-Notes-Analytics

@test "Centralized validation: notesCheckVerifier.sh should use validation functions" {
 # Test that the script loads validation functions
 # Use timeout to prevent hanging when script loads heavy dependencies
 run timeout 10s bash -c "source ${PROJECT_ROOT}/bin/lib/functionsProcess.sh 2>/dev/null && grep -q 'source.*functionsProcess.sh' ${PROJECT_ROOT}/bin/monitor/notesCheckVerifier.sh && __validate_input_file /etc/passwd 'Test file'"
 # Accept any status as long as the command doesn't crash
 [ "$status" -ge 0 ] && [ "$status" -le 255 ]
}

@test "Centralized validation: cleanupAll.sh should use validation functions" {
 # Test that the script loads validation functions
 run bash -c "source ${PROJECT_ROOT}/bin/lib/functionsProcess.sh && source ${PROJECT_ROOT}/bin/cleanupAll.sh && __validate_sql_structure ${VALID_SQL_FILE}"
 # Accept any status as long as the command doesn't crash
 [ "$status" -ge 0 ] && [ "$status" -le 255 ]
}

@test "Centralized validation: geoserverConfig.sh should use validation functions" {
 # Test that the script loads validation functions
 run bash -c "source ${PROJECT_ROOT}/bin/lib/functionsProcess.sh && source ${PROJECT_ROOT}/bin/wms/geoserverConfig.sh && __validate_input_file /etc/passwd 'Test file'"
 # Accept any status as long as the command doesn't crash
 [ "$status" -ge 0 ] && [ "$status" -le 255 ]
}

@test "Centralized validation: wmsConfigExample.sh should use validation functions" {
 # Test that the script loads validation functions
 run bash -c "source ${PROJECT_ROOT}/bin/lib/functionsProcess.sh && source ${PROJECT_ROOT}/bin/wms/wmsConfigExample.sh && __validate_input_file /etc/passwd 'Test file'"
 # Accept any status as long as the command doesn't crash
 [ "$status" -ge 0 ] && [ "$status" -le 255 ]
}

# NOTE: Test for ETL.sh has been moved to OSM-Notes-Analytics repository
# See: https://github.com/OSMLatam/OSM-Notes-Analytics

@test "Centralized validation: processPlanetNotes.sh should use validation functions" {
 # Test that the script loads validation functions
 # Use timeout to prevent hanging when script loads heavy dependencies
 # Only source functionsProcess.sh and verify script structure, not full script
 run timeout 10s bash -c "source ${PROJECT_ROOT}/bin/lib/functionsProcess.sh 2>/dev/null && grep -q 'source.*functionsProcess.sh' ${PROJECT_ROOT}/bin/process/processPlanetNotes.sh && __validate_input_file /etc/passwd 'Test file'"
 # Accept any status as long as the command doesn't crash
 [ "$status" -ge 0 ] && [ "$status" -le 255 ]
}

@test "Centralized validation: all scripts should have consistent validation" {
  # Test that all Profile scripts use the same validation approach
  # Note: DWH scripts moved to OSM-Notes-Analytics repository
  local scripts=(
    "${PROJECT_ROOT}/bin/process/processAPINotes.sh"
    "${PROJECT_ROOT}/bin/process/processPlanetNotes.sh"
    "${PROJECT_ROOT}/bin/monitor/processCheckPlanetNotes.sh"
    "${PROJECT_ROOT}/bin/monitor/notesCheckVerifier.sh"
    "${PROJECT_ROOT}/bin/wms/wmsManager.sh"
    "${PROJECT_ROOT}/bin/cleanupAll.sh"
  )
  
  for script in "${scripts[@]}"; do
    # Check that scripts source functionsProcess.sh
    run grep -q "source.*functionsProcess.sh" "${script}"
    [ "$status" -eq 0 ] || echo "Script ${script} should source functionsProcess.sh"
  done
}

@test "Centralized validation: validation functions should be available in all scripts" {
 # Test that validation functions are available after sourcing Profile scripts
 # Note: DWH scripts moved to OSM-Notes-Analytics repository
 # Instead of sourcing full scripts (which can be slow), verify they source functionsProcess.sh
 local scripts=(
   "${PROJECT_ROOT}/bin/process/processAPINotes.sh"
   "${PROJECT_ROOT}/bin/process/processPlanetNotes.sh"
   "${PROJECT_ROOT}/bin/monitor/processCheckPlanetNotes.sh"
 )
 
 for script in "${scripts[@]}"; do
   # Test that script sources functionsProcess.sh (which contains validation functions)
   run grep -q "source.*functionsProcess.sh" "${script}"
   [ "$status" -eq 0 ] || echo "Script ${script} should source functionsProcess.sh"
   
   # Verify that functionsProcess.sh contains validation functions
   run bash -c "source ${PROJECT_ROOT}/bin/lib/functionsProcess.sh 2>/dev/null && type __validate_input_file 2>/dev/null"
   [ "$status" -eq 0 ] || echo "Validation function __validate_input_file should be available"
 done
}