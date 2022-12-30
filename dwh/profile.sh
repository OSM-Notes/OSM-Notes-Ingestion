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
# Version: 2022-12-20
declare -r VERSION="2022-12-20"

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
declare -r CLEAN="${CLEAN:-true}"

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory, where the ticket script resides.
# Taken from https://stackoverflow.com/questions/59895/how-can-i-get-the-source-directory-of-a-bash-script-from-within-the-script-itsel
# shellcheck disable=SC2155
declare -r SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" \
  &> /dev/null && pwd)"

# Logger framework.
# Taken from https://github.com/DushyanthJyothi/bash-logger.
declare -r LOGGER_UTILITY="${SCRIPT_BASE_DIRECTORY}/../bash_logger.sh"

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

# Type of process to run in the script.
declare -r PROCESS_TYPE=${1:-}

# Name of the PostgreSQL database to insert or update the data.
declare -r DBNAME=notes

# Name of the user or the country.
declare -r NAME="${2:-}"

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
  exit "${ERROR_INVALID_ARGUMENT}"
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
 # User id
 declare -i USER_ID
 USER_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT user_id
     FROM dwh.datamartUsers
     WHERE username = '${NAME}'
     " \
     -v ON_ERROR_STOP=1 )

 # Quantity of days creating notes.
 declare -i QTY_DAYS_OPEN
 QTY_DAYS_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT CURRENT_DATE - date_starting_creating_notes
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Quantity of days solving notes.
 declare -i QTY_DAYS_CLOSE
 QTY_DAYS_CLOSE=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT CURRENT_DATE - date_starting_solving_notes
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Countries opening notes.
 declare COUNTRIES_OPENING
 COUNTRIES_OPENING=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT countries_open_notes
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Countries closing notes.
 declare COUNTRIES_CLOSING
 COUNTRIES_CLOSING=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT countries_solving_notes
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Type of contributor.
 declare CONTRIBUTOR_TYPE
 CONTRIBUTOR_TYPE=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT contributor_type_name
     FROM dwh.datamartUsers u
      JOIN dwh.contributor_types t
      ON u.id_contributor_type = t.contributor_type_id
     WHERE id_user = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Badges.
 declare BADGES
 BADGES=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT b.badge_name, p.date_awarded
     FROM dwh.badges_per_users p
      JOIN dwh.badges b
      ON p.id_badge = b.badge_id
     WHERE id_user = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Last year's ations.
 declare LAST_YEAR_ACTIONS
 LAST_YEAR_ACTIONS=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT get_last_year_actions(${USER_ID})
     " \
    -v ON_ERROR_STOP=1 )

 # Working hours.
 declare WORKING_HOURS_OPENING
 WORKING_HOURS_OPENING=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT working_hours_opening
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare WORKING_HOURS_COMMENTING
 WORKING_HOURS_COMMENTING=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT working_hours_commenting
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare WORKING_HOURS_CLOSING
 WORKING_HOURS_CLOSING=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT working_hours_closing
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # First actions.
 declare -i FIRST_OPEN_NOTE_ID
 FIRST_OPEN_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT first_open_note_id
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i FIRST_COMMENTED_NOTE_ID
 FIRST_COMMENTED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT first_commented_note_id
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i FIRST_CLOSED_NOTE_ID
 FIRST_CLOSED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT first_closed_note_id
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i FIRST_REOPENED_NOTE_ID
 FIRST_REOPENED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT first_reopened_note_id
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Last actions.
 declare -i LAST_OPEN_NOTE_ID
 LAST_OPEN_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT last_open_note_id
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i LAST_COMMENTED_NOTE_ID
 LAST_COMMENTED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT last_commented_note_id
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i LAST_CLOSED_NOTE_ID
 LAST_CLOSED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT last_closed_note_id
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i LAST_REOPENED_NOTE_ID
 LAST_REOPENED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT last_reopened_note_id
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # History values.
 # Whole history.
 declare -i HISTORY_WHOLE_OPEN
 HISTORY_WHOLE_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_whole_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_WHOLE_COMMENTED
 HISTORY_WHOLE_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_whole_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_WHOLE_CLOSED
 HISTORY_WHOLE_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_whole_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_WHOLE_CLOSED_WITH_COMMENT
 HISTORY_WHOLE_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_whole_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_WHOLE_REOPENED
 HISTORY_WHOLE_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_whole_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Last year history.
 declare -i HISTORY_YEAR_OPEN
 HISTORY_YEAR_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_year_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_COMMENTED
 HISTORY_YEAR_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_year_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_CLOSED
 HISTORY_YEAR_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_year_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_CLOSED_WITH_COMMENT
 HISTORY_YEAR_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_year_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_REOPENED
 HISTORY_YEAR_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_year_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Last month history.
 declare -i HISTORY_MONTH_OPEN
 HISTORY_MONTH_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_month_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_MONTH_COMMENTED
 HISTORY_MONTH_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_month_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_MONTH_CLOSED
 HISTORY_MONTH_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_month_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_MONTH_CLOSED_WITH_COMMENT
 HISTORY_MONTH_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_month_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_MONTH_REOPENED
 HISTORY_MONTH_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_month_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Last day history.
 declare -i HISTORY_DAY_OPEN
 HISTORY_DAY_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_day_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_DAY_COMMENTED
 HISTORY_DAY_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_day_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_DAY_CLOSED
 HISTORY_DAY_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_day_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_DAY_CLOSED_WITH_COMMENT
 HISTORY_DAY_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_day_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_DAY_REOPENED
 HISTORY_DAY_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_day_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )
 
 # Previous years.
 # 2013
 declare -i HISTORY_2013_OPEN
 HISTORY_2013_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2013_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2013_COMMENTED
 HISTORY_2013_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2013_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2013_CLOSED
 HISTORY_2013_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2013_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2013_CLOSED_WITH_COMMENT
 HISTORY_2013_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2013_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2013_REOPENED
 HISTORY_2013_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2013_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # 2014
 declare -i HISTORY_2014_OPEN
 HISTORY_2014_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2014_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2014_COMMENTED
 HISTORY_2014_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2014_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2014_CLOSED
 HISTORY_2014_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2014_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2014_CLOSED_WITH_COMMENT
 HISTORY_2014_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2014_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2014_REOPENED
 HISTORY_2014_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2014_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # 2015
 declare -i HISTORY_2015_OPEN
 HISTORY_2015_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2015_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2015_COMMENTED
 HISTORY_2015_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2015_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2015_CLOSED
 HISTORY_2015_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2015_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2015_CLOSED_WITH_COMMENT
 HISTORY_2015_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2015_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2015_REOPENED
 HISTORY_2015_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2015_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # 2016
 declare -i HISTORY_2016_OPEN
 HISTORY_2016_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2016_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2016_COMMENTED
 HISTORY_2016_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2016_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2016_CLOSED
 HISTORY_2016_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2016_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2016_CLOSED_WITH_COMMENT
 HISTORY_2016_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2016_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2016_REOPENED
 HISTORY_2016_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2016_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # 2017
 declare -i HISTORY_2017_OPEN
 HISTORY_2017_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2017_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2017_COMMENTED
 HISTORY_2017_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2017_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2017_CLOSED
 HISTORY_2017_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2017_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2017_CLOSED_WITH_COMMENT
 HISTORY_2017_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2017_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2017_REOPENED
 HISTORY_2017_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2017_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # 2018
 declare -i HISTORY_2018_OPEN
 HISTORY_2018_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2018_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2018_COMMENTED
 HISTORY_2018_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2018_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2018_CLOSED
 HISTORY_2018_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2018_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2018_CLOSED_WITH_COMMENT
 HISTORY_2018_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2018_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2018_REOPENED
 HISTORY_2018_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2018_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # 2019
 declare -i HISTORY_2019_OPEN
 HISTORY_2019_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2019_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2019_COMMENTED
 HISTORY_2019_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2019_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2019_CLOSED
 HISTORY_2019_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2019_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2019_CLOSED_WITH_COMMENT
 HISTORY_2019_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2019_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2019_REOPENED
 HISTORY_2019_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2019_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # 2020
 declare -i HISTORY_2020_OPEN
 HISTORY_2020_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2020_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2020_COMMENTED
 HISTORY_2020_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2020_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2020_CLOSED
 HISTORY_2020_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2020_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2020_CLOSED_WITH_COMMENT
 HISTORY_2020_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2020_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2020_REOPENED
 HISTORY_2020_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2020_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # 2021
 declare -i HISTORY_2021_OPEN
 HISTORY_2021_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2021_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2021_COMMENTED
 HISTORY_2021_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2021_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2021_CLOSED
 HISTORY_2021_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2021_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2021_CLOSED_WITH_COMMENT
 HISTORY_2021_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2021_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2021_REOPENED
 HISTORY_2021_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2021_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # 2022
 declare -i HISTORY_2022_OPEN
 HISTORY_2022_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2022_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2022_COMMENTED
 HISTORY_2022_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2022_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2022_CLOSED
 HISTORY_2022_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2022_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2022_CLOSED_WITH_COMMENT
 HISTORY_2022_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2022_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2022_REOPENED
 HISTORY_2022_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2022_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # 2023
 declare -i HISTORY_2023_OPEN
 HISTORY_2023_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2023_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2023_COMMENTED
 HISTORY_2023_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2023_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2023_CLOSED
 HISTORY_2023_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2023_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2023_CLOSED_WITH_COMMENT
 HISTORY_2023_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2023_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_2023_REOPENED
 HISTORY_2023_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_2023_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Ranking historic
 declare -i RANKING_HISTORIC_OPEN
 RANKING_HISTORIC_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_historic
      WHERE action = 'opened'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 declare -i RANKING_HISTORIC_COMMENTED
 RANKING_HISTORIC_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_historic
      WHERE action = 'commented'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 declare -i RANKING_HISTORIC_CLOSED
 RANKING_HISTORIC_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_historic
      WHERE action = 'closed'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 declare -i RANKING_HISTORIC_REOPENED
 RANKING_HISTORIC_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_historic
      WHERE action = 'reopened'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 # Ranking year
 declare -i RANKING_YEAR_OPEN
 RANKING_YEAR_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_year
      WHERE action = 'opened'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 declare -i RANKING_YEAR_COMMENTED
 RANKING_YEAR_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_year
      WHERE action = 'commented'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 declare -i RANKING_YEAR_CLOSED
 RANKING_YEAR_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_year
      WHERE action = 'closed'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 declare -i RANKING_YEAR_REOPENED
 RANKING_YEAR_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_year
      WHERE action = 'reopened'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 # Ranking month
 declare -i RANKING_MONTH_OPEN
 RANKING_MONTH_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_month
      WHERE action = 'opened'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 declare -i RANKING_MONTH_COMMENTED
 RANKING_MONTH_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_month
      WHERE action = 'commented'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 declare -i RANKING_MONTH_CLOSED
 RANKING_MONTH_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_month
      WHERE action = 'closed'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 declare -i RANKING_MONTH_REOPENED
 RANKING_MONTH_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_month
      WHERE action = 'reopened'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 # Ranking day
 declare -i RANKING_DAY_OPEN
 RANKING_DAY_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_day
      WHERE action = 'opened'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 declare -i RANKING_DAY_COMMENTED
 RANKING_DAY_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_day
      WHERE action = 'commented'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 declare -i RANKING_DAY_CLOSED
 RANKING_DAY_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_day
      WHERE action = 'closed'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 declare -i RANKING_DAY_REOPENED
 RANKING_DAY_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT position, id_country
      FROM dwh.ranking_day
      WHERE action = 'reopened'
      AND user_id = ${USER_ID}
     ) AS t
     " \
    -v ON_ERROR_STOP=1 )

 # Date with more opened notes
 declare DATE_MOST_OPEN
 DATE_MOST_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT date_most_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Date with more closed notes
 declare DATE_MOST_CLOSED
 DATE_MOST_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT date_most_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Used hashtags
 declare HASHTAGS
 HASHTAGS=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT hashtags
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 echo "User name: ${NAME}"
 echo "User ID: ${USER_ID}"
 echo "Quantity of days creating notes: ${QTY_DAYS_OPEN}"
 echo "Quantity of days solving notes: ${QTY_DAYS_CLOSE}"
 echo "Countries for open notes: ${COUNTRIES_OPENING}"
 echo "Countries for closed notes: ${COUNTRIES_CLOSING}"
 echo "Badges: ${BADGES}"
 echo "Last year actions: ${LAST_YEAR_ACTIONS}"
 echo "Working hours: Opening ${WORKING_HOURS_OPENING} Commenting ${WORKING_HOURS_COMMENTING} Closing ${WORKING_HOURS_CLOSING}"
 echo "               Open                                      Commented                                         Closed                                               Reopened"
 echo "First actions: https://www.openstreetmap.org/note/${FIRST_OPEN_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_COMMENTED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_CLOSED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_REOPENED_NOTE_ID}"
 echo "Last actions:  https://www.openstreetmap.org/note/${LAST_OPEN_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_COMMENTED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_CLOSED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_REOPENED_NOTE_ID}"
 echo "Total         ${HISTORY_WHOLE_OPEN} ${HISTORY_WHOLE_COMMENTED} ${HISTORY_WHOLE_CLOSED} ${HISTORY_WHOLE_REOPENED}"
 echo "Last 365 year ${HISTORY_YEAR_OPEN} ${HISTORY_YEAR_COMMENTED} ${HISTORY_YEAR_CLOSED} ${HISTORY_YEAR_REOPENED}"
 echo "Last 30 days  ${HISTORY_MONTH_OPEN} ${HISTORY_MONTH_COMMENTED} ${HISTORY_MONTH_CLOSED} ${HISTORY_MONTH_REOPENED}"
 echo "Last day      ${HISTORY_DAY_OPEN} ${HISTORY_DAY_COMMENTED} ${HISTORY_DAY_CLOSED} ${HISTORY_DAY_REOPENED}"
 echo "2013          ${HISTORY_2013_OPEN} ${HISTORY_2013_COMMENTED} ${HISTORY_2013_CLOSED} ${HISTORY_2013_REOPENED}"
 echo "2014          ${HISTORY_2014_OPEN} ${HISTORY_2014_COMMENTED} ${HISTORY_2014_CLOSED} ${HISTORY_2014_REOPENED}"
 echo "2015          ${HISTORY_2015_OPEN} ${HISTORY_2015_COMMENTED} ${HISTORY_2015_CLOSED} ${HISTORY_2015_REOPENED}"
 echo "2016          ${HISTORY_2016_OPEN} ${HISTORY_2016_COMMENTED} ${HISTORY_2016_CLOSED} ${HISTORY_2016_REOPENED}"
 echo "2017          ${HISTORY_2017_OPEN} ${HISTORY_2017_COMMENTED} ${HISTORY_2017_CLOSED} ${HISTORY_2017_REOPENED}"
 echo "2018          ${HISTORY_2018_OPEN} ${HISTORY_2018_COMMENTED} ${HISTORY_2018_CLOSED} ${HISTORY_2018_REOPENED}"
 echo "2019          ${HISTORY_2019_OPEN} ${HISTORY_2019_COMMENTED} ${HISTORY_2019_CLOSED} ${HISTORY_2019_REOPENED}"
 echo "2020          ${HISTORY_2020_OPEN} ${HISTORY_2020_COMMENTED} ${HISTORY_2020_CLOSED} ${HISTORY_2020_REOPENED}"
 echo "2021          ${HISTORY_2021_OPEN} ${HISTORY_2021_COMMENTED} ${HISTORY_2021_CLOSED} ${HISTORY_2021_REOPENED}"
 echo "2022          ${HISTORY_2022_OPEN} ${HISTORY_2022_COMMENTED} ${HISTORY_2022_CLOSED} ${HISTORY_2022_REOPENED}"
 echo "2023          ${HISTORY_2023_OPEN} ${HISTORY_2023_COMMENTED} ${HISTORY_2023_CLOSED} ${HISTORY_2023_REOPENED}"
 echo "Rankings historic       ${RANKING_HISTORIC_OPEN} ${RANKING_HISTORIC_COMMENTED} ${RANKING_HISTORIC_CLOSED} ${RANKING_HISTORIC_REOPENED}"
 echo "Rankings last 12 months ${RANKING_YEAR_OPEN} ${RANKING_YEAR_COMMENTED} ${RANKING_YEAR_CLOSED} ${RANKING_YEAR_REOPENED}"
 echo "Rankings last 30 days   ${RANKING_MONTH_OPEN} ${RANKING_MONTH_COMMENTED} ${RANKING_MONTH_CLOSED} ${RANKING_MONTH_REOPENED}"
 echo "Rankings today          ${RANKING_DAY_OPEN} ${RANKING_DAY_COMMENTED} ${RANKING_DAY_CLOSED} ${RANKING_DAY_REOPENED}"
 echo "Hashtags: ${HASHTAGS}"
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
 elif [[ "${PROCESS_TYPE}" == "--country" ]] ; then
  __processCountryProfile
 fi

 __logw "Ending process"
}
# >> "${LOG_FILE}" 2>&1

if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]] ; then
 mv "${LOG_FILE}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
 rmdir "${TMP_DIR}"
fi

