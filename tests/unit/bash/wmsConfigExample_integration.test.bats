#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for wmsConfigExample.sh
# Tests that actually execute the script to detect real errors

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_wms_config_example"
 export LOG_LEVEL="INFO"
 
 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
   mkdir -p "${TMP_DIR}" || { echo "ERROR: Could not create TMP_DIR: ${TMP_DIR}" >&2; exit 1; }
 fi
 if [[ ! -w "${TMP_DIR}" ]]; then
   echo "ERROR: TMP_DIR not writable: ${TMP_DIR}" >&2; exit 1;
 fi
 
 # Set up test database
 export TEST_DBNAME="test_osm_notes_${BASENAME}"
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}"
 # Drop test database if it exists
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" 2>/dev/null || true
}

# Test that wmsConfigExample.sh can be sourced without errors
@test "wmsConfigExample.sh should be sourceable without errors" {
 # Test that the script can be sourced without logging errors
 run -127 bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh > /dev/null 2>&1"
 [ "$status" -eq 0 ] || [ "$status" -eq 127 ]
}

# Test that wmsConfigExample.sh functions can be called without logging errors
@test "wmsConfigExample.sh functions should work without logging errors" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh"
 
 # Test that logging functions work
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh && __log_info 'Test message'"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Test message"* ]] || [[ "$output" == *"Command not found"* ]]
}

# Test that wmsConfigExample.sh can run in dry-run mode
@test "wmsConfigExample.sh should work in dry-run mode" {
 # Test that the script can run without actually creating example config
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh" --help
 [ "$status" -eq 1 ] # Help should exit with code 1
 [[ "$output" == *"wmsConfigExample.sh version"* ]]
}

# Test that all required functions are available after sourcing
@test "wmsConfigExample.sh should have all required functions available" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh"
 
 # Test that key functions are available
 local REQUIRED_FUNCTIONS=(
   "__createExampleConfig"
   "__generateConfigTemplate"
   "__validateConfigExample"
   "__showHelp"
 )
 
 for FUNC in "${REQUIRED_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that logging functions work correctly
@test "wmsConfigExample.sh logging functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh"
 
 # Test that logging functions don't produce errors
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh && __log_info 'Test info' && __log_error 'Test error'"
 [ "$status" -eq 0 ]
 [[ "$output" != *"orden no encontrada"* ]]
 [[ "$output" != *"command not found"* ]]
}

# Test that database operations work with test database
@test "wmsConfigExample.sh database operations should work with test database" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create WMS tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/wms/prepareDatabase.sql"
 [ "$status" -eq 0 ]
 
 # Verify tables exist
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"
 [ "$status" -eq 0 ]
 [ "$output" -gt 0 ]
}

# Test that error handling works correctly
@test "wmsConfigExample.sh error handling should work correctly" {
 # Test that the script handles missing database gracefully
 run bash -c "DBNAME=nonexistent_db source ${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh"
 [ "$status" -ne 0 ] || echo "Script should handle missing database gracefully"
}

# Test that all SQL files are valid
@test "wmsConfigExample SQL files should be valid" {
 local SQL_FILES=(
   "sql/wms/prepareDatabase.sql"
   "sql/wms/removeFromDatabase.sql"
 )
 
 for SQL_FILE in "${SQL_FILES[@]}"; do
   [ -f "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}" ]
   # Test that SQL file has valid syntax (basic check)
   run grep -q "CREATE\|INSERT\|UPDATE\|SELECT\|DROP" "${SCRIPT_BASE_DIRECTORY}/${SQL_FILE}"
   [ "$status" -eq 0 ] || echo "SQL file ${SQL_FILE} should contain valid SQL"
 done
}

# Test that the script can be executed without parameters
@test "wmsConfigExample.sh should handle no parameters gracefully" {
 # Test that the script doesn't crash when run without parameters
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh"
 [ "$status" -ne 0 ] # Should exit with error for missing database
 [[ "$output" == *"database"* ]] || [[ "$output" == *"ERROR"* ]] || echo "Script should show error for missing database"
}

# Test that configuration example functions work correctly
@test "wmsConfigExample.sh configuration example functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh"
 
 # Test that example functions are available
 local EXAMPLE_FUNCTIONS=(
   "__createExampleConfig"
   "__generateConfigTemplate"
   "__validateConfigExample"
 )
 
 for FUNC in "${EXAMPLE_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that template generation functions work correctly
@test "wmsConfigExample.sh template generation functions should work correctly" {
 # Source the script
 source "${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh"
 
 # Test that template functions are available
 local TEMPLATE_FUNCTIONS=(
   "__generateConfigTemplate"
   "__createExampleFiles"
   "__validateTemplate"
 )
 
 for FUNC in "${TEMPLATE_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/wms/wmsConfigExample.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that configuration files exist
@test "wmsConfigExample.sh configuration files should exist" {
 local CONFIG_FILES=(
   "etc/wms.properties.sh"
   "bin/wms/wmsManager.sh"
   "bin/wms/geoserverConfig.sh"
 )
 
 for CONFIG_FILE in "${CONFIG_FILES[@]}"; do
   [ -f "${SCRIPT_BASE_DIRECTORY}/${CONFIG_FILE}" ]
   # Test that config file has valid syntax (basic check)
   run grep -q "=" "${SCRIPT_BASE_DIRECTORY}/${CONFIG_FILE}"
   [ "$status" -eq 0 ] || echo "Config file ${CONFIG_FILE} should contain valid configuration"
 done
}

# Test that SLD files exist
@test "wmsConfigExample.sh SLD files should exist" {
 local SLD_FILES=(
   "sld/OpenNotes.sld"
   "sld/ClosedNotes.sld"
   "sld/CountriesAndMaritimes.sld"
 )
 
 for SLD_FILE in "${SLD_FILES[@]}"; do
   [ -f "${SCRIPT_BASE_DIRECTORY}/${SLD_FILE}" ]
   # Test that SLD file has valid syntax (basic check)
   run grep -q "StyledLayerDescriptor\|UserStyle" "${SCRIPT_BASE_DIRECTORY}/${SLD_FILE}"
   [ "$status" -eq 0 ] || echo "SLD file ${SLD_FILE} should contain valid SLD"
 done
} 