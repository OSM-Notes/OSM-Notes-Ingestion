#!/bin/bash

# Validation Functions for OSM-Notes-profile
# This file contains validation functions used across different scripts.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

# shellcheck disable=SC2317,SC2155,SC2034

# Note: This file expects to be sourced after commonFunctions.sh which provides logging functions
# If sourced directly, ensure commonFunctions.sh is loaded first

# JSON schema files for validation
# shellcheck disable=SC2034
declare -r JSON_SCHEMA_OVERPASS="${SCRIPT_BASE_DIRECTORY}/json/osm-jsonschema.json"
declare -r JSON_SCHEMA_GEOJSON="${SCRIPT_BASE_DIRECTORY}/json/geojsonschema.json"

# Validate input file
function __validate_input_file() {
 local file_path="${1}"
 local description="${2:-Input file}"

 if [[ ! -f "${file_path}" ]]; then
  __loge "ERROR: ${description} not found: ${file_path}"
  return 1
 fi

 if [[ ! -r "${file_path}" ]]; then
  __loge "ERROR: ${description} not readable: ${file_path}"
  return 1
 fi

 if [[ ! -s "${file_path}" ]]; then
  __loge "ERROR: ${description} is empty: ${file_path}"
  return 1
 fi

 __logd "${description} validation passed: ${file_path}"
 return 0
}

# Validate input files
function __validate_input_files() {
 local files=("$@")
 local failed=0

 for file in "${files[@]}"; do
  if ! __validate_input_file "${file}" "Input file"; then
   failed=1
  fi
 done

 return "${failed}"
}

# Validate XML structure
function __validate_xml_structure() {
 local xml_file="${1}"

 if ! __validate_input_file "${xml_file}" "XML file"; then
  return 1
 fi

 # Check if file is valid XML
 if ! xmllint --noout "${xml_file}" 2> /dev/null; then
  __loge "ERROR: Invalid XML structure: ${xml_file}"
  return 1
 fi

 # Check for required root element
 if ! xmllint --xpath "//osm-notes" "${xml_file}" > /dev/null 2>&1; then
  __loge "ERROR: Missing osm-notes root element: ${xml_file}"
  return 1
 fi

 __logd "XML structure validation passed: ${xml_file}"
 return 0
}

# Validate CSV structure
function __validate_csv_structure() {
 local csv_file="${1}"
 local expected_columns="${2:-}"

 if ! __validate_input_file "${csv_file}" "CSV file"; then
  return 1
 fi

 # Check if file has content
 if [[ ! -s "${csv_file}" ]]; then
  __loge "ERROR: CSV file is empty: ${csv_file}"
  return 1
 fi

 # Check if file has header
 local FIRST_LINE
 FIRST_LINE=$(head -n 1 "${csv_file}" 2> /dev/null)
 if [[ -z "${FIRST_LINE}" ]]; then
  __loge "ERROR: CSV file has no header: ${csv_file}"
  return 1
 fi

 # Validate expected columns if provided
 if [[ -n "${expected_columns}" ]]; then
  local COLUMN_COUNT
  COLUMN_COUNT=$(echo "${FIRST_LINE}" | tr ',' '\n' | wc -l)
  local EXPECTED_COUNT
  EXPECTED_COUNT=$(echo "${expected_columns}" | tr ',' '\n' | wc -l)

  if [[ "${COLUMN_COUNT}" -ne "${EXPECTED_COUNT}" ]]; then
   __loge "ERROR: CSV column count mismatch. Expected: ${EXPECTED_COUNT}, Found: ${COLUMN_COUNT}"
   return 1
  fi
 fi

 __logd "CSV structure validation passed: ${csv_file}"
 return 0
}

# Validate SQL structure
function __validate_sql_structure() {
 local sql_file="${1}"

 if ! __validate_input_file "${sql_file}" "SQL file"; then
  return 1
 fi

 # Check for basic SQL syntax
 if ! grep -q -E "(CREATE|INSERT|UPDATE|DELETE|SELECT|DROP|ALTER|VACUUM|ANALYZE|REINDEX|CLUSTER|TRUNCATE)" "${sql_file}"; then
  __loge "ERROR: No valid SQL statements found: ${sql_file}"
  return 1
 fi

 # Check for balanced parentheses
 local open_parens
 local close_parens
 open_parens=$(grep -o '(' "${sql_file}" | wc -l)
 close_parens=$(grep -o ')' "${sql_file}" | wc -l)

 if [[ "${open_parens}" -ne "${close_parens}" ]]; then
  __loge "ERROR: Unbalanced parentheses in SQL file: ${sql_file}"
  return 1
 fi

 __logd "SQL structure validation passed: ${sql_file}"
 return 0
}

# Validate config file
function __validate_config_file() {
 local config_file="${1}"

 if ! __validate_input_file "${config_file}" "Config file"; then
  return 1
 fi

 # Check for key-value pairs
 if ! grep -q '=' "${config_file}"; then
  __loge "ERROR: No key-value pairs found in config file: ${config_file}"
  return 1
 fi

 # Check for valid variable names
 if grep -q -E '^[^A-Za-z_][^=]*=' "${config_file}"; then
  __loge "ERROR: Invalid variable names in config file: ${config_file}"
  return 1
 fi

 __logd "Config file validation passed: ${config_file}"
 return 0
}

# Validate JSON structure
function __validate_json_structure() {
 local json_file="${1}"
 local schema_file="${2:-}"

 if ! __validate_input_file "${json_file}" "JSON file"; then
  return 1
 fi

 # Check if file is valid JSON
 if ! jq empty "${json_file}" 2> /dev/null; then
  __loge "ERROR: Invalid JSON structure: ${json_file}"
  return 1
 fi

 # Validate against schema if provided
 if [[ -n "${schema_file}" ]] && [[ -f "${schema_file}" ]]; then
  if command -v ajv > /dev/null 2>&1; then
   if ! ajv validate -s "${schema_file}" -d "${json_file}"; then
    __loge "ERROR: JSON validation against schema failed: ${json_file}"
    return 1
   fi
  else
   __logw "WARNING: ajv not available, skipping schema validation"
  fi
 fi

 __logd "JSON structure validation passed: ${json_file}"
 return 0
}

# Validate database connection
function __validate_database_connection() {
 local dbname="${1:-${DBNAME}}"
 local dbuser="${2:-${DB_USER}}"
 local dbhost="${3:-${DB_HOST}}"
 local dbport="${4:-${DB_PORT}}"

 # Check if PostgreSQL client is available
 if ! command -v psql > /dev/null 2>&1; then
  __loge "ERROR: PostgreSQL client (psql) not available"
  return 1
 fi

 # Test database connection
 if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${dbhost}" -p "${dbport}" -U "${dbuser}" -d "${dbname}" -c "SELECT 1;" > /dev/null 2>&1; then
  __loge "ERROR: Database connection failed"
  return 1
 fi

 __logd "Database connection validation passed"
 return 0
}

# Validate database tables
function __validate_database_tables() {
 local dbname="${1:-${DBNAME}}"
 local dbuser="${2:-${DB_USER}}"
 local dbhost="${3:-${DB_HOST}}"
 local dbport="${4:-${DB_PORT}}"
 local tables=("${@:5}")

 # Validate database connection first
 if ! __validate_database_connection "${dbname}" "${dbuser}" "${dbhost}" "${dbport}"; then
  return 1
 fi

 # Check if tables exist
 for table in "${tables[@]}"; do
  if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${dbhost}" -p "${dbport}" -U "${dbuser}" -d "${dbname}" -c "SELECT 1 FROM ${table} LIMIT 1;" > /dev/null 2>&1; then
   __loge "ERROR: Table does not exist: ${table}"
   return 1
  fi
 done

 __logd "Database tables validation passed"
 return 0
}

# Validate database extensions
function __validate_database_extensions() {
 local dbname="${1:-${DBNAME}}"
 local dbuser="${2:-${DB_USER}}"
 local dbhost="${3:-${DB_HOST}}"
 local dbport="${4:-${DB_PORT}}"
 local extensions=("${@:5}")

 # Validate database connection first
 if ! __validate_database_connection "${dbname}" "${dbuser}" "${dbhost}" "${dbport}"; then
  return 1
 fi

 # Check if extensions are available
 for ext in "${extensions[@]}"; do
  if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${dbhost}" -p "${dbport}" -U "${dbuser}" -d "${dbname}" -c "SELECT 1 FROM pg_extension WHERE extname = '${ext}';" | grep -q "1"; then
   __loge "ERROR: Extension not available: ${ext}"
   return 1
  fi
 done

 __logd "Database extensions validation passed"
 return 0
}

# Validate ISO8601 date format
function __validate_iso8601_date() {
 local date_string="${1}"
 local description="${2:-Date}"

 # Check if date string is not empty
 if [[ -z "${date_string}" ]]; then
  __loge "ERROR: ${description} is empty"
  return 1
 fi

 # Validate ISO8601 format (YYYY-MM-DDTHH:MM:SSZ or YYYY-MM-DDTHH:MM:SS+HH:MM)
 if ! echo "${date_string}" | grep -q -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2})$'; then
  __loge "ERROR: Invalid ISO8601 date format: ${date_string}"
  return 1
 fi

 # Validate date components
 local year month day hour minute second
 year=$(echo "${date_string}" | cut -d'T' -f1 | cut -d'-' -f1)
 month=$(echo "${date_string}" | cut -d'T' -f1 | cut -d'-' -f2)
 day=$(echo "${date_string}" | cut -d'T' -f1 | cut -d'-' -f3)
 hour=$(echo "${date_string}" | cut -d'T' -f2 | cut -d':' -f1)
 minute=$(echo "${date_string}" | cut -d'T' -f2 | cut -d':' -f2)
 second=$(echo "${date_string}" | cut -d'T' -f2 | cut -d':' -f3 | cut -d'Z' -f1 | cut -d'+' -f1 | cut -d'-' -f1)

 # Validate ranges
 if [[ "${year}" -lt 1900 ]] || [[ "${year}" -gt 2100 ]]; then
  __loge "ERROR: Invalid year: ${year}"
  return 1
 fi

 if [[ "${month}" -lt 1 ]] || [[ "${month}" -gt 12 ]]; then
  __loge "ERROR: Invalid month: ${month}"
  return 1
 fi

 if [[ "${day}" -lt 1 ]] || [[ "${day}" -gt 31 ]]; then
  __loge "ERROR: Invalid day: ${day}"
  return 1
 fi

 if [[ "${hour}" -lt 0 ]] || [[ "${hour}" -gt 23 ]]; then
  __loge "ERROR: Invalid hour: ${hour}"
  return 1
 fi

 if [[ "${minute}" -lt 0 ]] || [[ "${minute}" -gt 59 ]]; then
  __loge "ERROR: Invalid minute: ${minute}"
  return 1
 fi

 if [[ "${second}" -lt 0 ]] || [[ "${second}" -gt 59 ]]; then
  __loge "ERROR: Invalid second: ${second}"
  return 1
 fi

 __logd "ISO8601 date validation passed: ${date_string}"
 return 0
}

# Validate XML dates
function __validate_xml_dates() {
 local xml_file="${1}"
 local xpath_queries=("${@:2}")

 if ! __validate_input_file "${xml_file}" "XML file"; then
  return 1
 fi

 # If no specific queries provided, use common date attributes
 if [[ ${#xpath_queries[@]} -eq 0 ]]; then
  xpath_queries=(
   "//note/@created_at"
   "//note/@closed_at"
   "//comment/@timestamp"
  )
 fi

 local failed=0

 for query in "${xpath_queries[@]}"; do
  local dates
  mapfile -t dates < <(xmllint --xpath "${query}" "${xml_file}" 2> /dev/null | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}Z' || true)

  for date in "${dates[@]}"; do
   if [[ -n "${date}" ]]; then
    if ! __validate_iso8601_date "${date}" "XML date"; then
     failed=1
    fi
   fi
  done
 done

 if [[ "${failed}" -eq 1 ]]; then
  __loge "ERROR: XML date validation failed"
  return 1
 fi

 __logd "XML date validation passed: ${xml_file}"
 return 0
}

# Validate CSV dates
function __validate_csv_dates() {
 local csv_file="${1}"
 local date_columns=("${@:2}")

 if ! __validate_input_file "${csv_file}" "CSV file"; then
  return 1
 fi

 # If no specific columns provided, look for common date column names
 if [[ ${#date_columns[@]} -eq 0 ]]; then
  local header
  header=$(head -n 1 "${csv_file}")
  IFS=',' read -ra columns <<< "${header}"

  for col in "${columns[@]}"; do
   if [[ "${col}" =~ (date|time|created|updated|timestamp) ]]; then
    date_columns+=("${col}")
   fi
  done
 fi

 local failed=0

 for col in "${date_columns[@]}"; do
  local col_index
  col_index=$(head -n 1 "${csv_file}" | tr ',' '\n' | grep -n "^${col}$" | cut -d: -f1)

  if [[ -n "${col_index}" ]]; then
   local dates
   mapfile -t dates < <(tail -n +2 "${csv_file}" | cut -d',' -f"${col_index}" | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' || true)

   for date in "${dates[@]}"; do
    if [[ -n "${date}" ]]; then
     if ! __validate_iso8601_date "${date}" "CSV date"; then
      failed=1
     fi
    fi
   done
  fi
 done

 if [[ "${failed}" -eq 1 ]]; then
  __loge "ERROR: CSV date validation failed"
  return 1
 fi

 __logd "CSV date validation passed: ${csv_file}"
 return 0
}

# Validate file checksum
function __validate_file_checksum() {
 local file_path="${1}"
 local expected_checksum="${2}"
 local algorithm="${3:-sha256}"

 if ! __validate_input_file "${file_path}" "File"; then
  return 1
 fi

 # Calculate actual checksum
 local actual_checksum
 case "${algorithm}" in
 md5)
  actual_checksum=$(md5sum "${file_path}" | cut -d' ' -f1)
  ;;
 sha1)
  actual_checksum=$(sha1sum "${file_path}" | cut -d' ' -f1)
  ;;
 sha256)
  actual_checksum=$(sha256sum "${file_path}" | cut -d' ' -f1)
  ;;
 *)
  __loge "ERROR: Unsupported checksum algorithm: ${algorithm}"
  return 1
  ;;
 esac

 # Compare checksums
 if [[ "${actual_checksum}" != "${expected_checksum}" ]]; then
  __loge "ERROR: Checksum mismatch for ${file_path}"
  __loge "Expected: ${expected_checksum}"
  __loge "Actual: ${actual_checksum}"
  return 1
 fi

 __logd "File checksum validation passed: ${file_path}"
 return 0
}

# Validate file checksum from file
function __validate_file_checksum_from_file() {
 local file_path="${1}"
 local checksum_file="${2}"
 local algorithm="${3:-sha256}"

 if ! __validate_input_file "${file_path}" "File"; then
  return 1
 fi

 if ! __validate_input_file "${checksum_file}" "Checksum file"; then
  return 1
 fi

 # Extract expected checksum from checksum file
 local expected_checksum
 local filename
 filename=$(basename "${file_path}")
 expected_checksum=$(grep "${filename}" "${checksum_file}" | cut -d' ' -f1)

 if [[ -z "${expected_checksum}" ]]; then
  __loge "ERROR: No checksum found for ${filename} in ${checksum_file}"
  return 1
 fi

 # Validate checksum
 if ! __validate_file_checksum "${file_path}" "${expected_checksum}" "${algorithm}"; then
  return 1
 fi

 return 0
}

# Generate file checksum
function __generate_file_checksum() {
 local file_path="${1}"
 local algorithm="${2:-sha256}"

 if ! __validate_input_file "${file_path}" "File"; then
  return 1
 fi

 local checksum
 case "${algorithm}" in
 md5)
  checksum=$(md5sum "${file_path}" | cut -d' ' -f1)
  ;;
 sha1)
  checksum=$(sha1sum "${file_path}" | cut -d' ' -f1)
  ;;
 sha256)
  checksum=$(sha256sum "${file_path}" | cut -d' ' -f1)
  ;;
 *)
  __loge "ERROR: Unsupported checksum algorithm: ${algorithm}"
  return 1
  ;;
 esac

 echo "${checksum}"
 return 0
}

# Validate directory checksums
function __validate_directory_checksums() {
 local directory="${1}"
 local checksum_file="${2}"
 local algorithm="${3:-sha256}"

 if [[ ! -d "${directory}" ]]; then
  __loge "ERROR: Directory not found: ${directory}"
  return 1
 fi

 if ! __validate_input_file "${checksum_file}" "Checksum file"; then
  return 1
 fi

 local failed=0
 local files
 mapfile -t files < <(find "${directory}" -type f -name "*.xml" -o -name "*.csv" -o -name "*.json" 2> /dev/null)

 for file in "${files[@]}"; do
  local relative_path
  relative_path=$(realpath --relative-to="${directory}" "${file}")

  if ! __validate_file_checksum_from_file "${file}" "${checksum_file}" "${algorithm}"; then
   __loge "ERROR: Checksum validation failed for ${relative_path}"
   failed=1
  fi
 done

 if [[ "${failed}" -eq 1 ]]; then
  __loge "ERROR: Directory checksum validation failed"
  return 1
 fi

 __logd "Directory checksum validation passed: ${directory}"
 return 0
}

# Validate JSON schema
function __validate_json_schema() {
 local json_file="${1}"
 local schema_file="${2}"

 if ! __validate_input_file "${json_file}" "JSON file"; then
  return 1
 fi

 if ! __validate_input_file "${schema_file}" "JSON schema file"; then
  return 1
 fi

 # Check if ajv is available
 if ! command -v ajv > /dev/null 2>&1; then
  __loge "ERROR: ajv (JSON schema validator) not available"
  return 1
 fi

 # Validate JSON against schema
 if ! ajv validate -s "${schema_file}" -d "${json_file}"; then
  __loge "ERROR: JSON schema validation failed: ${json_file}"
  return 1
 fi

 __logd "JSON schema validation passed: ${json_file}"
 return 0
}

# Validate coordinates
function __validate_coordinates() {
 local lat="${1}"
 local lon="${2}"

 # Check if coordinates are numeric
 if ! [[ "${lat}" =~ ^-?[0-9]+\.?[0-9]*$ ]] || ! [[ "${lon}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  __loge "ERROR: Invalid coordinate format: lat=${lat}, lon=${lon}"
  return 1
 fi

 # Validate latitude range (-90 to 90)
 if (($(echo "${lat} < -90" | bc -l))) || (($(echo "${lat} > 90" | bc -l))); then
  __loge "ERROR: Latitude out of range (-90 to 90): ${lat}"
  return 1
 fi

 # Validate longitude range (-180 to 180)
 if (($(echo "${lon} < -180" | bc -l))) || (($(echo "${lon} > 180" | bc -l))); then
  __loge "ERROR: Longitude out of range (-180 to 180): ${lon}"
  return 1
 fi

 __logd "Coordinate validation passed: lat=${lat}, lon=${lon}"
 return 0
}

# Validate numeric range
function __validate_numeric_range() {
 local value="${1}"
 local min="${2}"
 local max="${3}"
 local description="${4:-Value}"

 # Check if value is numeric
 if ! [[ "${value}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  __loge "ERROR: Invalid numeric format: ${value}"
  return 1
 fi

 # Validate range
 if (($(echo "${value} < ${min}" | bc -l))) || (($(echo "${value} > ${max}" | bc -l))); then
  __loge "ERROR: ${description} out of range (${min} to ${max}): ${value}"
  return 1
 fi

 __logd "Numeric range validation passed: ${value}"
 return 0
}

# Validate string pattern
function __validate_string_pattern() {
 local string="${1}"
 local pattern="${2}"
 local description="${3:-String}"

 if [[ ! "${string}" =~ ${pattern} ]]; then
  __loge "ERROR: ${description} does not match pattern: ${string}"
  return 1
 fi

 __logd "String pattern validation passed: ${string}"
 return 0
}

# Validate XML coordinates
function __validate_xml_coordinates() {
 local xml_file="${1}"
 local lat_xpath="${2:-//note/@lat}"
 local lon_xpath="${3:-//note/@lon}"

 if ! __validate_input_file "${xml_file}" "XML file"; then
  return 1
 fi

 local failed=0
 local coordinates
 mapfile -t coordinates < <(xmllint --xpath "${lat_xpath} | ${lon_xpath}" "${xml_file}" 2> /dev/null | grep -o '[0-9.-]*' || true)

 # Process coordinates in pairs (lat, lon)
 for ((i = 0; i < ${#coordinates[@]}; i += 2)); do
  local lat="${coordinates[i]}"
  local lon="${coordinates[i + 1]}"

  if [[ -n "${lat}" ]] && [[ -n "${lon}" ]]; then
   if ! __validate_coordinates "${lat}" "${lon}"; then
    failed=1
   fi
  fi
 done

 if [[ "${failed}" -eq 1 ]]; then
  __loge "ERROR: XML coordinate validation failed"
  return 1
 fi

 __logd "XML coordinate validation passed: ${xml_file}"
 return 0
}

# Validate CSV coordinates
function __validate_csv_coordinates() {
 local csv_file="${1}"
 local lat_column="${2:-lat}"
 local lon_column="${3:-lon}"

 if ! __validate_input_file "${csv_file}" "CSV file"; then
  return 1
 fi

 # Find column indices
 local header
 header=$(head -n 1 "${csv_file}")
 local lat_index lon_index
 lat_index=$(echo "${header}" | tr ',' '\n' | grep -n "^${lat_column}$" | cut -d: -f1)
 lon_index=$(echo "${header}" | tr ',' '\n' | grep -n "^${lon_column}$" | cut -d: -f1)

 if [[ -z "${lat_index}" ]] || [[ -z "${lon_index}" ]]; then
  __loge "ERROR: Coordinate columns not found: ${lat_column}, ${lon_column}"
  return 1
 fi

 local failed=0

 # Read coordinates from CSV
 while IFS=',' read -r -a fields; do
  local lat="${fields[lat_index - 1]}"
  local lon="${fields[lon_index - 1]}"

  if [[ -n "${lat}" ]] && [[ -n "${lon}" ]]; then
   if ! __validate_coordinates "${lat}" "${lon}"; then
    failed=1
   fi
  fi
 done < <(tail -n +2 "${csv_file}")

 if [[ "${failed}" -eq 1 ]]; then
  __loge "ERROR: CSV coordinate validation failed"
  return 1
 fi

 __logd "CSV coordinate validation passed: ${csv_file}"
 return 0
}

# Validate database variables
function __validate_database_variables() {
 local required_vars=("DBNAME" "DB_USER" "DB_PASSWORD" "DB_HOST" "DB_PORT")
 local missing_vars=()

 for var in "${required_vars[@]}"; do
  if [[ -z "${!var}" ]]; then
   missing_vars+=("${var}")
  fi
 done

 if [[ ${#missing_vars[@]} -gt 0 ]]; then
  __loge "ERROR: Missing required database variables: ${missing_vars[*]}"
  return 1
 fi

 __logd "Database variables validation passed"
 return 0
}
