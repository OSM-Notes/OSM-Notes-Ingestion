#!/bin/bash

# Generates a report of the differences of notes between the most recent
# planet file and the periodically ingested from API.
#
# To change the email addresses of the recipients, the EMAILS environment
# variable can be changed like:
#   export EMAILS="maptime.bogota@gmail.com,contact@osm.org"
#
# To check the last execution, you can just run:
#   cd $(find /tmp/ -name "notesCheckVerifier_*" -type d -printf "%T@ %p\n" 2> /dev/null | sort -n | cut -d' ' -f 2- | tail -n 1) ; tail -f notesCheckVerifier.log ; cd -
#
# The following environment variables helps to configure the script:
# * EMAILS : List of emails to send the report, separated by comma.
# * LOG_LEVEL : Log level in capitals.
#
# export EMAILS="angoca@yahoo.com" ; export LOG_LEVEL=WARN; cd ~/OSM-Notes-profile ; ./notesCheckVerifier.sh
#
# For contributing, please execute these commands at the end:
# * shellcheck -x -o all notesCheckVerifier.sh
# * shfmt -w -i 1 -sr -bn notesCheckVerifier.sh
#
# Autor: Andres Gomez Casanova - AngocA
# Version: 2023-10-06
declare -r VERSION="2023-10-06"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with a non-zero return code.
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

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Clean files.
declare CLEAN_FILES="${CLEAN_FILES:-true}"

# Base directory, where the script resides.
# Taken from https://stackoverflow.com/questions/59895/how-can-i-get-the-source-directory-of-a-bash-script-from-within-the-script-itsel
# shellcheck disable=SC2155
declare -r SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" \
 &> /dev/null && pwd)"

# Loads the global properties.
source "${SCRIPT_BASE_DIRECTORY}/../properties.sh"

# Logger framework.
# Taken from https://github.com/DushyanthJyothi/bash-logger.
declare -r LOGGER_UTILITY="${SCRIPT_BASE_DIRECTORY}/../bash_logger.sh"

# Mask for the files and directories.
umask 0000

# Name of this script.
declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME
# Temporal directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
# Log file for output.
declare LOG_FILE_NAME
LOG_FILE_NAME="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILE_NAME

# Lock file for single git execution.
declare LOCK
LOCK="/tmp/${BASENAME}.lock"
readonly LOCK

# Type of process to run in the script.
declare -r PROCESS_TYPE=${1:-}

# File that contains the ids or query to get the ids.
declare -r PROCESS_FILE=${PROCESS_TYPE}

# Report file.
declare -r REPORT=${TMP_DIR}/report.txt
# Complete report.
declare -r REPORT_ZIP=${TMP_DIR}/report.zip

###########
# FUNCTIONS

source "${SCRIPT_BASE_DIRECTORY}/../functionsProcess.sh"

# Shows the help information.
function __show_help {
 echo "${BASENAME} version ${VERSION}"
 echo "Checks the differences in the database from the most recent planet"
 echo "for notes and the notes ingested via API calls. This script works"
 echo "better around 0h UTF, when the planer file is published and the"
 echo "difference with the API calls are less."
 echo
 echo "If the script returns a lot of old differences, it is because the"
 echo "API calls script failed. In this case, the best is to recreate the"
 echo "base tables from a Planet with 'processPlanetNotes.sh'. Also, it is"
 echo "very important to notify the error with a GitHub issue in the project"
 echo "and attach as much information as possible to find a way to correct"
 echo "the error"
 echo
 echo "Written por: Andres Gomez (AngocA)"
 echo "MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 set +e
 # Checks prereqs.
 ## Mutt.
 if ! mutt -v > /dev/null 2>&1; then
  __loge "Falta instalar mutt."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## flock.
 if ! flock --version > /dev/null 2>&1; then
  __loge "Falta instalar flock."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Bash 4 or greater.
 if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  __loge "Requiere Bash 4+."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks if the process file exists.
 if [[ "${PROCESS_FILE}" != "" ]] && [[ ! -r "${PROCESS_FILE}" ]]; then
  __loge "El archivo para obtener los ids no se encuentra: ${PROCESS_FILE}."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 __log_finish
 set -e
}

# Downloads the planet notes.
function __downloadingPlanet {
 __log_start

 export SAXON_CLASSPATH=${SAXON_CLASSPATH:-~/saxon/}
 "${SCRIPT_BASE_DIRECTORY}/processCheckPlanetNotes.sh"

 __log_finish
}

# Checks the differences between planet and API notes.
function __checkingDifferences {
 __log_start

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "report.sql"
 zip "${REPORT_ZIP}" /tmp/differentNoteIds.csv \
  /tmp/differentNoteCommentIds.csv /tmp/differentNotes.csv \
  /tmp/differentNoteComments.csv

 __log_finish
}

# Sends the report of differences in the database.
function __sendMail {
 __log_start
 QTY=$(wc -l /tmp/differentNoteIds | cut -f 1 -d' ')
 if [[ "${QTY}" -ne 0 ]]; then
  __logi "Sending mail."
  {
   echo "These are the differences between the Planet file and the API calls"
   echo "for OSM notes profile."
   echo
   echo "Latest note:"
   cat /tmp/lastNote.csv
   echo
   cat /tmp/lastNoteComment.csv
   echo
   echo "This report was generated by:"
   echo "https://github.com/OSMLatam/OSM-Notes-profile"
  } >> "${REPORT}"
  echo "" | mutt -s "OSM Notes profile differences" -i "${REPORT}" -a "${REPORT_ZIP}" -- "${EMAILS}"
  __logi "Mensaje enviado."
 fi
 __log_finish
}

# Clean unnecessary files.
function __cleanFiles {
 __log_start
 if [[ "${CLEAN_FILES}" = "true" ]]; then
  __logi "Limpiando archivos innecesarios."
  rm -f "${REPORT}" "${REPORT_ZIP}"
 fi
 __log_finish
}

######
# MAIN

function main() {
 __logi "Preparing the env."
 __logd "Output saved at: ${TMP_DIR}."

 if [[ "${PROCESS_TYPE}" == "-h" ]] || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi
 __checkPrereqs
 __logw "Starting process."

 # Sets the trap in case of any signal.
 __trapOn
 exec 7> "${LOCK}"

 __downloadingPlanet
 __checkingDifferences
 __sendMail
 __cleanFiles
 __logw "Process finished."
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [[ ! -t 1 ]]; then
 __set_log_file "${LOG_FILE_NAME}"
 main >> "${LOG_FILE_NAME}" 2>&1
else
 main
fi
