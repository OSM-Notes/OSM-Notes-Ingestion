#!/bin/bash

# Common Functions for OSM-Notes-profile
# This file contains functions used across all scripts in the project.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-17
VERSION="2025-08-17"

# shellcheck disable=SC2317,SC2155,SC2034

# Error codes (common across all scripts)
# shellcheck disable=SC2034
if [[ -z "${ERROR_HELP_MESSAGE:-}" ]]; then declare -r ERROR_HELP_MESSAGE=1; fi
if [[ -z "${ERROR_PREVIOUS_EXECUTION_FAILED:-}" ]]; then declare -r ERROR_PREVIOUS_EXECUTION_FAILED=238; fi
if [[ -z "${ERROR_CREATING_REPORT:-}" ]]; then declare -r ERROR_CREATING_REPORT=239; fi
if [[ -z "${ERROR_MISSING_LIBRARY:-}" ]]; then declare -r ERROR_MISSING_LIBRARY=241; fi
if [[ -z "${ERROR_INVALID_ARGUMENT:-}" ]]; then declare -r ERROR_INVALID_ARGUMENT=242; fi
if [[ -z "${ERROR_LOGGER_UTILITY:-}" ]]; then declare -r ERROR_LOGGER_UTILITY=243; fi
if [[ -z "${ERROR_DOWNLOADING_BOUNDARY_ID_LIST:-}" ]]; then declare -r ERROR_DOWNLOADING_BOUNDARY_ID_LIST=244; fi
if [[ -z "${ERROR_NO_LAST_UPDATE:-}" ]]; then declare -r ERROR_NO_LAST_UPDATE=245; fi
if [[ -z "${ERROR_PLANET_PROCESS_IS_RUNNING:-}" ]]; then declare -r ERROR_PLANET_PROCESS_IS_RUNNING=246; fi
if [[ -z "${ERROR_DOWNLOADING_NOTES:-}" ]]; then declare -r ERROR_DOWNLOADING_NOTES=247; fi
if [[ -z "${ERROR_EXECUTING_PLANET_DUMP:-}" ]]; then declare -r ERROR_EXECUTING_PLANET_DUMP=248; fi
if [[ -z "${ERROR_DOWNLOADING_BOUNDARY:-}" ]]; then declare -r ERROR_DOWNLOADING_BOUNDARY=249; fi
if [[ -z "${ERROR_GEOJSON_CONVERSION:-}" ]]; then declare -r ERROR_GEOJSON_CONVERSION=250; fi
if [[ -z "${ERROR_INTERNET_ISSUE:-}" ]]; then declare -r ERROR_INTERNET_ISSUE=251; fi
if [[ -z "${ERROR_DATA_VALIDATION:-}" ]]; then declare -r ERROR_DATA_VALIDATION=252; fi
if [[ -z "${ERROR_GENERAL:-}" ]]; then declare -r ERROR_GENERAL=255; fi

# Show help function
function __show_help() {
 echo "Common Functions for OSM-Notes-profile"
 echo "This file contains functions used across all scripts in the project."
 echo
 echo "Usage: source bin/commonFunctions.sh"
 echo
 echo "Available functions:"
 echo "  __log*          - Logging functions"
 echo "  __validation    - Input validation"
 echo "  __checkPrereqsCommands - Prerequisites check"
 echo "  Note: __trapOn is now only available in executable scripts, not in this library"
 echo
 echo "Author: Andres Gomez (AngocA)"
 echo "Version: ${VERSION}"
 exit "${ERROR_HELP_MESSAGE}"
}

# Common variables
# shellcheck disable=SC2034
if [[ -z "${GENERATE_FAILED_FILE:-}" ]]; then declare GENERATE_FAILED_FILE=true; fi
# Create a unique failed execution file name based on script name
# Only define if not already set by the calling script
if [[ -z "${FAILED_EXECUTION_FILE:-}" ]]; then
 # Try to get the calling script name from BASH_SOURCE
 if [[ ${#BASH_SOURCE[@]} -gt 1 ]]; then
  # Get the calling script (index 1) instead of this script (index 0)
  SCRIPT_NAME=$(basename "${BASH_SOURCE[1]:-unknown_script}" .sh)
 else
  # Fallback to current script if no calling context
  SCRIPT_NAME=$(basename "${BASH_SOURCE[0]:-unknown_script}" .sh)
 fi
 if [[ -z "${FAILED_EXECUTION_FILE:-}" ]]; then
  declare -r FAILED_EXECUTION_FILE="/tmp/${SCRIPT_NAME}_failed_execution"
 fi
fi
if [[ -z "${PREREQS_CHECKED:-}" ]]; then declare PREREQS_CHECKED=false; fi

# Logger framework
# shellcheck disable=SC2034
if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
 # Try to find the project root by looking for the project directory
 CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
 if [[ "${CURRENT_DIR}" == */bin ]]; then
  SCRIPT_BASE_DIRECTORY="$(cd "${CURRENT_DIR}/.." && pwd)"
 elif [[ "${CURRENT_DIR}" == */lib/osm-common ]]; then
  # We're in lib/osm-common, go up two levels to project root
  SCRIPT_BASE_DIRECTORY="$(cd "${CURRENT_DIR}/../.." && pwd)"
 else
  SCRIPT_BASE_DIRECTORY="$(cd "${CURRENT_DIR}/../.." && pwd)"
 fi
fi

# Load bash logger functions - this provides all logging functionality
if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh" ]]; then
 # shellcheck source=../lib/osm-common/bash_logger.sh
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh"
else
 # If bash_logger.sh is not available, this is a critical error
 # We should fail fast rather than provide fallback implementations
 echo "ERROR: Required logging library not found: ${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh" >&2
 echo "ERROR: This library is essential for proper operation" >&2
 exit "${ERROR_LOGGER_UTILITY}"
fi

# Logger initialization function
# This function initializes the logger system and sets up logging
# Parameters: None
# Returns: None
function __start_logger {
 __logd "Initializing logger system"

 # Set log level from environment if not already set
 if [[ -n "${LOG_LEVEL:-}" ]]; then
  __set_log_level "${LOG_LEVEL}"
  __logd "Logger level set to: ${LOG_LEVEL}"
 fi

 # Set log file if LOG_FILE environment variable is set
 if [[ -n "${LOG_FILE:-}" ]]; then
  __set_log_file "${LOG_FILE}"
  __logi "Logger file set to: ${LOG_FILE}"
 fi

 __logd "Logger system initialized successfully"
}

# Validation function
function __validation {
 __log_start
 if [[ "${1}" == "" ]]; then
  echo "ERROR: ${2}"
  __log_finish
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 __log_finish
}

# Check prerequisites commands
function __checkPrereqsCommands {
 __log_start
 __logd "Checking prerequisites commands."

 # Check if required commands are available
 local MISSING_COMMANDS=()

 # Check basic commands
 for CMD in psql xmllint xsltproc curl wget grep; do
  if ! command -v "${CMD}" > /dev/null 2>&1; then
   MISSING_COMMANDS+=("${CMD}")
  fi
 done

 # Check parallel processing commands
 for CMD in free uptime ulimit prlimit bc timeout; do
  if ! command -v "${CMD}" > /dev/null 2>&1; then
   MISSING_COMMANDS+=("${CMD}")
  fi
 done

 # Check XML processing commands
 if ! command -v xmlstarlet > /dev/null 2>&1; then
  MISSING_COMMANDS+=("xmlstarlet")
 fi

 # Check JSON processing commands
 if ! command -v jq > /dev/null 2>&1; then
  MISSING_COMMANDS+=("jq")
 fi

 # Check geospatial processing commands
 for CMD in ogr2ogr gdalinfo; do
  if ! command -v "${CMD}" > /dev/null 2>&1; then
   MISSING_COMMANDS+=("${CMD}")
  fi
 done

 # Report missing commands
 if [[ ${#MISSING_COMMANDS[@]} -gt 0 ]]; then
  __loge "ERROR: Missing required commands: ${MISSING_COMMANDS[*]}"
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
 local MISSING_FUNCTIONS=()

 # Check logger functions
 for FUNC in __log __logi __loge; do
  if ! declare -f "${FUNC}" > /dev/null 2>&1; then
   MISSING_FUNCTIONS+=("${FUNC}")
  fi
 done

 # Report missing functions
 if [[ ${#MISSING_FUNCTIONS[@]} -gt 0 ]]; then
  __loge "ERROR: Missing required functions: ${MISSING_FUNCTIONS[*]}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 __logi "All required functions are available."
 __log_finish
}

# Drop generic objects
function __dropGenericObjects {
 __log_start
 __logd "Dropping generic objects."

 # Validate that POSTGRES_12_DROP_GENERIC_OBJECTS is defined
 if [[ -z "${POSTGRES_12_DROP_GENERIC_OBJECTS:-}" ]]; then
  __loge "ERROR: POSTGRES_12_DROP_GENERIC_OBJECTS variable is not defined. This variable should be defined in the calling script"
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
  __loge "ERROR: POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY variable is not defined. This variable should be defined in the calling script"
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
  __loge "ERROR: POSTGRES_22_CREATE_PROC_INSERT_NOTE variable is not defined. This variable should be defined in the calling script"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Validate that POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT is defined
 if [[ -z "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT:-}" ]]; then
  __loge "ERROR: POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT variable is not defined. This variable should be defined in the calling script"
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

# Get location notes - Function moved to functionsProcess.sh to avoid duplication
# The correct implementation is in functionsProcess.sh which handles CSV decompression

# Set log file for output redirection
# Parameters:
#   $1 - Log file path
# Returns:
#   0 if successful, 1 if failed
function __set_log_file() {
 __log_start
 local LOG_FILE="${1}"

 if [[ -z "${LOG_FILE}" ]]; then
  __loge "ERROR: Log file path not provided"
  __log_finish
  return 1
 fi

 # Create directory if it doesn't exist
 local LOG_DIR
 LOG_DIR=$(dirname "${LOG_FILE}")
 if [[ ! -d "${LOG_DIR}" ]]; then
  mkdir -p "${LOG_DIR}" 2> /dev/null || {
   __loge "ERROR: Cannot create log directory: ${LOG_DIR}"
   __log_finish
   return 1
  }
 fi

 # Ensure the log file is writable
 touch "${LOG_FILE}" 2> /dev/null || {
  __loge "ERROR: Cannot create or write to log file: ${LOG_FILE}"
  __log_finish
  return 1
 }

 __logd "Log file set to: ${LOG_FILE}"
 __log_finish
 return 0
}
