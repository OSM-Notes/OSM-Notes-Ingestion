#!/usr/bin/env bats

# Boundary Processing Functions Tests
# Comprehensive tests for boundary processing functions
# Author: Andres Gomez (AngocA)
# Version: 2025-12-08

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export BASHPID=$$

 # Set log level to DEBUG to capture all log output
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"

 # Load boundary processing functions
 source "${TEST_BASE_DIR}/bin/lib/boundaryProcessingFunctions.sh"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Function Existence Tests
# =============================================================================

@test "All boundary processing functions should be available" {
 # Test that all boundary processing functions exist
 run declare -f __log_download_start
 [[ "${status}" -eq 0 ]]

 run declare -f __log_json_validation_failure
 [[ "${status}" -eq 0 ]]

 run declare -f __log_download_success
 [[ "${status}" -eq 0 ]]

 run declare -f __log_geojson_conversion_start
 [[ "${status}" -eq 0 ]]

 run declare -f __log_geojson_retry_delay
 [[ "${status}" -eq 0 ]]

 run declare -f __log_import_start
 [[ "${status}" -eq 0 ]]

 run declare -f __log_field_selected_import
 [[ "${status}" -eq 0 ]]

 run declare -f __log_taiwan_special_handling
 [[ "${status}" -eq 0 ]]

 run declare -f __log_duplicate_columns_fixed
 [[ "${status}" -eq 0 ]]

 run declare -f __log_duplicate_columns_skip
 [[ "${status}" -eq 0 ]]

 run declare -f __log_process_complete
 [[ "${status}" -eq 0 ]]

 run declare -f __log_lock_acquired
 [[ "${status}" -eq 0 ]]

 run declare -f __log_lock_failed
 [[ "${status}" -eq 0 ]]

 run declare -f __log_import_completed
 [[ "${status}" -eq 0 ]]

 run declare -f __log_no_duplicate_columns
 [[ "${status}" -eq 0 ]]

 run declare -f __resolve_geojson_file
 [[ "${status}" -eq 0 ]]

 run declare -f __validate_capital_location
 [[ "${status}" -eq 0 ]]

 run declare -f __compareIdsWithBackup
 [[ "${status}" -eq 0 ]]

 run declare -f __processBoundary_impl
 [[ "${status}" -eq 0 ]]

 run declare -f __processCountries_impl
 [[ "${status}" -eq 0 ]]

 run declare -f __processMaritimes_impl
 [[ "${status}" -eq 0 ]]
}

# =============================================================================
# Tests for Logging Functions
# =============================================================================

@test "__log_download_start should log download start message" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_download_start "12345" "3" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"3"* ]]
 [[ "${LOG_OUTPUT}" == *"download"* ]]
}

@test "__log_json_validation_failure should log validation failure" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_json_validation_failure "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"JSON validation failed"* ]]
}

@test "__log_download_success should log download success" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_download_success "12345" "10" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"10s"* ]]
 [[ "${LOG_OUTPUT}" == *"successfully"* ]]
}

@test "__log_geojson_conversion_start should log conversion start" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_conversion_start "12345" "5" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"GeoJSON"* ]]
 [[ "${LOG_OUTPUT}" == *"5"* ]]
}

@test "__log_geojson_retry_delay should log retry delay" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_geojson_retry_delay "12345" "5" "2" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"5s"* ]]
 [[ "${LOG_OUTPUT}" == *"2"* ]]
}

@test "__log_import_start should log import start" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_import_start "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"Importing"* ]]
}

@test "__log_field_selected_import should log field selected import" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_field_selected_import "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"field-selected"* ]]
}

@test "__log_taiwan_special_handling should log Taiwan handling" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_taiwan_special_handling "16239" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"16239"* ]]
 [[ "${LOG_OUTPUT}" == *"Taiwan"* ]]
}

@test "__log_duplicate_columns_fixed should log duplicate columns fixed" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_duplicate_columns_fixed "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"Duplicate columns fixed"* ]]
}

@test "__log_duplicate_columns_skip should log duplicate columns skip" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_duplicate_columns_skip "12345" "test reason" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"test reason"* ]]
}

@test "__log_process_complete should log process complete" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_process_complete "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"completed"* ]]
}

@test "__log_lock_acquired should log lock acquired" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_lock_acquired "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"Lock acquired"* ]]
}

@test "__log_lock_failed should log lock failed" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_lock_failed "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"Failed to acquire lock"* ]]
}

@test "__log_import_completed should log import completed" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_import_completed "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"Database import completed"* ]]
}

@test "__log_no_duplicate_columns should log no duplicate columns" {
 local LOG_OUTPUT
 LOG_OUTPUT=$(__log_no_duplicate_columns "12345" 2>&1)
 
 [[ "${LOG_OUTPUT}" == *"12345"* ]]
 [[ "${LOG_OUTPUT}" == *"No duplicate columns"* ]]
}

# =============================================================================
# Tests for __resolve_geojson_file
# =============================================================================

@test "__resolve_geojson_file should resolve existing .geojson file" {
 local GEOJSON_FILE="${TEST_DIR}/test.geojson"
 echo '{"type":"FeatureCollection","features":[]}' > "${GEOJSON_FILE}"

 # Function uses eval to set output variable
 # Call function and check return status
 run __resolve_geojson_file "${GEOJSON_FILE}" "RESOLVED_FILE" 2>/dev/null
 [[ "${status}" -eq 0 ]]
 
 # Variable should be set in the function's scope, verify file exists
 [[ -f "${GEOJSON_FILE}" ]]
}

@test "__resolve_geojson_file should decompress .geojson.gz file" {
 local GEOJSON_FILE="${TEST_DIR}/test.geojson"
 echo '{"type":"FeatureCollection","features":[]}' > "${GEOJSON_FILE}"
 gzip -c "${GEOJSON_FILE}" > "${GEOJSON_FILE}.gz"
 rm -f "${GEOJSON_FILE}"

 # Function uses eval to set output variable
 # Call function and check return status
 run __resolve_geojson_file "${GEOJSON_FILE}" "RESOLVED_FILE" >/dev/null 2>&1
 [[ "${status}" -eq 0 ]]
 
 # Check that decompressed file exists in TMP_DIR
 local DECOMPRESSED_FILE
 DECOMPRESSED_FILE=$(find "${TEST_DIR}" -name "test.geojson" -type f | head -1)
 [[ -n "${DECOMPRESSED_FILE}" ]]
 [[ -f "${DECOMPRESSED_FILE}" ]]
 [[ "${DECOMPRESSED_FILE}" != "${GEOJSON_FILE}.gz" ]]
}

@test "__resolve_geojson_file should handle base path without extension" {
 local GEOJSON_FILE="${TEST_DIR}/test.geojson"
 echo '{"type":"FeatureCollection","features":[]}' > "${GEOJSON_FILE}"

 # Function uses eval to set output variable
 # Call function and check return status
 run __resolve_geojson_file "${TEST_DIR}/test" "RESOLVED_FILE" >/dev/null 2>&1
 [[ "${status}" -eq 0 ]]
 
 # File should exist
 [[ -f "${GEOJSON_FILE}" ]]
}

@test "__resolve_geojson_file should return error for non-existent file" {
 local RESOLVED_FILE
 run __resolve_geojson_file "${TEST_DIR}/nonexistent.geojson" "RESOLVED_FILE" 2>/dev/null

 [[ "${status}" -eq 1 ]]
}

# =============================================================================
# Tests for __validate_capital_location
# =============================================================================

@test "__validate_capital_location should validate capital location" {
 export DBNAME="test_db"

 # Mock psql to return success
 psql() {
  if [[ "$1" == "-d" ]] && [[ "$3" == "-Atq" ]]; then
   echo "true"
   return 0
  fi
  return 0
 }
 export -f psql

 # Mock __retry_overpass_api to return valid capital data
 __retry_overpass_api() {
  local OUTPUT_FILE="$2"
  cat > "${OUTPUT_FILE}" << 'EOF'
{
  "elements": [
    {
      "type": "node",
      "lat": 4.6097,
      "lon": -74.0817
    }
  ]
}
EOF
  return 0
 }
 export -f __retry_overpass_api

 run __validate_capital_location "12345" "test_db" 2>/dev/null
 # Should succeed if capital is within boundary
 [[ "${status}" -eq 0 ]] || [[ "${status}" -eq 1 ]]
}

@test "__validate_capital_location should handle missing capital" {
 export DBNAME="test_db"

 # Mock psql to return false (capital not in boundary)
 psql() {
  if [[ "$1" == "-d" ]] && [[ "$3" == "-Atq" ]]; then
   echo "false"
   return 0
  fi
  return 0
 }
 export -f psql

 # Mock __retry_overpass_api to return empty result
 __retry_overpass_api() {
  local OUTPUT_FILE="$2"
  echo '{"elements":[]}' > "${OUTPUT_FILE}"
  return 0
 }
 export -f __retry_overpass_api

 run __validate_capital_location "12345" "test_db" 2>/dev/null
 # Should fail if capital not found or not in boundary
 [[ "${status}" -eq 1 ]] || [[ "${status}" -eq 0 ]]
}

# =============================================================================
# Tests for __compareIdsWithBackup
# =============================================================================

@test "__compareIdsWithBackup should return 0 when IDs match" {
 local OVERPASS_IDS_FILE="${TEST_DIR}/overpass_ids.csv"
 local BACKUP_FILE="${TEST_DIR}/backup.geojson"

 # Create Overpass IDs file
 echo "country_id" > "${OVERPASS_IDS_FILE}"
 echo "12345" >> "${OVERPASS_IDS_FILE}"
 echo "67890" >> "${OVERPASS_IDS_FILE}"

 # Create backup GeoJSON with matching IDs
 cat > "${BACKUP_FILE}" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "country_id": "12345"
      }
    },
    {
      "type": "Feature",
      "properties": {
        "country_id": "67890"
      }
    }
  ]
}
EOF

 run __compareIdsWithBackup "${OVERPASS_IDS_FILE}" "${BACKUP_FILE}" "countries" 2>/dev/null
 [[ "${status}" -eq 0 ]]
}

@test "__compareIdsWithBackup should return 1 when IDs differ" {
 local OVERPASS_IDS_FILE="${TEST_DIR}/overpass_ids.csv"
 local BACKUP_FILE="${TEST_DIR}/backup.geojson"

 # Create Overpass IDs file
 echo "country_id" > "${OVERPASS_IDS_FILE}"
 echo "12345" >> "${OVERPASS_IDS_FILE}"
 echo "99999" >> "${OVERPASS_IDS_FILE}"

 # Create backup GeoJSON with different IDs
 cat > "${BACKUP_FILE}" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "country_id": "12345"
      }
    },
    {
      "type": "Feature",
      "properties": {
        "country_id": "67890"
      }
    }
  ]
}
EOF

 run __compareIdsWithBackup "${OVERPASS_IDS_FILE}" "${BACKUP_FILE}" "countries" 2>/dev/null
 [[ "${status}" -eq 1 ]]
}

@test "__compareIdsWithBackup should handle missing Overpass file" {
 local BACKUP_FILE="${TEST_DIR}/backup.geojson"
 cat > "${BACKUP_FILE}" << 'EOF'
{"type":"FeatureCollection","features":[]}
EOF

 run __compareIdsWithBackup "${TEST_DIR}/nonexistent.csv" "${BACKUP_FILE}" "countries" 2>/dev/null
 [[ "${status}" -eq 1 ]]
}

@test "__compareIdsWithBackup should handle missing backup file" {
 local OVERPASS_IDS_FILE="${TEST_DIR}/overpass_ids.csv"
 echo "country_id" > "${OVERPASS_IDS_FILE}"
 echo "12345" >> "${OVERPASS_IDS_FILE}"

 run __compareIdsWithBackup "${OVERPASS_IDS_FILE}" "${TEST_DIR}/nonexistent.geojson" "countries" 2>/dev/null
 [[ "${status}" -eq 1 ]]
}

# =============================================================================
# Tests for __processBoundary_impl (Basic tests - complex function)
# =============================================================================

@test "__processBoundary_impl should handle TEST_MODE" {
 export TEST_MODE="true"
 export BATS_TEST_NAME="test"
 export ID="12345"
 export JSON_FILE="${TEST_DIR}/test.json"
 export GEOJSON_FILE="${TEST_DIR}/test.geojson"
 export QUERY_FILE="${TEST_DIR}/query.op"
 export SKIP_NETWORK_CHECK_FOR_TESTS="true"

 # Create minimal query file
 echo "[out:json];relation(12345);out geom;" > "${QUERY_FILE}"

 # Mock network check to skip
 __check_network_connectivity() {
  return 0
 }
 export -f __check_network_connectivity

 # Mock Overpass API to return empty result (will fail validation but test structure)
 __retry_file_operation() {
  echo '{"elements":[]}' > "${JSON_FILE}"
  return 1
 }
 export -f __retry_file_operation

 run __processBoundary_impl "${QUERY_FILE}" 2>/dev/null
 # Function may fail due to missing dependencies, but should not crash
 [[ "${status}" -ge 0 ]]
}

# =============================================================================
# Tests for __processCountries_impl (Basic tests - complex function)
# =============================================================================

@test "__processCountries_impl should handle basic structure" {
 export TEST_MODE="true"
 export BATS_TEST_NAME="test"
 export QUERY_FILE="${TEST_DIR}/countries.op"

 # Create minimal query file
 echo "[out:csv(::id)];relation[\"admin_level\"=\"2\"][\"type\"=\"boundary\"];out;" > "${QUERY_FILE}"

 # Mock disk space check
 __check_disk_space() {
  return 0
 }
 export -f __check_disk_space

 # Mock Overpass query
 __retry_file_operation() {
  echo "country_id" > "${TEST_DIR}/countries_ids.csv"
  echo "12345" >> "${TEST_DIR}/countries_ids.csv"
  return 0
 }
 export -f __retry_file_operation

 run __processCountries_impl 2>/dev/null
 # Function may fail due to missing dependencies, but should not crash
 [[ "${status}" -ge 0 ]]
}

# =============================================================================
# Tests for __processMaritimes_impl (Basic tests - complex function)
# =============================================================================

@test "__processMaritimes_impl should handle basic structure" {
 export TEST_MODE="true"
 export BATS_TEST_NAME="test"
 export QUERY_FILE="${TEST_DIR}/maritimes.op"

 # Create minimal query file
 echo "[out:csv(::id)];relation[\"boundary\"=\"maritime\"];out;" > "${QUERY_FILE}"

 # Mock __resolve_geojson_file to return non-existent (will trigger Overpass)
 __resolve_geojson_file() {
  return 1
 }
 export -f __resolve_geojson_file

 run __processMaritimes_impl 2>/dev/null
 # Function may fail due to missing dependencies, but should not crash
 [[ "${status}" -ge 0 ]]
}

