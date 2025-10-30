#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export LOG_LEVEL="DEBUG"
 export DOWNLOAD_USER_AGENT="UA-Test/1.0 (+https://example.test; contact: test@example.test)"
}

teardown() {
 rm -rf "${TMP_DIR}"
}

@test "Overpass wget includes User-Agent header when set" {
 run bash -c '
  set -euo pipefail
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  # Capture built operation
  function __retry_file_operation() {
    echo "$1" > "${TMP_DIR}/overpass_cmd.txt"
    return 0
  }
  # Prepare inputs
  export OVERPASS_ENDPOINTS="https://overpass.endpointA/api/interpreter"
  QUERY_FILE_LOCAL="${TMP_DIR}/q.op"
  echo "[out:json]; rel(1); (._;>;); out;" > "${QUERY_FILE_LOCAL}"
  JSON_FILE_LOCAL="${TMP_DIR}/1.json"
  OUT_LOCAL="${TMP_DIR}/out"
  __overpass_download_with_endpoints "${QUERY_FILE_LOCAL}" "${JSON_FILE_LOCAL}" "${OUT_LOCAL}" 1 1
  grep -q "--header=\"User-Agent: ${DOWNLOAD_USER_AGENT}\"" "${TMP_DIR}/overpass_cmd.txt"
 '
 [ "$status" -eq 0 ]
}

@test "OSM API curl includes -H User-Agent when set" {
 run bash -c '
  set -euo pipefail
  source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"
  # Mock curl in PATH to capture args
  mkdir -p "${TMP_DIR}/bin"
  cat > "${TMP_DIR}/bin/curl" <<EOF
#!/bin/bash
echo "$@" > "${TMP_DIR}/curl_args.txt"
exit 0
EOF
  chmod +x "${TMP_DIR}/bin/curl"
  export PATH="${TMP_DIR}/bin:${PATH}"
  __retry_osm_api "https://api.openstreetmap.org/api/0.6/notes?limit=1" "${TMP_DIR}/out.xml" 1 1 5
  grep -q "-H User-Agent: ${DOWNLOAD_USER_AGENT}" "${TMP_DIR}/curl_args.txt"
 '
 [ "$status" -eq 0 ]
}



