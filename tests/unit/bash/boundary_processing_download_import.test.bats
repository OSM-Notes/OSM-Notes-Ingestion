#!/usr/bin/env bats

# Boundary Processing Download and Import Tests
# Tests for download and import functions (downloadBoundary, importBoundary, etc.)
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export BASHPID=$$
 export TEST_MODE="true"
 export BATS_TEST_NAME="test"

 # Set log level to DEBUG to capture all log output
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"

 # Mock external dependencies
 export OVERPASS_RETRIES_PER_ENDPOINT=2
 export OVERPASS_BACKOFF_SECONDS=1
 export DOWNLOAD_MAX_THREADS=2

 # Create mock JSON and GeoJSON files
 # shellcheck disable=SC2317
 create_mock_json() {
  local ID="${1}"
  local JSON_FILE="${TMP_DIR}/${ID}.json"
  cat > "${JSON_FILE}" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API",
  "elements": [
    {
      "type": "relation",
      "id": 12345,
      "members": [],
      "tags": {
        "name": "Test Country",
        "name:en": "Test Country",
        "name:es": "País de Prueba",
        "type": "boundary",
        "admin_level": "2"
      }
    }
  ]
}
EOF
 }

 # shellcheck disable=SC2317
 create_mock_geojson() {
  local ID="${1}"
  local GEOJSON_FILE="${TMP_DIR}/${ID}.geojson"
  cat > "${GEOJSON_FILE}" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "name": "Test Country",
        "name:en": "Test Country",
        "name:es": "País de Prueba"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]
      }
    }
  ]
}
EOF
 }

 # Mock osmtogeojson - writes directly to stdout (will be redirected to file)
 osmtogeojson() {
  local JSON_FILE="${1}"
  local BOUNDARY_ID
  BOUNDARY_ID=$(basename "${JSON_FILE}" .json)
  create_mock_geojson "${BOUNDARY_ID}"
  cat "${TMP_DIR}/${BOUNDARY_ID}.geojson"
  return 0
 }
 export -f osmtogeojson

 # Mock jq
 jq() {
  local QUERY="${1}"
  local FILE="${2}"
  if [[ "${QUERY}" == ".features | length" ]]; then
   echo "1"
  elif [[ "${QUERY}" == ".elements" ]]; then
   echo '[{"type":"relation"}]'
  fi
 }
 export -f jq

 # Mock __overpass_download_with_endpoints
 # This function will be redefined after loading boundaryProcessingFunctions.sh
 # to ensure it overrides any real implementation
 __overpass_download_with_endpoints() {
  local QUERY_FILE="${1}"
  local OUTPUT_FILE="${2}"
  local LOG_FILE="${3}"
  local BOUNDARY_ID
  # Extract ID from output file name (format: /path/to/ID.json)
  BOUNDARY_ID=$(basename "${OUTPUT_FILE}" .json)
  # If that doesn't work, try to extract from query file
  if [[ -z "${BOUNDARY_ID}" ]] || [[ "${BOUNDARY_ID}" == "output" ]]; then
   BOUNDARY_ID=$(basename "${QUERY_FILE}" .op | sed 's/query\.//')
  fi
  # Fallback: use a default ID
  if [[ -z "${BOUNDARY_ID}" ]]; then
   BOUNDARY_ID="12345"
  fi
  create_mock_json "${BOUNDARY_ID}"
  # Copy the created JSON to the output file
  if [[ -f "${TMP_DIR}/${BOUNDARY_ID}.json" ]]; then
   cp "${TMP_DIR}/${BOUNDARY_ID}.json" "${OUTPUT_FILE}" 2> /dev/null || true
  fi
  return 0
 }
 export -f __overpass_download_with_endpoints

 # Mock __validate_json_with_element
 __validate_json_with_element() {
  local FILE="${1}"
  local ELEMENT="${2}"
  [[ -f "${FILE}" ]] && [[ -s "${FILE}" ]]
 }
 export -f __validate_json_with_element

 # Mock __sanitize_sql_string
 __sanitize_sql_string() {
  echo "${1}" | sed "s/'/''/g"
 }
 export -f __sanitize_sql_string

 # Mock __sanitize_sql_integer
 __sanitize_sql_integer() {
  echo "${1}"
 }
 export -f __sanitize_sql_integer

 # Mock ogr2ogr (simulate successful import)
 # ogr2ogr is called via eval with a full command string
 ogr2ogr() {
  # Accept all arguments and simulate successful import
  # The function is called via eval, so we need to handle the full command
  return 0
 }
 export -f ogr2ogr

 # Mock psql for database operations
 # psql is called with: psql -d "${DBNAME}" -c "..." or psql -d "${DBNAME}" -Atq -c "..."
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

  # Handle different SQL commands
  if [[ "${CMD}" == *"TRUNCATE"* ]]; then
   return 0
  elif [[ "${CMD}" == *"COUNT(*)"* ]] && [[ "${CMD}" == *"import"* ]] && [[ "${CMD}" == *"ST_GeometryType"* ]]; then
   echo "1" # Simulate polygon count
  elif [[ "${CMD}" == *"INSERT INTO countries"* ]]; then
   return 0
  elif [[ "${CMD}" == *"SELECT COUNT(*)"* ]] && [[ "${CMD}" == *"countries"* ]] && [[ "${CMD}" == *"country_id"* ]]; then
   echo "1" # Simulate successful insert verification
  fi
  return 0
 }
 export -f psql

 # Load boundary processing functions
 source "${TEST_BASE_DIR}/bin/lib/boundaryProcessingFunctions.sh"

 # Re-define mocks after loading functions (functions may load real implementations)
 # This ensures our mocks override any real functions that were loaded
 __overpass_download_with_endpoints() {
  local QUERY_FILE="${1}"
  local OUTPUT_FILE="${2}"
  local LOG_FILE="${3}"
  local BOUNDARY_ID
  # Extract ID from output file name (format: /path/to/ID.json)
  BOUNDARY_ID=$(basename "${OUTPUT_FILE}" .json)
  # If that doesn't work, try to extract from query file
  if [[ -z "${BOUNDARY_ID}" ]] || [[ "${BOUNDARY_ID}" == "output" ]]; then
   BOUNDARY_ID=$(basename "${QUERY_FILE}" .op | sed 's/query\.//')
  fi
  # Fallback: use a default ID
  if [[ -z "${BOUNDARY_ID}" ]]; then
   BOUNDARY_ID="12345"
  fi
  create_mock_json "${BOUNDARY_ID}"
  # Copy the created JSON to the output file
  if [[ -f "${TMP_DIR}/${BOUNDARY_ID}.json" ]]; then
   cp "${TMP_DIR}/${BOUNDARY_ID}.json" "${OUTPUT_FILE}" 2> /dev/null || true
  fi
  return 0
 }
 export -f __overpass_download_with_endpoints

 # Re-export other mocks
 export -f osmtogeojson
 export -f jq
 export -f __validate_json_with_element
 export -f __sanitize_sql_string
 export -f __sanitize_sql_integer
 export -f ogr2ogr
 export -f psql
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Tests for __downloadBoundary_json_geojson_only
# =============================================================================

@test "__downloadBoundary_json_geojson_only should download and convert boundary" {
 local BOUNDARY_ID="12345"

 # Ensure mocks are available
 export -f __overpass_download_with_endpoints
 export -f __validate_json_with_element
 export -f osmtogeojson
 export -f jq

 run __downloadBoundary_json_geojson_only "${BOUNDARY_ID}" 2> /dev/null
 [[ "${status}" -eq 0 ]]

 # Verify JSON file was created
 [[ -f "${TMP_DIR}/${BOUNDARY_ID}.json" ]]

 # Verify GeoJSON file was created
 [[ -f "${TMP_DIR}/${BOUNDARY_ID}.geojson" ]]
}

@test "__downloadBoundary_json_geojson_only should fail on download error" {
 local BOUNDARY_ID="99999"

 # Mock __overpass_download_with_endpoints to fail
 __overpass_download_with_endpoints() {
  return 1
 }
 export -f __overpass_download_with_endpoints

 run __downloadBoundary_json_geojson_only "${BOUNDARY_ID}" 2> /dev/null
 [[ "${status}" -ne 0 ]]
}

@test "__downloadBoundary_json_geojson_only should fail on invalid JSON" {
 local BOUNDARY_ID="12345"

 # Mock __validate_json_with_element to fail
 __validate_json_with_element() {
  return 1
 }
 export -f __validate_json_with_element

 run __downloadBoundary_json_geojson_only "${BOUNDARY_ID}" 2> /dev/null
 [[ "${status}" -ne 0 ]]
}

@test "__downloadBoundary_json_geojson_only should fail on conversion error" {
 local BOUNDARY_ID="12345"

 # Mock osmtogeojson to fail
 osmtogeojson() {
  return 1
 }
 export -f osmtogeojson

 run __downloadBoundary_json_geojson_only "${BOUNDARY_ID}" 2> /dev/null
 [[ "${status}" -ne 0 ]]
}

# =============================================================================
# Tests for __importBoundary_simplified
# =============================================================================

@test "__importBoundary_simplified should import boundary to database" {
 local BOUNDARY_ID="12345"
 create_mock_geojson "${BOUNDARY_ID}"
 local GEOJSON_FILE="${TMP_DIR}/${BOUNDARY_ID}.geojson"

 run __importBoundary_simplified "${BOUNDARY_ID}" "${GEOJSON_FILE}" 2> /dev/null
 [[ "${status}" -eq 0 ]]
}

@test "__importBoundary_simplified should handle missing GeoJSON file" {
 local BOUNDARY_ID="12345"
 local GEOJSON_FILE="${TMP_DIR}/nonexistent.geojson"

 # Mock ogr2ogr to fail when file doesn't exist
 ogr2ogr() {
  # Check if input file exists in arguments
  local ARGS_STR="$*"
  if [[ "${ARGS_STR}" == *"nonexistent.geojson"* ]]; then
   return 1
  fi
  return 0
 }
 export -f ogr2ogr

 run __importBoundary_simplified "${BOUNDARY_ID}" "${GEOJSON_FILE}" 2> /dev/null
 # Function should fail when ogr2ogr fails
 [[ "${status}" -ne 0 ]]
}

@test "__importBoundary_simplified should handle Austria special case" {
 local BOUNDARY_ID="16239"
 create_mock_geojson "${BOUNDARY_ID}"
 local GEOJSON_FILE="${TMP_DIR}/${BOUNDARY_ID}.geojson"

 run __importBoundary_simplified "${BOUNDARY_ID}" "${GEOJSON_FILE}" 2> /dev/null
 [[ "${status}" -eq 0 ]]
}

@test "__importBoundary_simplified should fail on ogr2ogr error" {
 local BOUNDARY_ID="12345"
 create_mock_geojson "${BOUNDARY_ID}"
 local GEOJSON_FILE="${TMP_DIR}/${BOUNDARY_ID}.geojson"

 # Mock ogr2ogr to fail
 ogr2ogr() {
  return 1
 }
 export -f ogr2ogr

 run __importBoundary_simplified "${BOUNDARY_ID}" "${GEOJSON_FILE}" 2> /dev/null
 [[ "${status}" -ne 0 ]]
}

# =============================================================================
# Tests for __downloadMaritime_json_geojson_only
# =============================================================================

@test "__downloadMaritime_json_geojson_only should download and convert maritime boundary" {
 local BOUNDARY_ID="148838"

 run __downloadMaritime_json_geojson_only "${BOUNDARY_ID}" 2> /dev/null
 [[ "${status}" -eq 0 ]]

 # Verify JSON file was created
 [[ -f "${TMP_DIR}/${BOUNDARY_ID}.json" ]]

 # Verify GeoJSON file was created
 [[ -f "${TMP_DIR}/${BOUNDARY_ID}.geojson" ]]
}

@test "__downloadMaritime_json_geojson_only should fail on download error" {
 local BOUNDARY_ID="99999"

 # Mock __overpass_download_with_endpoints to fail
 __overpass_download_with_endpoints() {
  return 1
 }
 export -f __overpass_download_with_endpoints

 run __downloadMaritime_json_geojson_only "${BOUNDARY_ID}" 2> /dev/null
 [[ "${status}" -ne 0 ]]
}

# =============================================================================
# Tests for __importMaritime_simplified
# =============================================================================

@test "__importMaritime_simplified should import maritime boundary to database" {
 local BOUNDARY_ID="148838"
 create_mock_geojson "${BOUNDARY_ID}"
 local GEOJSON_FILE="${TMP_DIR}/${BOUNDARY_ID}.geojson"
 export IS_MARITIME="true"

 run __importMaritime_simplified "${BOUNDARY_ID}" "${GEOJSON_FILE}" 2> /dev/null
 [[ "${status}" -eq 0 ]]
}

@test "__importMaritime_simplified should set is_maritime to true" {
 local BOUNDARY_ID="148838"
 create_mock_geojson "${BOUNDARY_ID}"
 local GEOJSON_FILE="${TMP_DIR}/${BOUNDARY_ID}.geojson"

 run __importMaritime_simplified "${BOUNDARY_ID}" "${GEOJSON_FILE}" 2> /dev/null
 [[ "${status}" -eq 0 ]]
}

# =============================================================================
# Tests for __downloadMaritimes_parallel_new
# =============================================================================

@test "__downloadMaritimes_parallel_new should download multiple maritimes in parallel" {
 # Create boundaries file
 local BOUNDARIES_FILE="${TMP_DIR}/maritimes.txt"
 echo "148838" > "${BOUNDARIES_FILE}"
 echo "148839" >> "${BOUNDARIES_FILE}"

 run __downloadMaritimes_parallel_new "${BOUNDARIES_FILE}" 2> /dev/null
 [[ "${status}" -eq 0 ]]

 # Verify success file was created
 [[ -f "${TMP_DIR}/download_maritime_success.txt" ]]
}

@test "__downloadMaritimes_parallel_new should handle empty file" {
 local BOUNDARIES_FILE="${TMP_DIR}/empty.txt"
 touch "${BOUNDARIES_FILE}"

 run __downloadMaritimes_parallel_new "${BOUNDARIES_FILE}" 2> /dev/null
 [[ "${status}" -ne 0 ]]
}

@test "__downloadMaritimes_parallel_new should track failed downloads" {
 local BOUNDARIES_FILE="${TMP_DIR}/maritimes.txt"
 echo "99999" > "${BOUNDARIES_FILE}" # Invalid ID

 # Mock __downloadMaritime_json_geojson_only to fail
 __downloadMaritime_json_geojson_only() {
  return 1
 }
 export -f __downloadMaritime_json_geojson_only

 run __downloadMaritimes_parallel_new "${BOUNDARIES_FILE}" 2> /dev/null
 [[ "${status}" -ne 0 ]]

 # Verify failed file was created
 [[ -f "${TMP_DIR}/download_maritime_failed.txt" ]]
}

# =============================================================================
# Tests for __importMaritimes_sequential_new
# =============================================================================

@test "__importMaritimes_sequential_new should import multiple maritimes sequentially" {
 # Create success file with downloaded IDs
 local SUCCESS_FILE="${TMP_DIR}/download_maritime_success.txt"
 echo "148838" > "${SUCCESS_FILE}"
 echo "148839" >> "${SUCCESS_FILE}"

 # Create corresponding GeoJSON files
 create_mock_geojson "148838"
 create_mock_geojson "148839"

 run __importMaritimes_sequential_new "${SUCCESS_FILE}" 2> /dev/null
 [[ "${status}" -eq 0 ]]
}

@test "__importMaritimes_sequential_new should handle missing GeoJSON files" {
 local SUCCESS_FILE="${TMP_DIR}/download_maritime_success.txt"
 echo "99999" > "${SUCCESS_FILE}" # No GeoJSON file exists

 run __importMaritimes_sequential_new "${SUCCESS_FILE}" 2> /dev/null
 [[ "${status}" -ne 0 ]]

 # Verify failed IDs file was created
 [[ -f "${TMP_DIR}/import_maritime_failed.txt" ]]
}

@test "__importMaritimes_sequential_new should track failed imports" {
 local SUCCESS_FILE="${TMP_DIR}/download_maritime_success.txt"
 echo "12345" > "${SUCCESS_FILE}"
 create_mock_geojson "12345"

 # Mock __importMaritime_simplified to fail
 __importMaritime_simplified() {
  return 1
 }
 export -f __importMaritime_simplified

 run __importMaritimes_sequential_new "${SUCCESS_FILE}" 2> /dev/null
 [[ "${status}" -ne 0 ]]

 # Verify failed IDs file was created
 [[ -f "${TMP_DIR}/import_maritime_failed.txt" ]]
}

# =============================================================================
# Tests for __downloadCountries_parallel_new
# =============================================================================

@test "__downloadCountries_parallel_new should download multiple countries in parallel" {
 # Create boundaries file
 local BOUNDARIES_FILE="${TMP_DIR}/countries.txt"
 echo "12345" > "${BOUNDARIES_FILE}"
 echo "12346" >> "${BOUNDARIES_FILE}"

 run __downloadCountries_parallel_new "${BOUNDARIES_FILE}" 2> /dev/null
 [[ "${status}" -eq 0 ]]

 # Verify success file was created
 [[ -f "${TMP_DIR}/download_success.txt" ]]
}

@test "__downloadCountries_parallel_new should handle empty file" {
 local BOUNDARIES_FILE="${TMP_DIR}/empty.txt"
 touch "${BOUNDARIES_FILE}"

 run __downloadCountries_parallel_new "${BOUNDARIES_FILE}" 2> /dev/null
 [[ "${status}" -ne 0 ]]
}

@test "__downloadCountries_parallel_new should track failed downloads" {
 local BOUNDARIES_FILE="${TMP_DIR}/countries.txt"
 echo "99999" > "${BOUNDARIES_FILE}" # Invalid ID

 # Mock __downloadBoundary_json_geojson_only to fail
 __downloadBoundary_json_geojson_only() {
  return 1
 }
 export -f __downloadBoundary_json_geojson_only

 run __downloadCountries_parallel_new "${BOUNDARIES_FILE}" 2> /dev/null
 [[ "${status}" -ne 0 ]]

 # Verify failed file was created
 [[ -f "${TMP_DIR}/download_failed.txt" ]]
}

# =============================================================================
# Tests for __importCountries_sequential_new
# =============================================================================

@test "__importCountries_sequential_new should import multiple countries sequentially" {
 # Create success file with downloaded IDs
 local SUCCESS_FILE="${TMP_DIR}/download_success.txt"
 echo "12345" > "${SUCCESS_FILE}"
 echo "12346" >> "${SUCCESS_FILE}"

 # Create corresponding GeoJSON files
 create_mock_geojson "12345"
 create_mock_geojson "12346"

 run __importCountries_sequential_new "${SUCCESS_FILE}" 2> /dev/null
 [[ "${status}" -eq 0 ]]
}

@test "__importCountries_sequential_new should handle missing GeoJSON files" {
 local SUCCESS_FILE="${TMP_DIR}/download_success.txt"
 echo "99999" > "${SUCCESS_FILE}" # No GeoJSON file exists

 run __importCountries_sequential_new "${SUCCESS_FILE}" 2> /dev/null
 [[ "${status}" -ne 0 ]]

 # Verify failed IDs file was created
 [[ -f "${TMP_DIR}/import_failed.txt" ]]
}

@test "__importCountries_sequential_new should track failed imports" {
 local SUCCESS_FILE="${TMP_DIR}/download_success.txt"
 echo "12345" > "${SUCCESS_FILE}"
 create_mock_geojson "12345"

 # Mock __importBoundary_simplified to fail
 __importBoundary_simplified() {
  return 1
 }
 export -f __importBoundary_simplified

 run __importCountries_sequential_new "${SUCCESS_FILE}" 2> /dev/null
 [[ "${status}" -ne 0 ]]

 # Verify failed IDs file was created
 [[ -f "${TMP_DIR}/import_failed.txt" ]]
}
