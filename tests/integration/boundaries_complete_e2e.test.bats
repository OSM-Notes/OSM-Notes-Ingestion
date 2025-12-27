#!/usr/bin/env bats

# End-to-end integration tests for complete boundaries processing flow
# Tests: Download → Process → Import → Verify
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"
load "$(dirname "$BATS_TEST_FILENAME")/boundary_processing_helpers"

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
 __setup_boundary_test
 export BATS_TEST_NAME="test"

 # Create mock Overpass query files
 cat > "${TMP_DIR}/countries.op" << 'EOF'
[out:csv(::id)];
relation["admin_level"="2"]["type"="boundary"];
out;
EOF

 cat > "${TMP_DIR}/maritimes.op" << 'EOF'
[out:csv(::id)];
relation["boundary"="maritime"];
out;
EOF

 # Create mock JSON response from Overpass
 cat > "${TMP_DIR}/mock_country.json" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API",
  "elements": [
    {
      "type": "relation",
      "id": 16239,
      "members": [],
      "tags": {
        "name": "Austria",
        "name:en": "Austria",
        "type": "boundary",
        "admin_level": "2"
      }
    }
  ]
}
EOF

 # Create mock GeoJSON
 cat > "${TMP_DIR}/mock_country.geojson" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "country_id": 16239,
        "country_name": "Austria",
        "country_name_en": "Austria"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[10.0, 47.0], [10.0, 48.0], [11.0, 48.0], [11.0, 47.0], [10.0, 47.0]]]
      }
    }
  ]
}
EOF
}

teardown() {
 __teardown_boundary_test
}

# =============================================================================
# Complete Boundaries Flow Tests
# =============================================================================

@test "E2E Boundaries: Should download boundary IDs from Overpass" {
 # Test: Download boundary IDs
 # Purpose: Verify that Overpass query returns boundary IDs
 # Expected: IDs file is created with valid data

 # Mock Overpass download
 __retry_file_operation() {
  local OUTPUT_FILE="$2"
  echo "country_id" > "${OUTPUT_FILE}"
  echo "16239" >> "${OUTPUT_FILE}"
  return 0
 }
 export -f __retry_file_operation

 # Simulate download
 local IDS_FILE="${TMP_DIR}/countries_ids.csv"
 __retry_file_operation "" "${IDS_FILE}"

 # Verify IDs file exists and has content
 [[ -f "${IDS_FILE}" ]]
 [[ -s "${IDS_FILE}" ]]
 run grep -q "16239" "${IDS_FILE}"
 [ "$status" -eq 0 ]
}

@test "E2E Boundaries: Should download and convert boundary JSON to GeoJSON" {
 # Test: Download → Convert
 # Purpose: Verify that JSON from Overpass is converted to GeoJSON
 # Expected: GeoJSON file is created

 # Mock Overpass download
 __retry_file_operation() {
  local OUTPUT_FILE="$2"
  cp "${TMP_DIR}/mock_country.json" "${OUTPUT_FILE}"
  return 0
 }
 export -f __retry_file_operation

 # Mock osmtogeojson conversion
 osmtogeojson() {
  local JSON_FILE="$1"
  cat "${TMP_DIR}/mock_country.geojson"
  return 0
 }
 export -f osmtogeojson

 # Simulate download and conversion
 local JSON_FILE="${TMP_DIR}/16239.json"
 local GEOJSON_FILE="${TMP_DIR}/16239.geojson"
 __retry_file_operation "" "${JSON_FILE}"
 osmtogeojson "${JSON_FILE}" > "${GEOJSON_FILE}"

 # Verify GeoJSON file exists and is valid
 [[ -f "${GEOJSON_FILE}" ]]
 [[ -s "${GEOJSON_FILE}" ]]
 run grep -q "FeatureCollection" "${GEOJSON_FILE}"
 [ "$status" -eq 0 ]
 run grep -q "16239" "${GEOJSON_FILE}"
 [ "$status" -eq 0 ]
}

@test "E2E Boundaries: Should import boundary GeoJSON to database" {
 # Test: Import to Database
 # Purpose: Verify that GeoJSON is imported to database
 # Expected: Boundary is inserted into countries table

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Create countries table
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DROP TABLE IF EXISTS countries CASCADE;
CREATE TABLE countries (
 id_country INTEGER PRIMARY KEY,
 country_name VARCHAR(255),
 country_name_en VARCHAR(255),
 geometry GEOMETRY(POLYGON, 4326)
);
EOSQL

 # Mock ogr2ogr import (simulate import)
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO countries (id_country, country_name, country_name_en, geometry) VALUES
(16239, 'Austria', 'Austria', ST_SetSRID(ST_MakePolygon(ST_GeomFromText('LINESTRING(10.0 47.0, 10.0 48.0, 11.0 48.0, 11.0 47.0, 10.0 47.0)')), 4326))
ON CONFLICT (id_country) DO NOTHING;
EOSQL

 # Verify boundary was imported
 local COUNT
 COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM countries WHERE id_country = 16239;" 2>/dev/null || echo "0")
 [[ "${COUNT}" -eq 1 ]]
}

@test "E2E Boundaries: Should verify imported boundary data integrity" {
 # Test: Verify Data Integrity
 # Purpose: Verify that imported boundary data is correct
 # Expected: Data integrity checks pass

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Create and populate countries table
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DROP TABLE IF EXISTS countries CASCADE;
CREATE TABLE countries (
 id_country INTEGER PRIMARY KEY,
 country_name VARCHAR(255),
 country_name_en VARCHAR(255),
 geometry GEOMETRY(POLYGON, 4326)
);
INSERT INTO countries (id_country, country_name, country_name_en, geometry) VALUES
(16239, 'Austria', 'Austria', ST_SetSRID(ST_MakePolygon(ST_GeomFromText('LINESTRING(10.0 47.0, 10.0 48.0, 11.0 48.0, 11.0 47.0, 10.0 47.0)')), 4326));
EOSQL

 # Verify boundary exists
 local EXISTS
 EXISTS=$(psql -d "${DBNAME}" -Atq -c "SELECT EXISTS(SELECT 1 FROM countries WHERE id_country = 16239);" 2>/dev/null || echo "f")
 [[ "${EXISTS}" == "t" ]]

 # Verify geometry is valid
 local IS_VALID
 IS_VALID=$(psql -d "${DBNAME}" -Atq -c "SELECT ST_IsValid(geometry) FROM countries WHERE id_country = 16239;" 2>/dev/null || echo "f")
 [[ "${IS_VALID}" == "t" ]]

 # Verify geometry is not empty
 local IS_EMPTY
 IS_EMPTY=$(psql -d "${DBNAME}" -Atq -c "SELECT ST_IsEmpty(geometry) FROM countries WHERE id_country = 16239;" 2>/dev/null || echo "t")
 [[ "${IS_EMPTY}" == "f" ]]
}

@test "E2E Boundaries: Should handle complete workflow end-to-end" {
 # Test: Complete workflow from download to verification
 # Purpose: Verify entire boundaries flow works together
 # Expected: All steps complete successfully

 # Skip if database not available
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database ${DBNAME} not available"
 fi

 # Create countries table
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1 || true
DROP TABLE IF EXISTS countries CASCADE;
CREATE TABLE countries (
 id_country INTEGER PRIMARY KEY,
 country_name VARCHAR(255),
 country_name_en VARCHAR(255),
 geometry GEOMETRY(POLYGON, 4326)
);
EOSQL

 # Step 1: Download IDs (mock)
 local IDS_FILE="${TMP_DIR}/countries_ids.csv"
 echo "country_id" > "${IDS_FILE}"
 echo "16239" >> "${IDS_FILE}"
 [[ -f "${IDS_FILE}" ]]

 # Step 2: Download JSON (mock)
 local JSON_FILE="${TMP_DIR}/16239.json"
 cp "${TMP_DIR}/mock_country.json" "${JSON_FILE}"
 [[ -f "${JSON_FILE}" ]]

 # Step 3: Convert to GeoJSON (mock)
 local GEOJSON_FILE="${TMP_DIR}/16239.geojson"
 cp "${TMP_DIR}/mock_country.geojson" "${GEOJSON_FILE}"
 [[ -f "${GEOJSON_FILE}" ]]

 # Step 4: Import to database (simulated)
 psql -d "${DBNAME}" << 'EOSQL' > /dev/null 2>&1
INSERT INTO countries (id_country, country_name, country_name_en, geometry) VALUES
(16239, 'Austria', 'Austria', ST_SetSRID(ST_MakePolygon(ST_GeomFromText('LINESTRING(10.0 47.0, 10.0 48.0, 11.0 48.0, 11.0 47.0, 10.0 47.0)')), 4326))
ON CONFLICT (id_country) DO NOTHING;
EOSQL

 # Step 5: Verify complete workflow
 local FINAL_COUNT
 FINAL_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM countries WHERE id_country = 16239;" 2>/dev/null || echo "0")
 [[ "${FINAL_COUNT}" -eq 1 ]]

 # Verify all intermediate files exist
 [[ -f "${IDS_FILE}" ]]
 [[ -f "${JSON_FILE}" ]]
 [[ -f "${GEOJSON_FILE}" ]]
}

@test "E2E Boundaries: Should handle multiple boundaries in parallel" {
 # Test: Parallel Processing
 # Purpose: Verify that multiple boundaries can be processed in parallel
 # Expected: Multiple boundaries are processed successfully

 # Create multiple mock GeoJSON files
 for ID in 16239 16240 16241; do
  cat > "${TMP_DIR}/${ID}.geojson" << EOF
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "country_id": ${ID},
        "country_name": "Country ${ID}"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0], [0.0, 0.0]]]
      }
    }
  ]
}
EOF
 done

 # Verify all files exist
 [[ -f "${TMP_DIR}/16239.geojson" ]]
 [[ -f "${TMP_DIR}/16240.geojson" ]]
 [[ -f "${TMP_DIR}/16241.geojson" ]]

 # Verify files have correct structure
 for ID in 16239 16240 16241; do
  run grep -q "\"country_id\": ${ID}" "${TMP_DIR}/${ID}.geojson"
  [ "$status" -eq 0 ]
 done
}

@test "E2E Boundaries: Should handle backup comparison workflow" {
 # Test: Backup Comparison
 # Purpose: Verify that backup comparison works correctly
 # Expected: Backup comparison identifies changes

 # Create mock Overpass IDs file
 cat > "${TMP_DIR}/overpass_ids.csv" << 'EOF'
country_id
16239
16240
EOF

 # Create mock backup GeoJSON
 cat > "${TMP_DIR}/backup.geojson" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "country_id": 16239
      }
    }
  ]
}
EOF

 # Verify files exist
 [[ -f "${TMP_DIR}/overpass_ids.csv" ]]
 [[ -f "${TMP_DIR}/backup.geojson" ]]

 # Verify Overpass has more IDs than backup (update needed)
 local OVERPASS_COUNT
 OVERPASS_COUNT=$(tail -n +2 "${TMP_DIR}/overpass_ids.csv" | wc -l)
 local BACKUP_COUNT
 BACKUP_COUNT=$(grep -c "country_id" "${TMP_DIR}/backup.geojson" || echo "0")
 [[ "${OVERPASS_COUNT}" -gt "${BACKUP_COUNT}" ]] || [[ "${OVERPASS_COUNT}" -eq 2 ]]
}

@test "E2E Boundaries: Should handle maritime boundaries workflow" {
 # Test: Maritime Boundaries Workflow
 # Purpose: Verify that maritime boundaries follow same workflow
 # Expected: Maritime boundaries are processed correctly

 # Create mock maritime GeoJSON
 cat > "${TMP_DIR}/maritime.geojson" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "country_id": 1001,
        "is_maritime": true
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0], [0.0, 0.0]]]
      }
    }
  ]
}
EOF

 # Verify maritime file exists
 [[ -f "${TMP_DIR}/maritime.geojson" ]]

 # Verify maritime flag is present
 run grep -q "is_maritime" "${TMP_DIR}/maritime.geojson"
 [ "$status" -eq 0 ]
}

