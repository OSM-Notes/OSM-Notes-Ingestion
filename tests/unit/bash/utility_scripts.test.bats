#!/usr/bin/env bats

# Utility Scripts Tests
# Comprehensive tests for utility scripts in bin/scripts/
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

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
 rm -f "${TEST_BASE_DIR}/data/maritimes.geojson"
 rm -f "${TEST_BASE_DIR}/data/noteLocation.csv"
 rm -f "${TEST_BASE_DIR}/data/noteLocation.csv.zip"
}

# =============================================================================
# Tests for exportCountriesBackup.sh
# =============================================================================

@test "exportCountriesBackup.sh should check database connection" {
 # Mock psql to simulate connection failure
 psql() {
  if [[ "$1" == "-d" ]] && [[ "$2" == "test_db" ]] && [[ "$3" == "-c" ]]; then
   return 1
  fi
  return 0
 }
 export -f psql

 # Run script and expect failure
 run bash "${TEST_BASE_DIR}/bin/scripts/exportCountriesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 1 ]]
}

@test "exportCountriesBackup.sh should check if countries table exists" {
 # Mock psql to return 0 countries
 psql() {
  if [[ "$*" == *"SELECT COUNT(*) FROM countries"* ]]; then
   echo "0"
   return 0
  fi
  return 0
 }
 export -f psql

 # Run script and expect failure (empty table)
 run bash "${TEST_BASE_DIR}/bin/scripts/exportCountriesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 1 ]]
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
 # Mock psql
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
  # Countries only count
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

 # Run script
 run bash "${TEST_BASE_DIR}/bin/scripts/exportCountriesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${TEST_BASE_DIR}/data/countries.geojson" ]]
}

# =============================================================================
# Tests for exportMaritimesBackup.sh
# =============================================================================

@test "exportMaritimesBackup.sh should check database connection" {
 # Mock psql to simulate connection failure
 psql() {
  if [[ "$1" == "-d" ]] && [[ "$2" == "test_db" ]] && [[ "$3" == "-c" ]]; then
   return 1
  fi
  return 0
 }
 export -f psql

 # Run script and expect failure
 run bash "${TEST_BASE_DIR}/bin/scripts/exportMaritimesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 1 ]]
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

 # Run script and expect failure
 run bash "${TEST_BASE_DIR}/bin/scripts/exportMaritimesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 1 ]]
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

 # Run script and expect failure
 run bash "${TEST_BASE_DIR}/bin/scripts/exportMaritimesBackup.sh" 2>/dev/null
 [[ "${status}" -eq 1 ]]
}

# =============================================================================
# Tests for generateNoteLocationBackup.sh
# =============================================================================

@test "generateNoteLocationBackup.sh should check database connection" {
 # Mock psql to simulate connection failure
 psql() {
  if [[ "$1" == "-d" ]] && [[ "$2" == "test_db" ]] && [[ "$3" == "-c" ]]; then
   return 1
  fi
  return 0
 }
 export -f psql

 # Run script and expect failure
 run bash "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" 2>/dev/null
 [[ "${status}" -eq 1 ]]
}

@test "generateNoteLocationBackup.sh should check if notes have country assignment" {
 # Mock psql to return 0 notes with country
 psql() {
  if [[ "$*" == *"SELECT COUNT(*) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "0"
   return 0
  fi
  return 0
 }
 export -f psql

 # Run script and expect failure
 run bash "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" 2>/dev/null
 [[ "${status}" -eq 1 ]]
}

@test "generateNoteLocationBackup.sh should export notes to CSV" {
 # Mock psql to return valid counts and export data
 psql() {
  if [[ "$*" == *"SELECT COUNT(*) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "100"
   return 0
  elif [[ "$*" == *"SELECT MAX(note_id) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "5000"
   return 0
  elif [[ "$*" == *"\COPY"* ]]; then
   # Simulate CSV export
   echo "1,10" > "${TEST_BASE_DIR}/data/noteLocation.csv"
   echo "2,20" >> "${TEST_BASE_DIR}/data/noteLocation.csv"
   return 0
  fi
  return 0
 }
 export -f psql

 # Mock zip command
 zip() {
  if [[ "$1" == "-q" ]] && [[ "$2" == "-j" ]]; then
   local ZIP_FILE="$3"
   local CSV_FILE="$4"
   # Create a mock zip file
   echo "mock zip content" > "${ZIP_FILE}"
   return 0
  fi
  return 1
 }
 export -f zip

 # Run script
 run bash "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" 2>/dev/null
 [[ "${status}" -eq 0 ]]
}

@test "generateNoteLocationBackup.sh should compress CSV to ZIP" {
 # Mock psql
 psql() {
  if [[ "$*" == *"SELECT COUNT(*) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "50"
   return 0
  elif [[ "$*" == *"SELECT MAX(note_id)"* ]]; then
   echo "1000"
   return 0
  elif [[ "$*" == *"\COPY"* ]]; then
   echo "1,10" > "${TEST_BASE_DIR}/data/noteLocation.csv"
   echo "2,20" >> "${TEST_BASE_DIR}/data/noteLocation.csv"
   return 0
  fi
  return 0
 }
 export -f psql

 # Mock zip to create compressed file
 zip() {
  if [[ "$1" == "-q" ]] && [[ "$2" == "-j" ]]; then
   local ZIP_FILE="$3"
   echo "compressed content" > "${ZIP_FILE}"
   return 0
  fi
  return 1
 }
 export -f zip

 # Run script
 run bash "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${TEST_BASE_DIR}/data/noteLocation.csv.zip" ]]
}

@test "generateNoteLocationBackup.sh should remove uncompressed CSV after compression" {
 # Mock psql
 psql() {
  if [[ "$*" == *"SELECT COUNT(*) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "25"
   return 0
  elif [[ "$*" == *"SELECT MAX(note_id)"* ]]; then
   echo "500"
   return 0
  elif [[ "$*" == *"\COPY"* ]]; then
   echo "1,10" > "${TEST_BASE_DIR}/data/noteLocation.csv"
   return 0
  fi
  return 0
 }
 export -f psql

 # Mock zip
 zip() {
  if [[ "$1" == "-q" ]] && [[ "$2" == "-j" ]]; then
   local ZIP_FILE="$3"
   echo "zip content" > "${ZIP_FILE}"
   return 0
  fi
  return 1
 }
 export -f zip

 # Run script
 run bash "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" 2>/dev/null
 [[ "${status}" -eq 0 ]]
 # CSV should be removed after compression
 [[ ! -f "${TEST_BASE_DIR}/data/noteLocation.csv" ]]
 [[ -f "${TEST_BASE_DIR}/data/noteLocation.csv.zip" ]]
}

@test "generateNoteLocationBackup.sh should handle max note_id query" {
 # Mock psql to return max note_id
 psql() {
  if [[ "$*" == *"SELECT COUNT(*) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "100"
   return 0
  elif [[ "$*" == *"SELECT MAX(note_id) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "12345"
   return 0
  elif [[ "$*" == *"\COPY"* ]]; then
   echo "1,10" > "${TEST_BASE_DIR}/data/noteLocation.csv"
   return 0
  fi
  return 0
 }
 export -f psql

 # Mock zip
 zip() {
  if [[ "$1" == "-q" ]] && [[ "$2" == "-j" ]]; then
   local ZIP_FILE="$3"
   echo "zip" > "${ZIP_FILE}"
   return 0
  fi
  return 1
 }
 export -f zip

 # Run script
 run bash "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" 2>/dev/null
 [[ "${status}" -eq 0 ]]
}

