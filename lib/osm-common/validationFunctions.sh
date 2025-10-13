#!/bin/bash

# Validation Functions for OSM-Notes-profile
# This file contains validation functions for various data types.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

# Define version variable
VERSION="2025-08-13"

# shellcheck disable=SC2317,SC2155,SC2034

# Note: This file expects to be sourced after commonFunctions.sh which provides logging functions
# If sourced directly, ensure commonFunctions.sh is loaded first

# Load common functions if not already loaded
# Set SCRIPT_BASE_DIRECTORY if not already set
if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# Don't set LOGGER_UTILITY here - let commonFunctions.sh handle it
# This prevents conflicts with the simple logger implementation

if [[ -z "${__COMMON_FUNCTIONS_LOADED:-}" ]]; then
 # shellcheck disable=SC1091
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh" ]]; then
  # Preserve SCRIPT_BASE_DIRECTORY before loading commonFunctions.sh
  SAVED_SCRIPT_BASE_DIRECTORY="${SCRIPT_BASE_DIRECTORY}"
  source "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh"
  # Restore SCRIPT_BASE_DIRECTORY if it was changed
  if [[ "${SCRIPT_BASE_DIRECTORY}" != "${SAVED_SCRIPT_BASE_DIRECTORY}" ]]; then
   SCRIPT_BASE_DIRECTORY="${SAVED_SCRIPT_BASE_DIRECTORY}"
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
 echo "Version: ${VERSION}"
 exit 1
}

# Validate input file (enhanced version with support for files, directories, and executables)
function __validate_input_file() {
 __log_start
 local FILE_PATH="${1}"
 local DESCRIPTION="${2:-File}"
 local EXPECTED_TYPE="${3:-file}"
 local VALIDATION_ERRORS=()

 # Check if file path is provided
 if [[ -z "${FILE_PATH}" ]]; then
  __loge "ERROR: ${DESCRIPTION} path is empty"
  __log_finish
  return 1
 fi

 # Check if file exists
 if [[ ! -e "${FILE_PATH}" ]]; then
  VALIDATION_ERRORS+=("File does not exist: ${FILE_PATH}")
 fi

 # Check if file is readable (for files)
 if [[ "${EXPECTED_TYPE}" == "file" ]] && [[ -e "${FILE_PATH}" ]]; then
  if [[ ! -f "${FILE_PATH}" ]]; then
   VALIDATION_ERRORS+=("Path is not a file: ${FILE_PATH}")
  elif [[ ! -r "${FILE_PATH}" ]]; then
   VALIDATION_ERRORS+=("File is not readable: ${FILE_PATH}")
  # Note: File emptiness validation is handled by specific validation functions
  # as different file types may have different rules about empty files
  fi
 fi

 # Check if directory is accessible (for directories)
 if [[ "${EXPECTED_TYPE}" == "dir" ]] && [[ -e "${FILE_PATH}" ]]; then
  if [[ ! -d "${FILE_PATH}" ]]; then
   VALIDATION_ERRORS+=("Path is not a directory: ${FILE_PATH}")
  elif [[ ! -r "${FILE_PATH}" ]]; then
   VALIDATION_ERRORS+=("Directory is not readable: ${FILE_PATH}")
  fi
 fi

 # Check if executable is executable
 if [[ "${EXPECTED_TYPE}" == "executable" ]] && [[ -e "${FILE_PATH}" ]]; then
  if [[ ! -x "${FILE_PATH}" ]]; then
   VALIDATION_ERRORS+=("File is not executable: ${FILE_PATH}")
  fi
 fi

 # Report validation errors
 if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
  __loge "ERROR: ${DESCRIPTION} validation failed:"
  for ERROR in "${VALIDATION_ERRORS[@]}"; do
   __loge "  - ${ERROR}"
  done
  __log_finish
  return 1
 fi

 __logi "${DESCRIPTION} validation passed: ${FILE_PATH}"
 __log_finish
 return 0
}

# Validate input files
function __validate_input_files() {
 __log_start
 local FILES=("$@")
 local FAILED=0

 for FILE in "${FILES[@]}"; do
  if ! __validate_input_file "${FILE}" "Input file"; then
   FAILED=1
  fi
 done

 __log_finish
 return "${FAILED}"
}

# Validate XML structure (main implementation)
function __validate_xml_structure() {
 __validate_xml_structure_impl "$@"
}

# Validate XML structure (internal implementation)
function __validate_xml_structure_impl() {
 __log_start
 local XML_FILE="${1}"
 local EXPECTED_ROOT="${2:-}"

 __logi "=== VALIDATING XML STRUCTURE ==="
 __logd "XML file: ${XML_FILE}"

 if ! __validate_input_file "${XML_FILE}" "XML file"; then
  __log_finish
  return 1
 fi

 # For large files, use lightweight validation
 local FILE_SIZE
 FILE_SIZE=$(stat -c%s "${XML_FILE}" 2> /dev/null || echo "0")
 local SIZE_MB=$((FILE_SIZE / 1024 / 1024))

 if [[ "${SIZE_MB}" -gt 500 ]]; then
  __logw "WARNING: Large XML file detected (${SIZE_MB} MB). Using lightweight structure validation."

  # Use lightweight validation for large files
  if ! grep -q "<osm-notes\|<osm>" "${XML_FILE}" 2> /dev/null; then
   __loge "ERROR: Missing expected root element in large XML file: ${XML_FILE}"
   __log_finish
   return 1
  fi
  __logd "Large XML file validation passed: ${XML_FILE}"
  __log_finish
  return 0
 fi

 # Use standard validation for smaller files
 # Lightweight XML validation using grep instead of xmllint
 if ! grep -q '<?xml' "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: XML file does not contain XML declaration: ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Check expected root element if provided
 if [[ -n "${EXPECTED_ROOT}" ]]; then
  if ! grep -q "<${EXPECTED_ROOT}" "${XML_FILE}" 2> /dev/null; then
   __loge "ERROR: Expected root element '${EXPECTED_ROOT}' not found: ${XML_FILE}"
   __log_finish
   return 1
  fi

  # Check for required root element using grep (much faster for large files)
  if ! grep -q "<osm-notes\|<osm>" "${XML_FILE}" 2> /dev/null; then
   __loge "ERROR: Missing osm-notes or osm root element: ${XML_FILE}"
   __log_finish
   return 1
  fi

  # Check for basic XML structure
  if ! grep -q "<?xml\|<osm-notes\|<osm>" "${XML_FILE}" 2> /dev/null; then
   __loge "ERROR: Invalid XML structure (missing XML declaration or root element): ${XML_FILE}"
   __log_finish
   return 1
  fi

  __logi "Lightweight XML structure validation passed: ${XML_FILE}"
  __log_finish
  return 0
 fi

 # Check if file is valid XML using lightweight validation (for smaller files)
 # Check for basic XML structure markers
 if ! grep -q '<?xml' "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: XML file does not contain XML declaration: ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Check for required root element (osm-notes for planet, osm for API)
 if ! grep -q "<osm-notes\|<osm>" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Missing osm-notes or osm root element: ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Check expected root element if provided
 if [[ -n "${EXPECTED_ROOT}" ]]; then
  if ! grep -q "<${EXPECTED_ROOT}" "${XML_FILE}" 2> /dev/null; then
   __loge "ERROR: Expected root element '${EXPECTED_ROOT}' not found: ${XML_FILE}"
   __log_finish
   return 1
  fi
 fi

 __logi "XML structure validation passed: ${XML_FILE}"
 __logi "=== XML STRUCTURE VALIDATION COMPLETED SUCCESSFULLY ==="
 __log_finish
 return 0
}

# Validate CSV structure
function __validate_csv_structure() {
 __log_start
 local CSV_FILE="${1}"
 local EXPECTED_COLUMNS="${2:-}"

 if ! __validate_input_file "${CSV_FILE}" "CSV file"; then
  __log_finish
  return 1
 fi

 # Check if file has content
 if [[ ! -s "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file is empty: ${CSV_FILE}"
  __log_finish
  return 1
 fi

 # Check if file has header
 local FIRST_LINE
 FIRST_LINE=$(head -n 1 "${CSV_FILE}" 2> /dev/null)
 if [[ -z "${FIRST_LINE}" ]]; then
  __loge "ERROR: CSV file has no header: ${CSV_FILE}"
  __log_finish
  return 1
 fi

 # Check column count if expected columns provided
 if [[ -n "${EXPECTED_COLUMNS}" ]]; then
  local COLUMN_COUNT
  COLUMN_COUNT=$(echo "${FIRST_LINE}" | tr ',' '\n' | wc -l)
  local EXPECTED_COUNT

  # Check if EXPECTED_COLUMNS is a number (direct column count)
  if [[ "${EXPECTED_COLUMNS}" =~ ^[0-9]+$ ]]; then
   EXPECTED_COUNT="${EXPECTED_COLUMNS}"
  else
   # EXPECTED_COLUMNS is a comma-separated list of column names
   EXPECTED_COUNT=$(echo "${EXPECTED_COLUMNS}" | tr ',' '\n' | wc -l)
  fi

  if [[ "${COLUMN_COUNT}" -ne "${EXPECTED_COUNT}" ]]; then
   __loge "ERROR: Expected ${EXPECTED_COUNT} columns, got ${COLUMN_COUNT}: ${CSV_FILE}"
   __log_finish
   return 1
  fi
 fi

 __logi "CSV structure validation passed: ${CSV_FILE}"
 __log_finish
 return 0
}

# Validate SQL structure
function __validate_sql_structure() {
 __log_start
 local SQL_FILE="${1}"

 # Basic file validation (but allow empty files for specific SQL validation)
 if [[ ! -f "${SQL_FILE}" ]]; then
  __loge "ERROR: SQL file does not exist: ${SQL_FILE}"
  __log_finish
  return 1
 fi

 if [[ ! -r "${SQL_FILE}" ]]; then
  __loge "ERROR: SQL file is not readable: ${SQL_FILE}"
  __log_finish
  return 1
 fi

 # Check if file is empty
 if [[ ! -s "${SQL_FILE}" ]]; then
  __loge "ERROR: SQL file is empty: ${SQL_FILE}"
  __log_finish
  return 1
 fi

 # Check if file contains only comments (lines starting with -- or /* */)
 # Create a temporary file with non-comment, non-empty lines
 local TEMP_FILE
 TEMP_FILE=$(mktemp)
 grep -v '^[[:space:]]*--' "${SQL_FILE}" | grep -v '^[[:space:]]*$' > "${TEMP_FILE}"

 # If temp file is empty, the original file contains only comments
 if [[ ! -s "${TEMP_FILE}" ]]; then
  rm -f "${TEMP_FILE}"
  __loge "ERROR: No valid SQL statements found: ${SQL_FILE}"
  __log_finish
  return 1
 fi

 rm -f "${TEMP_FILE}"

 # Check for basic SQL syntax (expanded list of SQL keywords)
 if ! grep -q -E "(CREATE|INSERT|UPDATE|DELETE|SELECT|DROP|ALTER|VACUUM|ANALYZE|REINDEX|CLUSTER|TRUNCATE|BEGIN|COMMIT|ROLLBACK|SAVEPOINT|GRANT|REVOKE|EXPLAIN|COPY|IMPORT|EXPORT|LOCK|UNLOCK|SET|RESET|SHOW|DESCRIBE|USE|CONNECT|DISCONNECT)" "${SQL_FILE}"; then
  __loge "ERROR: No valid SQL statements found: ${SQL_FILE}"
  __log_finish
  return 1
 fi

 # Check for balanced parentheses
 local OPEN_PARENS
 local CLOSE_PARENS
 OPEN_PARENS=$(grep -o '(' "${SQL_FILE}" | wc -l)
 CLOSE_PARENS=$(grep -o ')' "${SQL_FILE}" | wc -l)

 if [[ "${OPEN_PARENS}" -ne "${CLOSE_PARENS}" ]]; then
  __loge "ERROR: Unbalanced parentheses in SQL file: ${SQL_FILE}"
  __log_finish
  return 1
 fi

 __logi "SQL structure validation passed: ${SQL_FILE}"
 __log_finish
 return 0
}

# Validate config file
function __validate_config_file() {
 __log_start
 local CONFIG_FILE="${1}"

 if ! __validate_input_file "${CONFIG_FILE}" "Config file"; then
  __log_finish
  return 1
 fi

 # Check for key-value pairs
 if ! grep -q '=' "${CONFIG_FILE}"; then
  __loge "ERROR: No key-value pairs found in config file: ${CONFIG_FILE}"
  __log_finish
  return 1
 fi

 # Check for valid variable names (allow leading spaces)
 if grep -q -E '^[[:space:]]*[^A-Za-z_][^=]*=' "${CONFIG_FILE}"; then
  __loge "ERROR: Invalid variable names in config file: ${CONFIG_FILE}"
  __log_finish
  return 1
 fi

 __logi "Config file validation passed: ${CONFIG_FILE}"
 __log_finish
 return 0
}

# Validate JSON structure
function __validate_json_structure() {
 __log_start
 local JSON_FILE="${1}"
 local SCHEMA_FILE="${2:-}"

 if ! __validate_input_file "${JSON_FILE}" "JSON file"; then
  __log_finish
  return 1
 fi

 # Check if file is valid JSON
 if ! jq empty "${JSON_FILE}" 2> /dev/null; then
  __loge "ERROR: Invalid JSON structure: ${JSON_FILE}"
  __log_finish
  return 1
 fi

 # Validate against schema if provided
 if [[ -n "${SCHEMA_FILE}" ]] && [[ -f "${SCHEMA_FILE}" ]]; then
  if command -v ajv > /dev/null 2>&1; then
   if ! ajv validate -s "${SCHEMA_FILE}" -d "${JSON_FILE}"; then
    __loge "ERROR: JSON validation against schema failed: ${JSON_FILE}"
    __log_finish
    return 1
   fi
  else
   __logw "WARNING: ajv not available, skipping schema validation"
  fi
 fi

 __logd "JSON structure validation passed: ${JSON_FILE}"
 __log_finish
 return 0
}

# Validate database connection
# Nota:
# Por defecto, la conexión a PostgreSQL se realiza usando peer (local, sin usuario/contraseña).
# Los parámetros DBHOST, DBPORT y DBUSER solo son necesarios para pruebas en Docker, CI/CD
# o entornos donde no se use peer.
function __validate_database_connection() {
 __log_start
 local DBNAME_PARAM="${1:-${DBNAME}}"
 local DBUSER_PARAM="${2:-${DB_USER}}"
 local DBHOST_PARAM="${3:-${DB_HOST}}"
 local DBPORT_PARAM="${4:-${DB_PORT}}"

 # Check if database name is provided
 if [[ -z "${DBNAME_PARAM}" ]]; then
  __loge "ERROR: Database name is required"
  __log_finish
  return 1
 fi

 # Check if PostgreSQL client is available
 if ! command -v psql > /dev/null 2>&1; then
  __loge "ERROR: PostgreSQL client (psql) not available"
  __log_finish
  return 1
 fi

 # Test database connection
 if [[ -n "${DBHOST_PARAM}" ]] || [[ -n "${DBPORT_PARAM}" ]] || [[ -n "${DBUSER_PARAM}" ]]; then
  __log_finish
  # Usar parámetros personalizados (por ejemplo, en Docker o CI/CD)
  if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DBHOST_PARAM}" -p "${DBPORT_PARAM}" -U "${DBUSER_PARAM}" -d "${DBNAME_PARAM}" -c "SELECT 1;" > /dev/null 2>&1; then
   __loge "ERROR: Database connection failed (host/port/user)"
   __log_finish
   return 1
  fi
 else
  # Usar peer (local, sin usuario/contraseña)
  if ! psql -d "${DBNAME_PARAM}" -c "SELECT 1;" > /dev/null 2>&1; then
   __loge "ERROR: Database connection failed (peer)"
   __log_finish
   return 1
  fi
 fi

 __logd "Database connection validation passed"
 __log_finish
 return 0
}

# Validate database tables
# Nota:
# Por defecto, la conexión a PostgreSQL se realiza usando peer (local, sin usuario/contraseña).
# Los parámetros DBHOST, DBPORT y DBUSER solo son necesarios para pruebas en Docker, CI/CD
# o entornos donde no se use peer.
function __validate_database_tables() {
 __log_start
 local DBNAME_PARAM="${1:-${DBNAME}}"
 local DBUSER_PARAM="${2:-${DB_USER}}"
 local DBHOST_PARAM="${3:-${DB_HOST}}"
 local DBPORT_PARAM="${4:-${DB_PORT}}"
 local TABLES=("${@:5}")

 # Check if database name is provided
 if [[ -z "${DBNAME_PARAM}" ]]; then
  __loge "ERROR: Database name is required for table validation"
  __log_finish
  return 1
 fi

 # Check if tables are provided for validation
 if [[ ${#TABLES[@]} -eq 0 ]]; then
  __loge "ERROR: No tables specified for validation"
  __log_finish
  return 1
 fi

 if ! __validate_database_connection "${DBNAME_PARAM}" "${DBUSER_PARAM}" "${DBHOST_PARAM}" "${DBPORT_PARAM}"; then
  __log_finish
  return 1
 fi

 for TABLE in "${TABLES[@]}"; do
  if [[ -n "${DBHOST_PARAM}" ]] || [[ -n "${DBPORT_PARAM}" ]] || [[ -n "${DBUSER_PARAM}" ]]; then
   if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DBHOST_PARAM}" -p "${DBPORT_PARAM}" -U "${DBUSER_PARAM}" -d "${DBNAME_PARAM}" -c "SELECT 1 FROM information_schema.tables WHERE table_name = '${TABLE}';" | grep -q "1"; then
    __loge "ERROR: Table ${TABLE} does not exist in database ${DBNAME_PARAM} (host/port/user)"
    __log_finish
    return 1
   fi
  else
   if ! psql -d "${DBNAME_PARAM}" -c "SELECT 1 FROM information_schema.tables WHERE table_name = '${TABLE}';" | grep -q "1"; then
    __loge "ERROR: Table ${TABLE} does not exist in database ${DBNAME_PARAM} (peer)"
    __log_finish
    return 1
   fi
  fi
 done

 __logd "Database tables validation passed"
 __log_finish
 return 0
}

# Validate database extensions
# Nota:
# Por defecto, la conexión a PostgreSQL se realiza usando peer (local, sin usuario/contraseña).
# Los parámetros DBHOST, DBPORT y DBUSER solo son necesarios para pruebas en Docker, CI/CD
# o entornos donde no se use peer.
function __validate_database_extensions() {
 __log_start
 local DBNAME_PARAM="${1:-${DBNAME}}"
 local DBUSER_PARAM="${2:-${DB_USER}}"
 local DBHOST_PARAM="${3:-${DB_HOST}}"
 local DBPORT_PARAM="${4:-${DB_PORT}}"
 local EXTENSIONS=("${@:5}")

 # Check if database name is provided
 if [[ -z "${DBNAME_PARAM}" ]]; then
  __loge "ERROR: Database name is required for extension validation"
  __log_finish
  return 1
 fi

 # Check if extensions are provided for validation
 if [[ ${#EXTENSIONS[@]} -eq 0 ]]; then
  __loge "ERROR: No extensions specified for validation"
  __log_finish
  return 1
 fi

 if ! __validate_database_connection "${DBNAME_PARAM}" "${DBUSER_PARAM}" "${DBHOST_PARAM}" "${DBPORT_PARAM}"; then
  __log_finish
  return 1
 fi

 for EXTENSION in "${EXTENSIONS[@]}"; do
  if [[ -n "${DBHOST_PARAM}" ]] || [[ -n "${DBPORT_PARAM}" ]] || [[ -n "${DBUSER_PARAM}" ]]; then
   if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DBHOST_PARAM}" -p "${DBPORT_PARAM}" -U "${DBUSER_PARAM}" -d "${DBNAME_PARAM}" -c "SELECT 1 FROM pg_extension WHERE extname = '${EXTENSION}';" | grep -q "1"; then
    __loge "ERROR: Extension ${EXTENSION} is not installed in database ${DBNAME_PARAM} (host/port/user)"
    __log_finish
    return 1
   fi
  else
   if ! psql -d "${DBNAME_PARAM}" -c "SELECT 1 FROM pg_extension WHERE extname = '${EXTENSION}';" | grep -q "1"; then
    __loge "ERROR: Extension ${EXTENSION} is not installed in database ${DBNAME_PARAM} (peer)"
    __log_finish
    return 1
   fi
  fi
 done

 __logd "Database extensions validation passed"
 __log_finish
 return 0
}

# Validate ISO8601 date format
function __validate_iso8601_date() {
 __log_start
 local DATE_STRING="${1}"
 local DESCRIPTION="${2:-Date}"

 # Check if date string is not empty
 if [[ -z "${DATE_STRING}" ]]; then
  __loge "ERROR: ${DESCRIPTION} is empty"
  __log_finish
  return 1
 fi

 # Validate ISO8601 format (YYYY-MM-DDTHH:MM:SSZ or YYYY-MM-DDTHH:MM:SS+HH:MM)
 if ! echo "${DATE_STRING}" | grep -q -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(Z|[+-][0-9]{2}:[0-9]{2})$'; then
  __loge "ERROR: Invalid ISO8601 date format: ${DATE_STRING}"
  __log_finish
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

 # Convert to base 10 to handle leading zeros properly
 YEAR=$((10#${YEAR}))
 MONTH=$((10#${MONTH}))
 DAY=$((10#${DAY}))
 HOUR=$((10#${HOUR}))
 MINUTE=$((10#${MINUTE}))
 SECOND=$((10#${SECOND}))

 # Validate ranges
 if [[ "${YEAR}" -lt 1900 ]] || [[ "${YEAR}" -gt 2100 ]]; then
  __loge "ERROR: Invalid year: ${YEAR}"
  __log_finish
  return 1
 fi

 if [[ "${MONTH}" -lt 1 ]] || [[ "${MONTH}" -gt 12 ]]; then
  __loge "ERROR: Invalid month: ${MONTH}"
  __log_finish
  return 1
 fi

 if [[ "${DAY}" -lt 1 ]] || [[ "${DAY}" -gt 31 ]]; then
  __loge "ERROR: Invalid day: ${DAY}"
  __log_finish
  return 1
 fi

 if [[ "${HOUR}" -lt 0 ]] || [[ "${HOUR}" -gt 23 ]]; then
  __loge "ERROR: Invalid hour: ${HOUR}"
  __log_finish
  return 1
 fi

 if [[ "${MINUTE}" -lt 0 ]] || [[ "${MINUTE}" -gt 59 ]]; then
  __loge "ERROR: Invalid minute: ${MINUTE}"
  __log_finish
  return 1
 fi

 if [[ "${SECOND}" -lt 0 ]] || [[ "${SECOND}" -gt 59 ]]; then
  __loge "ERROR: Invalid second: ${SECOND}"
  __log_finish
  return 1
 fi
 __logd "ISO8601 date validation passed: ${DATE_STRING}"
 __log_finish
 return 0
}

# Validate XML dates (lightweight version for large files)
function __validate_xml_dates() {
 __log_start
 local XML_FILE="${1}"
 local XPATH_QUERIES=("${@:2}")
 local STRICT_MODE="${STRICT_MODE:-false}" # New parameter for strict validation

 # For large files, use lightweight validation
 local FILE_SIZE
 FILE_SIZE=$(stat -c%s "${XML_FILE}" 2> /dev/null || echo "0")
 local SIZE_MB=$((FILE_SIZE / 1024 / 1024))

 # If file is larger than 500MB, use lightweight validation
 if [[ "${SIZE_MB}" -gt 500 ]]; then
  __logw "WARNING: Large XML file detected (${SIZE_MB} MB). Using lightweight date validation."
  __validate_xml_dates_lightweight "${XML_FILE}" "${XPATH_QUERIES[@]}" "${STRICT_MODE}"
  local LIGHTWEIGHT_RESULT=$?
  __log_finish
  return "${LIGHTWEIGHT_RESULT}"
 fi

 # For smaller files, use standard validation
 if ! __validate_xml_structure "${XML_FILE}"; then
  __log_finish
  return 1
 fi

 local FAILED=0

 # Validate dates in XML
 for XPATH_QUERY in "${XPATH_QUERIES[@]}"; do
  local ALL_DATES_RAW
  # Extract all date values using grep instead of xmllint (more reliable)
  # Convert XPath query to grep pattern for lightweight extraction
  local GREP_PATTERN
  case "${XPATH_QUERY}" in
  "//note/@created_at")
   GREP_PATTERN='created_at="[^"]*"'
   ;;
  "//note/@closed_at")
   GREP_PATTERN='closed_at="[^"]*"'
   ;;
  "//note/@updated_at")
   GREP_PATTERN='updated_at="[^"]*"'
   ;;
  *)
   # Default pattern for general date extraction
   GREP_PATTERN='[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'
   ;;
  esac

  ALL_DATES_RAW=$(grep -oE "${GREP_PATTERN}" "${XML_FILE}" 2> /dev/null || true)

  if [[ -n "${ALL_DATES_RAW}" ]]; then
   # Extract date values from attributes and elements
   local EXTRACTED_DATES
   EXTRACTED_DATES=$(echo "${ALL_DATES_RAW}" | grep -oE '="[^"]*"' | sed 's/="//g' | sed 's/"//g' || true)
   if [[ -z "${EXTRACTED_DATES}" ]]; then
    # If no attributes found, try to extract element text content
    EXTRACTED_DATES=$(echo "${ALL_DATES_RAW}" | grep -oE '>[^<]*<' | sed 's/>//g' | sed 's/<//g' || true)
   fi

   if [[ -n "${EXTRACTED_DATES}" ]]; then
    # Limit the number of dates to validate to avoid memory issues
    local DATE_COUNT=0
    local MAX_DATES=1000

    while IFS= read -r DATE; do
     [[ -z "${DATE}" ]] && continue

     # Limit validation to first MAX_DATES dates
     if [[ "${DATE_COUNT}" -ge "${MAX_DATES}" ]]; then
      __logw "WARNING: Limiting date validation to first ${MAX_DATES} dates for performance"
      break
     fi

     DATE_COUNT=$((DATE_COUNT + 1))

     # Validate ISO 8601 dates (YYYY-MM-DDTHH:MM:SSZ)
     if [[ "${DATE}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
      if ! __validate_iso8601_date "${DATE}" "XML date"; then
       __loge "ERROR: Invalid ISO8601 date found in XML: ${DATE}"
       FAILED=1
       # In strict mode, fail immediately
       if [[ "${STRICT_MODE}" == "true" ]]; then
        __log_finish
        return 1
       fi
      fi
     # Validate UTC dates (YYYY-MM-DD HH:MM:SS UTC)
     elif [[ "${DATE}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]UTC$ ]]; then
      if ! __validate_date_format_utc "${DATE}" "XML date"; then
       __loge "ERROR: Invalid UTC date found in XML: ${DATE}"
       FAILED=1
       # In strict mode, fail immediately
       if [[ "${STRICT_MODE}" == "true" ]]; then
        __log_finish
        return 1
       fi
      fi
     else
      # Check if this looks like it should be a date but isn't in the expected format
      if [[ "${DATE}" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
       __logw "WARNING: Unexpected date format found in XML: ${DATE}"
      elif [[ "${DATE}" =~ [0-9]{4}.*[0-9]{2}.*[0-9]{2} ]] || [[ "${DATE}" =~ [a-zA-Z]+-?[a-zA-Z]+ ]]; then
       # This looks like it might be a malformed date (contains date-like patterns or letters)
       __loge "ERROR: Malformed date found in XML: ${DATE}"
       FAILED=1
       # In strict mode, fail immediately
       if [[ "${STRICT_MODE}" == "true" ]]; then
        __log_finish
        return 1
       fi
      fi
     fi
    done <<< "${EXTRACTED_DATES}"
   fi
  fi

  # In strict mode, also check for invalid date patterns that might not match the grep pattern
  if [[ "${STRICT_MODE}" == "true" ]]; then
   # Look for any attribute that looks like it should be a date but isn't
   local INVALID_DATE_PATTERNS=(
    'created_at="[^"]*[a-zA-Z][^"]*"'
    'closed_at="[^"]*[a-zA-Z][^"]*"'
    'timestamp="[^"]*[a-zA-Z][^"]*"'
   )

   for PATTERN in "${INVALID_DATE_PATTERNS[@]}"; do
    local INVALID_DATES
    INVALID_DATES=$(grep -oE "${PATTERN}" "${XML_FILE}" 2> /dev/null || true)

    if [[ -n "${INVALID_DATES}" ]]; then
     __loge "ERROR: Invalid date patterns found in strict mode: ${INVALID_DATES}"
     __log_finish
     return 1
    fi
   done
  fi
 done

 if [[ "${FAILED}" -eq 1 ]]; then
  __log_finish
  return 1
 fi

 # Only log in trace mode to reduce verbosity
 if [[ "${LOG_LEVEL:-}" == "TRACE" ]]; then
  __logd "XML dates validation passed: ${XML_FILE}"
 fi
 __log_finish
 return 0
}

# Lightweight XML date validation for large files
function __validate_xml_dates_lightweight() {
 __log_start
 local XML_FILE="${1}"
 local XPATH_QUERIES=("${@:2}")
 local STRICT_MODE="${3:-false}" # Get STRICT_MODE from __validate_xml_dates

 __logd "Using lightweight XML date validation for large file: ${XML_FILE}"

 # For large files, just check a sample of dates using grep
 local FAILED=0
 local SAMPLE_SIZE=100

 # Extract a sample of dates using grep (much faster than xmllint for large files)
 local SAMPLE_DATES
 SAMPLE_DATES=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' "${XML_FILE}" | head -n "${SAMPLE_SIZE}" || true)

 # Also check for malformed dates that might cause issues (dates with letters or invalid characters)
 local MALFORMED_DATES
 MALFORMED_DATES=$(grep -oE '[0-9]{4}-[0-9]*[a-zA-Z][0-9a-zA-Z]*-[0-9]*[a-zA-Z][0-9a-zA-Z]*T[0-9]*[a-zA-Z][0-9a-zA-Z]*:[0-9]*[a-zA-Z][0-9a-zA-Z]*:[0-9]*[a-zA-Z][0-9a-zA-Z]*Z' "${XML_FILE}" | head -n "${SAMPLE_SIZE}" || true)

 if [[ -n "${MALFORMED_DATES}" ]]; then
  __loge "ERROR: Malformed dates found in XML (contains invalid characters):"
  while IFS= read -r DATE; do
   [[ -z "${DATE}" ]] && continue
   __loge "  - ${DATE}"
   FAILED=1
   # In strict mode, fail immediately
   if [[ "${STRICT_MODE}" == "true" ]]; then
    __log_finish
    return 1
   fi
  done <<< "${MALFORMED_DATES}"
 fi

 if [[ -n "${SAMPLE_DATES}" ]]; then
  local VALID_COUNT=0
  local TOTAL_COUNT=0

  while IFS= read -r DATE; do
   [[ -z "${DATE}" ]] && continue
   TOTAL_COUNT=$((TOTAL_COUNT + 1))

   # Quick validation of ISO 8601 format
   if [[ "${DATE}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    # Basic validation without calling __validate_iso8601_date for performance
    local YEAR="${DATE:0:4}"
    local MONTH="${DATE:5:2}"
    local DAY="${DATE:8:2}"
    local HOUR="${DATE:11:2}"
    local MINUTE="${DATE:14:2}"
    local SECOND="${DATE:17:2}"

    # Convert to base 10 to handle leading zeros properly
    YEAR=$((10#${YEAR}))
    MONTH=$((10#${MONTH}))
    DAY=$((10#${DAY}))
    HOUR=$((10#${HOUR}))
    MINUTE=$((10#${MINUTE}))
    SECOND=$((10#${SECOND}))

    # Basic range validation
    if [[ "${YEAR}" -ge 2000 && "${YEAR}" -le 2030 ]] \
     && [[ "${MONTH}" -ge 1 && "${MONTH}" -le 12 ]] \
     && [[ "${DAY}" -ge 1 && "${DAY}" -le 31 ]] \
     && [[ "${HOUR}" -ge 0 && "${HOUR}" -le 23 ]] \
     && [[ "${MINUTE}" -ge 0 && "${MINUTE}" -le 59 ]] \
     && [[ "${SECOND}" -ge 0 && "${SECOND}" -le 59 ]]; then
     VALID_COUNT=$((VALID_COUNT + 1))
    else
     __logw "WARNING: Invalid date format found in sample: ${DATE}"
     FAILED=1
     # In strict mode, fail immediately
     if [[ "${STRICT_MODE}" == "true" ]]; then
      __log_finish
      return 1
     fi
    fi
   else
    __logw "WARNING: Unexpected date format found in sample: ${DATE}"
    FAILED=1
    # In strict mode, fail immediately
    if [[ "${STRICT_MODE}" == "true" ]]; then
     __log_finish
     return 1
    fi
   fi
  done <<< "${SAMPLE_DATES}"

  if [[ "${TOTAL_COUNT}" -gt 0 ]]; then
   local VALID_PERCENTAGE=$((VALID_COUNT * 100 / TOTAL_COUNT))
   __logd "Date validation sample: ${VALID_COUNT}/${TOTAL_COUNT} valid dates (${VALID_PERCENTAGE}%)"

   # If more than 90% of dates are valid, consider the file valid
   if [[ "${VALID_PERCENTAGE}" -ge 90 ]]; then
    __logd "XML dates validation passed (sample-based): ${XML_FILE}"
    # Still check if there were malformed dates
    if [[ "${FAILED}" -eq 1 ]]; then
     __log_finish
     return 1
    fi
    __log_finish
    return 0
   else
    __loge "ERROR: Too many invalid dates found in sample (${VALID_PERCENTAGE}% valid)"
    __log_finish
    return 1
   fi
  fi
 fi

 # If no dates found, consider it valid (might be a file without dates)
 __logd "No dates found in XML file, skipping date validation: ${XML_FILE}"
 # Still check if there were malformed dates
 if [[ "${FAILED}" -eq 1 ]]; then
  __log_finish
  return 1
 fi
 __log_finish
 return 0
}

# Validate CSV dates
function __validate_csv_dates() {
 local CSV_FILE="${1}"
 local DATE_COLUMNS=("${@:2}")

 if ! __validate_csv_structure "${CSV_FILE}"; then
  __log_finish
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
    # Skip empty dates
    [[ -z "${DATE}" ]] && continue
    # Skip dates that don't match the expected pattern
    if [[ ! "${DATE}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
     continue
    fi
    if ! __validate_date_format "${DATE}" "CSV date"; then
     __loge "ERROR: Invalid date found in CSV: ${DATE}"
     FAILED=1
    fi
   done <<< "${DATES}"
  fi
 done

 if [[ "${FAILED}" -eq 1 ]]; then
  __log_finish
  return 1
 fi

 __logi "CSV dates validation passed: ${CSV_FILE}"
 __log_finish
 return 0
}

# Validate file checksum
function __validate_file_checksum() {
 __log_start
 local FILE_PATH="${1}"
 local EXPECTED_CHECKSUM="${2}"
 local ALGORITHM="${3:-sha256}"

 # Check for empty checksum
 if [[ -z "${EXPECTED_CHECKSUM}" ]]; then
  __loge "ERROR: Expected checksum is empty"
  __log_finish
  return 1
 fi

 if ! __validate_input_file "${FILE_PATH}" "File for checksum validation"; then
  __log_finish
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
  __loge "ERROR: ${ALGORITHM} checksum validation failed - Invalid algorithm"
  __log_finish
  return 1
  ;;
 esac

 # Compare checksums
 if [[ "${ACTUAL_CHECKSUM}" != "${EXPECTED_CHECKSUM}" ]]; then
  __loge "ERROR: ${ALGORITHM} checksum validation failed - Checksum mismatch for ${FILE_PATH}. Expected: ${EXPECTED_CHECKSUM}, Actual: ${ACTUAL_CHECKSUM}"
  __log_finish
  return 1
 fi

 __logd "${ALGORITHM} checksum validation passed"
 __log_finish
 return 0
}

# Validate file checksum from file
function __validate_file_checksum_from_file() {
 __log_start
 local FILE_PATH="${1}"
 local CHECKSUM_FILE="${2}"
 local ALGORITHM="${3:-sha256}"

 if ! __validate_input_file "${FILE_PATH}" "File"; then
  __log_finish
  return 1
 fi

 # Check if checksum file exists and is readable, but allow empty files
 if [[ ! -f "${CHECKSUM_FILE}" ]]; then
  __loge "ERROR: Checksum file not found: ${CHECKSUM_FILE}"
  __log_finish
  return 1
 fi

 if [[ ! -r "${CHECKSUM_FILE}" ]]; then
  __loge "ERROR: Checksum file not readable: ${CHECKSUM_FILE}"
  __log_finish
  return 1
 fi

 # Extract expected checksum from checksum file
 local EXPECTED_CHECKSUM
 local FILENAME
 FILENAME=$(basename "${FILE_PATH}")

 # First try to find checksum by filename
 EXPECTED_CHECKSUM=$(grep "${FILENAME}" "${CHECKSUM_FILE}" | awk '{print $1}' 2> /dev/null)

 # If not found by filename, assume single-line checksum file and take first field
 if [[ -z "${EXPECTED_CHECKSUM}" ]]; then
  __logw "Checksum not found by filename, trying to extract from single-line file"
  EXPECTED_CHECKSUM=$(head -1 "${CHECKSUM_FILE}" | awk '{print $1}' 2> /dev/null)
 fi

 if [[ -z "${EXPECTED_CHECKSUM}" ]]; then
  __loge "ERROR: Could not extract checksum from file: ${CHECKSUM_FILE}"
  __log_finish
  return 1
 fi

 # Validate checksum
 if ! __validate_file_checksum "${FILE_PATH}" "${EXPECTED_CHECKSUM}" "${ALGORITHM}"; then
  __log_finish
  return 1
 fi

 return 0
}

# Generate file checksum
function __generate_file_checksum() {
 __log_start
 local FILE_PATH="${1}"
 local ALGORITHM="${2:-sha256}"
 local OUTPUT_FILE="${3:-}"

 if ! __validate_input_file "${FILE_PATH}" "File for checksum generation"; then
  __log_finish
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
  __log_finish
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
 __log_finish
 return 0
}

# Validate directory checksums
function __validate_directory_checksums() {
 __log_start
 local DIRECTORY="${1}"
 local CHECKSUM_FILE="${2}"
 local ALGORITHM="${3:-sha256}"

 if [[ ! -d "${DIRECTORY}" ]]; then
  __loge "ERROR: Directory validation failed"
  __log_finish
  return 1
 fi

 if ! __validate_input_file "${CHECKSUM_FILE}" "Checksum file"; then
  __log_finish
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
  __log_finish
  return 1
 fi

 __logd "Directory checksum validation passed"
 __log_finish
 return 0
}

# Validate JSON schema
function __validate_json_schema() {
 __log_start
 local JSON_FILE="${1}"
 local SCHEMA_FILE="${2}"

 if ! __validate_input_file "${JSON_FILE}" "JSON file"; then
  __log_finish
  return 1
 fi

 if ! __validate_input_file "${SCHEMA_FILE}" "JSON schema file"; then
  __log_finish
  return 1
 fi

 # Check if ajv is available
 if ! command -v ajv > /dev/null 2>&1; then
  __loge "ERROR: ajv (JSON schema validator) not available"
  __log_finish
  return 1
 fi

 # Validate JSON against schema
 if ! ajv validate -s "${SCHEMA_FILE}" -d "${JSON_FILE}"; then
  __loge "ERROR: JSON schema validation failed: ${JSON_FILE}"
  __log_finish
  return 1
 fi

 __logd "JSON schema validation passed: ${JSON_FILE}"
 __log_finish
 return 0
}

# Validate coordinates (enhanced version with precision control and better error reporting)
function __validate_coordinates() {
 __log_start
 local LATITUDE="${1}"
 local LONGITUDE="${2}"
 local PRECISION="${3:-7}"
 local VALIDATION_ERRORS=()

 # Check if values are numeric
 if ! [[ "${LATITUDE}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  VALIDATION_ERRORS+=("Latitude '${LATITUDE}' is not a valid number")
 fi

 if ! [[ "${LONGITUDE}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  VALIDATION_ERRORS+=("Longitude '${LONGITUDE}' is not a valid number")
 fi

 # Check latitude range (-90 to 90)
 if [[ "${LATITUDE}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  if (($(echo "${LATITUDE} < -90" | bc -l 2> /dev/null || echo "0"))) || (($(echo "${LATITUDE} > 90" | bc -l 2> /dev/null || echo "0"))); then
   VALIDATION_ERRORS+=("Latitude '${LATITUDE}' is outside valid range (-90 to 90)")
  fi
 fi

 # Check longitude range (-180 to 180)
 if [[ "${LONGITUDE}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  if (($(echo "${LONGITUDE} < -180" | bc -l 2> /dev/null || echo "0"))) || (($(echo "${LONGITUDE} > 180" | bc -l 2> /dev/null || echo "0"))); then
   VALIDATION_ERRORS+=("Longitude '${LONGITUDE}' is outside valid range (-180 to 180)")
  fi
 fi

 # Check precision if bc is available (only if precision is explicitly specified and < 7)
 if command -v bc > /dev/null 2>&1 && [[ "${3:-}" != "" ]] && [[ "${PRECISION}" -lt 7 ]]; then
  if [[ "${LATITUDE}" =~ \.[0-9]{$((PRECISION + 1)),} ]]; then
   VALIDATION_ERRORS+=("Latitude '${LATITUDE}' has too many decimal places (max ${PRECISION})")
  fi

  if [[ "${LONGITUDE}" =~ \.[0-9]{$((PRECISION + 1)),} ]]; then
   VALIDATION_ERRORS+=("Longitude '${LONGITUDE}' has too many decimal places (max ${PRECISION})")
  fi
 fi

 # Report validation errors
 if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
  __loge "ERROR: Coordinate validation failed:"
  for ERROR in "${VALIDATION_ERRORS[@]}"; do
   __loge "  - ${ERROR}"
  done
  __log_finish
  return 1
 fi

 # Only log in trace mode to reduce verbosity
 if [[ "${LOG_LEVEL:-}" == "TRACE" ]]; then
  __logd "Coordinate validation passed: lat=${LATITUDE}, lon=${LONGITUDE}"
 fi
 __log_finish
 return 0
}

# Validate numeric range
function __validate_numeric_range() {
 __log_start
 local VALUE="${1}"
 local MIN="${2}"
 local MAX="${3}"
 local DESCRIPTION="${4:-Value}"

 # Check if value is numeric
 if ! [[ "${VALUE}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  __loge "ERROR: Invalid numeric format: ${VALUE}"
  __log_finish
  return 1
 fi

 # Validate range
 if (($(echo "${VALUE} < ${MIN}" | bc -l 2> /dev/null || echo "0"))) || (($(echo "${VALUE} > ${MAX}" | bc -l 2> /dev/null || echo "0"))); then
  __loge "ERROR: ${DESCRIPTION} out of range (${MIN} to ${MAX}): ${VALUE}"
  __log_finish
  return 1
 fi

 # Only log in trace mode to reduce verbosity
 if [[ "${LOG_LEVEL:-}" == "TRACE" ]]; then
  __logd "Numeric range validation passed: ${VALUE}"
 fi
 __log_finish
 return 0
}

# Validate string pattern
function __validate_string_pattern() {
 __log_start
 local STRING="${1}"
 local PATTERN="${2}"
 local DESCRIPTION="${3:-String}"

 if [[ ! "${STRING}" =~ ${PATTERN} ]]; then
  __loge "ERROR: ${DESCRIPTION} does not match pattern: ${STRING}"
  __log_finish
  return 1
 fi

 # Only log in trace mode to reduce verbosity
 if [[ "${LOG_LEVEL:-}" == "TRACE" ]]; then
  __logd "String pattern validation passed: ${STRING}"
 fi
 __log_finish
 return 0
}

# Validate XML coordinates - This function has been moved to functionsProcess.sh
# to avoid duplication and use the more advanced implementation.
# Use the function from functionsProcess.sh instead.

# Validate CSV coordinates
function __validate_csv_coordinates() {
 __log_start
 local CSV_FILE="${1}"
 local LAT_COLUMN="${2:-lat}"
 local LON_COLUMN="${3:-lon}"

 if ! __validate_input_file "${CSV_FILE}" "CSV file"; then
  __log_finish
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
  __log_finish
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
  __log_finish
  return 1
 fi

 # Only log in trace mode to reduce verbosity
 if [[ "${LOG_LEVEL:-}" == "TRACE" ]]; then
  __logd "CSV coordinate validation passed: ${CSV_FILE}"
 fi
 __log_finish
 return 0
}

# Validate database variables
function __validate_database_variables() {
 __log_start
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
  __log_finish
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
   __log_finish
   return 1
  fi
 fi
 __log_finish

 __logd "Database variable validation passed"
 return 0
}

# Validate date format
function __validate_date_format() {
 __log_start
 local DATE_STRING="${1}"
 local DESCRIPTION="${2:-Date}"

 if [[ -z "${DATE_STRING}" ]]; then
  __loge "ERROR: ${DESCRIPTION} is empty"
  __log_finish
  return 1
 fi

 # Check if date string matches ISO 8601 format
 if ! [[ "${DATE_STRING}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
  __loge "ERROR: ${DESCRIPTION} does not match ISO 8601 format: ${DATE_STRING}"
  __log_finish
  return 1
 fi

 # Validate date components using regex
 local YEAR MONTH DAY HOUR MINUTE SECOND
 if [[ "${DATE_STRING}" =~ ^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})Z$ ]]; then
  YEAR="${BASH_REMATCH[1]}"
  MONTH="${BASH_REMATCH[2]}"
  DAY="${BASH_REMATCH[3]}"
  HOUR="${BASH_REMATCH[4]}"
  MINUTE="${BASH_REMATCH[5]}"
  SECOND="${BASH_REMATCH[6]}"
 else
  __loge "ERROR: ${DESCRIPTION} format parsing failed: ${DATE_STRING}"
  __log_finish
  return 1
 fi

 # Check year range
 if [[ $((10#${YEAR})) -lt 1900 ]] || [[ $((10#${YEAR})) -gt 2100 ]]; then
  __loge "ERROR: ${DESCRIPTION} year out of range: ${YEAR}"
  __log_finish
  return 1
 fi

 # Check month range
 if [[ $((10#${MONTH})) -lt 1 ]] || [[ $((10#${MONTH})) -gt 12 ]]; then
  __loge "ERROR: ${DESCRIPTION} month out of range: ${MONTH}"
  __log_finish
  return 1
 fi

 # Check day range
 if [[ $((10#${DAY})) -lt 1 ]] || [[ $((10#${DAY})) -gt 31 ]]; then
  __loge "ERROR: ${DESCRIPTION} day out of range: ${DAY}"
  __log_finish
  return 1
 fi

 # Check hour range
 if [[ $((10#${HOUR})) -lt 0 ]] || [[ $((10#${HOUR})) -gt 23 ]]; then
  __loge "ERROR: ${DESCRIPTION} hour out of range: ${HOUR}"
  __log_finish
  return 1
 fi

 # Check minute range
 if [[ $((10#${MINUTE})) -lt 0 ]] || [[ $((10#${MINUTE})) -gt 59 ]]; then
  __loge "ERROR: ${DESCRIPTION} minute out of range: ${MINUTE}"
  __log_finish
  return 1
 fi

 # Check second range
 if [[ $((10#${SECOND})) -lt 0 ]] || [[ $((10#${SECOND})) -gt 59 ]]; then
  __loge "ERROR: ${DESCRIPTION} second out of range: ${SECOND}"
  __log_finish
  return 1
 fi

 # Only log in trace mode to reduce verbosity
 if [[ "${LOG_LEVEL:-}" == "TRACE" ]]; then
  __logd "${DESCRIPTION} validation passed: ${DATE_STRING}"
 fi
 __log_finish
 return 0
}

# Validate date format with UTC timezone
function __validate_date_format_utc() {
 __log_start
 local DATE_STRING="${1}"
 local DESCRIPTION="${2:-Date}"

 if [[ -z "${DATE_STRING}" ]]; then
  __loge "ERROR: ${DESCRIPTION} is empty"
  __log_finish
  return 1
 fi

 # Check if date string matches format: YYYY-MM-DD HH:MM:SS UTC
 if ! [[ "${DATE_STRING}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]UTC$ ]]; then
  __loge "ERROR: ${DESCRIPTION} does not match UTC format: ${DATE_STRING}"
  __log_finish
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
  __log_finish
  return 1
 fi

 # Check year range
 if [[ $((10#${YEAR})) -lt 1900 ]] || [[ $((10#${YEAR})) -gt 2100 ]]; then
  __loge "ERROR: ${DESCRIPTION} year out of range: ${YEAR}"
  __log_finish
  return 1
 fi

 # Check month range
 if [[ $((10#${MONTH})) -lt 1 ]] || [[ $((10#${MONTH})) -gt 12 ]]; then
  __loge "ERROR: ${DESCRIPTION} month out of range: ${MONTH}"
  __log_finish
  return 1
 fi

 # Check day range
 if [[ $((10#${DAY})) -lt 1 ]] || [[ $((10#${DAY})) -gt 31 ]]; then
  __loge "ERROR: ${DESCRIPTION} day out of range: ${DAY}"
  __log_finish
  return 1
 fi

 # Check hour range
 if [[ $((10#${HOUR})) -lt 0 ]] || [[ $((10#${HOUR})) -gt 23 ]]; then
  __loge "ERROR: ${DESCRIPTION} hour out of range: ${HOUR}"
  __log_finish
  return 1
 fi

 # Check minute range
 if [[ $((10#${MINUTE})) -lt 0 ]] || [[ $((10#${MINUTE})) -gt 59 ]]; then
  __loge "ERROR: ${DESCRIPTION} minute out of range: ${MINUTE}"
  __log_finish
  return 1
 fi

 # Check second range
 if [[ $((10#${SECOND})) -lt 0 ]] || [[ $((10#${SECOND})) -gt 59 ]]; then
  __loge "ERROR: ${DESCRIPTION} second out of range: ${SECOND}"
  __log_finish
  return 1
 fi

 __logt "${DESCRIPTION} validation passed: ${DATE_STRING}"
 __log_finish
 return 0
}
