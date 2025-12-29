#!/usr/bin/env bats

# Export Maritimes Backup Script Tests
# Tests for bin/scripts/exportMaritimesBackup.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Setup test properties first (this must be done before any script sources properties.sh)
 if declare -f setup_test_properties > /dev/null 2>&1; then
  setup_test_properties
 fi
 
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
 # Restore original properties if needed
 if declare -f restore_properties > /dev/null 2>&1; then
  restore_properties
 fi
 
 # Clean up test files
 rm -rf "${TEST_DIR}"
 # Clean up data directory files created during tests
 rm -f "${TEST_BASE_DIR}/data/maritimes.geojson"
}

@test "exportMaritimesBackup.sh should check database connection" {
 # Mock psql to simulate connection failure
 psql() {
  if [[ "$1" == "-d" ]] && [[ "$2" == "test_db" ]] && [[ "$3" == "-c" ]]; then
   return 1
  fi
  return 0
 }
 export -f psql

 # Run script and expect failure with ERROR_GENERAL (255)
 run bash "${TEST_BASE_DIR}/bin/scripts/exportMaritimesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 255 ]]
}

@test "exportMaritimesBackup.sh should check if countries table exists" {
 # Mock psql to return 0 countries
 psql() {
  if [[ "$*" == *"SELECT COUNT(*) FROM countries"* ]]; then
   echo "0"
   return 0
  fi
  return 0
 }
 export -f psql

 # Run script and expect failure with ERROR_GENERAL (255)
 run bash "${TEST_BASE_DIR}/bin/scripts/exportMaritimesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 255 ]]
}

@test "exportMaritimesBackup.sh should export maritimes to GeoJSON" {
 # Mock psql to return valid counts
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
  # Maritime count query (with WHERE clause)
  if [[ "$*" == *"-Atq"* ]] && [[ "$*" == *"SELECT COUNT(*) FROM countries WHERE ("* ]]; then
   echo "5"
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
        "country_name_en": "Test (EEZ)"
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
 run bash "${TEST_BASE_DIR}/bin/scripts/exportMaritimesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${TEST_BASE_DIR}/data/maritimes.geojson" ]]
}

@test "exportMaritimesBackup.sh should identify maritime boundaries by patterns" {
 # Mock psql to return maritime count
 psql() {
  # Connection check
  if [[ "$1" == "-d" ]] && [[ "$2" == "test_db" ]] && [[ "$3" == "-c" ]] && [[ "$4" == "SELECT 1;" ]]; then
   return 0
  fi
  # Total count query (simple COUNT without WHERE)
  if [[ "$*" == *"-Atq"* ]] && [[ "$*" == *"SELECT COUNT(*) FROM countries"* ]] && [[ "$*" != *"WHERE"* ]]; then
   echo "20"
   return 0
  fi
  # Maritime count query (with WHERE clause)
  if [[ "$*" == *"-Atq"* ]] && [[ "$*" == *"SELECT COUNT(*) FROM countries WHERE ("* ]]; then
   echo "8"
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
 run bash "${TEST_BASE_DIR}/bin/scripts/exportMaritimesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 0 ]]
}

@test "exportMaritimesBackup.sh should fail if no maritimes found" {
 # Mock psql to return 0 maritimes
 psql() {
  # Connection check
  if [[ "$1" == "-d" ]] && [[ "$2" == "test_db" ]] && [[ "$3" == "-c" ]] && [[ "$4" == "SELECT 1;" ]]; then
   return 0
  fi
  # Total count query
  if [[ "$*" == *"-Atq"* ]] && [[ "$*" == *"SELECT COUNT(*) FROM countries"* ]] && [[ "$*" != *"WHERE"* ]]; then
   echo "10"
   return 0
  fi
  # Maritime count query (no maritimes)
  if [[ "$*" == *"-Atq"* ]] && [[ "$*" == *"SELECT COUNT(*) FROM countries WHERE ("* ]]; then
   echo "0"
   return 0
  fi
  return 0
 }
 export -f psql

 # Run script and expect failure with ERROR_GENERAL (255)
 run bash "${TEST_BASE_DIR}/bin/scripts/exportMaritimesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 255 ]]
}

