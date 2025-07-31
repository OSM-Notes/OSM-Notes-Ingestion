#!/bin/bash

# Common Functions for OSM-Notes-profile
# This file contains functions used across all scripts in the project.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

# shellcheck disable=SC2317,SC2155,SC2034

# Error codes (common across all scripts)
# shellcheck disable=SC2034
declare -r ERROR_HELP_MESSAGE=1
declare -r ERROR_PREVIOUS_EXECUTION_FAILED=238
declare -r ERROR_CREATING_REPORT=239
declare -r ERROR_MISSING_LIBRARY=241
declare -r ERROR_INVALID_ARGUMENT=242
declare -r ERROR_LOGGER_UTILITY=243
declare -r ERROR_DOWNLOADING_BOUNDARY_ID_LIST=244
declare -r ERROR_NO_LAST_UPDATE=245
declare -r ERROR_PLANET_PROCESS_IS_RUNNING=246
declare -r ERROR_DOWNLOADING_NOTES=247
declare -r ERROR_EXECUTING_PLANET_DUMP=248
declare -r ERROR_DOWNLOADING_BOUNDARY=249
declare -r ERROR_GEOJSON_CONVERSION=250
declare -r ERROR_INTERNET_ISSUE=251
declare -r ERROR_DATA_VALIDATION=252
declare -r ERROR_GENERAL=255

# Common variables
# shellcheck disable=SC2034
declare GENERATE_FAILED_FILE=true
declare -r FAILED_EXECUTION_FILE="/tmp/${BASENAME}_failed"
declare PREREQS_CHECKED=false

# Logger framework
# shellcheck disable=SC2034
declare -r LOGGER_UTILITY="${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"

# Logger functions
function __log() { log "${@}"; }
function __logt() { log_trace "${@}"; }
function __logd() { log_debug "${@}"; }
function __logi() { log_info "${@}"; }
function __logw() { log_warn "${@}"; }
function __loge() { log_error "${@}"; }
function __logf() { log_fatal "${@}"; }

# Start logger function
function __start_logger() {
 # shellcheck disable=SC1090
 source "${LOGGER_UTILITY}"
 # shellcheck disable=SC2034
 LOG_LEVEL="${LOG_LEVEL:-INFO}"
 # Set the log level in bash_logger
 __set_log_level "${LOG_LEVEL}"
}

# Validation function
function __validation {
 if [[ "${1}" == "" ]]; then
  echo "ERROR: ${2}"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
}

# Trap function for cleanup
function __trapOn() {
 trap 'echo "ERROR: Command failed at line $LINENO"' ERR
 trap 'echo "INFO: Script interrupted at line $LINENO"' INT
 trap 'echo "INFO: Script terminated at line $LINENO"' TERM
}

# Check prerequisites commands
function __checkPrereqsCommands {
 __log_start
 __logd "Checking prerequisites commands."

 # Check if required commands are available
 local missing_commands=()

 # Check basic commands
 for cmd in bash curl wget psql; do
  if ! command -v "${cmd}" > /dev/null 2>&1; then
   missing_commands+=("${cmd}")
  fi
 done

 # Check XML processing commands
 for cmd in xmllint xsltproc; do
  if ! command -v "${cmd}" > /dev/null 2>&1; then
   missing_commands+=("${cmd}")
  fi
 done

 # Check JSON processing commands
 if ! command -v jq > /dev/null 2>&1; then
  missing_commands+=("jq")
 fi

 # Check geospatial processing commands
 for cmd in ogr2ogr gdalinfo; do
  if ! command -v "${cmd}" > /dev/null 2>&1; then
   missing_commands+=("${cmd}")
  fi
 done

 # Report missing commands
 if [[ ${#missing_commands[@]} -gt 0 ]]; then
  __loge "ERROR: Missing required commands: ${missing_commands[*]}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 __logi "All required commands are available."
 __log_finish
}

# Check prerequisites functions
function __checkPrereqs_functions {
 __log_start
 __logd "Checking prerequisites functions."

 # Check if required functions are available
 local missing_functions=()

 # Check logger functions
 for func in __log __logi __loge; do
  if ! declare -f "${func}" > /dev/null 2>&1; then
   missing_functions+=("${func}")
  fi
 done

 # Report missing functions
 if [[ ${#missing_functions[@]} -gt 0 ]]; then
  __loge "ERROR: Missing required functions: ${missing_functions[*]}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 __logi "All required functions are available."
 __log_finish
}

# Check base tables
function __checkBaseTables {
 __log_start
 __logd "Checking base tables."
 
 # Validate that POSTGRES_11_CHECK_BASE_TABLES is defined
 if [[ -z "${POSTGRES_11_CHECK_BASE_TABLES:-}" ]]; then
  __loge "ERROR: POSTGRES_11_CHECK_BASE_TABLES variable is not defined"
  __loge "ERROR: This variable should be defined in the calling script"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 # Validate that the SQL file exists
 if [[ ! -f "${POSTGRES_11_CHECK_BASE_TABLES}" ]]; then
  __loge "ERROR: SQL file not found: ${POSTGRES_11_CHECK_BASE_TABLES}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 psql -d "${DBNAME}" -f "${POSTGRES_11_CHECK_BASE_TABLES}"
 __log_finish
}

# Drop generic objects
function __dropGenericObjects {
 __log_start
 __logd "Dropping generic objects."
 
 # Validate that POSTGRES_12_DROP_GENERIC_OBJECTS is defined
 if [[ -z "${POSTGRES_12_DROP_GENERIC_OBJECTS:-}" ]]; then
  __loge "ERROR: POSTGRES_12_DROP_GENERIC_OBJECTS variable is not defined"
  __loge "ERROR: This variable should be defined in the calling script"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 # Validate that the SQL file exists
 if [[ ! -f "${POSTGRES_12_DROP_GENERIC_OBJECTS}" ]]; then
  __loge "ERROR: SQL file not found: ${POSTGRES_12_DROP_GENERIC_OBJECTS}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 psql -d "${DBNAME}" -f "${POSTGRES_12_DROP_GENERIC_OBJECTS}"
 __log_finish
}

# Create function to get country
function __createFunctionToGetCountry {
 __log_start
 __logd "Creating function to get country."
 
 # Validate that POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY is defined
 if [[ -z "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY:-}" ]]; then
  __loge "ERROR: POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY variable is not defined"
  __loge "ERROR: This variable should be defined in the calling script"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 # Validate that the SQL file exists
 if [[ ! -f "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}" ]]; then
  __loge "ERROR: SQL file not found: ${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 psql -d "${DBNAME}" -f "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}"
 __log_finish
}

# Create procedures
function __createProcedures {
 __log_start
 __logd "Creating procedures."
 
 # Validate that POSTGRES_22_CREATE_PROC_INSERT_NOTE is defined
 if [[ -z "${POSTGRES_22_CREATE_PROC_INSERT_NOTE:-}" ]]; then
  __loge "ERROR: POSTGRES_22_CREATE_PROC_INSERT_NOTE variable is not defined"
  __loge "ERROR: This variable should be defined in the calling script"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 # Validate that POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT is defined
 if [[ -z "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT:-}" ]]; then
  __loge "ERROR: POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT variable is not defined"
  __loge "ERROR: This variable should be defined in the calling script"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 # Validate that the SQL files exist
 if [[ ! -f "${POSTGRES_22_CREATE_PROC_INSERT_NOTE}" ]]; then
  __loge "ERROR: SQL file not found: ${POSTGRES_22_CREATE_PROC_INSERT_NOTE}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 if [[ ! -f "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}" ]]; then
  __loge "ERROR: SQL file not found: ${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 psql -d "${DBNAME}" -f "${POSTGRES_22_CREATE_PROC_INSERT_NOTE}"
 psql -d "${DBNAME}" -f "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}"
 __log_finish
}

# Organize areas
function __organizeAreas {
 __log_start
 __logd "Organizing areas."
 
 # Validate that POSTGRES_31_ORGANIZE_AREAS is defined
 if [[ -z "${POSTGRES_31_ORGANIZE_AREAS:-}" ]]; then
  __loge "ERROR: POSTGRES_31_ORGANIZE_AREAS variable is not defined"
  __loge "ERROR: This variable should be defined in the calling script"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 # Validate that the SQL file exists
 if [[ ! -f "${POSTGRES_31_ORGANIZE_AREAS}" ]]; then
  __loge "ERROR: SQL file not found: ${POSTGRES_31_ORGANIZE_AREAS}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 psql -d "${DBNAME}" -f "${POSTGRES_31_ORGANIZE_AREAS}"
 __log_finish
}

# Get location notes
function __getLocationNotes {
 __log_start
 __logd "Getting location notes."
 
 # Validate that POSTGRES_32_UPLOAD_NOTE_LOCATION is defined
 if [[ -z "${POSTGRES_32_UPLOAD_NOTE_LOCATION:-}" ]]; then
  __loge "ERROR: POSTGRES_32_UPLOAD_NOTE_LOCATION variable is not defined"
  __loge "ERROR: This variable should be defined in the calling script"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 # Validate that the SQL file exists
 if [[ ! -f "${POSTGRES_32_UPLOAD_NOTE_LOCATION}" ]]; then
  __loge "ERROR: SQL file not found: ${POSTGRES_32_UPLOAD_NOTE_LOCATION}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 
 psql -d "${DBNAME}" -f "${POSTGRES_32_UPLOAD_NOTE_LOCATION}"
 __log_finish
}
