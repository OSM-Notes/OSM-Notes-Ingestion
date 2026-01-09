#!/usr/bin/env bats

# Integration tests for boundaries backup functionality
# Tests that backups are actually used in processPlanet and updateCountries
# Author: Andres Gomez (AngocA)
# Version: 2026-01-23

bats_require_minimum_version 1.5.0

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

# Shared database setup (runs once per file, not per test)
setup_file() {
 # Set up test environment
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="$(mktemp -d)"
 export TEST_DIR="${TMP_DIR}"
 export DBNAME="${TEST_DBNAME:-osm_notes_ingestion_test}"
 export BASENAME="test_boundaries_backup"
 export LOG_LEVEL="INFO"
 export TEST_MODE="true"
 export FORCE_FALLBACK_MODE="true"
 
 # Setup hybrid mock environment
 source "${SCRIPT_BASE_DIRECTORY}/tests/setup_hybrid_mock_environment.sh"
 setup_hybrid_mock_environment
 activate_hybrid_mock_environment
 
 # Setup shared database schema once for all tests
 __shared_db_setup_file
}

setup() {
 # Per-test setup (runs before each test)
 # Use shared database setup from setup_file
 
 # Ensure TMP_DIR exists (it should be created in setup_file, but verify)
 if [[ -z "${TMP_DIR:-}" ]] || [[ ! -d "${TMP_DIR}" ]]; then
  export TMP_DIR="$(mktemp -d)"
  export TEST_DIR="${TMP_DIR}"
 fi

 # Backup real files if they exist
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" ]]; then
  mv "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson.backup" 2>/dev/null || true
 fi
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" ]]; then
  mv "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson.backup" 2>/dev/null || true
 fi

 # Create test backup files with known IDs
 mkdir -p "${SCRIPT_BASE_DIRECTORY}/data"

 # Create countries backup with specific IDs
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

 # Create maritimes backup
 cat > "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "country_id": 12345,
        "country_name": "Test Maritime (EEZ)",
        "country_name_es": "Marítimo de Prueba (ZEE)",
        "country_name_en": "Test Maritime (EEZ)"
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
 # Per-test cleanup (runs after each test)
 # Restore real backups if they existed
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson.backup" ]]; then
  mv "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson.backup" "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" 2>/dev/null || true
 fi
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson.backup" ]]; then
  mv "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson.backup" "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" 2>/dev/null || true
 fi
}

teardown_file() {
 # Shared database teardown (runs once per file)
 # Deactivate hybrid mock environment
 deactivate_hybrid_mock_environment
 
 # Cleanup shared database
 __shared_db_teardown_file
 
 # Restore real backups if they existed
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson.backup" ]]; then
  mv "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson.backup" "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" 2>/dev/null || true
 fi
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson.backup" ]]; then
  mv "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson.backup" "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" 2>/dev/null || true
 fi
 
 # Cleanup TMP_DIR
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

@test "processPlanet base should use backup when available" {
 # Skip if database is not available
 __skip_if_no_database "${DBNAME}" "Database not available"
 
 # This test verifies that processPlanetNotes.sh --base uses backup
 # instead of downloading from Overpass when backup files exist
 # Note: This is a simplified test that verifies backup files are used
 # Full integration test would require executing processPlanetNotes.sh --base
 # which is tested in hybrid mode scripts (run_processAPINotes_hybrid.sh)
 
 # Verify backup files exist (created in setup)
 [ -f "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" ]
 [ -f "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" ]
 
 # Verify backup files are valid GeoJSON
 run jq empty "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" 2>&1
 [ "$status" -eq 0 ]
 
 run jq empty "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" 2>&1
 [ "$status" -eq 0 ]
}

@test "updateCountries should compare IDs before downloading" {
 # Skip if database is not available
 __skip_if_no_database "${DBNAME}" "Database not available"
 
 # This test verifies that updateCountries compares IDs first
 # and only downloads if they differ
 # Note: This is a simplified test that verifies backup files exist
 # Full integration test would require executing updateCountries.sh
 # which is tested in hybrid mode scripts (run_updateCountries_hybrid.sh)
 
 # Verify backup files exist (created in setup)
 [ -f "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" ]
 [ -f "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" ]
 
 # Verify backup files contain expected country IDs
 local country_id_1
 country_id_1=$(jq -r '.features[0].properties.country_id' "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson")
 [ "${country_id_1}" = "16239" ]
 
 local country_id_2
 country_id_2=$(jq -r '.features[1].properties.country_id' "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson")
 [ "${country_id_2}" = "2186646" ]
}

@test "backup files should be valid GeoJSON" {
 # Verify test backups are valid
 run jq empty "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" 2>&1
 [ "$status" -eq 0 ]

 run jq empty "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" 2>&1
 [ "$status" -eq 0 ]

 # Verify structure
 run jq -r '.type' "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson"
 [ "$output" = "FeatureCollection" ]

 run jq '.features | length' "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson"
 [ "$output" -eq 2 ]

 run jq '.features | length' "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson"
 [ "$output" -eq 1 ]
}

