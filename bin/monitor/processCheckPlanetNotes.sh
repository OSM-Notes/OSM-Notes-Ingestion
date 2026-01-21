#!/bin/bash

# This script checks the loaded notes in the database, with a new planet
# download, and compares the notes. It allows to identify incorrectly
# processed notes. The scripts downloads the notes from planet, and load
# them into a new table for this purpose.
#
# The script structure is:
# * Creates the database structure.
# * Downloads the planet notes.
# * Converts the notes into flat CSV files.
# * Imports the notes into the db.
#
# This is an example about how to call this script:
#
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/processCheckPlanetNotes.sh
#
# When running under MacOS or zsh, it is better to invoke bash:
# bash ./processPlanetNotes.sh
#
# To follow the progress you can execute:
#   tail -40f $(ls -1rtd /tmp/processCheckPlanetNotes_* | tail -1)/processCheckPlanetNotes.log
#
# The database should already be prepared with base tables for notes.
#
# This is the list of error codes:
# 1) Help message displayed
# 238) Previous execution failed
# 241) Library or utility missing
# 242) Invalid argument
# 243) Logger utility is missing
# 247) Error downloading notes
# 255) General error
#
# For contributing, please execute these commands before submitting:
# * shellcheck -x -o all processCheckPlanetNotes.sh
# * shfmt -w -i 1 -sr -bn processCheckPlanetNotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2026-01-20
VERSION="2026-01-20"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with a non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory for the project.
# Only set SCRIPT_BASE_DIRECTORY if not already defined (e.g., in test environment)
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

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME

# Set PostgreSQL application name for monitoring
# This allows monitoring tools to identify which script is using the database
export PGAPPNAME="${BASENAME}"

# Load path configuration functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/pathConfigurationFunctions.sh"

# Initialize all directories (logs, temp, locks)
__init_directories "${BASENAME}"

# Type of process to run in the script.
if [[ -z "${PROCESS_TYPE:-}" ]]; then
 declare -r PROCESS_TYPE=${1:-}
fi

# Planet notes file configuration.
# (Declared in processPlanetFunctions.sh)

# Output CSV files for check processing.
if [[ -z "${OUTPUT_NOTES_FILE:-}" ]]; then
 declare -r OUTPUT_NOTES_FILE="${TMP_DIR}/notes.csv"
fi
if [[ -z "${OUTPUT_NOTE_COMMENTS_FILE:-}" ]]; then
 declare -r OUTPUT_NOTE_COMMENTS_FILE="${TMP_DIR}/note_comments.csv"
fi
if [[ -z "${OUTPUT_TEXT_COMMENTS_FILE:-}" ]]; then
 declare -r OUTPUT_TEXT_COMMENTS_FILE="${TMP_DIR}/note_comments_text.csv"
fi

# PostgreSQL SQL script files.
# Drop check tables.
declare -r POSTGRES_11_DROP_CHECK_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes_11_dropCheckTables.sql"
# Create check tables.
declare -r POSTGRES_21_CREATE_CHECK_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes_21_createCheckTables.sql"
# Load check notes.
declare -r POSTGRES_31_LOAD_CHECK_NOTES="${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes_31_loadCheckNotes.sql"
# Analyze and vacuum.
declare -r POSTGRES_41_ANALYZE_AND_VACUUM="${SCRIPT_BASE_DIRECTORY}/sql/monitor/processCheckPlanetNotes_41_analyzeAndVacuum.sql"

###########
# FUNCTIONS

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Load validation functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"

# Load error handling functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/errorHandlingFunctions.sh"

# Load process functions (includes validation functions)
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/lib/functionsProcess.sh"

# Load planet-specific functions for validation
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
# Note: processPlanetNotes.sh sets a trap EXIT that uses SCRIPT_EXIT_CODE
# We will manage this trap in the execution block below
# __downloadPlanetNotes
# __validatePlanetNotesXMLFile
# __validatePlanetNotesXMLFileComplete

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}"
 echo "This script checks the loaded notes to validate if their state is"
 echo "correct."
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 # Checks prereqs.
 # Note: __checkPrereqsCommands calls __validate_properties which will exit
 # if DBNAME is not set, so we don't need set +e here
 __checkPrereqsCommands

 ## Validate SQL script files using centralized validation
 __logi "Validating SQL script files..."

 # Create array of SQL files to validate
 local SQL_FILES=(
  "${POSTGRES_11_DROP_CHECK_TABLES}"
  "${POSTGRES_21_CREATE_CHECK_TABLES}"
  "${POSTGRES_31_LOAD_CHECK_NOTES}"
  "${POSTGRES_41_ANALYZE_AND_VACUUM}"
 )

 # Validate each SQL file
 set +e
 for SQL_FILE in "${SQL_FILES[@]}"; do
  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if ! __validate_sql_structure "${SQL_FILE}"; then
   __loge "ERROR: SQL file validation failed: ${SQL_FILE}"
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 done
 set -e

 __log_finish
}

# Drop check tables.
function __dropCheckTables {
 __log_start
 __logi "Droping check tables."
 # Use -P pager=off to prevent opening vi/less for long output
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -P pager=off -f "${POSTGRES_11_DROP_CHECK_TABLES}" 2>&1
 __log_finish
}

# Creates check tables that receives the whole history.
function __createCheckTables {
 __log_start
 __logi "Creating tables."
 # Use -P pager=off to prevent opening vi/less for long output
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -P pager=off -f "${POSTGRES_21_CREATE_CHECK_TABLES}"
 __log_finish
}

# Generates CSV files from XML using AWK extraction.
# Parameters:
#   $1: XML file path
function __generateCheckCsvFiles {
 __log_start
 __logi "Generating CSV files from XML for check processing."

 local XML_FILE="${1}"

 # Process notes with AWK (fast and dependency-free)
 __logd "Processing notes with AWK: ${XML_FILE} -> ${OUTPUT_NOTES_FILE}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk" "${XML_FILE}" > "${OUTPUT_NOTES_FILE}"
 if [[ ! -f "${OUTPUT_NOTES_FILE}" ]]; then
  __loge "Notes CSV file was not created: ${OUTPUT_NOTES_FILE}"
  __log_finish
  return 1
 fi

 # Process comments with AWK (fast and dependency-free)
 __logd "Processing comments with AWK: ${XML_FILE} -> ${OUTPUT_NOTE_COMMENTS_FILE}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comments.awk" "${XML_FILE}" > "${OUTPUT_NOTE_COMMENTS_FILE}"
 if [[ ! -f "${OUTPUT_NOTE_COMMENTS_FILE}" ]]; then
  __loge "Comments CSV file was not created: ${OUTPUT_NOTE_COMMENTS_FILE}"
  __log_finish
  return 1
 fi

 # Process text comments with AWK (fast and dependency-free)
 __logd "Processing text comments with AWK: ${XML_FILE} -> ${OUTPUT_TEXT_COMMENTS_FILE}"
 awk -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_comment_texts.awk" "${XML_FILE}" > "${OUTPUT_TEXT_COMMENTS_FILE}"
 if [[ ! -f "${OUTPUT_TEXT_COMMENTS_FILE}" ]]; then
  __logw "Text comments CSV file was not created, generating empty file to continue: ${OUTPUT_TEXT_COMMENTS_FILE}"
  : > "${OUTPUT_TEXT_COMMENTS_FILE}"
 fi

 # Debug: Show generated CSV files and their sizes
 __logd "Generated CSV files:"
 local NOTES_LINES
 NOTES_LINES=$(wc -l < "${OUTPUT_NOTES_FILE}" 2> /dev/null || echo 0)
 # shellcheck disable=SC2310
 # Intentional: logging failures should not stop execution
 __logd "  Notes: ${OUTPUT_NOTES_FILE} (${NOTES_LINES} lines)" || true
 local COMMENTS_LINES
 COMMENTS_LINES=$(wc -l < "${OUTPUT_NOTE_COMMENTS_FILE}" 2> /dev/null || echo 0)
 # shellcheck disable=SC2310
 # Intentional: logging failures should not stop execution
 __logd "  Comments: ${OUTPUT_NOTE_COMMENTS_FILE} (${COMMENTS_LINES} lines)" || true
 local TEXT_LINES
 TEXT_LINES=$(wc -l < "${OUTPUT_TEXT_COMMENTS_FILE}" 2> /dev/null || echo 0)
 # shellcheck disable=SC2310
 # Intentional: logging failures should not stop execution
 __logd "  Text: ${OUTPUT_TEXT_COMMENTS_FILE} (${TEXT_LINES} lines)" || true

 __log_finish
}

# Loads new notes from check.
function __loadCheckNotes {
 __log_start
 # Loads the data in the database.
 # Create temporary SQL file with \copy commands
 local TEMP_SQL_FILE
 TEMP_SQL_FILE=$(mktemp)

 # Verify CSV files exist before attempting to load
 if [[ ! -f "${OUTPUT_NOTES_FILE}" ]]; then
  __loge "ERROR: Notes CSV file does not exist: ${OUTPUT_NOTES_FILE}"
  __log_finish
  return 1
 fi
 if [[ ! -f "${OUTPUT_NOTE_COMMENTS_FILE}" ]]; then
  __loge "ERROR: Comments CSV file does not exist: ${OUTPUT_NOTE_COMMENTS_FILE}"
  __log_finish
  return 1
 fi
 if [[ ! -f "${OUTPUT_TEXT_COMMENTS_FILE}" ]]; then
  __loge "ERROR: Text comments CSV file does not exist: ${OUTPUT_TEXT_COMMENTS_FILE}"
  __log_finish
  return 1
 fi

 # Post-process CSV files to remove part_id column (last column)
 # AWK generates 8 columns for notes (with id_country,part_id), 7 for comments (with part_id), 4 for text (with part_id)
 # Check tables have 7 columns for notes (with id_country, no part_id), 6 for comments (no part_id), 3 for text (no part_id)
 # Remove part_id (last field) from each line using awk
 __logd "Removing part_id column (last column) from CSV files for check tables..."
 local TEMP_NOTES_FILE
 TEMP_NOTES_FILE=$(mktemp)
 # For notes: keep first 7 fields (including id_country), remove part_id (8th field)
 awk -F',' 'BEGIN{OFS=","} {for(i=1;i<=7;i++) {if(i>1) printf ","; printf "%s", $i} printf "\n"}' "${OUTPUT_NOTES_FILE}" > "${TEMP_NOTES_FILE}" || {
  __loge "ERROR: Failed to remove part_id column from notes CSV"
  __log_finish
  return 1
 }
 mv "${TEMP_NOTES_FILE}" "${OUTPUT_NOTES_FILE}"

 local TEMP_COMMENTS_FILE
 TEMP_COMMENTS_FILE=$(mktemp)
 # For comments: remove last field (part_id), keep first 6 fields
 awk -F',' 'BEGIN{OFS=","} {for(i=1;i<=6;i++) {if(i>1) printf ","; printf "%s", $i} printf "\n"}' "${OUTPUT_NOTE_COMMENTS_FILE}" > "${TEMP_COMMENTS_FILE}" || {
  __loge "ERROR: Failed to remove part_id column from comments CSV"
  __log_finish
  return 1
 }
 mv "${TEMP_COMMENTS_FILE}" "${OUTPUT_NOTE_COMMENTS_FILE}"

 local TEMP_TEXT_FILE
 TEMP_TEXT_FILE=$(mktemp)
 # For text comments: remove last field (part_id), keep first 3 fields
 # Note: body field may contain commas inside quotes, but part_id is always last field after quotes
 # Use Python or perl for proper CSV parsing, or use simple sed for trailing comma
 sed 's/,$//' "${OUTPUT_TEXT_COMMENTS_FILE}" > "${TEMP_TEXT_FILE}" || {
  __loge "ERROR: Failed to remove part_id column from text comments CSV"
  __log_finish
  return 1
 }
 mv "${TEMP_TEXT_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"

 __logd "CSV files post-processed: removed part_id column"

 # Export variables for envsubst
 # envsubst requires variables to be exported to replace them
 export OUTPUT_NOTES_FILE
 export OUTPUT_NOTE_COMMENTS_FILE
 export OUTPUT_TEXT_COMMENTS_FILE

 __logd "Exporting variables for envsubst:"
 __logd "  OUTPUT_NOTES_FILE=${OUTPUT_NOTES_FILE}"
 __logd "  OUTPUT_NOTE_COMMENTS_FILE=${OUTPUT_NOTE_COMMENTS_FILE}"
 __logd "  OUTPUT_TEXT_COMMENTS_FILE=${OUTPUT_TEXT_COMMENTS_FILE}"

 # Substitute variables first
 # shellcheck disable=SC2016
 # SC2016: envsubst requires single quotes to prevent shell expansion
 envsubst '$OUTPUT_NOTES_FILE,$OUTPUT_NOTE_COMMENTS_FILE,$OUTPUT_TEXT_COMMENTS_FILE' \
  < "${POSTGRES_31_LOAD_CHECK_NOTES}" > "${TEMP_SQL_FILE}.tmp"
 local ENVSUBST_EXIT_CODE=$?

 if [[ ${ENVSUBST_EXIT_CODE} -ne 0 ]]; then
  __loge "ERROR: envsubst failed with exit code ${ENVSUBST_EXIT_CODE}"
  rm -f "${TEMP_SQL_FILE}.tmp" "${TEMP_SQL_FILE}"
  __log_finish
  return 1
 fi

 # Verify that variables were actually replaced
 # shellcheck disable=SC2016
 # SC2016: Single quotes needed to prevent shell expansion in grep pattern
 if grep -q '\${OUTPUT_NOTES_FILE}\|\${OUTPUT_NOTE_COMMENTS_FILE}\|\${OUTPUT_TEXT_COMMENTS_FILE}' "${TEMP_SQL_FILE}.tmp" 2> /dev/null; then
  __loge "ERROR: Variables were not replaced by envsubst. Check variable export."
  __loge "First 20 lines of generated SQL:"
  # shellcheck disable=SC2310
  # Intentional: logging failures should not stop execution
  head -n 20 "${TEMP_SQL_FILE}.tmp" | while IFS= read -r line; do
   __loge "  ${line}" || true
  done || true
  rm -f "${TEMP_SQL_FILE}.tmp" "${TEMP_SQL_FILE}"
  __log_finish
  return 1
 fi

 # Convert COPY FROM to \copy FROM (client-side copy)
 # \copy works from client side, so files don't need to be on server
 # Use awk to handle multi-line COPY statements and convert to single-line \copy
 awk '
 BEGIN { in_copy = 0; copy_buffer = ""; }
 /^COPY[ \t]+/ || /^[ \t]+COPY[ \t]+/ {
   in_copy = 1;
   gsub(/^[ \t]*COPY[ \t]+/, "\\copy ");
   copy_buffer = $0;
   next;
 }
 in_copy == 1 {
   # Accumulate all lines until we find the semicolon (end of COPY statement)
   gsub(/^[ \t]+|[ \t]+$/, "");
   # Remove SQL comments from the line
   gsub(/--.*$/, "");
   gsub(/^[ \t]+|[ \t]+$/, "");
   if (copy_buffer != "") {
     copy_buffer = copy_buffer " " $0;
   } else {
     copy_buffer = $0;
   }
   if (/;/) {
     # Output complete \copy command as a single line
     # psql requires \copy to be on a single line when reading from file
     # Remove any remaining comments
     gsub(/--.*$/, "", copy_buffer);
     gsub(/[ \t]+$/, "", copy_buffer);
     print copy_buffer;
     in_copy = 0;
     copy_buffer = "";
     next;
   }
   next;
 }
 { print; }
 ' "${TEMP_SQL_FILE}.tmp" > "${TEMP_SQL_FILE}" \
  || sed -E 's/^COPY[ \t]+/\\copy /g; s/^[ \t]+COPY[ \t]+/\\copy /g' "${TEMP_SQL_FILE}.tmp" > "${TEMP_SQL_FILE}" || true

 rm -f "${TEMP_SQL_FILE}.tmp"

 # Execute SQL file with psql (required for \copy commands)
 # Use -P pager=off to prevent opening vi/less for long output
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -P pager=off -f "${TEMP_SQL_FILE}" 2>&1
 local PSQL_EXIT_CODE=$?

 # Clean up temporary file
 rm -f "${TEMP_SQL_FILE}"

 if [[ ${PSQL_EXIT_CODE} -ne 0 ]]; then
  __loge "ERROR: Failed to load check notes (exit code: ${PSQL_EXIT_CODE})"
  __log_finish
  return 1
 fi

 __log_finish
}

# Calculates statistics on all tables and vacuum.
function __analyzeAndVacuum {
 __log_start
 # Use -P pager=off to prevent opening vi/less for long output
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -P pager=off -f "${POSTGRES_41_ANALYZE_AND_VACUUM}"
 __log_finish
}

# Cleans files generated during the process.
function __cleanNotesFiles {
 __log_start
 rm -f "${PLANET_NOTES_FILE}" "${OUTPUT_NOTES_FILE}" \
  "${OUTPUT_NOTE_COMMENTS_FILE}" "${OUTPUT_TEXT_COMMENTS_FILE}"
 __log_finish
}

# Function that activates the error trap.
function __trapOn() {
 __log_start
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
   exit ${ERROR_EXIT_CODE};
  fi;
 }' ERR
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
  exit ${ERROR_GENERAL};
 }' SIGINT SIGTERM
 __log_finish
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
 __logi "Processing: ${PROCESS_TYPE}."

 if [[ "${PROCESS_TYPE}" == "-h" ]] \
  || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi
 __checkPrereqs
 __logw "Starting process."

 # Sets the trap in case of any signal.
 __trapOn
 exec 7> "${LOCK}"
 __logw "Validating single execution."
 # shellcheck disable=SC2034
 ONLY_EXECUTION="no"
 flock -n 7
 # shellcheck disable=SC2034
 ONLY_EXECUTION="yes"

 # Write lock file content with useful debugging information
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

 __dropCheckTables
 __createCheckTables
 __downloadPlanetNotes 2>&1

 # Validate XML only if validation is enabled
 if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
  __validatePlanetNotesXMLFileComplete
 else
  __logw "WARNING: XML validation SKIPPED (SKIP_XML_VALIDATION=true)"
 fi

 # Generate CSV files from XML
 __generateCheckCsvFiles "${PLANET_NOTES_FILE}"

 __loadCheckNotes
 __analyzeAndVacuum
 __cleanNotesFiles
 __logw "Ending process."
 __log_finish
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

# Function to clean up temporary directory
# This ensures all temporary files are removed, not just empty directories
function __cleanup_temp_dir() {
 local LAST_EXIT_CODE=$?
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  # Use rm -rf to recursively remove all contents, not just empty directories
  # This prevents accumulation of temporary files if main() leaves files behind
  rm -rf "${TMP_DIR}" 2> /dev/null || true
 fi
 exit "${LAST_EXIT_CODE}"
}

# Only execute main if this script is being run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 if [[ ! -t 1 ]]; then
  export LOG_FILE="${LOG_FILENAME}"
  # Disable trap before main execution to prevent it from changing exit code
  # This is needed because processPlanetNotes.sh sets a trap EXIT that uses SCRIPT_EXIT_CODE
  # The trap was set when we sourced processPlanetNotes.sh above
  trap - EXIT
  # Set our own cleanup trap to ensure temporary directory is always cleaned up
  # Use rm -rf instead of rmdir to ensure all temporary files are removed
  trap '__cleanup_temp_dir' EXIT
  # Initialize SCRIPT_EXIT_CODE before main execution so trap handlers can use it
  export SCRIPT_EXIT_CODE=0
  # Execute main function in a subshell to capture exit code correctly
  # Note: Using subshell ( ... ) instead of block { ... } so that exit calls
  # within main don't exit the entire script, allowing us to capture the exit code
  set +e
  (
   __start_logger
   main
  ) >> "${LOG_FILENAME}" 2>&1
  EXIT_CODE=$?
  # Preserve exit code before cleanup operations
  # Export SCRIPT_EXIT_CODE so trap handlers can access it
  export SCRIPT_EXIT_CODE="${EXIT_CODE}"
  # Preserve exit code before any cleanup operations that might change it
  FINAL_EXIT_CODE="${EXIT_CODE}"
  set -e
  mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log" 2> /dev/null || true
  # Clean up temporary directory and all its contents
  # Use rm -rf instead of rmdir to ensure all temporary files are removed
  # This matches the cleanup behavior from processPlanetNotes.sh
  # The trap will also clean up on exit, but we do it here explicitly too
  if [[ -d "${TMP_DIR}" ]]; then
   rm -rf "${TMP_DIR}" 2> /dev/null || true
  fi
  # Disable trap before exit since we've already cleaned up
  trap - EXIT
  exit "${FINAL_EXIT_CODE}"
 else
  # Interactive mode: disable trap from processPlanetNotes.sh and set our own
  # The trap from processPlanetNotes.sh only cleans up on error, we need to
  # clean up always to prevent temporary file accumulation
  trap - EXIT
  trap '__cleanup_temp_dir' EXIT
  __start_logger
  main
  # Explicit cleanup after main completes successfully
  if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
   rm -rf "${TMP_DIR}" 2> /dev/null || true
  fi
  trap - EXIT
 fi
fi
