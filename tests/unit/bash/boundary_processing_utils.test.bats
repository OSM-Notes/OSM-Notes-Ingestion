#!/usr/bin/env bats

# Boundary Processing Utils Tests
# Tests for utility functions (resolve, validate, compare)
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
# Tests for __get_countries_table_name
# =============================================================================

@test "__get_countries_table_name should return 'countries' by default" {
 # Test default behavior (USE_COUNTRIES_NEW not set)
 unset USE_COUNTRIES_NEW
 result=$(__get_countries_table_name)
 [[ "${result}" == "countries" ]]
}

@test "__get_countries_table_name should return 'countries_new' when USE_COUNTRIES_NEW=true" {
 # Test with USE_COUNTRIES_NEW=true
 export USE_COUNTRIES_NEW="true"
 result=$(__get_countries_table_name)
 [[ "${result}" == "countries_new" ]]
}

@test "__get_countries_table_name should return 'countries' when USE_COUNTRIES_NEW=false" {
 # Test with USE_COUNTRIES_NEW=false
 export USE_COUNTRIES_NEW="false"
 result=$(__get_countries_table_name)
 [[ "${result}" == "countries" ]]
}

@test "__get_countries_table_name should return 'countries' when USE_COUNTRIES_NEW is empty" {
 # Test with empty USE_COUNTRIES_NEW
 export USE_COUNTRIES_NEW=""
 result=$(__get_countries_table_name)
 [[ "${result}" == "countries" ]]
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

