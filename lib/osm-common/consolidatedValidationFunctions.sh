#!/bin/bash
# Consolidated Validation Functions for OSM-Notes-profile
# This file consolidates all validation functions to eliminate duplication
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27
# Description: Centralized validation functions for better maintainability

# Common help function for library files
function __show_help_library() {
 local SCRIPT_NAME="${1:-Unknown Script}"
 local DESCRIPTION="${2:-No description available}"
 local FUNCTIONS_LIST="${3:-}"
 local VERSION="${4:-${VERSION:-Unknown}}"

 echo "${SCRIPT_NAME}"
 echo "${DESCRIPTION}"
 echo
 echo "Usage: source bin/$(basename "${BASH_SOURCE[0]}")"
 echo
 if [[ -n "${FUNCTIONS_LIST}" ]]; then
  echo "Available functions:"
  echo -e "${FUNCTIONS_LIST}"
  echo
 fi
 echo "Author: Andres Gomez (AngocA)"
 echo "Version: ${VERSION}"
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
 __log_start
 local XML_FILE="${1}"
 local SCHEMA_FILE="${2:-}"
 local TIMEOUT="${3:-300}"

 # File size thresholds for different validation strategies
 local LARGE_FILE_THRESHOLD=100      # MB
 local VERY_LARGE_FILE_THRESHOLD=500 # MB

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  __log_finish
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
   __log_finish
   return 0
  else
   __loge "ERROR: Structure-only validation failed"
   __log_finish
   return 1
  fi
 elif [[ "${SIZE_MB}" -gt "${LARGE_FILE_THRESHOLD}" ]] || [[ "${IS_PLANET_FILE}" == true ]]; then
  __logw "WARNING: Large XML file or Planet file detected (${SIZE_MB} MB). Using basic validation."

  # For large files or planet files, use basic XML validation without schema
  if __validate_xml_basic "${XML_FILE}"; then
   __logi "Basic XML validation succeeded"
   __log_finish
   return 0
  else
   __loge "ERROR: Basic XML validation failed"
   __log_finish
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
    __log_finish
    return 0
   else
    __loge "ERROR: XML schema validation failed - xmllint output: ${XMLLINT_OUTPUT}"
    __log_finish
    return 1
   fi
  else
   # Fallback to basic validation if no schema provided
   if __validate_xml_basic "${XML_FILE}"; then
    __logi "Basic XML validation succeeded"
    __log_finish
    return 0
   else
    __loge "ERROR: Basic XML validation failed"
    __log_finish
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
 __log_start
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  __log_finish
  return 1
 fi

 __logi "Performing basic XML validation: ${XML_FILE}"

 # Lightweight XML validation using grep instead of xmllint
 # Check if file contains basic XML structure markers
 if ! grep -q '<?xml' "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: XML file does not contain XML declaration"
  __log_finish
  return 1
 fi

 # Check if file contains expected root element
 if ! grep -q '<osm' "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: XML file does not contain expected root element (<osm>)"
  __log_finish
  return 1
 fi

 # Check if file is not empty
 if [[ ! -s "${XML_FILE}" ]]; then
  __loge "ERROR: XML file is empty"
  __log_finish
  return 1
 fi

 # Check if file has minimum size (at least 100 bytes)
 local XML_SIZE
 XML_SIZE=$(stat -c%s "${XML_FILE}" 2> /dev/null || stat -f%z "${XML_FILE}" 2>&1 || echo "0")
 if [[ "${XML_SIZE}" -lt 100 ]]; then
  __loge "ERROR: XML file is too small (${XML_SIZE} bytes), expected at least 100 bytes"
  __log_finish
  return 1
 fi

 __logi "Basic XML validation succeeded"
 __log_finish
 return 0
}

# XML structure-only validation (very lightweight)
# Parameters:
#   $1: XML file path
# Returns: 0 if validation passes, 1 if validation fails
function __validate_xml_structure_only() {
 __log_start
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  __log_finish
  return 1
 fi

 __logi "Performing structure-only XML validation: ${XML_FILE}"

 # Check if file contains basic XML structure markers
 if grep -q '<?xml' "${XML_FILE}" && grep -q '<osm' "${XML_FILE}"; then
  __logi "Structure-only XML validation succeeded"
  __log_finish
  return 0
 else
  __loge "ERROR: Structure-only XML validation failed - missing XML structure markers"
  __log_finish
  return 1
 fi
}

# Validate XML structure (generic implementation)
# Parameters:
#   $1: XML file path
# Returns: 0 if validation passes, 1 if validation fails
function __validate_xml_structure() {
 __log_start
 __validate_xml_basic "${1}"
 __log_finish
}

# Validate XML structure implementation (alias for compatibility)
# Parameters:
#   $1: XML file path
# Returns: 0 if validation passes, 1 if validation fails
function __validate_xml_structure_impl() {
 __log_start
 __validate_xml_basic "${1}"
 __log_finish
}

# =====================================================
# CSV Validation Functions (Consolidated)
# =====================================================

# Validate OSM comments with realistic patterns
# Parameters:
#   $1: CSV file path
#   $2: Validation type (comments, text_comments, notes)
# Returns: 0 if validation passes, 1 if validation fails
function __validate_osm_comments_realistic() {
 __log_start
 local CSV_FILE="${1}"
 local VALIDATION_TYPE="${2}"

 if [[ ! -f "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file not found: ${CSV_FILE}"
  __log_finish
  return 1
 fi

 __logi "Validating OSM ${VALIDATION_TYPE} with realistic patterns: ${CSV_FILE}"

 # Check if CSV has content
 if [[ ! -s "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file is empty: ${CSV_FILE}"
  __log_finish
  return 1
 fi

 case "${VALIDATION_TYPE}" in
 "comments")
  # Validate comment events with realistic OSM patterns
  local INVALID_LINES=0
  local LINE_NUMBER=0
  local TOTAL_LINES=0
  local EMPTY_EVENTS=0
  local ANONYMOUS_COMMENTS=0
  local SYSTEM_ACTIONS=0

  while IFS= read -r line; do
   ((LINE_NUMBER++))
   ((TOTAL_LINES++))

   # Skip empty lines
   if [[ -z "${line}" ]]; then
    continue
   fi

   # Parse CSV fields (note_id, sequence, action, timestamp, uid, username)
   local NOTE_ID SEQUENCE ACTION TIMESTAMP UID USERNAME
   IFS=',' read -r NOTE_ID SEQUENCE ACTION TIMESTAMP UID USERNAME <<< "${line}"

   # Remove quotes from fields
   ACTION=$(echo "${ACTION}" | tr -d '"')
   TIMESTAMP=$(echo "${TIMESTAMP}" | tr -d '"')
   UID=$(echo "${UID}" | tr -d '"')
   USERNAME=$(echo "${USERNAME}" | tr -d '"')

   # Validate required fields
   if [[ -z "${NOTE_ID}" ]] || [[ -z "${SEQUENCE}" ]] || [[ -z "${ACTION}" ]] || [[ -z "${TIMESTAMP}" ]]; then
    __logw "WARNING: Missing required fields in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
    continue
   fi

   # Validate action values (realistic OSM actions)
   if [[ ! "${ACTION}" =~ ^(opened|closed|reopened|commented|hidden|reopened_automatically)$ ]]; then
    __logw "WARNING: Unknown action '${ACTION}' in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
    continue
   fi

   # Validate timestamp format (ISO 8601)
   if [[ ! "${TIMESTAMP}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    __logw "WARNING: Invalid timestamp format '${TIMESTAMP}' in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
    continue
   fi

   # Track realistic patterns
   if [[ -z "${UID}" ]] || [[ -z "${USERNAME}" ]]; then
    ((ANONYMOUS_COMMENTS++))
    __logd "DEBUG: Anonymous comment detected in line ${LINE_NUMBER} (note ${NOTE_ID})"
   fi

   # Track system actions (actions that commonly have no user)
   if [[ "${ACTION}" =~ ^(reopened|closed)$ ]] && [[ -z "${UID}" ]]; then
    ((SYSTEM_ACTIONS++))
    __logd "DEBUG: System action detected in line ${LINE_NUMBER} (note ${NOTE_ID}, action: ${ACTION})"
   fi

  done < "${CSV_FILE}"

  # Report validation results
  __logi "Comment validation completed:"
  __logi "  Total lines: ${TOTAL_LINES}"
  __logi "  Anonymous comments: ${ANONYMOUS_COMMENTS}"
  __logi "  System actions: ${SYSTEM_ACTIONS}"
  __logi "  Invalid lines: ${INVALID_LINES}"

  if [[ "${INVALID_LINES}" -gt 0 ]]; then
   __loge "ERROR: Found ${INVALID_LINES} invalid lines in ${CSV_FILE}"
   __log_finish
   return 1
  fi
  ;;

 "text_comments")
  # Validate text comments with realistic OSM patterns
  local INVALID_LINES=0
  local LINE_NUMBER=0
  local TOTAL_LINES=0
  local EMPTY_TEXTS=0
  local LONG_TEXTS=0

  while IFS= read -r line; do
   ((LINE_NUMBER++))
   ((TOTAL_LINES++))

   # Skip empty lines
   if [[ -z "${line}" ]]; then
    continue
   fi

   # Parse CSV fields (note_id, sequence, text)
   local NOTE_ID SEQUENCE TEXT
   IFS=',' read -r NOTE_ID SEQUENCE TEXT <<< "${line}"

   # Remove quotes from text field
   TEXT=$(echo "${TEXT}" | tr -d '"')

   # Validate required fields
   if [[ -z "${NOTE_ID}" ]] || [[ -z "${SEQUENCE}" ]]; then
    __logw "WARNING: Missing required fields in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
    continue
   fi

   # Track empty texts (realistic pattern in OSM)
   if [[ -z "${TEXT}" ]]; then
    ((EMPTY_TEXTS++))
    __logd "DEBUG: Empty text comment detected in line ${LINE_NUMBER} (note ${NOTE_ID})"
   fi

   # Track very long texts (potential data corruption)
   if [[ ${#TEXT} -gt 10000 ]]; then
    __logw "WARNING: Very long text comment in line ${LINE_NUMBER} (${#TEXT} chars): ${TEXT:0:100}..."
    ((LONG_TEXTS++))
   fi

  done < "${CSV_FILE}"

  # Report validation results
  __logi "Text comment validation completed:"
  __logi "  Total lines: ${TOTAL_LINES}"
  __logi "  Empty texts: ${EMPTY_TEXTS}"
  __logi "  Long texts: ${LONG_TEXTS}"
  __logi "  Invalid lines: ${INVALID_LINES}"

  if [[ "${INVALID_LINES}" -gt 0 ]]; then
   __loge "ERROR: Found ${INVALID_LINES} invalid lines in ${CSV_FILE}"
   __log_finish
   return 1
  fi
  ;;

 "notes")
  # Validate notes with realistic OSM patterns
  local INVALID_LINES=0
  local LINE_NUMBER=0
  local TOTAL_LINES=0
  local MISSING_COORDINATES=0
  local INVALID_COORDINATES=0

  while IFS= read -r line; do
   ((LINE_NUMBER++))
   ((TOTAL_LINES++))

   # Skip empty lines
   if [[ -z "${line}" ]]; then
    continue
   fi

   # Parse CSV fields (note_id, lat, lon, created_at, status, closed_at, country_id)
   local NOTE_ID LAT LON CREATED_AT STATUS CLOSED_AT COUNTRY_ID
   IFS=',' read -r NOTE_ID LAT LON CREATED_AT STATUS CLOSED_AT COUNTRY_ID <<< "${line}"

   # Remove quotes from fields
   CREATED_AT=$(echo "${CREATED_AT}" | tr -d '"')
   STATUS=$(echo "${STATUS}" | tr -d '"')
   CLOSED_AT=$(echo "${CLOSED_AT}" | tr -d '"')

   # Validate required fields
   if [[ -z "${NOTE_ID}" ]] || [[ -z "${LAT}" ]] || [[ -z "${LON}" ]] || [[ -z "${CREATED_AT}" ]]; then
    __logw "WARNING: Missing required fields in line ${LINE_NUMBER}: ${line}"
    ((INVALID_LINES++))
    continue
   fi

   # Validate coordinates (realistic ranges)
   if [[ ! "${LAT}" =~ ^-?[0-9]+\.?[0-9]*$ ]] || [[ ! "${LON}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
    __logw "WARNING: Invalid coordinate format in line ${LINE_NUMBER}: lat=${LAT}, lon=${LON}"
    ((INVALID_COORDINATES++))
    ((INVALID_LINES++))
    continue
   fi

   # Validate coordinate ranges (realistic Earth bounds)
   if (($(echo "${LAT} < -90" | bc -l))) || (($(echo "${LAT} > 90" | bc -l))); then
    __logw "WARNING: Latitude out of range in line ${LINE_NUMBER}: ${LAT}"
    ((INVALID_COORDINATES++))
    ((INVALID_LINES++))
    continue
   fi

   if (($(echo "${LON} < -180" | bc -l))) || (($(echo "${LON} > 180" | bc -l))); then
    __logw "WARNING: Longitude out of range in line ${LINE_NUMBER}: ${LON}"
    ((INVALID_COORDINATES++))
    ((INVALID_LINES++))
    continue
   fi

   # Validate timestamp format
   if [[ ! "${CREATED_AT}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    __logw "WARNING: Invalid created_at format '${CREATED_AT}' in line ${LINE_NUMBER}"
    ((INVALID_LINES++))
    continue
   fi

   # Validate status (can be empty for open notes)
   if [[ -n "${STATUS}" ]] && [[ ! "${STATUS}" =~ ^(open|close|hidden)$ ]]; then
    __logw "WARNING: Invalid status '${STATUS}' in line ${LINE_NUMBER}"
    ((INVALID_LINES++))
    continue
   fi

  done < "${CSV_FILE}"

  # Report validation results
  __logi "Note validation completed:"
  __logi "  Total lines: ${TOTAL_LINES}"
  __logi "  Invalid coordinates: ${INVALID_COORDINATES}"
  __logi "  Invalid lines: ${INVALID_LINES}"

  if [[ "${INVALID_LINES}" -gt 0 ]]; then
   __loge "ERROR: Found ${INVALID_LINES} invalid lines in ${CSV_FILE}"
   __log_finish
   return 1
  fi
  ;;

 *)
  __logw "WARNING: Unknown validation type '${VALIDATION_TYPE}', skipping validation"
  __log_finish
  return 0
  ;;
 esac

 __logi "OSM ${VALIDATION_TYPE} validation passed with realistic patterns"
 __log_finish
 return 0
}

# Validate CSV structure
# Parameters:
#   $1: CSV file path
#   $2: Expected column count (optional)
# Returns: 0 if validation passes, 1 if validation fails
function __validate_csv_structure() {
 __log_start
 local CSV_FILE="${1}"
 local EXPECTED_COLUMNS="${2:-}"

 if [[ ! -f "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file not found: ${CSV_FILE}"
  __log_finish
  return 1
 fi

 __logi "Validating CSV structure: ${CSV_FILE}"

 # Check if CSV has content
 if [[ ! -s "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file is empty: ${CSV_FILE}"
  __log_finish
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
   __log_finish
   return 1
  fi
 fi

 __logi "CSV structure validation succeeded"
 __log_finish
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
 __log_start
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  __log_finish
  return 1
 fi

 __logi "Validating XML coordinates: ${XML_FILE}"

 # Check for coordinate patterns in XML
 if grep -q 'lat=' "${XML_FILE}" && grep -q 'lon=' "${XML_FILE}"; then
  __logi "XML coordinate validation succeeded"
  __log_finish
  return 0
 else
  __loge "ERROR: XML coordinate validation failed - missing lat/lon attributes"
  __log_finish
  return 1
 fi
}

# Validate coordinates (generic implementation)
# Parameters:
#   $1: Coordinate string or file path
# Returns: 0 if validation passes, 1 if validation fails
function __validate_coordinates() {
 __log_start
 local COORD_INPUT="${1}"

 if [[ -f "${COORD_INPUT}" ]]; then
  # If it's a file, validate as XML coordinates
  __validate_xml_coordinates "${COORD_INPUT}"
 else
  # If it's a string, validate coordinate format
  if [[ "${COORD_INPUT}" =~ ^-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*$ ]]; then
   __logi "Coordinate string validation succeeded: ${COORD_INPUT}"
   __log_finish
   return 0
  else
   __loge "ERROR: Invalid coordinate format: ${COORD_INPUT}"
   __log_finish
   return 1
  fi
 fi
 __log_finish
}

# Validate CSV coordinates
# Parameters:
#   $1: CSV file path
#   $2: Latitude column index (optional, default: 0)
#   $3: Longitude column index (optional, default: 1)
# Returns: 0 if validation passes, 1 if validation fails
function __validate_csv_coordinates() {
 __log_start
 local CSV_FILE="${1}"
 local LAT_COL="${2:-0}"
 local LON_COL="${3:-1}"

 if [[ ! -f "${CSV_FILE}" ]]; then
  __loge "ERROR: CSV file not found: ${CSV_FILE}"
  __log_finish
  return 1
 fi

 __logi "Validating CSV coordinates: ${CSV_FILE}, lat_col=${LAT_COL}, lon_col=${LON_COL}"

 # Validate CSV structure first
 if ! __validate_csv_structure "${CSV_FILE}"; then
  __log_finish
  return 1
 fi

 # Check if coordinate columns exist and contain valid data
 local FIRST_DATA_LINE
 FIRST_DATA_LINE=$(tail -n +2 "${CSV_FILE}" | head -n 1)

 if [[ -z "${FIRST_DATA_LINE}" ]]; then
  __loge "ERROR: CSV file has no data rows"
  __log_finish
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
  __log_finish
  return 1
 fi

 # Check coordinate ranges
 if (($(echo "${LAT_VAL} < -90 || ${LAT_VAL} > 90" | bc -l))); then
  __loge "ERROR: Latitude out of range (-90 to 90): ${LAT_VAL}"
  __log_finish
  return 1
 fi

 if (($(echo "${LON_VAL} < -180 || ${LON_VAL} > 180" | bc -l))); then
  __loge "ERROR: Longitude out of range (-180 to 180): ${LON_VAL}"
  __log_finish
  return 1
 fi

 __logi "CSV coordinate validation succeeded"
 __log_finish
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
 __log_start
 local FILE_PATH="${1}"
 local FILE_TYPE="${2:-file}"

 if [[ -z "${FILE_PATH}" ]]; then
  __loge "ERROR: File path is empty"
  __log_finish
  return 1
 fi

 if [[ ! -f "${FILE_PATH}" ]]; then
  __loge "ERROR: ${FILE_TYPE} not found: ${FILE_PATH}"
  __log_finish
  return 1
 fi

 if [[ ! -r "${FILE_PATH}" ]]; then
  __loge "ERROR: ${FILE_TYPE} is not readable: ${FILE_PATH}"
  __log_finish
  return 1
 fi

 if [[ ! -s "${FILE_PATH}" ]]; then
  __loge "ERROR: ${FILE_TYPE} is empty: ${FILE_PATH}"
  __log_finish
  return 1
 fi

 __logd "${FILE_TYPE} validation passed: ${FILE_PATH}"
 __log_finish
 return 0
}

# Validate multiple input files
# Parameters:
#   $@: List of file paths to validate
# Returns: 0 if all validations pass, 1 if any fail
function __validate_input_files() {
 local ALL_VALID=true
 __log_start

 for FILE_PATH in "$@"; do
  if ! __validate_input_file "${FILE_PATH}"; then
   ALL_VALID=false
  fi
 done

 if [[ "${ALL_VALID}" == true ]]; then
  __logi "All input files validation passed"
  __log_finish
  return 0
 else
  __loge "Some input files validation failed"
  __log_finish
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
 __log_start
 local DB_NAME="${1:-${DBNAME}}"

 if [[ -z "${DB_NAME}" ]]; then
  __loge "ERROR: Database name not specified"
  __log_finish
  return 1
 fi

 __logi "Validating database connection: ${DB_NAME}"

 # Test database connection
 if ! psql -d "${DB_NAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  __loge "ERROR: Cannot connect to database: ${DB_NAME}"
  __log_finish
  return 1
 fi

 __logi "Database connection validation succeeded"
 __log_finish
 return 0
}

# Validate database tables
# Parameters:
#   $1: Database name (optional, uses DBNAME if not provided)
#   $2: Schema name (optional, default: public)
#   $3: Table name pattern (optional, default: all tables)
# Returns: 0 if validation passes, 1 if validation fails
function __validate_database_tables() {
 __log_start
 local DB_NAME="${1:-${DBNAME}}"
 local SCHEMA_NAME="${2:-public}"
 local TABLE_PATTERN="${3:-%}"

 if [[ -z "${DB_NAME}" ]]; then
  __loge "ERROR: Database name not specified"
  __log_finish
  return 1
 fi

 __logi "Validating database tables: ${DB_NAME}.${SCHEMA_NAME}.${TABLE_PATTERN}"

 # Check if tables exist
 local TABLE_COUNT
 TABLE_COUNT=$(psql -d "${DB_NAME}" -Atq -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${SCHEMA_NAME}' AND table_name LIKE '${TABLE_PATTERN}';")

 if [[ "${TABLE_COUNT}" -eq 0 ]]; then
  __loge "ERROR: No tables found matching pattern: ${SCHEMA_NAME}.${TABLE_PATTERN}"
  __log_finish
  return 1
 fi

 __logi "Database tables validation succeeded: ${TABLE_COUNT} tables found"
 __log_finish
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
 __log_start
 local DATE_STRING="${1}"

 if [[ -z "${DATE_STRING}" ]]; then
  __loge "ERROR: Date string is empty"
  __log_finish
  return 1
 fi

 # Check ISO8601 format (YYYY-MM-DDTHH:MM:SSZ or YYYY-MM-DD)
 if [[ "${DATE_STRING}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9]{2}:[0-9]{2}:[0-9]{2}Z?)?$ ]]; then
  __logd "ISO8601 date validation passed: ${DATE_STRING}"
  __log_finish
  return 0
 else
  __loge "ERROR: Invalid ISO8601 date format: ${DATE_STRING}"
  __log_finish
  return 1
 fi
}

# Validate date format
# Parameters:
#   $1: Date string to validate
#   $2: Expected format (optional, default: ISO8601)
# Returns: 0 if validation passes, 1 if validation fails
function __validate_date_format() {
 __log_start
 local DATE_STRING="${1}"
 local EXPECTED_FORMAT="${2:-ISO8601}"

 case "${EXPECTED_FORMAT}" in
 "ISO8601")
  __validate_iso8601_date "${DATE_STRING}"
  ;;
 *)
  __loge "ERROR: Unsupported date format: ${EXPECTED_FORMAT}"
  __log_finish
  return 1
  ;;
 esac
 __log_finish
}

# Validate date format UTC
# Parameters:
#   $1: Date string to validate
# Returns: 0 if validation passes, 1 if validation fails
function __validate_date_format_utc() {
 __log_start
 local DATE_STRING="${1}"

 # First validate ISO8601 format
 if ! __validate_iso8601_date "${DATE_STRING}"; then
  __log_finish
  return 1
 fi

 # Check if it ends with Z (UTC indicator)
 if [[ "${DATE_STRING}" =~ Z$ ]]; then
  __logd "UTC date validation passed: ${DATE_STRING}"
  __log_finish
  return 0
 else
  __loge "ERROR: Date is not in UTC format (missing Z suffix): ${DATE_STRING}"
  __log_finish
  return 1
 fi
}
