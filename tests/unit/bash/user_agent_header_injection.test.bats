#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

setup() {
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
 setup_test_properties
 export TMP_DIR="$(mktemp -d)"
 export LOG_LEVEL="DEBUG"
 export DOWNLOAD_USER_AGENT="UA-Test/1.0 (+https://example.test; contact: test@example.test)"
}

teardown() {
 rm -rf "${TMP_DIR}"
 restore_properties
}

@test "Overpass curl includes User-Agent header when set" {
 # Capture built operation and create mock JSON file
 function __retry_file_operation() {
  echo "$1" > "${TMP_DIR}/overpass_cmd.txt"
  # Extract JSON file path from command and create a mock JSON file
  # The function uses curl with -o (lowercase) for output file
  local CMD="$1"
  local JSON_FILE="${JSON_FILE_LOCAL}"
  
  # Try to extract from curl command (-o option, lowercase)
  if [[ "${CMD}" == *"-o"* ]]; then
   local EXTRACTED
   EXTRACTED=$(echo "${CMD}" | sed -n 's/.*-o[[:space:]]*\([^[:space:]]*\).*/\1/p' | head -1)
   # Only use extracted value if it doesn't contain variable syntax
   if [[ -n "${EXTRACTED}" ]] && [[ "${EXTRACTED}" != *"\$"* ]] && [[ "${EXTRACTED}" != *"{"* ]]; then
    JSON_FILE="${EXTRACTED}"
   fi
  fi
  
  # Create the JSON file before validation (critical for test to pass)
  if [[ -n "${JSON_FILE}" ]]; then
   echo '{"elements":[{"type":"relation","id":1}]}' > "${JSON_FILE}"
  fi
  return 0
 }
 # Prepare inputs
 export OVERPASS_ENDPOINTS="https://overpass.endpointA/api/interpreter"
 QUERY_FILE_LOCAL="${TMP_DIR}/q.op"
 echo "[out:json]; rel(1); (._;>;); out;" > "${QUERY_FILE_LOCAL}"
 JSON_FILE_LOCAL="${TMP_DIR}/1.json"
 OUT_LOCAL="${TMP_DIR}/out"
 # Check if function exists
 if ! declare -f __overpass_download_with_endpoints > /dev/null 2>&1; then
  skip "__overpass_download_with_endpoints function not available"
 fi
 __overpass_download_with_endpoints "${QUERY_FILE_LOCAL}" "${JSON_FILE_LOCAL}" "${OUT_LOCAL}" 1 1
 # Check if command file was created
 [ -f "${TMP_DIR}/overpass_cmd.txt" ]
 # Check if the command contains User-Agent header (check for User-Agent anywhere in the command)
 grep -q "User-Agent" "${TMP_DIR}/overpass_cmd.txt"
}

@test "OSM API curl includes -H User-Agent when set" {
 # Mock curl in PATH to capture args and create output file
 mkdir -p "${TMP_DIR}/bin"
 cat > "${TMP_DIR}/bin/curl" <<'EOF'
#!/bin/bash
# Capture all arguments
echo "$@" > "${TMP_DIR}/curl_args.txt"

# Extract output file from -o option and create it
# Also handle -w option for HTTP code output
local OUTPUT_FILE=""
local HTTP_CODE_OUTPUT=""
local PREV_ARG=""
local NEXT_IS_OUTPUT=false
local NEXT_IS_HTTP_CODE=false

for arg in "$@"; do
 if [[ "${NEXT_IS_OUTPUT}" == "true" ]]; then
  OUTPUT_FILE="${arg}"
  NEXT_IS_OUTPUT=false
 elif [[ "${NEXT_IS_HTTP_CODE}" == "true" ]]; then
  HTTP_CODE_OUTPUT="${arg}"
  NEXT_IS_HTTP_CODE=false
 elif [[ "${arg}" == "-o" ]]; then
  NEXT_IS_OUTPUT=true
 elif [[ "${arg}" == "-w" ]]; then
  NEXT_IS_HTTP_CODE=true
 fi
done

# Create output file if specified
if [[ -n "${OUTPUT_FILE}" ]] && [[ "${OUTPUT_FILE}" != "/dev/null" ]]; then
 echo "<osm><note id=\"1\"/></osm>" > "${OUTPUT_FILE}"
fi

# Output HTTP code if -w was used (to stdout, before the file content)
if [[ -n "${HTTP_CODE_OUTPUT}" ]]; then
 echo -n "200"
fi

exit 0
EOF
 chmod +x "${TMP_DIR}/bin/curl"
 export PATH="${TMP_DIR}/bin:${PATH}"
 
 # Ensure function is loaded
 if [ -f "${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh" ]; then
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/noteProcessingFunctions.sh" > /dev/null 2>&1 || true
 fi
 
 # Check if function exists
 if ! declare -f __retry_osm_api > /dev/null 2>&1; then
  skip "__retry_osm_api function not available"
 fi
 
 __retry_osm_api "https://api.openstreetmap.org/api/0.6/notes?limit=1" "${TMP_DIR}/out.xml" 1 1 5
 # Check if curl args file was created
 [ -f "${TMP_DIR}/curl_args.txt" ]
 # Check if the command contains User-Agent header (check for User-Agent anywhere in the args)
 grep -q "User-Agent" "${TMP_DIR}/curl_args.txt"
}



