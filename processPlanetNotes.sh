#!/bin/bash

# This script prepares a database for note analysis, and loads the notes from
# the planet, completely or the missing ones. Depending on the invokation it
# performs some tasks.
# The script structure is:
# * Creates the database structure.
# * Downloads the list of country ids (overpass).
# * Downloads the country boundaries (overpass).
# * Downloads the list of maritime area ids (overpass).
# * Downloads the maritime area boundaries (overpass).
# * Imports the boundaries into the db.
# * Downloads the planet notes.
# * Converts the notes into flat CSV files.
# * Imports the notes into the db.
# * Sets the order for countries by zones.
# * Creates a function to get the country of a position using the order by
#   zones.
# * Runs the function against all notes.
#
# Globally there are two workflows:
#
# * base > sync (This workflow is called from processApiNotes)
# * base > flatfile > locatenotes > sync (if there is not enough memory for the
#   other workflow, this can be used with 2 computers)
#
# These are some examples to call this script:
#
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/processPlanetNotes.sh --base
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/processPlanetNotes.sh
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/processPlanetNotes.sh --flatfile
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/processPlanetNotes.sh --locatenotes ~/OSM-Notes-profile/output-notes.csv ~/OSM-Notes-profile/output-note_comments.csv
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/processPlanetNotes.sh --boundaries
#
# The design of this architecture is at: https://miro.com/app/board/uXjVPDTbDok=/
#
# If the download fails with "Too many requests", you can check this page:
# http://overpass-api.de/api/status and increase the sleep time between loops.
# There is a variable for this: SECONDS_TO_WAIT.
#
# Known errors:
# * Austria has an issue to be imported with ogr2ogr for a particular thing in
#   the geometry. A simplification is done to upload it. However, there is a
#   missing part not being imported.
# * Taiwan has an issue to be imported with ogr2ogr for a very long row. Some
#   fields are removed.
# * The Gaza Strip is not at the same level as a country. The ID is hardcoded.
# * Not all countries have defined the maritimes borders. Also, not all
#   countries have signed the Covemar.
#
# The following files are necessary to prepare the environment.
# https://github.com/tyrasd/osmtogeojson
# npm install -g osmtogeojson
# https://sourceforge.net/projects/saxon/files/Saxon-HE/11/Java/SaxonHE11-4J.zip/download
#
# When running under MacOS or zsh, it is better to invoke bash:
# bash ./processPlanetNotes.sh
#
# To follow the progress you can execute:
#   tail -40f $(ls -1rtd /tmp/processPlanetNotes_* | tail -1)/processPlanetNotes.log
#
# You need to create a database called 'notes':
#   CREATE DATABASE notes;
# You need to install postgis and add the extension:
#   CREATE EXTENSION postgis;
# You also need to log into the database with the current user ${USER}
#   createuser myuser
#   CREATE ROLE myuser WITH LOGIN
# You need to check the access to PostgreSQL with the following without
# password:
#   psql -d notes
# This could be an option:
#   export PGPASSWORD='password'
# Or change the pg_hba.conf file.
# Also you need to give permissions to create objects in public schema:
#   GRANT USAGE ON SCHEMA public TO myuser
#
# To specify the Saxon location, you can put this file in the same directory as
# saxon ; otherwise, it will this location:
#   export SAXON_CLASSPATH=~/saxon/
#
# Some interesting queries to track the process:
#
# select country_name_en, americas, europe, russia_middle_east, asia_oceania
# from countries
# order by americas nulls last, europe nulls last,
#  russia_middle_east nulls last, asia_oceania nulls last;
#
# The most iterations to find an area.
# select iter, country_name_en, count(1)
# from tries t join countries c
# on (t.id_country = c.country_id)
# group by iter, country_name_en
# order by iter desc, count(1) desc;
#
# Details of the iteration.
# select t.*, country_name_en
# from tries t join countries c on (t.id_country = c.country_id)
# where iter = 121;
#
# How many iterations per region to find the appropriate area.
# This allows to reorganize the updates of the organizeAreas function.
# select iter, count(1), area, country_name_en
# from tries t join countries c
# on t.id_country = c.country_id
# group by iter, area, country_name_en
# order by area, count(1) desc;
#
# Sections per parameter:
#                       	        empty	base	locate	bounda	flatfile
#                                       (sync)          notes   ries
# __dropSyncTables              	 	x
# __dropApiTables               		x
# __dropBaseTables              		x
# __dropSyncTables              	x	 	x
# __checkBaseTables             	x		x
# __createBaseTables             	x	x	x
# __createSyncTables            	x		x
# __dropCountryTables 	                	x		x
# __createCountryTables         		x		x
# __processCountries             		x		x
# __processMaritimes             		x		x
# __cleanPartial                		x		x
# __downloadPlanetNotes          	x				x
# __validatePlanetNotesXMLFile         	x				x
# __convertPlanetNotesToFlatFile 	x				x
# __createsFunctionToGetCountry 	x	x	x
# __createsProcedures                 	x	x	x
# __analyzeAndVacuum                 	x	x	x
# __copyFlatFiles                 			x
# __loadSyncNotes                 	x		x
# __removeDuplicates                 	x		x
# __dropSyncTables                 	x		x
# __organizeAreas                 	x		x
# __getLocationNotes                 	x		x
# __cleanNotesFiles                   	x	x	x
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
# 244) The list of ids for boundary geometries can not be downloaded.
# 245) Error downloading planet notes file.
#
# For contributing, please execute these commands before subimitting:
# * shellcheck -x -o all processPlanetNotes.sh
# * shfmt -w -i 1 -sr -bn processPlanetNotes.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2023-10-10
declare -r VERSION="2023-10-10"

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
# 244: The list of ids for boundary geometries can not be downloaded.
declare -r ERROR_DOWNLOADING_ID_LIST=244

# If all files should be deleted. In case of an error, this could be disabled.
# You can defined when calling: export CLEAN=false
declare -r CLEAN=${CLEAN:-true}

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL.
declare LOG_LEVEL="${LOG_LEVEL:-ERROR}"

# Base directory, where the script resides.
# Taken from https://stackoverflow.com/questions/59895/how-can-i-get-the-source-directory-of-a-bash-script-from-within-the-script-itsel
# shellcheck disable=SC2155
declare -r SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" \
 &> /dev/null && pwd)"

# Loads the global properties.
source "${SCRIPT_BASE_DIRECTORY}/properties.sh"

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
# Log file for output.
declare LOG_FILENAME
LOG_FILENAME="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILENAME

# Lock file for single execution.
declare LOCK
LOCK="/tmp/${BASENAME}.lock"
readonly LOCK

# Type of process to run in the script.
declare -r PROCESS_TYPE=${1:-}

# Flat file to start from load.
declare -r FLAT_NOTES_FILE=${2:-}
declare -r FLAT_NOTE_COMMENTS_FILE=${3:-}

# Wait between loops when downloading boundaries, to prevent "Too many
# requests".
declare -r SECONDS_TO_WAIT=3

# File that contains the ids of the boundaries for countries.
declare -r COUNTRIES_FILE="${TMP_DIR}/countries"
# File taht contains the ids of the boundaries of the maritimes areas.
declare -r MARITIMES_FILE="${TMP_DIR}/maritimes"
# File for the Overpass query.
declare -r QUERY_FILE="${TMP_DIR}/query"

# Name of the file to download.
declare -r PLANET_NOTES_NAME="planet-notes-latest.osn"
# Filename fot the OSM Notes from Planet.
declare -r PLANET_NOTES_FILE="${TMP_DIR}/${PLANET_NOTES_NAME}"

# XML Schema of the Planet notes file.
declare -r XMLSCHEMA_PLANET_NOTES="${TMP_DIR}/OSM-notes-planet-schema.xsd"
# Jar name of the XSLT processor.
declare SAXON_JAR
set +ue
SAXON_JAR="$(find "${SAXON_CLASSPATH:-.}" -maxdepth 1 -type f -name "saxon-he-*.*.jar" | grep -v test | grep -v xqj | head -1)"
set -ue
readonly SAXON_JAR
# Name of the file of the XSLT transformation for notes.
declare -r XSLT_NOTES_FILE="${TMP_DIR}/notes-csv.xslt"
# Name of the file of the XSLT transformation for note comments.
declare -r XSLT_NOTE_COMMENTS_FILE="${TMP_DIR}/note_comments-csv.xslt"
# Filename for the flat file for notes.
declare -r OUTPUT_NOTES_FILE="${TMP_DIR}/output-notes.csv"
# Filename for the flat file for comment notes.
declare -r OUTPUT_NOTE_COMMENTS_FILE="${TMP_DIR}/output-note_comments.csv"

# Last note id file.
declare -r LAST_NOTE_FILE="${TMP_DIR}/lastNote.xml"
# Quantity of notes to process per loop.
declare -r LOOP_SIZE="${LOOP_SIZE:-10000}"
# Parallel threads to process notes.
declare -r PARALLELISM="${PARALLELISM:-5}"

###########
# FUNCTIONS

source "${SCRIPT_BASE_DIRECTORY}/functionsProcess.sh"
# __start_logger
# __trapOn
# __checkBaseTables
# __downloadPlanetNotes
# __validatePlanetNotesXMLFile
# __convertPlanetNotesToFlatFile
# __createsFunctionToGetCountry
# __createsProcedures

# Shows the help information.
function __show_help {
 echo "${BASENAME} version ${VERSION}"
 echo "This is a script that downloads the OSM notes from the Planet,"
 echo "processes them with a XSLT transformation, to create a flat file,"
 echo "and finally it uploads them into a PostgreSQL database."
 echo
 echo "It could receive one of these parameters:"
 echo " * --base : to starts from scratch from Planet notes file, including the"
 echo "     boundaries."
 echo " * --boundaries : processes the countries and maritimes areas only."
 echo " * --flatfile : converts the planet file into a flat csv file."
 echo " * --locatenotes <flatNotesfile> <flatNoteCommentsfile> : takes the flat"
 echo "     files, import them and finally locate the notes."
 echo " * Without parameter, it processes the new notes from Planet notes file."
 echo
 echo "Flatfile option is useful when the regular machine does not have enough"
 echo "memory to process the notes file. Normally it needs 6 GB for Java."
 echo "LocateNotes is useful to continue from the flat file."
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--base" ]] \
  && [[ "${PROCESS_TYPE}" != "--boundaries" ]] \
  && [[ "${PROCESS_TYPE}" != "--flatfile" ]] \
  && [[ "${PROCESS_TYPE}" != "--locatenotes" ]] \
  && [[ "${PROCESS_TYPE}" != "--help" ]] \
  && [[ "${PROCESS_TYPE}" != "-h" ]]; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --base"
  echo " * --boundaries"
  echo " * --flatfile"
  echo " * --help"
  echo " * --locatenotes"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 if [[ "${PROCESS_TYPE}" == "--locatenotes" ]] \
  && [[ "${FLAT_NOTES_FILE}" == "" ]]; then
  __loge "ERROR: You  must specify a flat Notes CSV file to process."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 if [[ "${PROCESS_TYPE}" == "--locatenotes" ]] \
  && [[ "${FLAT_NOTE_COMMENTS_FILE}" == "" ]]; then
  __loge "ERROR: You  must specify a flat Note Comments CSV file to process."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set +e
 # Checks prereqs.
 if [[ "${PROCESS_TYPE}" != "--flatfile" ]]; then
  ## PostgreSQL
  if ! psql --version > /dev/null 2>&1; then
   __loge "ERROR: PostgreSQL is missing."
   exit "${ERROR_MISSING_LIBRARY}"
  fi
  ## PostGIS
  psql -d "${DBNAME}" -v ON_ERROR_STOP=1 > /dev/null 2>&1 << EOF
  SELECT PostGIS_version();
EOF
  RET=${?}
  if [[ "${RET}" -ne 0 ]]; then
   __loge "ERROR: PostGIS is missing."
   exit "${ERROR_MISSING_LIBRARY}"
  fi
  ## Wget
  if ! wget --version > /dev/null 2>&1; then
   __loge "ERROR: Wget is missing."
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
 fi
 if [[ "${PROCESS_TYPE}" == "" ]] \
  || [[ "${PROCESS_TYPE}" == "--flatfile" ]]; then
  ## Block-sorting file compressor
  if ! bzip2 --help > /dev/null 2>&1; then
   __loge "ERROR: bzip2 is missing."
   exit "${ERROR_MISSING_LIBRARY}"
  fi
  ## XML lint
  if ! xmllint --version > /dev/null 2>&1; then
   __loge "ERROR: XMLlint is missing."
   exit "${ERROR_MISSING_LIBRARY}"
  fi
  ## Java
  if ! java --version > /dev/null 2>&1; then
   __loge "ERROR: Java JRE is missing."
   exit "${ERROR_MISSING_LIBRARY}"
  fi
  ## Saxon Jar
  if [[ ! -r "${SAXON_JAR}" ]]; then
   __loge "ERROR: Saxon jar is missing at ${SAXON_JAR}."
   exit "${ERROR_MISSING_LIBRARY}"
  fi
  if ! java -cp "${SAXON_JAR}" net.sf.saxon.Transform -? > /dev/null 2>&1; then
   __loge "ERROR: Saxon jar is missing at ${SAXON_JAR}."
   exit "${ERROR_MISSING_LIBRARY}"
  fi
 fi
 ## Bash 4 or greater.
 if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  __loge "ERROR: Requires Bash 4+."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks if the flat file exist.
 if [[ "${FLAT_NOTES_FILE}" != "" ]] && [[ ! -r "${FLAT_NOTES_FILE}" ]]; then
  __loge "ERROR: The flat file cannot be accessed: ${FLAT_NOTES_FILE}."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 ## Checks the flat file if exist.
 if [[ "${FLAT_NOTE_COMMENTS_FILE}" != "" ]] \
  && [[ ! -r "${FLAT_NOTE_COMMENTS_FILE}" ]]; then
  __loge "ERROR: The flat file cannot be accessed: ${FLAT_NOTE_COMMENTS_FILE}."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 __log_finish
 set -e
}

# Drop existing base tables.
function __dropCountryTables {
 __log_start
 __logi "Droping country tables."
 psql -d "${DBNAME}" << EOF
  DROP TABLE IF EXISTS tries;
  DROP TABLE IF EXISTS countries;
EOF
 __log_finish
}

# Drop existing base tables.
function __dropBaseTables {
 __log_start
 __logi "Droping base tables."
 psql -d "${DBNAME}" << EOF
  DROP FUNCTION IF EXISTS get_country;
  DROP PROCEDURE IF EXISTS insert_note_comment;
  DROP PROCEDURE IF EXISTS insert_note;
  DROP TABLE IF EXISTS note_comments_check;
  DROP TABLE IF EXISTS notes_check;
  DROP TABLE IF EXISTS note_comments;
  DROP TABLE IF EXISTS notes;
  DROP TABLE IF EXISTS users;
  DROP TABLE IF EXISTS logs;
  DROP TYPE note_event_enum;
  DROP TYPE note_status_enum;
EOF
 __log_finish
}

# Drop sync tables.
function __dropSyncTables {
 __log_start
 __logi "Droping sync tables."
 psql -d "${DBNAME}" << EOF
  DROP TABLE IF EXISTS note_comments_sync;
  DROP TABLE IF EXISTS notes_sync;
EOF
 __log_finish
}

# Drop tables for notes from API.
function __dropApiTables {
 __log_start
 __logi "Droping api tables."
 psql -d "${DBNAME}" << EOF
  DROP TABLE IF EXISTS note_comments_api;
  DROP TABLE IF EXISTS notes_api;
EOF
 __log_finish
}

# Creates base tables that hold the whole history.
function __createCountryTables {
 __log_start
 __logi "Creating tables"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  CREATE TABLE countries (
   country_id INTEGER NOT NULL,
   country_name VARCHAR(100) NOT NULL,
   country_name_es VARCHAR(100),
   country_name_en VARCHAR(100),
   geom GEOMETRY NOT NULL,
   americas INTEGER,
   europe INTEGER,
   russia_middle_east INTEGER,
   asia_oceania INTEGER
  );

  ALTER TABLE countries
   ADD CONSTRAINT pk_countries
   PRIMARY KEY (country_id);

  CREATE TABLE tries (
   area VARCHAR(20),
   iter INTEGER,
   id_note INTEGER,
   id_country INTEGER
  );
EOF
 __log_finish
}

# Creates base tables that hold the whole history.
function __createBaseTables {
 __log_start
 __logi "Creating tables"
 psql -d "${DBNAME}" << EOF
  CREATE TYPE note_status_enum AS ENUM (
    'open',
    'close',
    'hidden'
    );

  CREATE TYPE note_event_enum AS ENUM (
   'opened',
   'closed',
   'reopened',
   'commented',
   'hidden'
   );
EOF

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  CREATE TABLE IF NOT EXISTS notes (
   note_id INTEGER NOT NULL, -- id
   latitude DECIMAL NOT NULL,
   longitude DECIMAL NOT NULL,
   created_at TIMESTAMP NOT NULL,
   status note_status_enum,
   closed_at TIMESTAMP,
   id_country INTEGER,
   conflict VARCHAR(50)
  );

  CREATE TABLE IF NOT EXISTS users(
   user_id INTEGER NOT NULL,
   username VARCHAR(256) NOT NULL
  );

  CREATE TABLE IF NOT EXISTS note_comments (
   note_id INTEGER NOT NULL,
   event note_event_enum NOT NULL,
   created_at TIMESTAMP NOT NULL,
   id_user INTEGER,
   conflict VARCHAR(50)
  );

  CREATE TABLE IF NOT EXISTS logs (
   timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
   message VARCHAR(1000)
  );

  CREATE INDEX IF NOT EXISTS notes_closed ON notes (closed_at);
  CREATE INDEX IF NOT EXISTS notes_created ON notes (created_at);
  CREATE INDEX IF NOT EXISTS notes_countries ON notes (id_country);
  CREATE INDEX IF NOT EXISTS note_comments_id ON note_comments (note_id);
  CREATE INDEX IF NOT EXISTS note_comments_users ON note_comments (id_user);
  CREATE INDEX IF NOT EXISTS note_comments_created ON note_comments (created_at);
EOF

 psql -d "${DBNAME}" << EOF

  ALTER TABLE notes
   ADD CONSTRAINT pk_notes
   PRIMARY KEY (note_id);

  ALTER TABLE users
   ADD CONSTRAINT pk_users
   PRIMARY KEY (user_id);

  -- ToDo primary key duplicated error. This is an API error.
  --ALTER TABLE note_comments
  -- ADD CONSTRAINT pk_note_comments
  -- PRIMARY KEY (note_id, event, created_at);

  ALTER TABLE note_comments
   ADD CONSTRAINT fk_notes
   FOREIGN KEY (note_id)
   REFERENCES notes (note_id);

  ALTER TABLE note_comments
   ADD CONSTRAINT fk_users
   FOREIGN KEY (id_user)
   REFERENCES users (user_id);

EOF
 __log_finish
}

# Creates sync tables that receives the whole history, but then keep the new
# ones.
function __createSyncTables {
 __log_start
 __logi "Creating tables"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  CREATE TABLE notes_sync (
   LIKE notes
  );

  CREATE TABLE note_comments_sync (
   LIKE note_comments
  );

  ALTER TABLE note_comments_sync ADD COLUMN username VARCHAR(256);
EOF
 __log_finish
}

# Download the list of countries, then it downloads each country individually,
# converts the OSM JSON into a GeoJSON, and then it inserts the geometry of the
# country into the Postgres database with ogr2ogr.
function __processCountries {
 __log_start
 echo "TRUNCATE TABLE countries" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

 # Extracts ids of all country relations into a JSON.
 __logi "Obtaining the countries ids."
 cat << EOF > "${QUERY_FILE}"
  [out:csv(::id)];
  (
    relation["type"="boundary"]["boundary"="administrative"]["admin_level"="2"];
  );
  out ids;
EOF

 set +e
 wget -O "${COUNTRIES_FILE}" --post-file="${QUERY_FILE}" "${OVERPASS_INTERPRETER}"
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: Country list could not be downloaded."
  exit "${ERROR_DOWNLOADING_ID_LIST}"
 fi

 tail -n +2 "${COUNTRIES_FILE}" > "${COUNTRIES_FILE}.tmp"
 mv "${COUNTRIES_FILE}.tmp" "${COUNTRIES_FILE}"

 # Areas not at country level.
 {
  # Adds the Gaza Strip
  echo "1703814"
  # Adds Judea and Samaria.
  echo "1803010"
  # Adds the Buthan - China dispute.
  echo "12931402"
  # Adds Ilemi Triangle
  echo "192797"
  # Adds Neutral zone Burkina Faso - Benin
  echo "12940096"
  # Adds Bir Tawil
  echo "3335661"
  # Adds Jungholz, Austria
  echo "37848"
  # Adds Antarctica areas
  echo "3394112" # British Antarctic
  echo "3394110" # Argentine Antarctic
  echo "3394115" # Chilean Antarctic
  echo "3394113" # Ross dependency
  echo "3394111" # Australian Antarctic
  echo "3394114" # Adelia Land
  echo "3245621" # Queen Maud Land
  echo "2955118" # Peter I Island
  echo "2186646" # Antarctica continent
 } >> "${COUNTRIES_FILE}"

 __logi "Retrieving the countries' boundaries."
 while read -r LINE; do
  ID=$(echo "${LINE}" | awk '{print $1}')
  JSON_FILE="${TMP_DIR}/${ID}.json"
  GEOJSON_FILE="${TMP_DIR}/${ID}.geojson"
  __logi "ID: ${ID}"
  cat << EOF > "${QUERY_FILE}"
   [out:json];
   rel(${ID});
   (._;>;);
   out;
EOF
  __logi "Retrieving shape."
  wget -O "${JSON_FILE}" --post-file="${QUERY_FILE}" "${OVERPASS_INTERPRETER}"

  __logi "Converting into geoJSON."
  osmtogeojson "${JSON_FILE}" > "${GEOJSON_FILE}"
  set +e
  set +o pipefail
  COUNTRY=$(grep "\"name\":" "${GEOJSON_FILE}" | head -1 \
   | awk -F\" '{print $4}' | sed "s/'/''/")
  COUNTRY_ES=$(grep "\"name:es\":" "${GEOJSON_FILE}" | head -1 \
   | awk -F\" '{print $4}' | sed "s/'/''/")
  COUNTRY_EN=$(grep "\"name:en\":" "${GEOJSON_FILE}" | head -1 \
   | awk -F\" '{print $4}' | sed "s/'/''/")
  set -o pipefail
  set -e
  __logi "Name: ${COUNTRY_EN}"

  # Taiwan cannot be imported directly. Thus, a simplification is done.
  # ERROR:  row is too big: size 8616, maximum size 8160
  grep -v "official_name" "${GEOJSON_FILE}" \
   | grep -v "alt_name" > "${GEOJSON_FILE}-new"
  mv "${GEOJSON_FILE}-new" "${GEOJSON_FILE}"

  __logi "Importing into Postgres."
  ogr2ogr -f "PostgreSQL" PG:"dbname=${DBNAME} user=${USER}" "${GEOJSON_FILE}" \
   -nln import -overwrite

  __logi "Inserting into final table."
  if [[ "${ID}" -ne 16239 ]]; then
   STATEMENT="INSERT INTO countries (country_id, country_name, country_name_es,
     country_name_en, geom) select ${ID}, '${COUNTRY}', '${COUNTRY_ES}',
     '${COUNTRY_EN}', ST_Union(ST_makeValid(wkb_geometry))
     from import group by 1"
  else # This case is for Austria.
   # GEOSUnaryUnion: TopologyException: Input geom 1 is invalid:
   # Self-intersection at or near point 10.454439900000001 47.555796399999998
   # at 10.454439900000001 47.555796399999998
   STATEMENT="INSERT INTO countries (country_id, country_name, country_name_es,
     country_name_en, geom) select ${ID}, '${COUNTRY}', '${COUNTRY_ES}',
     '${COUNTRY_EN}', ST_Union(ST_Buffer(wkb_geometry,0.0))
     from import group by 1"
  fi
  __logd "${STATEMENT}"
  echo "${STATEMENT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

  if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
   rm -f "${JSON_FILE}" "${GEOJSON_FILE}"
  fi
  __logi "Waiting ${SECONDS_TO_WAIT} seconds..."
  sleep "${SECONDS_TO_WAIT}"
 done < "${COUNTRIES_FILE}"
 __log_finish
}

# Download the list of maritimes areas, then it downloads each area
# individually, converts the OSM JSON into a GeoJSON, and then it inserts the
# geometry of the maritime area into the Postgres database with ogr2ogr.
function __processMaritimes {
 __log_start
 # Extracts ids of all EEZ relations into a JSON.
 __logi "Obtaining the eez ids."
 cat << EOF > "${QUERY_FILE}"
  [out:csv(::id)];
  (
    relation["border_type"]["border_type"~"contiguous|eez"];
  );
  out ids;
EOF

 set +e
 wget -O "${MARITIMES_FILE}" --post-file="${QUERY_FILE}" "${OVERPASS_INTERPRETER}"
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: Maritimes border list could not be downloaded."
  exit "${ERROR_DOWNLOADING_ID_LIST}"
 fi

 tail -n +2 "${MARITIMES_FILE}" > "${MARITIMES_FILE}.tmp"
 mv "${MARITIMES_FILE}.tmp" "${MARITIMES_FILE}"

 __logi "Retrieving the maritimes' boundaries."
 while read -r LINE; do
  ID=$(echo "${LINE}" | awk '{print $1}')
  JSON_FILE="${TMP_DIR}/${ID}.json"
  GEOJSON_FILE="${TMP_DIR}/${ID}.geojson"
  __logi "ID: ${ID}"
  cat << EOF > "${QUERY_FILE}"
   [out:json];
   rel(${ID});
   (._;>;);
   out;
EOF
  __logi "Retrieving shape."
  wget -O "${JSON_FILE}" --post-file="${QUERY_FILE}" "${OVERPASS_INTERPRETER}"

  __logi "Converting into geoJSON."
  osmtogeojson "${JSON_FILE}" > "${GEOJSON_FILE}"
  set +e
  set +o pipefail
  NAME=$(grep "\"name\":" "${GEOJSON_FILE}" | head -1 \
   | awk -F\" '{print $4}' | sed "s/'/''/")
  NAME_ES=$(grep "\"name:es\":" "${GEOJSON_FILE}" | head -1 \
   | awk -F\" '{print $4}' | sed "s/'/''/")
  NAME_EN=$(grep "\"name:en\":" "${GEOJSON_FILE}" | head -1 \
   | awk -F\" '{print $4}' | sed "s/'/''/")
  set -o pipefail
  set -e
  __logi "Name: ${NAME_EN}"

  __logi "Importing into Postgres."
  ogr2ogr -f "PostgreSQL" PG:"dbname=${DBNAME} user=${USER}" "${GEOJSON_FILE}" \
   -nln import -overwrite

  __logi "Inserting into final table."
  STATEMENT="INSERT INTO countries (country_id, country_name, country_name_es,
    country_name_en, geom) SELECT ${ID}, '${NAME}', '${NAME_ES:-${NAME}}',
    '${NAME_EN:-${NAME}}', ST_Union(wkb_geometry) FROM import GROUP BY 1"
  __logd "${STATEMENT}"
  echo "${STATEMENT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

  if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
   rm -f "${JSON_FILE}" "${GEOJSON_FILE}"
  fi
  __logi "Waiting ${SECONDS_TO_WAIT} seconds..."
  sleep "${SECONDS_TO_WAIT}"
 done < "${MARITIMES_FILE}"

 __logi "Calculating statistics on countries"
 echo "ANALYZE countries" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
 __log_finish
}

# Clean files and tables.
function __cleanPartial {
 __log_start
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -f "${QUERY_FILE}" "${COUNTRIES_FILE}" "${MARITIMES_FILE}"
  echo "DROP TABLE IF EXISTS import" | psql -d "${DBNAME}"
 fi
 __log_finish
}

# Copies the CSV file to temporal directory.
function __copyFlatFiles {
 __log_start
 cp "${FLAT_NOTES_FILE}" "${OUTPUT_NOTES_FILE}"
 cp "${FLAT_NOTE_COMMENTS_FILE}" "${OUTPUT_NOTE_COMMENTS_FILE}"
 __log_finish
}

# Loads new notes from sync.
function __loadSyncNotes {
 __log_start
 # Loads the data in the database.
 # Adds a column to include the country where it belongs.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  TRUNCATE TABLE notes_sync;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Uploading sync notes' AS Text;
  COPY notes_sync (note_id, latitude, longitude, created_at, closed_at, status)
    FROM '${OUTPUT_NOTES_FILE}' csv;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on notes sync' as Text;
  ANALYZE notes_sync;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Counting sync notes' AS Text;
  SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1),
    'Uploaded sync notes' AS Type FROM notes_sync;

  TRUNCATE TABLE note_comments_sync;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Uploading sync comments' AS Text;
  COPY note_comments_sync(note_id, event, created_at, id_user, username)
    FROM '${OUTPUT_NOTE_COMMENTS_FILE}' csv DELIMITER ',' QUOTE '''';
  SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on comments sync' as Text;
  ANALYZE note_comments_sync;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Counting sync comments' AS Text;
  SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1),
    'Uploaded sync comments' AS Type FROM note_comments_sync;
EOF
 __log_finish
}

# Calculates statistics on all tables and vacuum.
function __analyzeAndVacuum {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  VACUUM VERBOSE;
  ANALYZE VERBOSE;
EOF
 __log_finish
}

# Removes notes and comments from the new set that are already in the database.
function __removeDuplicates {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  SELECT CURRENT_TIMESTAMP AS Processing, 'Counting notes sync' as Text;
  SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1), 'Sync notes' AS Type
    FROM notes_sync;
  SELECT CURRENT_TIMESTAMP AS Processing,
    'Deleting duplicates notes sync' as Text;
  DROP TABLE IF EXISTS notes_sync_no_duplicates;
  CREATE TABLE notes_sync_no_duplicates AS
    SELECT
     note_id,
     latitude,
     longitude,
     created_at,
     status,
     closed_at,
     id_country
    FROM notes_sync WHERE note_id IN (
      SELECT note_id FROM notes_sync s
      EXCEPT 
      SELECT note_id FROM notes);
  DROP TABLE notes_sync;
  ALTER TABLE notes_sync_no_duplicates RENAME TO notes_sync;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on notes sync' as Text;
  ANALYZE notes_sync;
  SELECT CURRENT_TIMESTAMP AS Processing,
    'Counting notes sync different' as Text;
  SELECT COUNT(1), 'Sync notes no duplicates' AS Type FROM notes_sync;

  SELECT CURRENT_TIMESTAMP AS Processing, 'Inserting sync note' AS Text;
  DO
  \$\$
  DECLARE
   r RECORD;
   closed_time VARCHAR(100);
   qty INT;
   count INT;
  BEGIN
   SELECT COUNT(1) INTO qty
   FROM notes;

   IF (qty = 0) THEN
    INSERT INTO notes (
      note_id, latitude, longitude, created_at, status, closed_at, id_country
      ) SELECT
      note_id, latitude, longitude, created_at, status, closed_at, id_country
      FROM notes_sync;
   ELSE
    count := 0;
    FOR r IN
     SELECT note_id, latitude, longitude, created_at, closed_at, status
     FROM notes_sync
    LOOP
     closed_time := 'TO_TIMESTAMP(''' || r.closed_at
       || ''', ''YYYY-MM-DD HH24:MI:SS'')';
     EXECUTE 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
       || r.longitude || ', '
       || 'TO_TIMESTAMP(''' || r.created_at || ''', ''YYYY-MM-DD HH24:MI:SS''), '
       || COALESCE (closed_time, 'NULL') || ','
       || '''' || r.status || '''::note_status_enum)';
    END LOOP;
    IF (count % 1000 = 0) THEN
     COMMIT;
    END IF;
    count := count + 1;
   END IF;
  END;
  \$\$;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on notes' as Text;
  ANALYZE notes;

  SELECT CURRENT_TIMESTAMP AS Processing, 'Counting comments sync' as Text;
  SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1), 'Sync comments' AS Type
    FROM note_comments_sync;
  SELECT CURRENT_TIMESTAMP AS Processing,
    'Deleting duplicates comments sync' as Text;
  DROP TABLE IF EXISTS note_comments_sync_no_duplicates;
  CREATE TABLE note_comments_sync_no_duplicates AS
    SELECT
     note_id,
     event,
     created_at,
     id_user,
     username
    FROM note_comments_sync
    WHERE note_id IN (
      SELECT note_id FROM note_comments_sync s
      EXCEPT 
      SELECT note_id FROM note_comments);
  DROP TABLE note_comments_sync;
  ALTER TABLE note_comments_sync_no_duplicates RENAME TO note_comments_sync;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on comments sync' as Text;
  ANALYZE note_comments_sync;
  SELECT CURRENT_TIMESTAMP AS Processing,
    'Counting comments sync different' as Text;
  SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1),
    'Sync comments no duplicates' AS Type
    FROM note_comments_sync;

  SELECT CURRENT_TIMESTAMP AS Processing, 'Inserting sync comments' AS Text;
  DO
  \$\$
  DECLARE
   r RECORD;
   created_time VARCHAR(100);
   qty INT;
  BEGIN
   SELECT COUNT(1) INTO qty
   FROM note_comments;

   IF (qty = 0) THEN
    INSERT INTO users (
     user_id, username
     ) SELECT
     id_user, username
     FROM note_comments_sync
     WHERE id_user IS NOT NULL
     GROUP BY id_user, username;
     
    INSERT INTO note_comments (
     note_id, event, created_at, id_user
     ) SELECT 
     note_id, event, created_at, id_user
     FROM note_comments_sync;
   ELSE
    FOR r IN
     SELECT note_id, event, created_at, id_user, username
     FROM note_comments_sync
    LOOP
     created_time := 'TO_TIMESTAMP(''' || r.created_at
       || ''', ''YYYY-MM-DD HH24:MI:SS'')';
     EXECUTE 'CALL insert_note_comment (' || r.note_id || ', '
       || '''' || r.event || '''::note_event_enum, '
       || COALESCE(created_time, 'NULL') || ', '
       || COALESCE(r.id_user || '', 'NULL') || ', '
       || QUOTE_NULLABLE('''' || r.username || '''') || ')';
    END LOOP;
   END IF;
  END
  \$\$;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on comments' as Text;
  ANALYZE note_comments;

BEGIN
EOF
 __log_finish
}

# Cleans files generated during the process.
function __cleanNotesFiles {
 __log_start
 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  rm -f "${XSLT_NOTES_FILE}" "${XSLT_NOTE_COMMENTS_FILE}" \
   "${PLANET_NOTES_FILE}.xml" "${OUTPUT_NOTES_FILE}" \
   "${OUTPUT_NOTE_COMMENTS_FILE}"
 fi
 __log_finish
}

# Gets the area of each note.
function __getLocationNotes {
 __log_start
 declare -l MAX_NOTE_ID
 wget -O "${LAST_NOTE_FILE}" \
  "https://api.openstreetmap.org/api/0.6/notes/search.xml?limit=1&closed=0&from=$(date "+%Y-%m-%d" || true)"
 MAX_NOTE_ID=$(awk -F'[<>]' '/^  <id>/ {print $3}' "${LAST_NOTE_FILE}")
 MAX_NOTE_ID=$((MAX_NOTE_ID + 100))

 declare -l SIZE=$((MAX_NOTE_ID / PARALLELISM))
 rm -r "${LAST_NOTE_FILE}"
 for j in $(seq 1 1 "${PARALLELISM}"); do
  (
   __logi "Starting ${j}"
   MIN=$((SIZE * (j - 1) + LOOP_SIZE))
   MAX=$((SIZE * j))
   for i in $(seq -f %1.0f "$((MAX))" "-${LOOP_SIZE}" "${MIN}"); do
    MIN_LOOP=$((i - LOOP_SIZE))
    MAX_LOOP=${i}
    __logd "${i}: [${MIN_LOOP} - ${MAX_LOOP}]"
    echo "UPDATE notes
      SET id_country = get_country(longitude, latitude, note_id)
      WHERE ${MIN_LOOP} <= note_id AND note_id <= ${MAX_LOOP}
      AND id_country IS NULL" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
   done
   __logi "Finishing ${j}"
  ) &
 done
 wait
 echo "UPDATE notes
   SET id_country = get_country(longitude, latitude, note_id)
   WHERE id_country IS NULL" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
 __log_finish
}

######
# MAIN

function main() {
 __logi "Preparing environment."
 __logd "Output saved at: ${TMP_DIR}"
 __logi "Processing: ${PROCESS_TYPE}"

 if [[ "${PROCESS_TYPE}" == "-h" ]] || [[ "${PROCESS_TYPE}" == "--help" ]]; then
  __show_help
  exit "${ERROR_HELP_MESSAGE}"
 else
  if [[ "${PROCESS_TYPE}" == "" ]]; then
   __logi "Process: Imports new notes from Planet."
  elif [[ "${PROCESS_TYPE}" == "--base" ]]; then
   __logi "Process: From scratch."
  elif [[ "${PROCESS_TYPE}" == "--boundaries" ]]; then
   __logi "Process: Downloads the countries and maritimes areas only."
  elif [[ "${PROCESS_TYPE}" == "--flatfile" ]]; then
   __logi "Process: Converts the planet into a flat CSV file."
  elif [[ "${PROCESS_TYPE}" == "--locatenotes" ]]; then
   __logi "Process: Takes the flat file and import it into the DB."
  fi
 fi
 # Checks the prerequisities. It could terminate the process.
 __checkPrereqs

 __logw "Starting process."

 # Sets the trap in case of any signal.
 __trapOn
 if [[ "${PROCESS_TYPE}" != "--flatfile" ]]; then
  exec 7> "${LOCK}"
  __logw "Validating single execution."
  flock -n 7
 fi

 if [[ "${PROCESS_TYPE}" == "--base" ]]; then
  __dropSyncTables   # base
  __dropApiTables    # base
  __dropBaseTables   # base
  __createBaseTables # base
 elif [[ "${PROCESS_TYPE}" == "" ]] \
  || [[ "${PROCESS_TYPE}" == "--locatenotes" ]]; then
  __dropSyncTables # sync
  set +E
  set +e
  __checkBaseTables # sync
  RET=${?}
  set -e
  if [[ "${RET}" -ne 0 ]]; then
   __createBaseTables # sync
  fi
  set -E
  __createSyncTables # sync
 fi
 if [[ "${PROCESS_TYPE}" == "--base" ]] \
  || [[ "${PROCESS_TYPE}" == "--boundaries" ]]; then
  __dropCountryTables   # base and boundaries
  __createCountryTables # base and boundaries

  # Downloads the areas. It could terminate the execution if an error appears.
  __processCountries # base and boundaries
  __processMaritimes # base and boundaries

  __cleanPartial # base and boundaries
  if [[ "${PROCESS_TYPE}" == "--boundaries" ]]; then
   __logw "Ending process"
   exit 0
  fi
 fi
 if [[ "${PROCESS_TYPE}" == "" ]] \
  || [[ "${PROCESS_TYPE}" == "--flatfile" ]]; then
  __downloadPlanetNotes          # sync and flatfile
  __validatePlanetNotesXMLFile   # sync and flatfile
  __convertPlanetNotesToFlatFile # sync and flatfile
  if [[ "${PROCESS_TYPE}" == "--flatfile" ]]; then
   echo "CSV files are at ${TMP_DIR}"
   __logw "Ending process"
   exit 0
  fi
 fi
 __createsFunctionToGetCountry # base, sync & locate
 __createsProcedures           # all
 __analyzeAndVacuum            # all
 if [[ "${PROCESS_TYPE}" == "--locatenotes" ]]; then
  __copyFlatFiles # locate
 fi
 if [[ "${PROCESS_TYPE}" == "" ]] \
  || [[ "${PROCESS_TYPE}" == "--locatenotes" ]]; then
  __loadSyncNotes    # sync & locate
  __removeDuplicates # sync & locate
  __dropSyncTables   # sync & locate
  __organizeAreas    # sync & locate
  __getLocationNotes # sync & locate
 fi
 __cleanNotesFiles # base, sync & locate
 __logw "Ending process"

 if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
  if [[ ! -t 1 ]]; then
   mv "${LOG_FILENAME}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
   rmdir "${TMP_DIR}"
  fi
 fi
}

# Allows to other user read the directory.
chmod go+x "${TMP_DIR}"

__start_logger
if [[ ! -t 1 ]]; then
 __set_log_file "${LOG_FILENAME}"
 main >> "${LOG_FILENAME}"
else
 main
fi
