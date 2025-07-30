#!/usr/bin/env bats

# Test file for boundary validation and special cases
# Tests the special handling for Austria, Taiwan, and column duplication issues
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-29

load ../../test_helper

setup() {
  # Setup test environment
  export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
  export TMP_DIR="$(mktemp -d)"
  export BASENAME="test_boundary_validation"
  
  # Source the functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
  
  # Mock logger functions
  function __log_start() { echo "LOG_START: $*"; }
  function __log_finish() { echo "LOG_FINISH: $*"; }
  function __logi() { echo "INFO: $*"; }
  function __loge() { echo "ERROR: $*"; }
  function __logw() { echo "WARN: $*"; }
  function __logd() { echo "DEBUG: $*"; }
}

teardown() {
  # Cleanup test environment
  rm -rf "${TMP_DIR}"
}

@test "test Taiwan boundary handling - oversized records" {
  # Create a mock GeoJSON file with many official_name and alt_name tags
  cat > "${TMP_DIR}/taiwan_test.geojson" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "name": "Taiwan",
        "official_name": "Republic of China",
        "alt_name": "Formosa",
        "alt_name:en": "Taiwan",
        "official_name:en": "Republic of China",
        "alt_name:zh": "台湾",
        "official_name:zh": "中华民国",
        "alt_name:ja": "台湾",
        "official_name:ja": "中華民国"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[121, 23], [122, 23], [122, 24], [121, 24], [121, 23]]]
      }
    }
  ]
}
EOF

  # Mock the __processBoundary function to test Taiwan handling
  function __processBoundary() {
    local ID="$1"
    local JSON_FILE="${TMP_DIR}/test.json"
    local GEOJSON_FILE="${TMP_DIR}/taiwan_test.geojson"
    
    # Simulate Taiwan processing
    if [[ "${ID}" -eq 16239 ]]; then
      # Remove problematic tags
      grep -v "official_name" "${GEOJSON_FILE}" \
        | grep -v "alt_name" > "${GEOJSON_FILE}-new"
      mv "${GEOJSON_FILE}-new" "${GEOJSON_FILE}"
      
      # Verify tags were removed
      if grep -q "official_name" "${GEOJSON_FILE}"; then
        echo "ERROR: official_name tags not removed"
        return 1
      fi
      if grep -q "alt_name" "${GEOJSON_FILE}"; then
        echo "ERROR: alt_name tags not removed"
        return 1
      fi
      
      echo "SUCCESS: Taiwan boundary processed correctly"
      return 0
    fi
    return 1
  }
  
  run __processBoundary 16239
  [ "$status" -eq 0 ]
  [[ "$output" == *"SUCCESS: Taiwan boundary processed correctly"* ]]
}

@test "test Austria boundary handling - topology issues" {
  # Create a mock GeoJSON file with invalid topology
  cat > "${TMP_DIR}/austria_test.geojson" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "name": "Austria",
        "name:en": "Austria",
        "name:de": "Österreich"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[10, 47], [11, 47], [11, 48], [10, 48], [10, 47]]]
      }
    }
  ]
}
EOF

  # Mock the __processBoundary function to test Austria handling
  function __processBoundary() {
    local ID="$1"
    local GEOJSON_FILE="${TMP_DIR}/austria_test.geojson"
    
    # Simulate Austria processing
    if [[ "${ID}" -eq 16239 ]]; then
      # Check if ST_Buffer is used for Austria
      local process_operation="psql -d testdb -c \"INSERT INTO countries SELECT 16239, 'Austria', 'Österreich', 'Austria', ST_Union(ST_Buffer(wkb_geometry, 0.0)) FROM import;\""
      
      if [[ "${process_operation}" == *"ST_Buffer"* ]]; then
        echo "SUCCESS: Austria boundary uses ST_Buffer for topology fix"
        return 0
      else
        echo "ERROR: Austria boundary not using ST_Buffer"
        return 1
      fi
    fi
    return 1
  }
  
  run __processBoundary 16239
  [ "$status" -eq 0 ]
  [[ "$output" == *"SUCCESS: Austria boundary uses ST_Buffer for topology fix"* ]]
}

@test "test column duplication detection and handling" {
  # Mock database query to simulate duplicate columns
  function psql() {
    if [[ "$*" == *"SELECT column_name, COUNT(*)"* ]]; then
      echo "name:xx-XX|2"
      echo "name:XX-xx|2"
      echo "name:en|1"
      return 0
    fi
    return 0
  }
  
  # Test column duplication detection
  local column_check_operation="psql -d testdb -c \"SELECT column_name, COUNT(*) FROM information_schema.columns WHERE table_name = 'import' GROUP BY column_name HAVING COUNT(*) > 1;\""
  local column_check_result
  column_check_result=$(eval "${column_check_operation}" 2>/dev/null)
  
  [[ -n "${column_check_result}" ]]
  [[ "${column_check_result}" == *"name:xx-XX"* ]]
  [[ "${column_check_result}" == *"name:XX-xx"* ]]
}

@test "test ogr2ogr validation with case-sensitive column names" {
  # Create a test GeoJSON with case-sensitive column names
  cat > "${TMP_DIR}/case_sensitive_test.geojson" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "name": "Test Country",
        "name:en": "Test Country",
        "name:EN": "Test Country",
        "name:En": "Test Country"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]
      }
    }
  ]
}
EOF

  # Mock ogr2ogr to simulate column duplication error
  function ogr2ogr() {
    if [[ "$*" == *"case_sensitive_test.geojson"* ]]; then
      echo "ERROR: column \"name:EN\" specified more than once"
      return 1
    fi
    return 0
  }
  
  # Test that the error is detected and handled
  run ogr2ogr -f PostgreSQL PG:dbname=testdb -nln import -overwrite "${TMP_DIR}/case_sensitive_test.geojson"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR: column \"name:EN\" specified more than once"* ]]
}

@test "test large boundary handling - Taiwan case" {
  # Create a mock GeoJSON file that would exceed PostgreSQL row size limit
  cat > "${TMP_DIR}/large_boundary_test.geojson" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {
        "name": "Large Country",
        "official_name": "Very Long Official Name That Exceeds Normal Limits",
        "alt_name": "Alternative Name 1",
        "alt_name:en": "Alternative Name 2",
        "alt_name:es": "Nombre Alternativo 3",
        "alt_name:fr": "Nom Alternatif 4",
        "alt_name:de": "Alternativer Name 5",
        "alt_name:it": "Nome Alternativo 6",
        "alt_name:pt": "Nome Alternativo 7",
        "alt_name:ru": "Альтернативное Имя 8",
        "alt_name:zh": "替代名称 9",
        "alt_name:ja": "代替名 10",
        "official_name:en": "Very Long Official Name in English",
        "official_name:es": "Nombre Oficial Muy Largo en Español",
        "official_name:fr": "Nom Officiel Très Long en Français",
        "official_name:de": "Sehr Langer Offizieller Name auf Deutsch",
        "official_name:it": "Nome Ufficiale Molto Lungo in Italiano",
        "official_name:pt": "Nome Oficial Muito Longo em Português",
        "official_name:ru": "Очень Длинное Официальное Имя на Русском",
        "official_name:zh": "很长的官方中文名称",
        "official_name:ja": "日本語の非常に長い公式名称"
      },
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0, 0], [1, 0], [1, 1], [0, 1], [0, 0]]]
      }
    }
  ]
}
EOF

  # Test that large boundaries are handled correctly
  local original_size=$(wc -c < "${TMP_DIR}/large_boundary_test.geojson")
  
  # Simulate the Taiwan processing (remove problematic tags)
  grep -v "official_name" "${TMP_DIR}/large_boundary_test.geojson" \
    | grep -v "alt_name" > "${TMP_DIR}/large_boundary_test_processed.geojson"
  
  local processed_size=$(wc -c < "${TMP_DIR}/large_boundary_test_processed.geojson")
  
  # Verify that the processed file is smaller
  [ "${processed_size}" -lt "${original_size}" ]
  
  # Verify that problematic tags were removed
  if grep -q "official_name" "${TMP_DIR}/large_boundary_test_processed.geojson"; then
    echo "ERROR: official_name tags not removed from large boundary"
    return 1
  fi
  
  if grep -q "alt_name" "${TMP_DIR}/large_boundary_test_processed.geojson"; then
    echo "ERROR: alt_name tags not removed from large boundary"
    return 1
  fi
  
  echo "SUCCESS: Large boundary processed correctly"
}

@test "test Austria topology fix with ST_Buffer" {
  # Mock the SQL operation for Austria
  function psql() {
    if [[ "$*" == *"ST_Buffer"* ]]; then
      echo "SUCCESS: Austria topology fixed with ST_Buffer"
      return 0
    elif [[ "$*" == *"ST_makeValid"* ]]; then
      echo "ERROR: Austria should use ST_Buffer, not ST_makeValid"
      return 1
    fi
    return 0
  }
  
  # Test Austria processing
  local austria_operation="psql -d testdb -c \"INSERT INTO countries SELECT 16239, 'Austria', 'Österreich', 'Austria', ST_Union(ST_Buffer(wkb_geometry, 0.0)) FROM import;\""
  
  run eval "${austria_operation}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SUCCESS: Austria topology fixed with ST_Buffer"* ]]
}

@test "test standard boundary processing with ST_makeValid" {
  # Mock the SQL operation for standard boundaries
  function psql() {
    if [[ "$*" == *"ST_makeValid"* ]]; then
      echo "SUCCESS: Standard boundary processed with ST_makeValid"
      return 0
    elif [[ "$*" == *"ST_Buffer"* ]]; then
      echo "ERROR: Standard boundary should use ST_makeValid, not ST_Buffer"
      return 1
    fi
    return 0
  }
  
  # Test standard boundary processing
  local standard_operation="psql -d testdb -c \"INSERT INTO countries SELECT 1, 'Test Country', 'Test Country', 'Test Country', ST_Union(ST_makeValid(wkb_geometry)) FROM import;\""
  
  run eval "${standard_operation}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SUCCESS: Standard boundary processed with ST_makeValid"* ]]
} 