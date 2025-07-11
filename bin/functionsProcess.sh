#!/bin/bash

# This is a script for sourcing from another scripts. It contains functions
# used in different scripts
#
# This scripts uses the constant ERROR_LOGGER_UTILITY.
#
# For contributing, please execute these commands before subimitting:
# * shellcheck -x -o all functionsProcess.sh
# * shfmt -w -i 1 -sr -bn functionsProcess.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-11

# Error codes.
# 1: Help message.
# shellcheck disable=SC2034
declare -r ERROR_HELP_MESSAGE=1
# 238: Preivous execution failed.
declare -r ERROR_PREVIOUS_EXECUTION_FAILED=238
# 239: Library or utility missing.
declare -r ERROR_CREATING_REPORT=239
# 241: Library or utility missing.
declare -r ERROR_MISSING_LIBRARY=241
# 242: Invalid argument for script invocation.
# shellcheck disable=SC2034
declare -r ERROR_INVALID_ARGUMENT=242
# 243: Logger utility is not available.
declare -r ERROR_LOGGER_UTILITY=243
# 244: The list of ids for boundary geometries cannot be downloaded.
declare -r ERROR_DOWNLOADING_ID_LIST=244
# 245: No last update.
declare -r ERROR_NO_LAST_UPDATE=245
# 246: Planet process is currently running.
declare -r ERROR_PLANET_PROCESS_IS_RUNNING=246
# 247: Error downloading planet notes file.
declare -r ERROR_DOWNLOADING_NOTES=247
# 248: Error executing the Planet dump.
declare -r ERROR_EXECUTING_PLANET_DUMP=248
# 249: Error downloading boundary.
declare -r ERROR_DOWNLOADING_BOUNDARY=249
# 250: Error converting OSM JSON to GeoJSON.
declare -r ERROR_GEOJSON=250
# 251: Internet issue.
declare -r ERROR_INTERNET_ISSUE=251
# 255: General error.
declare -r ERROR_GENERAL=255

# Generates file for failed exeuction.
declare GENERATE_FAILED_FILE=true
# Previous execution failed.
declare -r FAILED_EXECUTION_FILE="/tmp/${BASENAME}_failed"

# File that contains the ids of the boundaries for countries.
declare -r COUNTRIES_FILE="${TMP_DIR}/countries"
# File taht contains the ids of the boundaries of the maritimes areas.
declare -r MARITIMES_FILE="${TMP_DIR}/maritimes"
# File for the Overpass query.
declare QUERY_FILE="${TMP_DIR}/query"

# Logger framework.
# Taken from https://github.com/DushyanthJyothi/bash-logger.
# shellcheck disable=SC2154
declare -r LOGGER_UTILITY="${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"

# Name of the file of the XSLT transformation for notes.
declare -r XSLT_NOTES_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt"
# Name of the file of the XSLT transformation for note comments.
declare -r XSLT_NOTE_COMMENTS_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments-Planet-csv.xslt"
# Name of the file of the XSLT transformation for text comments.
declare -r XSLT_TEXT_COMMENTS_FILE="${SCRIPT_BASE_DIRECTORY}/xslt/note_comments_text-Planet-csv.xslt"
# XML Schema of the Planet notes file.
declare -r XMLSCHEMA_PLANET_NOTES="${SCRIPT_BASE_DIRECTORY}/xsd/OSM-notes-planet-schema.xsd"

# JSON schema for Overpass files.
declare -r JSON_SCHEMA_OVERPASS="${SCRIPT_BASE_DIRECTORY}/json-schema/osm-jsonschema.json"
# JSON schema for GeoJSON files.
declare -r JSON_SCHEMA_GEOJSON="${SCRIPT_BASE_DIRECTORY}/json-schema/geojsonschema.json"

# Filename for the flat file for notes.
declare -r OUTPUT_NOTES_FILE="${TMP_DIR}/output-notes.csv"
# Filename for the flat file for comment notes.
declare -r OUTPUT_NOTE_COMMENTS_FILE="${TMP_DIR}/output-note_comments.csv"
# Filename for the flat file for text comment notes.
declare -r OUTPUT_TEXT_COMMENTS_FILE="${TMP_DIR}/output-text_comments.csv"

# PostgreSQL files.
# Check base tables.
declare -r POSTGRES_CHECK_BASE_TABLES="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_checkBaseTables.sql"
# Create get country function.
declare -r POSTGRES_CREATE_FUNCTION_GET_COUNTRY="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_21_createFunctionToGetCountry.sql"
# Create insert note procedure.
declare -r POSTGRES_CREATE_PROC_INSERT_NOTE="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_22_createProcedure_insertNote.sql"
# Create insert note comment procedure.
declare -r POSTGRES_CREATE_PROC_INSERT_NOTE_COMMENT="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_23_createProcedure_insertNoteComment.sql"
# Organize areas.
declare -r POSTGRES_ORGANIZE_AREAS="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_organizeAreas.sql"
# Upload note locations.
declare -r POSTGRES_UPLOAD_NOTE_LOCATION="${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_loadsBackupNoteLocation.sql"

# Directory for Lock when inserting in the database
declare -r LOCK_OGR2OGR=/tmp/ogr2ogr.lock

# Overpass queries
# Get countries.
declare -r OVERPASS_COUNTRIES="${SCRIPT_BASE_DIRECTORY}/overpass/countries.op"
# Get maritimes.
declare -r OVERPASS_MARITIMES="${SCRIPT_BASE_DIRECTORY}/overpass/maritimes.op"

# Note location backup file
declare -r CSV_BACKUP_NOTE_LOCATION="/tmp/noteLocation.csv"
declare -r CSV_BACKUP_NOTE_LOCATION_COMPRESSED="${SCRIPT_BASE_DIRECTORY}/data/noteLocation.csv.zip"

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
 if [[ -f "${LOGGER_UTILITY}" ]]; then
  # Starts the logger mechanism.
  set +e
  # shellcheck source=../lib/bash_logger.sh
  source "${LOGGER_UTILITY}"
  local -i RET=${?}
  set -e
  if [[ "${RET}" -ne 0 ]]; then
   printf "\nERROR: Invalid logger framework file.\n"
   exit "${ERROR_LOGGER_UTILITY}"
  fi
  # Logger levels: TRACE, DEBUG, INFO, WARN, ERROR.
  # shellcheck disable=SC2154
  __set_log_level "${LOG_LEVEL}"
 else
  printf "\nLogger was not found.\n"
 fi
}

# Shows if there is another executing process.
function __onlyExecution {
 __log_start
 if [[ -n "${ONLY_EXECUTION:-}" ]] && [[ "${ONLY_EXECUTION}" == "no" ]]; then
  echo " There is another process already in execution"
 else
  if [[ "${GENERATE_FAILED_FILE}" = true ]]; then
   __logw "Generating file for failed exeuction."
   touch "${FAILED_EXECUTION_FILE}"
  else
   __logi "Do not generate file for failed execution."
  fi
 fi
 __log_finish
}

# Function that activates the error trap.
function __trapOn() {
 __log_start
 trap '{ printf "%s ERROR: The script ${BASENAME:-} did not finish correctly. Line number: %d%s.\n" "$(date +%Y%m%d_%H:%M:%S)" "${LINENO}" "$(__onlyExecution)"; exit ${ERROR_GENERAL};}' \
  ERR
 trap '{ printf "%s WARN: The script ${BASENAME:-} was terminated.\n" "$(date +%Y%m%d_%H:%M:%S)"; exit ${ERROR_GENERAL};}' \
  SIGINT SIGTERM
 __log_finish
}

# Checks prerequisites commands to run the script.
function __checkPrereqsCommands {
 __log_start
 set +e
 ## PostgreSQL
 __logd "Checking PostgreSQL."
 if ! psql --version > /dev/null 2>&1; then
  __loge "ERROR: PostgreSQL is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## PostGIS
 # shellcheck disable=SC2154
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 > /dev/null 2>&1 << EOF
 SELECT /* Notes-base */ PostGIS_version();
EOF
 RET=${?}
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: PostGIS is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Wget
 __logd "Checking wget."
 if ! wget --version > /dev/null 2>&1; then
  __loge "ERROR: Wget is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Aria2c
 if ! aria2c --version > /dev/null 2>&1; then
  __loge "ERROR: Aria2c is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## osmtogeojson
 if ! osmtogeojson --version > /dev/null 2>&1; then
  __loge "ERROR: osmtogeojson is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## JSON validator
 if ! ajv help > /dev/null 2>&1; then
  __loge "ERROR: ajv is missing."
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
 ## Mutt.
 if ! mutt -v > /dev/null 2>&1; then
  __loge "Falta instalar mutt."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## wget
 if ! wget --version > /dev/null 2>&1; then
  __loge "ERROR: wget is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Block-sorting file compressor
 if ! bzip2 --help > /dev/null 2>&1; then
  __loge "ERROR: bzip2 is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## XML lint
 __logd "Checking XML lint."
 if ! xmllint --version > /dev/null 2>&1; then
  __loge "ERROR: XMLlint is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## XSLTproc
 __logd "Checking XSLTproc."
 if ! xsltproc --version > /dev/null 2>&1; then
  __loge "ERROR: XSLTproc is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Bash 4 or greater.
 __logd "Checking Bash version."
 if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  __loge "ERROR: Requires Bash 4+."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}" ]]; then
  __loge "ERROR: Backup file is missing at ${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${POSTGRES_UPLOAD_NOTE_LOCATION}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_UPLOAD_NOTE_LOCATION}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${XSLT_NOTES_FILE}" ]]; then
  __loge "ERROR: File is missing at ${XSLT_NOTES_FILE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${XSLT_NOTE_COMMENTS_FILE}" ]]; then
  __loge "ERROR: File is missing at ${XSLT_NOTE_COMMENTS_FILE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${XSLT_TEXT_COMMENTS_FILE}" ]]; then
  __loge "ERROR: File is missing at ${XSLT_TEXT_COMMENTS_FILE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${XMLSCHEMA_PLANET_NOTES}" ]]; then
  __loge "ERROR: File is missing at ${XMLSCHEMA_PLANET_NOTES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${JSON_SCHEMA_OVERPASS}" ]]; then
  __loge "ERROR: File is missing at ${JSON_SCHEMA_OVERPASS}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if [[ ! -r "${JSON_SCHEMA_GEOJSON}" ]]; then
  __loge "ERROR: File is missing at ${JSON_SCHEMA_GEOJSON}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 set -e
 __log_finish
}

function __checkPrereqs_functions {
 __log_start
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_CHECK_BASE_TABLES}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_CHECK_BASE_TABLES}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_CREATE_FUNCTION_GET_COUNTRY}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_CREATE_FUNCTION_GET_COUNTRY}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_CREATE_PROC_INSERT_NOTE}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_CREATE_PROC_INSERT_NOTE}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_CREATE_PROC_INSERT_NOTE_COMMENT}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_CREATE_PROC_INSERT_NOTE_COMMENT}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks postgres scripts.
 if [[ ! -r "${POSTGRES_ORGANIZE_AREAS}" ]]; then
  __loge "ERROR: File is missing at ${POSTGRES_ORGANIZE_AREAS}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 __log_finish
}

# Checks the base tables if exist.
function __checkBaseTables {
 __log_start
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_CHECK_BASE_TABLES}"
 RET=${?}
 set -e
 RET_FUNC="${RET}"
 __log_finish
}

# Downloads the notes from the planet.
function __downloadPlanetNotes {
 __log_start
 # Download Planet notes.
 __logw "Retrieving Planet notes file..."
 # shellcheck disable=SC2154
 aria2c -d "${TMP_DIR}" -o "${PLANET_NOTES_NAME}.bz2" -x 8 \
  "${PLANET}/notes/${PLANET_NOTES_NAME}.bz2"
 # shellcheck disable=SC2154
 wget -O "${PLANET_NOTES_FILE}.bz2.md5" \
  "${PLANET}/notes/${PLANET_NOTES_NAME}.bz2.md5"
 # Validates the download with the hash value md5.
 diff <(md5sum "${PLANET_NOTES_FILE}.bz2" | cut -d' ' -f 1 || true) \
  <(cut -d' ' -f 1 "${PLANET_NOTES_FILE}.bz2.md5" || true)
 # If there is a difference, if will return non-zero value and fail the script.

 rm "${PLANET_NOTES_FILE}.bz2.md5"

 if [[ ! -r "${PLANET_NOTES_FILE}.bz2" ]]; then
  __loge "ERROR: Downloading notes file."
  # shellcheck disable=SC2154
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

 # shellcheck disable=SC2154
 xmllint --noout --schema "${XMLSCHEMA_PLANET_NOTES}" \
  "${PLANET_NOTES_FILE}.xml" 2>&1

 __log_finish
}

# Creates the XSLT files and process the XML files with them.
function __convertPlanetNotesToFlatFile {
 __log_start
 # Process the notes file.

 # Note too large: https://www.openstreetmap.org/note/156572
 # It requires --maxdepth 5000
 # Converts the XML into a flat file in CSV format.
 __logi "Processing notes from XML."
 xsltproc --timing --load-trace -o "${OUTPUT_NOTES_FILE}" \
   "${XSLT_NOTES_FILE}" "${PLANET_NOTES_FILE}.xml"
 __logi "Processing comments from XML."
 xsltproc --timing --load-trace -o "${OUTPUT_NOTE_COMMENTS_FILE}" \
   "${XSLT_NOTE_COMMENTS_FILE}" "${PLANET_NOTES_FILE}.xml"
 __logi "Processing text from XML."
 xsltproc --timing --load-trace --maxdepth 40000 -o "${OUTPUT_TEXT_COMMENTS_FILE}" \
   "${XSLT_TEXT_COMMENTS_FILE}" "${PLANET_NOTES_FILE}.xml"
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
 set +e
 # Insert values for representative countries in each area.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -f "${POSTGRES_ORGANIZE_AREAS}"
 RET=${?}
 set -e
 RET_FUNC="${RET}"
 __log_finish
}

# Processes a specific boundary id.
function __processBoundary {
 __log_start
 PROCESS="${BASHPID}"
 OUTPUT_OVERPASS="${TMP_DIR}/output.${BASHPID}"
 set +e
 __logi "Retrieving shape ${ID}."
 RETRY=true
 while [[ "${RETRY}" = true ]]; do
  # Retrieves the JSON from Overpass.
  wget -O "${JSON_FILE}" --post-file="${QUERY_FILE}" \
   "${OVERPASS_INTERPRETER}" 2> "${OUTPUT_OVERPASS}"
  RET="${?}"
  cat "${OUTPUT_OVERPASS}"
  MANY_REQUESTS=$(grep -c "ERROR 429: Too Many Requests." "${OUTPUT_OVERPASS}")
  if [[ "${MANY_REQUESTS}" -ne 0 ]]; then
   # If "too many requests" as part of the output, then waits.
   __logw "Waiting ${SECONDS_TO_WAIT} seconds because too many requests."
   sleep "${SECONDS_TO_WAIT}"
  elif [[ "${RET}" -ne 0 ]]; then
   # Retry once if there was an error.
   set -e
  else
   # Validates the JSON with a JSON schema.
   set +e
   ajv validate -s "${JSON_SCHEMA_OVERPASS}" -d "${JSON_FILE}" \
    --spec=draft2020 2> /dev/null
   echo "${RET}"
   set -e
   if [[ "${RET}" -eq 0 ]]; then
    # The format is valid.
    __logd "The JSON file ${JSON_FILE} is valid."
    RETRY=false
   else
    __logd "The JSON file ${JSON_FILE} is invalid; retrying."
   fi
  fi
 done
 rm -f "${OUTPUT_OVERPASS}"
 set -e

 # Validate the geojson with a json schema
 __logi "Converting into geoJSON."
 osmtogeojson "${JSON_FILE}" > "${GEOJSON_FILE}"
 set +e
 ajv validate -s "${JSON_SCHEMA_GEOJSON}" -d "${JSON_FILE}" \
  --spec=draft2020 2> /dev/null
 echo "${RET}"
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __loge "The GeoJSON file ${JSON_FILE} is invalid; failing."
  exit "${ERROR_GEOJSON}"
 fi

 set +o pipefail
 NAME=$(grep "\"name\":" "${GEOJSON_FILE}" | head -1 \
  | awk -F\" '{print $4}' | sed "s/'/''/")
 NAME_ES=$(grep "\"name:es\":" "${GEOJSON_FILE}" | head -1 \
  | awk -F\" '{print $4}' | sed "s/'/''/")
 NAME_EN=$(grep "\"name:en\":" "${GEOJSON_FILE}" | head -1 \
  | awk -F\" '{print $4}' | sed "s/'/''/")
 set -o pipefail
 set -e
 NAME_EN="${NAME_EN:-No English name}"
 __logi "Name: ${NAME_EN:-}."

 # Taiwan cannot be imported directly. Thus, a simplification is done.
 # ERROR:  row is too big: size 8616, maximum size 8160
 grep -v "official_name" "${GEOJSON_FILE}" \
  | grep -v "alt_name" > "${GEOJSON_FILE}-new"
 mv "${GEOJSON_FILE}-new" "${GEOJSON_FILE}"

 __logi "Importing into Postgres."
 set +e
 mkdir "${LOCK_OGR2OGR}" 2> /dev/null
 RET="${?}"
 set -e
 while [[ "${RET}" -ne 0 ]]; do
  set +e
  LOCK_ID=$(cat "${LOCK_OGR2OGR}"/pid)
  set -e
  __logd "${PROCESS} waiting for the lock. Current owner ${LOCK_ID}."
  sleep 1
  set +e
  mkdir "${LOCK_OGR2OGR}" 2> /dev/null
  RET="${?}"
  set -e
 done
 echo "${PROCESS}" > "${LOCK_OGR2OGR}"/pid
 __logi "I took the lock ${PROCESS} - ${ID}."
 ogr2ogr -f "PostgreSQL" PG:"dbname=${DBNAME} user=${DB_USER}" \
  "${GEOJSON_FILE}" -nln import -overwrite
 # If an error like this appear:
 # ERROR:  column "name:xx-XX" specified more than once
 # It means two of the objects of the country has a name for the same
 # language, but with different case. The current solution is to open
 # the JSON file, look for the language, and modify the parts to have the
 # same case. Or modify the objects in OSM.
 STATEMENT="SELECT COUNT(1) FROM countries
   WHERE country_id = ${ID}"
 COUNTRY_QTY=$(echo "${STATEMENT}" | psql -d "${DBNAME}" -t -v ON_ERROR_STOP=1)
 if [[ "${COUNTRY_QTY}" -eq 0 ]]; then
  __logi "Inserting into final table."
  if [[ "${ID}" -ne 16239 ]]; then
   STATEMENT="INSERT INTO countries (country_id, country_name, country_name_es,
     country_name_en, geom)
     SELECT ${ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}',
      ST_Union(ST_makeValid(wkb_geometry))
     FROM import
     GROUP BY 1"
  else # This case is for Austria.
   # GEOSUnaryUnion: TopologyException: Input geom 1 is invalid:
   # Self-intersection at or near point 10.454439900000001 47.555796399999998
   # at 10.454439900000001 47.555796399999998
   STATEMENT="INSERT INTO countries (country_id, country_name, country_name_es,
     country_name_en, geom)
     SELECT ${ID}, '${NAME}', '${NAME_ES}', '${NAME_EN}',
      ST_Union(ST_Buffer(wkb_geometry, 0.0))
     FROM import
     GROUP BY 1"
  fi
 elif [[ "${COUNTRY_QTY}" -eq 1 ]]; then
  if [[ "${ID}" -ne 16239 ]]; then
   STATEMENT="UPDATE countries AS c
    SET country_name = '${NAME}', country_name_es = '${NAME_ES}',
    country_name_en = '${NAME_EN}',
    geom = (
     SELECT geom FROM (
      SELECT ${ID}, ST_Union(ST_makeValid(wkb_geometry)) geom
      FROM import GROUP BY 1
     ) AS t
    ),
    updated = true
    WHERE country_id = ${ID}"
  else # This case is for Austria.
   # GEOSUnaryUnion: TopologyException: Input geom 1 is invalid:
   # Self-intersection at or near point 10.454439900000001 47.555796399999998
   # at 10.454439900000001 47.555796399999998
   STATEMENT="UPDATE countries AS c
    SET country_name = '${NAME}', country_name_es = '${NAME_ES}',
    country_name_en = '${NAME_EN}',
    geom = (
     SELECT geom FROM (
      SELECT ${ID}, ST_Union(ST_Buffer(wkb_geometry, 0.0))
      FROM import GROUP BY 1
     ) AS t
    ),
    updated = true
    FROM import AS i
    WHERE country_id = ${ID}"
  fi
 fi
 __logt "${STATEMENT}"
 echo "${STATEMENT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
 unset NAME
 unset NAME_ES
 unset NAME_EN

 __logi "I release the lock ${PROCESS} - ${ID}."
 rm -f "${LOCK_OGR2OGR}/pid"
 rmdir "${LOCK_OGR2OGR}/"

 __log_finish
}

# Processes the list of countries or maritimes areas in the given file.
function __processList {
 __log_start

 BOUNDARIES_FILE="${1}"
 QUERY_FILE="${QUERY_FILE}.${BASHPID}"
 __logi "Retrieving the countriy or maritime boundaries."
 while read -r LINE; do
  ID=$(echo "${LINE}" | awk '{print $1}')
  JSON_FILE="${TMP_DIR}/${ID}.json"
  GEOJSON_FILE="${TMP_DIR}/${ID}.geojson"
  __logi "ID: ${ID}."
  cat << EOF > "${QUERY_FILE}"
   [out:json];
   rel(${ID});
   (._;>;);
   out;
EOF

  __processBoundary

  if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
   rm -f "${JSON_FILE}" "${GEOJSON_FILE}" "${QUERY_FILE}"
  else
   mv "${JSON_FILE}" "${TMP_DIR}/${ID}.json.old"
   mv "${GEOJSON_FILE}" "${TMP_DIR}/${ID}.geojson.old"
  fi
 done < "${BOUNDARIES_FILE}"

 __log_finish
}

# Download the list of countries, then it downloads each country individually,
# converts the OSM JSON into a GeoJSON, and then it inserts the geometry of the
# country into the Postgres database with ogr2ogr.
function __processCountries {
 __log_start
 # Extracts ids of all country relations into a JSON.
 __logi "Obtaining the countries ids."
 set +e
 wget -O "${COUNTRIES_FILE}" --post-file="${OVERPASS_COUNTRIES}" \
  "${OVERPASS_INTERPRETER}"
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

 # Processes the countries in parallel.
 MAX_THREADS=$(nproc)

 TOTAL_LINES=$(wc -l < "${COUNTRIES_FILE}")
 SIZE=$((TOTAL_LINES / MAX_THREADS))
 SIZE=$((SIZE + 1))
 split -l"${SIZE}" "${COUNTRIES_FILE}" "${TMP_DIR}/part_country_"
 if [[ -d "${LOCK_OGR2OGR}" ]]; then
  rm -f "${LOCK_OGR2OGR}/pid"
  rmdir "${LOCK_OGR2OGR}"
 fi
 __logw "Starting parallel process to process country boundaries..."
 for I in "${TMP_DIR}"/part_country_??; do
  (
   __logi "Starting list ${I} - ${BASHPID}."
   __processList "${I}" >> "${LOG_FILENAME}.${BASHPID}" 2>&1
   __logi "Finished list ${I} - ${BASHPID}."
   if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
    rm -f "${LOG_FILENAME}.${BASHPID}"
   else
    mv "${LOG_FILENAME}.${BASHPID}" "${TMP_DIR}/${BASENAME}.old.${BASHPID}"
   fi
  ) &
  sleep 5
 done

 FAIL=0
 for JOB in $(jobs -p); do
  echo "${JOB}"
  set +e
  wait "${JOB}"
  RET="${?}"
  set -e
  if [[ "${RET}" -ne 0 ]]; then
   FAIL=$((FAIL + 1))
  fi
 done
 __logw "Waited for all jobs, restarting in main thread - countries."
 if [[ "${FAIL}" -ne 0 ]]; then
  echo "FAIL! (${FAIL})"
  exit "${ERROR_DOWNLOADING_BOUNDARY}"
 fi

 # If some of the threads generated an error.
 set +e
 QTY_LOGS=$(ls -1 "${TMP_DIR}" | grep -c "${BASENAME}\.log\.")
 set -e
 if [[ "${QTY_LOGS}" -ne 0 ]]; then
  __logw "Some thread generated an error."
  exit "${ERROR_DOWNLOADING_BOUNDARY}"
 fi
 if [[ -d "${LOCK_OGR2OGR}" ]]; then
  rm -f "${LOCK_OGR2OGR}/pid"
  rmdir "${LOCK_OGR2OGR}"
 fi
 __log_finish
}

# Download the list of maritimes areas, then it downloads each area
# individually, converts the OSM JSON into a GeoJSON, and then it inserts the
# geometry of the maritime area into the Postgres database with ogr2ogr.
function __processMaritimes {
 __log_start
 # Extracts ids of all EEZ relations into a JSON.
 __logi "Obtaining the eez ids."
 set +e
 wget -O "${MARITIMES_FILE}" --post-file="${OVERPASS_MARITIMES}" \
  "${OVERPASS_INTERPRETER}"
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]]; then
  __loge "ERROR: Maritimes border list could not be downloaded."
  exit "${ERROR_DOWNLOADING_ID_LIST}"
 fi

 tail -n +2 "${MARITIMES_FILE}" > "${MARITIMES_FILE}.tmp"
 mv "${MARITIMES_FILE}.tmp" "${MARITIMES_FILE}"

 # Processes the maritimes in parallel.
 MAX_THREADS=$(nproc)

 TOTAL_LINES=$(wc -l < "${MARITIMES_FILE}")
 SIZE=$((TOTAL_LINES / MAX_THREADS))
 SIZE=$((SIZE + 1))
 split -l"${SIZE}" "${MARITIMES_FILE}" "${TMP_DIR}/part_maritime_"
 if [[ -d "${LOCK_OGR2OGR}" ]]; then
  rm -f "${LOCK_OGR2OGR}/pid"
  rmdir "${LOCK_OGR2OGR}"
 fi
 __logw "Starting parallel process to process maritime boundaries..."
 for I in "${TMP_DIR}"/part_maritime_??; do
  (
   __logi "Starting list ${I} - ${BASHPID}."
   __processList "${I}" >> "${LOG_FILENAME}.${BASHPID}" 2>&1
   __logi "Finished list ${I} - ${BASHPID}."
   if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]]; then
    rm -f "${LOG_FILENAME}.${BASHPID}"
   else
    mv "${LOG_FILENAME}.${BASHPID}" "${TMP_DIR}/${BASENAME}.old.${BASHPID}"
   fi
  ) &
  sleep 5
 done

 FAIL=0
 for JOB in $(jobs -p); do
  echo "${JOB}"
  set +e
  wait "${JOB}"
  RET="${?}"
  set -e
  if [[ "${RET}" -ne 0 ]]; then
   FAIL=$((FAIL + 1))
  fi
 done
 __logw "Waited for all jobs, restarting in main thread - maritimes."
 if [[ "${FAIL}" -ne 0 ]]; then
  echo "FAIL! (${FAIL})"
  exit "${ERROR_DOWNLOADING_BOUNDARY}"
 fi

 # If some of the threads generated an error.
 set +e
 QTY_LOGS=$(ls -1 "${TMP_DIR}" | grep "${BASENAME}\.log\.")
 set -e
 if [[ "${QTY_LOGS}" -ne 0 ]]; then
  __logw "Some thread generated an error."
  exit "${ERROR_DOWNLOADING_BOUNDARY}"
 fi
 if [[ -d "${LOCK_OGR2OGR}" ]]; then
  rm -f "${LOCK_OGR2OGR}/pid"
  rmdir "${LOCK_OGR2OGR}"
 fi

 __logi "Calculating statistics on countries."
 echo "ANALYZE countries" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
 __log_finish
}

# Gets the area of each note.
function __getLocationNotes {
 __log_start
 __logd "Testing if notes should be updated."
 if [[ "${UPDATE_NOTE_LOCATION}" = false ]]; then
  __logi "Extracting notes backup."
  rm -f "${CSV_BACKUP_NOTE_LOCATION}"
  unzip "${CSV_BACKUP_NOTE_LOCATION_COMPRESSED}" -d /tmp
  chmod 666 "${CSV_BACKUP_NOTE_LOCATION}"

  __logi "Importing notes location."
  export CSV_BACKUP_NOTE_LOCATION
  # shellcheck disable=SC2016
  psql -d "${DBNAME}" -v ON_ERROR_STOP=1 \
   -c "$(envsubst '$CSV_BACKUP_NOTE_LOCATION' \
    < "${POSTGRES_UPLOAD_NOTE_LOCATION}" || true)"
 fi

 # Retrieves the max note for already location processed notes (from file.)
 MAX_NOTE_ID_NOT_NULL=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT MAX(note_id) FROM notes WHERE id_country IS NOT NULL")
 # Retrieves the max note.
 MAX_NOTE_ID=$(psql -d "${DBNAME}" -Atq -v ON_ERROR_STOP=1 \
  <<< "SELECT MAX(note_id) FROM notes")

 MAX_THREADS=$(nproc)
 # Uses n-1 cores, if number of cores is greater than 1.
 # This prevents monopolization of the CPUs.
 if [[ "${MAX_THREADS}" -gt 1 ]]; then
  MAX_THREADS=$((MAX_THREADS - 1))
 fi

 # Processes notes that should already have a location.
 declare -l SIZE=$((MAX_NOTE_ID_NOT_NULL / MAX_THREADS))
 __logw "Starting parallel process to locate notes - old..."
 for J in $(seq 1 1 "${MAX_THREADS}"); do
  (
   __logi "Starting ${J}."
   MIN=$((SIZE * (J - 1) + LOOP_SIZE))
   MAX=$((SIZE * J))
   for I in $(seq -f %1.0f "$((MAX))" "-${LOOP_SIZE}" "${MIN}"); do
    MIN_LOOP=$((I - LOOP_SIZE))
    MAX_LOOP=${I}
    __logd "${I}: [${MIN_LOOP} - ${MAX_LOOP}]."
    #STMT="SELECT COUNT(1), 'Notes without country - before - ${J}: ${MIN_LOOP}-${MAX_LOOP}'
    #  FROM notes
    #  WHERE ${MIN_LOOP} <= note_id AND note_id <= ${MAX_LOOP}
    #  AND id_country IS NULL"
    #echo "${STMT}" | psql -d "${DBNAME}" -t -v ON_ERROR_STOP=1

    if [[ "${UPDATE_NOTE_LOCATION}" = true ]]; then
     __logd "Updating incorrectly located notes."
     STMT="UPDATE notes AS n /* Notes-base thread old review */
     SET id_country = NULL
     FROM countries AS c
     WHERE n.id_country = c.country_id
     AND NOT ST_Contains(c.geom, ST_SetSRID(ST_Point(n.longitude, n.latitude),
      4326))
      AND ${MIN_LOOP} <= n.note_id AND n.note_id <= ${MAX_LOOP}
      AND id_country IS NOT NULL"
     __logt "${STMT}"
     echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
    fi

    #STMT="SELECT COUNT(1), 'Notes without country - after - ${J}: ${MIN_LOOP}-${MAX_LOOP}'
    #  FROM notes
    #  WHERE ${MIN_LOOP} <= note_id AND note_id <= ${MAX_LOOP}
    #  AND id_country IS NULL"
    #echo "${STMT}" | psql -d "${DBNAME}" -t -v ON_ERROR_STOP=1

    STMT="UPDATE notes /* Notes-base thread old */
      SET id_country = get_country(longitude, latitude, note_id)
      WHERE ${MIN_LOOP} <= note_id AND note_id <= ${MAX_LOOP}
      AND id_country IS NULL"
    echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
   done
   __logi "Finishing ${J}."
  ) &
 done

 wait
 __logw "Waited for all jobs, restarting in main thread - old notes."

 # Processes new notes that do not have location.
 MAX_NOTE_ID_NOT_NULL=$((MAX_NOTE_ID_NOT_NULL - LOOP_SIZE))
 QTY=$((MAX_NOTE_ID - MAX_NOTE_ID_NOT_NULL))
 declare -l SIZE=$((QTY / MAX_THREADS))
 __logw "Starting parallel process to locate notes - new..."
 for J in $(seq 1 1 "${MAX_THREADS}"); do
  (
   __logi "Starting ${J}."
   MIN=$((MAX_NOTE_ID_NOT_NULL + SIZE * (J - 1) + LOOP_SIZE))
   MAX=$((MAX_NOTE_ID_NOT_NULL + SIZE * J))
   for I in $(seq -f %1.0f "$((MAX))" "-${LOOP_SIZE}" "${MIN}"); do
    MIN_LOOP=$((I - LOOP_SIZE))
    MAX_LOOP=${I}
    __logd "${I}: [${MIN_LOOP} - ${MAX_LOOP}]."
    #STMT="SELECT COUNT(1), 'Notes without country - before - ${J}: ${MIN_LOOP}-${MAX_LOOP}'
    #  FROM notes
    #  WHERE ${MIN_LOOP} <= note_id AND note_id <= ${MAX_LOOP}
    #  AND id_country IS NULL"
    #echo "${STMT}" | psql -d "${DBNAME}" -t -v ON_ERROR_STOP=1

    if [[ "${UPDATE_NOTE_LOCATION}" = true ]]; then
     __logd "Updating incorrectly located notes."
     STMT="UPDATE notes AS n /* Notes-base thread new review */
     SET id_country = NULL
     FROM countries AS c
     WHERE n.id_country = c.country_id
     AND NOT ST_Contains(c.geom, ST_SetSRID(ST_Point(n.longitude, n.latitude),
      4326))
      AND ${MIN_LOOP} <= n.note_id AND n.note_id < ${MAX_LOOP}
      AND id_country IS NOT NULL"
     __logt "${STMT}"
     echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
    fi

    #STMT="SELECT COUNT(1), 'Notes without country - after - ${J}: ${MIN_LOOP}-${MAX_LOOP}'
    #  FROM notes
    #  WHERE ${MIN_LOOP} <= note_id AND note_id < ${MAX_LOOP}
    #  AND id_country IS NULL"
    #echo "${STMT}" | psql -d "${DBNAME}" -t -v ON_ERROR_STOP=1

    STMT="UPDATE notes /* Notes-base thread old */
      SET id_country = get_country(longitude, latitude, note_id)
      WHERE ${MIN_LOOP} <= note_id AND note_id < ${MAX_LOOP}
      AND id_country IS NULL"
    echo "${STMT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1
   done
   __logi "Finishing ${J}."
  ) &
 done

 wait
 __logw "Waited for all jobs, restarting in main thread - new notes."

 echo "UPDATE notes /* Notes-base remaining */
   SET id_country = get_country(longitude, latitude, note_id)
   WHERE id_country IS NULL" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1

 __log_finish
}
