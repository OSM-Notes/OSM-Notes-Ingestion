#!/bin/bash
# Consolidated Validation Functions for OSM-Notes-profile
# This file consolidates all validation functions to eliminate duplication
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27
# Description: Centralized validation functions for better maintainability

# Common help function for library files
function __show_help_library() {
 local script_name="${1:-Unknown Script}"
 local description="${2:-No description available}"
 local functions_list="${3:-}"
 local version="${4:-${VERSION:-Unknown}}"

 echo "${script_name}"
 echo "${description}"
 echo
 echo "Usage: source bin/$(basename "${BASH_SOURCE[0]}")"
 echo
 if [[ -n "${functions_list}" ]]; then
  echo "Available functions:"
  echo -e "${functions_list}"
  echo
 fi
 echo "Author: Andres Gomez (AngocA)"
 echo "Version: ${version}"
 exit "${ERROR_HELP_MESSAGE:-1}"
}

# =====================================================
# XML Validation Functions (Consolidated)
# =====================================================

# Enhanced XML validation with comprehensive error handling
# Parameters:
#   $1: XML file path
#   $2: Schema file path (optional)
#   $3: Timeout in seconds (optional, default: 300)
# Returns: 0 if validation passes, 1 if validation fails
function __validate_xml_with_enhanced_error_handling() {
 local XML_FILE="${1}"
 local SCHEMA_FILE="${2:-}"
 local TIMEOUT="${3:-300}"

 # File size thresholds for different validation strategies
 local LARGE_FILE_THRESHOLD=100      # MB
 local VERY_LARGE_FILE_THRESHOLD=500 # MB

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 # Check file size
 local SIZE_BYTES
 SIZE_BYTES=$(stat -c%s "${XML_FILE}" 2> /dev/null || stat -f%z "${XML_FILE}" 2> /dev/null || echo "0")
 local SIZE_MB
 SIZE_MB=$((SIZE_BYTES / 1024 / 1024))

 # Check if it's a planet file (contains 'planet' in name)
 local IS_PLANET_FILE=false
 if [[ "${XML_FILE}" =~ planet ]]; then
  IS_PLANET_FILE=true
 fi

 __logi "Validating XML file: ${XML_FILE} (${SIZE_MB} MB)"

 # For very large files, use basic structure validation only
 if [[ "${SIZE_MB}" -gt "${VERY_LARGE_FILE_THRESHOLD}" ]]; then
  __logw "WARNING: Very large XML file detected (${SIZE_MB} MB). Using structure-only validation."

  if __validate_xml_structure_only "${XML_FILE}"; then
   __logi "Structure-only validation succeeded for very large file"
   return 0
  else
   __loge "ERROR: Structure-only validation failed"
   return 1
  fi
 elif [[ "${SIZE_MB}" -gt "${LARGE_FILE_THRESHOLD}" ]] || [[ "${IS_PLANET_FILE}" == true ]]; then
  __logw "WARNING: Large XML file or Planet file detected (${SIZE_MB} MB). Using basic validation."

  # For large files or planet files, use basic XML validation without schema
  if __validate_xml_basic "${XML_FILE}"; then
   __logi "Basic XML validation succeeded"
   return 0
  else
   __loge "ERROR: Basic XML validation failed"
   return 1
  fi
 else
  # Standard validation for smaller files (non-planet)
  if [[ -n "${SCHEMA_FILE}" ]] && [[ -f "${SCHEMA_FILE}" ]]; then
   local XMLLINT_OUTPUT
   XMLLINT_OUTPUT=$(timeout "${TIMEOUT}" xmllint --noout --schema "${SCHEMA_FILE}" "${XML_FILE}" 2>&1)
   local EXIT_CODE=$?
   if [[ ${EXIT_CODE} -eq 0 ]]; then
    __logi "XML validation succeeded"
    return 0
   else
    __loge "ERROR: XML schema validation failed - xmllint output: ${XMLLINT_OUTPUT}"
    return 1
   fi
  else
   # Fallback to basic validation if no schema provided
   if __validate_xml_basic "${XML_FILE}"; then
    __logi "Basic XML validation succeeded"
    return 0
   else
    __loge "ERROR: Basic XML validation failed"
    return 1
   fi
  fi
 fi
}

# Basic XML structure validation (lightweight)
# Parameters:
#   $1: XML file path
# Returns: 0 if validation passes, 1 if validation fails
function __validate_xml_basic() {
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 __logi "Performing basic XML validation: ${XML_FILE}"

 # Check basic XML structure using xmllint without schema
 local XMLLINT_OUTPUT
 if ! timeout 120 xmllint --noout --nonet "${XML_FILE}" 2>&1; then
  XMLLINT_OUTPUT=$(timeout 120 xmllint --noout --nonet "${XML_FILE}" 2>&1)
  __loge "ERROR: Basic XML structure validation failed - xmllint output: ${XMLLINT_OUTPUT}"
  return 1
 fi

 __logi "Basic XML validation succeeded"
 return 0
}

# XML structure-only validation (very lightweight)
# Parameters:
#   $1: XML file path
# Returns: 0 if validation passes, 1 if validation fails
function __validate_xml_structure_only() {
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 __logi "Performing structure-only XML validation: ${XML_FILE}"

 # Check if file contains basic XML structure markers
 if grep -q '<?xml' "${XML_FILE}" && grep -q '<osm' "${XML_FILE}"; then
  __logi "Structure-only XML validation succeeded"
  return 0
 else
  __loge "ERROR: Structure-only XML validation failed - missing XML structure markers"
  return 1
 fi
}

# Validate XML structure (generic implementation)
# Parameters:
#   $1: XML file path
# Returns: 0 if validation passes, 1 if validation fails
function __validate_xml_structure() {
 __validate_xml_basic "${1}"
}

# Validate XML structure implementation (alias for compatibility)
# Parameters:
#   $1: XML file path
# Returns: 0 if validation passes, 1 if validation fails
function __validate_xml_structure_impl() {
 __validate_xml_basic "${1}"
}

# =====================================================
# CSV Validation Functions (Consolidated)
# =====================================================

# Validate CSV for enum compatibility
# Parameters:
#   $1: CSV file path
#   $2: Column index to validate (optional, default: 0)
# Returns: 0 if validation passes, 1 if validation fails
function __validate_csv_for_enum_compatibility() {
 local CSV_FILE="${1}"
 local COLUMN_INDEX="${2:-0}"

 if [[ ! -f "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file not found: ${CSV_FILE}"
  return 1
 fi

 __logi "Validating CSV enum compatibility: ${CSV_FILE}, column ${COLUMN_INDEX}"

 # Check if CSV has content
 if [[ ! -s "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file is empty: ${CSV_FILE}"
  return 1
 fi

 # Validate column index
 local FIRST_LINE
 FIRST_LINE=$(head -n 1 "${CSV_FILE}")
 local COLUMN_COUNT
 COLUMN_COUNT=$(echo "${FIRST_LINE}" | awk -F',' '{print NF}')

 if [[ "${COLUMN_INDEX}" -ge "${COLUMN_COUNT}" ]]; then
  __loge "ERROR: Column index ${COLUMN_INDEX} is out of range (0-${COLUMN_COUNT})"
  return 1
 fi

 __logi "CSV enum compatibility validation succeeded"
 return 0
}

# Validate CSV structure
# Parameters:
#   $1: CSV file path
#   $2: Expected column count (optional)
# Returns: 0 if validation passes, 1 if validation fails
function __validate_csv_structure() {
 local CSV_FILE="${1}"
 local EXPECTED_COLUMNS="${2:-}"

 if [[ ! -f "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file not found: ${CSV_FILE}"
  return 1
 fi

 __logi "Validating CSV structure: ${CSV_FILE}"

 # Check if CSV has content
 if [[ ! -s "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file is empty: ${CSV_FILE}"
  return 1
 fi

 # Get column count from first line
 local FIRST_LINE
 FIRST_LINE=$(head -n 1 "${CSV_FILE}")
 local ACTUAL_COLUMNS
 ACTUAL_COLUMNS=$(echo "${FIRST_LINE}" | awk -F',' '{print NF}')

 __logd "CSV has ${ACTUAL_COLUMNS} columns"

 # Validate expected column count if provided
 if [[ -n "${EXPECTED_COLUMNS}" ]]; then
  if [[ "${ACTUAL_COLUMNS}" -ne "${EXPECTED_COLUMNS}" ]]; then
   __loge "ERROR: Expected ${EXPECTED_COLUMNS} columns, got ${ACTUAL_COLUMNS}"
   return 1
  fi
 fi

 __logi "CSV structure validation succeeded"
 return 0
}

# =====================================================
# Coordinate Validation Functions (Consolidated)
# =====================================================

# Validate XML coordinates
# Parameters:
#   $1: XML file path
# Returns: 0 if validation passes, 1 if validation fails
function __validate_xml_coordinates() {
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  return 1
 fi

 __logi "Validating XML coordinates: ${XML_FILE}"

 # Check for coordinate patterns in XML
 if grep -q 'lat=' "${XML_FILE}" && grep -q 'lon=' "${XML_FILE}"; then
  __logi "XML coordinate validation succeeded"
  return 0
 else
  __loge "ERROR: XML coordinate validation failed - missing lat/lon attributes"
  return 1
 fi
}

# Validate coordinates (generic implementation)
# Parameters:
#   $1: Coordinate string or file path
# Returns: 0 if validation passes, 1 if validation fails
function __validate_coordinates() {
 local COORD_INPUT="${1}"

 if [[ -f "${COORD_INPUT}" ]]; then
  # If it's a file, validate as XML coordinates
  __validate_xml_coordinates "${COORD_INPUT}"
 else
  # If it's a string, validate coordinate format
  if [[ "${COORD_INPUT}" =~ ^-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*$ ]]; then
   __logi "Coordinate string validation succeeded: ${COORD_INPUT}"
   return 0
  else
   __loge "ERROR: Invalid coordinate format: ${COORD_INPUT}"
   return 1
  fi
 fi
}

# Validate CSV coordinates
# Parameters:
#   $1: CSV file path
#   $2: Latitude column index (optional, default: 0)
#   $3: Longitude column index (optional, default: 1)
# Returns: 0 if validation passes, 1 if validation fails
function __validate_csv_coordinates() {
 local CSV_FILE="${1}"
 local LAT_COL="${2:-0}"
 local LON_COL="${3:-1}"

 if [[ ! -f "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file not found: ${CSV_FILE}"
  return 1
 fi

 __logi "Validating CSV coordinates: ${CSV_FILE}, lat_col=${LAT_COL}, lon_col=${LON_COL}"

 # Validate CSV structure first
 if ! __validate_csv_structure "${CSV_FILE}"; then
  return 1
 fi

 # Check if coordinate columns exist and contain valid data
 local FIRST_DATA_LINE
 FIRST_DATA_LINE=$(tail -n +2 "${CSV_FILE}" | head -n 1)

 if [[ -z "${FIRST_DATA_LINE}" ]]; then
  __loge "ERROR: CSV file has no data rows"
  return 1
 fi

 # Extract coordinates from first data line
 local LAT_VAL
 local LON_VAL
 LAT_VAL=$(echo "${FIRST_DATA_LINE}" | awk -F',' -v col="${LAT_COL}" '{print $(col+1)}')
 LON_VAL=$(echo "${FIRST_DATA_LINE}" | awk -F',' -v col="${LON_COL}" '{print $(col+1)}')

 # Validate coordinate values
 if [[ ! "${LAT_VAL}" =~ ^-?[0-9]+\.?[0-9]*$ ]] || [[ ! "${LON_VAL}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  __loge "ERROR: Invalid coordinate values: lat=${LAT_VAL}, lon=${LON_VAL}"
  return 1
 fi

 # Check coordinate ranges
 if (($(echo "${LAT_VAL} < -90 || ${LAT_VAL} > 90" | bc -l))); then
  __loge "ERROR: Latitude out of range (-90 to 90): ${LAT_VAL}"
  return 1
 fi

 if (($(echo "${LON_VAL} < -180 || ${LON_VAL} > 180" | bc -l))); then
  __loge "ERROR: Longitude out of range (-180 to 180): ${LON_VAL}"
  return 1
 fi

 __logi "CSV coordinate validation succeeded"
 return 0
}

# =====================================================
# Input Validation Functions (Consolidated)
# =====================================================

# Validate input file
# Parameters:
#   $1: File path to validate
#   $2: File type (optional, for better error messages)
# Returns: 0 if validation passes, 1 if validation fails
function __validate_input_file() {
 local FILE_PATH="${1}"
 local FILE_TYPE="${2:-file}"

 if [[ -z "${FILE_PATH}" ]]; then
  __loge "ERROR: File path is empty"
  return 1
 fi

 if [[ ! -f "${FILE_PATH}" ]]; then
  __loge "ERROR: ${FILE_TYPE} not found: ${FILE_PATH}"
  return 1
 fi

 if [[ ! -r "${FILE_PATH}" ]]; then
  __loge "ERROR: ${FILE_TYPE} is not readable: ${FILE_PATH}"
  return 1
 fi

 if [[ ! -s "${FILE_PATH}" ]]; then
  __loge "ERROR: ${FILE_TYPE} is empty: ${FILE_PATH}"
  return 1
 fi

 __logd "${FILE_TYPE} validation passed: ${FILE_PATH}"
 return 0
}

# Validate multiple input files
# Parameters:
#   $@: List of file paths to validate
# Returns: 0 if all validations pass, 1 if any fail
function __validate_input_files() {
 local all_valid=true

 for file_path in "$@"; do
  if ! __validate_input_file "${file_path}"; then
   all_valid=false
  fi
 done

 if [[ "${all_valid}" == true ]]; then
  __logi "All input files validation passed"
  return 0
 else
  __loge "Some input files validation failed"
  return 1
 fi
}

# =====================================================
# Database Validation Functions (Consolidated)
# =====================================================

# Validate database connection
# Parameters:
#   $1: Database name (optional, uses DBNAME if not provided)
# Returns: 0 if validation passes, 1 if validation fails
function __validate_database_connection() {
 local DB_NAME="${1:-${DBNAME}}"

 if [[ -z "${DB_NAME}" ]]; then
  __loge "ERROR: Database name not specified"
  return 1
 fi

 __logi "Validating database connection: ${DB_NAME}"

 # Test database connection
 if ! psql -d "${DB_NAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  __loge "ERROR: Cannot connect to database: ${DB_NAME}"
  return 1
 fi

 __logi "Database connection validation succeeded"
 return 0
}

# Validate database tables
# Parameters:
#   $1: Database name (optional, uses DBNAME if not provided)
#   $2: Schema name (optional, default: public)
#   $3: Table name pattern (optional, default: all tables)
# Returns: 0 if validation passes, 1 if validation fails
function __validate_database_tables() {
 local DB_NAME="${1:-${DBNAME}}"
 local SCHEMA_NAME="${2:-public}"
 local TABLE_PATTERN="${3:-%}"

 if [[ -z "${DB_NAME}" ]]; then
  __loge "ERROR: Database name not specified"
  return 1
 fi

 __logi "Validating database tables: ${DB_NAME}.${SCHEMA_NAME}.${TABLE_PATTERN}"

 # Check if tables exist
 local TABLE_COUNT
 TABLE_COUNT=$(psql -d "${DB_NAME}" -Atq -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${SCHEMA_NAME}' AND table_name LIKE '${TABLE_PATTERN}';")

 if [[ "${TABLE_COUNT}" -eq 0 ]]; then
  __loge "ERROR: No tables found matching pattern: ${SCHEMA_NAME}.${TABLE_PATTERN}"
  return 1
 fi

 __logi "Database tables validation succeeded: ${TABLE_COUNT} tables found"
 return 0
}

# =====================================================
# Date Validation Functions (Consolidated)
# =====================================================

# Validate ISO8601 date format
# Parameters:
#   $1: Date string to validate
# Returns: 0 if validation passes, 1 if validation fails
function __validate_iso8601_date() {
 local DATE_STRING="${1}"

 if [[ -z "${DATE_STRING}" ]]; then
  __loge "ERROR: Date string is empty"
  return 1
 fi

 # Check ISO8601 format (YYYY-MM-DDTHH:MM:SSZ or YYYY-MM-DD)
 if [[ "${DATE_STRING}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z?)?$ ]]; then
  __logd "ISO8601 date validation passed: ${DATE_STRING}"
  return 0
 else
  __loge "ERROR: Invalid ISO8601 date format: ${DATE_STRING}"
  return 1
 fi
}

# Validate date format
# Parameters:
#   $1: Date string to validate
#   $2: Expected format (optional, default: ISO8601)
# Returns: 0 if validation passes, 1 if validation fails
function __validate_date_format() {
 local DATE_STRING="${1}"
 local EXPECTED_FORMAT="${2:-ISO8601}"

 case "${EXPECTED_FORMAT}" in
 "ISO8601")
  __validate_iso8601_date "${DATE_STRING}"
  ;;
 *)
  __loge "ERROR: Unsupported date format: ${EXPECTED_FORMAT}"
  return 1
  ;;
 esac
}

# Validate date format UTC
# Parameters:
#   $1: Date string to validate
# Returns: 0 if validation passes, 1 if validation fails
function __validate_date_format_utc() {
 local DATE_STRING="${1}"

 # First validate ISO8601 format
 if ! __validate_iso8601_date "${DATE_STRING}"; then
  return 1
 fi

 # Check if it ends with Z (UTC indicator)
 if [[ "${DATE_STRING}" =~ Z$ ]]; then
  __logd "UTC date validation passed: ${DATE_STRING}"
  return 0
 else
  __loge "ERROR: Date is not in UTC format (missing Z suffix): ${DATE_STRING}"
  return 1
 fi
}
