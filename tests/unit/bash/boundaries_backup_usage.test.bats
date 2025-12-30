#!/usr/bin/env bats

# Tests for boundaries backup usage functionality
# Verifies that backup files are used instead of downloading from Overpass
# Author: Andres Gomez (AngocA)
# Version: 2025-11-27

bats_require_minimum_version 1.5.0

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

setup() {
 # Setup test properties first (this must be done before any script sources properties.sh)
 if declare -f setup_test_properties > /dev/null 2>&1; then
  setup_test_properties
 fi
 
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export SCRIPT_BASE_DIRECTORY
 export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
 export TMP_DIR="$(mktemp -d)"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"

 # Create test data directory
 mkdir -p "${SCRIPT_BASE_DIRECTORY}/data"

 # Create a minimal valid GeoJSON backup for testing
 cat > "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "country_id": 16239,
        "country_name": "Austria",
        "country_name_es": "Austria",
        "country_name_en": "Austria"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[10.0, 47.0], [10.0, 48.0], [11.0, 48.0], [11.0, 47.0], [10.0, 47.0]]]
      }
    },
    {
      "type": "Feature",
      "properties": {
        "country_id": 2186646,
        "country_name": "Antarctica",
        "country_name_es": "Antártida",
        "country_name_en": "Antarctica"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[-180.0, -90.0], [-180.0, -60.0], [180.0, -60.0], [180.0, -90.0], [-180.0, -90.0]]]
      }
    }
  ]
}
EOF

 cat > "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "country_id": 12345,
        "country_name": "Test Country (EEZ)",
        "country_name_es": "País de Prueba (ZEE)",
        "country_name_en": "Test Country (EEZ)"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0.0, 0.0], [0.0, 10.0], [10.0, 10.0], [10.0, 0.0], [0.0, 0.0]]]
      }
    }
  ]
}
EOF
}

teardown() {
 # Restore original properties if needed
 export TEST_BASE_DIR="${SCRIPT_BASE_DIRECTORY}"
 if declare -f restore_properties > /dev/null 2>&1; then
  restore_properties
 fi
 # Cleanup test backups (keep real ones if they exist)
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson.test" ]]; then
  mv "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson.test" "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" 2>/dev/null || true
 fi
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson.test" ]]; then
  mv "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson.test" "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" 2>/dev/null || true
 fi
 rm -rf "${TMP_DIR}"
}

@test "backup files should be detected when they exist" {
 # Test that backup files are found
 [ -f "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" ]
 [ -f "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" ]

 # Test that they are valid GeoJSON
 run jq empty "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" 2>&1
 [ "$status" -eq 0 ]

 run jq empty "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" 2>&1
 [ "$status" -eq 0 ]
}

@test "__compareIdsWithBackup should return 0 when IDs match" {
 # Source the function
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/boundaryProcessingFunctions.sh" > /dev/null 2>&1

 # Create test IDs file matching backup
 local OVERPASS_IDS_FILE="${TMP_DIR}/overpass_ids.txt"
 echo "@id" > "${OVERPASS_IDS_FILE}"
 echo "16239" >> "${OVERPASS_IDS_FILE}"
 echo "2186646" >> "${OVERPASS_IDS_FILE}"

 # Test comparison
 run __compareIdsWithBackup "${OVERPASS_IDS_FILE}" "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" "countries"
 [ "$status" -eq 0 ]
}

@test "__compareIdsWithBackup should return 1 when IDs differ" {
 # Source the function
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/boundaryProcessingFunctions.sh" > /dev/null 2>&1

 # Create test IDs file with different IDs
 local OVERPASS_IDS_FILE="${TMP_DIR}/overpass_ids.txt"
 echo "@id" > "${OVERPASS_IDS_FILE}"
 echo "99999" >> "${OVERPASS_IDS_FILE}" # Different ID

 # Test comparison
 run __compareIdsWithBackup "${OVERPASS_IDS_FILE}" "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" "countries"
 [ "$status" -eq 1 ]
}

@test "__compareIdsWithBackup should return 1 when backup doesn't exist" {
 # Source the function
 source "${SCRIPT_BASE_DIRECTORY}/bin/lib/boundaryProcessingFunctions.sh" > /dev/null 2>&1

 # Create test IDs file
 local OVERPASS_IDS_FILE="${TMP_DIR}/overpass_ids.txt"
 echo "@id" > "${OVERPASS_IDS_FILE}"
 echo "16239" >> "${OVERPASS_IDS_FILE}"

 # Test with non-existent backup
 run __compareIdsWithBackup "${OVERPASS_IDS_FILE}" "${TMP_DIR}/nonexistent.geojson" "countries"
 [ "$status" -eq 1 ]
}

@test "export scripts should create valid GeoJSON files" {
 # Test exportCountriesBackup.sh creates valid file structure
 skip "Requires database connection - test in hybrid mode instead"
}

@test "backup files should have correct structure" {
 # Verify backup structure
 local COUNTRIES_FILE="${SCRIPT_BASE_DIRECTORY}/data/countries.geojson"
 local MARITIMES_FILE="${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson"

 # Check type
 run jq -r '.type' "${COUNTRIES_FILE}"
 [ "$output" = "FeatureCollection" ]

 # Check features exist
 run jq '.features | length' "${COUNTRIES_FILE}"
 [ "$output" -gt 0 ]

 # Check country_id exists in properties
 run jq -r '.features[0].properties.country_id' "${COUNTRIES_FILE}"
 [ "$output" != "null" ]
 [ "$output" != "" ]
}

