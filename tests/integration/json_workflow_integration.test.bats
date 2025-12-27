#!/usr/bin/env bats

# JSON Workflow Integration Tests
# Tests complete workflow: download -> validate -> convert -> validate
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"
load "$(dirname "$BATS_TEST_FILENAME")/service_availability_helpers"
load "$(dirname "$BATS_TEST_FILENAME")/json_validation_helpers.bash"

setup() {
 __setup_json_validation_test
}

teardown() {
 __teardown_json_validation_test
}

# =============================================================================
# Test: Complete Workflow with Validation at Each Step
# =============================================================================
# Purpose: Verify complete workflow with validation at each step
# Scenario: Download -> validate -> convert -> validate
# Expected: All steps should succeed with validation
@test "should complete full workflow with validation at each step" {
 if ! command -v osmtogeojson > /dev/null; then
  skip "osmtogeojson not available"
 fi

 __check_overpass_connectivity

 local TEST_ID="3793105"
 local JSON_FILE="${TMP_DIR}/${TEST_ID}.json"
 local GEOJSON_FILE="${TMP_DIR}/${TEST_ID}.geojson"
 local QUERY_FILE="${TMP_DIR}/query_${TEST_ID}.op"
 local OUTPUT_OVERPASS="${TMP_DIR}/output_${TEST_ID}.txt"

 # Create query
 __create_overpass_query "${TEST_ID}" "${QUERY_FILE}"

 # Step 1: Download with retry logic
 local DOWNLOAD_SUCCESS=false
 local DOWNLOAD_RETRY_COUNT=0
 local MAX_DOWNLOAD_RETRIES=3

 while [[ ${DOWNLOAD_RETRY_COUNT} -lt ${MAX_DOWNLOAD_RETRIES} ]] && [[ "${DOWNLOAD_SUCCESS}" == "false" ]]; do
  if [[ ${DOWNLOAD_RETRY_COUNT} -gt 0 ]]; then
   rm -f "${JSON_FILE}" "${OUTPUT_OVERPASS}" 2> /dev/null || true
   __test_sleep 2
  fi

  run curl -s -H "User-Agent: OSM-Notes-Ingestion/1.0" -o "${JSON_FILE}" --data-binary @"${QUERY_FILE}" "${OVERPASS_INTERPRETER}" 2> "${OUTPUT_OVERPASS}"

  if [ "${status}" -eq 0 ] && [[ -f "${JSON_FILE}" ]] && [[ -s "${JSON_FILE}" ]]; then
   # Step 2: Validate JSON
   if __validate_json_with_element "${JSON_FILE}" "elements"; then
    DOWNLOAD_SUCCESS=true
   else
    DOWNLOAD_RETRY_COUNT=$((DOWNLOAD_RETRY_COUNT + 1))
   fi
  else
   DOWNLOAD_RETRY_COUNT=$((DOWNLOAD_RETRY_COUNT + 1))
  fi
 done

 # Skip if download failed (may be rate limited)
 if [[ "${DOWNLOAD_SUCCESS}" != "true" ]]; then
  skip "Download failed after retries - may be rate limited"
 fi

 # Step 3: Convert to GeoJSON with retry logic
 local GEOJSON_SUCCESS=false
 local GEOJSON_RETRY_COUNT=0
 local MAX_GEOJSON_RETRIES=3

 while [[ ${GEOJSON_RETRY_COUNT} -lt ${MAX_GEOJSON_RETRIES} ]] && [[ "${GEOJSON_SUCCESS}" == "false" ]]; do
  if [[ ${GEOJSON_RETRY_COUNT} -gt 0 ]]; then
   rm -f "${GEOJSON_FILE}" 2> /dev/null || true
   __test_sleep 1
  fi

  # Step 4: Convert
  if osmtogeojson "${JSON_FILE}" > "${GEOJSON_FILE}" 2> /dev/null; then
   # Step 5: Validate GeoJSON
   if __validate_json_with_element "${GEOJSON_FILE}" "features"; then
    GEOJSON_SUCCESS=true
   else
    GEOJSON_RETRY_COUNT=$((GEOJSON_RETRY_COUNT + 1))
   fi
  else
   GEOJSON_RETRY_COUNT=$((GEOJSON_RETRY_COUNT + 1))
  fi
 done

 # Both should succeed
 [[ "${DOWNLOAD_SUCCESS}" == "true" ]]
 [[ "${GEOJSON_SUCCESS}" == "true" ]]
 [[ -f "${JSON_FILE}" ]]
 [[ -f "${GEOJSON_FILE}" ]]
 [[ -s "${GEOJSON_FILE}" ]]
}

