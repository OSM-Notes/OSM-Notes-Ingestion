#!/usr/bin/env bats

# Export Countries Backup Script Tests
# Tests for bin/scripts/exportCountriesBackup.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-12-14

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"

 # Create data directory for output files
 mkdir -p "${TEST_BASE_DIR}/data"

 # Set log level to DEBUG
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
 # Clean up data directory files created during tests
 rm -f "${TEST_BASE_DIR}/data/countries.geojson"
}

@test "exportCountriesBackup.sh should check database connection" {
 # Mock psql to simulate connection failure
 psql() {
  # Check if this is the connection test query
  if [[ "$*" == *"-d"* ]] && [[ "$*" == *"test_db"* ]] && [[ "$*" == *"-c"* ]] && [[ "$*" == *"SELECT 1;"* ]]; then
   return 1
  fi
  return 0
 }
 export -f psql

 # Run script and expect failure with ERROR_GENERAL (255)
 run bash "${TEST_BASE_DIR}/bin/scripts/exportCountriesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 255 ]]
}

@test "exportCountriesBackup.sh should check if countries table exists" {
 # Mock psql to return 0 countries
 psql() {
  # Connection check should succeed
  if [[ "$*" == *"-d"* ]] && [[ "$*" == *"test_db"* ]] && [[ "$*" == *"-c"* ]] && [[ "$*" == *"SELECT 1;"* ]]; then
   return 0
  fi
  # Count query should return 0
  if [[ "$*" == *"-Atq"* ]] && [[ "$*" == *"SELECT COUNT(*) FROM countries"* ]] && [[ "$*" != *"WHERE"* ]]; then
   echo "0"
   return 0
  fi
  return 0
 }
 export -f psql

 # Run script and expect failure with ERROR_GENERAL (255)
 run bash "${TEST_BASE_DIR}/bin/scripts/exportCountriesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 255 ]]
}

@test "exportCountriesBackup.sh should export countries to GeoJSON" {
 # Mock psql to return valid count
 psql() {
  # Connection check
  if [[ "$1" == "-d" ]] && [[ "$2" == "test_db" ]] && [[ "$3" == "-c" ]] && [[ "$4" == "SELECT 1;" ]]; then
   return 0
  fi
  # Total count query (simple COUNT without WHERE)
  if [[ "$*" == *"-Atq"* ]] && [[ "$*" == *"SELECT COUNT(*) FROM countries"* ]] && [[ "$*" != *"WHERE"* ]]; then
   echo "10"
   return 0
  fi
  # Countries only count (excluding maritimes)
  if [[ "$*" == *"-Atq"* ]] && [[ "$*" == *"SELECT COUNT(*) FROM countries WHERE NOT ("* ]]; then
   echo "8"
   return 0
  fi
  return 0
 }
 export -f psql

 # Mock ogr2ogr to create valid GeoJSON
 ogr2ogr() {
  if [[ "$1" == "-f" ]] && [[ "$2" == "GeoJSON" ]]; then
   local OUTPUT_FILE="$3"
   cat > "${OUTPUT_FILE}" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "country_id": 1,
        "country_name": "Test Country"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]
      }
    }
  ]
}
EOF
   return 0
  fi
  return 1
 }
 export -f ogr2ogr

 # Mock jq for validation
 jq() {
  if [[ "$1" == "empty" ]]; then
   return 0
  elif [[ "$1" == ".features | length" ]]; then
   echo "1"
   return 0
  fi
  return 0
 }
 export -f jq

 # Mock stat and numfmt for file size
 stat() {
  if [[ "$1" == "-c%s" ]]; then
   echo "1000"
   return 0
  fi
  return 1
 }
 export -f stat

 numfmt() {
  echo "1KB"
  return 0
 }
 export -f numfmt

 # Run script
 run bash "${TEST_BASE_DIR}/bin/scripts/exportCountriesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${TEST_BASE_DIR}/data/countries.geojson" ]]
}

@test "exportCountriesBackup.sh should filter out maritime boundaries" {
 # Mock psql to return counts
 psql() {
  # Connection check
  if [[ "$1" == "-d" ]] && [[ "$2" == "test_db" ]] && [[ "$3" == "-c" ]] && [[ "$4" == "SELECT 1;" ]]; then
   return 0
  fi
  # Total count query (simple COUNT without WHERE)
  if [[ "$*" == *"-Atq"* ]] && [[ "$*" == *"SELECT COUNT(*) FROM countries"* ]] && [[ "$*" != *"WHERE"* ]]; then
   echo "15"
   return 0
  fi
  # Countries only count (excluding maritimes)
  if [[ "$*" == *"-Atq"* ]] && [[ "$*" == *"SELECT COUNT(*) FROM countries WHERE NOT ("* ]]; then
   echo "10"
   return 0
  fi
  return 0
 }
 export -f psql

 # Mock ogr2ogr
 ogr2ogr() {
  if [[ "$1" == "-f" ]] && [[ "$2" == "GeoJSON" ]]; then
   local OUTPUT_FILE="$3"
   echo '{"type":"FeatureCollection","features":[]}' > "${OUTPUT_FILE}"
   return 0
  fi
  return 1
 }
 export -f ogr2ogr

 # Mock jq
 jq() {
  return 0
 }
 export -f jq

 # Mock stat and numfmt
 stat() {
  if [[ "$1" == "-c%s" ]]; then
   echo "500"
   return 0
  fi
  return 1
 }
 export -f stat

 numfmt() {
  echo "500B"
  return 0
 }
 export -f numfmt

 # Run script
 run bash "${TEST_BASE_DIR}/bin/scripts/exportCountriesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 0 ]]
}

@test "exportCountriesBackup.sh should validate GeoJSON output" {
# Ensure data directory exists
mkdir -p "${TEST_BASE_DIR}/data"

# Mock psql
psql() {
 # Connection check
 if [[ "$1" == "-d" ]] && [[ "$2" == "notes" ]] && [[ "$3" == "-c" ]] && [[ "$4" == "SELECT 1;" ]]; then
  return 0
 fi
 # Total count query (simple COUNT without WHERE)
 if [[ "$*" == *"-Atq"* ]] && [[ "$*" == *"SELECT COUNT(*) FROM countries"* ]] && [[ "$*" != *"WHERE"* ]]; then
  echo "10"
  return 0
 fi
 # Countries only count
 if [[ "$*" == *"-Atq"* ]] && [[ "$*" == *"SELECT COUNT(*) FROM countries WHERE NOT ("* ]]; then
  echo "8"
  return 0
 fi
 # Default: return success for any other query
 return 0
}
export -f psql

# Mock ogr2ogr to create valid GeoJSON
ogr2ogr() {
 if [[ "$1" == "-f" ]] && [[ "$2" == "GeoJSON" ]]; then
  local OUTPUT_FILE="$3"
  mkdir -p "$(dirname "${OUTPUT_FILE}")"
  echo '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"country_id":1},"geometry":{"type":"Polygon","coordinates":[[[0,0],[1,0],[1,1],[0,1],[0,0]]]}}]}' > "${OUTPUT_FILE}"
  return 0
 fi
 return 1
}
export -f ogr2ogr

# Mock jq to validate
jq() {
 if [[ "$1" == "empty" ]]; then
  return 0
 elif [[ "$1" == ".features | length" ]]; then
  echo "1"
  return 0
 fi
 return 0
}
export -f jq

# Mock stat and numfmt
stat() {
 if [[ "$1" == "-c%s" ]]; then
  echo "1000"
  return 0
 fi
 return 1
}
export -f stat

numfmt() {
 echo "1KB"
 return 0
}
export -f numfmt

# Set DBNAME to match what the script expects
export DBNAME="notes"

# Run script
run bash "${TEST_BASE_DIR}/bin/scripts/exportCountriesBackup.sh" 2>&1
echo "DEBUG: status=$status, output='$output'" >&2
echo "DEBUG: GeoJSON file exists: $([ -f "${TEST_BASE_DIR}/data/countries.geojson" ] && echo yes || echo no)" >&2
[[ "${status}" -eq 0 ]]
[[ -f "${TEST_BASE_DIR}/data/countries.geojson" ]]
}

