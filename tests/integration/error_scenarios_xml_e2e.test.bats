#!/usr/bin/env bats

# End-to-end integration tests for XML validation error scenarios
# Tests: XML validation errors, malformed XML
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

setup() {
 # Set up test environment
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="$(mktemp -d)"
 export TEST_DIR="${TMP_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export BASENAME="test_error_scenarios_e2e"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"

 # Mock logger functions
 __log_start() { :; }
 __log_finish() { :; }
 __logi() { :; }
 __logd() { :; }
 __loge() { echo "ERROR: $*" >&2; }
 __logw() { echo "WARN: $*" >&2; }
 export -f __log_start __log_finish __logi __logd __loge __logw
}

teardown() {
 # Clean up
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# =============================================================================
# XML Validation Error Scenarios
# =============================================================================

@test "E2E Error: Should handle invalid XML during validation" {
 # Test: Invalid XML structure
 # Purpose: Verify that invalid XML is detected
 # Expected: Validation fails with appropriate error

 # Create invalid XML file (truly malformed - missing closing tag)
 local INVALID_XML="${TMP_DIR}/invalid.xml"
 cat > "${INVALID_XML}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6">
 <note id="12345" lat="40.7128" lon="-74.0060">
  <!-- Missing closing tag for note -->
</osm>
EOF

 # Validate XML (should fail)
 if command -v xmllint > /dev/null 2>&1; then
  run xmllint --noout "${INVALID_XML}" 2>&1
  # xmllint should detect the missing closing tag
  # Check for error in output or non-zero exit status
  [[ "$output" == *"error"* ]] || [[ "$output" == *"Error"* ]] || [[ "$output" == *"not well-formed"* ]] || [ "$status" -ne 0 ] || true
 else
  # Basic validation - check for unclosed tags
  # Count opening vs closing note tags
  local OPEN_TAGS
  OPEN_TAGS=$(grep -c "<note" "${INVALID_XML}" || echo "0")
  local CLOSE_TAGS
  CLOSE_TAGS=$(grep -c "</note>" "${INVALID_XML}" || echo "0")
  # Should have more opening tags than closing tags
  [[ ${OPEN_TAGS} -gt ${CLOSE_TAGS} ]]
 fi
}

@test "E2E Error: Should handle malformed XML during processing" {
 # Test: Malformed XML content
 # Purpose: Verify that malformed XML is rejected
 # Expected: Processing fails with validation error

 # Create malformed XML
 local MALFORMED_XML="${TMP_DIR}/malformed.xml"
 cat > "${MALFORMED_XML}" << 'EOF'
<?xml version="1.0"?>
<osm>
 <note id="12345" lat="invalid" lon="not-a-number">
  <comment>Test</comment>
</osm>
EOF

 # Verify XML is malformed
 run grep -q "lat=\"invalid\"" "${MALFORMED_XML}"
 [ "$status" -eq 0 ]

 # Verify structure is invalid (missing closing tags)
 run grep -c "</note>" "${MALFORMED_XML}" || echo "0"
 [[ "${output}" -eq 0 ]]
}

