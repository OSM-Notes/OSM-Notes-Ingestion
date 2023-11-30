#!/bin/bash

# This script allows to see a user profile, a country profile or general
# statistics about notes. It reads all values from the database, from the
# datamart.
#
# There are 3 ways to call this script:
# * --user <UserName> : Shows the profile for the given user.
# * --country <CountryName> : Shows the profile for the given country.
# If the UserName or CountryName has spaces in the name, it should be invoked
# between double quotes.
# * (empty) : It shows general statistics about notes.
#
# For example:
# * --user AngocA
# * --country Colombia
# * --country "Estados Unidos de América"
# The name should match the name on the database in Spanish.
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
# For contributing, please execute these commands before subimitting:
# * shellcheck -x -o all profile.sh
# * shfmt -w -i 1 -sr -bn profile.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2023-11-30
declare -r VERSION="2023-11-30"

#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with an non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E

# If all files should be deleted. In case of an error, this could be disabled.
# You can defined when calling: export CLEAN=false
declare -r CLEAN="${CLEAN:-true}"

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory for the project.
declare SCRIPT_BASE_DIRECTORY
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
 &> /dev/null && pwd)"
readonly SCRIPT_BASE_DIRECTORY

# Loads the global properties.
# shellcheck source=../../etc/properties.sh
source "${SCRIPT_BASE_DIRECTORY}/etc/properties.sh"

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME
# Temporal directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
# Lof file for output.
declare LOG_FILENAME
LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILENAME

# Type of process to run in the script.
declare -r PROCESS_TYPE=${1:-}
# Argument for the process type.
declare -r ARGUMENT=${2:-}

# Username.
declare USERNAME
# Dimension_User_id of the username.
declare -i DIMENSION_USER_ID
# Name of the user or the country.
declare COUNTRY_NAME
# Country_id of the contry.
declare -i COUNTRY_ID

# Location of the common functions.
declare -r FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

###########
# FUNCTIONS

# shellcheck source=../functionsProcess.sh
source "${FUNCTIONS_FILE}"

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
 echo "* --country \"Estados Unidos de América\""
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
  && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --user"
  echo " * --country"
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

 __checkPrereqsCommands

 __log_finish
 set -e
}

# Retrives the dimension_user_id from a username.
function __getUserId {
 DIMENSION_USER_ID=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT dimension_user_id FROM dwh.datamartUsers
  WHERE username = '${USERNAME}'")
 if [[ "${DIMENSION_USER_ID}" == "" ]] || [[ "${DIMENSION_USER_ID}" -eq 0 ]]; then
  __loge "ERROR: The username \"${USERNAME}\" does not exist."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
}

# Retrives the country_id from a country name.
function __getCountryId {
 COUNTRY_ID=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT dimension_country_id FROM dwh.datamartCountries 
  WHERE country_name_es = '${COUNTRY_NAME}'")
 if [[ "${COUNTRY_ID}" == "" ]]; then
  __loge "ERROR: The country name \"${COUNTRY_NAME}\" does not exist."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
}

# Shows the user activity for all years after 2013.
function __showActivityYearUsers {
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
}

# Shows the country activity for all years after 2013.
function __showActivityYearCountries {
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
}

# Prints a given ranking in a better way.
function __printRanking {
 RANKING=${1}

 echo "${RANKING}" | sed 's/}, {/\n/g' | sed 's/^\[{//' | sed 's/}\]//' | sed 's/"rank" ://g' | sed 's/, "country_name" : "/ - /g' | sed 's/", "quantity" :/:/g'
}

# Shows the historic yearly rankings when the user has contributed the most.
function __showRankingYearUsers {
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
}

# Shows the historic yearly rankings on which users have been contributed the most.
function __showRankingYearCountries {
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
}

# Prints the hour the hour of the week.
function __processHourWeek {
 HOUR=${1}
 NUMBER=$(echo "${WEEK}" | grep "\"day_of_week\":${I},\"hour_of_day\":${HOUR}," | awk -F: '{print $4}' | sed 's/}, //' | sed 's/}\]//')
 printf "%5d" "${NUMBER}"
}

# Shows the week hours in a better fashion.
function __showWorkingWeek {
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
 while [ ${I} -le 7 ]; do
  J=0
  HOUR_0="${HOUR_0} - $(__processHourWeek 0)"
  HOUR_1="${HOUR_1} - $(__processHourWeek 1)"
  HOUR_2="${HOUR_2} - $(__processHourWeek 2)"
  HOUR_3="${HOUR_3} - $(__processHourWeek 3)"
  HOUR_4="${HOUR_4} - $(__processHourWeek 4)"
  HOUR_5="${HOUR_5} - $(__processHourWeek 5)"
  HOUR_6="${HOUR_6} - $(__processHourWeek 6)"
  HOUR_7="${HOUR_7} - $(__processHourWeek 7)"
  HOUR_8="${HOUR_8} - $(__processHourWeek 8)"
  HOUR_9="${HOUR_9} - $(__processHourWeek 9)"
  HOUR_10="${HOUR_10} - $(__processHourWeek 10)"
  HOUR_11="${HOUR_11} - $(__processHourWeek 11)"
  HOUR_12="${HOUR_12} - $(__processHourWeek 12)"
  HOUR_13="${HOUR_13} - $(__processHourWeek 13)"
  HOUR_14="${HOUR_14} - $(__processHourWeek 14)"
  HOUR_15="${HOUR_15} - $(__processHourWeek 15)"
  HOUR_16="${HOUR_16} - $(__processHourWeek 16)"
  HOUR_17="${HOUR_17} - $(__processHourWeek 17)"
  HOUR_18="${HOUR_18} - $(__processHourWeek 18)"
  HOUR_19="${HOUR_19} - $(__processHourWeek 19)"
  HOUR_20="${HOUR_20} - $(__processHourWeek 20)"
  HOUR_21="${HOUR_21} - $(__processHourWeek 21)"
  HOUR_22="${HOUR_22} - $(__processHourWeek 22)"
  HOUR_23="${HOUR_23} - $(__processHourWeek 23)"
  I=$((I+1))
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
}

# Shows the user profile.
function __processUserProfile {
 declare -i OSM_USER_ID
 OSM_USER_ID=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT user_id
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Quantity of days creating notes. (TODO Puede que haya dejado de abrir o cerrar notas)
 declare -i QTY_DAYS_OPEN
 QTY_DAYS_OPEN=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT CURRENT_DATE - date_starting_creating_notes
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1)

 declare DATE_FIRST_OPEN
 DATE_FIRST_OPEN=($(psql -d "${DBNAME}" -Atq \
  -c "SELECT date_starting_creating_notes
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${DIMENSION_USER_ID}
     " \
  -v ON_ERROR_STOP=1))

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

 # Used hashtags TODO procesar texto de notas
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

 declare -i HISTORY_WHOLE_CLOSED_WITH_COMMENT # TODO process text
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

 declare -i HISTORY_YEAR_CLOSED_WITH_COMMENT # TODO process text
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

 declare -i HISTORY_MONTH_CLOSED_WITH_COMMENT # TODO process text
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

 declare -i HISTORY_DAY_CLOSED_WITH_COMMENT # TODO process text
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

 # # Ranking historic # TODO
 # declare RANKING_HISTORIC_OPEN
 # RANKING_HISTORIC_OPEN=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_historic
 #      WHERE action = 'opened'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # declare RANKING_HISTORIC_COMMENTED
 # RANKING_HISTORIC_COMMENTED=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_historic
 #      WHERE action = 'commented'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # declare RANKING_HISTORIC_CLOSED
 # RANKING_HISTORIC_CLOSED=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_historic
 #      WHERE action = 'closed'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # declare RANKING_HISTORIC_REOPENED
 # RANKING_HISTORIC_REOPENED=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_historic
 #      WHERE action = 'reopened'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # # Ranking year #TODO
 # declare RANKING_YEAR_OPEN
 # RANKING_YEAR_OPEN=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_year
 #      WHERE action = 'opened'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # declare RANKING_YEAR_COMMENTED
 # RANKING_YEAR_COMMENTED=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_year
 #      WHERE action = 'commented'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # declare RANKING_YEAR_CLOSED
 # RANKING_YEAR_CLOSED=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_year
 #      WHERE action = 'closed'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # declare RANKING_YEAR_REOPENED
 # RANKING_YEAR_REOPENED=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_year
 #      WHERE action = 'reopened'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # # Ranking month #TODO
 # declare RANKING_MONTH_OPEN
 # RANKING_MONTH_OPEN=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_month
 #      WHERE action = 'opened'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # declare RANKING_MONTH_COMMENTED
 # RANKING_MONTH_COMMENTED=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_month
 #      WHERE action = 'commented'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # declare RANKING_MONTH_CLOSED
 # RANKING_MONTH_CLOSED=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_month
 #      WHERE action = 'closed'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # declare RANKING_MONTH_REOPENED
 # RANKING_MONTH_REOPENED=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_month
 #      WHERE action = 'reopened'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # # Ranking day #TODO
 # declare RANKING_DAY_OPEN
 # RANKING_DAY_OPEN=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_day
 #      WHERE action = 'opened'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # declare RANKING_DAY_COMMENTED
 # RANKING_DAY_COMMENTED=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_day
 #      WHERE action = 'commented'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # declare RANKING_DAY_CLOSED
 # RANKING_DAY_CLOSED=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_day
 #      WHERE action = 'closed'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 #
 # declare RANKING_DAY_REOPENED
 # RANKING_DAY_REOPENED=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT position, id_country
 #      FROM dwh.ranking_day
 #      WHERE action = 'reopened'
 #      AND dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )

 # Badges. TODO
 declare BADGES
 # BADGES=$(psql -d "${DBNAME}" -Atq \
 #    -c "SELECT b.badge_name, p.date_awarded
 #     FROM dwh.badges_per_users p
 #      JOIN dwh.badges b
 #      ON p.id_badge = b.badge_id
 #     WHERE dimension_user_id = ${DIMENSION_USER_ID}
 #     " \
 #    -v ON_ERROR_STOP=1 )
 # ToDo Abrir más de 100 notas en un día
 # ToDo Abrir más de 300 notas en un día
 # ToDo Abrir más de 1000 notas en un día
 # ToDo Resolver más de 100 notas en un día
 # ToDo Resolver más de 300 notas en un día
 # ToDo Resolver más de 1000 notas en un día

 # TODO si cero, ocultar
 echo "User name: ${USERNAME} (id: ${OSM_USER_ID})."
 echo "Note solver type: ${CONTRIBUTOR_TYPE}."
 echo "Quantity of days creating notes: ${QTY_DAYS_OPEN}, since ${DATE_FIRST_OPEN}."
 echo "Quantity of days solving notes: ${QTY_DAYS_CLOSE}, since ${DATE_FIRST_CLOSE}."
 echo "First actions: https://www.openstreetmap.org/note/${FIRST_OPEN_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_COMMENTED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_CLOSED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_REOPENED_NOTE_ID}"
 echo "Most recent actions:  https://www.openstreetmap.org/note/${LAST_OPEN_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_COMMENTED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_CLOSED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_REOPENED_NOTE_ID}"
 echo "Last activity year: ${LAST_ACTIVITY_YEAR}" # TODO Mostrar por columnas cada semana
 echo "The date when the most notes were opened:"
 echo "${DATES_MOST_OPEN}" | sed 's/}, {"date" : "/\n/g' | sed 's/", "quantity" : / - /g' | sed 's/\[{"date" : "//' | sed 's/}\]//'
 echo "The date when the most notes were closed:"
 echo "${DATES_MOST_CLOSED}" | sed 's/}, {"date" : "/\n/g' | sed 's/", "quantity" : / - /g' | sed 's/\[{"date" : "//' | sed 's/}\]//'
 echo "Hashtags used: ${HASHTAGS}" # TODO
 echo "Working hours:" # TODO Por año
 set +E
 echo "  Opening:"
 __showWorkingWeek "${WORKING_HOURS_OPENING}"
 echo "  Commenting:"
 __showWorkingWeek "${WORKING_HOURS_COMMENTING}"
 echo "  Closing:"
 __showWorkingWeek "${WORKING_HOURS_CLOSING}"
 set -E
 #                       1234567890 1234567890 1234567890 1234567890 1234567890
 printf "                  Opened  Commented     Closed Cld w/cmmt   Reopened\n"
 printf "Total:         %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_WHOLE_OPEN}" "${HISTORY_WHOLE_COMMENTED}" "${HISTORY_WHOLE_CLOSED}" "${HISTORY_WHOLE_CLOSED_WITH_COMMENT}" "${HISTORY_WHOLE_REOPENED}"
 printf "Last 365 year: %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_YEAR_OPEN}" "${HISTORY_YEAR_COMMENTED}" "${HISTORY_YEAR_CLOSED}" "${HISTORY_YEAR_CLOSED_WITH_COMMENT}" "${HISTORY_YEAR_REOPENED}"
 printf "Last 30 days:  %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_MONTH_OPEN}" "${HISTORY_MONTH_COMMENTED}" "${HISTORY_MONTH_CLOSED}" "${HISTORY_MONTH_CLOSED_WITH_COMMENT}" "${HISTORY_MONTH_REOPENED}"
 printf "Last day:      %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_DAY_OPEN}" "${HISTORY_DAY_COMMENTED}" "${HISTORY_DAY_CLOSED}" "${HISTORY_DAY_CLOSED_WITH_COMMENT}" "${HISTORY_DAY_REOPENED}"
 I=2013
 CURRENT_YEAR=$(date +%Y)
 while [[ "${I}" -le "${CURRENT_YEAR}" ]]; do
  __showActivityYearUsers "${I}"
  I=$((I + 1))
 done
 echo "Historically:"
 echo "Countries for open notes: ${COUNTRIES_OPENING}"
 echo "Countries for closed notes: ${COUNTRIES_CLOSING}"
 I=2013
 CURRENT_YEAR=$(date +%Y)
 while [[ "${I}" -le "${CURRENT_YEAR}" ]]; do
  __showRankingYearUsers "${I}"
  I=$((I + 1))
 done

 # echo "Rankings historic       ${RANKING_HISTORIC_OPEN} ${RANKING_HISTORIC_COMMENTED} ${RANKING_HISTORIC_CLOSED} ${RANKING_HISTORIC_REOPENED}"
 # echo "Rankings last 12 months ${RANKING_YEAR_OPEN} ${RANKING_YEAR_COMMENTED} ${RANKING_YEAR_CLOSED} ${RANKING_YEAR_REOPENED}"
 # echo "Rankings last 30 days   ${RANKING_MONTH_OPEN} ${RANKING_MONTH_COMMENTED} ${RANKING_MONTH_CLOSED} ${RANKING_MONTH_REOPENED}"
 # echo "Rankings today          ${RANKING_DAY_OPEN} ${RANKING_DAY_COMMENTED} ${RANKING_DAY_CLOSED} ${RANKING_DAY_REOPENED}"
 # echo "Badges: ${BADGES}" #TODO
}

# Shows the note statistics for a given country.
function __processCountryProfile {
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

 # Used hashtags TODO procesar texto de notas
 declare HASHTAGS
 HASHTAGS=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT hashtags
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Users opening notes. Global ranking.
 declare USERS_OPENING
 USERS_OPENING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT users_open_notes
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Users closing notes. Global ranking.
 declare USERS_CLOSING
 USERS_CLOSING=$(psql -d "${DBNAME}" -Atq \
  -c "SELECT users_solving_notes
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
  -v ON_ERROR_STOP=1)

 # Working hours. TODO mostrar semana
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

 declare -i HISTORY_WHOLE_CLOSED_WITH_COMMENT # TODO process text
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

 declare -i HISTORY_YEAR_CLOSED_WITH_COMMENT # TODO process text
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

 declare -i HISTORY_MONTH_CLOSED_WITH_COMMENT # TODO process text
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

 declare -i HISTORY_DAY_CLOSED_WITH_COMMENT # TODO process text
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

 # TODO si cero, ocultar
 echo "COUNTRY name: ${COUNTRY_NAME} (id: ${COUNTRY_OSM_ID})"
 echo "Quantity of days creating notes: ${QTY_DAYS_OPEN}, since ${DATE_FIRST_OPEN}."
 echo "Quantity of days solving notes: ${QTY_DAYS_CLOSE}, since ${DATE_FIRST_CLOSE}"
 echo "First actions: https://www.openstreetmap.org/note/${FIRST_OPEN_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_COMMENTED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_CLOSED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_REOPENED_NOTE_ID}"
 echo "Last actions:  https://www.openstreetmap.org/note/${LAST_OPEN_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_COMMENTED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_CLOSED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_REOPENED_NOTE_ID}"
 echo "Last activity year: ${LAST_ACTIVITY_YEAR}"
 echo "The date when the most notes were opened:"
 echo "${DATES_MOST_OPEN}" | sed 's/}, {"date" : "/\n/g' | sed 's/", "quantity" : / - /g' | sed 's/\[{"date" : "//' | sed 's/}\]//'
 echo "The date when the most notes were closed:"
 echo "${DATES_MOST_CLOSED}" | sed 's/}, {"date" : "/\n/g' | sed 's/", "quantity" : / - /g' | sed 's/\[{"date" : "//' | sed 's/}\]//'
 echo "Hashtags used: ${HASHTAGS}" # TODO
 echo "Working hours:" # TODO Por año
 set +E
 echo "  Opening:"
 __showWorkingWeek "${WORKING_HOURS_OF_WEEK_OPENING}"
 echo "  Commenting:"
 __showWorkingWeek "${WORKING_HOURS_OF_WEEK_COMMENTING}"
 echo "  Closing:"
 __showWorkingWeek "${WORKING_HOURS_OF_WEEK_CLOSING}"
 set -E
 #                       1234567890 1234567890 1234567890 1234567890 1234567890
 printf "                  Opened  Commented     Closed Cld w/cmmt   Reopened\n"
 printf "Total:         %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_WHOLE_OPEN}" "${HISTORY_WHOLE_COMMENTED}" "${HISTORY_WHOLE_CLOSED}" "${HISTORY_WHOLE_CLOSED_WITH_COMMENT}" "${HISTORY_WHOLE_REOPENED}"
 printf "Last 365 year: %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_YEAR_OPEN}" "${HISTORY_YEAR_COMMENTED}" "${HISTORY_YEAR_CLOSED}" "${HISTORY_YEAR_CLOSED_WITH_COMMENT}" "${HISTORY_YEAR_REOPENED}"
 printf "Last 30 days:  %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_MONTH_OPEN}" "${HISTORY_MONTH_COMMENTED}" "${HISTORY_MONTH_CLOSED}" "${HISTORY_MONTH_CLOSED_WITH_COMMENT}" "${HISTORY_MONTH_REOPENED}"
 printf "Last day:      %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_DAY_OPEN}" "${HISTORY_DAY_COMMENTED}" "${HISTORY_DAY_CLOSED}" "${HISTORY_DAY_CLOSED_WITH_COMMENT}" "${HISTORY_DAY_REOPENED}"
 I=2013
 CURRENT_YEAR=$(date +%Y)
 while [[ "${I}" -le "${CURRENT_YEAR}" ]]; do
  __showActivityYearCountries "${I}"
  I=$((I + 1))
  # TODO Top 10 Notas con más comentarios por año.
  # TODO Top 10 Notas con más reopening por año.
 done
 echo "Historically:"
 echo "Users creating notes: ${USERS_OPENING}"
 echo "Users closing notes: ${USERS_CLOSING}"
 I=2013
 CURRENT_YEAR=$(date +%Y)
 while [[ "${I}" -le "${CURRENT_YEAR}" ]]; do
  __showRankingYearCountries "${I}"
  I=$((I + 1))
 done
}

# Shows general stats about notes.
function __generalNoteStats {
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
 echo "ToDo Top 10 Notes with most comments por cada año desde 2013"
 echo "ToDo Top 10 Notes with most reopenings (guerra)"
 echo "ToDo Top 10 Notes with most reopenings por cada año desde 2013 (guerra)"
 echo "ToDo Nota más vieja disponible (no oculta)"
 echo "ToDo Nota más recientemente abierta"
 echo "ToDo Notas creadas hoy"
 echo "ToDo Notas creadas este mes"
 echo "ToDo Notas creadas este año"
 echo "ToDo Promedio de creación de notas diario para cada año"
 echo "ToDo Promedio de cerrado de notas diario para cada año"
 echo "ToDo Promedio de creación de notas mensual para cada año"
 echo "ToDo Promedio de cerrado de notas mensual para cada año"
 echo "ToDo Promedio de creación de notas anual para cada año"
 echo "ToDo Promedio de cerrado de notas anual para cada año"
 echo "ToDo Top 10 usuarios haciendo auto guerra de abrir y cerrar"
 echo "ToDo Top 10 usuarios participando en guerra de notas"
 echo "ToDo Top 10 usuarios participando en guerra de notas por año"
 echo "ToDo Usuarios que han abierto más de 1000 notas en un día"
 echo "ToDo Usuarios que han cerrado más de 1000 notas en un día"
}

######
# MAIN

function main() {
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}"
 __logi "Processing: ${PROCESS_TYPE}"

 if [[ "${PROCESS_TYPE}" == "-h" ]] || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
 fi
 __checkPrereqs

 __logw "Starting process"
 # Sets the trap in case of any signal.
 __trapOn

 if [[ "${PROCESS_TYPE}" == "--user" ]]; then
  __getUserId
  __processUserProfile
 elif [[ "${PROCESS_TYPE}" == "--country" ]]; then
  __getCountryId
  __processCountryProfile
 elif [[ "${PROCESS_TYPE}" == "" ]]; then
  __generalNoteStats
 fi

 __logw "Ending process"
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

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
