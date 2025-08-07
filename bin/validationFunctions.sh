#!/bin/bash

# Validation Functions for OSM-Notes-profile
# This file contains validation functions for various data types.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-02

# shellcheck disable=SC2317,SC2155,SC2034

# Note: This file expects to be sourced after commonFunctions.sh which provides logging functions
# If sourced directly, ensure commonFunctions.sh is loaded first

# Load common functions if not already loaded
# Set SCRIPT_BASE_DIRECTORY if not already set
if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Set LOGGER_UTILITY if not already set
if [[ -z "${LOGGER_UTILITY:-}" ]]; then
 LOGGER_UTILITY="${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"
fi

if [[ -z "${__COMMON_FUNCTIONS_LOADED:-}" ]]; then
 # shellcheck disable=SC1091
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh" ]]; then
  # Preserve SCRIPT_BASE_DIRECTORY before loading commonFunctions.sh
  SAVED_SCRIPT_BASE_DIRECTORY="${SCRIPT_BASE_DIRECTORY}"
  source "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh"
  # Restore SCRIPT_BASE_DIRECTORY if it was changed
  if [[ "${SCRIPT_BASE_DIRECTORY}" != "${SAVED_SCRIPT_BASE_DIRECTORY}" ]]; then
   SCRIPT_BASE_DIRECTORY="${SAVED_SCRIPT_BASE_DIRECTORY}"
   LOGGER_UTILITY="${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"
  fi
 elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/commonFunctions.sh" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/commonFunctions.sh"
 fi
fi

# JSON schema files for validation
# shellcheck disable=SC2034
if [[ -z "${JSON_SCHEMA_OVERPASS:-}" ]]; then declare -r JSON_SCHEMA_OVERPASS="${SCRIPT_BASE_DIRECTORY}/json/osm-jsonschema.json"; fi
if [[ -z "${JSON_SCHEMA_GEOJSON:-}" ]]; then declare -r JSON_SCHEMA_GEOJSON="${SCRIPT_BASE_DIRECTORY}/json/geojsonschema.json"; fi

# Show help function
function __show_help() {
 echo "Validation Functions for OSM-Notes-profile"
 echo "This file contains validation functions for various data types."
 echo
 echo "Usage: source bin/validationFunctions.sh"
 echo
 echo "Available functions:"
 echo "  __validate_input_file      - Validate input file"
 echo "  __validate_input_files     - Validate multiple input files"
 echo "  __validate_xml_structure   - Validate XML structure"
 echo "  __validate_csv_structure   - Validate CSV structure"
 echo "  __validate_sql_structure   - Validate SQL structure"
 echo "  __validate_config_file     - Validate config file"
 echo "  __validate_json_structure  - Validate JSON structure"
 echo "  __validate_database_connection - Validate database connection"
 echo "  __validate_database_tables - Validate database tables"
 echo "  __validate_database_extensions - Validate database extensions"
 echo "  __validate_iso8601_date    - Validate ISO8601 date"
 echo "  __validate_xml_dates       - Validate XML dates"
 echo "  __validate_csv_dates       - Validate CSV dates"
 echo "  __validate_file_checksum   - Validate file checksum"
 echo "  __validate_coordinates     - Validate coordinates"
 echo "  __validate_numeric_range   - Validate numeric range"
 echo "  __validate_string_pattern  - Validate string pattern"
 echo
 echo "Author: Andres Gomez (AngocA)"
 echo "Version: 2025-08-02"
 exit 1
}

# Validate input file
function __validate_input_file() {
 local FILE_PATH="${1}"
 local DESCRIPTION="${2:-Input file}"

 __logd "=== VALIDATING INPUT FILE ==="
 __logd "File: ${FILE_PATH}"
 __logd "Description: ${DESCRIPTION}"

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
 __logd "=== INPUT FILE VALIDATION COMPLETED ==="
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

 __logi "=== VALIDATING XML STRUCTURE ==="
 __logd "XML file: ${XML_FILE}"

 if ! __validate_input_file "${XML_FILE}" "XML file"; then
  return 1
 fi

 # Check if file is valid XML
 if ! xmllint --noout "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Invalid XML structure: ${XML_FILE}"
  return 1
 fi

 # Check for required root element (osm-notes for planet, osm for API)
 if ! (xmllint --xpath "//osm-notes" "${XML_FILE}" > /dev/null 2>&1 || xmllint --xpath "//osm" "${XML_FILE}" > /dev/null 2>&1); then
  __loge "ERROR: Missing osm-notes or osm root element: ${XML_FILE}"
  return 1
 fi

 __logd "XML structure validation passed: ${XML_FILE}"
 __logi "=== XML STRUCTURE VALIDATION COMPLETED SUCCESSFULLY ==="
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

 # Check if database name is provided
 if [[ -z "${DBNAME_PARAM}" ]]; then
  __loge "ERROR: Database name is required"
  return 1
 fi

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

 # Check if database name is provided
 if [[ -z "${DBNAME_PARAM}" ]]; then
  __loge "ERROR: Database name is required for table validation"
  return 1
 fi

 # Check if tables are provided for validation
 if [[ ${#TABLES[@]} -eq 0 ]]; then
  __loge "ERROR: No tables specified for validation"
  return 1
 fi

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

 # Check if database name is provided
 if [[ -z "${DBNAME_PARAM}" ]]; then
  __loge "ERROR: Database name is required for extension validation"
  return 1
 fi

 # Check if extensions are provided for validation
 if [[ ${#EXTENSIONS[@]} -eq 0 ]]; then
  __loge "ERROR: No extensions specified for validation"
  return 1
 fi

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
 local DATE_STRING="${1}"
 local DESCRIPTION="${2:-Date}"

 # Check if date string is not empty
 if [[ -z "${DATE_STRING}" ]]; then
  __loge "ERROR: ${DESCRIPTION} is empty"
  return 1
 fi

 # Validate ISO8601 format (YYYY-MM-DDTHH:MM:SSZ or YYYY-MM-DDTHH:MM:SS+HH:MM)
 if ! echo "${DATE_STRING}" | grep -q -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2})$'; then
  __loge "ERROR: Invalid ISO8601 date format: ${DATE_STRING}"
  return 1
 fi

 # Validate date components
 local YEAR MONTH DAY HOUR MINUTE SECOND
 YEAR=$(echo "${DATE_STRING}" | cut -d'T' -f1 | cut -d'-' -f1)
 MONTH=$(echo "${DATE_STRING}" | cut -d'T' -f1 | cut -d'-' -f2)
 DAY=$(echo "${DATE_STRING}" | cut -d'T' -f1 | cut -d'-' -f3)
 HOUR=$(echo "${DATE_STRING}" | cut -d'T' -f2 | cut -d':' -f1)
 MINUTE=$(echo "${DATE_STRING}" | cut -d'T' -f2 | cut -d':' -f2)
 SECOND=$(echo "${DATE_STRING}" | cut -d'T' -f2 | cut -d':' -f3 | cut -d'Z' -f1 | cut -d'+' -f1 | cut -d'-' -f1)

 # Validate ranges
 if [[ "${YEAR}" -lt 1900 ]] || [[ "${YEAR}" -gt 2100 ]]; then
  __loge "ERROR: Invalid year: ${YEAR}"
  return 1
 fi

 if [[ "${MONTH}" -lt 1 ]] || [[ "${MONTH}" -gt 12 ]]; then
  __loge "ERROR: Invalid month: ${MONTH}"
  return 1
 fi

 if [[ "${DAY}" -lt 1 ]] || [[ "${DAY}" -gt 31 ]]; then
  __loge "ERROR: Invalid day: ${DAY}"
  return 1
 fi

 if [[ "${HOUR}" -lt 0 ]] || [[ "${HOUR}" -gt 23 ]]; then
  __loge "ERROR: Invalid hour: ${HOUR}"
  return 1
 fi

 if [[ "${MINUTE}" -lt 0 ]] || [[ "${MINUTE}" -gt 59 ]]; then
  __loge "ERROR: Invalid minute: ${MINUTE}"
  return 1
 fi

 if [[ "${SECOND}" -lt 0 ]] || [[ "${SECOND}" -gt 59 ]]; then
  __loge "ERROR: Invalid second: ${SECOND}"
  return 1
 fi

 __logd "ISO8601 date validation passed: ${DATE_STRING}"
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
  local ALL_DATES_RAW
  # Extract all date values using xmllint (including potentially invalid ones)
  ALL_DATES_RAW=$(xmllint --xpath "${XPATH_QUERY}" "${XML_FILE}" 2> /dev/null || true)

  if [[ -n "${ALL_DATES_RAW}" ]]; then
   # Extract date values from attributes and elements
   local EXTRACTED_DATES
   EXTRACTED_DATES=$(echo "${ALL_DATES_RAW}" | grep -oE '="[^"]*"' | sed 's/="//g' | sed 's/"//g' || true)
   if [[ -z "${EXTRACTED_DATES}" ]]; then
    # If no attributes found, try to extract element text content
    EXTRACTED_DATES=$(echo "${ALL_DATES_RAW}" | grep -oE '>[^<]*<' | sed 's/>//g' | sed 's/<//g' || true)
   fi

   if [[ -n "${EXTRACTED_DATES}" ]]; then
    while IFS= read -r DATE; do
     [[ -z "${DATE}" ]] && continue

     # Validate ISO 8601 dates (YYYY-MM-DDTHH:MM:SSZ)
     if [[ "${DATE}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
      if ! __validate_iso8601_date "${DATE}" "XML date"; then
       __loge "ERROR: Invalid ISO8601 date found in XML: ${DATE}"
       FAILED=1
      fi
     # Validate UTC dates (YYYY-MM-DD HH:MM:SS UTC)
     elif [[ "${DATE}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]UTC$ ]]; then
      if ! __validate_date_format_utc "${DATE}" "XML date"; then
       __loge "ERROR: Invalid UTC date found in XML: ${DATE}"
       FAILED=1
      fi
     else
      __loge "ERROR: Invalid date format found in XML: ${DATE}"
      FAILED=1
     fi
    done <<< "${EXTRACTED_DATES}"
   fi
  fi
 done

 if [[ "${FAILED}" -eq 1 ]]; then
  return 1
 fi

 # Only log in trace mode to reduce verbosity
 if [[ "${LOG_LEVEL:-}" == "TRACE" ]]; then
  __logd "XML dates validation passed: ${XML_FILE}"
 fi
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
 local FILE_PATH="${1}"
 local EXPECTED_CHECKSUM="${2}"
 local ALGORITHM="${3:-sha256}"

 # Check for empty checksum
 if [[ -z "${EXPECTED_CHECKSUM}" ]]; then
  __loge "ERROR: Expected checksum is empty"
  return 1
 fi

 if ! __validate_input_file "${FILE_PATH}" "File for checksum validation"; then
  return 1
 fi

 # Calculate actual checksum
 local ACTUAL_CHECKSUM
 case "${ALGORITHM}" in
 md5)
  ACTUAL_CHECKSUM=$(md5sum "${FILE_PATH}" | cut -d' ' -f1)
  ;;
 sha1)
  ACTUAL_CHECKSUM=$(sha1sum "${FILE_PATH}" | cut -d' ' -f1)
  ;;
 sha256)
  ACTUAL_CHECKSUM=$(sha256sum "${FILE_PATH}" | cut -d' ' -f1)
  ;;
 sha512)
  ACTUAL_CHECKSUM=$(sha512sum "${FILE_PATH}" | cut -d' ' -f1)
  ;;
 *)
  __loge "ERROR: ${ALGORITHM} checksum validation failed"
  __loge "ERROR: Invalid algorithm"
  return 1
  ;;
 esac

 # Compare checksums
 if [[ "${ACTUAL_CHECKSUM}" != "${EXPECTED_CHECKSUM}" ]]; then
  __loge "ERROR: ${ALGORITHM} checksum validation failed"
  __loge "ERROR: Checksum mismatch for ${FILE_PATH}"
  __loge "Expected: ${EXPECTED_CHECKSUM}"
  __loge "Actual: ${ACTUAL_CHECKSUM}"
  return 1
 fi

 __logd "${ALGORITHM} checksum validation passed"
 return 0
}

# Validate file checksum from file
function __validate_file_checksum_from_file() {
 local FILE_PATH="${1}"
 local CHECKSUM_FILE="${2}"
 local ALGORITHM="${3:-sha256}"

 if ! __validate_input_file "${FILE_PATH}" "File"; then
  return 1
 fi

 # Check if checksum file exists and is readable, but allow empty files
 if [[ ! -f "${CHECKSUM_FILE}" ]]; then
  __loge "ERROR: Checksum file not found: ${CHECKSUM_FILE}"
  return 1
 fi

 if [[ ! -r "${CHECKSUM_FILE}" ]]; then
  __loge "ERROR: Checksum file not readable: ${CHECKSUM_FILE}"
  return 1
 fi

 # Extract expected checksum from checksum file
 local EXPECTED_CHECKSUM
 local FILENAME
 FILENAME=$(basename "${FILE_PATH}")
 EXPECTED_CHECKSUM=$(grep "${FILENAME}" "${CHECKSUM_FILE}" | cut -d' ' -f1)

 if [[ -z "${EXPECTED_CHECKSUM}" ]]; then
  __loge "ERROR: Could not extract checksum from file: ${CHECKSUM_FILE}"
  return 1
 fi

 # Validate checksum
 if ! __validate_file_checksum "${FILE_PATH}" "${EXPECTED_CHECKSUM}" "${ALGORITHM}"; then
  return 1
 fi

 return 0
}

# Generate file checksum
function __generate_file_checksum() {
 local FILE_PATH="${1}"
 local ALGORITHM="${2:-sha256}"
 local OUTPUT_FILE="${3:-}"

 if ! __validate_input_file "${FILE_PATH}" "File for checksum generation"; then
  return 1
 fi

 local CHECKSUM
 case "${ALGORITHM}" in
 md5)
  CHECKSUM=$(md5sum "${FILE_PATH}" | cut -d' ' -f1)
  ;;
 sha1)
  CHECKSUM=$(sha1sum "${FILE_PATH}" | cut -d' ' -f1)
  ;;
 sha256)
  CHECKSUM=$(sha256sum "${FILE_PATH}" | cut -d' ' -f1)
  ;;
 sha512)
  CHECKSUM=$(sha512sum "${FILE_PATH}" | cut -d' ' -f1)
  ;;
 *)
  __loge "ERROR: Invalid algorithm: ${ALGORITHM}"
  return 1
  ;;
 esac

 # If output file is specified, save checksum to file
 if [[ -n "${OUTPUT_FILE}" ]]; then
  # Generate checksum in the same format as md5sum/sha256sum (checksum + spaces + filename)
  case "${ALGORITHM}" in
  md5)
   md5sum "${FILE_PATH}" > "${OUTPUT_FILE}"
   ;;
  sha1)
   sha1sum "${FILE_PATH}" > "${OUTPUT_FILE}"
   ;;
  sha256)
   sha256sum "${FILE_PATH}" > "${OUTPUT_FILE}"
   ;;
  sha512)
   sha512sum "${FILE_PATH}" > "${OUTPUT_FILE}"
   ;;
  *)
   echo "${CHECKSUM}  $(basename "${FILE_PATH}")" > "${OUTPUT_FILE}"
   ;;
  esac
  __logd "${ALGORITHM} checksum saved to ${OUTPUT_FILE}"
 fi

 echo "${CHECKSUM}"
 return 0
}

# Validate directory checksums
function __validate_directory_checksums() {
 local DIRECTORY="${1}"
 local CHECKSUM_FILE="${2}"
 local ALGORITHM="${3:-sha256}"

 if [[ ! -d "${DIRECTORY}" ]]; then
  __loge "ERROR: Directory validation failed"
  return 1
 fi

 if ! __validate_input_file "${CHECKSUM_FILE}" "Checksum file"; then
  return 1
 fi

 local FAILED=0
 local FILES
 mapfile -t FILES < <(find "${DIRECTORY}" -type f 2> /dev/null)

 for FILE in "${FILES[@]}"; do
  local RELATIVE_PATH
  RELATIVE_PATH=$(realpath --relative-to="${DIRECTORY}" "${FILE}")

  if ! __validate_file_checksum_from_file "${FILE}" "${CHECKSUM_FILE}" "${ALGORITHM}"; then
   __loge "ERROR: Checksum validation failed for ${RELATIVE_PATH}"
   FAILED=1
  fi
 done

 if [[ "${FAILED}" -eq 1 ]]; then
  __loge "ERROR: Directory checksum validation failed"
  return 1
 fi

 __logd "Directory checksum validation passed"
 return 0
}

# Validate JSON schema
function __validate_json_schema() {
 local JSON_FILE="${1}"
 local SCHEMA_FILE="${2}"

 if ! __validate_input_file "${JSON_FILE}" "JSON file"; then
  return 1
 fi

 if ! __validate_input_file "${SCHEMA_FILE}" "JSON schema file"; then
  return 1
 fi

 # Check if ajv is available
 if ! command -v ajv > /dev/null 2>&1; then
  __loge "ERROR: ajv (JSON schema validator) not available"
  return 1
 fi

 # Validate JSON against schema
 if ! ajv validate -s "${SCHEMA_FILE}" -d "${JSON_FILE}"; then
  __loge "ERROR: JSON schema validation failed: ${JSON_FILE}"
  return 1
 fi

 __logd "JSON schema validation passed: ${JSON_FILE}"
 return 0
}

# Validate coordinates
function __validate_coordinates() {
 local LAT="${1}"
 local LON="${2}"

 # Check if coordinates are numeric
 if ! [[ "${LAT}" =~ ^-?[0-9]+\.?[0-9]*$ ]] || ! [[ "${LON}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  __loge "ERROR: Invalid coordinate format: lat=${LAT}, lon=${LON}"
  return 1
 fi

 # Validate latitude range (-90 to 90)
 if (($(echo "${LAT} < -90" | bc -l 2> /dev/null || echo "0"))) || (($(echo "${LAT} > 90" | bc -l 2> /dev/null || echo "0"))); then
  __loge "ERROR: Latitude out of range (-90 to 90): ${LAT}"
  return 1
 fi

 # Validate longitude range (-180 to 180)
 if (($(echo "${LON} < -180" | bc -l 2> /dev/null || echo "0"))) || (($(echo "${LON} > 180" | bc -l 2> /dev/null || echo "0"))); then
  __loge "ERROR: Longitude out of range (-180 to 180): ${LON}"
  return 1
 fi

 # Only log in trace mode to reduce verbosity
 if [[ "${LOG_LEVEL:-}" == "TRACE" ]]; then
  __logd "Coordinate validation passed: lat=${LAT}, lon=${LON}"
 fi
 return 0
}

# Validate numeric range
function __validate_numeric_range() {
 local VALUE="${1}"
 local MIN="${2}"
 local MAX="${3}"
 local DESCRIPTION="${4:-Value}"

 # Check if value is numeric
 if ! [[ "${VALUE}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  __loge "ERROR: Invalid numeric format: ${VALUE}"
  return 1
 fi

 # Validate range
 if (($(echo "${VALUE} < ${MIN}" | bc -l 2> /dev/null || echo "0"))) || (($(echo "${VALUE} > ${MAX}" | bc -l 2> /dev/null || echo "0"))); then
  __loge "ERROR: ${DESCRIPTION} out of range (${MIN} to ${MAX}): ${VALUE}"
  return 1
 fi

 # Only log in trace mode to reduce verbosity
 if [[ "${LOG_LEVEL:-}" == "TRACE" ]]; then
  __logd "Numeric range validation passed: ${VALUE}"
 fi
 return 0
}

# Validate string pattern
function __validate_string_pattern() {
 local STRING="${1}"
 local PATTERN="${2}"
 local DESCRIPTION="${3:-String}"

 if [[ ! "${STRING}" =~ ${PATTERN} ]]; then
  __loge "ERROR: ${DESCRIPTION} does not match pattern: ${STRING}"
  return 1
 fi

 # Only log in trace mode to reduce verbosity
 if [[ "${LOG_LEVEL:-}" == "TRACE" ]]; then
  __logd "String pattern validation passed: ${STRING}"
 fi
 return 0
}

# Validate XML coordinates
function __validate_xml_coordinates() {
 local XML_FILE="${1}"
 local LAT_XPATH="${2:-//note/@lat}"
 local LON_XPATH="${3:-//note/@lon}"

 if ! __validate_input_file "${XML_FILE}" "XML file"; then
  return 1
 fi

 local FAILED=0
 local COORDINATES
 mapfile -t COORDINATES < <(xmllint --xpath "${LAT_XPATH} | ${LON_XPATH}" "${XML_FILE}" 2> /dev/null | grep -o '[0-9.-]*' || true)

 # Process coordinates in pairs (lat, lon)
 for ((i = 0; i < ${#COORDINATES[@]}; i += 2)); do
  local LAT="${COORDINATES[i]}"
  local LON="${COORDINATES[i + 1]}"

  if [[ -n "${LAT}" ]] && [[ -n "${LON}" ]]; then
   if ! __validate_coordinates "${LAT}" "${LON}"; then
    FAILED=1
   fi
  fi
 done

 if [[ "${FAILED}" -eq 1 ]]; then
  __loge "ERROR: XML coordinate validation failed"
  return 1
 fi

 # Only log in trace mode to reduce verbosity
 if [[ "${LOG_LEVEL:-}" == "TRACE" ]]; then
  __logd "XML coordinate validation passed: ${XML_FILE}"
 fi
 return 0
}

# Validate CSV coordinates
function __validate_csv_coordinates() {
 local CSV_FILE="${1}"
 local LAT_COLUMN="${2:-lat}"
 local LON_COLUMN="${3:-lon}"

 if ! __validate_input_file "${CSV_FILE}" "CSV file"; then
  return 1
 fi

 # Find column indices
 local HEADER
 HEADER=$(head -n 1 "${CSV_FILE}")
 local LAT_INDEX LON_INDEX
 LAT_INDEX=$(echo "${HEADER}" | tr ',' '\n' | grep -n "^${LAT_COLUMN}$" | cut -d: -f1)
 LON_INDEX=$(echo "${HEADER}" | tr ',' '\n' | grep -n "^${LON_COLUMN}$" | cut -d: -f1)

 if [[ -z "${LAT_INDEX}" ]] || [[ -z "${LON_INDEX}" ]]; then
  __loge "ERROR: Coordinate columns not found: ${LAT_COLUMN}, ${LON_COLUMN}"
  return 1
 fi

 local FAILED=0

 # Read coordinates from CSV
 while IFS=',' read -r -a FIELDS; do
  local LAT="${FIELDS[LAT_INDEX - 1]}"
  local LON="${FIELDS[LON_INDEX - 1]}"

  if [[ -n "${LAT}" ]] && [[ -n "${LON}" ]]; then
   if ! __validate_coordinates "${LAT}" "${LON}"; then
    FAILED=1
   fi
  fi
 done < <(tail -n +2 "${CSV_FILE}")

 if [[ "${FAILED}" -eq 1 ]]; then
  __loge "ERROR: CSV coordinate validation failed"
  return 1
 fi

 # Only log in trace mode to reduce verbosity
 if [[ "${LOG_LEVEL:-}" == "TRACE" ]]; then
  __logd "CSV coordinate validation passed: ${CSV_FILE}"
 fi
 return 0
}

# Validate database variables
function __validate_database_variables() {
 # Check for minimal required variables (for peer authentication)
 local MINIMAL_VARS=("DBNAME" "DB_USER")
 local MISSING_MINIMAL=()

 for VAR in "${MINIMAL_VARS[@]}"; do
  if [[ -z "${!VAR}" ]]; then
   MISSING_MINIMAL+=("${VAR}")
  fi
 done

 if [[ ${#MISSING_MINIMAL[@]} -gt 0 ]]; then
  __loge "ERROR: Missing required database variables: ${MISSING_MINIMAL[*]}"
  return 1
 fi

 # For peer authentication (localhost), DB_PASSWORD, DB_HOST, DB_PORT are optional
 # For remote connections, all variables are required
 if [[ -n "${DB_HOST:-}" && "${DB_HOST}" != "localhost" && "${DB_HOST}" != "" ]]; then
  local REMOTE_VARS=("DB_PASSWORD" "DB_HOST" "DB_PORT")
  local MISSING_REMOTE=()

  for VAR in "${REMOTE_VARS[@]}"; do
   if [[ -z "${!VAR}" ]]; then
    MISSING_REMOTE+=("${VAR}")
   fi
  done

  if [[ ${#MISSING_REMOTE[@]} -gt 0 ]]; then
   __loge "ERROR: Missing required remote database variables: ${MISSING_REMOTE[*]}"
   return 1
  fi
 fi

 __logd "Database variable validation passed"
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
 if [[ $((10#${YEAR})) -lt 1900 ]] || [[ $((10#${YEAR})) -gt 2100 ]]; then
  __loge "ERROR: ${DESCRIPTION} year out of range: ${YEAR}"
  return 1
 fi

 # Check month range
 if [[ $((10#${MONTH})) -lt 1 ]] || [[ $((10#${MONTH})) -gt 12 ]]; then
  __loge "ERROR: ${DESCRIPTION} month out of range: ${MONTH}"
  return 1
 fi

 # Check day range
 if [[ $((10#${DAY})) -lt 1 ]] || [[ $((10#${DAY})) -gt 31 ]]; then
  __loge "ERROR: ${DESCRIPTION} day out of range: ${DAY}"
  return 1
 fi

 # Check hour range
 if [[ $((10#${HOUR})) -lt 0 ]] || [[ $((10#${HOUR})) -gt 23 ]]; then
  __loge "ERROR: ${DESCRIPTION} hour out of range: ${HOUR}"
  return 1
 fi

 # Check minute range
 if [[ $((10#${MINUTE})) -lt 0 ]] || [[ $((10#${MINUTE})) -gt 59 ]]; then
  __loge "ERROR: ${DESCRIPTION} minute out of range: ${MINUTE}"
  return 1
 fi

 # Check second range
 if [[ $((10#${SECOND})) -lt 0 ]] || [[ $((10#${SECOND})) -gt 59 ]]; then
  __loge "ERROR: ${DESCRIPTION} second out of range: ${SECOND}"
  return 1
 fi

 # Only log in trace mode to reduce verbosity
 if [[ "${LOG_LEVEL:-}" == "TRACE" ]]; then
  __logd "${DESCRIPTION} validation passed: ${DATE_STRING}"
 fi
 return 0
}

# Validate date format with UTC timezone
function __validate_date_format_utc() {
 local DATE_STRING="${1}"
 local DESCRIPTION="${2:-Date}"

 if [[ -z "${DATE_STRING}" ]]; then
  __loge "ERROR: ${DESCRIPTION} is empty"
  return 1
 fi

 # Check if date string matches format: YYYY-MM-DD HH:MM:SS UTC
 if ! [[ "${DATE_STRING}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]UTC$ ]]; then
  __loge "ERROR: ${DESCRIPTION} does not match UTC format: ${DATE_STRING}"
  return 1
 fi

 # Extract date and time components using regex
 local YEAR MONTH DAY HOUR MINUTE SECOND
 if [[ "${DATE_STRING}" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})[[:space:]]([0-9]{2}):([0-9]{2}):([0-9]{2})[[:space:]]UTC$ ]]; then
  YEAR="${BASH_REMATCH[1]}"
  MONTH="${BASH_REMATCH[2]}"
  DAY="${BASH_REMATCH[3]}"
  HOUR="${BASH_REMATCH[4]}"
  MINUTE="${BASH_REMATCH[5]}"
  SECOND="${BASH_REMATCH[6]}"
 else
  __loge "ERROR: ${DESCRIPTION} format parsing failed: ${DATE_STRING}"
  return 1
 fi

 # Check year range
 if [[ $((10#${YEAR})) -lt 1900 ]] || [[ $((10#${YEAR})) -gt 2100 ]]; then
  __loge "ERROR: ${DESCRIPTION} year out of range: ${YEAR}"
  return 1
 fi

 # Check month range
 if [[ $((10#${MONTH})) -lt 1 ]] || [[ $((10#${MONTH})) -gt 12 ]]; then
  __loge "ERROR: ${DESCRIPTION} month out of range: ${MONTH}"
  return 1
 fi

 # Check day range
 if [[ $((10#${DAY})) -lt 1 ]] || [[ $((10#${DAY})) -gt 31 ]]; then
  __loge "ERROR: ${DESCRIPTION} day out of range: ${DAY}"
  return 1
 fi

 # Check hour range
 if [[ $((10#${HOUR})) -lt 0 ]] || [[ $((10#${HOUR})) -gt 23 ]]; then
  __loge "ERROR: ${DESCRIPTION} hour out of range: ${HOUR}"
  return 1
 fi

 # Check minute range
 if [[ $((10#${MINUTE})) -lt 0 ]] || [[ $((10#${MINUTE})) -gt 59 ]]; then
  __loge "ERROR: ${DESCRIPTION} minute out of range: ${MINUTE}"
  return 1
 fi

 # Check second range
 if [[ $((10#${SECOND})) -lt 0 ]] || [[ $((10#${SECOND})) -gt 59 ]]; then
  __loge "ERROR: ${DESCRIPTION} second out of range: ${SECOND}"
  return 1
 fi

 __logt "${DESCRIPTION} validation passed: ${DATE_STRING}"
 return 0
}
