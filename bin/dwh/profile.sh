#!/bin/bash

# This script allows to see a user profile, a country profile or general
# statistics about notes. It reads all values from the database, from the
# datamart.
#
# There are 3 ways to call this script:
# * --user <UserName> : Shows the profile for the given user.
# * --country <CountryName> : Shows the profile for the given country (name in
#   in English).
# * --pais <NombrePais> : Shows the profile for the given country (name in
#   Spanish).
# If the UserName, CountryName or NombrePais has spaces in the name, it should
# be invoked between double quotes.
# * (empty) : It shows general statistics about notes.
#
# For example:
# * --user AngocA
# * --country Colombia
# * --country "United States of America"
# * --pais Alemania
# * --country Germany
# The name should match the name on the database in English or Spanish,
# respectively.
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
# For contributing, please execute these commands before submitting:
# * shellcheck -x -o all profile.sh
# * shfmt -w -i 1 -sr -bn profile.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-12
VERSION="2025-08-12"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with a non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E
# Fails parent if child fails.
shopt -s inherit_errexit

# If all files should be deleted. In case of an error, this could be disabled.
# You can defined when calling: export CLEAN=false
# CLEAN is now defined in etc/properties.sh, no need to declare it here

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
# shellcheck disable=SC1091
if [[ -f "${SCRIPT_BASE_DIRECTORY}/tests/properties.sh" ]] && [[ "${BATS_TEST_NAME:-}" != "" ]]; then
 # Use test properties when running in test environment
 source "${SCRIPT_BASE_DIRECTORY}/tests/properties.sh"
else
 # Use production properties
 source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"
fi

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME
# Temporary directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
chmod 777 "${TMP_DIR}"
# Log file for output.
declare LOG_FILENAME
LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILENAME

# Type of process to run in the script.
if [[ -z "${PROCESS_TYPE:-}" ]]; then
 declare -r PROCESS_TYPE=${1:-}
fi
# Argument for the process type.
declare -r ARGUMENT=${2:-}

# Username.
declare USERNAME
# Dimension_User_id of the username.
declare -i DIMENSION_USER_ID
# Name of the user or the country in English.
declare COUNTRY_NAME
# Name of the user or the country in Spanish.
declare PAIS_NAME
# Country_id of the country.
declare -i COUNTRY_ID

###########
# FUNCTIONS

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/commonFunctions.sh"

# Load validation functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"

# Load error handling functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/bin/errorHandlingFunctions.sh"

# Shows the help information.
function __show_help {
 echo "${0} version ${VERSION}"
 echo "This scripts shows the resulting profile for a given user or country,"
 echo "Or general statistics about notes."
 echo
 echo "There are 3 ways to call this script:"
 echo "* --user <UserName> : Shows the profile for the given user."
 echo "* --country <CountryName> : Shows the profile for the given country."
 echo "If the UserName or CountryName has spaces in the name, it should be"
 echo "invoked between double quotes. The name should match the name in"
 echo "Spanish in the database."
 echo "* (empty) : Shows general statistics about notes."
 echo
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
 if [[ "${PROCESS_TYPE}" != "" ]] \
  && [[ "${PROCESS_TYPE}" != "--user" ]] \
  && [[ "${PROCESS_TYPE}" != "--country" ]] \
  && [[ "${PROCESS_TYPE}" != "--pais" ]] \
  && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --user"
  echo " * --country"
  echo " * --pais"
  echo " * --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 if [[ "${PROCESS_TYPE}" == "--user" ]] \
  && [[ "${ARGUMENT}" == "" ]]; then
  __loge "ERROR: You  must provide a username."
  exit "${ERROR_INVALID_ARGUMENT}"
 else
  USERNAME="${ARGUMENT}"
 fi
 if [[ "${PROCESS_TYPE}" == "--country" ]] \
  && [[ "${ARGUMENT}" == "" ]]; then
  __loge "ERROR: You  must provide a country name."
  exit "${ERROR_INVALID_ARGUMENT}"
 else
  COUNTRY_NAME="${ARGUMENT}"
 fi
 if [[ "${PROCESS_TYPE}" == "--pais" ]] \
  && [[ "${ARGUMENT}" == "" ]]; then
  __loge "ERROR: You  must provide a country name."
  exit "${ERROR_INVALID_ARGUMENT}"
 else
  PAIS_NAME="${ARGUMENT}"
 fi

 __checkPrereqsCommands

 __log_finish
}

# Retrives the dimension_user_id from a username.
function __getUserId {
 __log_start
 DIMENSION_USER_ID=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT dimension_user_id FROM dwh.datamartUsers
  WHERE username = '${USERNAME}'")
 if [[ "${DIMENSION_USER_ID}" == "" ]] \
  || [[ "${DIMENSION_USER_ID}" -eq 0 ]]; then
  __loge "ERROR: The username \"${USERNAME}\" does not exist."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 __log_finish
}

# Retrives the country_id from a country name.
function __getCountryId {
 __log_start
 if [[ "${PROCESS_TYPE}" == "--country" ]]; then
  COUNTRY_ID=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
   <<< "SELECT dimension_country_id FROM dwh.datamartCountries
   WHERE country_name_en = '${COUNTRY_NAME}'")
 else
  COUNTRY_ID=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
   <<< "SELECT dimension_country_id FROM dwh.datamartCountries
   WHERE country_name_es = '${PAIS_NAME}'")
 fi

 if [[ "${COUNTRY_ID}" == "" ]]; then
  __loge "ERROR: The country name \"${COUNTRY_NAME}${PAIS_NAME}\" does not exist."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 __log_finish
}

# Shows the user activity for all years after 2013.
function __showActivityYearUsers {
 __log_start
 YEAR="${1}"

 declare -i HISTORY_YEAR_OPEN
 HISTORY_YEAR_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_${YEAR}_open
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_COMMENTED
 HISTORY_YEAR_COMMENTED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_${YEAR}_commented
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_CLOSED
 HISTORY_YEAR_CLOSED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_${YEAR}_closed
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_CLOSED_WITH_COMMENT
 HISTORY_YEAR_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_${YEAR}_closed_with_comment
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_REOPENED
 HISTORY_YEAR_REOPENED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_${YEAR}_reopened
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 printf "${YEAR}:          %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_YEAR_OPEN}" "${HISTORY_YEAR_COMMENTED}" "${HISTORY_YEAR_CLOSED}" "${HISTORY_YEAR_CLOSED_WITH_COMMENT}" "${HISTORY_YEAR_REOPENED}"
 __log_finish
}

# Shows the country activity for all years after 2013.
function __showActivityYearCountries {
 __log_start
 YEAR="${1}"

 declare -i HISTORY_YEAR_OPEN
 HISTORY_YEAR_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_${YEAR}_open
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_COMMENTED
 HISTORY_YEAR_COMMENTED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_${YEAR}_commented
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_CLOSED
 HISTORY_YEAR_CLOSED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_${YEAR}_closed
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_CLOSED_WITH_COMMENT
 HISTORY_YEAR_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_${YEAR}_closed_with_comment
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_REOPENED
 HISTORY_YEAR_REOPENED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_${YEAR}_reopened
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 printf "${YEAR}:          %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_YEAR_OPEN}" "${HISTORY_YEAR_COMMENTED}" "${HISTORY_YEAR_CLOSED}" "${HISTORY_YEAR_CLOSED_WITH_COMMENT}" "${HISTORY_YEAR_REOPENED}"
 __log_finish
}

# Prints a given ranking in a better way.
function __printRanking {
 __log_start
 RANKING=${1}

 echo "${RANKING}" | sed 's/}, {/\n/g' | sed 's/^\[{//' | sed 's/}\]//' | sed 's/"rank" ://g' | sed 's/, "country_name" : "/ - /g' | sed 's/, "username" : "/ - /g' | sed 's/", "quantity" :/:/g'
 __log_finish
}

# Shows the historic yearly rankings when the user has contributed the most.
function __showRankingYearUsers {
 __log_start
 YEAR="${1}"

 declare RANKING_OPENING
 RANKING_OPENING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT ranking_countries_opening_${YEAR}
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare RANKING_CLOSING
 RANKING_CLOSING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT ranking_countries_closing_${YEAR}
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 echo
 echo "Countries for opened notes on ${YEAR}:"
 __printRanking "${RANKING_OPENING}"
 echo "Countries for closed notes on ${YEAR}:"
 __printRanking "${RANKING_CLOSING}"
 __log_finish
}

# Shows the historic yearly rankings on which users have been contributed the most.
function __showRankingYearCountries {
 __log_start
 YEAR="${1}"

 declare RANKING_OPENING
 RANKING_OPENING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT ranking_users_opening_${YEAR}
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare RANKING_CLOSING
 RANKING_CLOSING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT ranking_users_closing_${YEAR}
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 echo
 echo "Users creating notes on ${YEAR}:"
 __printRanking "${RANKING_OPENING}"
 echo "Users closing notes on ${YEAR}:"
 __printRanking "${RANKING_CLOSING}"
 __log_finish
}

# Prints the hour the hour of the week.
function __processHourWeek {
 __log_start
 HOUR=${1}
 DOW=${2}
 NUMBER=$(echo "${WEEK}" | grep "\"day_of_week\":${DOW},\"hour_of_day\":${HOUR}," \
  | awk -F: '{print $4}' | sed 's/}, //' | sed 's/}\]//')
 printf "%5d" "${NUMBER}"
 __log_finish
}

# Shows the week hours in a better fashion.
function __showWorkingWeek {
 __log_start
 WEEK=${1}
 declare HOUR_0=" 0h"
 declare HOUR_1=" 1h"
 declare HOUR_2=" 2h"
 declare HOUR_3=" 3h"
 declare HOUR_4=" 4h"
 declare HOUR_5=" 5h"
 declare HOUR_6=" 6h"
 declare HOUR_7=" 7h"
 declare HOUR_8=" 8h"
 declare HOUR_9=" 9h"
 declare HOUR_10="10h"
 declare HOUR_11="11h"
 declare HOUR_12="12h"
 declare HOUR_13="13h"
 declare HOUR_14="14h"
 declare HOUR_15="15h"
 declare HOUR_16="16h"
 declare HOUR_17="17h"
 declare HOUR_18="18h"
 declare HOUR_19="19h"
 declare HOUR_20="20h"
 declare HOUR_21="21h"
 declare HOUR_22="22h"
 declare HOUR_23="23h"
 I=1
 set +e
 while [[ "${I}" -le 7 ]]; do
  HOUR_0="${HOUR_0} - $(__processHourWeek 0 "${I}")"
  HOUR_1="${HOUR_1} - $(__processHourWeek 1 "${I}")"
  HOUR_2="${HOUR_2} - $(__processHourWeek 2 "${I}")"
  HOUR_3="${HOUR_3} - $(__processHourWeek 3 "${I}")"
  HOUR_4="${HOUR_4} - $(__processHourWeek 4 "${I}")"
  HOUR_5="${HOUR_5} - $(__processHourWeek 5 "${I}")"
  HOUR_6="${HOUR_6} - $(__processHourWeek 6 "${I}")"
  HOUR_7="${HOUR_7} - $(__processHourWeek 7 "${I}")"
  HOUR_8="${HOUR_8} - $(__processHourWeek 8 "${I}")"
  HOUR_9="${HOUR_9} - $(__processHourWeek 9 "${I}")"
  HOUR_10="${HOUR_10} - $(__processHourWeek 10 "${I}")"
  HOUR_11="${HOUR_11} - $(__processHourWeek 11 "${I}")"
  HOUR_12="${HOUR_12} - $(__processHourWeek 12 "${I}")"
  HOUR_13="${HOUR_13} - $(__processHourWeek 13 "${I}")"
  HOUR_14="${HOUR_14} - $(__processHourWeek 14 "${I}")"
  HOUR_15="${HOUR_15} - $(__processHourWeek 15 "${I}")"
  HOUR_16="${HOUR_16} - $(__processHourWeek 16 "${I}")"
  HOUR_17="${HOUR_17} - $(__processHourWeek 17 "${I}")"
  HOUR_18="${HOUR_18} - $(__processHourWeek 18 "${I}")"
  HOUR_19="${HOUR_19} - $(__processHourWeek 19 "${I}")"
  HOUR_20="${HOUR_20} - $(__processHourWeek 20 "${I}")"
  HOUR_21="${HOUR_21} - $(__processHourWeek 21 "${I}")"
  HOUR_22="${HOUR_22} - $(__processHourWeek 22 "${I}")"
  HOUR_23="${HOUR_23} - $(__processHourWeek 23 "${I}")"
  ((I += 1))
 done
 set -e
 echo "        Sun -   Mon -   Tue -   Wed -   Thu -   Fri -   Sat"
 echo "${HOUR_0}"
 echo "${HOUR_1}"
 echo "${HOUR_2}"
 echo "${HOUR_3}"
 echo "${HOUR_4}"
 echo "${HOUR_5}"
 echo "${HOUR_6}"
 echo "${HOUR_7}"
 echo "${HOUR_8}"
 echo "${HOUR_9}"
 echo "${HOUR_10}"
 echo "${HOUR_11}"
 echo "${HOUR_12}"
 echo "${HOUR_13}"
 echo "${HOUR_14}"
 echo "${HOUR_15}"
 echo "${HOUR_16}"
 echo "${HOUR_17}"
 echo "${HOUR_18}"
 echo "${HOUR_19}"
 echo "${HOUR_20}"
 echo "${HOUR_21}"
 echo "${HOUR_22}"
 echo "${HOUR_23}"
 __log_finish
}

# Shows the activity as GitHub tiles.
function __printActivity {
 __log_start
 ACTIVITY="${1}"
 # TODO profile - not getting the current day, and always starting on Sunday

 declare SUN="Sunday:    "
 declare MON="Monday:    "
 declare TUE="Tuesday:   "
 declare WED="Wednesday: "
 declare THU="Thursay:   "
 declare FRI="Friday:    "
 declare SAT="Saturday:  "

 I=1
 set +e
 while [[ ${I} -le 53 ]]; do
  DAY="${ACTIVITY:0:1}"
  ACTIVITY="${ACTIVITY:1}"
  SUN="${SUN}${DAY}"
  DAY="${ACTIVITY:0:1}"
  ACTIVITY="${ACTIVITY:1}"
  MON="${MON}${DAY}"
  DAY="${ACTIVITY:0:1}"
  ACTIVITY="${ACTIVITY:1}"
  TUE="${TUE}${DAY}"
  DAY="${ACTIVITY:0:1}"
  ACTIVITY="${ACTIVITY:1}"
  WED="${WED}${DAY}"
  DAY="${ACTIVITY:0:1}"
  ACTIVITY="${ACTIVITY:1}"
  THU="${THU}${DAY}"
  DAY="${ACTIVITY:0:1}"
  ACTIVITY="${ACTIVITY:1}"
  FRI="${FRI}${DAY}"
  DAY="${ACTIVITY:0:1}"
  ACTIVITY="${ACTIVITY:1}"
  SAT="${SAT}${DAY}"
  I=$((I + 1))
 done
 set -e

 echo "${SUN}"
 echo "${MON}"
 echo "${TUE}"
 echo "${WED}"
 echo "${THU}"
 echo "${FRI}"
 echo "${SAT}"
 __log_finish
}

# Shows the user profile.
function __processUserProfile {
 __log_start
 declare -i OSM_USER_ID
 OSM_USER_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT user_id
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Quantity of days creating notes. (TODO profile - May have stopped opening or closing notes)
 declare -i QTY_DAYS_OPEN
 QTY_DAYS_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT CURRENT_DATE - date_starting_creating_notes
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare DATE_FIRST_OPEN
 DATE_FIRST_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT date_starting_creating_notes
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Quantity of days solving notes.
 declare -i QTY_DAYS_CLOSE
 QTY_DAYS_CLOSE=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT CURRENT_DATE - date_starting_solving_notes
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare DATE_FIRST_CLOSE
 DATE_FIRST_CLOSE=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT date_starting_solving_notes
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # First actions.
 declare -i FIRST_OPEN_NOTE_ID
 FIRST_OPEN_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT first_open_note_id
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i FIRST_COMMENTED_NOTE_ID
 FIRST_COMMENTED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT first_commented_note_id
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i FIRST_CLOSED_NOTE_ID
 FIRST_CLOSED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT first_closed_note_id
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i FIRST_REOPENED_NOTE_ID
 FIRST_REOPENED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT first_reopened_note_id
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Type of contributor.
 declare CONTRIBUTOR_TYPE
 CONTRIBUTOR_TYPE=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT contributor_type_name
     FROM dwh.datamartUsers u
      JOIN dwh.contributor_types t
      ON u.id_contributor_type = t.contributor_type_id
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Last activity year.
 declare LAST_ACTIVITY_YEAR
 LAST_ACTIVITY_YEAR=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT last_year_activity
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Most recent actions.
 declare -i LAST_OPEN_NOTE_ID
 LAST_OPEN_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT lastest_open_note_id
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i LAST_COMMENTED_NOTE_ID
 LAST_COMMENTED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT lastest_commented_note_id
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i LAST_CLOSED_NOTE_ID
 LAST_CLOSED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT lastest_closed_note_id
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i LAST_REOPENED_NOTE_ID
 LAST_REOPENED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT lastest_reopened_note_id
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Dates with more opened notes.
 declare DATES_MOST_OPEN
 DATES_MOST_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT dates_most_open
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Dates with more closed notes
 declare DATES_MOST_CLOSED
 DATES_MOST_CLOSED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT dates_most_closed
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Used hashtags TODO profile - procesar texto de notas
 declare HASHTAGS
 HASHTAGS=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT hashtags
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Countries opening notes.
 declare COUNTRIES_OPENING
 COUNTRIES_OPENING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT countries_open_notes
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Countries closing notes.
 declare COUNTRIES_CLOSING
 COUNTRIES_CLOSING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT countries_solving_notes
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Countries opening notes current month.
 declare COUNTRIES_OPENING_CURRENT_MONTH
 COUNTRIES_OPENING_CURRENT_MONTH=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT countries_open_notes_current_month
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Countries closing notes current month.
 declare COUNTRIES_CLOSING_CURRENT_MONTH
 COUNTRIES_CLOSING_CURRENT_MONTH=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT countries_solving_notes_current_month
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Countries opening notes current day.
 declare COUNTRIES_OPENING_CURRENT_DAY
 COUNTRIES_OPENING_CURRENT_DAY=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT countries_open_notes_current_day
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Countries closing notes current day.
 declare COUNTRIES_CLOSING_CURRENT_DAY
 COUNTRIES_CLOSING_CURRENT_DAY=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT countries_solving_notes_current_day
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Working hours.
 declare WORKING_HOURS_OPENING
 WORKING_HOURS_OPENING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT working_hours_of_week_opening
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare WORKING_HOURS_COMMENTING
 WORKING_HOURS_COMMENTING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT working_hours_of_week_commenting
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare WORKING_HOURS_CLOSING
 WORKING_HOURS_CLOSING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT working_hours_of_week_closing
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # History values.
 # Whole history.
 declare -i HISTORY_WHOLE_OPEN
 HISTORY_WHOLE_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_whole_open
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_WHOLE_COMMENTED
 HISTORY_WHOLE_COMMENTED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_whole_commented
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_WHOLE_CLOSED
 HISTORY_WHOLE_CLOSED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_whole_closed
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_WHOLE_CLOSED_WITH_COMMENT # TODO profile - process text
 HISTORY_WHOLE_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_whole_closed_with_comment
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_WHOLE_REOPENED
 HISTORY_WHOLE_REOPENED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_whole_reopened
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Last year history.
 declare -i HISTORY_YEAR_OPEN
 HISTORY_YEAR_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_year_open
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_COMMENTED
 HISTORY_YEAR_COMMENTED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_year_commented
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_CLOSED
 HISTORY_YEAR_CLOSED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_year_closed
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_CLOSED_WITH_COMMENT # TODO profile - process text
 HISTORY_YEAR_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_year_closed_with_comment
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_REOPENED
 HISTORY_YEAR_REOPENED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_year_reopened
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Last month history.
 declare -i HISTORY_MONTH_OPEN
 HISTORY_MONTH_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_month_open
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_MONTH_COMMENTED
 HISTORY_MONTH_COMMENTED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_month_commented
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_MONTH_CLOSED
 HISTORY_MONTH_CLOSED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_month_closed
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_MONTH_CLOSED_WITH_COMMENT # TODO profile - process text
 HISTORY_MONTH_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_month_closed_with_comment
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_MONTH_REOPENED
 HISTORY_MONTH_REOPENED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_month_reopened
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Last day history.
 declare -i HISTORY_DAY_OPEN
 HISTORY_DAY_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_day_open
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_DAY_COMMENTED
 HISTORY_DAY_COMMENTED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_day_commented
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_DAY_CLOSED
 HISTORY_DAY_CLOSED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_day_closed
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_DAY_CLOSED_WITH_COMMENT # TODO profile - process text
 HISTORY_DAY_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_day_closed_with_comment
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_DAY_REOPENED
 HISTORY_DAY_REOPENED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_day_reopened
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Badges. TODO profile - asignar
 # declare BADGES
 # BADGES=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT b.badge_name, p.date_awarded
 #     FROM dwh.badges_per_users p
 #      JOIN dwh.badges b
 #      ON p.id_badge = b.badge_id
 #     WHERE dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 # ToDo profile - Open more than 100 notes in a day
 # ToDo profile - Open more than 300 notes in a day
 # ToDo profile - Open more than 1000 notes in a day
 # ToDo profile - Resolve more than 100 notes in a day
 # ToDo profile - Resolve more than 300 notes in a day
 # ToDo profile - Resolve more than 1000 notes in a day

 # TODO profile - if zero, hide
 echo "User name: ${USERNAME} (id: ${OSM_USER_ID})."
 echo "Note solver type: ${CONTRIBUTOR_TYPE}."
 echo "Quantity of days creating notes: ${QTY_DAYS_OPEN}, since ${DATE_FIRST_OPEN}."
 echo "Quantity of days solving notes: ${QTY_DAYS_CLOSE}, since ${DATE_FIRST_CLOSE}."
 echo "First actions: https://www.openstreetmap.org/note/${FIRST_OPEN_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_COMMENTED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_CLOSED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_REOPENED_NOTE_ID}"
 echo "Most recent actions:  https://www.openstreetmap.org/note/${LAST_OPEN_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_COMMENTED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_CLOSED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_REOPENED_NOTE_ID}"
 echo "Last activity year:"
 __printActivity "${LAST_ACTIVITY_YEAR}"
 echo "The date when the most notes were opened:"
 echo "${DATES_MOST_OPEN}" | sed 's/}, {"date" : "/\n/g' | sed 's/", "quantity" : / - /g' | sed 's/\[{"date" : "//' | sed 's/}\]//'
 echo "The date when the most notes were closed:"
 echo "${DATES_MOST_CLOSED}" | sed 's/}, {"date" : "/\n/g' | sed 's/", "quantity" : / - /g' | sed 's/\[{"date" : "//' | sed 's/}\]//'
 echo "Hashtags used: ${HASHTAGS}" # TODO profile -
 echo "Working hours:"             # TODO profile - For past years
 set +E
 echo "  Opening:"
 __showWorkingWeek "${WORKING_HOURS_OPENING}"
 echo "  Commenting:"
 __showWorkingWeek "${WORKING_HOURS_COMMENTING}"
 echo "  Closing:"
 __showWorkingWeek "${WORKING_HOURS_CLOSING}"
 set -E
 echo
 echo "Actions:"
 #                       1234567890 1234567890 1234567890 1234567890 1234567890
 printf "                  Opened  Commented     Closed Cld w/cmmt   Reopened\n"
 printf "Total:         %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_WHOLE_OPEN}" "${HISTORY_WHOLE_COMMENTED}" "${HISTORY_WHOLE_CLOSED}" "${HISTORY_WHOLE_CLOSED_WITH_COMMENT}" "${HISTORY_WHOLE_REOPENED}"
 printf "Current year:  %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_YEAR_OPEN}" "${HISTORY_YEAR_COMMENTED}" "${HISTORY_YEAR_CLOSED}" "${HISTORY_YEAR_CLOSED_WITH_COMMENT}" "${HISTORY_YEAR_REOPENED}"
 printf "Current month: %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_MONTH_OPEN}" "${HISTORY_MONTH_COMMENTED}" "${HISTORY_MONTH_CLOSED}" "${HISTORY_MONTH_CLOSED_WITH_COMMENT}" "${HISTORY_MONTH_REOPENED}"
 printf "Today:         %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_DAY_OPEN}" "${HISTORY_DAY_COMMENTED}" "${HISTORY_DAY_CLOSED}" "${HISTORY_DAY_CLOSED_WITH_COMMENT}" "${HISTORY_DAY_REOPENED}"
 I=2013
 CURRENT_YEAR=$(date +%Y)
 while [[ "${I}" -le "${CURRENT_YEAR}" ]]; do
  __showActivityYearUsers "${I}"
  I=$((I + 1))
 done
 echo "Historically:"
 echo "Countries for open notes:"
 __printRanking "${COUNTRIES_OPENING}"
 echo "Countries for closed notes:"
 __printRanking "${COUNTRIES_CLOSING}"
 I=2013
 CURRENT_YEAR=$(date +%Y)
 while [[ "${I}" -le "${CURRENT_YEAR}" ]]; do
  __showRankingYearUsers "${I}"
  I=$((I + 1))
 done
 echo
 echo "Ranking in the current month:"
 echo "Countries for open notes:"
 __printRanking "${COUNTRIES_OPENING_CURRENT_MONTH}"
 echo "Countries for closed notes:"
 __printRanking "${COUNTRIES_CLOSING_CURRENT_MONTH}"
 echo "Ranking in the current day:"
 echo "Countries for open notes:"
 __printRanking "${COUNTRIES_OPENING_CURRENT_DAY}"
 echo "Countries for closed notes:"
 __printRanking "${COUNTRIES_CLOSING_CURRENT_DAY}"

 # echo "Rankings last 30 days   ${RANKING_MONTH_OPEN} ${RANKING_MONTH_COMMENTED} ${RANKING_MONTH_CLOSED} ${RANKING_MONTH_REOPENED}"
 # echo "Rankings today          ${RANKING_DAY_OPEN} ${RANKING_DAY_COMMENTED} ${RANKING_DAY_CLOSED} ${RANKING_DAY_REOPENED}"
 # echo "Badges: ${BADGES}" #TODO profile -
 __log_finish
}

# Shows the note statistics for a given country.
function __processCountryProfile {
 __log_start
 # Country OSM Id
 declare -i COUNTRY_OSM_ID
 COUNTRY_OSM_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT country_id
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Quantity of days with open notes.
 declare -i QTY_DAYS_OPEN
 QTY_DAYS_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT CURRENT_DATE - date_starting_creating_notes
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare DATE_FIRST_OPEN
 DATE_FIRST_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT date_starting_creating_notes
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Quantity of days solving notes.
 declare -i QTY_DAYS_CLOSE
 QTY_DAYS_CLOSE=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT CURRENT_DATE - date_starting_solving_notes
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare DATE_FIRST_CLOSE
 DATE_FIRST_CLOSE=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT date_starting_solving_notes
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # First actions.
 declare -i FIRST_OPEN_NOTE_ID
 FIRST_OPEN_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT first_open_note_id
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i FIRST_COMMENTED_NOTE_ID
 FIRST_COMMENTED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT first_commented_note_id
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i FIRST_CLOSED_NOTE_ID
 FIRST_CLOSED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT first_closed_note_id
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i FIRST_REOPENED_NOTE_ID
 FIRST_REOPENED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT first_reopened_note_id
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Last activity year.
 declare LAST_ACTIVITY_YEAR
 LAST_ACTIVITY_YEAR=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT last_year_activity
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Most recent actions.
 declare -i LAST_OPEN_NOTE_ID
 LAST_OPEN_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT lastest_open_note_id
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i LAST_COMMENTED_NOTE_ID
 LAST_COMMENTED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT lastest_commented_note_id
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i LAST_CLOSED_NOTE_ID
 LAST_CLOSED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT lastest_closed_note_id
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i LAST_REOPENED_NOTE_ID
 LAST_REOPENED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT lastest_reopened_note_id
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Date with more opened notes.
 declare DATES_MOST_OPEN
 DATES_MOST_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT dateS_most_open
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Date with more closed notes
 declare DATES_MOST_CLOSED
 DATES_MOST_CLOSED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT dates_most_closed
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Used hashtags TODO profile - procesar texto de notas
 declare HASHTAGS
 HASHTAGS=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT hashtags
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Users opening notes. Global ranking, historically.
 declare USERS_OPENING
 USERS_OPENING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT users_open_notes
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Users closing notes. Global ranking, historically.
 declare USERS_CLOSING
 USERS_CLOSING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT users_solving_notes
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Users opening notes. Current month.
 declare USERS_OPENING_CURRENT_MONTH
 USERS_OPENING_CURRENT_MONTH=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT users_open_notes_current_month
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Users closing notes. Current month.
 declare USERS_CLOSING_CURRENT_MONTH
 USERS_CLOSING_CURRENT_MONTH=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT users_solving_notes_current_month
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Users opening notes. Current day.
 declare USERS_OPENING_CURRENT_DAY
 USERS_OPENING_CURRENT_DAY=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT users_open_notes_current_day
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Users closing notes. Current day.
 declare USERS_CLOSING_CURRENT_DAY
 USERS_CLOSING_CURRENT_DAY=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT users_solving_notes_current_day
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Working hours.
 declare WORKING_HOURS_OF_WEEK_OPENING
 WORKING_HOURS_OF_WEEK_OPENING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT working_hours_of_week_opening
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare WORKING_HOURS_OF_WEEK_COMMENTING
 WORKING_HOURS_OF_WEEK_COMMENTING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT working_hours_of_week_commenting
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare WORKING_HOURS_OF_WEEK_CLOSING
 WORKING_HOURS_OF_WEEK_CLOSING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT working_hours_of_week_closing
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # History values.
 # Whole history.
 declare -i HISTORY_WHOLE_OPEN
 HISTORY_WHOLE_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_whole_open
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_WHOLE_COMMENTED
 HISTORY_WHOLE_COMMENTED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_whole_commented
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_WHOLE_CLOSED
 HISTORY_WHOLE_CLOSED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_whole_closed
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_WHOLE_CLOSED_WITH_COMMENT # TODO profile - process text
 HISTORY_WHOLE_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_whole_closed_with_comment
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_WHOLE_REOPENED
 HISTORY_WHOLE_REOPENED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_whole_reopened
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Last year history.
 declare -i HISTORY_YEAR_OPEN
 HISTORY_YEAR_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_year_open
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_COMMENTED
 HISTORY_YEAR_COMMENTED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_year_commented
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_CLOSED
 HISTORY_YEAR_CLOSED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_year_closed
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_CLOSED_WITH_COMMENT # TODO profile - process text
 HISTORY_YEAR_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_year_closed_with_comment
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_YEAR_REOPENED
 HISTORY_YEAR_REOPENED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_year_reopened
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Last month history.
 declare -i HISTORY_MONTH_OPEN
 HISTORY_MONTH_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_month_open
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_MONTH_COMMENTED
 HISTORY_MONTH_COMMENTED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_month_commented
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_MONTH_CLOSED
 HISTORY_MONTH_CLOSED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_month_closed
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_MONTH_CLOSED_WITH_COMMENT # TODO profile - process text
 HISTORY_MONTH_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_month_closed_with_comment
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_MONTH_REOPENED
 HISTORY_MONTH_REOPENED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_month_reopened
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Last day history.
 declare -i HISTORY_DAY_OPEN
 HISTORY_DAY_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_day_open
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_DAY_COMMENTED
 HISTORY_DAY_COMMENTED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_day_commented
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_DAY_CLOSED
 HISTORY_DAY_CLOSED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_day_closed
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_DAY_CLOSED_WITH_COMMENT # TODO profile - process text
 HISTORY_DAY_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_day_closed_with_comment
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare -i HISTORY_DAY_REOPENED
 HISTORY_DAY_REOPENED=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT history_day_reopened
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # TODO profile - if zero, hide
 echo "COUNTRY name: ${COUNTRY_NAME} (id: ${COUNTRY_OSM_ID})"
 echo "Quantity of days creating notes: ${QTY_DAYS_OPEN}, since ${DATE_FIRST_OPEN}."
 echo "Quantity of days solving notes: ${QTY_DAYS_CLOSE}, since ${DATE_FIRST_CLOSE}"
 echo "First actions: https://www.openstreetmap.org/note/${FIRST_OPEN_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_COMMENTED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_CLOSED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_REOPENED_NOTE_ID}"
 echo "Last actions:  https://www.openstreetmap.org/note/${LAST_OPEN_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_COMMENTED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_CLOSED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_REOPENED_NOTE_ID}"
 echo "Last activity year:"
 __printActivity "${LAST_ACTIVITY_YEAR}"
 # TODO profile - Activity is putting 0000009 in the last week
 echo "The date when the most notes were opened:"
 echo "${DATES_MOST_OPEN}" | sed 's/}, {"date" : "/\n/g' | sed 's/", "quantity" : / - /g' | sed 's/\[{"date" : "//' | sed 's/}\]//'
 echo "The date when the most notes were closed:"
 echo "${DATES_MOST_CLOSED}" | sed 's/}, {"date" : "/\n/g' | sed 's/", "quantity" : / - /g' | sed 's/\[{"date" : "//' | sed 's/}\]//'
 echo "Hashtags used: ${HASHTAGS}" # TODO
 echo "Working hours:"             # TODO profile - By year
 set +E
 echo "  Opening:"
 __showWorkingWeek "${WORKING_HOURS_OF_WEEK_OPENING}"
 echo "  Commenting:"
 __showWorkingWeek "${WORKING_HOURS_OF_WEEK_COMMENTING}"
 echo "  Closing:"
 __showWorkingWeek "${WORKING_HOURS_OF_WEEK_CLOSING}"
 set -E
 # TODO profile - Show the quantity of notes currently in open status
 # TODO profile - Show the quantity of notes currently in closed status
 echo
 echo "Actions:"
 #                       1234567890 1234567890 1234567890 1234567890 1234567890
 printf "                   Opens   Comments     Closes Cls w/cmmt    Reopens\n"
 printf "Total:         %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_WHOLE_OPEN}" "${HISTORY_WHOLE_COMMENTED}" "${HISTORY_WHOLE_CLOSED}" "${HISTORY_WHOLE_CLOSED_WITH_COMMENT}" "${HISTORY_WHOLE_REOPENED}"
 printf "Current year:  %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_YEAR_OPEN}" "${HISTORY_YEAR_COMMENTED}" "${HISTORY_YEAR_CLOSED}" "${HISTORY_YEAR_CLOSED_WITH_COMMENT}" "${HISTORY_YEAR_REOPENED}"
 printf "Current month: %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_MONTH_OPEN}" "${HISTORY_MONTH_COMMENTED}" "${HISTORY_MONTH_CLOSED}" "${HISTORY_MONTH_CLOSED_WITH_COMMENT}" "${HISTORY_MONTH_REOPENED}"
 printf "Today:         %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_DAY_OPEN}" "${HISTORY_DAY_COMMENTED}" "${HISTORY_DAY_CLOSED}" "${HISTORY_DAY_CLOSED_WITH_COMMENT}" "${HISTORY_DAY_REOPENED}"
 I=2013
 CURRENT_YEAR=$(date +%Y)
 while [[ "${I}" -le "${CURRENT_YEAR}" ]]; do
  __showActivityYearCountries "${I}"
  I=$((I + 1))
  # TODO Top 10 Notes with most comments per year.
  # TODO Top 10 Notes with most reopening per year.
 done
 echo "Historically:"
 echo "Users creating notes:"
 __printRanking "${USERS_OPENING}"
 echo "Users closing notes:"
 __printRanking "${USERS_CLOSING}"
 I=2013
 CURRENT_YEAR=$(date +%Y)
 while [[ "${I}" -le "${CURRENT_YEAR}" ]]; do
  __showRankingYearCountries "${I}"
  I=$((I + 1))
 done
 echo
 echo "Ranking users creating notes in the current month:"
 __printRanking "${USERS_OPENING_CURRENT_MONTH}"
 echo "Ranking users closing notes in the current month:"
 __printRanking "${USERS_CLOSING_CURRENT_MONTH}"
 echo "Ranking users creating notes in the current day:"
 __printRanking "${USERS_OPENING_CURRENT_DAY}"
 echo "Ranking users closing notes in the current day:"
 __printRanking "${USERS_CLOSING_CURRENT_DAY}"
 # TODO Badges
 # TODO Quantity of days with 0 notes (at midnight UTC)
 # TODO Quantity of new UTC years eve with 0 notes
 __log_finish
}

# Shows general stats about notes.
function __generalNoteStats {
 __log_start
 echo "ToDo Number of notes"
 echo "ToDo Number of currently open notes"
 echo "ToDo Number of currently closed notes"
 echo "ToDo Number of reactivated notes after hidden"
 echo "ToDo Number of OSM note id gaps (probably hidden notes)"
 echo "ToDo Number of reopened notes"
 echo "ToDo Number of note comments"
 echo "ToDo Number of users doing things on notes"
 echo "ToDo Number of users opening notes"
 echo "ToDo Number of users closing notes"
 echo "ToDo Number of users reactivating notes after hidden"
 echo "ToDo All previous values per year since 2013, to show the increment"
 echo "ToDo working hours for opening notes"
 echo "ToDo working hours for closing notes"
 echo "ToDo Top 10 Notes with most comments"
 echo "ToDo Top 10 Notes with most comments for each year since 2013"
 echo "ToDo Top 10 Notes with most reopenings (war)"
 echo "ToDo Top 10 Notes with most reopenings for each year since 2013 (war)"
 echo "ToDo Oldest available note (not hidden)"
 echo "ToDo Most recently opened note"
 echo "ToDo Notes created today"
 echo "ToDo Notes created this month"
 echo "ToDo Notes created this year"
 echo "ToDo Average daily note creation for each year"
 echo "ToDo Average daily note closing for each year"
 echo "ToDo Average monthly note creation for each year"
 echo "ToDo Average monthly note closing for each year"
 echo "ToDo Average annual note creation for each year"
 echo "ToDo Average annual note closing for each year"
 echo "ToDo Top 10 users doing self war of opening and closing"
 echo "ToDo Top 10 users participating in note war"
 echo "ToDo Top 10 users participating in note war per year"
 echo "ToDo Users who have opened more than 1000 notes in a day"
 echo "ToDo Users who have closed more than 1000 notes in a day"
 # TODO Distribution of contributions per user
 # select t.qty, count(1)
 # from (
 #  select count(1) qty, f.action_dimension_id_user user_notes
 #  from dwh.facts f
 #  group by f.action_dimension_id_user
 # ) AS t
 # group by qty
 # order by qty desc
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
     echo "Failed command: "${ERROR_COMMAND}"
     echo "Exit code: "${ERROR_EXIT_CODE}"
     echo "Temporary directory: ${TMP_DIR:-unknown}"
     echo "Process ID: $$"
    } > "${FAILED_EXECUTION_FILE}"
   fi;
   exit "${ERROR_EXIT_CODE}";
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
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}."
 __logi "Processing: ${PROCESS_TYPE}."

 if [[ "${PROCESS_TYPE}" == "-h" ]] || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi
 __checkPrereqs

 __logw "Starting process."
 # Sets the trap in case of any signal.
 __trapOn

 if [[ "${PROCESS_TYPE}" == "--user" ]]; then
  __getUserId
  __processUserProfile
 elif [[ "${PROCESS_TYPE}" == "--country" ]] \
  || [[ "${PROCESS_TYPE}" == "--pais" ]]; then
  __getCountryId
  __processCountryProfile
 elif [[ "${PROCESS_TYPE}" == "" ]]; then
  __generalNoteStats
 fi

 __logw "Ending process."
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

# Only execute main if this script is being run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 __start_logger
 if [[ ! -t 1 ]]; then
  __set_log_file "${LOG_FILENAME}"
  main >> "${LOG_FILENAME}"
  if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
   mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
   rmdir "${TMP_DIR}"
  fi
 else
  main
 fi
fi
