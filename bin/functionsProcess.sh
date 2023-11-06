#!/bin/bash

# This is a script for sourcing from another scripts. It contains functions
# used in different scripts
#
# This scripts uses the constant ERROR_LOGGER_UTILITY.
#
# Author: Andres Gomez (AngocA)
# Version: 2023-10-07

# Error codes.
# 1: Help message.
# shellcheck disable=SC2034
declare -r ERROR_HELP_MESSAGE=1
# 241: Library or utility missing.
declare -r ERROR_MISSING_LIBRARY=241
# 242: Invalid argument for script invocation.
# shellcheck disable=SC2034
declare -r ERROR_INVALID_ARGUMENT=242
# 243: Logger utility is not available.
declare -r ERROR_LOGGER_UTILITY=243

# Logger framework.
# Taken from https://github.com/DushyanthJyothi/bash-logger.
declare -r LOGGER_UTILITY="${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"

# PostgreSQL files.
# Check base tables.
declare -r POSTGRES_CHECK_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess-checkBaseTables.sql"
# Create get country function.
declare -r POSTGRES_CREATE_FUNCTION_GET_COUNTRY="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess-createFunctionToGetCountry.sql"
# Create insert note procedure.
declare -r POSTGRES_CREATE_PROC_INSERT_NOTE="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess-createProcedure-insertNote.sql"
# Create insert note comment procedure.
declare -r POSTGRES_CREATE_PROC_INSERT_NOTE_COMMENT="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess-createProcedure-insertNotecomment.sql"
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
 if [[ -f "${LOGGER_UTILITY}" ]] ; then
  # Starts the logger mechanism.
  set +e
  # shellcheck source=../lib/bash_logger.sh
  source "${LOGGER_UTILITY}"
  local -i RET=${?}
  set -e
  if [[ "${RET}" -ne 0 ]] ; then
   printf "\nERROR: Invalid logger framework file.\n"
   exit "${ERROR_LOGGER_UTILITY}"
  fi
  # Logger levels: TRACE, DEBUG, INFO, WARN, ERROR.
  __set_log_level "${LOG_LEVEL}"
  __logd "Logger loaded."
 else
  printf "\nLogger was not found.\n"
 fi
}

# Function that activates the error trap.
function __trapOn() {
 __log_start
 trap '{ printf "%s ERROR: The script did not finish correctly. Line number: %d.\n" "$(date +%Y%m%d_%H:%M:%S)" "${LINENO}"; exit ;}' \
   ERR
 trap '{ printf "%s WARN: The script was terminated.\n" "$(date +%Y%m%d_%H:%M:%S)"; exit ;}' \
   SIGINT SIGTERM
 __log_finish
}

function __checkPrereqs_functions {
  ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_CHECK_BASE_TABLES}" ]] ; then
  __loge "ERROR: File is missing at ${POSTGRES_CHECK_BASE_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
  ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_CREATE_FUNCTION_GET_COUNTRY}" ]] ; then
  __loge "ERROR: File is missing at ${POSTGRES_CREATE_FUNCTION_GET_COUNTRY}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
  ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_CREATE_PROC_INSERT_NOTE}" ]] ; then
  __loge "ERROR: File is missing at ${POSTGRES_CREATE_PROC_INSERT_NOTE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
  ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_CREATE_PROC_INSERT_NOTE_COMMENT}" ]] ; then
  __loge "ERROR: File is missing at ${POSTGRES_CREATE_PROC_INSERT_NOTE_COMMENT}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
  ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_ORGANIZE_AREAS}" ]] ; then
  __loge "ERROR: File is missing at ${POSTGRES_ORGANIZE_AREAS}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
}

# Checks the base tables if exist.
function __checkBaseTables {
 __log_start
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_CHECK_BASE_TABLES}"
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]] ; then
  __createBaseTables
 fi
 __log_finish
}

# Downloads the notes from the planet.
function __downloadPlanetNotes {
 __log_start
 # Download Planet notes.
 __loge "Retrieving Planet notes file..."
 aria2c -c "${PLANET_NOTES_FILE}.bz2" -x 8 \
   "https://planet.openstreetmap.org/notes/${PLANET_NOTES_NAME}.bz2"
 wget -O "${PLANET_NOTES_FILE}.bz2.md5" \
   "https://planet.openstreetmap.org/notes/${PLANET_NOTES_NAME}.bz2.md5"

 # Validates the download with the hash value md5.
 diff "${PLANET_NOTES_FILE}.bz2" "${PLANET_NOTES_FILE}.bz2.md5"
 # If there is a difference, if will return non-zero value and fail the script.

 rm "${PLANET_NOTES_FILE}.bz2.md5"

 if [[ ! -r "${PLANET_NOTES_FILE}.bz2" ]] ; then
  __loge "ERROR: Downloading notes file."
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

 xmllint --noout --schema "${XMLSCHEMA_PLANET_NOTES}" \
  "${PLANET_NOTES_FILE}.xml"

 __log_finish
}

# Creates the XSLT files and process the XML files with them.
function __convertPlanetNotesToFlatFile {
 __log_start
 # Process the notes file.

 # Converts the XML into a flat file in CSV format.
 __logi "Processing notes from XML"
 java -Xmx6000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
   -s:"${PLANET_NOTES_FILE}.xml" -xsl:"${XSLT_NOTES_FILE}" \
   -o:"${OUTPUT_NOTES_FILE}"
 __logi "Processing comments from XML"
 java -Xmx6000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
   -s:"${PLANET_NOTES_FILE}.xml" -xsl:"${XSLT_NOTE_COMMENTS_FILE}" \
   -o:"${OUTPUT_NOTE_COMMENTS_FILE}"
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
 # Insert values for representative countries in each area.

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_ORGANIZE_AREAS}"
 __log_finish
}
