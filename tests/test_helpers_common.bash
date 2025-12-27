#!/usr/bin/env bash

# Common helper functions shared across all test suites
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

# =============================================================================
# Common Setup and Teardown Functions
# =============================================================================

# Common test directory setup
# Usage: __common_setup_test_dir [BASENAME]
__common_setup_test_dir() {
 local BASENAME="${1:-test}"
 
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR
 export TMP_DIR="${TEST_DIR}"
 
 # Set up common test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR:-${SCRIPT_BASE_DIRECTORY:-$(cd "$(dirname "${BATS_TEST_FILENAME:-${BASH_SOURCE[1]}}")/../.." && pwd)}}"
 export DBNAME="${TEST_DBNAME:-osm_notes_ingestion_test}"
 export BASENAME="${BASENAME}"
 export TEST_MODE="true"
 
 # Set log level to DEBUG for tests
 export LOG_LEVEL="${LOG_LEVEL:-DEBUG}"
 export __log_level="${__log_level:-DEBUG}"
 
 # Force fallback mode for tests (use /tmp, not /var/log)
 export FORCE_FALLBACK_MODE="true"
 
 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
  mkdir -p "${TMP_DIR}"
 fi
}

# Common test directory teardown
# Usage: __common_teardown_test_dir [ADDITIONAL_PATTERNS...]
__common_teardown_test_dir() {
 # Clean up test directory
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}" 2> /dev/null || true
 fi
 
 # Clean up any additional patterns provided
 while [[ $# -gt 0 ]]; do
  local PATTERN="$1"
  shift
  if [[ -n "${PATTERN}" ]]; then
   rm -f ${PATTERN} 2> /dev/null || true
  fi
 done
}

# =============================================================================
# Common Mock Logger Functions
# =============================================================================

# Setup mock logger functions for tests
# Usage: __common_setup_mock_loggers
__common_setup_mock_loggers() {
 function __log_start() { echo "LOG_START: $*"; }
 function __log_finish() { echo "LOG_FINISH: $*"; }
 function __logi() { echo "INFO: $*"; }
 function __loge() { echo "ERROR: $*"; }
 function __logw() { echo "WARN: $*"; }
 function __logd() { echo "DEBUG: $*"; }
 function __logt() { echo "TRACE: $*"; }
 function __logf() { echo "FATAL: $*"; }
 export -f __log_start __log_finish __logi __loge __logw __logd __logt __logf
}

# =============================================================================
# Common Mock PostgreSQL Functions
# =============================================================================

# Setup basic mock psql that returns empty/zero results
# Usage: __common_setup_mock_psql [DEFAULT_RETURN_VALUE]
__common_setup_mock_psql() {
 local DEFAULT_RETURN="${1:-0}"
 
 psql() {
  local ARGS=("$@")
  local CMD=""
  local I=0
  # Parse arguments to find -c command
  while [[ $I -lt ${#ARGS[@]} ]]; do
   if [[ "${ARGS[$I]}" == "-c" ]] && [[ $((I + 1)) -lt ${#ARGS[@]} ]]; then
    CMD="${ARGS[$((I + 1))]}"
    break
   fi
   I=$((I + 1))
  done

  # Default: return specified value
  echo "${DEFAULT_RETURN}"
  return 0
 }
 export -f psql
}

# Mock psql that returns false
# Usage: __common_mock_psql_false
__common_mock_psql_false() {
 __common_setup_mock_psql "false"
}

# Mock psql that returns empty string
# Usage: __common_mock_psql_empty
__common_mock_psql_empty() {
 __common_setup_mock_psql ""
}

# =============================================================================
# Common File Verification Functions
# =============================================================================

# Verify file exists, skip test if not found
# Usage: __common_verify_file_exists FILE_PATH [SKIP_MESSAGE]
__common_verify_file_exists() {
 local FILE_PATH="$1"
 local SKIP_MSG="${2:-File not found}"

 if [[ ! -f "${FILE_PATH}" ]]; then
  skip "${SKIP_MSG}"
 fi
}

# Verify pattern exists in file
# Usage: __common_verify_pattern_in_file FILE_PATH PATTERN [ERROR_MESSAGE]
__common_verify_pattern_in_file() {
 local FILE_PATH="$1"
 local PATTERN="$2"
 local ERROR_MSG="${3:-Pattern not found}"

 __common_verify_file_exists "${FILE_PATH}"

 run grep -qE "${PATTERN}" "${FILE_PATH}"
 [[ "${status}" -eq 0 ]] || echo "${ERROR_MSG}"
}

# Verify pattern exists in SQL file
# Usage: __common_verify_sql_pattern SQL_FILE PATTERN [ERROR_MESSAGE]
__common_verify_sql_pattern() {
 local SQL_FILE="$1"
 local PATTERN="$2"
 local ERROR_MSG="${3:-SQL pattern not found}"

 __common_verify_file_exists "${SQL_FILE}"

 run grep -qE "${PATTERN}" "${SQL_FILE}"
 [[ "${status}" -eq 0 ]] || echo "${ERROR_MSG}"
}

# Verify pattern exists in script file
# Usage: __common_verify_script_pattern SCRIPT_FILE PATTERN [ERROR_MESSAGE]
__common_verify_script_pattern() {
 local SCRIPT_FILE="$1"
 local PATTERN="$2"
 local ERROR_MSG="${3:-Script pattern not found}"

 __common_verify_file_exists "${SCRIPT_FILE}"

 run grep -qE "${PATTERN}" "${SCRIPT_FILE}"
 [[ "${status}" -eq 0 ]] || echo "${ERROR_MSG}"
}

# =============================================================================
# Common Test Data Creation Functions
# =============================================================================

# Create mock script file
# Usage: __common_create_mock_script SCRIPT_FILE SCRIPT_CONTENT
__common_create_mock_script() {
 local SCRIPT_FILE="$1"
 local SCRIPT_CONTENT="$2"

 cat > "${SCRIPT_FILE}" << EOF
#!/bin/bash
${SCRIPT_CONTENT}
EOF
 chmod +x "${SCRIPT_FILE}"
}

# Create test log file with lines
# Usage: __common_create_test_log_file LOG_FILE LINE1 [LINE2 ...]
__common_create_test_log_file() {
 local LOG_FILE="$1"
 shift
 local LOG_LINES=("$@")

 printf '%s\n' "${LOG_LINES[@]}" > "${LOG_FILE}"
}

# =============================================================================
# Common Environment Detection Functions
# =============================================================================

# Detect if running in Docker container
# Usage: __common_is_docker
__common_is_docker() {
 [[ -f "/app/bin/functionsProcess.sh" ]]
}

# Get test base directory
# Usage: __common_get_test_base_dir
__common_get_test_base_dir() {
 if __common_is_docker; then
  echo "/app"
 else
  echo "$(cd "$(dirname "${BATS_TEST_FILENAME:-${BASH_SOURCE[1]}}")/../.." && pwd)"
 fi
}

# =============================================================================
# Specialized Mock Helpers for External Services
# =============================================================================

# Mock psql for database operations with pattern matching
# Usage: __setup_mock_psql_for_query [QUERY_PATTERN] [RESULT] [RETURN_CODE]
# Example: __setup_mock_psql_for_query "SELECT.*FROM countries" "12345" 0
__setup_mock_psql_for_query() {
 export MOCK_PSQL_QUERY_PATTERN="${1:-}"
 export MOCK_PSQL_RESULT="${2:-}"
 export MOCK_PSQL_RETURN_CODE="${3:-0}"
 
 psql() {
  local ARGS=("$@")
  local CMD=""
  local DBNAME=""
  
  # Extract database name from -d argument
  for i in "${!ARGS[@]}"; do
   if [[ "${ARGS[$i]}" == "-d" ]] && [[ $((i + 1)) -lt ${#ARGS[@]} ]]; then
    DBNAME="${ARGS[$((i + 1))]}"
    break
   fi
  done
  
  # Extract SQL command from -c argument
  for i in "${!ARGS[@]}"; do
   if [[ "${ARGS[$i]}" == "-c" ]] && [[ $((i + 1)) -lt ${#ARGS[@]} ]]; then
    CMD="${ARGS[$((i + 1))]}"
    break
   fi
  done
  
  # Pattern matching for specific queries
  # Note: psql output is redirected via shell (> file), so we always write to stdout
  # The shell handles the redirection
  if [[ -n "${MOCK_PSQL_QUERY_PATTERN}" ]] && echo "${CMD}" | grep -qE "${MOCK_PSQL_QUERY_PATTERN}"; then
   echo "${MOCK_PSQL_RESULT}"
   return "${MOCK_PSQL_RETURN_CODE:-0}"
  fi
  
  # Default behavior: return empty or specified result
  # Always write to stdout (shell handles redirection)
  if [[ -n "${MOCK_PSQL_RESULT}" ]]; then
   echo "${MOCK_PSQL_RESULT}"
  fi
  return "${MOCK_PSQL_RETURN_CODE:-0}"
 }
 export -f psql
}

# Mock psql that returns boolean values
# Usage: __setup_mock_psql_boolean [QUERY_PATTERN] [BOOLEAN_VALUE]
# Example: __setup_mock_psql_boolean "EXISTS" "t"
__setup_mock_psql_boolean() {
 local QUERY_PATTERN="${1:-}"
 local BOOLEAN_VALUE="${2:-t}"
 
 __setup_mock_psql_for_query "${QUERY_PATTERN}" "${BOOLEAN_VALUE}" 0
}

# Mock psql that returns count values
# Usage: __setup_mock_psql_count [QUERY_PATTERN] [COUNT]
# Example: __setup_mock_psql_count "COUNT" "5"
__setup_mock_psql_count() {
 local QUERY_PATTERN="${1:-}"
 local COUNT="${2:-0}"
 
 __setup_mock_psql_for_query "${QUERY_PATTERN}" "${COUNT}" 0
}

# Mock psql with tracking and pattern-based responses
# Usage: __setup_mock_psql_with_tracking [TRACK_FILE] [MATCH_FILE] [PATTERN1:RESULT1] [PATTERN2:RESULT2] ...
# Example: __setup_mock_psql_with_tracking "/tmp/track" "/tmp/match" "max_note_timestamp:0" "COUNT(*):5"
__setup_mock_psql_with_tracking() {
 export MOCK_PSQL_TRACK_FILE="${1:-}"
 export MOCK_PSQL_MATCH_FILE="${2:-}"
 shift 2 2>/dev/null || shift 1 2>/dev/null || true
 export MOCK_PSQL_PATTERNS="$*"
 
 # If second arg doesn't look like a file path, treat it as first pattern
 if [[ -n "${MOCK_PSQL_MATCH_FILE}" ]] && [[ "${MOCK_PSQL_MATCH_FILE}" != *"/"* ]] && [[ "${MOCK_PSQL_MATCH_FILE}" == *":"* ]]; then
  export MOCK_PSQL_PATTERNS="${MOCK_PSQL_MATCH_FILE} ${MOCK_PSQL_PATTERNS}"
  export MOCK_PSQL_MATCH_FILE=""
 fi
 
 psql() {
  local ARGS=("$@")
  local CMD=""
  
  # Track call if track file provided
  if [[ -n "${MOCK_PSQL_TRACK_FILE}" ]]; then
   echo "1" > "${MOCK_PSQL_TRACK_FILE}" 2>/dev/null || true
  fi
  
  # Extract SQL command from -c argument
  for i in "${!ARGS[@]}"; do
   if [[ "${ARGS[$i]}" == "-c" ]] && [[ $((i + 1)) -lt ${#ARGS[@]} ]]; then
    CMD="${ARGS[$((i + 1))]}"
    break
   fi
  done
  
  # Pattern matching: check each pattern:result pair
  # Convert space-separated string to array
  local PATTERNS_ARRAY
  IFS=' ' read -ra PATTERNS_ARRAY <<< "${MOCK_PSQL_PATTERNS}"
  
  for PATTERN_RESULT in "${PATTERNS_ARRAY[@]}"; do
   local PATTERN="${PATTERN_RESULT%%:*}"
   local RESULT="${PATTERN_RESULT#*:}"
   
   if [[ -n "${PATTERN}" ]] && echo "${CMD}" | grep -qE "${PATTERN}"; then
    # Track match if match file provided
    if [[ -n "${MOCK_PSQL_MATCH_FILE}" ]]; then
     echo "1" > "${MOCK_PSQL_MATCH_FILE}" 2>/dev/null || true
    elif [[ -n "${MOCK_PSQL_TRACK_FILE}" ]]; then
     # Use track file base name with _matched suffix
     echo "1" > "${MOCK_PSQL_TRACK_FILE%.*}_matched" 2>/dev/null || true
    fi
    echo "${RESULT}"
    return 0
   fi
  done
  
  # Default: return 0 if no pattern matched
  echo "0"
  return 0
 }
 export -f psql
}

# Mock osmtogeojson for OSM→GeoJSON conversion
# Usage: __setup_mock_osmtogeojson [INPUT_PATTERN] [OUTPUT_FILE]
# Example: __setup_mock_osmtogeojson ".*\.json" "/tmp/output.geojson"
__setup_mock_osmtogeojson() {
 local INPUT_PATTERN="${1:-}"
 local OUTPUT_FILE="${2:-}"
 
 osmtogeojson() {
  local INPUT="$1"
  local OUTPUT="${2:-/dev/stdout}"
  
  # If input matches expected pattern, create mock GeoJSON
  if [[ -n "${INPUT_PATTERN}" ]] && echo "${INPUT}" | grep -qE "${INPUT_PATTERN}"; then
   cat > "${OUTPUT}" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "id": 12345,
        "name": "Test Feature"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0], [0.0, 0.0]]]
      }
    }
  ]
}
EOF
   return 0
  fi
  
  # Default: pass through to real command if available
  if command -v osmtogeojson > /dev/null 2>&1; then
   command osmtogeojson "$@"
  else
   # Return minimal valid GeoJSON
   echo '{"type":"FeatureCollection","features":[]}' > "${OUTPUT}"
   return 0
  fi
 }
 export -f osmtogeojson
}

# Mock ogr2ogr for GeoJSON→PostgreSQL import
# Usage: __setup_mock_ogr2ogr [SUCCESS=true|false] [ERROR_MESSAGE]
# Example: __setup_mock_ogr2ogr "true"
__setup_mock_ogr2ogr() {
 local SUCCESS="${1:-true}"
 local ERROR_MSG="${2:-Import failed}"
 
 ogr2ogr() {
  if [[ "${SUCCESS}" == "true" ]]; then
   # Simulate successful import
   return 0
  else
   # Simulate import failure
   echo "ERROR: ${ERROR_MSG}" >&2
   return 1
  fi
 }
 export -f ogr2ogr
}

# Mock curl for API calls with pattern matching
# Usage: __setup_mock_curl_for_api [URL_PATTERN] [RESPONSE_FILE] [HTTP_CODE]
# Example: __setup_mock_curl_for_api "api.openstreetmap.org" "/tmp/response.xml" 200
__setup_mock_curl_for_api() {
 local URL_PATTERN="${1:-}"
 local RESPONSE_FILE="${2:-}"
 local HTTP_CODE="${3:-200}"
 
 curl() {
  local ARGS=("$@")
  local OUTPUT_FILE=""
  local URL=""
  
  # Extract output file from -o argument
  for i in "${!ARGS[@]}"; do
   if [[ "${ARGS[$i]}" == "-o" ]] && [[ $((i + 1)) -lt ${#ARGS[@]} ]]; then
    OUTPUT_FILE="${ARGS[$((i + 1))]}"
    break
   fi
  done
  
  # Extract URL (last argument typically)
  URL="${ARGS[-1]}"
  
  # Pattern matching for specific URLs
  if [[ -n "${URL_PATTERN}" ]] && echo "${URL}" | grep -qE "${URL_PATTERN}"; then
   if [[ -n "${RESPONSE_FILE}" ]] && [[ -f "${RESPONSE_FILE}" ]]; then
    cp "${RESPONSE_FILE}" "${OUTPUT_FILE:-/dev/stdout}"
   elif [[ -n "${OUTPUT_FILE}" ]]; then
    echo "Mock response for ${URL_PATTERN}" > "${OUTPUT_FILE}"
   fi
   return 0
  fi
  
  # Default: pass through to real command if available
  if command -v curl > /dev/null 2>&1; then
   command curl "$@"
  else
   # Return mock success
   if [[ -n "${OUTPUT_FILE}" ]]; then
    echo "Mock curl response" > "${OUTPUT_FILE}"
   fi
   return 0
  fi
 }
 export -f curl
}

# Mock curl for Overpass API specifically
# Usage: __setup_mock_curl_overpass [QUERY_FILE] [RESPONSE_FILE]
__setup_mock_curl_overpass() {
 local QUERY_FILE="${1:-}"
 local RESPONSE_FILE="${2:-}"
 
 curl() {
  local ARGS=("$@")
  local OUTPUT_FILE=""
  local DATA_FILE=""
  
  # Check if this is an Overpass API call
  local IS_OVERPASS=false
  for arg in "${ARGS[@]}"; do
   if echo "${arg}" | grep -qE "overpass.*api.*interpreter|api/interpreter"; then
    IS_OVERPASS=true
    break
   fi
  done
  
  if [[ "${IS_OVERPASS}" == "true" ]]; then
   # Extract output file
   for i in "${!ARGS[@]}"; do
    if [[ "${ARGS[$i]}" == "-o" ]] && [[ $((i + 1)) -lt ${#ARGS[@]} ]]; then
     OUTPUT_FILE="${ARGS[$((i + 1))]}"
     break
    fi
   done
   
   # Extract data file (--data-binary)
   for i in "${!ARGS[@]}"; do
    if [[ "${ARGS[$i]}" == "--data-binary" ]] && [[ $((i + 1)) -lt ${#ARGS[@]} ]]; then
     DATA_FILE="${ARGS[$((i + 1))]}"
     break
    fi
   done
   
   # Use provided response file or create default
   if [[ -n "${RESPONSE_FILE}" ]] && [[ -f "${RESPONSE_FILE}" ]]; then
    cp "${RESPONSE_FILE}" "${OUTPUT_FILE:-/dev/stdout}"
   elif [[ -n "${OUTPUT_FILE}" ]]; then
    cat > "${OUTPUT_FILE}" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API",
  "elements": []
}
EOF
   fi
   return 0
  fi
  
  # Not Overpass, pass through to real curl or default mock
  if command -v curl > /dev/null 2>&1; then
   command curl "$@"
  else
   return 0
  fi
 }
 export -f curl
}

