#!/bin/bash

# Process Planet Notes - Historical data loading from OSM Planet dumps
# Downloads, processes, and loads complete historical notes from OSM Planet files
#
# For detailed documentation, see:
#   - docs/Process_Planet.md (complete workflow, architecture, troubleshooting)
#   - docs/Documentation.md (system overview, data flow)
#   - docs/PostgreSQL_Setup.md (database setup requirements)
#   - bin/README.md (usage examples, parameters)
#
# Quick Reference:
#   Usage: ./processPlanetNotes.sh [--base]
#   --base: Full setup mode (downloads and processes complete planet file)
#   (no flag): Sync mode (processes only new notes since last execution)
#   Examples: export LOG_LEVEL=DEBUG ; ./processPlanetNotes.sh --base
#   Monitor: tail -f /var/log/osm-notes-ingestion/processing/processPlanetNotes.log
#   (or /tmp/osm-notes-ingestion/logs/processing/processPlanetNotes.log in fallback mode)
#
# Error Codes: See docs/Troubleshooting_Guide.md for complete list and solutions
#   1) Help message displayed
#   241) Library or utility missing
#   242) Invalid argument for script invocation
#   243) Logger utility is not available
#   244) IDs list cannot be downloaded
#   249) Error downloading boundary
#
# Modes:
#   --base: Initial setup or complete reload (downloads full planet file, creates base tables)
#   (sync): Regular updates (processes only new notes since last execution)
#
# Database Requirements: See docs/PostgreSQL_Setup.md for complete setup
#   - Database: CREATE DATABASE notes;
#   - Extensions: CREATE EXTENSION postgis; CREATE EXTENSION btree_gist;
#   - Permissions: GRANT USAGE ON SCHEMA public TO user;
#
# Known Issues: See docs/Process_Planet.md#known-issues
#   - Austria: Geometry simplification required for ogr2ogr import
#   - Taiwan: Long row issue, some fields removed
#   - Gaza Strip: ID hardcoded (not at country level)
#
# Dependencies: PostgreSQL, PostGIS, AWK, curl, GNU Parallel, ogr2ogr, lib/osm-common/
#
# For contributing: shellcheck -x -o all processPlanetNotes.sh && shfmt -w -i 1 -sr -bn processPlanetNotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2026-01-07
VERSION="2026-01-07"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with a non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# Early parameter validation before setsid restart
# This ensures invalid parameters are caught immediately
# Error code 242 = Invalid argument (from documentation)
PROCESS_TYPE_EARLY="${1:-}"
if [[ -n "${PROCESS_TYPE_EARLY}" ]] \
 && [[ "${PROCESS_TYPE_EARLY}" != "--base" ]] \
 && [[ "${PROCESS_TYPE_EARLY}" != "--help" ]] \
 && [[ "${PROCESS_TYPE_EARLY}" != "-h" ]]; then
 echo "ERROR: Invalid parameter. It should be:" >&2
 echo " * Empty string, nothing." >&2
 echo " * --base" >&2
 echo " * --help" >&2
 exit 242
fi

# SIGHUP protection: Ignore SIGHUP signal (terminal hangup)
# Note: setsid was considered but disabled as it can interfere with argument passing in some environments
# Using trap '' HUP instead for reliable SIGHUP protection
trap '' HUP

# If all files should be deleted. In case of an error, this could be disabled.
# You can define when calling: export CLEAN=false
# CLEAN is now defined in etc/properties.sh to avoid duplication

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory for the project.
# Only set SCRIPT_BASE_DIRECTORY if not already defined (e.g., when sourced
# from another script)
if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
 declare SCRIPT_BASE_DIRECTORY
 SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
  &> /dev/null && pwd)"
 readonly SCRIPT_BASE_DIRECTORY
fi

# Loads the global properties.
# All database connections must be controlled by the properties file.
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

# Mask for the files and directories.
umask 0000

# Only set BASENAME if not already defined (e.g., in test environment)
if [[ -z "${BASENAME:-}" ]]; then
 declare BASENAME
 BASENAME=$(basename -s .sh "${0}")
 readonly BASENAME
fi

# Set PostgreSQL application name for monitoring
# This allows monitoring tools to identify which script is using the database
# Only set if not already defined (e.g., when sourced from another script)
if [[ -z "${PGAPPNAME:-}" ]]; then
 export PGAPPNAME="${BASENAME}"
fi

# Load path configuration functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/pathConfigurationFunctions.sh"

# Initialize all directories (logs, temp, locks)
# Only if not already set (e.g., when sourced from another script)
if [[ -z "${TMP_DIR:-}" ]]; then
 __init_directories "${BASENAME}"
fi

# Type of process to run in the script.
# Only set PROCESS_TYPE if not already defined (e.g., when sourced from
# another script that already defines it as readonly)
# Check if variable is already declared using declare -p
if ! declare -p PROCESS_TYPE > /dev/null 2>&1; then
 # Variable is not declared, safe to declare it as readonly
 declare -r PROCESS_TYPE=${1:-}
fi

# Total notes count.
declare -i TOTAL_NOTES=-1

# Planet notes file configuration.
# (Declared in processPlanetFunctions.sh)

# PostgreSQL SQL script files.
# (Declared in processPlanetFunctions.sh)

# Enable failed execution file generation
export GENERATE_FAILED_FILE=true

# Failed execution file
# This variable is now defined in lib/osm-common/commonFunctions.sh to avoid duplication

# CLEAN is now defined in etc/properties.sh, no need to declare it here

# Files for countries and maritimes processing.
# (Declared in processPlanetFunctions.sh)

# Error codes are already defined in functionsProcess.sh

# Location of the common functions.

# AWK extraction scripts for Planet format (used by parallel processing).
# (Declared in processPlanetFunctions.sh)

# Control variables for functionsProcess.sh
export ONLY_EXECUTION="no"

# Global exit code variable for trap functions
export SCRIPT_EXIT_CODE=0

###########
# FUNCTIONS

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Local wrapper for __common_create_failed_marker from alertFunctions.sh
# This adds the script-specific parameters (script name and failed file path)
# to the common alert function.
#
# Parameters:
#   $1 - error_code: The error code that triggered the failure
#   $2 - error_message: Description of what failed
#   $3 - required_action: (Optional) What action is needed to fix it
#
# Note: This wrapper allows existing code to continue using the simple 3-parameter
# interface while calling the common 5-parameter function in alertFunctions.sh
function __create_failed_marker() {
 # Call the common alert function with script-specific parameters
 # Format: script_name, error_code, error_message, required_action, failed_file
 __common_create_failed_marker "processPlanetNotes" "${1}" "${2}" \
  "${3:-Verify the issue and fix it manually}" "${FAILED_EXECUTION_FILE}"
}

# Load Planet-specific functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/processPlanetFunctions.sh"

# Load validation functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"

# Load error handling functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh"

# Load alert functions for failed execution notifications
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/alertFunctions.sh"

# Load API-specific functions (includes POSTGRES_12_DROP_API_TABLES)
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/processAPIFunctions.sh"

# Load process functions (includes GEOJSON_TEST and other variables)
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"

# Load parallel processing functions (includes __splitXmlForParallelSafe implementation)
# MUST be loaded AFTER functionsProcess.sh to override wrapper functions
# shellcheck disable=SC1091,SC1094
# Source file may have complex parsing but is valid bash
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/parallelProcessingFunctions.sh"

# Function to handle cleanup on exit respecting CLEAN flag
function __cleanup_on_exit() {
 __log_start
 # Capture exit code immediately before any operations
 local LAST_EXIT_CODE=$?
 local EXIT_CODE="${SCRIPT_EXIT_CODE:-${LAST_EXIT_CODE}}"

 # Skip cleanup if we're just showing help
 if [[ "${SHOWING_HELP:-false}" == "true" ]]; then
  __logd "Help mode detected, skipping cleanup"
  __log_finish
  # Use the correct exit code for help
  exit "${ERROR_HELP_MESSAGE}"
 fi

 # Skip cleanup for parameter validation errors (they should exit immediately)
 if [[ "${EXIT_CODE}" == "${ERROR_INVALID_ARGUMENT}" ]]; then
  __logd "Parameter validation error detected, exiting immediately with code ${EXIT_CODE}"
  __log_finish
  exit "${EXIT_CODE}"
 fi

 # Only clean if CLEAN is true and this is an error exit (non-zero)
 if [[ "${CLEAN}" == "true" ]] && [[ ${EXIT_CODE} -ne 0 ]] && [[ -n "${TMP_DIR:-}" ]]; then
  __logw "Error detected (exit code: ${EXIT_CODE}), cleaning up temporary directory: ${TMP_DIR}"
  if [[ -d "${TMP_DIR}" ]]; then
   rm -rf "${TMP_DIR}" 2> /dev/null || true
   __logi "Temporary directory cleaned up: ${TMP_DIR}"
  fi
 elif [[ "${CLEAN}" == "false" ]] && [[ ${EXIT_CODE} -ne 0 ]]; then
  __logw "Error detected (exit code: ${EXIT_CODE}), but CLEAN=false - preserving temporary files in: ${TMP_DIR:-}"
 fi

 __log_finish
 exit "${EXIT_CODE}"
}

# Set trap to handle cleanup on script exit only (not function exit)
trap '__cleanup_on_exit' EXIT

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 __logi "=== STARTING PLANET PREREQUISITES CHECK ==="
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--base" ]] \
  && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:" >&2
  echo " * Empty string, nothing." >&2
  echo " * --base" >&2
  echo " * --help" >&2
  __loge "ERROR: Invalid parameter."
  export SCRIPT_EXIT_CODE="${ERROR_INVALID_ARGUMENT}"
  __log_finish
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set -e
 # Checks prereqs.
 __checkPrereqsCommands

 ## Validate SQL script files using centralized validation
 __logi "Validating SQL script files..."

 # Create array of SQL files to validate
 local SQL_FILES=(
  "${POSTGRES_11_DROP_SYNC_TABLES}"
  "${POSTGRES_12_DROP_API_TABLES}"
  "${POSTGRES_13_DROP_BASE_TABLES}"
  "${POSTGRES_21_CREATE_ENUMS}"
  "${POSTGRES_22_CREATE_BASE_TABLES}"
  "${POSTGRES_23_CREATE_CONSTRAINTS}"
  "${POSTGRES_24_CREATE_SYNC_TABLES}"
  "${POSTGRES_31_VACUUM_AND_ANALYZE}"
  "${POSTGRES_25_CREATE_PARTITIONS}"
  "${POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES}"
  "${POSTGRES_42_CONSOLIDATE_PARTITIONS}"
 )

 # Validate each SQL file
 for SQL_FILE in "${SQL_FILES[@]}"; do
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __validate_sql_structure "${SQL_FILE}"; then
   VALIDATION_RESULT=$?
  else
   VALIDATION_RESULT=0
  fi
  if [[ "${VALIDATION_RESULT:-0}" -ne 0 ]]; then
   __loge "ERROR: SQL file validation failed: ${SQL_FILE}"
   export SCRIPT_EXIT_CODE="${ERROR_MISSING_LIBRARY}"
   __log_finish
   return "${ERROR_MISSING_LIBRARY}"
  fi
  unset VALIDATION_RESULT
 done

 ## Validate XML schema file (only if validation is enabled)
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  __logi "Validating XML schema file..."
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __validate_input_file "${XMLSCHEMA_PLANET_NOTES}" "XML schema file"; then
   VALIDATION_RESULT=$?
  else
   VALIDATION_RESULT=0
  fi
  if [[ "${VALIDATION_RESULT:-0}" -ne 0 ]]; then
   __loge "ERROR: XML schema file validation failed: ${XMLSCHEMA_PLANET_NOTES}"
   __loge "To skip validation, set: export SKIP_XML_VALIDATION=true"
   export SCRIPT_EXIT_CODE="${ERROR_MISSING_LIBRARY}"
   __log_finish
   return "${ERROR_MISSING_LIBRARY}"
  fi
  unset VALIDATION_RESULT
 fi

 # Validate dates in XML files if they exist (only if validation is enabled)
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  __logi "Validating dates in XML files..."
  if [[ -f "${PLANET_NOTES_FILE}" ]]; then
   # shellcheck disable=SC2310
   # Function is invoked in if condition intentionally
   if ! __validate_xml_dates "${PLANET_NOTES_FILE}"; then
    VALIDATION_RESULT=$?
   else
    VALIDATION_RESULT=0
   fi
   if [[ "${VALIDATION_RESULT:-0}" -ne 0 ]]; then
    __loge "ERROR: XML date validation failed: ${PLANET_NOTES_FILE}"
    export SCRIPT_EXIT_CODE="${ERROR_MISSING_LIBRARY}"
    __log_finish
    return "${ERROR_MISSING_LIBRARY}"
   fi
   unset VALIDATION_RESULT
  fi
 else
  __logw "Skipping date validation (SKIP_XML_VALIDATION=true)"
 fi

 ## Validate updateCountries.sh script availability
 __logi "Validating updateCountries.sh script availability..."
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __validate_input_file "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh" "updateCountries script"; then
  VALIDATION_RESULT=$?
 else
  VALIDATION_RESULT=0
 fi
 if [[ "${VALIDATION_RESULT:-0}" -ne 0 ]]; then
  __loge "ERROR: updateCountries.sh script validation failed"
  export SCRIPT_EXIT_CODE="${ERROR_MISSING_LIBRARY}"
  __log_finish
  return "${ERROR_MISSING_LIBRARY}"
 fi
 unset VALIDATION_RESULT

 # CSV files are generated during processing, no need to validate them here
 # as they will be created by __processPlanetXmlPart function

 ## Validate JSON schema files
 __logi "Validating JSON schema files..."
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __validate_input_file "${JSON_SCHEMA_OVERPASS}" "JSON schema file"; then
  VALIDATION_RESULT=$?
 else
  VALIDATION_RESULT=0
 fi
 if [[ "${VALIDATION_RESULT:-0}" -ne 0 ]]; then
  __loge "ERROR: JSON schema file validation failed: ${JSON_SCHEMA_OVERPASS}"
  export SCRIPT_EXIT_CODE="${ERROR_MISSING_LIBRARY}"
  __log_finish
  return "${ERROR_MISSING_LIBRARY}"
 fi
 unset VALIDATION_RESULT

 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __validate_input_file "${JSON_SCHEMA_GEOJSON}" "GeoJSON schema file"; then
  VALIDATION_RESULT=$?
 else
  VALIDATION_RESULT=0
 fi
 if [[ "${VALIDATION_RESULT:-0}" -ne 0 ]]; then
  __loge "ERROR: GeoJSON schema file validation failed: ${JSON_SCHEMA_GEOJSON}"
  export SCRIPT_EXIT_CODE="${ERROR_MISSING_LIBRARY}"
  __log_finish
  return "${ERROR_MISSING_LIBRARY}"
 fi
 unset VALIDATION_RESULT

 ## Validate test files
 __logi "Validating JSON schema files..."
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __validate_input_file "${GEOJSON_TEST}" "GeoJSON test file"; then
  VALIDATION_RESULT=$?
 else
  VALIDATION_RESULT=0
 fi
 if [[ "${VALIDATION_RESULT:-0}" -ne 0 ]]; then
  __loge "ERROR: GeoJSON test file validation failed: ${GEOJSON_TEST}"
  export SCRIPT_EXIT_CODE="${ERROR_MISSING_LIBRARY}"
  __log_finish
  return "${ERROR_MISSING_LIBRARY}"
 fi
 unset VALIDATION_RESULT

 ## Validate backup files if they exist
 # Resolve note location backup file (download from GitHub if not found locally)
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __resolve_note_location_backup 2> /dev/null; then
  RESOLVE_RESULT=$?
 else
  RESOLVE_RESULT=0
 fi
 if [[ "${RESOLVE_RESULT:-0}" -eq 0 ]] || [[ -f "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}" ]]; then
  __logi "Validating backup files..."
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __validate_input_file "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}" "Backup file"; then
   VALIDATION_RESULT=$?
  else
   VALIDATION_RESULT=0
  fi
  if [[ "${VALIDATION_RESULT:-0}" -ne 0 ]]; then
   __loge "ERROR: Backup file validation failed: ${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}"
   export SCRIPT_EXIT_CODE="${ERROR_MISSING_LIBRARY}"
   __log_finish
   return "${ERROR_MISSING_LIBRARY}"
  fi
  unset VALIDATION_RESULT
 fi
 unset RESOLVE_RESULT

 if [[ -f "${POSTGRES_32_UPLOAD_NOTE_LOCATION}" ]]; then
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __validate_sql_structure "${POSTGRES_32_UPLOAD_NOTE_LOCATION}"; then
   VALIDATION_RESULT=$?
  else
   VALIDATION_RESULT=0
  fi
  if [[ "${VALIDATION_RESULT:-0}" -ne 0 ]]; then
   __loge "ERROR: Upload SQL file validation failed: ${POSTGRES_32_UPLOAD_NOTE_LOCATION}"
   export SCRIPT_EXIT_CODE="${ERROR_MISSING_LIBRARY}"
   __log_finish
   return "${ERROR_MISSING_LIBRARY}"
  fi
  unset VALIDATION_RESULT
 fi

 __checkPrereqs_functions
 __logi "=== PLANET PREREQUISITES CHECK COMPLETED SUCCESSFULLY ==="
 set -e
 __log_finish
}

# Drop sync tables.
##
# Drops sync tables used for Planet note processing
# Executes SQL script to drop temporary sync tables (notes_sync, note_comments_sync,
# note_comments_text_sync) used during Planet processing. Sets max_threads before
# dropping to optimize performance for large tables.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Tables dropped successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - Sync tables dropped successfully
#   Non-zero: psql command failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (check psql error message)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - MAX_THREADS: Maximum threads for parallel operations (optional)
#     - POSTGRES_11_DROP_SYNC_TABLES: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to set max_threads configuration
#   - Executes psql to drop sync tables (notes_sync, note_comments_sync, etc.)
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Sets app.max_threads before dropping (optimizes for large tables)
#   - Drops all sync tables and dependent objects (CASCADE)
#   - Used during cleanup or before recreating sync tables
#   - Part of Planet processing workflow (drops sync tables before base mode or sync mode)
#   - Sync tables are temporary and can be safely dropped
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_11_DROP_SYNC_TABLES="/path/to/drop_sync_tables.sql"
#   __dropSyncTables
#
# Related: __createSyncTables() (creates sync tables)
# Related: __dropBaseTables() (drops base tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
##
# Drops sync tables used for Planet processing
# Executes SQL script to drop temporary sync tables (notes_sync, note_comments_sync,
# note_comments_text_sync) and all partitions. Sets max_threads before dropping to
# optimize performance for large tables. Used during cleanup or before recreating sync tables.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Sync tables dropped successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - Sync tables dropped successfully
#   Non-zero: psql command failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (check psql error message)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - MAX_THREADS: Maximum threads for parallel operations (optional)
#     - POSTGRES_11_DROP_SYNC_TABLES: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to set max_threads configuration
#   - Executes psql to drop sync tables and all partitions
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Sets app.max_threads before dropping (optimizes for large tables)
#   - Drops all sync tables and partitions (CASCADE)
#   - Used during cleanup or before recreating sync tables
#   - Part of Planet processing workflow (drops after consolidation)
#   - Sync tables are temporary (used only during Planet processing)
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_11_DROP_SYNC_TABLES="/path/to/drop_sync_tables.sql"
#   export MAX_THREADS=4
#   __dropSyncTables
#
# Related: __createSyncTables() (creates sync tables)
# Related: __dropBaseTables() (drops base tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
##
# Drops sync tables used for Planet note processing
# Executes SQL script to drop temporary sync tables (notes_sync, note_comments_sync,
# note_comments_text_sync) and all their partitions. Sets max_threads before dropping
# to optimize performance for large tables. Used after data is moved to base tables.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Sync tables dropped successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - Sync tables dropped successfully
#   Non-zero: psql command failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (check psql error message)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - MAX_THREADS: Maximum threads for parallel operations (optional)
#     - POSTGRES_11_DROP_SYNC_TABLES: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to set max_threads configuration
#   - Executes psql to drop sync tables and all partitions
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Sets app.max_threads before dropping (optimizes for large tables)
#   - Drops all sync tables and their partitions (CASCADE)
#   - Used after data is moved from sync tables to base tables
#   - Part of Planet processing workflow (drops after consolidation)
#   - WARNING: This deletes all data in sync tables (should be empty after move)
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_11_DROP_SYNC_TABLES="/path/to/drop_sync_tables.sql"
#   export MAX_THREADS=8
#   __dropSyncTables
#
# Related: __createSyncTables() (creates sync tables)
# Related: __moveSyncToMain() (moves data from sync to base tables)
# Related: __dropBaseTables() (drops base tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __dropSyncTables {
 __log_start
 __logi "=== DROPPING SYNC TABLES ==="
 __logd "Executing SQL file: ${POSTGRES_11_DROP_SYNC_TABLES}"
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -c "SET app.max_threads = '${MAX_THREADS}';" -f "${POSTGRES_11_DROP_SYNC_TABLES}"
 __logi "=== SYNC TABLES DROPPED SUCCESSFULLY ==="
 __log_finish
}

##
# Drops API-related tables from database
# Executes SQL script to drop tables used for API notes processing.
# Sets max_threads before dropping to optimize performance for large tables.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Tables dropped successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - API tables dropped successfully
#   Non-zero: psql command failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (check psql error message)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - MAX_THREADS: Maximum threads for parallel operations (optional)
#     - POSTGRES_12_DROP_API_TABLES: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to set max_threads configuration
#   - Executes psql to drop API tables (notes_api, note_comments_api, etc.)
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Sets app.max_threads before dropping (optimizes for large tables)
#   - Drops all API-related tables and dependent objects (CASCADE)
#   - Used during cleanup or before recreating API tables
#   - Part of Planet processing workflow (drops API tables before base mode)
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_12_DROP_API_TABLES="/path/to/drop_api_tables.sql"
#   __dropApiTables
#
# Related: __createBaseTables() (creates base tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __dropApiTables {
 __log_start
 __logi "=== DROPPING API TABLES ==="
 __logd "Executing SQL file: ${POSTGRES_12_DROP_API_TABLES}"
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -c "SET app.max_threads = '${MAX_THREADS}';" -f "${POSTGRES_12_DROP_API_TABLES}"
 __logi "=== API TABLES DROPPED SUCCESSFULLY ==="
 __log_finish
}

##
# Drops base tables that hold complete note history
# Executes SQL script to drop base tables (notes, note_comments, note_comments_text)
# and all dependent objects. Used during base mode to start with clean database.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Tables dropped successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - Base tables dropped successfully
#   Non-zero: psql command failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_13_DROP_BASE_TABLES: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to drop base tables (notes, note_comments, note_comments_text)
#   - Drops all dependent objects (indexes, constraints, sequences, etc.)
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Drops all base tables and dependent objects (CASCADE)
#   - Used during base mode to start with clean database
#   - Part of Planet processing workflow (drops before creating new base tables)
#   - WARNING: This deletes all note history data
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_13_DROP_BASE_TABLES="/path/to/drop_base_tables.sql"
#   __dropBaseTables
#
# Related: __createBaseTables() (creates base tables)
# Related: __dropSyncTables() (drops sync tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __dropBaseTables {
 __log_start
 __logi "=== DROPPING BASE TABLES ==="
 __logd "Executing SQL file: ${POSTGRES_13_DROP_BASE_TABLES}"
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_13_DROP_BASE_TABLES}"
 __logi "=== BASE TABLES DROPPED SUCCESSFULLY ==="
 __log_finish
}

##
# Creates base tables that hold complete note history
# Creates ENUM types, base tables (notes, note_comments, note_comments_text), and constraints
# in sequence. These tables store the complete history of all OSM notes. Must be executed
# in order: enums first, then tables, then constraints.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - All tables created successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - Base tables created successfully
#   Non-zero: psql command failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - All SQL scripts executed successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_21_CREATE_ENUMS: Path to ENUM creation SQL script (required)
#     - POSTGRES_22_CREATE_BASE_TABLES: Path to table creation SQL script (required)
#     - POSTGRES_23_CREATE_CONSTRAINTS: Path to constraint creation SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to create ENUM types (note_status_enum, note_action_enum)
#   - Executes psql to create base tables (notes, note_comments, note_comments_text)
#   - Executes psql to create constraints (primary keys, foreign keys, indexes, etc.)
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Must be executed in sequence: enums -> tables -> constraints
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Creates complete schema for storing note history
#   - Used during base mode to set up database structure
#   - Part of Planet processing workflow (creates before loading Planet data)
#   - Base tables store complete history (all notes, all comments)
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_21_CREATE_ENUMS="/path/to/create_enums.sql"
#   export POSTGRES_22_CREATE_BASE_TABLES="/path/to/create_tables.sql"
#   export POSTGRES_23_CREATE_CONSTRAINTS="/path/to/create_constraints.sql"
#   __createBaseTables
#
# Related: __dropBaseTables() (drops base tables)
# Related: __createSyncTables() (creates sync tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __createBaseTables {
 __log_start
 __logi "=== CREATING BASE TABLES ==="
 __logd "Executing SQL files:"
 __logd "  Enums: ${POSTGRES_21_CREATE_ENUMS}"
 __logd "  Base tables: ${POSTGRES_22_CREATE_BASE_TABLES}"
 __logd "  Constraints: ${POSTGRES_23_CREATE_CONSTRAINTS}"
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_21_CREATE_ENUMS}"

 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_22_CREATE_BASE_TABLES}"

 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_23_CREATE_CONSTRAINTS}"
 __logi "=== BASE TABLES CREATED SUCCESSFULLY ==="
 __log_finish
}

##
# Creates sync tables for receiving Planet note history
# Creates temporary sync tables (notes_sync, note_comments_sync, note_comments_text_sync)
# that receive the complete Planet note history. After processing, only new notes are kept
# and moved to base tables. Used during Planet processing workflow.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Sync tables created successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - Sync tables created successfully
#   Non-zero: psql command failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_24_CREATE_SYNC_TABLES: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to create sync tables (notes_sync, note_comments_sync, note_comments_text_sync)
#   - Creates temporary tables with same structure as base tables
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Creates temporary tables for receiving Planet data
#   - Sync tables have same structure as base tables
#   - Used during Planet processing: data loaded into sync tables, then filtered
#   - After processing, only new notes are moved to base tables
#   - Part of Planet processing workflow (creates before loading Planet data)
#   - Sync tables are dropped after consolidation (see __dropSyncTables)
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_24_CREATE_SYNC_TABLES="/path/to/create_sync_tables.sql"
#   __createSyncTables
#
# Related: __dropSyncTables() (drops sync tables)
# Related: __createBaseTables() (creates base tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
##
# Creates sync tables for receiving Planet note history
# Creates temporary sync tables (notes_sync, note_comments_sync, note_comments_text_sync)
# that receive the complete Planet note history. After processing, only new notes are kept
# and moved to base tables. Used during Planet processing workflow.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Sync tables created successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - Sync tables created successfully
#   Non-zero: psql command failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_24_CREATE_SYNC_TABLES: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to create sync tables (notes_sync, note_comments_sync, note_comments_text_sync)
#   - Writes log messages to stderr
#   - No file or network operations
#
# Notes:
#   - Sync tables are temporary and receive Planet note history
#   - After processing, only new notes are kept and moved to base tables
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Part of Planet processing workflow (creates before loading Planet data)
#   - Sync tables are dropped after data is moved to base tables
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_24_CREATE_SYNC_TABLES="/path/to/create_sync_tables.sql"
#   __createSyncTables
#
# Related: __dropSyncTables() (drops sync tables)
# Related: __createBaseTables() (creates base tables)
# Related: __moveSyncToMain() (moves data from sync to base tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __createSyncTables {
 __log_start
 __logi "Creating tables."
 # shellcheck disable=SC2097,SC2098
 # PGAPPNAME is set at script initialization and passed to psql
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_24_CREATE_SYNC_TABLES}"
 __log_finish
}

# Clean files and tables.
##
# Cleans up partial processing files and temporary import table
# Removes temporary files created during boundary processing (countries, maritimes)
# and drops the temporary import table if CLEAN environment variable is set to true.
# Used for cleanup after boundary processing operations.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Always returns 0 (success) - cleanup function never fails
#
# Error codes:
#   None - Function always succeeds, only performs cleanup operations
#
# Error conditions:
#   Always succeeds - File removal and table drop failures are handled gracefully
#
# Context variables:
#   Reads:
#     - CLEAN: If "true", removes files and drops table; if "false" or unset, skips cleanup (optional, default: false)
#     - COUNTRIES_FILE: Path to countries file (required)
#     - MARITIMES_FILE: Path to maritimes file (required)
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Removes countries and maritimes files if CLEAN=true
#   - Executes psql to drop import table if CLEAN=true
#   - Writes log messages to stderr
#   - No network operations
#
# Notes:
#   - Only performs cleanup if CLEAN environment variable is "true"
#   - Uses rm -f to ignore missing files (non-fatal)
#   - Drops import table using DROP TABLE IF EXISTS (safe if table doesn't exist)
#   - Safe to call multiple times (idempotent)
#   - Used for cleanup after boundary processing (countries/maritimes)
#   - Import table is temporary and used during boundary import operations
#
# Example:
#   export CLEAN=true
#   export COUNTRIES_FILE="/tmp/countries"
#   export MARITIMES_FILE="/tmp/maritimes"
#   export DBNAME="osm_notes"
#   __cleanPartial
#
# Related: __cleanNotesFiles() (cleans note processing files)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __cleanPartial {
 __log_start
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -f "${COUNTRIES_FILE}" "${MARITIMES_FILE}"
  __logw "Dropping import table."
  echo "DROP TABLE IF EXISTS import" | PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}"
 fi
 __log_finish
}

##
# Performs VACUUM and ANALYZE on all database tables
# Executes PostgreSQL VACUUM and ANALYZE commands to reclaim storage space and update
# table statistics. Improves query performance by updating planner statistics and
# removing dead tuples. Should be run periodically after large data loads.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - VACUUM and ANALYZE completed successfully
#   Non-zero: Failure - psql command failed
#
# Error codes:
#   0: Success - VACUUM and ANALYZE executed successfully
#   Non-zero: psql command failed (SQL error, connection error, etc.)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_31_VACUUM_AND_ANALYZE: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql to run VACUUM (reclaims storage, removes dead tuples)
#   - Executes psql to run ANALYZE (updates table statistics for query planner)
#   - Writes log messages to stderr
#   - No file or network operations
#   - May lock tables during VACUUM (depends on PostgreSQL version and options)
#
# Notes:
#   - VACUUM reclaims storage space and removes dead tuples
#   - ANALYZE updates table statistics for query planner optimization
#   - Should be run after large data loads or deletions
#   - Can take significant time on large tables
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Part of database maintenance workflow
#   - Improves query performance by updating planner statistics
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_31_VACUUM_AND_ANALYZE="/path/to/vacuum_analyze.sql"
#   __analyzeAndVacuum
#
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __analyzeAndVacuum {
 __log_start
 # shellcheck disable=SC2097,SC2098
 # PGAPPNAME is set at script initialization and passed to psql
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_31_VACUUM_AND_ANALYZE}"
 __log_finish
}

##
# Loads new notes and comments from sync tables into partition tables
# Loads data from CSV files (OUTPUT_NOTES_FILE, OUTPUT_NOTE_COMMENTS_FILE) into
# partition tables using envsubst for file path substitution. Used during parallel
# processing to load data from processed XML parts into database partitions.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Data loaded successfully
#   Non-zero: Failure - psql command failed (SQL error, connection error, etc.)
#
# Error codes:
#   0: Success - Data loaded successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (SQL syntax error, connection error, file not found, etc.)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - OUTPUT_NOTES_FILE: Path to notes CSV file (required, exported)
#     - OUTPUT_NOTE_COMMENTS_FILE: Path to note comments CSV file (required, exported)
#     - POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES: Path to SQL script template (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - OUTPUT_NOTES_FILE: Exported for envsubst substitution
#     - OUTPUT_NOTE_COMMENTS_FILE: Exported for envsubst substitution
#   Modifies: None
#
# Side effects:
#   - Executes psql to load CSV data into partition tables
#   - Uses envsubst to substitute file paths in SQL template
#   - Writes log messages to stderr
#   - No file or network operations
#   - Database operations: INSERT into partition tables
#
# Notes:
#   - Uses envsubst to substitute $OUTPUT_NOTES_FILE and $OUTPUT_NOTE_COMMENTS_FILE in SQL template
#   - SQL template must contain ${OUTPUT_NOTES_FILE} and ${OUTPUT_NOTE_COMMENTS_FILE} placeholders
#   - Used during parallel processing to load data from processed XML parts
#   - Part of parallel processing workflow (called by __processPlanetXmlPart)
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - CSV files must exist and be readable
#
# Example:
#   export OUTPUT_NOTES_FILE="/tmp/notes.csv"
#   export OUTPUT_NOTE_COMMENTS_FILE="/tmp/comments.csv"
#   export POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES="/path/to/load_partitioned.sql"
#   __loadSyncNotes
#
# Related: __processPlanetXmlPart() (processes XML part and calls this function)
# Related: __processPlanetNotesWithParallel() (orchestrates parallel processing)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __loadSyncNotes {
 __log_start
 # Loads the data in the database.
 export OUTPUT_NOTES_FILE
 export OUTPUT_NOTE_COMMENTS_FILE
 # shellcheck disable=SC2016
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$OUTPUT_NOTES_FILE,$OUTPUT_NOTE_COMMENTS_FILE' \
   < "${POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES}" || true)"
 __log_finish
}

##
# Removes duplicate notes and comments from sync tables
# Removes notes and comments from sync tables that already exist in main tables.
# Uses database locking (put_lock/remove_lock) to ensure single execution.
# Creates temporary tables (notes_sync_no_duplicates, note_comments_sync_no_duplicates),
# filters duplicates, and updates sequences. Part of Planet sync workflow.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Duplicates removed successfully
#   Non-zero: Failure - Database lock failed, SQL execution failed, or sequence update failed
#
# Error codes:
#   0: Success - Duplicates removed successfully
#   Non-zero: Failure - Lock acquisition failed, SQL execution failed, or sequence update failed
#
# Error conditions:
#   0: Success - All operations completed successfully
#   Non-zero: Lock acquisition failed - put_lock() failed
#   Non-zero: SQL execution failed - remove_duplicates SQL script failed
#   Non-zero: Lock removal failed - remove_lock() failed
#   Non-zero: Sequence update failed - comments sequence SQL script failed
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - PROCESS_ID: Process ID (generated from $$, exported)
#     - POSTGRES_43_REMOVE_DUPLICATES: Path to SQL script template (required)
#     - POSTGRES_44_COMMENTS_SEQUENCE: Path to SQL script for sequence update (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - PROCESS_ID: Process ID (exported for envsubst substitution)
#   Modifies:
#     - Creates temporary tables (notes_sync_no_duplicates, note_comments_sync_no_duplicates)
#     - Drops and recreates sync tables (notes_sync, note_comments_sync)
#     - Updates sequences in database
#
# Side effects:
#   - Acquires database lock (put_lock)
#   - Executes SQL to remove duplicates (creates filtered tables, drops old sync tables)
#   - Releases database lock (remove_lock)
#   - Updates comment sequences
#   - Writes log messages to stderr
#   - Database operations: CREATE TABLE, DROP TABLE, ALTER TABLE, UPDATE sequences
#   - No file or network operations
#
# Notes:
#   - Uses database locking to ensure single execution (prevents concurrent duplicate removal)
#   - Process ID is generated from $$ (shell PID) and used for locking
#   - Creates temporary tables with filtered data (no duplicates)
#   - Replaces sync tables with filtered versions
#   - Updates sequences to handle re-execution scenarios (some objects may already exist)
#   - Critical function: Part of Planet sync workflow
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Uses envsubst to substitute PROCESS_ID in SQL template
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_43_REMOVE_DUPLICATES="/path/to/remove_duplicates.sql"
#   export POSTGRES_44_COMMENTS_SEQUENCE="/path/to/comments_sequence.sql"
#   __removeDuplicates
#
# Related: put_lock() (PostgreSQL function for locking)
# Related: remove_lock() (PostgreSQL function for unlocking)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
##
# Removes duplicate notes and comments from sync tables
# Removes notes and comments from sync tables that already exist in main tables.
# Uses database locking (put_lock/remove_lock) to ensure single execution.
# Creates temporary tables (notes_sync_no_duplicates, note_comments_sync_no_duplicates),
# filters duplicates, and updates sequences. Part of Planet sync workflow.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Duplicates removed successfully
#   Non-zero: Failure - Database lock failed, SQL execution failed, or sequence update failed
#
# Error codes:
#   0: Success - Duplicates removed and sequences updated successfully
#   Non-zero: Lock acquisition failed - put_lock failed
#   Non-zero: SQL execution failed - envsubst or psql failed
#   Non-zero: Lock removal failed - remove_lock failed
#   Non-zero: Sequence update failed - psql failed
#
# Error conditions:
#   0: Success - All operations completed successfully
#   Non-zero: Lock acquisition failed - Cannot acquire database lock
#   Non-zero: SQL execution failed - Duplicate removal SQL failed
#   Non-zero: Lock removal failed - Cannot remove database lock
#   Non-zero: Sequence update failed - Sequence update SQL failed
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_43_REMOVE_DUPLICATES: Path to SQL script template (required)
#     - POSTGRES_44_COMMENTS_SEQUENCE: Path to SQL script for sequence update (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - PROCESS_ID: Process ID (exported, used in SQL)
#   Modifies:
#     - Creates temporary tables (notes_sync_no_duplicates, note_comments_sync_no_duplicates)
#     - Removes duplicates from sync tables
#     - Updates sequences for note_comments
#
# Side effects:
#   - Generates process ID (PID)
#   - Acquires database lock (put_lock)
#   - Creates temporary tables for duplicate filtering
#   - Removes duplicates from sync tables (via SQL script)
#   - Updates sequences for note_comments
#   - Removes database lock (remove_lock)
#   - Writes log messages to stderr
#   - Database operations: Lock acquisition, duplicate removal, sequence update
#   - No file or network operations
#
# Notes:
#   - Uses database locking to prevent concurrent duplicate removal
#   - Creates temporary tables to filter duplicates before removal
#   - Updates sequences after duplicate removal (ensures correct sequence values)
#   - Critical function: Part of Planet sync workflow
#   - Must be called before moving data from sync to main tables
#   - Uses envsubst for process_id substitution in SQL template
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_43_REMOVE_DUPLICATES="/path/to/remove_duplicates.sql"
#   export POSTGRES_44_COMMENTS_SEQUENCE="/path/to/update_sequence.sql"
#   __removeDuplicates
#   # Removes duplicates and updates sequences
#
# Related: __moveSyncToMain() (moves data from sync to main tables)
# Related: __loadSyncNotes() (loads data into sync tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __removeDuplicates {
 __log_start
 PROCESS_ID="${$}"
 echo "CALL put_lock('${PROCESS_ID}'::VARCHAR)" | PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" \
  -v ON_ERROR_STOP=1
 __logi "Lock put ${PROCESS_ID}"

 export PROCESS_ID
 # shellcheck disable=SC2016,SC2154
 # POSTGRES_43_REMOVE_DUPLICATES is defined in processPlanetFunctions.sh
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$PROCESS_ID' < "${POSTGRES_43_REMOVE_DUPLICATES}" || true)"

 echo "CALL remove_lock('${PROCESS_ID}'::VARCHAR)" | PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" \
  -v ON_ERROR_STOP=1
 # Puts the sequence. When reexecuting, some objects already exist.
 __logi "Lock removed ${PROCESS_ID}"

 # shellcheck disable=SC2097,SC2098,SC2154
 # PGAPPNAME is set at script initialization and passed to psql
 # POSTGRES_44_COMMENTS_SEQUENCE is defined in processPlanetFunctions.sh
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -f "${POSTGRES_44_COMMENTS_SEQUENCE}"
 __log_finish
}

##
# Loads text comments from CSV file into database
# Loads text comments from CSV file (OUTPUT_TEXT_COMMENTS_FILE) into database using
# envsubst for file path substitution. Handles existing objects gracefully (some
# objects may already exist). Part of Planet processing workflow.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Text comments loaded successfully
#   Non-zero: Failure - psql command failed (SQL error, connection error, etc.)
#
# Error codes:
#   0: Success - Text comments loaded successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (SQL syntax error, connection error, file not found, etc.)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - OUTPUT_TEXT_COMMENTS_FILE: Path to text comments CSV file (required, exported)
#     - POSTGRES_45_LOAD_TEXT_COMMENTS: Path to SQL script template (required)
#     - POSTGRES_46_OBJECTS_TEXT_COMMENTS: Path to SQL script for handling existing objects (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - OUTPUT_TEXT_COMMENTS_FILE: Exported for envsubst substitution
#   Modifies: None
#
# Side effects:
#   - Executes psql to load CSV data into note_comments_text table
#   - Uses envsubst to substitute file path in SQL template
#   - Handles existing objects (some objects may already exist)
#   - Writes log messages to stderr
#   - No file or network operations
#   - Database operations: INSERT into note_comments_text table
#
# Notes:
#   - Uses envsubst to substitute $OUTPUT_TEXT_COMMENTS_FILE in SQL template
#   - SQL template must contain ${OUTPUT_TEXT_COMMENTS_FILE} placeholder
#   - Handles existing objects gracefully (second SQL script handles conflicts)
#   - Part of Planet processing workflow (called after processing XML parts)
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - CSV file must exist and be readable
#
# Example:
#   export OUTPUT_TEXT_COMMENTS_FILE="/tmp/text_comments.csv"
#   export POSTGRES_45_LOAD_TEXT_COMMENTS="/path/to/load_text_comments.sql"
#   export POSTGRES_46_OBJECTS_TEXT_COMMENTS="/path/to/objects_text_comments.sql"
#   __loadTextComments
#
# Related: __processPlanetXmlPart() (generates text comments CSV)
# Related: __loadSyncNotes() (loads notes and comments)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __loadTextComments {
 __log_start
 # Loads the text comment in the database.
 export OUTPUT_TEXT_COMMENTS_FILE
 # shellcheck disable=SC2016,SC2154
 # POSTGRES_45_LOAD_TEXT_COMMENTS and POSTGRES_46_OBJECTS_TEXT_COMMENTS are defined in processPlanetFunctions.sh
 # shellcheck disable=SC2154
 # POSTGRES_45_LOAD_TEXT_COMMENTS is defined in processPlanetFunctions.sh
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$OUTPUT_TEXT_COMMENTS_FILE' \
   < "${POSTGRES_45_LOAD_TEXT_COMMENTS}" || true)"
 # Some objects could already exist.
 # shellcheck disable=SC2154
 # POSTGRES_46_OBJECTS_TEXT_COMMENTS is defined in processPlanetFunctions.sh
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -f "${POSTGRES_46_OBJECTS_TEXT_COMMENTS}"
 __log_finish
}

##
# Moves data from sync tables to main tables after consolidation
# Moves data from sync tables (notes_sync, note_comments_sync, note_comments_text_sync)
# to main tables (notes, note_comments, note_comments_text). Performs deduplication,
# handles conflicts with ON CONFLICT DO UPDATE, and updates statistics. Part of Planet
# processing workflow (final step before cleanup).
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Data moved successfully
#   Non-zero: Failure - psql command failed (SQL error, connection error, etc.)
#
# Error codes:
#   0: Success - Data moved successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (SQL syntax error, connection error, file not found, etc.)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_43_MOVE_SYNC_TO_MAIN: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Moves data from sync tables to main tables
#     - Updates statistics on main tables (ANALYZE)
#
# Side effects:
#   - Executes psql to move data from sync to main tables
#   - Performs deduplication (removes duplicates before insertion)
#   - Handles conflicts with ON CONFLICT DO UPDATE
#   - Updates statistics on main tables (ANALYZE)
#   - Writes log messages to stderr
#   - Uses --pset pager=off to prevent blocking on long output
#   - Database operations: INSERT ... ON CONFLICT DO UPDATE, ANALYZE
#   - No file or network operations
#
# Notes:
#   - Moves notes, comments, and text comments from sync to main tables
#   - Performs deduplication before final insertion
#   - Uses ON CONFLICT DO UPDATE to handle existing records
#   - Updates statistics on main tables for query optimization
#   - Critical function: Final step in Planet processing workflow
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Uses --pset pager=off to prevent blocking on SELECT output
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_43_MOVE_SYNC_TO_MAIN="/path/to/move_sync_to_main.sql"
#   __moveSyncToMain
#
# Related: __consolidatePartitions() (consolidates partitions into sync tables)
# Related: __removeDuplicates() (removes duplicates from sync tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
##
# Moves data from sync tables to main tables after consolidation
# Moves data from sync tables (notes_sync, note_comments_sync, note_comments_text_sync)
# to main tables (notes, note_comments, note_comments_text). Performs deduplication,
# handles conflicts with ON CONFLICT DO UPDATE, and updates statistics. Part of Planet
# processing workflow (final step before cleanup).
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Data moved successfully
#   Non-zero: Failure - psql command failed (SQL error, connection error, etc.)
#
# Error codes:
#   0: Success - Data moved successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Error conditions:
#   0: Success - SQL script executed successfully
#   Non-zero: psql execution failed (SQL syntax error, connection error, file not found, etc.)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_43_MOVE_SYNC_TO_MAIN: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Moves data from sync tables to main tables
#     - Updates statistics on main tables
#
# Side effects:
#   - Executes psql to move data from sync tables to main tables
#   - Performs deduplication (removes notes/comments that already exist)
#   - Handles conflicts with ON CONFLICT DO UPDATE (updates existing records)
#   - Updates statistics on main tables (ANALYZE)
#   - Writes log messages to stderr
#   - Uses --pset pager=off to prevent blocking on SELECT output
#   - Database operations: INSERT ... ON CONFLICT DO UPDATE, ANALYZE
#   - No file or network operations
#
# Notes:
#   - Moves data from sync tables to main tables (final step before cleanup)
#   - Performs deduplication (only new notes/comments are moved)
#   - Handles conflicts with ON CONFLICT DO UPDATE (updates status, closed_at, etc.)
#   - Updates statistics after moving data (improves query performance)
#   - Critical function: Part of Planet processing workflow
#   - Must be called after duplicate removal (__removeDuplicates)
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Sync tables are dropped after this step (see __dropSyncTables)
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_43_MOVE_SYNC_TO_MAIN="/path/to/move_sync_to_main.sql"
#   __moveSyncToMain
#   # Moves data from sync tables to main tables
#
# Related: __removeDuplicates() (removes duplicates before moving)
# Related: __dropSyncTables() (drops sync tables after moving)
# Related: __loadSyncNotes() (loads data into sync tables)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __moveSyncToMain {
 __log_start
 __logi "Moving data from sync tables to main tables"
 # Use --pset pager=off to prevent opening vi/less for long output
 # This prevents blocking when SELECT statements produce output
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 --pset pager=off -f "${POSTGRES_43_MOVE_SYNC_TO_MAIN}"
 __log_finish
}

##
# Creates partition tables for parallel processing and verifies their creation
# Creates partition tables for parallel processing of Planet notes. Sets PostgreSQL
# session variable (app.max_threads) and executes SQL script to create partition
# tables. Verifies partition tables were created by querying information_schema.
# Creates partitions for notes_sync, note_comments_sync, and note_comments_text_sync.
#
# Parameters:
#   $1: NUM_PARTITIONS - Number of partitions to create (required)
#
# Returns:
#   0: Success - Partition tables created successfully
#   Non-zero: Failure - psql command failed (SQL error, connection error, etc.)
#
# Error codes:
#   0: Success - Partition tables created successfully
#   Non-zero: psql execution failed (ON_ERROR_STOP=1 causes immediate failure)
#
# Error conditions:
#   0: Success - Partition tables created and verified
#   Non-zero: psql execution failed (SQL syntax error, connection error, file not found, etc.)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - POSTGRES_25_CREATE_PARTITIONS: Path to SQL script (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies:
#     - Creates partition tables in database (notes_sync_part_N, note_comments_sync_part_N, etc.)
#     - Sets PostgreSQL session variable (app.max_threads)
#
# Side effects:
#   - Sets PostgreSQL session variable (app.max_threads = NUM_PARTITIONS)
#   - Executes psql to create partition tables
#   - Queries information_schema to verify partition creation
#   - Writes log messages to stderr
#   - Uses --pset pager=off to prevent blocking on SELECT output
#   - Database operations: CREATE TABLE (partition tables)
#   - No file or network operations
#
# Notes:
#   - Creates partitions for notes_sync, note_comments_sync, and note_comments_text_sync
#   - Partition names: {table}_part_{N} (e.g., notes_sync_part_1, notes_sync_part_2)
#   - Sets app.max_threads session variable for SQL script (used by SQL to determine partition count)
#   - Verifies partition creation by querying information_schema.tables
#   - Critical function: Required for parallel processing workflow
#   - Uses ON_ERROR_STOP=1 to fail immediately on SQL errors
#   - Must be called before splitting XML and processing parts
#
# Example:
#   export DBNAME="osm_notes"
#   export POSTGRES_25_CREATE_PARTITIONS="/path/to/create_partitions.sql"
#   __createPartitionTables 8
#   # Creates 8 partitions for each sync table (24 tables total)
#
# Related: __processPlanetNotesWithParallel() (orchestrates parallel processing)
# Related: __splitXmlForParallelSafe() (splits XML into parts)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __createPartitionTables {
 __log_start
 local -r NUM_PARTITIONS="${1}"

 __logi "Creating ${NUM_PARTITIONS} partition tables for parallel processing"
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SET app.max_threads = '${NUM_PARTITIONS}';" \
  -f "${POSTGRES_25_CREATE_PARTITIONS}"
 __logi "Partition tables creation completed"

 # Verify that partition tables were created
 __logi "Verifying partition tables creation..."
 # Use --pset pager=off to prevent opening vi/less for long output
 # Show summary instead of all partition names
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" --pset pager=off -c "
 SELECT
  CASE
   WHEN table_name LIKE 'notes_sync_part_%' THEN 'notes_sync_part'
   WHEN table_name LIKE 'note_comments_sync_part_%' THEN 'note_comments_sync_part'
   WHEN table_name LIKE 'note_comments_text_sync_part_%' THEN 'note_comments_text_sync_part'
   ELSE 'other'
  END AS partition_type,
  COUNT(*) as partition_count
 FROM information_schema.tables
 WHERE table_schema = 'public'
  AND table_name LIKE '%_part_%'
 GROUP BY partition_type
 ORDER BY partition_type;
 "
 __log_finish
}

# Processes Planet notes with SIMPLIFIED parallel approach (prevents crash with large files)
# Large XML files (2.2GB) can cause issues, so we split first then process parts with AWK
# This is the working approach: split XML -> process parts -> load DB
##
# Processes Planet notes using parallel processing (SPLIT+PROCESS approach)
# Splits Planet XML file into multiple parts and processes them in parallel using AWK.
# Uses GNU parallel if available, otherwise falls back to sequential processing.
# Creates partition tables, splits XML, processes parts with AWK, loads data into partitions,
# and consolidates partitions. Optimizes memory usage by limiting notes per part (100k).
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - All parts processed successfully
#   ERROR_EXECUTING_PLANET_DUMP: Failure - Split failed, no parts found, or parallel processing failed
#
# Error codes:
#   0: Success - All parts processed successfully
#   ERROR_EXECUTING_PLANET_DUMP: Failure - XML split failed, no part files found, or parallel processing failed
#
# Error conditions:
#   0: Success - All parts processed and loaded successfully
#   ERROR_EXECUTING_PLANET_DUMP: XML split failed - __splitXmlForParallelSafe returned error
#   ERROR_EXECUTING_PLANET_DUMP: No part files found - Directory empty after split
#   ERROR_EXECUTING_PLANET_DUMP: Parallel processing failed - One or more parts failed
#
# Context variables:
#   Reads:
#     - TOTAL_NOTES: Total number of notes in XML file (required)
#     - MAX_THREADS: Maximum number of parallel threads (required)
#     - PLANET_NOTES_FILE: Path to Planet XML file (required)
#     - TMP_DIR: Temporary directory for parts (required)
#     - DBNAME: PostgreSQL database name (required)
#     - POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES: SQL script path (required)
#     - SCRIPT_BASE_DIRECTORY: Base directory for scripts (required)
#     - LOG_FILENAME: Log file path (required)
#     - ERROR_EXECUTING_PLANET_DUMP: Error code for processing failures (defined in calling script)
#   Sets:
#     - SCRIPT_EXIT_CODE: Exit code for error handling (exported)
#   Modifies:
#     - Creates partition tables in database
#     - Creates part files in TMP_DIR/parts
#
# Side effects:
#   - Creates partition tables (__createPartitionTables)
#   - Splits XML file into parts (__splitXmlForParallelSafe)
#   - Processes parts in parallel (GNU parallel or sequential)
#   - Loads data into partition tables
#   - Consolidates partitions into sync tables
#   - Creates temporary files and directories
#   - Writes log messages to stderr
#   - Exports functions and variables for parallel workers
#   - Sources bash_logger.sh for parallel workers
#
# Notes:
#   - Uses SPLIT+PROCESS approach: split XML first, then process parts in parallel
#   - Limits notes per part to 100k to prevent OOM kills with large text fields
#   - Automatically adjusts number of parts if TOTAL_NOTES exceeds MAX_THREADS * 100k
#   - Uses GNU parallel if available (faster), falls back to sequential if not
#   - Each parallel worker processes one part file using AWK
#   - Workers write to shared log file (synchronized by parallel)
#   - Critical function: Main processing workflow for Planet notes
#   - Performance: Significantly faster than sequential processing for large files
#
# Example:
#   export TOTAL_NOTES=5000000
#   export MAX_THREADS=8
#   export PLANET_NOTES_FILE="/tmp/planet_notes.xml"
#   export TMP_DIR="/tmp"
#   __processPlanetNotesWithParallel
#
# Related: __splitXmlForParallelSafe() (splits XML into parts)
# Related: __createPartitionTables() (creates partition tables)
# Related: __processPlanetXmlPart() (processes single part file)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __processPlanetNotesWithParallel {
 __log_start
 __logi "Processing Planet notes with SPLIT+PROCESS approach (using AWK for fast processing)"

 # STEP 1: Calculate optimal number of parts (balance performance vs safety)
 # Reduced from 1M to 100k to prevent OOM kills with large text fields
 local MAX_NOTES_PER_PART=100000 # 100k notes per part for memory safety
 local NUM_PARTS=${MAX_THREADS}

 # If total notes would create parts > MAX_NOTES_PER_PART, increase number
 if [[ ${TOTAL_NOTES} -gt $((MAX_THREADS * MAX_NOTES_PER_PART)) ]]; then
  NUM_PARTS=$((TOTAL_NOTES / MAX_NOTES_PER_PART))
  # Round up if there's a remainder
  if [[ $((TOTAL_NOTES % MAX_NOTES_PER_PART)) -gt 0 ]]; then
   NUM_PARTS=$((NUM_PARTS + 1))
  fi
  __logi "Adjusted parts: ${MAX_THREADS} → ${NUM_PARTS} to keep max ${MAX_NOTES_PER_PART} notes/part (optimal chunk size)"
 fi

 # Create partitions for database (must be done AFTER calculating NUM_PARTS)
 __createPartitionTables "${NUM_PARTS}"

 local NOTES_PER_PART=$((TOTAL_NOTES / NUM_PARTS))
 __logi "Step 2: Splitting ${TOTAL_NOTES} notes into ${NUM_PARTS} parts (~${NOTES_PER_PART} notes/part)..."

 local PARTS_DIR="${TMP_DIR}/parts"
 mkdir -p "${PARTS_DIR}"

 # Split XML using the implementation from parallelProcessingFunctions.sh
 # (loaded at script startup to override functionsProcess.sh wrapper)
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __splitXmlForParallelSafe "${PLANET_NOTES_FILE}" \
  "${NUM_PARTS}" "${PARTS_DIR}" "planet"; then
  SPLIT_RESULT=$?
 else
  SPLIT_RESULT=0
 fi
 if [[ "${SPLIT_RESULT:-0}" -ne 0 ]]; then
  __loge "ERROR: Failed to split XML file"
  __log_finish
  export SCRIPT_EXIT_CODE="${ERROR_EXECUTING_PLANET_DUMP}"
  return "${ERROR_EXECUTING_PLANET_DUMP}"
 fi
 unset SPLIT_RESULT

 # STEP 3: Process each part with AWK in parallel
 __logi "Step 3: Processing ${NUM_PARTS} XML parts in parallel with AWK (${MAX_THREADS} concurrent jobs)..."
 __logd "Looking for part files in: ${PARTS_DIR}"

 # Find all part files and sort them numerically (not alphabetically)
 local PART_FILES
 mapfile -t PART_FILES < <(find "${PARTS_DIR}" -name "planet_part_*.xml" -type f \
  | sort -t_ -k3 -n || true)

 if [[ ${#PART_FILES[@]} -eq 0 ]]; then
  __loge "ERROR: No part files found in ${PARTS_DIR}"
  __loge "Directory contents:"
  # shellcheck disable=SC2012
  # Using ls for human-readable directory listing is acceptable here
  ls -la "${PARTS_DIR}" 2>&1 | while IFS= read -r line; do
   # shellcheck disable=SC2310
   # Function is invoked in || condition intentionally to prevent exit on error
   __loge "  ${line}" || true
  done || true
  __log_finish
  export SCRIPT_EXIT_CODE="${ERROR_EXECUTING_PLANET_DUMP}"
  return "${ERROR_EXECUTING_PLANET_DUMP}"
 fi

 __logi "Found ${#PART_FILES[@]} part files to process"
 __logd "Part files list (first 5):"
 for I in "${!PART_FILES[@]}"; do
  if [[ ${I} -lt 5 ]]; then
   __logd "  [${I}]: ${PART_FILES[${I}]}"
  fi
 done

 # Export variables and functions needed by parallel processing
 export DBNAME TMP_DIR MAX_THREADS
 export POSTGRES_41_LOAD_PARTITIONED_SYNC_NOTES
 export SCRIPT_BASE_DIRECTORY
 export LOG_FILENAME # Export log file path for parallel workers

 # Source and export bash_logger functions for parallel jobs
 # shellcheck disable=SC1091
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh"
 export -f __log_start __log_finish __logi __logd __loge __logw __set_log_file

 # Export the main processing function
 export -f __processPlanetXmlPart

 # Create wrapper function for parallel workers to setup logging
 function __parallel_worker_wrapper() {
  local -r PART_FILE="$1"
  local PART_BASENAME
  PART_BASENAME=$(basename "${PART_FILE}")

  # Setup logging for this worker (appends to shared log file)
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __set_log_file "${LOG_FILENAME}" 2> /dev/null; then
   :
  fi

  # Log worker start
  __logi "[WORKER] Starting processing of part file: ${PART_BASENAME}"
  __logd "[WORKER] Full path: ${PART_FILE}"
  __logd "[WORKER] DBNAME: ${DBNAME:-NOT_SET}"
  __logd "[WORKER] TMP_DIR: ${TMP_DIR:-NOT_SET}"

  # Execute the main processing function
  # Output is synchronized by parallel's internal buffering
  __logd "[WORKER] About to call __processPlanetXmlPart for ${PART_BASENAME}"
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __processPlanetXmlPart "${PART_FILE}"; then
   PROCESS_RESULT=$?
  else
   PROCESS_RESULT=0
  fi
  if [[ "${PROCESS_RESULT:-0}" -eq 0 ]]; then
   __logi "[WORKER] Successfully completed processing of ${PART_BASENAME}"
  else
   __loge "[WORKER] Failed to process ${PART_BASENAME}, exit code: ${PROCESS_RESULT:-1}"
   return 1
  fi
  unset PROCESS_RESULT
 }
 export -f __parallel_worker_wrapper

 # Process parts in parallel using GNU parallel if available
 if command -v parallel > /dev/null 2>&1; then
  __logi "Using GNU parallel for processing (${MAX_THREADS} jobs)"
  __logi "Worker logs will be written to: ${LOG_FILENAME}"
  __logd "About to start parallel processing of ${#PART_FILES[@]} parts"
  __logd "DBNAME: ${DBNAME}"
  __logd "TMP_DIR: ${TMP_DIR}"
  __logd "MAX_THREADS: ${MAX_THREADS}"

  # Process all parts in parallel with progress tracking
  # Workers use wrapper to setup logging correctly in each subshell
  # Note: --line-buffer removed because workers write directly to log file
  # via __set_log_file, so parallel doesn't need to buffer stdout/stderr
  __logi "Starting parallel execution now..."
  if ! printf '%s\n' "${PART_FILES[@]}" \
   | parallel --will-cite --jobs "${MAX_THREADS}" --halt now,fail=1 \
    "__parallel_worker_wrapper {}"; then
   __loge "ERROR: Parallel processing failed"
   __loge "Check logs for details on which part(s) failed"
   __log_finish
   export SCRIPT_EXIT_CODE="${ERROR_EXECUTING_PLANET_DUMP}"
   return "${ERROR_EXECUTING_PLANET_DUMP}"
  fi
  __logi "Parallel processing completed successfully"
 else
  # Fallback: Process in batches using background jobs
  __logi "GNU parallel not found, using background jobs (${MAX_THREADS} concurrent)"

  local ACTIVE_JOBS=0
  local PART_NUM=0
  local FAILED=0

  for PART_FILE in "${PART_FILES[@]}"; do
   # Process part in background
   (
    # shellcheck disable=SC2310
    # Function is invoked in || condition intentionally to capture exit code
    __processPlanetXmlPart "${PART_FILE}" || PROCESS_RESULT=$?
    if [[ "${PROCESS_RESULT:-0}" -ne 0 ]]; then
     exit 1
    fi
    unset PROCESS_RESULT
   ) &

   ACTIVE_JOBS=$((ACTIVE_JOBS + 1))
   PART_NUM=$((PART_NUM + 1))

   # Wait if we've reached max concurrent jobs
   if [[ ${ACTIVE_JOBS} -ge ${MAX_THREADS} ]]; then
    __logi "Waiting for batch of ${MAX_THREADS} jobs to complete..."
    wait -n || FAILED=$((FAILED + 1))
    ACTIVE_JOBS=$((ACTIVE_JOBS - 1))
   fi
  done

  # Wait for remaining jobs
  __logi "Waiting for remaining jobs to complete..."
  wait || FAILED=$((FAILED + 1))

  if [[ ${FAILED} -gt 0 ]]; then
   __loge "ERROR: ${FAILED} parallel jobs failed"
   __log_finish
   export SCRIPT_EXIT_CODE="${ERROR_EXECUTING_PLANET_DUMP}"
   return "${ERROR_EXECUTING_PLANET_DUMP}"
  fi
 fi

 __logi "All ${#PART_FILES[@]} parts processed successfully"

 # STEP 4: Consolidate partitions into main tables
 __logi "Step 4: Consolidating ${NUM_PARTS} partitions into main tables..."
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "SET app.max_threads = '${NUM_PARTS}';" \
  -f "${POSTGRES_42_CONSOLIDATE_PARTITIONS}"

 # Move data from sync tables to main tables
 __logi "Step 5: Moving data from sync tables to main tables..."
 __moveSyncToMain

 # Clean up part files
 __logi "Cleaning up part files..."
 rm -rf "${PARTS_DIR}"

 __logi "Planet notes processing completed successfully (split+process approach)"
 __log_finish
}

# Cleans files generated during the process.
##
# Cleans up files generated during Planet notes processing
# Removes temporary files created during Planet processing if CLEAN environment variable
# is set to true. Files removed include Planet XML file, generated CSV files, and
# partial boundary files (part_country_*, part_maritime_*).
# Used for cleanup after successful or failed processing.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Always returns 0 (success) - cleanup function never fails
#
# Error codes:
#   None - Function always succeeds, only performs file removal
#
# Error conditions:
#   Always succeeds - File removal failures are ignored (rm -f)
#
# Context variables:
#   Reads:
#     - CLEAN: If "true", removes files; if "false" or unset, skips cleanup (optional, default: false)
#     - PLANET_NOTES_FILE: Path to Planet XML file (required)
#     - OUTPUT_NOTES_FILE: Path to notes CSV file (required)
#     - OUTPUT_NOTE_COMMENTS_FILE: Path to comments CSV file (required)
#     - OUTPUT_TEXT_COMMENTS_FILE: Path to text comments CSV file (required)
#     - TMP_DIR: Temporary directory containing partial boundary files (required)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Removes Planet XML file and CSV files if CLEAN=true
#   - Removes partial boundary files (part_country_*, part_maritime_*) if CLEAN=true
#   - Writes log messages to stderr
#   - No database or network operations
#   - File removal failures are ignored (rm -f)
#
# Notes:
#   - Only removes files if CLEAN environment variable is "true"
#   - Uses rm -f to ignore missing files (non-fatal)
#   - Removes partial boundary files using glob pattern (part_country_*, part_maritime_*)
#   - Safe to call multiple times (idempotent)
#   - Used for cleanup after Planet processing (success or failure)
#   - Files are removed silently (no error if file doesn't exist)
#
# Example:
#   export CLEAN=true
#   export PLANET_NOTES_FILE="/tmp/planet_notes.xml"
#   export OUTPUT_NOTES_FILE="/tmp/notes.csv"
#   export TMP_DIR="/tmp"
#   __cleanNotesFiles
#
# Related: __cleanPartial() (cleans partial boundary processing files)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __cleanNotesFiles {
 __log_start
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -f "${PLANET_NOTES_FILE}" "${OUTPUT_NOTES_FILE}" \
   "${OUTPUT_NOTE_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"
  rm -f "${TMP_DIR}"/part_country_* "${TMP_DIR}"/part_maritime_*
 fi
 __log_finish
}

##
# Performs complete validation of Planet notes XML file
# Validates XML structure against schema, dates, and coordinates. Performs comprehensive
# validation to ensure downloaded Planet file is valid before processing. Cleans up
# temporary validation files. Exits script with ERROR_DATA_VALIDATION if any validation fails.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Exits with ERROR_DATA_VALIDATION if any validation fails
#   Returns 0 if all validations pass
#
# Error codes:
#   0: Success - All validations passed (structure, dates, coordinates)
#   ERROR_DATA_VALIDATION: Failure - File not found, structure invalid, dates invalid, or coordinates invalid (exits script)
#
# Error conditions:
#   0: Success - All validations passed successfully
#   ERROR_DATA_VALIDATION: File not found - PLANET_NOTES_FILE does not exist
#   ERROR_DATA_VALIDATION: Structure invalid - XML does not match schema
#   ERROR_DATA_VALIDATION: Dates invalid - Dates are not in expected format or invalid
#   ERROR_DATA_VALIDATION: Coordinates invalid - Coordinates are missing or invalid
#
# Context variables:
#   Reads:
#     - PLANET_NOTES_FILE: Path to Planet notes XML file (required)
#     - XMLSCHEMA_PLANET_NOTES: Path to XML schema file (required)
#     - FAILED_EXECUTION_FILE: Path to failed execution marker file (required)
#     - LOG_LEVEL: Controls logging verbosity
#     - ERROR_DATA_VALIDATION: Error code for validation failures (defined in calling script)
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Cleans up temporary validation files (before and after validation)
#   - Validates XML structure against schema (using xmllint)
#   - Validates dates in XML file (ISO 8601 format)
#   - Validates coordinates in XML file (lat/lon attributes)
#   - Creates failed execution marker if validation fails
#   - Writes log messages to stderr
#   - Exits script with ERROR_DATA_VALIDATION if validation fails
#   - No file modifications or database operations
#
# Notes:
#   - Performs three validation steps: structure, dates, coordinates
#   - Cleans up temporary validation files before starting
#   - Uses __validate_xml_with_enhanced_error_handling for structure validation
#   - Uses __validate_xml_dates for date validation
#   - Uses __validate_xml_coordinates for coordinate validation
#   - Cleans up temporary files after validation (success or failure)
#   - All validations must pass for function to succeed
#   - Critical function: exits script on failure (does not return)
#   - Used before processing Planet notes to ensure data quality
#
# Example:
#   export PLANET_NOTES_FILE="/tmp/planet_notes.xml"
#   export XMLSCHEMA_PLANET_NOTES="/path/to/schema.xsd"
#   export FAILED_EXECUTION_FILE="/tmp/failed_execution"
#   __validatePlanetNotesXMLFileComplete
#   # All validations passed - file is valid
#
# Related: __validateApiNotesXMLFileComplete() (API notes validation)
# Related: __validate_xml_with_enhanced_error_handling() (XML structure validation)
# Related: __validate_xml_dates() (date validation)
# Related: __validate_xml_coordinates() (coordinate validation)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __validatePlanetNotesXMLFileComplete {
 __log_start

 # Check if file exists
 if [[ ! -f "${PLANET_NOTES_FILE}" ]]; then
  __loge "ERROR: Planet notes file not found: ${PLANET_NOTES_FILE}"
  __create_failed_marker "${ERROR_DATA_VALIDATION}" \
   "Planet notes file not found: ${PLANET_NOTES_FILE}" \
   "Check if the Planet XML file was downloaded correctly and exists at the expected location"
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Clean up any existing temporary files
 __cleanup_validation_temp_files

 # Validate XML structure against schema with enhanced error handling
 __logi "Validating XML structure against schema..."
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __validate_xml_with_enhanced_error_handling "${PLANET_NOTES_FILE}" "${XMLSCHEMA_PLANET_NOTES}"; then
  __loge "ERROR: XML structure validation failed: ${PLANET_NOTES_FILE}"
  __cleanup_validation_temp_files
  __create_failed_marker "${ERROR_DATA_VALIDATION}" \
   "XML structure validation failed: ${PLANET_NOTES_FILE}" \
   "Check if the Planet XML file is well-formed and matches the expected schema"
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Validate dates in XML file
 __logi "Validating dates in XML file..."
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __validate_xml_dates "${PLANET_NOTES_FILE}"; then
  __loge "ERROR: XML date validation failed: ${PLANET_NOTES_FILE}"
  __cleanup_validation_temp_files
  __create_failed_marker "${ERROR_DATA_VALIDATION}" \
   "XML date validation failed: ${PLANET_NOTES_FILE}" \
   "Check if the Planet XML file contains valid date formats"
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Validate coordinates in XML file
 __logi "Validating coordinates in XML file..."
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __validate_xml_coordinates "${PLANET_NOTES_FILE}"; then
  __loge "ERROR: XML coordinate validation failed: ${PLANET_NOTES_FILE}"
  __cleanup_validation_temp_files
  __create_failed_marker "${ERROR_DATA_VALIDATION}" \
   "XML coordinate validation failed: ${PLANET_NOTES_FILE}" \
   "Check if the Planet XML file contains valid coordinate values"
  exit "${ERROR_DATA_VALIDATION}"
 fi

 # Final cleanup
 __cleanup_validation_temp_files

 __logi "All Planet notes XML validations passed successfully"
 __log_finish
}

# Validates XML structure with enhanced error handling for large files
# Parameters:
#   $1 - XML file path
#   $2 - Schema file path (optional for very large files)
# Returns:
#   0 if validation passes, 1 if validation fails
# Enhanced XML validation with error handling
# Now uses consolidated functions from consolidatedValidationFunctions.sh
function __validate_xml_with_enhanced_error_handling {
 __log_start
 # Source the consolidated validation functions
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/consolidatedValidationFunctions.sh" ]]; then
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/consolidatedValidationFunctions.sh"
  __validate_xml_with_enhanced_error_handling "$@"
 else
  # Fallback if consolidated functions are not available
  __loge "ERROR: Consolidated validation functions not found. Please ensure consolidatedValidationFunctions.sh is available."
  __log_finish
  export SCRIPT_EXIT_CODE="${ERROR_MISSING_LIBRARY}"
  return "${ERROR_MISSING_LIBRARY}"
 fi
 __log_finish
}

# Basic XML structure validation (lightweight)
# Parameters:
#   $1 - XML file path
# Returns:
#   0 if validation passes, 1 if validation fails
function __validate_xml_basic {
 __log_start
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  __log_finish
  export SCRIPT_EXIT_CODE="${ERROR_DATA_VALIDATION}"
  return "${ERROR_DATA_VALIDATION}"
 fi

 __logi "Performing basic XML validation: ${XML_FILE}"

 # Lightweight XML validation using grep instead of xmllint
 # Check if file contains basic XML structure markers
 if ! grep -q '<?xml' "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: XML file does not contain XML declaration"
  __log_finish
  export SCRIPT_EXIT_CODE="${ERROR_DATA_VALIDATION}"
  return "${ERROR_DATA_VALIDATION}"
 fi

 # Check root element
 if ! grep -q "<osm-notes>" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Missing root element <osm-notes> in ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Check for note elements
 if ! grep -q "<note" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: No note elements found in XML file ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Count total notes
 local TOTAL_NOTES
 TOTAL_NOTES=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")

 if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
  __logi "Found ${TOTAL_NOTES} notes in XML file"

  # Check for proper note structure (opening and closing tags)
  local OPENING_TAGS
  local CLOSING_TAGS
  OPENING_TAGS=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")
  CLOSING_TAGS=$(grep -c "</note>" "${XML_FILE}" 2> /dev/null || echo "0")

  if [[ "${OPENING_TAGS}" -ne "${CLOSING_TAGS}" ]]; then
   __loge "ERROR: Mismatched note tags: ${OPENING_TAGS} opening, ${CLOSING_TAGS} closing"
   __log_finish
   export SCRIPT_EXIT_CODE="${ERROR_DATA_VALIDATION}"
   return "${ERROR_DATA_VALIDATION}"
  fi

  __logi "Basic XML validation passed"
  __log_finish
  return 0
 else
  __loge "ERROR: No notes found in XML file"
  __log_finish
  export SCRIPT_EXIT_CODE="${ERROR_DATA_VALIDATION}"
  return "${ERROR_DATA_VALIDATION}"
 fi
}

# Structure-only validation for very large files (no xmllint)
# Parameters:
#   $1 - XML file path
# Returns:
#   0 if validation passes, 1 if validation fails
function __validate_xml_structure_only {
 __log_start
 local XML_FILE="${1}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "ERROR: XML file not found: ${XML_FILE}"
  __log_finish
  export SCRIPT_EXIT_CODE="${ERROR_DATA_VALIDATION}"
  return "${ERROR_DATA_VALIDATION}"
 fi

 __logi "Performing structure-only validation for very large file: ${XML_FILE}"

 # Check root element
 if ! grep -q "<osm-notes>" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: Missing root element <osm-notes> in ${XML_FILE}"
  __log_finish
  export SCRIPT_EXIT_CODE="${ERROR_DATA_VALIDATION}"
  return "${ERROR_DATA_VALIDATION}"
 fi

 # Check for note elements
 if ! grep -q "<note" "${XML_FILE}" 2> /dev/null; then
  __loge "ERROR: No note elements found in XML file ${XML_FILE}"
  __log_finish
  return 1
 fi

 # Count total notes
 local TOTAL_NOTES
 TOTAL_NOTES=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")

 if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
  __logi "Found ${TOTAL_NOTES} notes in XML file"

  # Check for proper note structure (opening and closing tags)
  local OPENING_TAGS
  local CLOSING_TAGS
  OPENING_TAGS=$(grep -c "<note" "${XML_FILE}" 2> /dev/null || echo "0")
  CLOSING_TAGS=$(grep -c "</note>" "${XML_FILE}" 2> /dev/null || echo "0")

  if [[ "${OPENING_TAGS}" -ne "${CLOSING_TAGS}" ]]; then
   __loge "ERROR: Mismatched note tags: ${OPENING_TAGS} opening, ${CLOSING_TAGS} closing"
   __log_finish
   return 1
  fi

  # Additional lightweight checks
  # Check for common XML issues
  if grep -q "&[^a-zA-Z0-9#]" "${XML_FILE}" 2> /dev/null; then
   __logw "WARNING: Potential unescaped ampersands found in XML"
  fi

  # Check for basic XML structure integrity
  local FIRST_LINE
  local LAST_LINE
  FIRST_LINE=$(head -1 "${XML_FILE}" 2> /dev/null | grep -c "<?xml\|<osm-notes>" || echo "0")
  LAST_LINE=$(tail -1 "${XML_FILE}" 2> /dev/null | grep -c "</osm-notes>" || echo "0")

  if [[ "${FIRST_LINE}" -eq 0 ]] && [[ "${LAST_LINE}" -eq 0 ]]; then
   __logw "WARNING: XML declaration or root element structure may be incomplete"
  fi

  __logi "Structure-only validation passed for very large file"
  __log_finish
  return 0
 else
  __loge "ERROR: No notes found in XML file"
  __log_finish
  return 1
 fi
}

# Monitor xmllint resource usage in the background
# Parameters:
#   $1 - PID of the xmllint process
#   $2 - monitoring interval in seconds
#   $3 - log file for resource monitoring
function __monitor_xmllint_resources {
 __log_start
 local XMLLINT_PID="${1}"
 local INTERVAL="${2:-5}"
 local MONITOR_LOG="${3:-${TMP_DIR}/xmllint_resources.log}"

 __logi "Starting resource monitoring for xmllint PID: ${XMLLINT_PID}"

 {
  local DATE_START
  DATE_START=$(date '+%Y-%m-%d %H:%M:%S' 2> /dev/null || echo 'unknown')
  echo "${DATE_START} - Starting resource monitoring for PID ${XMLLINT_PID}"

  while kill -0 "${XMLLINT_PID}" 2> /dev/null; do
   if ps -p "${XMLLINT_PID}" > /dev/null 2>&1; then
    local CPU_USAGE
    local MEM_USAGE
    local RSS_KB
    CPU_USAGE=$(ps -p "${XMLLINT_PID}" -o %cpu --no-headers 2> /dev/null | tr -d ' ')
    MEM_USAGE=$(ps -p "${XMLLINT_PID}" -o %mem --no-headers 2> /dev/null | tr -d ' ')
    RSS_KB=$(ps -p "${XMLLINT_PID}" -o rss --no-headers 2> /dev/null | tr -d ' ')

    local DATE_NOW
    DATE_NOW=$(date '+%Y-%m-%d %H:%M:%S' 2> /dev/null || echo 'unknown')
    echo "${DATE_NOW} - PID: ${XMLLINT_PID}, CPU: ${CPU_USAGE}%, Memory: ${MEM_USAGE}%, RSS: ${RSS_KB}KB"

    # Check if memory usage is too high
    if [[ -n "${RSS_KB}" ]] && [[ "${RSS_KB}" -gt 2097152 ]]; then # 2GB in KB
     local DATE_WARN
     DATE_WARN=$(date '+%Y-%m-%d %H:%M:%S' 2> /dev/null || echo 'unknown')
     echo "${DATE_WARN} - WARNING: Memory usage exceeds 2GB (${RSS_KB}KB)"
    fi
   fi
   sleep "${INTERVAL}"
  done

  local DATE_END
  DATE_END=$(date '+%Y-%m-%d %H:%M:%S' 2> /dev/null || echo 'unknown')
  echo "${DATE_END} - Process ${XMLLINT_PID} finished or terminated"
 } >> "${MONITOR_LOG}" 2>&1 &

 local MONITOR_PID=$!
 echo "${MONITOR_PID}"
 __log_finish
}

# Run xmllint with resource limitations to prevent system overload
# Parameters:
#   $1 - timeout in seconds
#   $2 - xmllint command arguments
#   $3 - XML file path
# Returns:
#   0 if validation passes, 1 if validation fails
function __run_xmllint_with_limits {
 __log_start
 local TIMEOUT_SECS="${1}"
 local XMLLINT_ARGS="${2}"
 local XML_FILE="${3}"

 # CPU limit: 25% of one core, Memory limit: 2GB
 local CPU_LIMIT="25"
 local MEMORY_LIMIT="2000000" # 2GB in KB
 local MONITOR_LOG="${TMP_DIR}/xmllint_resources.log"

 __logi "Running xmllint with resource limits: CPU ${CPU_LIMIT}%, Memory ${MEMORY_LIMIT}KB"

 # Create a temporary script to run xmllint with resource limits
 local TEMP_SCRIPT
 TEMP_SCRIPT=$(mktemp)
 cat > "${TEMP_SCRIPT}" << EOF
#!/bin/bash
# Set memory limit
ulimit -v ${MEMORY_LIMIT}
# Run xmllint with timeout
timeout ${TIMEOUT_SECS} xmllint ${XMLLINT_ARGS} "${XML_FILE}" &
XMLLINT_PID=\$!
echo \$XMLLINT_PID > "${TMP_DIR}/xmllint.pid"
wait \$XMLLINT_PID
EOF

 chmod +x "${TEMP_SCRIPT}"

 # Run with cpulimit if available, otherwise just run the script
 local RESULT=0
 local MONITOR_PID=""

 if command -v cpulimit > /dev/null 2>&1; then
  # Start the process with cpulimit
  cpulimit --limit="${CPU_LIMIT}" "${TEMP_SCRIPT}" &
  local MAIN_PID=$!

  # Wait a bit for xmllint to start, then get its PID
  sleep 2
  if [[ -f "${TMP_DIR}/xmllint.pid" ]]; then
   local XMLLINT_PID
   XMLLINT_PID=$(cat "${TMP_DIR}/xmllint.pid" 2> /dev/null)
   if [[ -n "${XMLLINT_PID}" ]]; then
    MONITOR_PID=$(__monitor_xmllint_resources "${XMLLINT_PID}" 5 "${MONITOR_LOG}")
   fi
  fi

  # Wait for the main process to complete
  wait "${MAIN_PID}"
  RESULT=$?
 else
  __logw "WARNING: cpulimit not available, running without CPU limits"

  # Start the process normally
  "${TEMP_SCRIPT}" &
  local MAIN_PID=$!

  # Wait a bit for xmllint to start, then get its PID
  sleep 2
  if [[ -f "${TMP_DIR}/xmllint.pid" ]]; then
   local XMLLINT_PID
   XMLLINT_PID=$(cat "${TMP_DIR}/xmllint.pid" 2> /dev/null)
   if [[ -n "${XMLLINT_PID}" ]]; then
    MONITOR_PID=$(__monitor_xmllint_resources "${XMLLINT_PID}" 5 "${MONITOR_LOG}")
   fi
  fi

  # Wait for the main process to complete
  wait "${MAIN_PID}"
  RESULT=$?
 fi

 # Stop monitoring if it's running
 if [[ -n "${MONITOR_PID}" ]]; then
  kill "${MONITOR_PID}" 2> /dev/null || true
 fi

 # Clean up
 rm -f "${TEMP_SCRIPT}" "${TMP_DIR}/xmllint.pid"

 # Show resource monitoring summary if available
 if [[ -f "${MONITOR_LOG}" ]]; then
  __logi "Resource monitoring log available at: ${MONITOR_LOG}"
  local MAX_CPU
  local MAX_MEM
  MAX_CPU=$(grep "CPU:" "${MONITOR_LOG}" | sed 's/.*CPU: \([0-9.]*\)%.*/\1/' | sort -n | tail -1)
  MAX_MEM=$(grep "RSS:" "${MONITOR_LOG}" | sed 's/.*RSS: \([0-9]*\)KB.*/\1/' | sort -n | tail -1)
  if [[ -n "${MAX_CPU}" ]] && [[ -n "${MAX_MEM}" ]]; then
   __logi "Peak resource usage - CPU: ${MAX_CPU}%, Memory: ${MAX_MEM}KB"
  fi
 fi

 # Log output if there was an error
 if [[ ${RESULT} -ne 0 ]]; then
  __loge "xmllint validation failed with exit code: ${RESULT}"
  if [[ ${RESULT} -eq 124 ]]; then
   __loge "Process was terminated due to timeout (${TIMEOUT_SECS}s)"
  elif [[ ${RESULT} -eq 137 ]]; then
   __loge "Process was killed (likely due to memory limits)"
  fi
 fi

 __log_finish
 return "${RESULT}"
}

# Clean up temporary files created during validation
# Parameters:
#   None
# Returns:
#   0 if cleanup successful
function __cleanup_validation_temp_files {
 __log_start
 # Only clean up if CLEAN is set to true
 if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
  local TEMP_FILES=(
   "/tmp/sample_validation.xml"
   "/tmp/validation_error.log"
  )

  for TEMP_FILE in "${TEMP_FILES[@]}"; do
   if [[ -f "${TEMP_FILE}" ]]; then
    rm -f "${TEMP_FILE}"
    __logd "Cleaned up temporary file: ${TEMP_FILE}"
   fi
  done
 else
  __logd "Skipping cleanup of temporary files (CLEAN=${CLEAN:-false})"
 fi

 __log_finish
 return 0
}

# Function that activates the error trap.
function __trapOn() {
 __log_start
 # shellcheck disable=SC2154
 # Variables are assigned dynamically within the trap handler
 trap '{
  local ERROR_LINE="${LINENO}"
  local ERROR_COMMAND="${BASH_COMMAND}"
  local ERROR_EXIT_CODE="$?"

  # Only report actual errors, not successful returns
  if [[ "${ERROR_EXIT_CODE}" -ne 0 ]]; then
   # Get the main script name (the one that was executed, not the library)
   local MAIN_SCRIPT_NAME
   MAIN_SCRIPT_NAME=$(basename "${0}" .sh)

   printf "%s ERROR: The script %s did not finish correctly. Temporary directory: ${TMP_DIR:-} - Line number: %d.\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}" "${ERROR_LINE}";
   printf "ERROR: Failed command: %s (exit code: %d)\n" "${ERROR_COMMAND}" "${ERROR_EXIT_CODE}";
   if [[ "${GENERATE_FAILED_FILE}" = true ]]; then
    {
     echo "Error occurred at $(date +%Y%m%d_%H:%M:%S)"
     echo "Script: ${MAIN_SCRIPT_NAME}"
     echo "Line number: ${ERROR_LINE}"
     echo "Failed command: ${ERROR_COMMAND}"
     echo "Exit code: ${ERROR_EXIT_CODE}"
     echo "Temporary directory: ${TMP_DIR:-unknown}"
     echo "Process ID: $$"
    } > "${FAILED_EXECUTION_FILE}"
   fi;
   exit "${ERROR_EXIT_CODE}";
  fi;
 }' ERR
 # shellcheck disable=SC2154
 # ERROR_GENERAL is assigned dynamically
 trap '{
  # Get the main script name (the one that was executed, not the library)
  local MAIN_SCRIPT_NAME
  MAIN_SCRIPT_NAME=$(basename "${0}" .sh)

  printf "%s WARN: The script %s was terminated. Temporary directory: ${TMP_DIR:-}\n" "$(date +%Y%m%d_%H:%M:%S)" "${MAIN_SCRIPT_NAME}";
  if [[ "${GENERATE_FAILED_FILE}" = true ]]; then
   {
    echo "Script terminated at $(date +%Y%m%d_%H:%M:%S)"
    echo "Script: ${MAIN_SCRIPT_NAME}"
    echo "Temporary directory: ${TMP_DIR:-unknown}"
    echo "Process ID: $$"
    echo "Signal: SIGTERM/SIGINT"
   } > "${FAILED_EXECUTION_FILE}"
  fi;
  exit "${ERROR_GENERAL}";
 }' SIGINT SIGTERM
 __log_finish
}

# Process geographic data and location notes
# This function handles the logic for checking countries/maritimes data
# and delegating to updateCountries.sh if needed
# Note: Maritimes are imported into the 'countries' table, not a separate table
##
# Processes geographic data and prepares for location note processing
# Checks if countries table exists and has data. If running in base mode and
# countries table is empty/missing, attempts to load countries automatically by
# calling updateCountries.sh --base. Logs geographic data status and prepares
# for subsequent location note processing (which requires get_country() function).
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Geographic data found or loaded successfully
#   ERROR_EXECUTING_PLANET_DUMP: Failure - updateCountries.sh failed (exits script)
#
# Error codes:
#   0: Success - Geographic data found or loaded successfully
#   ERROR_EXECUTING_PLANET_DUMP: Failure - updateCountries.sh failed (exits script)
#
# Error conditions:
#   0: Success - Countries table exists and has data
#   0: Success - Countries loaded automatically (base mode)
#   ERROR_EXECUTING_PLANET_DUMP: updateCountries.sh failed - Cannot continue without geographic data (exits script)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - PROCESS_TYPE: Process type ("--base" or empty) (required)
#     - SCRIPT_BASE_DIRECTORY: Base directory for scripts (required)
#     - SKIP_AUTO_LOAD_COUNTRIES: If "true", skips automatic country loading (optional)
#     - ERROR_EXECUTING_PLANET_DUMP: Error code for processing failures (defined in calling script)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Queries database to check countries table existence and count
#   - Executes updateCountries.sh --base if needed (base mode, empty table, script exists)
#   - Creates failed execution marker if updateCountries.sh fails
#   - Writes log messages to stderr
#   - Exits script with ERROR_EXECUTING_PLANET_DUMP if updateCountries.sh fails
#   - No direct database modifications (updateCountries.sh modifies database)
#
# Notes:
#   - Checks countries table count (includes both countries and maritimes)
#   - In base mode: Attempts automatic loading if table is empty/missing
#   - Automatic loading can take 30-60 minutes (downloads and processes all boundaries)
#   - updateCountries.sh is executed as independent subprocess (separate TMP_DIR and log file)
#   - Location notes processing is deferred until after get_country() function is created
#   - Critical function: Ensures geographic data is available before processing location notes
#   - Can be skipped with SKIP_AUTO_LOAD_COUNTRIES=true (for testing or manual loading)
#
# Example:
#   export DBNAME="osm_notes"
#   export PROCESS_TYPE="--base"
#   export SCRIPT_BASE_DIRECTORY="/path/to/scripts"
#   __processGeographicData
#
# Related: updateCountries.sh (loads country boundaries)
# Related: __createFunctionToGetCountry() (creates get_country function)
# Related: __getLocationNotes() (processes location notes)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
##
# Processes geographic data and manages country boundary loading for Planet notes processing
# Checks if countries table has data and optionally triggers automatic loading via updateCountries.sh
# in base mode. Handles empty database scenarios by calling updateCountries.sh --base to download
# and process all country and maritime boundaries. Verifies data loading success before proceeding.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - Geographic data verified or loaded successfully
#   Exits with ERROR_EXECUTING_PLANET_DUMP if updateCountries.sh fails or no data loaded
#
# Error codes:
#   0: Success - Countries table has data or was loaded successfully
#   ERROR_EXECUTING_PLANET_DUMP (238): updateCountries.sh failed or no countries loaded after execution
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PROCESS_TYPE: Processing mode, must be "--base" for auto-loading (required)
#     - SCRIPT_BASE_DIRECTORY: Base directory for script paths (required)
#     - SKIP_AUTO_LOAD_COUNTRIES: Set to "true" to disable auto-loading (optional, default: false)
#     - PGAPPNAME: PostgreSQL application name for connection (optional)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Queries PostgreSQL database to check countries table count
#   - Executes updateCountries.sh --base as subprocess if in base mode and table is empty
#   - Creates failed execution marker file if updateCountries.sh fails
#   - Exits script with ERROR_EXECUTING_PLANET_DUMP on critical failures
#   - Logs all operations to standard logger
#   - Note: Does NOT call __getLocationNotes() - that is called later after get_country() function creation
#
# Example:
#   export DBNAME="osm_notes"
#   export PROCESS_TYPE="--base"
#   export SCRIPT_BASE_DIRECTORY="/path/to/repo"
#   __processGeographicData
#
# Related: updateCountries.sh (loads country boundaries)
# Related: __createFunctionToGetCountry() (creates get_country function for location notes)
# Related: __getLocationNotes() (processes location notes after get_country() exists)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __processGeographicData {
 __log_start
 __logi "Processing geographic data and location notes..."

 # Check if countries data exist (includes both countries and maritimes)
 local COUNTRIES_COUNT

 # Extract only numeric value from psql output (may include connection messages)
 COUNTRIES_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM countries;" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

 if [[ "${COUNTRIES_COUNT:-0}" -gt 0 ]]; then
  __logi "Geographic data found (${COUNTRIES_COUNT} countries/maritimes)."
  __logi "Note: Location notes will be processed after get_country() function is created."
  # Do not call __getLocationNotes here - it will be called after creating get_country()
 else
  __logw "No geographic data found (countries: ${COUNTRIES_COUNT})."

  # If running in base mode, try to load countries automatically
  # This handles both cases: when countries table doesn't exist or when it's empty
  __logd "Checking conditions to load countries automatically:"
  __logd "  PROCESS_TYPE: '${PROCESS_TYPE}'"
  __logd "  Expected: '--base'"
  __logd "  updateCountries.sh path: '${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh'"
  if [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh" ]]; then
   __logd "  updateCountries.sh exists: YES"
  else
   __logd "  updateCountries.sh exists: NO"
  fi

  if [[ "${PROCESS_TYPE}" == "--base" ]] && [[ -f "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh" ]] \
   && [[ "${SKIP_AUTO_LOAD_COUNTRIES:-false}" != "true" ]]; then
   __logi "Attempting to load countries automatically in base mode..."
   __logi "This process may take a long time (30-60 minutes) as it downloads and processes all country boundaries..."

   # Execute updateCountries.sh as independent subprocess (like processAPINotes does with processPlanetNotes)
   # Each script maintains its own TMP_DIR and log file, ensuring complete log separation
   # Pass DBNAME explicitly to ensure updateCountries.sh uses the correct database
   # This is critical when running in test mode where DBNAME might be different
   # updateCountries.sh is completely independent - it creates its own TMP_DIR and log file
   # Note: updateCountries.sh will unset LOG_FILE to prevent inheriting parent's log file
   if ! DBNAME="${DBNAME}" "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh" --base; then
    __loge "ERROR: Failed to load countries automatically. updateCountries.sh is required for proper operation."
    __loge "This is a critical error. processPlanetNotes.sh cannot continue without geographic data."
    __loge "Please fix the issue and run updateCountries.sh manually: ./bin/process/updateCountries.sh --base"
    __create_failed_marker "${ERROR_EXECUTING_PLANET_DUMP}" \
     "updateCountries.sh failed during processPlanetNotes.sh --base" \
     "Fix the issue with updateCountries.sh and run manually: ./bin/process/updateCountries.sh --base"
    exit "${ERROR_EXECUTING_PLANET_DUMP}"
   fi

   # Verify that countries were actually loaded after updateCountries.sh execution
   # Re-check COUNTRIES_COUNT to confirm data is present
   local COUNTRIES_COUNT_AFTER
   COUNTRIES_COUNT_AFTER=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM countries;" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")

   if [[ "${COUNTRIES_COUNT_AFTER:-0}" -gt 0 ]]; then
    __logi "Countries and maritimes areas loaded successfully (${COUNTRIES_COUNT_AFTER} countries/maritimes)."
    __logi "Note: Location notes will be processed after get_country() function is created."
    # Do not call __getLocationNotes here - it will be called after creating get_country()
   else
    __loge "ERROR: updateCountries.sh completed, but no countries were found in the database (count: ${COUNTRIES_COUNT_AFTER})."
    __loge "This indicates that updateCountries.sh did not load the data correctly."
    __loge "Please check the updateCountries.sh log file and run it manually: ./bin/process/updateCountries.sh --base"
    __create_failed_marker "${ERROR_EXECUTING_PLANET_DUMP}" \
     "updateCountries.sh completed but no countries loaded during processPlanetNotes.sh --base" \
     "Check updateCountries.sh log and run manually: ./bin/process/updateCountries.sh --base"
    exit "${ERROR_EXECUTING_PLANET_DUMP}"
   fi
  else
   __logw "Skipping automatic country loading."
   if [[ "${PROCESS_TYPE}" != "--base" ]]; then
    __logw "  Reason: Not running in base mode (PROCESS_TYPE='${PROCESS_TYPE}')."
   fi
   if [[ ! -f "${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh" ]]; then
    __logw "  Reason: updateCountries.sh not found at '${SCRIPT_BASE_DIRECTORY}/bin/process/updateCountries.sh'."
   fi
   if [[ "${SKIP_AUTO_LOAD_COUNTRIES:-false}" == "true" ]]; then
    __logw "  Reason: SKIP_AUTO_LOAD_COUNTRIES=true (test mode or manual control)."
   fi
   __logw "Notes will be processed without country assignment."
   __logw "To assign countries later, run: ./bin/process/updateCountries.sh --base"
   __logw "Note: Countries will be assigned automatically when processPlanetNotes.sh completes."
  fi
 fi

 __log_finish
}

# Checks for previous failed execution and displays error message.
# Exits if failed execution marker file exists.
##
# Checks for previous failed execution marker file
# Verifies if a previous execution failed by checking for failed execution marker file.
# If marker file exists, displays error details and recovery instructions, then exits
# script with ERROR_PREVIOUS_EXECUTION_FAILED. Prevents repeated failures by blocking
# execution until issue is resolved.
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   Exits with ERROR_PREVIOUS_EXECUTION_FAILED if marker file exists
#   Returns 0 if no marker file exists
#
# Error codes:
#   0: Success - No previous failure detected
#   ERROR_PREVIOUS_EXECUTION_FAILED: Failure - Previous execution failed (exits script)
#
# Error conditions:
#   0: Success - No failed execution marker found
#   ERROR_PREVIOUS_EXECUTION_FAILED: Previous failure detected - Marker file exists (exits script)
#
# Context variables:
#   Reads:
#     - FAILED_EXECUTION_FILE: Path to failed execution marker file (required)
#     - LOG_LEVEL: Controls logging verbosity
#     - ERROR_PREVIOUS_EXECUTION_FAILED: Error code for previous execution failure (defined in calling script)
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Checks for failed execution marker file existence
#   - Displays error details from marker file
#   - Displays recovery instructions
#   - Exits script with ERROR_PREVIOUS_EXECUTION_FAILED if marker exists
#   - Writes log messages to stderr
#   - No file, database, or network operations
#
# Notes:
#   - Marker file is created by __trapOn() ERR trap handler on script failure
#   - Prevents repeated failures by blocking execution until issue is resolved
#   - User must manually remove marker file after fixing the issue
#   - Critical function: Prevents cascading failures
#   - Should be called early in script execution (before processing starts)
#   - Recovery instructions are displayed to help user fix the issue
#
# Example:
#   export FAILED_EXECUTION_FILE="/tmp/processPlanetNotes_failed_execution"
#   export ERROR_PREVIOUS_EXECUTION_FAILED=255
#   __checkPreviousFailedExecution
#   # Exits if marker file exists, continues if not
#
# Related: __trapOn() (creates failed execution marker on error)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __checkPreviousFailedExecution {
 __log_start
 if [[ -f "${FAILED_EXECUTION_FILE}" ]]; then
  __logw "Previous execution failed detected"
  __loge "Checking failed execution file: ${FAILED_EXECUTION_FILE}"

  __loge "========================================"
  __loge "PREVIOUS EXECUTION FAILED"
  __loge "========================================"
  echo ""
  echo "The previous execution of processPlanetNotes.sh failed."
  echo "Please review the error details below:"
  echo ""
  cat "${FAILED_EXECUTION_FILE}"
  echo ""
  echo "========================================"
  echo "To recover from this error:"
  echo "1. Review the error details above"
  echo "2. Fix the underlying problem"
  echo "3. Delete the marker file:"
  echo "   rm ${FAILED_EXECUTION_FILE}"
  echo "4. Rerun the script"
  echo "========================================"
  echo "Note: An email notification was already sent when the error occurred."
  echo ""

  exit "${ERROR_PREVIOUS_EXECUTION_FAILED}"
 fi
 __log_finish
}

# Sets up the lock file for single execution.
# Creates lock file descriptor and writes lock file content.
function __setupLockFile {
 __log_start
 __logw "Validating single execution."
 # Try to create/open lock file, handle permission errors explicitly
 if ! exec 7> "${LOCK}" 2> /dev/null; then
  __loge "Failed to create lock file: ${LOCK}"
  local LOCK_OWNER
  LOCK_OWNER=$(stat -c '%U:%G' "${LOCK}" 2> /dev/null || echo 'unknown')
  __loge "Lock file owner: ${LOCK_OWNER}"
  local CURRENT_USER
  CURRENT_USER=$(whoami 2> /dev/null || echo 'unknown')
  __loge "Current user: ${CURRENT_USER}"
  local LOCK_PERMS
  LOCK_PERMS=$(stat -c '%a' "${LOCK}" 2> /dev/null || echo 'unknown')
  __loge "Lock file permissions: ${LOCK_PERMS}"
  __loge "This may be a permission issue. Try removing the lock file manually:"
  __loge "  rm -f ${LOCK}"
  __loge "Or run this script with appropriate permissions."
  export SCRIPT_EXIT_CODE="${ERROR_GENERAL}"
  exit "${ERROR_GENERAL}"
 fi
 ONLY_EXECUTION="no"
 if ! flock -n 7; then
  __loge "Another instance of ${BASENAME} is already running."
  __loge "Lock file: ${LOCK}"
  if [[ -f "${LOCK}" ]]; then
   __loge "Lock file contents:"
   cat "${LOCK}" >&2 || true
  fi
  export SCRIPT_EXIT_CODE=1
  exit 1
 fi
 ONLY_EXECUTION="yes"

 local START_DATE
 START_DATE=$(date '+%Y-%m-%d %H:%M:%S' 2> /dev/null || echo 'unknown')
 cat > "${LOCK}" << EOF
PID: $$
Process: ${BASENAME}
Started: ${START_DATE}
Temporary directory: ${TMP_DIR}
Process type: ${PROCESS_TYPE}
Main script: ${0}
EOF
 __logd "Lock file content written to: ${LOCK}"
 __log_finish
}

# Downloads, validates, and processes Planet notes in base mode.
# Creates base structure, downloads notes, validates XML, and processes them.
function __processPlanetBaseMode {
 __log_start
 __logi "Running in base mode - creating complete structure and processing initial data"
 __dropSyncTables
 __dropApiTables
 __dropGenericObjects
 __dropBaseTables
 __createBaseTables
 __createSyncTables
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __downloadPlanetNotes; then
  __create_failed_marker "${ERROR_DOWNLOADING_NOTES}" \
   "Failed to download Planet notes" \
   "Check network connectivity and OSM Planet server status. If temporary, delete this file and retry"
  exit "${ERROR_DOWNLOADING_NOTES}"
 fi

 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  __logi "Validating Planet XML file (structure, dates, coordinates)..."
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __validatePlanetNotesXMLFileComplete; then
   __loge "ERROR: XML validation failed. Stopping process."
   __create_failed_marker "${ERROR_DATA_VALIDATION}" \
    "XML validation failed during Planet processing" \
    "Check the Planet XML file for structural, date, or coordinate issues"
   exit "${ERROR_DATA_VALIDATION}"
  fi
 else
  __logw "WARNING: XML validation SKIPPED (SKIP_XML_VALIDATION=true)"
  __logw "Assuming Planet XML is well-formed and valid (faster processing)"
 fi

 __logi "Counting notes in Planet XML file: ${PLANET_NOTES_FILE}"
 __countXmlNotesPlanet "${PLANET_NOTES_FILE}"
 __logi "TOTAL_NOTES after counting: ${TOTAL_NOTES}"
 if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
  __logi "TOTAL_NOTES is greater than 0 (${TOTAL_NOTES}), proceeding to process notes with parallel processing"
  __logi "About to call __processPlanetNotesWithParallel"
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __processPlanetNotesWithParallel; then
   local PARALLEL_EXIT_CODE=$?
   __loge "ERROR: Failed to process Planet notes in parallel (exit code: ${PARALLEL_EXIT_CODE})"
   __create_failed_marker "${ERROR_EXECUTING_PLANET_DUMP}" \
    "Failed to process Planet notes in parallel" \
    "Check logs for details on which part(s) failed. Review parallel processing errors."
   exit "${ERROR_EXECUTING_PLANET_DUMP}"
  fi
  __logi "Returned from __processPlanetNotesWithParallel, exit code: $?"
 else
  __logi "No notes found in XML file (TOTAL_NOTES=${TOTAL_NOTES}), skipping processing."
 fi
 __log_finish
}

# Downloads, validates, and processes Planet notes in sync mode.
# Checks base tables, creates if needed, downloads notes, validates XML, and processes them.
function __processPlanetSyncMode {
 __log_start
 __logi "Running in sync mode - processing new notes only"
 __dropSyncTables
 set +E
 export RET_FUNC=0
 __checkBaseTables
 if [[ "${RET_FUNC}" -ne 0 ]]; then
  __createBaseTables
 fi
 set -E
 __createSyncTables
 # shellcheck disable=SC2310
 # Function is invoked in if condition intentionally
 if ! __downloadPlanetNotes; then
  __create_failed_marker "${ERROR_DOWNLOADING_NOTES}" \
   "Failed to download Planet notes" \
   "Check network connectivity and OSM Planet server status. If temporary, delete this file and retry"
  exit "${ERROR_DOWNLOADING_NOTES}"
 fi

 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  __logi "Validating Planet XML file (structure, dates, coordinates)..."
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __validatePlanetNotesXMLFileComplete; then
   __loge "ERROR: XML validation failed. Stopping process."
   __create_failed_marker "${ERROR_DATA_VALIDATION}" \
    "XML validation failed during Planet processing" \
    "Check the Planet XML file for structural, date, or coordinate issues"
   exit "${ERROR_DATA_VALIDATION}"
  fi
 else
  __logw "WARNING: XML validation SKIPPED (SKIP_XML_VALIDATION=true)"
  __logw "Assuming Planet XML is well-formed and valid (faster processing)"
 fi

 __logi "Counting notes in Planet XML file: ${PLANET_NOTES_FILE}"
 __countXmlNotesPlanet "${PLANET_NOTES_FILE}"
 __logi "TOTAL_NOTES after counting: ${TOTAL_NOTES}"
 if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
  __logi "TOTAL_NOTES is greater than 0 (${TOTAL_NOTES}), proceeding to process notes with parallel processing"
  __logi "About to call __processPlanetNotesWithParallel"
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __processPlanetNotesWithParallel; then
   local PARALLEL_EXIT_CODE=$?
   __loge "ERROR: Failed to process Planet notes in parallel (exit code: ${PARALLEL_EXIT_CODE})"
   __create_failed_marker "${ERROR_EXECUTING_PLANET_DUMP}" \
    "Failed to process Planet notes in parallel" \
    "Check logs for details on which part(s) failed. Review parallel processing errors."
   exit "${ERROR_EXECUTING_PLANET_DUMP}"
  fi
  __logi "Returned from __processPlanetNotesWithParallel, exit code: $?"
 else
  __logi "No notes found in XML file (TOTAL_NOTES=${TOTAL_NOTES}), skipping processing."
 fi
 __log_finish
}

##
# Processes geographic data and location notes in base mode
# Orchestrates geographic data processing workflow for base mode. Processes geographic
# data (countries/maritimes), creates get_country() function, processes location notes
# (assigns countries to notes), and organizes areas. Used when processing Planet data
# from scratch (--base mode).
#
# Parameters:
#   $@: Optional arguments passed to __getLocationNotes (optional)
#
# Returns:
#   0: Success - All operations completed successfully (or skipped if no countries)
#   Non-zero: Failure - Geographic data processing, function creation, or location processing failed
#
# Error codes:
#   0: Success - All operations completed successfully
#   Non-zero: Failure - Any step failed (geographic data, function creation, location processing, area organization)
#
# Error conditions:
#   0: Success - All operations completed successfully
#   0: Success - No countries found (skips location processing, continues)
#   Non-zero: Geographic data processing failed - __processGeographicData returned error
#   Non-zero: Function creation failed - __createFunctionToGetCountry returned error
#   Non-zero: Location processing failed - __getLocationNotes returned error
#   Non-zero: Area organization failed - __organizeAreas returned error (logged as warning, continues)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - RET_FUNC: Return code from __organizeAreas (set by function)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - RET_FUNC: Return code from __organizeAreas (exported)
#   Modifies: None
#
# Side effects:
#   - Processes geographic data (countries/maritimes boundaries)
#   - Creates get_country() PostgreSQL function
#   - Queries database to count countries
#   - Processes location notes (assigns countries to notes)
#   - Organizes areas (optimizes country lookup)
#   - Writes log messages to stderr
#   - Database operations: Function creation, note updates, area organization
#   - No file or network operations (delegated to called functions)
#
# Notes:
#   - Workflow: Process geographic data → Create function → Process location notes → Organize areas
#   - Only processes location notes if countries table has data (COUNTRIES_COUNT > 0)
#   - Area organization failure is non-fatal (logged as warning, continues)
#   - Used in base mode (--base) when processing Planet data from scratch
#   - Critical function: Part of Planet base mode workflow
#   - Location notes processing requires get_country() function to exist
#
# Example:
#   export DBNAME="osm_notes"
#   export PROCESS_TYPE="--base"
#   __processGeographicDataBaseMode
#
# Related: __processGeographicData() (processes geographic data)
# Related: __createFunctionToGetCountry() (creates get_country function)
# Related: __getLocationNotes() (processes location notes)
# Related: __organizeAreas() (organizes areas)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __processGeographicDataBaseMode {
 __log_start
 __logi "Processing geographic data in base mode..."
 __logd "Starting __processGeographicDataBaseMode function"
 if ! __processGeographicData; then
  __loge "ERROR: Failed to process geographic data"
  __log_finish
  return 1
 fi
 __logd "__processGeographicData completed successfully"

 __logi "Creating get_country() function..."
 __logd "Calling __createFunctionToGetCountry..."
 if ! __createFunctionToGetCountry; then
  __loge "ERROR: Failed to create get_country() function"
  __loge "__createFunctionToGetCountry returned non-zero exit code"
  __log_finish
  return 1
 fi
 __logd "__createFunctionToGetCountry completed successfully"

 local COUNTRIES_COUNT
 __logd "Checking countries count..."
 # Extract only numeric value from psql output (may include connection messages)
 COUNTRIES_COUNT=$(PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM countries;" 2> /dev/null | grep -E '^[0-9]+$' | tail -1 || echo "0")
 __logd "Countries count: ${COUNTRIES_COUNT}"
 if [[ "${COUNTRIES_COUNT:-0}" -gt 0 ]]; then
  __logi "Processing location notes with get_country() function..."
  __logd "Calling __getLocationNotes..."
  if ! __getLocationNotes "$@"; then
   __loge "ERROR: Failed to process location notes"
   __log_finish
   return 1
  fi
  __logd "__getLocationNotes completed successfully"
 else
  __logd "Skipping location notes processing (no countries found)"
 fi

 __logi "Organizing areas after geographic data is loaded..."
 __logd "Calling __organizeAreas..."
 set +e
 export RET_FUNC=0
 if ! __organizeAreas; then
  local ORGANIZE_AREAS_EXIT_CODE=$?
  export RET_FUNC="${ORGANIZE_AREAS_EXIT_CODE}"
  __logw "Areas organization failed (exit code: ${ORGANIZE_AREAS_EXIT_CODE}), but continuing with process..."
  __logd "__organizeAreas returned exit code: ${ORGANIZE_AREAS_EXIT_CODE}"
 else
  __logd "__organizeAreas completed successfully"
 fi
 set -e
 if [[ "${RET_FUNC}" -ne 0 ]]; then
  __logw "Areas organization failed, but continuing with process..."
 fi
 __logd "__processGeographicDataBaseMode completed successfully, returning 0"
 __log_finish
 return 0
}

##
# Processes geographic data and location notes in sync mode
# Orchestrates geographic data processing workflow for sync mode. Creates get_country()
# function, drops sync tables, processes geographic data (countries/maritimes), and
# organizes areas. Used when syncing Planet data (incremental updates, not --base mode).
#
# Parameters:
#   None (uses environment variables)
#
# Returns:
#   0: Success - All operations completed successfully
#   Non-zero: Failure - Function creation, table drop, geographic data processing, or area organization failed
#
# Error codes:
#   0: Success - All operations completed successfully
#   Non-zero: Failure - Any step failed (function creation, table drop, geographic data, area organization)
#
# Error conditions:
#   0: Success - All operations completed successfully
#   Non-zero: Function creation failed - __createFunctionToGetCountry returned error
#   Non-zero: Table drop failed - __dropSyncTables returned error
#   Non-zero: Geographic data processing failed - __processGeographicData returned error
#   Non-zero: Area organization failed - __organizeAreas returned error (logged as warning, continues)
#
# Context variables:
#   Reads:
#     - DBNAME: PostgreSQL database name (required)
#     - PGAPPNAME: PostgreSQL application name (optional)
#     - RET_FUNC: Return code from __organizeAreas (set by function)
#     - LOG_LEVEL: Controls logging verbosity
#   Sets:
#     - RET_FUNC: Return code from __organizeAreas (exported)
#   Modifies:
#     - Drops sync tables (via __dropSyncTables)
#
# Side effects:
#   - Creates get_country() PostgreSQL function
#   - Drops sync tables (notes_sync, note_comments_sync)
#   - Processes geographic data (countries/maritimes boundaries)
#   - Organizes areas (optimizes country lookup)
#   - Writes log messages to stderr
#   - Database operations: Function creation, table drops, area organization
#   - No file or network operations (delegated to called functions)
#
# Notes:
#   - Workflow: Create function → Drop sync tables → Process geographic data → Organize areas
#   - Sync mode does not process location notes (only base mode does)
#   - Area organization failure is non-fatal (logged as warning, continues)
#   - Used in sync mode (incremental updates, not --base mode)
#   - Critical function: Part of Planet sync mode workflow
#   - Drops sync tables before processing geographic data (cleanup)
#
# Example:
#   export DBNAME="osm_notes"
#   export PROCESS_TYPE=""
#   __processGeographicDataSyncMode
#
# Related: __createFunctionToGetCountry() (creates get_country function)
# Related: __dropSyncTables() (drops sync tables)
# Related: __processGeographicData() (processes geographic data)
# Related: __organizeAreas() (organizes areas)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __processGeographicDataSyncMode {
 __log_start
 __logi "Processing geographic data in sync mode..."
 __logd "Starting __processGeographicDataSyncMode function"

 __logi "Creating get_country() function..."
 __logd "Calling __createFunctionToGetCountry..."
 if ! __createFunctionToGetCountry; then
  __loge "ERROR: Failed to create get_country() function"
  __loge "__createFunctionToGetCountry returned non-zero exit code"
  __log_finish
  return 1
 fi
 __logd "__createFunctionToGetCountry completed successfully"

 __logi "Dropping sync tables..."
 __logd "Calling __dropSyncTables..."
 if ! __dropSyncTables; then
  __loge "ERROR: Failed to drop sync tables"
  __loge "__dropSyncTables returned non-zero exit code"
  __log_finish
  return 1
 fi
 __logd "__dropSyncTables completed successfully"

 __logi "Processing geographic data..."
 __logd "Calling __processGeographicData..."
 if ! __processGeographicData; then
  __loge "ERROR: Failed to process geographic data"
  __loge "__processGeographicData returned non-zero exit code"
  __log_finish
  return 1
 fi
 __logd "__processGeographicData completed successfully"

 __logi "Organizing areas after geographic data is loaded..."
 __logd "Calling __organizeAreas..."
 set +e
 export RET_FUNC=0
 if ! __organizeAreas; then
  local ORGANIZE_AREAS_EXIT_CODE=$?
  export RET_FUNC="${ORGANIZE_AREAS_EXIT_CODE}"
  __logw "Areas organization failed (exit code: ${ORGANIZE_AREAS_EXIT_CODE}), but continuing with process..."
  __logd "__organizeAreas returned exit code: ${ORGANIZE_AREAS_EXIT_CODE}"
 else
  __logd "__organizeAreas completed successfully"
 fi
 set -e
 if [[ "${RET_FUNC}" -ne 0 ]]; then
  __logw "Areas organization failed, but continuing with process..."
 fi
 __logd "__processGeographicDataSyncMode completed successfully, returning 0"
 __log_finish
 return 0
}

######
# MAIN

function main() {
 # Enable bash debug mode if BASH_DEBUG environment variable is set
 if [[ "${BASH_DEBUG:-}" == "true" ]] || [[ "${BASH_DEBUG:-}" == "1" ]]; then
  set -xv
 fi

 __log_start
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Process ID: ${$}"
 __logi "Processing: '${PROCESS_TYPE}'."

 if [[ "${PROCESS_TYPE}" == "-h" ]] \
  || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  SHOWING_HELP="true"
  __show_help
 else
  if [[ "${PROCESS_TYPE}" == "" ]]; then
   __logi "Process: Imports new notes from Planet."
  elif [[ "${PROCESS_TYPE}" == "--base" ]]; then
   __logi "Process: From scratch."

  fi
 fi

 __checkPreviousFailedExecution

 # Validate parameters before proceeding
 # Note: __checkPrereqs will exit directly if invalid parameter is detected
 __checkPrereqs

 __logw "Starting process."

 __trapOn
 __setupLockFile

 if [[ "${PROCESS_TYPE}" == "--base" ]]; then
  __processPlanetBaseMode
 elif [[ "${PROCESS_TYPE}" == "" ]]; then
  __processPlanetSyncMode
 fi

 if [[ "${PROCESS_TYPE}" == "--base" ]]; then
  if ! __processGeographicDataBaseMode; then
   __loge "ERROR: Failed to process geographic data in base mode"
   exit 1
  fi
 elif [[ "${PROCESS_TYPE}" == "" ]]; then
  if ! __processGeographicDataSyncMode; then
   __loge "ERROR: Failed to process geographic data in sync mode"
   exit 1
  fi
 fi

 # Create procedures (required for all modes - base & sync)
 __createProcedures # all

 __cleanNotesFiles  # base & sync
 __analyzeAndVacuum # base & sync

 rm -f "${LOCK}"
 __logw "Ending process."
 __log_finish
}

# Allows other users to read the directory.
chmod go+x "${TMP_DIR}"
# Shows the help information.
function __show_help {
 # Set flag to indicate we're showing help (prevents cleanup interference)
 export SHOWING_HELP="true"

 echo "${BASENAME} version ${VERSION}"
 echo "This is a script that downloads the OSM notes from the Planet,"
 echo "processes them with AWK extraction to create flat CSV files,"
 echo "and finally it uploads them into a PostgreSQL database."
 echo
 echo "It could receive one of these parameters:"
 echo " * --base : to starts from scratch from Planet notes file (complete setup)."
 echo " * Without parameter, it processes the new notes from Planet notes file."
 echo
 echo "Note: This script focuses only on notes processing and database structure."
 echo "      Geographic data (countries and maritimes) must be loaded separately using updateCountries.sh"
 echo
 echo "Environment variable:"
 echo " * CLEAN could be set to false, to left all created files."
 echo " * LOG_LEVEL specifies the logger levels. Possible values are:"
 echo "   DEBUG, INFO, WARN, ERROR"
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 if [[ ! -t 1 ]]; then
  export LOG_FILE="${LOG_FILENAME}"
  {
   __start_logger
   main
  } >> "${LOG_FILENAME}" 2>&1
  if [[ -n "${CLEAN:-}" ]] && [[ "${CLEAN}" = true ]]; then
   mv "${LOG_FILENAME}" \
    "${LOG_DIR}/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
   # Remove directory and all contents (may contain CSV files from processing)
   rm -rf "${TMP_DIR}" 2> /dev/null || true
  fi
 else
  __start_logger
  main
 fi
fi
