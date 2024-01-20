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
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
# 239) Error creating report files.
#
# For contributing, please execute these commands at the end:
# * shellcheck -x -o all notesCheckVerifier.sh
# * shfmt -w -i 1 -sr -bn notesCheckVerifier.sh
#
# Autor: Andres Gomez Casanova - AngocA
# Version: 2024-01-18
declare -r VERSION="2024-01-18"

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

# Clean files.
declare CLEAN="${CLEAN:-true}"

# Base directory for the project.
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
 &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Loads the global properties.
# shellcheck source=../../etc/properties.sh
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

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

# Location of the common functions.
declare -r FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

# Script to process notes from Planet.
declare -r SCRIPT_PROCESS_PLANET="${SCRIPT_BASE_DIRECTORY}/bin/monitor/processCheckPlanetNotes.sh"

# SQL report file.
declare -r SQL_REPORT="${SCRIPT_BASE_DIRECTORY}/sql/monitor/notesCheckVerifier-report.sql"

###########
# FUNCTIONS

# shellcheck source=../functionsProcess.sh
source "${FUNCTIONS_FILE}"

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
 __checkPrereqsCommands
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

 "${SCRIPT_PROCESS_PLANET}"

 __log_finish
}

# Checks the differences between planet and API notes.
function __checkingDifferences {
 __log_start

 LAST_NOTE=/tmp/lastNote.csv
 LAST_COMMENT=/tmp/lastCommentNote.csv
 DIFFERENT_NOTE_IDS_FILE=/tmp/differentNoteIds.csv
 DIFFERENT_COMMENT_IDS_FILE=/tmp/differentNoteCommentIds.csv
 DIRRERENT_NOTES_FILE=/tmp/differentNotes.csv
 DIRRERENT_COMMENTS_FILE=/tmp/differentNoteComments.csv
 DIFFERENCES_TEXT_COMMENT=/tmp/textComments.csv

 export LAST_NOTE
 export LAST_COMMENT
 export DIFFERENT_NOTE_IDS_FILE
 export DIFFERENT_COMMENT_IDS_FILE
 export DIRRERENT_NOTES_FILE
 export DIRRERENT_COMMENTS_FILE
 export DIFFERENCES_TEXT_COMMENT
 # shellcheck disable=SC2016
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
  -c "$(envsubst '$LAST_NOTE,$LAST_COMMENT,$DIFFERENT_NOTE_IDS_FILE,$DIFFERENT_COMMENT_IDS_FILE,$DIRRERENT_NOTES_FILE,$DIRRERENT_COMMENTS_FILE,$DIFFERENCES_TEXT_COMMENT' \
   < "${SQL_REPORT}" || true)" 2>&1

 if [[ ! -r "${DIFFERENT_NOTE_IDS_FILE}" ]] \
  || [[ ! -r "${DIFFERENT_COMMENT_IDS_FILE}" ]] \
  || [[ ! -r "${DIRRERENT_NOTES_FILE}" ]] \
  || [[ ! -r "${DIRRERENT_COMMENTS_FILE}" ]] || [[ ! -r "${LAST_NOTE}" ]] \
  || [[ ! -r "${LAST_COMMENT}" ]]; then
  __loge "Difference files were not created."
  exit "${ERROR_CREATING_REPORT}"
 fi

 zip "${REPORT_ZIP}" "${DIFFERENT_NOTE_IDS_FILE}" \
  "${DIFFERENT_COMMENT_IDS_FILE}" "${DIRRERENT_NOTES_FILE}" \
  "${DIRRERENT_COMMENTS_FILE}"

 __log_finish
}

# Sends the report of differences in the database.
function __sendMail {
 __log_start
 QTY=$(tail -n +2 "${DIFFERENT_NOTE_IDS_FILE}" | wc -l | cut -f 1 -d' ')
 if [[ "${QTY}" -ne 0 ]]; then
  __logi "Sending mail."
  {
   echo "These are the differences between the Planet file and the API calls"
   echo "for OSM notes profile."
   echo
   echo "Latest note:"
   cat "${LAST_NOTE}"
   echo
   cat "${LAST_COMMENT}"
   echo
   echo "This report was generated by:"
   echo "https://github.com/OSMLatam/OSM-Notes-profile"
  } >> "${REPORT}"
  echo "" | mutt -s "OSM Notes profile differences" -i "${REPORT}" \
    -a "${REPORT_ZIP}" -- "${EMAILS}" 2>&1
  __logi "Menssage sent."
 fi
 __log_finish
}

# Clean unnecessary files.
function __cleanFiles {
 __log_start
 if [[ "${CLEAN}" = "true" ]]; then
  __logi "Limpiando archivos innecesarios."
  rm -f "${REPORT}" "${REPORT_ZIP}" # Other files cannot be removed.
 fi
 __log_finish
}

######
# MAIN

function main() {
 __log_start
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
 __log_finish
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [[ ! -t 1 ]]; then
 __set_log_file "${LOG_FILE_NAME}"
 main >> "${LOG_FILE_NAME}"
else
 main
fi
