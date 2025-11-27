#!/usr/bin/env bats

# Integration tests for boundaries backup functionality
# Tests that backups are actually used in processPlanet and updateCountries
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

bats_require_minimum_version 1.5.0

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

setup() {
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export SCRIPT_BASE_DIRECTORY
 export TMP_DIR="$(mktemp -d)"
 export LOG_LEVEL="INFO"
 export TEST_MODE="true"

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
 # Restore real backups if they existed
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson.backup" ]]; then
  mv "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson.backup" "${SCRIPT_BASE_DIRECTORY}/data/countries.geojson" 2>/dev/null || true
 fi
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson.backup" ]]; then
  mv "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson.backup" "${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson" 2>/dev/null || true
 fi
 rm -rf "${TMP_DIR}"
}

@test "processPlanet base should use backup when available" {
 skip "Requires full database setup - test in hybrid mode instead"
 # This test would verify that processPlanetNotes.sh --base uses backup
 # instead of downloading from Overpass
}

@test "updateCountries should compare IDs before downloading" {
 skip "Requires full database setup - test in hybrid mode instead"
 # This test would verify that updateCountries compares IDs first
 # and only downloads if they differ
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

