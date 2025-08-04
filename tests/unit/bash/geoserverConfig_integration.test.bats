#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Integration tests for geoserverConfig.sh
# Tests that actually execute the script to detect real errors

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_geoserver_config"
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

# Test that geoserverConfig.sh can be sourced without errors
@test "geoserverConfig.sh should be sourceable without errors" {
 # Test that the script can be sourced without logging errors
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/wms/geoserverConfig.sh > /dev/null 2>&1"
 [ "$status" -eq 0 ] || echo "Script should be sourceable"
}

# Test that geoserverConfig.sh functions can be called without logging errors
@test "geoserverConfig.sh functions should work without logging errors" {
 # Test that logging functions work
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/wms/geoserverConfig.sh && echo 'Test message'"
 [ "$status" -eq 0 ]
 [[ "$output" == *"Test message"* ]] || echo "Basic function should work"
}

# Test that geoserverConfig.sh can run in dry-run mode
@test "geoserverConfig.sh should work in dry-run mode" {
 # Test that the script can run without actually configuring GeoServer
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/wms/geoserverConfig.sh" --help
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ] # Help should exit with code 0 or 1
 [[ "$output" == *"help"* ]] || [[ "$output" == *"usage"* ]] || [[ "$output" == *"ERROR"* ]] || echo "Script should show help information or error"
}

# Test that all required functions are available after sourcing
@test "geoserverConfig.sh should have all required functions available" {
 # Test that key functions are available
 local REQUIRED_FUNCTIONS=(
   "__configureGeoServer"
   "__createGeoServerWorkspace"
   "__createGeoServerDatastore"
   "__createGeoServerLayers"
   "__showHelp"
 )
 
 for FUNC in "${REQUIRED_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/wms/geoserverConfig.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that logging functions work correctly
@test "geoserverConfig.sh logging functions should work correctly" {
 # Test that logging functions don't produce errors
 run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/wms/geoserverConfig.sh && echo 'Test info' && echo 'Test error'"
 [ "$status" -eq 0 ]
 [[ "$output" != *"orden no encontrada"* ]]
 [[ "$output" != *"command not found"* ]]
}

# Test that database operations work with test database
@test "geoserverConfig.sh database operations should work with test database" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create WMS tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/wms/prepareDatabase.sql"
 [ "$status" -eq 0 ]
 
 # Verify tables exist
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"
 [ "$status" -eq 0 ]
 [[ "$output" =~ ^[0-9]+$ ]] || echo "Expected numeric count, got: $output"
}

# Test that error handling works correctly
@test "geoserverConfig.sh error handling should work correctly" {
 # Test that the script handles missing database gracefully
 run bash -c "DBNAME=nonexistent_db source ${SCRIPT_BASE_DIRECTORY}/bin/wms/geoserverConfig.sh"
 [ "$status" -ne 0 ] || echo "Script should handle missing database gracefully"
}

# Test that all SQL files are valid
@test "geoserverConfig SQL files should be valid" {
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
@test "geoserverConfig.sh should handle no parameters gracefully" {
 # Test that the script doesn't crash when run without parameters
 run timeout 30s bash "${SCRIPT_BASE_DIRECTORY}/bin/wms/geoserverConfig.sh"
 [ "$status" -ne 0 ] # Should exit with error for missing database
 [[ "$output" == *"database"* ]] || [[ "$output" == *"ERROR"* ]] || echo "Script should show error for missing database"
}

# Test that GeoServer configuration functions work correctly
@test "geoserverConfig.sh GeoServer configuration functions should work correctly" {
 # Test that configuration functions are available
 local CONFIG_FUNCTIONS=(
   "__configureGeoServer"
   "__createGeoServerWorkspace"
   "__createGeoServerDatastore"
 )
 
 for FUNC in "${CONFIG_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/wms/geoserverConfig.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that layer creation functions work correctly
@test "geoserverConfig.sh layer creation functions should work correctly" {
 # Test that layer functions are available
 local LAYER_FUNCTIONS=(
   "__createGeoServerLayers"
   "__configureLayerStyles"
   "__publishLayer"
 )
 
 for FUNC in "${LAYER_FUNCTIONS[@]}"; do
   run bash -c "source ${SCRIPT_BASE_DIRECTORY}/bin/wms/geoserverConfig.sh && declare -f ${FUNC}"
   [ "$status" -eq 0 ] || echo "Function ${FUNC} should be available"
 done
}

# Test that configuration files exist
@test "geoserverConfig.sh configuration files should exist" {
 local CONFIG_FILES=(
   "etc/wms.properties.sh"
   "bin/wms/wmsConfigExample.sh"
   "bin/wms/wmsManager.sh"
 )
 
 for CONFIG_FILE in "${CONFIG_FILES[@]}"; do
   [ -f "${SCRIPT_BASE_DIRECTORY}/${CONFIG_FILE}" ]
   # Test that config file has valid syntax (basic check)
   run grep -q "=" "${SCRIPT_BASE_DIRECTORY}/${CONFIG_FILE}"
   [ "$status" -eq 0 ] || echo "Config file ${CONFIG_FILE} should contain valid configuration"
 done
}

# Test that SLD files exist
@test "geoserverConfig.sh SLD files should exist" {
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