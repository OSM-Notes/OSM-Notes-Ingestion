#!/bin/bash

# This scripts processes the most recents notes (creation or modification) from
# the OpenStreetMap API.
# * It downloads the notes via HTTP call.
# * Then with an XSLT transformation converts the data into flat files.
# * It uploads the data into temp tables of a PostreSQL database.
# * Finally, it synchronizes the master tables.
#
# These are some examples to call this script:
#
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/processAPINotes.sh
#
# To follow the progress you can execute:
#   tail -40f $(ls -1rtd /tmp/processAPINotes_* | tail -1)/processAPINotes.log
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument.
# 243) Logger utility is missing.
# 244) No last update.
#
# Author: Andres Gomez (AngocA)
# Version: 2022-11-29
declare -r VERSION="2022-11-29"

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
# 244: No last update.
declare -r ERROR_NO_LAST_UPDATE=244

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
declare -r LOGGER_UTILITY="${SCRIPT_BASE_DIRECTORY}/bash_logger.sh"

declare BASENAME
BASENAME=$(basename -s .sh "${0}")
readonly BASENAME
# Temporal directory for all files.
declare TMP_DIR
TMP_DIR=$(mktemp -d "/tmp/${BASENAME}_XXXXXX")
readonly TMP_DIR
# Log file for output.
declare LOG_FILE
LOG_FILE="${TMP_DIR}/${BASENAME}.log"
readonly LOG_FILE

# Lock file for single execution.
declare LOCK
LOCK="/tmp/${BASENAME}.lock"
readonly LOCK

# Type of process to run in the script.
declare -r PROCESS_TYPE=${1:-}

# Maximum of notes to download from the API.
declare -r MAX_NOTES=10000

# XML Schema of the API notes file.
declare -r XMLSCHEMA_API_NOTES="${TMP_DIR}/OSM-notes-API-schema.xsd"
# Jar name of the XSLT processor.
declare -r SAXON_JAR="${SAXON_CLASSPATH:-.}/saxon-he-11.4.jar"
# Name of the file of the XSLT transformation for notes from API.
declare -r XSLT_NOTES_API_FILE="${TMP_DIR}/notes-API-csv.xslt"
# Name of the file of the XSLT transformation for note comments from API.
declare -r XSLT_NOTE_COMMENTS_API_FILE="${TMP_DIR}/note_comments-API-csv.xslt"
# Filename for the flat file for notes.
declare -r OUTPUT_NOTES_FILE="${TMP_DIR}/output-notes.csv"
# Filename for the flat file for comment notes.
declare -r OUTPUT_NOTE_COMMENTS_FILE="${TMP_DIR}/output-note_comments.csv"

# Script to synchronize the notes with the Planet.
declare -r NOTES_SYNC_SCRIPT="${SCRIPT_BASE_DIRECTORY}/processPlanetNotes.sh"

# Name of the PostgreSQL database to insert or update the data.
declare -r DBNAME=notes

# Temporal file that contiains the downloaded notes from the API.
declare -r API_NOTES_FILE="${TMP_DIR}/OSM-notes-API.xml"

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
 trap '{ printf "%s ERROR: The script did not finish correctly. Line number: %d.\n" "$(date +%Y-%m-%d_%H:%M:%S)" "${LINENO}"; exit ;}' \
   ERR
 trap '{ printf "%s WARN: The script was terminated.\n" "$(date +%Y%m%d_%H:%M:%S)"; exit 1 ;}' \
   SIGINT SIGTERM
 __log_finish
}

# Shows the help information.
function __show_help {
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
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 #__log_start
 __logd "Checking process type."
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--help" ]] \
   && [[ "${PROCESS_TYPE}" != "-h" ]] ; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string (nothing)."
  echo " * --help"
  __loge "ERROR: Invalid parameter."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set +e
 # Checks prereqs.
 ## PostgreSQL
 __logd "Checking PostgreSQL."
 if ! psql --version > /dev/null 2>&1 ; then
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
 __logd "Checking wget."
 if ! wget --version > /dev/null 2>&1 ; then
  __loge "ERROR: Wget is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## flock
 if ! flock --version > /dev/null 2>&1 ; then
  __loge "ERROR: flock is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## XML lint
 __logd "Checking XML lint."
 if ! xmllint --version > /dev/null 2>&1 ; then
  __loge "ERROR: XMLlint is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Java
 __logd "Checking Java."
 if ! java --version > /dev/null 2>&1 ; then
  __loge "ERROR: Java JRE is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Saxon Jar
 __logd "Checking Saxon Jar."
 if [[ ! -r "${SAXON_JAR}" ]] ; then
  __loge "ERROR: Saxon jar is missing at ${SAXON_JAR}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Bash 4 or greater.
 __logd "Checking Bash version."
 if [[ "${BASH_VERSINFO[0]}" -lt 4 ]] ; then
  __loge "ERROR: Requires Bash 4+."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks required files.
 if [[ ! -r "${NOTES_SYNC_SCRIPT}" ]] ; then
  __loge "ERROR: File is missing at ${NOTES_SYNC_SCRIPT}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 #__log_finish
 set -e
}

# Drop tables for notes from API.
function __dropApiTables {
 __log_start
 __logi "Droping tables."
 psql -d "${DBNAME}" << EOF
  DROP TABLE note_comments_api;
  DROP TABLE notes_api;
EOF
 __log_finish
}

# Creates tables for notes from API.
function __createApiTables {
 __log_start
 __logi "Creating tables"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  CREATE TABLE notes_api (
   note_id INTEGER NOT NULL,
   latitude DECIMAL NOT NULL,
   longitude DECIMAL NOT NULL,
   created_at TIMESTAMP NOT NULL,
   closed_at TIMESTAMP,
   status note_status_enum,
   id_country INTEGER
  );

  CREATE TABLE note_comments_api (
   note_id INTEGER NOT NULL,
   event note_event_enum NOT NULL,
   created_at TIMESTAMP NOT NULL,
   id_user INTEGER,
   username VARCHAR(256)
  );
EOF
 __log_finish
}

# Creates table properties during the execution.
function __createPropertiesTable {
 __log_start
 __logi "Creating properties table"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  DO
  \$\$
  DECLARE
   last_update VARCHAR(32);
   new_last_update VARCHAR(32);
   qty INT;
  BEGIN
   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'execution_properties'
   ;

   IF (qty = 0) THEN
    EXECUTE 'CREATE TABLE execution_properties ('
      || 'key VARCHAR(256) NOT NULL,'
      || 'value VARCHAR(256)'
      || ')';
   END IF;

   SELECT MAX(TIMESTAMP)
     INTO new_last_update
   FROM (
    SELECT MAX(created_at) AS TIMESTAMP
    FROM notes
    UNION
    SELECT MAX(closed_at) AS TIMESTAMP
    FROM notes
    UNION
    SELECT MAX(created_at) AS TIMESTAMP
    FROM note_comments
   ) T;

   IF (new_last_update IS NOT NULL) THEN
    SELECT value INTO last_update
      FROM execution_properties
      WHERE key = 'lastUpdate';

    IF (last_update IS NULL) THEN
     INSERT INTO execution_properties VALUES
       ('lastUpdate', new_last_update);
    ELSE
     UPDATE execution_properties
       SET value = new_last_update
       WHERE key = 'lastUpdate';
    END IF;
   ELSE
    RAISE EXCEPTION 'Notes are not yet on the database';
   END IF;
  END;
  \$\$;
  SELECT value, 'oldLastUpdate' AS key
  FROM execution_properties
  WHERE key = 'lastUpdate';
EOF
 __log_finish
}

# Checks the base tables if exist.
function __checkBaseTables {
 __log_start
 set +e
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  DO
  \$\$
  DECLARE
   qty INT;
  BEGIN
   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'countries'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: countries';
   END IF;

   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'notes'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: notes';
   END IF;

   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'note_comments'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: note_comments';
   END IF;
  END;
  \$\$;
EOF
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]] ; then
  __logw "Creating base tables. It will take several hours."
  "${NOTES_SYNC_SCRIPT}" --base
  __logw "Base tables created."
 fi
 __log_finish

}

# Gets the new notes
function __getNewNotesFromApi {
 __log_start
 declare TEMP_FILE="${TMP_DIR}/last_update_value.txt"
 # Gets the most recent value on the database.
 psql -d "${DBNAME}" -Atq \
   -c "SELECT TO_CHAR(TO_TIMESTAMP(value, 'YYYY-MM-DD HH24:MI:SS'), 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') FROM execution_properties WHERE KEY = 'lastUpdate'" \
   -v ON_ERROR_STOP=1 > "${TEMP_FILE}" 2> /dev/null
 LAST_UPDATE=$(cat "${TEMP_FILE}")
 __logw "Last update: ${LAST_UPDATE}"
 if [[ "${LAST_UPDATE}" == "" ]] ; then
  __loge "ERROR: No last update. Please load notes."
  exit "${ERROR_NO_LAST_UPDATE}"
 fi

 # Gets the values from OSM API.
 wget -O "${API_NOTES_FILE}" \
   "https://api.openstreetmap.org/api/0.6/notes/search.xml?limit=${MAX_NOTES}&closed=-1&from=${LAST_UPDATE}"

 rm "${TEMP_FILE}"
 __log_finish
}

# Validates the XML file to be sure everything will work fine.
function __validateApiNotesXMLFile {
 __log_start
 # XML Schema.
 cat << EOF > "${XMLSCHEMA_API_NOTES}"
<xs:schema attributeFormDefault="unqualified" elementFormDefault="qualified" xmlns:xs="http://www.w3.org/2001/XMLSchema">

  <!-- Attributes for OSM API -->
  <xs:attributeGroup name="attributesOSMAPI">
    <xs:attribute name="version" use="required">
      <xs:simpleType>
        <xs:restriction base="xs:decimal">
          <xs:minInclusive value="0.6"/>
        </xs:restriction>
      </xs:simpleType>
    </xs:attribute>

    <xs:attribute name="generator" type="xs:string" use="required"/>
    <xs:attribute name="copyright" type="xs:string" use="required"/>
    <xs:attribute name="attribution" type="xs:anyURI" use="required"/>
    <xs:attribute name="license" type="xs:anyURI" use="required"/>
  </xs:attributeGroup>

  <!-- Attributes for Notes -->
  <xs:attributeGroup name="attributesNotes">
    <xs:attribute name="lon" use="required">
      <xs:simpleType>
        <xs:restriction base="xs:decimal">
          <xs:fractionDigits value="7"/>
          <xs:minInclusive value="-180"/>
          <xs:maxInclusive value="180"/>
        </xs:restriction>
      </xs:simpleType>
    </xs:attribute>
    <xs:attribute name="lat" use="required">
      <xs:simpleType>
        <xs:restriction base="xs:decimal">
          <xs:fractionDigits value="7"/>
          <xs:minInclusive value="-90"/>
          <xs:maxInclusive value="90"/>
        </xs:restriction>
      </xs:simpleType>
    </xs:attribute>
  </xs:attributeGroup>

  <!-- Elements for Comments -->
  <xs:element name="comment">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="date">
          <xs:simpleType>
            <xs:restriction base="xs:string">
              <xs:pattern value="20[0-3][0-9]-[0-1][0-9]-[0-3][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9] UTC"/>
            </xs:restriction>
          </xs:simpleType>
        </xs:element>
        <xs:element name="uid" minOccurs="0">
          <xs:simpleType>
            <xs:restriction base="xs:integer">
              <xs:minInclusive value="1"/>
            </xs:restriction>
          </xs:simpleType>
        </xs:element>
        <xs:element name="user" minOccurs="0">
          <xs:simpleType>
            <xs:restriction base="xs:string">
              <xs:minLength value="1"/>
            </xs:restriction>
          </xs:simpleType>
        </xs:element>
        <xs:element name="user_url" type="xs:anyURI" minOccurs="0"/>
        <xs:element name="action" >
          <xs:simpleType>
            <xs:restriction base="xs:string">
              <xs:enumeration value="opened"/>
              <xs:enumeration value="closed"/>
              <xs:enumeration value="reopened"/>
              <xs:enumeration value="commented"/>
              <xs:enumeration value="hidden"/>
            </xs:restriction>
          </xs:simpleType>
        </xs:element>
        <xs:element name="text" type="xs:string"/>
        <xs:element name="html" type="xs:string"/>
      </xs:sequence>
    </xs:complexType>
  </xs:element>

  <!-- Elements for Notes -->
  <xs:element name="note">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="id">
          <xs:simpleType>
            <xs:restriction base="xs:integer">
              <xs:minInclusive value="1"/>
            </xs:restriction>
          </xs:simpleType>
        </xs:element>
        <xs:element name="url" type="xs:anyURI"/>
        <xs:element name="comment_url" type="xs:anyURI" minOccurs="0"/>
        <xs:element name="close_url" type="xs:anyURI" minOccurs="0"/>
        <xs:element name="reopen_url" type="xs:string" minOccurs="0"/>
        <xs:element name="date_created" type="xs:string"/>
          <!--xs:simpleType>
            <xs:restriction base="xs:string">
              <xs:pattern value="20[0-3][0-9]-[0-1][0-9]-[0-3][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9] UTC"/>
            </xs:restriction>
          </xs:simpleType>
        </xs:element-->
        <xs:element name="status">
          <xs:simpleType>
            <xs:restriction base="xs:string">
              <xs:enumeration value="open"/>
              <xs:enumeration value="closed"/>
            </xs:restriction>
          </xs:simpleType>
        </xs:element>
        <xs:element name="date_closed" minOccurs="0">
          <xs:simpleType>
            <xs:restriction base="xs:string">
              <xs:pattern value="20[0-3][0-9]-[0-1][0-9]-[0-3][0-9] [0-2][0-9]:[0-5][0-9]:[0-5][0-9] UTC"/>
            </xs:restriction>
          </xs:simpleType>
        </xs:element>
        <xs:element name="comments">
          <xs:complexType>
            <xs:sequence>
              <xs:element ref="comment" maxOccurs="unbounded" minOccurs="0"/>
            </xs:sequence>
          </xs:complexType>
        </xs:element>
      </xs:sequence>
      <xs:attributeGroup ref="attributesNotes"/>
    </xs:complexType>
  </xs:element>

  <!-- Root tag -->
  <xs:element name="osm">
    <xs:complexType>
      <xs:sequence>
        <xs:element ref="note" maxOccurs="unbounded" minOccurs="0"/>
      </xs:sequence>
      <xs:attributeGroup ref="attributesOSMAPI"/>
    </xs:complexType>
  </xs:element>
</xs:schema>
EOF

 xmllint --noout --schema "${XMLSCHEMA_API_NOTES}" "${API_NOTES_FILE}"

 rm -f "${XMLSCHEMA_API_NOTES}"
 __log_finish
}

# Creates the XSLT files and process the XML files with them.
# The CSV file structure for notes is:
# 3451247,29.6141093,-98.4844977,"2022-11-22 02:13:03 UTC",,"open"
# 3451210,39.7353700,-104.9626400,"2022-11-22 01:30:39 UTC","2022-11-22 02:09:32 UTC","close"
#
# The CSV file structure for comments is:
# 3450803,'opened','2022-11-21 17:13:10 UTC',17750622,'Juanmiguelrizogonzalez'
# 3450803,'closed','2022-11-22 02:06:53 UTC',15422751,'GHOSTsama2503'
# 3450803,'reopened','2022-11-22 02:06:58 UTC',15422751,'GHOSTsama2503'
# 3450803,'commented','2022-11-22 02:07:24 UTC',15422751,'GHOSTsama2503'
function __convertApiNotesToFlatFile {
 __log_start
 # Process the notes file.
 # XSLT transformations.
 cat << EOF > "${XSLT_NOTES_API_FILE}"
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:strip-space elements="*"/>
<xsl:output method="text" />
<xsl:template match="/">
 <xsl:for-each select="osm/note"><xsl:value-of select="id"/>,<xsl:value-of select="@lat"/>,<xsl:value-of select="@lon"/>,"<xsl:value-of select="date_created"/>",<xsl:choose><xsl:when test="date_closed != ''">"<xsl:value-of select="date_closed"/>","close"
</xsl:when><xsl:otherwise>,"open"<xsl:text>
</xsl:text></xsl:otherwise></xsl:choose>
 </xsl:for-each>
</xsl:template>
</xsl:stylesheet>
EOF

 cat << EOF > "${XSLT_NOTE_COMMENTS_API_FILE}"
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:strip-space elements="*"/>
<xsl:output method="text" />
<xsl:template match="/">
 <xsl:for-each select="osm/note">
 <xsl:variable name="note_id"><xsl:value-of select="id"/></xsl:variable>
  <xsl:for-each select="comments/comment">
<xsl:choose> <xsl:when test="uid != ''"> <xsl:copy-of select="\$note_id" />,'<xsl:value-of select="action" />','<xsl:value-of select="date"/>',<xsl:value-of select="uid"/>,'<xsl:value-of select="replace(user,'''','''''')"/>'<xsl:text>
</xsl:text></xsl:when><xsl:otherwise>
<xsl:copy-of select="\$note_id" />,'<xsl:value-of select="action" />','<xsl:value-of select="date"/>',,<xsl:text>
</xsl:text></xsl:otherwise> </xsl:choose>
  </xsl:for-each>
 </xsl:for-each>
</xsl:template>
</xsl:stylesheet>
EOF

 # Converts the XML into a flat file in CSV format.
 java -Xmx1000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
   -s:"${API_NOTES_FILE}" -xsl:"${XSLT_NOTES_API_FILE}" \
   -o:"${OUTPUT_NOTES_FILE}"
 __logi "$(grep -c "<note " "${API_NOTES_FILE}") - Notes from API."
 __logw "$(wc -l "${OUTPUT_NOTES_FILE}") - Notes in flat file."
 head "${OUTPUT_NOTES_FILE}"

 java -Xmx1000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
   -s:"${API_NOTES_FILE}" -xsl:"${XSLT_NOTE_COMMENTS_API_FILE}" \
   -o:"${OUTPUT_NOTE_COMMENTS_FILE}"
 __logi "$(grep -c "<comment>" "${API_NOTES_FILE}") - Comments from API."
 __logw "$(wc -l "${OUTPUT_NOTE_COMMENTS_FILE}") - Notes in flat file."
 head "${OUTPUT_NOTE_COMMENTS_FILE}"

 rm -f "${XSLT_NOTES_API_FILE}" "${XSLT_NOTE_COMMENTS_API_FILE}"
 __log_finish
}

# Checks if the quantity of notes is less that the maximum allowed. If is the
# the same, it means not all notes were downloaded, and it needs a
# synchronization
function __checkQtyNotes {
 __log_start
 QTY=$(wc -l "${OUTPUT_NOTES_FILE}" | awk '{print $1}')
 if [[ "${QTY}" -ge "${MAX_NOTES}" ]] ; then
  __logw "Starting full synchronization from Planet."
  __logi "This could take several minutes."
  "${NOTES_SYNC_SCRIPT}"
  __logw "Finished full synchronization from Planet."
 fi
 __log_finish
}

# Loads notes from API into the database.
function __loadApiNotes {
 __log_start

 __logi "Notes to be processed:"
 declare TEXT
 while read -r LINE ; do
  TEXT=$(echo "${LINE}" | cut -f 1 -d,)
  __logi "${TEXT}"
 done < "${OUTPUT_NOTES_FILE}"

 __logi "Note comments to be processed:"
 while read -r LINE ; do
  TEXT=$(echo "${LINE}" | cut -f 1-2 -d,)
  __logi "${TEXT}"
 done < "${OUTPUT_NOTE_COMMENTS_FILE}"

 # Loads the data in the database.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  COPY notes_api (note_id, latitude, longitude, created_at, closed_at, status)
    FROM '${OUTPUT_NOTES_FILE}' csv;
  SELECT CURRENT_TIMESTAMP, COUNT(1), 'uploaded new notes' as type
  FROM notes_api;
  COPY note_comments_api FROM '${OUTPUT_NOTE_COMMENTS_FILE}' csv
    DELIMITER ',' QUOTE '''';
  SELECT CURRENT_TIMESTAMP, COUNT(1), 'uploaded new comments' as type
  FROM note_comments_api;
EOF
 __log_finish
}

# Inserts new notes and comments into the database.
function __insertNewNotesAndComments {
 __log_start
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  SELECT CURRENT_TIMESTAMP, COUNT(1), 'current notes - before' as qty
  FROM notes;
  DO
  \$\$
   DECLARE
    r RECORD;
    m_closed_time VARCHAR(100);
    m_lastupdate TIMESTAMP;
   BEGIN
    SELECT value INTO m_lastupdate
     FROM execution_properties
     WHERE key = 'lastUpdate';
    FOR r IN
     SELECT note_id, latitude, longitude, created_at, closed_at, status
     FROM notes_api
    LOOP
     IF (r.created_at = m_lastupdate OR r.closed_at = m_lastupdate) THEN
      CONTINUE;
     END IF;
     m_closed_time := 'TO_TIMESTAMP(''' || r.closed_at
       || ''', ''YYYY-MM-DD HH24:MI:SS'')';
     EXECUTE 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
       || r.longitude || ', '
       || 'TO_TIMESTAMP(''' || r.created_at
       || ''', ''YYYY-MM-DD HH24:MI:SS''), '
       || COALESCE (m_closed_time, 'NULL') || ','
       || '''' || r.status || '''::note_status_enum)';
    END LOOP;
   END;
  \$\$;
  SELECT CURRENT_TIMESTAMP, COUNT(1), 'current notes - after' as qty FROM notes;

  SELECT CURRENT_TIMESTAMP, COUNT(1), 'current comments - before' as qty
  FROM note_comments;
  DO
  \$\$
   DECLARE
    r RECORD;
    m_created_time VARCHAR(100);
    m_lastupdate TIMESTAMP;
   BEGIN
    SELECT value INTO m_lastupdate
     FROM execution_properties
     WHERE key = 'lastUpdate';
    FOR r IN
     SELECT note_id, event, created_at, id_user, username
     FROM note_comments_api
    LOOP
     IF (r.created_at = m_lastupdate) THEN
      CONTINUE;
     END IF;
     EXECUTE 'CALL insert_note_comment (' || r.note_id || ', '
       || '''' || r.event || '''::note_event_enum, '
       || 'TO_TIMESTAMP(''' || r.created_at
       || ''', ''YYYY-MM-DD HH24:MI:SS''), '
       || COALESCE(r.id_user || '', 'NULL') || ', '
       || QUOTE_NULLABLE('''' || r.username || '''') || ')';
    END LOOP;
   END;
  \$\$;
  SELECT CURRENT_TIMESTAMP, COUNT(1), 'current comments - after' as qty
  FROM note_comments;
EOF
 __log_finish
}

# Updates the refresh value.
function __updateLastValue {
 __log_start
 __logi "Updating last update time"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  SELECT value FROM execution_properties WHERE key = 'lastUpdate';
  DO
  \$\$
   DECLARE
    last_update VARCHAR(32);
    new_last_update VARCHAR(32);
   BEGIN
    SELECT MAX(TIMESTAMP)
      INTO new_last_update
    FROM (
     SELECT MAX(created_at) TIMESTAMP
     FROM notes
     UNION
     SELECT MAX(closed_at) TIMESTAMP
     FROM notes
     UNION
     SELECT MAX(created_at) TIMESTAMP
     FROM note_comments
    ) T;

    UPDATE execution_properties
     SET value = new_last_update
     WHERE key = 'lastUpdate';
   END;
  \$\$;
  SELECT value, 'newLastUpdate' AS key
  FROM execution_properties
  WHERE key = 'lastUpdate';
EOF
 __log_finish
}

# Clean files generated during the process.
function __cleanNotesFiles {
 __log_start
 rm "${API_NOTES_FILE}" "${OUTPUT_NOTES_FILE}" "${OUTPUT_NOTE_COMMENTS_FILE}"
 __log_finish
}

######
# MAIN

# Return value for several functions.
declare -i RET

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
 __logw "Process started."
 # Sets the trap in case of any signal.
 __trapOn
 exec 8> "${LOCK}"
 __logw "Validating single execution."
 flock -n 8
 __dropApiTables
 set +E
 __checkBaseTables
 set -E
 __createApiTables
 __createPropertiesTable
 __getNewNotesFromApi
 if [ $(cat "${API_NOTES_FILE}" | wc -l) -ne 0 ] ; then
  __validateApiNotesXMLFile
  __convertApiNotesToFlatFile
  __checkQtyNotes
  __loadApiNotes
  __insertNewNotesAndComments
  __updateLastValue
 fi
 __cleanNotesFiles
 __logw "Process finished."
} >> "${LOG_FILE}" 2>&1

if [[ -n "${CLEAN}" ]] && [[ "${CLEAN}" = true ]] ; then
 mv "${LOG_FILE}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
 rmdir "${TMP_DIR}"
fi
