#!/usr/bin/env bats

# Version: 2025-12-30

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

setup() {
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export LOG_LEVEL="ERROR"
 export DOWNLOAD_USER_AGENT="Test-UA/1.0 (+https://example.test; contact: test@example.test)"
}

teardown() {
 rm -rf "${TMP_DIR}"
}

@test "__overpass_download_with_endpoints falls back to second endpoint when first returns invalid JSON" {
 run bash -c '
  set -u
  set +e
  export SCRIPT_BASE_DIRECTORY
  export TMP_DIR
  # Load libs
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" || exit 1

  QUERY_FILE_LOCAL="${TMP_DIR}/q.op"
  echo "[out:json]; rel(16239); (._;>;); out;" > "${QUERY_FILE_LOCAL}" || exit 1
  JSON_FILE_LOCAL="${TMP_DIR}/16239.json"
  OUTPUT_OVERPASS_LOCAL="${TMP_DIR}/out"

  # Track which endpoint is being called
  ENDPOINT_CALL_COUNT=0
  export ENDPOINT_CALL_COUNT

  # Monkey-patch retry to simulate endpoint-specific responses
  function __retry_file_operation() {
    local OP="$1"
    # Extract the output file path from the command
    # The command format is: curl ... -o ${LOCAL_JSON_FILE} ...
    # The variable LOCAL_JSON_FILE is expanded when OP is constructed,
    # so we need to extract it from the command string
    local OUT
    # Extract file path from command - look for -o followed by the file path
    # The path is between -o and --data-binary
    OUT=$(echo "${OP}" | sed -n "s/.*-o[[:space:]]*\([^[:space:]]*\).*/\1/p" || echo "")
    
    # Fallback: use the known JSON file path from test context
    # This ensures we always have a valid path even if extraction fails
    if [[ -z "${OUT}" ]] || [[ "${OUT}" == *"\$"* ]]; then
      OUT="${JSON_FILE_LOCAL}"
    fi

    # Increment call count to track which endpoint is being called
    ENDPOINT_CALL_COUNT=$((ENDPOINT_CALL_COUNT + 1))
    export ENDPOINT_CALL_COUNT

    local VALID_JSON="{\"elements\":[{\"id\":1}]}"
    # Check CURRENT_OVERPASS_ENDPOINT which is exported by __overpass_download_with_endpoints
    # before calling __retry_file_operation, or use call count as fallback
    if [[ "${CURRENT_OVERPASS_ENDPOINT:-}" == *"endpointA"* ]] || [[ "${ENDPOINT_CALL_COUNT}" -eq 1 ]]; then
      # First endpoint returns invalid JSON (empty object without elements)
      echo "{}" > "${OUT}" || exit 1
    else
      # Second endpoint (or any other) returns valid JSON with elements
      printf "%s" "${VALID_JSON}" > "${OUT}" || exit 1
    fi
    return 0
  }

  export OVERPASS_ENDPOINTS="https://overpass.endpointA/api/interpreter,https://overpass.endpointB/api/interpreter"
  export OVERPASS_RETRIES_PER_ENDPOINT=1
  export OVERPASS_BACKOFF_SECONDS=1

  if __overpass_download_with_endpoints "${QUERY_FILE_LOCAL}" "${JSON_FILE_LOCAL}" "${OUTPUT_OVERPASS_LOCAL}" 1 1; then
    # File must contain a valid JSON with elements key
    if grep -q '"elements"' "${JSON_FILE_LOCAL}"; then
      exit 0
    else
      echo "JSON file does not contain elements key" >&2
      cat "${JSON_FILE_LOCAL}" >&2
      exit 1
    fi
  else
    echo "expected success with fallback" >&2
    echo "Endpoint call count: ${ENDPOINT_CALL_COUNT}" >&2
    echo "CURRENT_OVERPASS_ENDPOINT: ${CURRENT_OVERPASS_ENDPOINT:-not set}" >&2
    exit 1
  fi
 '
 [ "$status" -eq 0 ]
}

@test "__processBoundary continues and records failed boundary when all endpoints invalid and CONTINUE_ON_OVERPASS_ERROR=true" {
 run bash -c '
  set -u
  set +e
  export SCRIPT_BASE_DIRECTORY
  export TMP_DIR
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh" || exit 1

  # Force helper to fail regardless of endpoint
  function __overpass_download_with_endpoints() {
    return 1
  }

  export CONTINUE_ON_OVERPASS_ERROR=true
  export ID=9999
  export JSON_FILE="${TMP_DIR}/${ID}.json"
  export GEOJSON_FILE="${TMP_DIR}/${ID}.geojson"
  QUERY_FILE_LOCAL="${TMP_DIR}/q_${ID}.op"
  echo "[out:json]; rel(${ID}); (._;>;); out;" > "${QUERY_FILE_LOCAL}" || exit 1

  # Expect function to return non-zero but not exit the shell, and record failed id
  if __processBoundary "${QUERY_FILE_LOCAL}"; then
    echo "expected failure with continue-on-error" >&2
    exit 1
  fi
  test -f "${TMP_DIR}/failed_boundaries.txt" || exit 1
  grep -q "^${ID}$" "${TMP_DIR}/failed_boundaries.txt" || exit 1
  exit 0
 '
 [ "$status" -eq 0 ]
}


