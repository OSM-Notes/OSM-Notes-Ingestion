#!/bin/bash

# This script allows to see a user profile or a country profile. It reads all
# values from the database, from the star schema.
#
# There are 2 ways to call this script:
# * --user <UserName> : Shows the profile for the given user.
# * --country <CountryName> : Shows the profiel for the given country.
# If the UserName or CountryName has spaces in the name, it should be invoked
# between double quotes.
# For example:
# * --user AngocA
# * --country Colombia
# * --country "United States of America"
# The name should match the name on the database.
#
# This script is only to test data on the data warehouse, and validate the data
# to show in the web page report.
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
#
# Author: Andres Gomez (AngocA)
# Version: 2022-12-06
declare -r VERSION="2022-12-06"

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

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory, where the ticket script resides.
# Taken from https://stackoverflow.com/questions/59895/how-can-i-get-the-source-directory-of-a-bash-script-from-within-the-script-itsel
# shellcheck disable=SC2155
declare -r SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" \
  &> /dev/null && pwd)"

# Logger framework.
# Taken from https://github.com/DushyanthJyothi/bash-logger.
declare -r LOGGER_UTILITY="${SCRIPT_BASE_DIRECTORY}/bash_logger.sh"

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME
# Temporal directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
# Lof file for output.
declare LOG_FILE
LOG_FILE="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILE

# Lock file for single execution.
declare LOCK
LOCK="/tmp/${BASENAME}.lock"
readonly LOCK

# Type of process to run in the script.
declare -r PROCESS_TYPE=${1:-}

# Name of the PostgreSQL database to insert or update the data.
declare -r DBNAME=notes

# Name of the user or the country.
declare -r NAME="${2}"

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
 if [[ -f "${LOGGER_UTILITY}" ]] ; then
  # Starts the logger mechanism.
  set +e
  # shellcheck source=./bash_logger.sh
  source "${LOGGER_UTILITY}"
  local -i RET=${?}
  set -e
  if [[ "${RET}" -ne 0 ]] ; then
   printf "\nERROR: Invalid logger framework file.\n"
   exit "${ERROR_LOGGER_UTILITY}"
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
 trap '{ printf "%s ERROR: The script did not finish correctly. Line number: %d.\n" "$(date +%Y%m%d_%H:%M:%S)" "${LINENO}"; exit ;}' \
   ERR
 trap '{ printf "%s WARN: The script was terminated.\n" "$(date +%Y%m%d_%H:%M:%S)"; exit ;}' \
   SIGINT SIGTERM
 __log_finish
}

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}"
 echo "This is an ETL script that takes the data from notes and comments and"
 echo "process it into a star schema. This schema allows an easier access from"
 echo "the OSM Notes profile."
 echo
 echo "There are 2 ways to call this script:"
 echo "* --user <UserName> : Shows the profile for the given user."
 echo "* --country <CountryName> : Shows the profiel for the given country."
 echo "If the UserName or CountryName has spaces in the name, it should be"
 echo "invoked between double quotes."
 echo "For example:"
 echo "* --user AngocA"
 echo "* --country Colombia"
 echo "* --country \"United States of America\""
 echo "The name should match the name on the database."
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 if [[ "${PROCESS_TYPE}" != "--user" ]] \
   && [[ "${PROCESS_TYPE}" != "--country" ]] \
   && [[ "${PROCESS_TYPE}" != "--help" ]] \
   && [[ "${PROCESS_TYPE}" != "-h" ]] ; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --user"
  echo " * --country"
  echo " * --help"
 fi
 ## PostgreSQL
 if ! psql --version > /dev/null 2>&1 ; then
  __loge "ERROR: PostgreSQL is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Bash 4 or greater.
 if [[ "${BASH_VERSINFO[0]}" -lt 4 ]] ; then
  __loge "ERROR: Requires Bash 4+."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __log_finish
 set -e
}

function __processUserProfile {
 # Quantity of days creating notes.
 declare -i QTY_DAYS_OPEN
 QTY_DAYS_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT CURRENT_DATE - DATE(MIN(created_at))
     FROM dwh.facts f
     JOIN dwh.users_dimension u
     ON f.created_id_user = u.user_id
     WHERE u.username = ${NAME}
     " \
    -v ON_ERROR_STOP=1 )

 # Quantity of days solving notes.
 declare -i QTY_DAYS_CLOSE
 QTY_DAYS_CLOSE=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT CURRENT_DATE - DATE(MIN(closed_at))
     FROM dwh.facts f
     JOIN dwh.dimension_countries u
     ON f.closed_id_user = u.user_id
     WHERE u.username = ${NAME}
     " \
    -v ON_ERROR_STOP=1 )

 # Countries opening notes.
 declare -i COUNTRIES_OPENING
 COUNTRIES_OPENING=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT STRING_AGG(country_name_en, ',')
     FROM dwh.facts f
     JOIN dwh.users_dimension u
     ON f.closed_id_user = u.user_id
     JOIN dwh.dimension_countries c
     ON f.id_country = c.country_id
     WHERE u.username = ${NAME}
     AND f.action_comment = 'opened'
     GROUP BY country_name_en
     " \
    -v ON_ERROR_STOP=1 )

 # Countries closing notes.
 declare -i COUNTRIES_CLOSING
 COUNTRIES_CLOSING=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT STRING_AGG(country_name_en, ',')
     FROM dwh.facts f
     JOIN dwh.users_dimension u
     ON f.closed_id_user = u.user_id
     JOIN dwh.dimension_countries c
     ON f.id_country = c.country_id
     WHERE u.username = ${NAME}
     AND f.action_comment = 'closed'
     GROUP BY country_name_en
     " \
    -v ON_ERROR_STOP=1 )


 echo "User: ${NAME}"
 echo "Quantity of days creating notes: ${QTY_DAYS_OPEN}"
 echo "Quantity of days solving notes: ${QTY_DAYS_CLOSE}"
 echo "Countries for open notes: ${COUNTRIES_OPENING}"
 echo "Countries for closed notes: ${COUNTRIES_CLOSING}"
}

######
# MAIN

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

{
 __start_logger
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}"
 __logi "Processing: ${PROCESS_TYPE}"
} >> "${LOG_FILE}" 2>&1

if [[ "${PROCESS_TYPE}" == "-h" ]] || [[ "${PROCESS_TYPE}" == "--help" ]]; then
 __show_help
fi
__checkPrereqs
{
 __logw "Starting process"
 # Sets the trap in case of any signal.
 __trapOn

 if [[ "${PROCESS_TYPE}" == "--user" ]] ; then
  __processUserProfile
 elif [[ "${PROCESS_TYPE}" == "--country" ]] 
  __processCountryProfile
 fi

 __logw "Ending process"
} >> "${LOG_FILE}" 2>&1

if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]] ; then
 mv "${LOG_FILE}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
 rmdir "${TMP_DIR}"
fi

