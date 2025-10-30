#!/usr/bin/env bats

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
  set -euo pipefail
  export SCRIPT_BASE_DIRECTORY
  export TMP_DIR
  # Load libs
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"

  # Monkey-patch retry to simulate endpoint-specific responses
  function __retry_file_operation() {
    local OP="$1"
    # Extract output file after -O
    local OUT
    OUT=$(echo "$OP" | awk "{for(i=1;i<=NF;i++) if (\$i==\"-O\") {print \$(i+1); exit}}")
    # Use current interpreter to decide content
    if [[ "${OVERPASS_INTERPRETER}" == *"endpointA"* ]]; then
      echo '{}' > "${OUT}"
    else
      echo '{"elements":[]}' > "${OUT}"
    fi
    return 0
  }

  export OVERPASS_ENDPOINTS="https://overpass.endpointA/api/interpreter,https://overpass.endpointB/api/interpreter"
  export OVERPASS_RETRIES_PER_ENDPOINT=1
  export OVERPASS_BACKOFF_SECONDS=1

  QUERY_FILE_LOCAL="${TMP_DIR}/q.op"
  echo "[out:json]; rel(16239); (._;>;); out;" > "${QUERY_FILE_LOCAL}"
  JSON_FILE_LOCAL="${TMP_DIR}/16239.json"
  OUTPUT_OVERPASS_LOCAL="${TMP_DIR}/out"

  if __overpass_download_with_endpoints "${QUERY_FILE_LOCAL}" "${JSON_FILE_LOCAL}" "${OUTPUT_OVERPASS_LOCAL}" 1 1; then
    # File must contain a valid JSON with elements key
    grep -q '"elements"' "${JSON_FILE_LOCAL}"
    exit 0
  else
    echo "expected success with fallback" >&2
    exit 1
  fi
 '
 [ "$status" -eq 0 ]
}

@test "__processBoundary continues and records failed boundary when all endpoints invalid and CONTINUE_ON_OVERPASS_ERROR=true" {
 run bash -c '
  set -euo pipefail
  export SCRIPT_BASE_DIRECTORY
  export TMP_DIR
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"

  # Force helper to fail regardless of endpoint
  function __overpass_download_with_endpoints() {
    return 1
  }

  export CONTINUE_ON_OVERPASS_ERROR=true
  export ID=9999
  export JSON_FILE="${TMP_DIR}/${ID}.json"
  export GEOJSON_FILE="${TMP_DIR}/${ID}.geojson"
  local QUERY_FILE_LOCAL="${TMP_DIR}/q_${ID}.op"
  echo "[out:json]; rel(${ID}); (._;>;); out;" > "${QUERY_FILE_LOCAL}"

  # Expect function to return non-zero but not exit the shell, and record failed id
  if __processBoundary "${QUERY_FILE_LOCAL}"; then
    echo "expected failure with continue-on-error" >&2
    exit 1
  fi
  test -f "${TMP_DIR}/failed_boundaries.txt"
  grep -q "^${ID}$" "${TMP_DIR}/failed_boundaries.txt"
 '
 [ "$status" -eq 0 ]
}


