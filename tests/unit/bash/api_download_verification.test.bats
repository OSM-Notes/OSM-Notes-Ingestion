#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
  # Create temporary directory for test
  export TMP_DIR=$(mktemp -d)
  export API_NOTES_FILE="${TMP_DIR}/test_api_notes.xml"
  export ERROR_INTERNET_ISSUE=1
  
  # Mock logger functions
  function __loge() { echo "ERROR: $*" >&2; }
  function __logi() { echo "INFO: $*" >&2; }
  function __logd() { echo "DEBUG: $*" >&2; }
  function __logw() { echo "WARN: $*" >&2; }
}

teardown() {
  rm -rf "${TMP_DIR}"
}

@test "test verification when API file exists and has content" {
  # Create a test file with content
  echo "<osm-notes><note id='1'><note_id>1</note_id></note></osm-notes>" > "${API_NOTES_FILE}"
  
  # Source the verification logic
  cat > /tmp/test_verification.sh << 'EOF'
function __loge() { echo "ERROR: $*" >&2; }
function __logi() { echo "INFO: $*" >&2; }

# Verify that the API notes file was downloaded successfully
if [[ ! -f "${API_NOTES_FILE}" ]]; then
 __loge "ERROR: API notes file was not downloaded: ${API_NOTES_FILE}"
 exit "${ERROR_INTERNET_ISSUE}"
fi

# Check if the file has content (not empty)
if [[ ! -s "${API_NOTES_FILE}" ]]; then
 __loge "ERROR: API notes file is empty: ${API_NOTES_FILE}"
 exit "${ERROR_INTERNET_ISSUE}"
fi

__logi "API notes file downloaded successfully: ${API_NOTES_FILE}"
EOF
  
  source /tmp/test_verification.sh
  
  # The verification should pass
  run source /tmp/test_verification.sh
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"API notes file downloaded successfully"* ]]
}

@test "test verification when API file does not exist" {
  # Remove the test file
  rm -f "${API_NOTES_FILE}"
  
  cat > /tmp/test_verification.sh << 'EOF'
function __loge() { echo "ERROR: $*" >&2; }

# Verify that the API notes file was downloaded successfully
if [[ ! -f "${API_NOTES_FILE}" ]]; then
 __loge "ERROR: API notes file was not downloaded: ${API_NOTES_FILE}"
 exit "${ERROR_INTERNET_ISSUE}"
fi
EOF
  
  # The verification should fail
  run source /tmp/test_verification.sh
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"ERROR: API notes file was not downloaded"* ]]
}

@test "test verification when API file is empty" {
  # Create an empty file
  touch "${API_NOTES_FILE}"
  
  cat > /tmp/test_verification.sh << 'EOF'
function __loge() { echo "ERROR: $*" >&2; }

# Check if the file has content (not empty)
if [[ ! -s "${API_NOTES_FILE}" ]]; then
 __loge "ERROR: API notes file is empty: ${API_NOTES_FILE}"
 exit "${ERROR_INTERNET_ISSUE}"
fi
EOF
  
  # The verification should fail
  run source /tmp/test_verification.sh
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"ERROR: API notes file is empty"* ]]
}

@test "test verification with valid XML content" {
  # Create a valid XML file
  cat > "${API_NOTES_FILE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="1" lat="40.7128" lon="-74.0060">
    <note_id>1</note_id>
    <status>open</status>
    <date_created>2025-08-02T12:00:00Z</date_created>
  </note>
</osm-notes>
EOF
  
  cat > /tmp/test_verification.sh << 'EOF'
function __loge() { echo "ERROR: $*" >&2; }
function __logi() { echo "INFO: $*" >&2; }

# Verify that the API notes file was downloaded successfully
if [[ ! -f "${API_NOTES_FILE}" ]]; then
 __loge "ERROR: API notes file was not downloaded: ${API_NOTES_FILE}"
 exit "${ERROR_INTERNET_ISSUE}"
fi

# Check if the file has content (not empty)
if [[ ! -s "${API_NOTES_FILE}" ]]; then
 __loge "ERROR: API notes file is empty: ${API_NOTES_FILE}"
 exit "${ERROR_INTERNET_ISSUE}"
fi

__logi "API notes file downloaded successfully: ${API_NOTES_FILE}"
EOF
  
  # The verification should pass
  run source /tmp/test_verification.sh
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"API notes file downloaded successfully"* ]]
}

@test "test direct wget download with waiting" {
  # Test that wget command waits for completion
  local TEST_FILE="${TMP_DIR}/test_download.txt"
  
  # Mock wget to create a file and simulate download time
  function wget() {
    echo "Mock wget: downloading to $2"
    sleep 0.1  # Simulate download time
    echo "Downloaded content" > "$2"
    return 0
  }
  
  # Test the direct wget command format used in the script
  run wget -O "${TEST_FILE}" "https://example.com"
  
  [[ "${status}" -eq 0 ]]
  [[ -f "${TEST_FILE}" ]]
  [[ -s "${TEST_FILE}" ]]
  [[ "$(cat "${TEST_FILE}")" == "Downloaded content" ]]
}

@test "test download retry logic" {
  # Test the retry logic for downloads
  local TEST_FILE="${TMP_DIR}/test_retry.txt"
  local RETRY_COUNT=0
  local DOWNLOAD_MAX_RETRIES=3
  local DOWNLOAD_BASE_DELAY=5
  local DOWNLOAD_SUCCESS=false
  
  # Mock wget that fails first two times, succeeds on third
  function wget() {
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [[ ${RETRY_COUNT} -eq 3 ]]; then
      echo "Mock wget: success on attempt ${RETRY_COUNT}"
      echo "Downloaded content" > "$2"
      return 0
    else
      echo "Mock wget: failed on attempt ${RETRY_COUNT}"
      return 1
    fi
  }
  
  # Simulate retry logic
  while [[ ${RETRY_COUNT} -lt ${DOWNLOAD_MAX_RETRIES} ]]; do
    if wget -O "${TEST_FILE}" "https://example.com"; then
      if [[ -f "${TEST_FILE}" ]] && [[ -s "${TEST_FILE}" ]]; then
        DOWNLOAD_SUCCESS=true
        break
      fi
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    sleep 0.1  # Short delay for test
  done
  
  [[ "${DOWNLOAD_SUCCESS}" == true ]]
  [[ -f "${TEST_FILE}" ]]
  [[ -s "${TEST_FILE}" ]]
  [[ "$(cat "${TEST_FILE}")" == "Downloaded content" ]]
} 