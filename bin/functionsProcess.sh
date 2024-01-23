#!/bin/bash

# This is a script for sourcing from another scripts. It contains functions
# used in different scripts
#
# This scripts uses the constant ERROR_LOGGER_UTILITY.
#
# For contributing, please execute these commands before subimitting:
# * shellcheck -x -o all functionsProcess.sh
# * shfmt -w -i 1 -sr -bn functionsProcess.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2024-01-22

# Error codes.
# 1: Help message.
# shellcheck disable=SC2034
declare -r ERROR_HELP_MESSAGE=1
# 238: Preivous execution failed.
declare -r ERROR_PREVIOUS_EXECUTION_FAILED=238
# 239: Library or utility missing.
declare -r ERROR_CREATING_REPORT=239
# 241: Library or utility missing.
declare -r ERROR_MISSING_LIBRARY=241
# 242: Invalid argument for script invocation.
# shellcheck disable=SC2034
declare -r ERROR_INVALID_ARGUMENT=242
# 243: Logger utility is not available.
declare -r ERROR_LOGGER_UTILITY=243
# 244: The list of ids for boundary geometries cannot be downloaded.
declare -r ERROR_DOWNLOADING_ID_LIST=244
# 245: No last update.
declare -r ERROR_NO_LAST_UPDATE=245
# 246: Planet process is currently running.
declare -r ERROR_PLANET_PROCESS_IS_RUNNING=246
# 247: Error downloading planet notes file.
declare -r ERROR_DOWNLOADING_NOTES=247
# 248: Error executing the Planet dump.
declare -r ERROR_EXECUTING_PLANET_DUMP=248
# 249: Error downloading boundary.
declare -r ERROR_DOWNLOADING_BOUNDARY=249
# 255: General error.
declare -r ERROR_GENERAL=255

# Previous execution failed.
declare -r FAILED_EXECUTION_FILE="/tmp/${BASENAME}_failed"

# Logger framework.
# Taken from https://github.com/DushyanthJyothi/bash-logger.
# shellcheck disable=SC2154
declare -r LOGGER_UTILITY="${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"

# Name of the file of the XSLT transformation for notes.
declare -r XSLT_NOTES_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt"
# Name of the file of the XSLT transformation for note comments.
declare -r XSLT_NOTE_COMMENTS_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-Planet-csv.xslt"
# Name of the file of the XSLT transformation for text comments.
declare -r XSLT_TEXT_COMMENTS_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-Planet-csv.xslt"
# XML Schema of the Planet notes file.
declare -r XMLSCHEMA_PLANET_NOTES="${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-planet-schema.xsd"

# Filename for the flat file for notes.
declare -r OUTPUT_NOTES_FILE="${TMP_DIR}/output-notes.csv"
# Filename for the flat file for comment notes.
declare -r OUTPUT_NOTE_COMMENTS_FILE="${TMP_DIR}/output-note_comments.csv"
# Filename for the flat file for text comment notes.
declare -r OUTPUT_TEXT_COMMENTS_FILE="${TMP_DIR}/output-text_comments.csv"

# Jar name of the XSLT processor.
declare SAXON_JAR
set +ue
SAXON_JAR="$(find "${SAXON_CLASSPATH:-.}" -maxdepth 1 -type f \
 -name "saxon-he-*.*.jar" | grep -v test | grep -v xqj | head -1)"
set -ue
readonly SAXON_JAR

# PostgreSQL files.
# Check base tables.
declare -r POSTGRES_CHECK_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess-checkBaseTables.sql"
# Create get country function.
declare -r POSTGRES_CREATE_FUNCTION_GET_COUNTRY="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess-createFunctionToGetCountry.sql"
# Create insert note procedure.
declare -r POSTGRES_CREATE_PROC_INSERT_NOTE="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess-createProcedure-insertNote.sql"
# Create insert note comment procedure.
declare -r POSTGRES_CREATE_PROC_INSERT_NOTE_COMMENT="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess-createProcedure-insertNoteComment.sql"
# Organize areas.
declare -r POSTGRES_ORGANIZE_AREAS="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess-organizeAreas.sql"

###########
# FUNCTIONS

### Logger

# Loads the logger (log4j like) tool.
# It has the following functions.
#function __log(){log ${@};}
#function __logt(){log_trace ${@};}
#function __logd(){log_debug ${@};}
#function __logi(){log_info ${@};}
#function __logw(){log_warn ${@};}
#function __loge(){log_error ${@};}
#function __logf(){log_fatal ${@};}

# Starts the logger utility.
function __start_logger() {
 if [[ -f "${LOGGER_UTILITY}" ]]; then
  # Starts the logger mechanism.
  set +e
  # shellcheck source=../lib/bash_logger.sh
  source "${LOGGER_UTILITY}"
  local -i RET=${?}
  set -e
  if [[ "${RET}" -ne 0 ]]; then
   printf "\nERROR: Invalid logger framework file.\n"
   exit "${ERROR_LOGGER_UTILITY}"
  fi
  # Logger levels: TRACE, DEBUG, INFO, WARN, ERROR.
  # shellcheck disable=SC2154
  __set_log_level "${LOG_LEVEL}"
  __logd "Logger loaded."
 else
  printf "\nLogger was not found.\n"
 fi
}

# Shows if there is another executing process.
function __onlyExecution {
 __log_start
 if [[ -n "${ONLY_EXECUTION:-}" ]] && [[ "${ONLY_EXECUTION}" == "no" ]]; then
  echo " There is another process already in execution"
 else
  touch "${FAILED_EXECUTION_FILE}"
 fi
 __log_finish
}

# Function that activates the error trap.
function __trapOn() {
 __log_start
 trap '{ printf "%s ERROR: The script ${BASENAME:-} did not finish correctly. Line number: %d%s.\n" "$(date +%Y%m%d_%H:%M:%S)" "${LINENO}" "$(__onlyExecution)"; exit ${ERROR_GENERAL};}' \
  ERR
 trap '{ printf "%s WARN: The script ${BASENAME:-} was terminated.\n" "$(date +%Y%m%d_%H:%M:%S)"; exit ${ERROR_GENERAL};}' \
  SIGINT SIGTERM
 __log_finish
}

# Checks prerequisites commands to run the script.
function __checkPrereqsCommands {
 __log_start
 set +e
 ## PostgreSQL
 __logd "Checking PostgreSQL."
 if ! psql --version > /dev/null 2>&1; then
  __loge "ERROR: PostgreSQL is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## PostGIS
 # shellcheck disable=SC2154
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 > /dev/null 2>&1 << EOF
 SELECT /* Notes-base */ PostGIS_version();
EOF
 RET=${?}
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: PostGIS is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Wget
 __logd "Checking wget."
 if ! wget --version > /dev/null 2>&1; then
  __loge "ERROR: Wget is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Aria2c
 if ! aria2c --version > /dev/null 2>&1; then
  __loge "ERROR: Aria2c is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## osmtogeojson
 if ! osmtogeojson --version > /dev/null 2>&1; then
  __loge "ERROR: osmtogeojson is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## gdal ogr2ogr
 if ! ogr2ogr --version > /dev/null 2>&1; then
  __loge "ERROR: ogr2ogr is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## flock
 if ! flock --version > /dev/null 2>&1; then
  __loge "ERROR: flock is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Mutt.
 if ! mutt -v > /dev/null 2>&1; then
  __loge "Falta instalar mutt."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## wget
 if ! wget --version > /dev/null 2>&1; then
  __loge "ERROR: wget is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Block-sorting file compressor
 if ! bzip2 --help > /dev/null 2>&1; then
  __loge "ERROR: bzip2 is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## XML lint
 __logd "Checking XML lint."
 if ! xmllint --version > /dev/null 2>&1; then
  __loge "ERROR: XMLlint is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Java
 __logd "Checking Java."
 if ! java --version > /dev/null 2>&1; then
  __loge "ERROR: Java JRE is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Bash 4 or greater.
 __logd "Checking Bash version."
 if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  __loge "ERROR: Requires Bash 4+."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 set -e
 __log_finish
}

function __checkPrereqs_functions {
 __log_start
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_CHECK_BASE_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_CHECK_BASE_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_CREATE_FUNCTION_GET_COUNTRY}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_CREATE_FUNCTION_GET_COUNTRY}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_CREATE_PROC_INSERT_NOTE}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_CREATE_PROC_INSERT_NOTE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_CREATE_PROC_INSERT_NOTE_COMMENT}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_CREATE_PROC_INSERT_NOTE_COMMENT}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_ORGANIZE_AREAS}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_ORGANIZE_AREAS}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __log_finish
}

# Checks the base tables if exist.
function __checkBaseTables {
 __log_start
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_CHECK_BASE_TABLES}"
 RET=${?}
 set -e
 RET_FUNC="${RET}"
 __log_finish
}

# Downloads the notes from the planet.
function __downloadPlanetNotes {
 __log_start
 set -e
 # Download Planet notes.
 __logw "Retrieving Planet notes file..."
 # shellcheck disable=SC2154
 aria2c -d "${TMP_DIR}" -o "${PLANET_NOTES_NAME}.bz2" -x 8 \
  "${PLANET}/notes/${PLANET_NOTES_NAME}.bz2"
 # shellcheck disable=SC2154
 wget -O "${PLANET_NOTES_FILE}.bz2.md5" \
  "${PLANET}/notes/${PLANET_NOTES_NAME}.bz2.md5"
 # Validates the download with the hash value md5.
 diff <(md5sum "${PLANET_NOTES_FILE}.bz2" | cut -d' ' -f 1 || true) \
  <(cut -d' ' -f 1 "${PLANET_NOTES_FILE}.bz2.md5" || true)
 # If there is a difference, if will return non-zero value and fail the script.

 rm "${PLANET_NOTES_FILE}.bz2.md5"

 if [[ ! -r "${PLANET_NOTES_FILE}.bz2" ]]; then
  __loge "ERROR: Downloading notes file."
  # shellcheck disable=SC2154
  exit "${ERROR_DOWNLOADING_NOTES}"
 fi
 __logi "Extracting Planet notes..."
 bzip2 -d "${PLANET_NOTES_FILE}.bz2"
 mv "${PLANET_NOTES_FILE}" "${PLANET_NOTES_FILE}.xml"
 __log_finish
}

# Validates the XML file to be sure everything will work fine.
function __validatePlanetNotesXMLFile {
 __log_start

 # shellcheck disable=SC2154
 xmllint --noout --schema "${XMLSCHEMA_PLANET_NOTES}" \
  "${PLANET_NOTES_FILE}.xml" 2>&1

 __log_finish
}

# Creates the XSLT files and process the XML files with them.
function __convertPlanetNotesToFlatFile {
 __log_start
 # Process the notes file.

 # Converts the XML into a flat file in CSV format.
 __logi "Processing notes from XML."
 # shellcheck disable=SC2154
 java -Xmx6000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
  -s:"${PLANET_NOTES_FILE}.xml" -xsl:"${XSLT_NOTES_FILE}" \
  -o:"${OUTPUT_NOTES_FILE}"
 __logi "Processing comments from XML."
 # shellcheck disable=SC2154
 java -Xmx6000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
  -s:"${PLANET_NOTES_FILE}.xml" -xsl:"${XSLT_NOTE_COMMENTS_FILE}" \
  -o:"${OUTPUT_NOTE_COMMENTS_FILE}"
 __logi "Processing text from XML."
 # shellcheck disable=SC2154
 java -Xmx6000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
  -s:"${PLANET_NOTES_FILE}.xml" -xsl:"${XSLT_TEXT_COMMENTS_FILE}" \
  -o:"${OUTPUT_TEXT_COMMENTS_FILE}"
 __log_finish
}

# Creates a function to get the country or maritime area from coordinates.
function __createFunctionToGetCountry {
 __log_start
 # Creates a function that performs a basic triage according to its longitude:
 # * -180 - -30: Americas.
 # * -30 - 25: West Europe and West Africa.
 # * 25 - 65: Middle East, East Africa and Russia.
 # * 65 - 180: Southeast Asia and Oceania.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_CREATE_FUNCTION_GET_COUNTRY}"
 __log_finish
}

# Creates procedures to insert notes and comments.
function __createProcedures {
 __log_start
 set -e
 # Creates a procedure that inserts a note.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_CREATE_PROC_INSERT_NOTE}"

 # Creates a procedure that inserts a note comment.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -f "${POSTGRES_CREATE_PROC_INSERT_NOTE_COMMENT}"
 __log_finish
}

# Assigns a value to each area to find it easily.
function __organizeAreas {
 __log_start
 set +e
 # Insert values for representative countries in each area.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_ORGANIZE_AREAS}"
 RET=${?}
 set -e
 RET_FUNC="${RET}"
 __log_finish
}
