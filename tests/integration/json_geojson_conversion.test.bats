#!/usr/bin/env bats

# JSON to GeoJSON Conversion Tests
# Tests GeoJSON conversion with validation and retry logic
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"
load "$(dirname "$BATS_TEST_FILENAME")/json_validation_helpers.bash"

setup() {
 __setup_json_validation_test
}

teardown() {
 __teardown_json_validation_test
}

# =============================================================================
# Test: GeoJSON Conversion with Validation and Retry
# =============================================================================
# Purpose: Verify that GeoJSON conversion includes validation and retry logic
# Scenario: Convert JSON to GeoJSON and validate the result
# Expected: GeoJSON should be validated and retry should occur if validation fails
@test "should validate GeoJSON after conversion with retry logic" {
 if ! command -v osmtogeojson > /dev/null; then
  skip "osmtogeojson not available"
 fi

 __check_overpass_connectivity

 local TEST_ID="3793105"
 local JSON_FILE
 JSON_FILE=$(__download_json_from_overpass "${TEST_ID}")

 if [[ -z "${JSON_FILE}" ]]; then
  skip "Download failed - may be rate limited"
 fi

 # Validate JSON before conversion
 if ! __validate_json_with_element "${JSON_FILE}" "elements"; then
  skip "JSON validation failed"
 fi

 local GEOJSON_FILE="${TMP_DIR}/${TEST_ID}.geojson"

 # Simulate GeoJSON conversion with retry logic
 local GEOJSON_VALIDATION_RETRIES=3
 local GEOJSON_VALIDATION_RETRY_COUNT=0
 local GEOJSON_SUCCESS=false

 while [[ ${GEOJSON_VALIDATION_RETRY_COUNT} -lt ${GEOJSON_VALIDATION_RETRIES} ]] && [[ "${GEOJSON_SUCCESS}" == "false" ]]; do
  if [[ ${GEOJSON_VALIDATION_RETRY_COUNT} -gt 0 ]]; then
   rm -f "${GEOJSON_FILE}" 2> /dev/null || true
   sleep 1
  fi

  # Convert to GeoJSON
  if osmtogeojson "${JSON_FILE}" > "${GEOJSON_FILE}" 2> /dev/null; then
   # Validate GeoJSON structure
   if __validate_json_with_element "${GEOJSON_FILE}" "features"; then
    GEOJSON_SUCCESS=true
   else
    GEOJSON_VALIDATION_RETRY_COUNT=$((GEOJSON_VALIDATION_RETRY_COUNT + 1))
   fi
  else
   GEOJSON_VALIDATION_RETRY_COUNT=$((GEOJSON_VALIDATION_RETRY_COUNT + 1))
  fi
 done

 # Should succeed
 [[ "${GEOJSON_SUCCESS}" == "true" ]]
 [[ -f "${GEOJSON_FILE}" ]]
 [[ -s "${GEOJSON_FILE}" ]]
}

# =============================================================================
# Test: Validation Before Expensive Operations
# =============================================================================
# Purpose: Verify that validation happens before expensive operations
# Scenario: JSON fails validation, GeoJSON conversion should not be attempted
# Expected: Validation should prevent expensive GeoJSON conversion
@test "should validate JSON before expensive GeoJSON conversion" {
 # Create a mock JSON that would fail validation
 cat > "${TMP_DIR}/no_elements.json" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API"
}
EOF

 # Should fail validation before attempting conversion
 run __validate_json_with_element "${TMP_DIR}/no_elements.json" "elements"
 [[ "${status}" -eq 1 ]]

 # Verify we didn't create a GeoJSON file
 [[ ! -f "${TMP_DIR}/no_elements.geojson" ]]
}

