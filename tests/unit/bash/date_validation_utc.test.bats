#!/usr/bin/env bats

# Unit tests for UTC date validation and parsing
# Tests regex patterns and date component extraction for UTC-formatted dates
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
  # Create temporary directory for test
  export TMP_DIR=$(mktemp -d)
  
  # Mock logger functions to avoid dependency on logging library
  function __loge() { echo "ERROR: $*" >&2; }
  function __logi() { echo "INFO: $*" >&2; }
  function __logd() { echo "DEBUG: $*" >&2; }
  function __logw() { echo "WARN: $*" >&2; }
}

teardown() {
  # Clean up temporary directory
  rm -rf "${TMP_DIR}"
}

# =============================================================================
# UTC Date Regex Pattern Validation
# =============================================================================

@test "test UTC date regex pattern" {
  # Test: Validate that UTC date format matches expected regex pattern
  # Purpose: Ensure dates from OSM API in UTC format are correctly recognized
  # Expected: Regex should match standard UTC format: YYYY-MM-DD HH:MM:SS UTC
  local DATE_STRING="2025-08-02 15:06:50 UTC"
  
  # Test the regex pattern
  # Pattern breakdown:
  # - ^[0-9]{4} : 4 digits for year
  # - -[0-9]{2} : 2 digits for month
  # - -[0-9]{2} : 2 digits for day
  # - [[:space:]] : whitespace separator
  # - [0-9]{2}:[0-9]{2}:[0-9]{2} : time in HH:MM:SS format
  # - [[:space:]]UTC$ : UTC timezone indicator
  if [[ "${DATE_STRING}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]UTC$ ]]; then
    echo "Regex match successful"
  else
    echo "Regex match failed"
  fi
  
  # The test should pass if the regex matches
  [[ "${DATE_STRING}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]UTC$ ]]
}

@test "test date component extraction" {
  # Test: Extract individual date/time components from UTC date string
  # Purpose: Verify that regex capture groups correctly extract year, month, day, hour, minute, second
  # Expected: All components should be extracted correctly and match expected values
  local DATE_STRING="2025-08-02 15:06:50 UTC"
  local YEAR MONTH DAY HOUR MINUTE SECOND
  
  # Extract components using regex with capture groups
  # Each component is captured in parentheses and stored in BASH_REMATCH array
  if [[ "${DATE_STRING}" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})[[:space:]]([0-9]{2}):([0-9]{2}):([0-9]{2})[[:space:]]UTC$ ]]; then
    YEAR="${BASH_REMATCH[1]}"    # Capture group 1: year
    MONTH="${BASH_REMATCH[2]}"   # Capture group 2: month
    DAY="${BASH_REMATCH[3]}"     # Capture group 3: day
    HOUR="${BASH_REMATCH[4]}"    # Capture group 4: hour
    MINUTE="${BASH_REMATCH[5]}"  # Capture group 5: minute
    SECOND="${BASH_REMATCH[6]}"  # Capture group 6: second
  else
    echo "Regex extraction failed"
    return 1
  fi
  
  # Verify components match expected values
  [[ "${YEAR}" == "2025" ]]
  [[ "${MONTH}" == "08" ]]
  [[ "${DAY}" == "02" ]]
  [[ "${HOUR}" == "15" ]]
  [[ "${MINUTE}" == "06" ]]
  [[ "${SECOND}" == "50" ]]
  
  # Test numeric comparisons with octal fix
  # Important: Bash interprets numbers starting with 0 as octal (08, 09 are invalid)
  # Using 10# prefix forces decimal interpretation
  [[ $((10#${MONTH})) -eq 8 ]]
  [[ $((10#${DAY})) -eq 2 ]]
  [[ $((10#${HOUR})) -eq 15 ]]
  [[ $((10#${MINUTE})) -eq 6 ]]
  [[ $((10#${SECOND})) -eq 50 ]]
}

@test "test XML date extraction with UTC format" {
  # Test: Extract UTC-formatted dates from XML structure
  # Purpose: Verify that UTC dates can be extracted from OSM XML note elements
  # Expected: All UTC dates in XML should be correctly identified and extracted
  # Create test XML file with UTC dates (simulating OSM API response format)
  cat > "${TMP_DIR}/test.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6">
<note lon="19.9384207" lat="49.8130084">
  <id>3964419</id>
  <date_created>2023-10-30 09:46:47 UTC</date_created>
  <status>closed</status>
  <date_closed>2025-08-02 20:32:40 UTC</date_closed>
  <comments>
    <comment>
      <date>2023-10-30 09:46:47 UTC</date>
      <action>opened</action>
    </comment>
  </comments>
</note>
</osm>
EOF
  
  # Extract UTC dates using xmllint and grep
  # xmllint extracts date elements, grep filters for UTC format pattern
  local DATES
  DATES=$(xmllint --xpath "//date_created|//date_closed|//date" "${TMP_DIR}/test.xml" 2> /dev/null | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\} UTC' || true)
  
  # Verify dates were extracted
  [[ -n "${DATES}" ]]
  # Verify specific dates are present
  echo "${DATES}" | grep -q "2023-10-30 09:46:47 UTC"
  echo "${DATES}" | grep -q "2025-08-02 20:32:40 UTC"
} 