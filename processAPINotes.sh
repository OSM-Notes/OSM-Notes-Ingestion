#!/bin/bash

# This scripts processes the most recents notes (creation or modification) from
# the OpenStreetMap API.
# * It downloads the notes via HTTP call.
# * Then with an XSLT transformation converts the data into flat files.
# * It uploads the data into temp tables of a PostreSQL database.
# * Finally, it synchronizes the master tables.
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument.
# 243) Logger utility is missing.
#
# Author: Andres Gomez (AngocA)
# Version: 2022-11-19
declare -r VERSION="2022-11-19"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with an non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# Error codes.
# 1: Help message.
declare -r ERROR_HELP_MESSAGE=1
# 241: Library or utility missing.
declare -r ERROR_MISSING_LIBRARY=241
# 242: Invalid argument for script invocation.
declare -r ERROR_INVALID_ARGUMENT=242
# 243: Logger utility is not available.
declare -r ERROR_LOGGER_UTILITY=243

# If all files should be deleted. In case of an error, this could be disabled.
# You can defined when calling: export CLEAN=false
declare -r CLEAN=${CLEAN:-true}

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-FATAL}"

# Logger framework.
# Taken from https://github.com/DushyanthJyothi/bash-logger.
declare -r LOGGER_UTILITY=bash_logger.sh

# Base directory, where the ticket script resides.
# Taken from https://stackoverflow.com/questions/59895/how-can-i-get-the-source-directory-of-a-bash-script-from-within-the-script-itsel
# shellcheck disable=SC2155
declare -r SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" \
  &> /dev/null && pwd)"

# Temporal directory for all files.
declare -r TMP_DIR=$(mktemp -d "/tmp/${0%.sh}-XXXXXX")
# Lof file for output.
declare -r LOG_FILE="${TMP_DIR}/${0%.sh}.log"

# Type of process to run in the script: base, sync or boundaries.
declare -r PROCESS_TYPE=${1:-}

# XML Schema of the API notes file.
declare -r XMLSCHEMA_API_NOTES="OSM-notes-API-schema.xsd"
# Jar name of the XSLT processor.
declare -r SAXON_JAR=${SAXON_CLASSPATH:-.}/saxon-he-11.4.jar
# Name of the file of the XSLT transformation for notes from API.
declare -r XSLT_NOTES_API_FILE="notes-API-csv.xslt"
# Name of the file of the XSLT transformation for note comments from API.
declare -r XSLT_NOTE_COMMENTS_API_FILE="note_comments-API-csv.xslt"
# Filename for the flat file for notes.
declare -r OUTPUT_NOTES_FILE="${TMP_DIR}/output-notes.csv"
# Filename for the flat file for comment notes.
declare -r OUTPUT_NOTE_COMMENTS_FILE="${TMP_DIR}/output-note_comments.csv"

# Name of the PostgreSQL database to insert or update the data.
declare -r DBNAME=notes

###########
# FUNCTIONS

### Logger

# Loads the logger (log4j like) tool.
# It has the following functions.
# __log default.
# __logt for trace.
# __logd for debug.
# __logi for info.
# __logw for warn.
# __loge for error. Writes in standard error.
# __logf for fatal.
# Declare mock functions, in order to have them in case the logger utility
# cannot be found.
function __log() { :; }
function __logt() { :; }
function __logd() { :; }
function __logi() { :; }
function __logw() { :; }
function __loge() { :; }
function __logf() { :; }
function __log_start() { :; }
function __log_finish() { :; }

# Starts the logger utility.
function __start_logger() {
 if [ -f "${SCRIPT_BASE_DIRECTORY}"/${LOGGER_UTILITY} ] ; then
  # Starts the logger mechanism.
  set +e
  # shellcheck source=./bash_logger.sh
  source "${SCRIPT_BASE_DIRECTORY}"/${LOGGER_UTILITY}
  local -i RET=${?}
  set -e
  if [ ${RET} -ne 0 ] ; then
   printf "\nERROR: Invalid logger framework file.\n"
   exit ${ERROR_LOGGER_UTILITY}
  fi
  # Logger levels: TRACE, DEBUG, INFO, WARN, ERROR.
  __bl_set_log_level "${LOG_LEVEL}"
  __logd "Logger loaded."
 else
  printf "\nLogger was not found.\n"
 fi
}

# Function that activates the error trap.
function __trapOn() {
 __log_start
 trap '{ printf "%s ERROR: The script did not finish correctly. Line number: %d.\n" "$(date +%Y-%m-%d_%H:%M:%S)" "${LINENO}"; exit ;}' \
   ERR
 trap '{ printf "%s WARN: The script was terminated.\n" "$(date +%Y%m%d_%H:%M:%S)"; exit 1 ;}' \
   SIGINT SIGTERM
 __log_finish
}

# Shows the help information.
function __show_help {
 __log_start
  echo "${0} version ${VERSION}."
  echo
  echo "This is a script that downloads the OSM notes from the OpenStreetMap"
  echo "API. It takes the most recent ones and synchronizes a database that"
  echo "holds the whole history."
  echo
  echo "It does not receive any parameter. This script should be configured"
  echo "in a crontab or similar scheduler."
  echo
  echo "Written by: Andres Gomez (AngocA)."
  echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
  exit ${ERROR_HELP_MESSAGE}
 __log_finish
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 __logd "Checking process type."
 if [ "${PROCESS_TYPE}" != "" ] && [ "${PROCESS_TYPE}" != "--help" ] \
   && [ "${PROCESS_TYPE}" != "-h" ] ; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string (nothing)."
  echo " * --help"
  exit ${ERROR_INVALID_ARGUMENT}
 fi
 set +e
 # Checks prereqs.
 ## PostgreSQL
 __logd "Checking PostgreSQL."
 if ! psql --version > /dev/null 2>&1 ; then
  echo "ERROR: PostgreSQL is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Wget
 __logd "Checking wget."
 if ! wget --version > /dev/null 2>&1 ; then
  echo "ERROR: Wget is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## osmtogeojson
 __logd "Checking OSMtoGeoJSON."
 if ! osmtogeojson --version > /dev/null 2>&1 ; then
  echo "ERROR: osmtogeojson is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## gdal ogr2ogr
 __logd "Checking GDAL ogr2ogr."
 if ! ogr2ogr --version > /dev/null 2>&1 ; then
  echo "ERROR: ogr2ogr is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## cURL
 __logd "Checking cURL."
 if ! curl --version > /dev/null 2>&1 ; then
  echo "ERROR: curl is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Java
 __logd "Checking Java."
 if ! java --version > /dev/null 2>&1 ; then
  echo "ERROR: Java JRE is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## XML lint
 __logd "Checking XML lint."
 if ! xmllint --version > /dev/null 2>&1 ; then
  echo "ERROR: XMLlint is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Saxon Jar
 __logd "Checking Saxon Jar."
 if [ ! -r "${SAXON_JAR}" ] ; then
  echo "ERROR: Saxon jar is missing at ${SAXON_JAR}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Bash 4 or greater.
 __logd "Checking Bash version."
 if [ "${BASH_VERSINFO}" -lt 4 ]; then
  echo "ERROR: Requires Bash 4+."
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 set -e
 __log_finish
}

# TODO Source the code from the base script

######
# MAIN

# Return value for several functions.
declare -i RET

__start_logger
__logi "Preparing environment."
__logd "Output saved at: ${TMP_DIR}"
# Sets the trap in case of any signal.
__trapOn
__checkPrereqs
if [ "${PROCESS_TYPE}" == "-h" ] || [ "${PROCESS_TYPE}" == "--help" ]; then
 __show_help
fi
#{
 __logw "Process started."
# TODO Locks for only one execution
 __logw "Process finished."
#} >> "${LOG_FILE}" 2>&1

if [ -n "${CLEAN}" ] && [ "${CLEAN}" = true ] ; then
 rm -f "${LOG_FILE}"
 rmdir "${TMP_DIR}"
fi
