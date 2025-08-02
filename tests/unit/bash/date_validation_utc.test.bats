#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
  # Create temporary directory for test
  export TMP_DIR=$(mktemp -d)
  
  # Mock logger functions
  function __loge() { echo "ERROR: $*" >&2; }
  function __logi() { echo "INFO: $*" >&2; }
  function __logd() { echo "DEBUG: $*" >&2; }
  function __logw() { echo "WARN: $*" >&2; }
}

teardown() {
  rm -rf "${TMP_DIR}"
}

@test "test UTC date regex pattern" {
  # Test the regex pattern directly
  local DATE_STRING="2025-08-02 15:06:50 UTC"
  
  # Test the regex pattern
  if [[ "${DATE_STRING}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]UTC$ ]]; then
    echo "Regex match successful"
  else
    echo "Regex match failed"
  fi
  
  # The test should pass if the regex matches
  [[ "${DATE_STRING}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]UTC$ ]]
}

@test "test date component extraction" {
  # Test date component extraction using regex
  local DATE_STRING="2025-08-02 15:06:50 UTC"
  local YEAR MONTH DAY HOUR MINUTE SECOND
  
  # Extract components using regex
  if [[ "${DATE_STRING}" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})[[:space:]]([0-9]{2}):([0-9]{2}):([0-9]{2})[[:space:]]UTC$ ]]; then
    YEAR="${BASH_REMATCH[1]}"
    MONTH="${BASH_REMATCH[2]}"
    DAY="${BASH_REMATCH[3]}"
    HOUR="${BASH_REMATCH[4]}"
    MINUTE="${BASH_REMATCH[5]}"
    SECOND="${BASH_REMATCH[6]}"
  else
    echo "Regex extraction failed"
    return 1
  fi
  
  # Verify components
  [[ "${YEAR}" == "2025" ]]
  [[ "${MONTH}" == "08" ]]
  [[ "${DAY}" == "02" ]]
  [[ "${HOUR}" == "15" ]]
  [[ "${MINUTE}" == "06" ]]
  [[ "${SECOND}" == "50" ]]
  
  # Test numeric comparisons with octal fix
  [[ $((10#${MONTH})) -eq 8 ]]
  [[ $((10#${DAY})) -eq 2 ]]
  [[ $((10#${HOUR})) -eq 15 ]]
  [[ $((10#${MINUTE})) -eq 6 ]]
  [[ $((10#${SECOND})) -eq 50 ]]
}

@test "test XML date extraction with UTC format" {
  # Create test XML file with UTC dates
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
  
  # Test that the regex extracts UTC dates correctly
  local DATES
  DATES=$(xmllint --xpath "//date_created|//date_closed|//date" "${TMP_DIR}/test.xml" 2> /dev/null | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\} UTC' || true)
  
  [[ -n "${DATES}" ]]
  echo "${DATES}" | grep -q "2023-10-30 09:46:47 UTC"
  echo "${DATES}" | grep -q "2025-08-02 20:32:40 UTC"
} 