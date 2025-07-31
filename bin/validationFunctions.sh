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
 local FILE_PATH="${1}"
 local DESCRIPTION="${2:-Input file}"

 if [[ ! -f "${FILE_PATH}" ]]; then
  __loge "ERROR: ${DESCRIPTION} not found: ${FILE_PATH}"
  return 1
 fi

 if [[ ! -r "${FILE_PATH}" ]]; then
  __loge "ERROR: ${DESCRIPTION} not readable: ${FILE_PATH}"
  return 1
 fi

 if [[ ! -s "${FILE_PATH}" ]]; then
  __loge "ERROR: ${DESCRIPTION} is empty: ${FILE_PATH}"
  return 1
 fi

 __logd "${DESCRIPTION} validation passed: ${FILE_PATH}"
 return 0
}

# Validate input files
function __validate_input_files() {
 local FILES=("$@")
 local FAILED=0

 for FILE in "${FILES[@]}"; do
  if ! __validate_input_file "${FILE}" "Input file"; then
   FAILED=1
  fi
 done

 return "${FAILED}"
}

# Validate XML structure
function __validate_xml_structure() {
 local XML_FILE="${1}"

 if ! __validate_input_file "${XML_FILE}" "XML file"; then
  return 1
 fi

 # Check if file is valid XML
 if ! xmllint --noout "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Invalid XML structure: ${XML_FILE}"
  return 1
 fi

 # Check for required root element
 if ! xmllint --xpath "//osm-notes" "${XML_FILE}" > /dev/null 2>&1; then
  __loge "ERROR: Missing osm-notes root element: ${XML_FILE}"
  return 1
 fi

 __logd "XML structure validation passed: ${XML_FILE}"
 return 0
}

# Validate CSV structure
function __validate_csv_structure() {
 local CSV_FILE="${1}"
 local EXPECTED_COLUMNS="${2:-}"

 if ! __validate_input_file "${CSV_FILE}" "CSV file"; then
  return 1
 fi

 # Check if file has content
 if [[ ! -s "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file is empty: ${CSV_FILE}"
  return 1
 fi

 # Check if file has header
 local FIRST_LINE
 FIRST_LINE=$(head -n 1 "${CSV_FILE}" 2> /dev/null)
 if [[ -z "${FIRST_LINE}" ]]; then
  __loge "ERROR: CSV file has no header: ${CSV_FILE}"
  return 1
 fi

 # Check column count if expected columns provided
 if [[ -n "${EXPECTED_COLUMNS}" ]]; then
  local COLUMN_COUNT
  COLUMN_COUNT=$(echo "${FIRST_LINE}" | tr ',' '\n' | wc -l)
  local EXPECTED_COUNT
  EXPECTED_COUNT=$(echo "${EXPECTED_COLUMNS}" | tr ',' '\n' | wc -l)

  if [[ "${COLUMN_COUNT}" -ne "${EXPECTED_COUNT}" ]]; then
   __loge "ERROR: CSV file has ${COLUMN_COUNT} columns, expected ${EXPECTED_COUNT}: ${CSV_FILE}"
   return 1
  fi
 fi

 __logd "CSV structure validation passed: ${CSV_FILE}"
 return 0
}

# Validate SQL structure
function __validate_sql_structure() {
 local SQL_FILE="${1}"

 if ! __validate_input_file "${SQL_FILE}" "SQL file"; then
  return 1
 fi

 # Check for basic SQL syntax
 if ! grep -q -E "(CREATE|INSERT|UPDATE|DELETE|SELECT|DROP|ALTER|VACUUM|ANALYZE|REINDEX|CLUSTER|TRUNCATE)" "${SQL_FILE}"; then
  __loge "ERROR: No valid SQL statements found: ${SQL_FILE}"
  return 1
 fi

 # Check for balanced parentheses
 local OPEN_PARENS
 local CLOSE_PARENS
 OPEN_PARENS=$(grep -o '(' "${SQL_FILE}" | wc -l)
 CLOSE_PARENS=$(grep -o ')' "${SQL_FILE}" | wc -l)

 if [[ "${OPEN_PARENS}" -ne "${CLOSE_PARENS}" ]]; then
  __loge "ERROR: Unbalanced parentheses in SQL file: ${SQL_FILE}"
  return 1
 fi

 __logd "SQL structure validation passed: ${SQL_FILE}"
 return 0
}

# Validate config file
function __validate_config_file() {
 local CONFIG_FILE="${1}"

 if ! __validate_input_file "${CONFIG_FILE}" "Config file"; then
  return 1
 fi

 # Check for key-value pairs
 if ! grep -q '=' "${CONFIG_FILE}"; then
  __loge "ERROR: No key-value pairs found in config file: ${CONFIG_FILE}"
  return 1
 fi

 # Check for valid variable names
 if grep -q -E '^[^A-Za-z_][^=]*=' "${CONFIG_FILE}"; then
  __loge "ERROR: Invalid variable names in config file: ${CONFIG_FILE}"
  return 1
 fi

 __logd "Config file validation passed: ${CONFIG_FILE}"
 return 0
}

# Validate JSON structure
function __validate_json_structure() {
 local JSON_FILE="${1}"
 local SCHEMA_FILE="${2:-}"

 if ! __validate_input_file "${JSON_FILE}" "JSON file"; then
  return 1
 fi

 # Check if file is valid JSON
 if ! jq empty "${JSON_FILE}" 2> /dev/null; then
  __loge "ERROR: Invalid JSON structure: ${JSON_FILE}"
  return 1
 fi

 # Validate against schema if provided
 if [[ -n "${SCHEMA_FILE}" ]] && [[ -f "${SCHEMA_FILE}" ]]; then
  if command -v ajv > /dev/null 2>&1; then
   if ! ajv validate -s "${SCHEMA_FILE}" -d "${JSON_FILE}"; then
    __loge "ERROR: JSON validation against schema failed: ${JSON_FILE}"
    return 1
   fi
  else
   __logw "WARNING: ajv not available, skipping schema validation"
  fi
 fi

 __logd "JSON structure validation passed: ${JSON_FILE}"
 return 0
}

# Validate database connection
# Nota:
# Por defecto, la conexión a PostgreSQL se realiza usando peer (local, sin usuario/contraseña).
# Los parámetros DBHOST, DBPORT y DBUSER solo son necesarios para pruebas en Docker, CI/CD
# o entornos donde no se use peer.
function __validate_database_connection() {
 local DBNAME_PARAM="${1:-${DBNAME}}"
 local DBUSER_PARAM="${2:-${DB_USER}}"
 local DBHOST_PARAM="${3:-${DB_HOST}}"
 local DBPORT_PARAM="${4:-${DB_PORT}}"

 # Check if PostgreSQL client is available
 if ! command -v psql > /dev/null 2>&1; then
  __loge "ERROR: PostgreSQL client (psql) not available"
  return 1
 fi

 # Test database connection
 if [[ -n "${DBHOST_PARAM}" ]] || [[ -n "${DBPORT_PARAM}" ]] || [[ -n "${DBUSER_PARAM}" ]]; then
  # Usar parámetros personalizados (por ejemplo, en Docker o CI/CD)
  if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DBHOST_PARAM}" -p "${DBPORT_PARAM}" -U "${DBUSER_PARAM}" -d "${DBNAME_PARAM}" -c "SELECT 1;" > /dev/null 2>&1; then
   __loge "ERROR: Database connection failed (host/port/user)"
   return 1
  fi
 else
  # Usar peer (local, sin usuario/contraseña)
  if ! psql -d "${DBNAME_PARAM}" -c "SELECT 1;" > /dev/null 2>&1; then
   __loge "ERROR: Database connection failed (peer)"
   return 1
  fi
 fi

 __logd "Database connection validation passed"
 return 0
}

# Validate database tables
# Nota:
# Por defecto, la conexión a PostgreSQL se realiza usando peer (local, sin usuario/contraseña).
# Los parámetros DBHOST, DBPORT y DBUSER solo son necesarios para pruebas en Docker, CI/CD
# o entornos donde no se use peer.
function __validate_database_tables() {
 local DBNAME_PARAM="${1:-${DBNAME}}"
 local DBUSER_PARAM="${2:-${DB_USER}}"
 local DBHOST_PARAM="${3:-${DB_HOST}}"
 local DBPORT_PARAM="${4:-${DB_PORT}}"
 local TABLES=("${@:5}")

 if ! __validate_database_connection "${DBNAME_PARAM}" "${DBUSER_PARAM}" "${DBHOST_PARAM}" "${DBPORT_PARAM}"; then
  return 1
 fi

 for TABLE in "${TABLES[@]}"; do
  if [[ -n "${DBHOST_PARAM}" ]] || [[ -n "${DBPORT_PARAM}" ]] || [[ -n "${DBUSER_PARAM}" ]]; then
   if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DBHOST_PARAM}" -p "${DBPORT_PARAM}" -U "${DBUSER_PARAM}" -d "${DBNAME_PARAM}" -c "SELECT 1 FROM information_schema.tables WHERE table_name = '${TABLE}';" | grep -q "1"; then
    __loge "ERROR: Table ${TABLE} does not exist in database ${DBNAME_PARAM} (host/port/user)"
    return 1
   fi
  else
   if ! psql -d "${DBNAME_PARAM}" -c "SELECT 1 FROM information_schema.tables WHERE table_name = '${TABLE}';" | grep -q "1"; then
    __loge "ERROR: Table ${TABLE} does not exist in database ${DBNAME_PARAM} (peer)"
    return 1
   fi
  fi
 done

 __logd "Database tables validation passed"
 return 0
}

# Validate database extensions
# Nota:
# Por defecto, la conexión a PostgreSQL se realiza usando peer (local, sin usuario/contraseña).
# Los parámetros DBHOST, DBPORT y DBUSER solo son necesarios para pruebas en Docker, CI/CD
# o entornos donde no se use peer.
function __validate_database_extensions() {
 local DBNAME_PARAM="${1:-${DBNAME}}"
 local DBUSER_PARAM="${2:-${DB_USER}}"
 local DBHOST_PARAM="${3:-${DB_HOST}}"
 local DBPORT_PARAM="${4:-${DB_PORT}}"
 local EXTENSIONS=("${@:5}")

 if ! __validate_database_connection "${DBNAME_PARAM}" "${DBUSER_PARAM}" "${DBHOST_PARAM}" "${DBPORT_PARAM}"; then
  return 1
 fi

 for EXTENSION in "${EXTENSIONS[@]}"; do
  if [[ -n "${DBHOST_PARAM}" ]] || [[ -n "${DBPORT_PARAM}" ]] || [[ -n "${DBUSER_PARAM}" ]]; then
   if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DBHOST_PARAM}" -p "${DBPORT_PARAM}" -U "${DBUSER_PARAM}" -d "${DBNAME_PARAM}" -c "SELECT 1 FROM pg_extension WHERE extname = '${EXTENSION}';" | grep -q "1"; then
    __loge "ERROR: Extension ${EXTENSION} is not installed in database ${DBNAME_PARAM} (host/port/user)"
    return 1
   fi
  else
   if ! psql -d "${DBNAME_PARAM}" -c "SELECT 1 FROM pg_extension WHERE extname = '${EXTENSION}';" | grep -q "1"; then
    __loge "ERROR: Extension ${EXTENSION} is not installed in database ${DBNAME_PARAM} (peer)"
    return 1
   fi
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
 local XML_FILE="${1}"
 local XPATH_QUERIES=("${@:2}")

 if ! __validate_xml_structure "${XML_FILE}"; then
  return 1
 fi

 local FAILED=0

 # Validate dates in XML
 for XPATH_QUERY in "${XPATH_QUERIES[@]}"; do
  local DATES
  DATES=$(xmllint --xpath "${XPATH_QUERY}" "${XML_FILE}" 2> /dev/null | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}Z' || true)

  if [[ -n "${DATES}" ]]; then
   while IFS= read -r DATE; do
    if ! __validate_date_format "${DATE}" "XML date"; then
     __loge "ERROR: Invalid date found in XML: ${DATE}"
     FAILED=1
    fi
   done <<< "${DATES}"
  fi
 done

 if [[ "${FAILED}" -eq 1 ]]; then
  return 1
 fi

 __logd "XML dates validation passed: ${XML_FILE}"
 return 0
}

# Validate CSV dates
function __validate_csv_dates() {
 local CSV_FILE="${1}"
 local DATE_COLUMNS=("${@:2}")

 if ! __validate_csv_structure "${CSV_FILE}"; then
  return 1
 fi

 # Get header line
 local HEADER
 HEADER=$(head -n 1 "${CSV_FILE}")

 local FAILED=0

 # Validate dates in CSV
 for DATE_COLUMN in "${DATE_COLUMNS[@]}"; do
  local COL_INDEX
  COL_INDEX=$(echo "${HEADER}" | tr ',' '\n' | grep -n "^${DATE_COLUMN}$" | cut -d: -f1)

  if [[ -z "${COL_INDEX}" ]]; then
   __loge "ERROR: Date column not found: ${DATE_COLUMN}"
   FAILED=1
   continue
  fi

  # Skip header and validate dates
  local DATES
  DATES=$(tail -n +2 "${CSV_FILE}" | cut -d',' -f"${COL_INDEX}" | grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' || true)

  if [[ -n "${DATES}" ]]; then
   while IFS= read -r DATE; do
    if ! __validate_date_format "${DATE}" "CSV date"; then
     __loge "ERROR: Invalid date found in CSV: ${DATE}"
     FAILED=1
    fi
   done <<< "${DATES}"
  fi
 done

 if [[ "${FAILED}" -eq 1 ]]; then
  return 1
 fi

 __logd "CSV dates validation passed: ${CSV_FILE}"
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

 local FAILED=0
 local FILES
 mapfile -t FILES < <(find "${directory}" -type f -name "*.xml" -o -name "*.csv" -o -name "*.json" 2> /dev/null)

 for FILE in "${FILES[@]}"; do
  local RELATIVE_PATH
  RELATIVE_PATH=$(realpath --relative-to="${directory}" "${FILE}")

  if ! __validate_file_checksum_from_file "${FILE}" "${checksum_file}" "${algorithm}"; then
   __loge "ERROR: Checksum validation failed for ${RELATIVE_PATH}"
   FAILED=1
  fi
 done

 if [[ "${FAILED}" -eq 1 ]]; then
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
 local REQUIRED_VARS=("DBNAME" "DB_USER" "DB_PASSWORD" "DB_HOST" "DB_PORT")
 local MISSING_VARS=()

 for VAR in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!VAR}" ]]; then
   MISSING_VARS+=("${VAR}")
  fi
 done

 if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
  __loge "ERROR: Missing required database variables: ${MISSING_VARS[*]}"
  return 1
 fi

 __logd "Database variables validation passed"
 return 0
}

# Validate date format
function __validate_date_format() {
 local DATE_STRING="${1}"
 local DESCRIPTION="${2:-Date}"

 if [[ -z "${DATE_STRING}" ]]; then
  __loge "ERROR: ${DESCRIPTION} is empty"
  return 1
 fi

 # Check if date string matches ISO 8601 format
 if ! [[ "${DATE_STRING}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  __loge "ERROR: ${DESCRIPTION} does not match ISO 8601 format: ${DATE_STRING}"
  return 1
 fi

 # Validate date components
 local YEAR MONTH DAY HOUR MINUTE SECOND
 IFS='T:Z' read -r YEAR MONTH DAY HOUR MINUTE SECOND <<< "${DATE_STRING}"

 # Check year range
 if [[ "${YEAR}" -lt 1900 ]] || [[ "${YEAR}" -gt 2100 ]]; then
  __loge "ERROR: ${DESCRIPTION} year out of range: ${YEAR}"
  return 1
 fi

 # Check month range
 if [[ "${MONTH}" -lt 1 ]] || [[ "${MONTH}" -gt 12 ]]; then
  __loge "ERROR: ${DESCRIPTION} month out of range: ${MONTH}"
  return 1
 fi

 # Check day range
 if [[ "${DAY}" -lt 1 ]] || [[ "${DAY}" -gt 31 ]]; then
  __loge "ERROR: ${DESCRIPTION} day out of range: ${DAY}"
  return 1
 fi

 # Check hour range
 if [[ "${HOUR}" -lt 0 ]] || [[ "${HOUR}" -gt 23 ]]; then
  __loge "ERROR: ${DESCRIPTION} hour out of range: ${HOUR}"
  return 1
 fi

 # Check minute range
 if [[ "${MINUTE}" -lt 0 ]] || [[ "${MINUTE}" -gt 59 ]]; then
  __loge "ERROR: ${DESCRIPTION} minute out of range: ${MINUTE}"
  return 1
 fi

 # Check second range
 if [[ "${SECOND}" -lt 0 ]] || [[ "${SECOND}" -gt 59 ]]; then
  __loge "ERROR: ${DESCRIPTION} second out of range: ${SECOND}"
  return 1
 fi

 __logd "${DESCRIPTION} validation passed: ${DATE_STRING}"
 return 0
}
