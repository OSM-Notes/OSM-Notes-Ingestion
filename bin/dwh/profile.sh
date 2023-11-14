#!/bin/bash

# This script allows to see a user profile or a country profile. It reads all
# values from the database, from the datamart.
#
# There are 2 ways to call this script:
# * --user <UserName> : Shows the profile for the given user.
# * --country <CountryName> : Shows the profile for the given country.
# If the UserName or CountryName has spaces in the name, it should be invoked
# between double quotes.
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
# Version: 2023-11-11
declare -r VERSION="2023-11-11"

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
declare LOG_FILE
LOG_FILE="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILE

# Type of process to run in the script.
declare -r PROCESS_TYPE=${1:-}
# Argument for the process type.
declare -r ARGUMENT=${2:-}

# Username.
declare USERNAME
# User_id of the username.
declare -i USER_ID
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
 echo "This scripts shows the resulting profile for a given user or country."
 echo
 echo "There are 2 ways to call this script:"
 echo "* --user <UserName> : Shows the profile for the given user."
 echo "* --country <CountryName> : Shows the profile for the given country."
 echo "If the UserName or CountryName has spaces in the name, it should be"
 echo "invoked between double quotes. The name should match the name in"
 echo "Spanish in the database."
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
 if [[ "${PROCESS_TYPE}" == "--user" ]] \
  && [[ "${ARGUMENT}" == "" ]]; then
  __loge "ERROR: You  must a username."
  exit "${ERROR_INVALID_ARGUMENT}"
 else
  USERNAME="${ARGUMENT}"
 fi
 if [[ "${PROCESS_TYPE}" == "--country" ]] \
  && [[ "${ARGUMENT}" == "" ]]; then
  __loge "ERROR: You  must a country name."
  exit "${ERROR_INVALID_ARGUMENT}"
 else
  COUNTRY_NAME="${ARGUMENT}"
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

# Retrives the user_id from a username.
function __getUserId {
 USER_ID=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT dimension_user_id FROM dwh.datamartUsers WHERE username = '${USERNAME}'")
 if [ "${USER_ID}" == "" ]; then
  __loge "ERROR: The username \"${USERNAME}\" does not exist."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
}

# Retrives the user_id from a username.
function __getCountryId {
 COUNTRY_ID=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT dimension_country_id FROM dwh.dimension_countries 
  WHERE country_name_es = '${COUNTRY_NAME}'")
 if [ "${COUNTRY_ID}" == "" ]; then
  __loge "ERROR: The country name \"${COUNTRY_NAME}\" does not exist."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
}

function __showActivityYearUsers {
 YEAR="${1}"

 declare -i HISTORY_YEAR_OPEN
 HISTORY_YEAR_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_${YEAR}_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_COMMENTED
 HISTORY_YEAR_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_${YEAR}_commented
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_CLOSED
 HISTORY_YEAR_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_${YEAR}_closed
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_CLOSED_WITH_COMMENT
 HISTORY_YEAR_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_${YEAR}_closed_with_comment
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_REOPENED
 HISTORY_YEAR_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_${YEAR}_reopened
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 printf "${YEAR}          %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_YEAR_OPEN}" "${HISTORY_YEAR_COMMENTED}" "${HISTORY_YEAR_CLOSED}" "${HISTORY_YEAR_CLOSED_WITH_COMMENT}" "${HISTORY_YEAR_REOPENED}"
}

function __showActivityYearCountries {
 YEAR="${1}"

 declare -i HISTORY_YEAR_OPEN
 HISTORY_YEAR_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_${YEAR}_open
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_COMMENTED
 HISTORY_YEAR_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_${YEAR}_commented
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_CLOSED
 HISTORY_YEAR_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_${YEAR}_closed
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_CLOSED_WITH_COMMENT
 HISTORY_YEAR_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_${YEAR}_closed_with_comment
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_REOPENED
 HISTORY_YEAR_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_${YEAR}_reopened
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 printf "${YEAR}          %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_YEAR_OPEN}" "${HISTORY_YEAR_COMMENTED}" "${HISTORY_YEAR_CLOSED}" "${HISTORY_YEAR_CLOSED_WITH_COMMENT}" "${HISTORY_YEAR_REOPENED}"
}

function __processUserProfile {
 # Quantity of days creating notes.
 declare -i QTY_DAYS_OPEN
 QTY_DAYS_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT CURRENT_DATE - date_starting_creating_notes
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i DATE_FIRST_OPEN
 DATE_FIRST_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT date_starting_creating_notes
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Quantity of days solving notes.
 declare -i QTY_DAYS_CLOSE
 QTY_DAYS_CLOSE=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT CURRENT_DATE - date_starting_solving_notes
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i DATE_FIRST_CLOSE
 DATE_FIRST_CLOSE=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT date_starting_solving_notes
     FROM dwh.datamartUsers
     WHERE dimension_user_id = ${USER_ID}
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

 # Type of contributor.
 declare CONTRIBUTOR_TYPE
 CONTRIBUTOR_TYPE=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT contributor_type_name
     FROM dwh.datamartUsers u
      JOIN dwh.contributor_types t
      ON u.id_contributor_type = t.contributor_type_id
     WHERE dimension_user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Last activity year.
 declare LAST_ACTIVITY_YEAR
 LAST_ACTIVITY_YEAR=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT last_year_activity
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Last year's ations. TODO
 declare LAST_YEAR_ACTIONS
 LAST_YEAR_ACTIONS="TODO" #$(psql -d "${DBNAME}" -Atq \
 #   -c "SELECT get_last_year_actions_user(${USER_ID})
 #    " \
 #   -v ON_ERROR_STOP=1 )

 # Most recent actions.
 declare -i LAST_OPEN_NOTE_ID
 LAST_OPEN_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT lastest_open_note_id
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i LAST_COMMENTED_NOTE_ID
 LAST_COMMENTED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT lastest_commented_note_id
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i LAST_CLOSED_NOTE_ID
 LAST_CLOSED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT lastest_closed_note_id
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i LAST_REOPENED_NOTE_ID
 LAST_REOPENED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT lastest_reopened_note_id
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Date with more opened notes TODO retrieve a JOSN with 10 ten
 declare DATE_MOST_OPEN
 DATE_MOST_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT date_most_open
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )
 declare DATE_MOST_OPEN_QTY
 DATE_MOST_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT date_most_open_qty
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
 declare DATE_MOST_CLOSED_QTY
 DATE_MOST_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT date_most_closed_qty
     FROM dwh.datamartUsers
     WHERE user_id = ${USER_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Used hashtags TODO procesar texto de notas
 declare HASHTAGS
 HASHTAGS=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT hashtags
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

 # Working hours. TODO mostrar semana
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

 declare -i HISTORY_WHOLE_CLOSED_WITH_COMMENT # TODO process text
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

 declare -i HISTORY_YEAR_CLOSED_WITH_COMMENT # TODO process text
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

 declare -i HISTORY_MONTH_CLOSED_WITH_COMMENT # TODO process text
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

 declare -i HISTORY_DAY_CLOSED_WITH_COMMENT # TODO process text
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
 
# # Ranking historic # TODO
# declare RANKING_HISTORIC_OPEN
# RANKING_HISTORIC_OPEN=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_historic
#      WHERE action = 'opened'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# declare RANKING_HISTORIC_COMMENTED
# RANKING_HISTORIC_COMMENTED=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_historic
#      WHERE action = 'commented'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# declare RANKING_HISTORIC_CLOSED
# RANKING_HISTORIC_CLOSED=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_historic
#      WHERE action = 'closed'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# declare RANKING_HISTORIC_REOPENED
# RANKING_HISTORIC_REOPENED=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_historic
#      WHERE action = 'reopened'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# # Ranking year #TODO
# declare RANKING_YEAR_OPEN
# RANKING_YEAR_OPEN=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_year
#      WHERE action = 'opened'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# declare RANKING_YEAR_COMMENTED
# RANKING_YEAR_COMMENTED=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_year
#      WHERE action = 'commented'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# declare RANKING_YEAR_CLOSED
# RANKING_YEAR_CLOSED=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_year
#      WHERE action = 'closed'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# declare RANKING_YEAR_REOPENED
# RANKING_YEAR_REOPENED=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_year
#      WHERE action = 'reopened'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# # Ranking month #TODO
# declare RANKING_MONTH_OPEN
# RANKING_MONTH_OPEN=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_month
#      WHERE action = 'opened'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# declare RANKING_MONTH_COMMENTED
# RANKING_MONTH_COMMENTED=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_month
#      WHERE action = 'commented'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# declare RANKING_MONTH_CLOSED
# RANKING_MONTH_CLOSED=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_month
#      WHERE action = 'closed'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# declare RANKING_MONTH_REOPENED
# RANKING_MONTH_REOPENED=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_month
#      WHERE action = 'reopened'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# # Ranking day #TODO
# declare RANKING_DAY_OPEN
# RANKING_DAY_OPEN=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_day
#      WHERE action = 'opened'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# declare RANKING_DAY_COMMENTED
# RANKING_DAY_COMMENTED=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_day
#      WHERE action = 'commented'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# declare RANKING_DAY_CLOSED
# RANKING_DAY_CLOSED=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_day
#      WHERE action = 'closed'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )
#
# declare RANKING_DAY_REOPENED
# RANKING_DAY_REOPENED=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT position, id_country
#      FROM dwh.ranking_day
#      WHERE action = 'reopened'
#      AND id_user = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )

 # Badges. TODO
 declare BADGES
# BADGES=$(psql -d "${DBNAME}" -Atq \
#    -c "SELECT b.badge_name, p.date_awarded
#     FROM dwh.badges_per_users p
#      JOIN dwh.badges b
#      ON p.id_badge = b.badge_id
#     WHERE dimension_user_id = ${USER_ID}
#     " \
#    -v ON_ERROR_STOP=1 )

# TODO si cero, ocultar
 echo "User name: ${USERNAME} (id: ${USER_ID})"
 echo "Note solver type: ${CONTRIBUTOR_TYPE}"
 echo "Quantity of days creating notes: ${QTY_DAYS_OPEN}, since ${DATE_FIRST_OPEN}."
 echo "Quantity of days solving notes: ${QTY_DAYS_CLOSE}, since ${DATE_FIRST_CLOSE}"
 echo "First actions: https://www.openstreetmap.org/note/${FIRST_OPEN_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_COMMENTED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_CLOSED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_REOPENED_NOTE_ID}"
 echo "Last actions:  https://www.openstreetmap.org/note/${LAST_OPEN_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_COMMENTED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_CLOSED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_REOPENED_NOTE_ID}"
 echo "Last activity year: ${LAST_ACTIVITY_YEAR}"
 echo "Last year actions: ${LAST_YEAR_ACTIONS}" # TODO
 echo "The date when the most notes were opened: ${DATE_MOST_OPEN} (${DATE_MOST_OPEN_QTY})"
 echo "The date when the most notes were closed: ${DATE_MOST_CLOSED} (${DATE_MOST_CLOSED_QTY})"
 echo "Hashtags used: ${HASHTAGS}" # TODO
 echo "Countries for open notes: ${COUNTRIES_OPENING}"
 echo "Countries for closed notes: ${COUNTRIES_CLOSING}"
 echo "Working hours: Opening ${WORKING_HOURS_OPENING} Commenting ${WORKING_HOURS_COMMENTING} Closing ${WORKING_HOURS_CLOSING}" # Mostrar semana
#                       1234567890 1234567890 1234567890 1234567890 1234567890
 printf "                 Opened   Commented  Closed     Cld w/cmmt Reopened\n"
 printf "Total:         %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_WHOLE_OPEN}" "${HISTORY_WHOLE_COMMENTED}" "${HISTORY_WHOLE_CLOSED}" "${HISTORY_WHOLE_CLOSED_WITH_COMMENT}" "${HISTORY_WHOLE_REOPENED}"
 printf "Last 365 year: %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_YEAR_OPEN}" "${HISTORY_YEAR_COMMENTED}" "${HISTORY_YEAR_CLOSED}" "${HISTORY_YEAR_CLOSED_WITH_COMMENT}" "${HISTORY_YEAR_REOPENED}"
 printf "Last 30 days:  %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_MONTH_OPEN}" "${HISTORY_MONTH_COMMENTED}" "${HISTORY_MONTH_CLOSED}" "${HISTORY_MONTH_CLOSED_WITH_COMMENT}" "${HISTORY_MONTH_REOPENED}"
 printf "Last day      %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_DAY_OPEN}" "${HISTORY_DAY_COMMENTED}" "${HISTORY_DAY_CLOSED}" "${HISTORY_DAY_CLOSED_WITH_COMMENT}" "${HISTORY_DAY_REOPENED}"
 I=2013
 CURRENT_YEAR=$(date +%Y)
 while [ "${I}" -le "${CURRENT_YEAR}" ]; do
  __showActivityYearUsers "${I}"
  I=$((I+1))
 done
# echo "Rankings historic       ${RANKING_HISTORIC_OPEN} ${RANKING_HISTORIC_COMMENTED} ${RANKING_HISTORIC_CLOSED} ${RANKING_HISTORIC_REOPENED}"
# echo "Rankings last 12 months ${RANKING_YEAR_OPEN} ${RANKING_YEAR_COMMENTED} ${RANKING_YEAR_CLOSED} ${RANKING_YEAR_REOPENED}"
# echo "Rankings last 30 days   ${RANKING_MONTH_OPEN} ${RANKING_MONTH_COMMENTED} ${RANKING_MONTH_CLOSED} ${RANKING_MONTH_REOPENED}"
# echo "Rankings today          ${RANKING_DAY_OPEN} ${RANKING_DAY_COMMENTED} ${RANKING_DAY_CLOSED} ${RANKING_DAY_REOPENED}"
# echo "Badges: ${BADGES}" #TODO
}

# Shows the note statistics for a given country.
function __processCountryProfile {
 # Quantity of days with open notes.
 declare -i QTY_DAYS_OPEN
 QTY_DAYS_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT CURRENT_DATE - date_starting_creating_notes
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i DATE_FIRST_OPEN
 DATE_FIRST_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT date_starting_creating_notes
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Quantity of days solving notes.
 declare -i QTY_DAYS_CLOSE
 QTY_DAYS_CLOSE=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT CURRENT_DATE - date_starting_solving_notes
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i DATE_FIRST_CLOSE
 DATE_FIRST_CLOSE=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT date_starting_solving_notes
     FROM dwh.datamartCountries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # First actions.
 declare -i FIRST_OPEN_NOTE_ID
 FIRST_OPEN_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT first_open_note_id
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i FIRST_COMMENTED_NOTE_ID
 FIRST_COMMENTED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT first_commented_note_id
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i FIRST_CLOSED_NOTE_ID
 FIRST_CLOSED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT first_closed_note_id
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i FIRST_REOPENED_NOTE_ID
 FIRST_REOPENED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT first_reopened_note_id
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Last activity year.
 declare LAST_ACTIVITY_YEAR
 LAST_ACTIVITY_YEAR=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT last_year_activity
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Last year's ations. TODO
 declare LAST_YEAR_ACTIONS
 LAST_YEAR_ACTIONS="TODO" #$(psql -d "${DBNAME}" -Atq \
 #   -c "SELECT get_last_year_actions_country(${COUNTRY_ID})
 #    " \
 #   -v ON_ERROR_STOP=1 )

 # Most recent actions.
 declare -i LAST_OPEN_NOTE_ID
 LAST_OPEN_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT lastest_open_note_id
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i LAST_COMMENTED_NOTE_ID
 LAST_COMMENTED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT lastest_commented_note_id
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i LAST_CLOSED_NOTE_ID
 LAST_CLOSED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT lastest_closed_note_id
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i LAST_REOPENED_NOTE_ID
 LAST_REOPENED_NOTE_ID=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT lastest_reopened_note_id
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Date with more opened notes TODO retrieve a JOSN with 10 ten
 declare DATE_MOST_OPEN
 DATE_MOST_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT date_most_open
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )
 declare DATE_MOST_OPEN_QTY
 DATE_MOST_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT date_most_open_qty
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Date with more closed notes
 declare DATE_MOST_CLOSED
 DATE_MOST_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT date_most_closed
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )
 declare DATE_MOST_CLOSED_QTY
 DATE_MOST_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT date_most_closed_qty
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Used hashtags TODO procesar texto de notas
 declare HASHTAGS
 HASHTAGS=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT hashtags
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Users opening notes.
 declare USERS_OPENING
 USERS_OPENING=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT countries_open_notes
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Users closing notes.
 declare USERS_CLOSING
 USERS_CLOSING=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT countries_solving_notes
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Working hours. TODO mostrar semana
 declare WORKING_HOURS_OPENING
 WORKING_HOURS_OPENING=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT working_hours_opening
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare WORKING_HOURS_COMMENTING
 WORKING_HOURS_COMMENTING=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT working_hours_commenting
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare WORKING_HOURS_CLOSING
 WORKING_HOURS_CLOSING=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT working_hours_closing
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # History values.
 # Whole history.
 declare -i HISTORY_WHOLE_OPEN
 HISTORY_WHOLE_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_whole_open
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_WHOLE_COMMENTED
 HISTORY_WHOLE_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_whole_commented
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_WHOLE_CLOSED
 HISTORY_WHOLE_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_whole_closed
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_WHOLE_CLOSED_WITH_COMMENT # TODO process text
 HISTORY_WHOLE_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_whole_closed_with_comment
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_WHOLE_REOPENED
 HISTORY_WHOLE_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_whole_reopened
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Last year history.
 declare -i HISTORY_YEAR_OPEN
 HISTORY_YEAR_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_year_open
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_COMMENTED
 HISTORY_YEAR_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_year_commented
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_CLOSED
 HISTORY_YEAR_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_year_closed
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_CLOSED_WITH_COMMENT # TODO process text
 HISTORY_YEAR_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_year_closed_with_comment
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_YEAR_REOPENED
 HISTORY_YEAR_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_year_reopened
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Last month history.
 declare -i HISTORY_MONTH_OPEN
 HISTORY_MONTH_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_month_open
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_MONTH_COMMENTED
 HISTORY_MONTH_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_month_commented
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_MONTH_CLOSED
 HISTORY_MONTH_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_month_closed
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_MONTH_CLOSED_WITH_COMMENT # TODO process text
 HISTORY_MONTH_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_month_closed_with_comment
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_MONTH_REOPENED
 HISTORY_MONTH_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_month_reopened
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 # Last day history.
 declare -i HISTORY_DAY_OPEN
 HISTORY_DAY_OPEN=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_day_open
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_DAY_COMMENTED
 HISTORY_DAY_COMMENTED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_day_commented
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_DAY_CLOSED
 HISTORY_DAY_CLOSED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_day_closed
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_DAY_CLOSED_WITH_COMMENT # TODO process text
 HISTORY_DAY_CLOSED_WITH_COMMENT=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_day_closed_with_comment
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )

 declare -i HISTORY_DAY_REOPENED
 HISTORY_DAY_REOPENED=$(psql -d "${DBNAME}" -Atq \
    -c "SELECT history_day_reopened
     FROM dwh.datamartContries
     WHERE dimension_country_id = ${COUNTRY_ID}
     " \
    -v ON_ERROR_STOP=1 )
 
# TODO si cero, ocultar
 echo "COUNTRY name: ${COUNTRY_NAME} (id: ${COUNTRY_ID})"
 echo "Quantity of days creating notes: ${QTY_DAYS_OPEN}, since ${DATE_FIRST_OPEN}."
 echo "Quantity of days solving notes: ${QTY_DAYS_CLOSE}, since ${DATE_FIRST_CLOSE}"
 echo "First actions: https://www.openstreetmap.org/note/${FIRST_OPEN_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_COMMENTED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_CLOSED_NOTE_ID} https://www.openstreetmap.org/note/${FIRST_REOPENED_NOTE_ID}"
 echo "Last actions:  https://www.openstreetmap.org/note/${LAST_OPEN_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_COMMENTED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_CLOSED_NOTE_ID}  https://www.openstreetmap.org/note/${LAST_REOPENED_NOTE_ID}"
 echo "Last activity year: ${LAST_ACTIVITY_YEAR}"
 echo "Last year actions: ${LAST_YEAR_ACTIONS}" # TODO
 echo "The date when the most notes were opened: ${DATE_MOST_OPEN} (${DATE_MOST_OPEN_QTY})"
 echo "The date when the most notes were closed: ${DATE_MOST_CLOSED} (${DATE_MOST_CLOSED_QTY})"
 echo "Hashtags used: ${HASHTAGS}" # TODO
 echo "Users creating notes: ${COUNTRIES_OPENING}"
 echo "Users closing notes: ${COUNTRIES_CLOSING}"
 echo "Working hours: Opening ${WORKING_HOURS_OPENING} Commenting ${WORKING_HOURS_COMMENTING} Closing ${WORKING_HOURS_CLOSING}" # Mostrar semana
#                       1234567890 1234567890 1234567890 1234567890 1234567890
 printf "                 Opened   Commented  Closed     Cld w/cmmt Reopened\n"
 printf "Total:         %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_WHOLE_OPEN}" "${HISTORY_WHOLE_COMMENTED}" "${HISTORY_WHOLE_CLOSED}" "${HISTORY_WHOLE_CLOSED_WITH_COMMENT}" "${HISTORY_WHOLE_REOPENED}"
 printf "Last 365 year: %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_YEAR_OPEN}" "${HISTORY_YEAR_COMMENTED}" "${HISTORY_YEAR_CLOSED}" "${HISTORY_YEAR_CLOSED_WITH_COMMENT}" "${HISTORY_YEAR_REOPENED}"
 printf "Last 30 days:  %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_MONTH_OPEN}" "${HISTORY_MONTH_COMMENTED}" "${HISTORY_MONTH_CLOSED}" "${HISTORY_MONTH_CLOSED_WITH_COMMENT}" "${HISTORY_MONTH_REOPENED}"
 printf "Last day      %9d  %9d  %9d  %9d  %9d\n" "${HISTORY_DAY_OPEN}" "${HISTORY_DAY_COMMENTED}" "${HISTORY_DAY_CLOSED}" "${HISTORY_DAY_CLOSED_WITH_COMMENT}" "${HISTORY_DAY_REOPENED}"
 I=2013
 CURRENT_YEAR=$(date +%Y)
 while [ "${I}" -le "${CURRENT_YEAR}" ]; do
  __showActivityYearCountries "${I}"
  I=$((I+1))
 done
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

 if [[ "${PROCESS_TYPE}" == "--user" ]] ; then
  __getUserId
  __processUserProfile
 elif [[ "${PROCESS_TYPE}" == "--country" ]] ; then
 __getCountryId
  __processCountryProfile
 fi

 __logw "Ending process"
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [ ! -t 1 ] ; then
 __set_log_file "${LOG_FILENAME}"
 main >> "${LOG_FILENAME}"
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]] ; then
  mv "${LOG_FILE}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
  rmdir "${TMP_DIR}"
 fi
else
 main
fi

