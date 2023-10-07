#!/bin/bash

# This script checks the loaded notes in the database, with a new planet
# download, and compares the notes. It allows to identify incorrectly
# processed notes. The scripts downloads the notes from planet, and load
# them into a new table for this purpose.
#
# The script structure is:
# * Creates the database structure.
# * Downloads the planet notes.
# * Converts the notes into flat CSV files.
# * Imports the notes into the db.
#
# This is an example about how to call this script:
#
# * export LOG_LEVEL=DEBUG ; ~/OSM-Notes-profile/processCheckPlanetNotes.sh
#
# The following file is necessary to prepare the environment.
# https://sourceforge.net/projects/saxon/files/Saxon-HE/11/Java/SaxonHE11-4J.zip/download
#
# When running under MacOS or zsh, it is better to invoke bash:
# bash ./processPlanetNotes.sh
#
# To follow the progress you can execute:
#   tail -40f $(ls -1rtd /tmp/processCheckPlanetNotes_* | tail -1)/processCheckPlanetNotes.log
#
# The database should already be prepared with base tables for notes.
#
# To specify the Saxon location, you can put this file in the same directory as
# saxon ; otherwise, it will this location:
#   export SAXON_CLASSPATH=~/saxon/
#
# This is the list of error codes:
# 1) Help message.
# 241) Library or utility missing.
# 242) Invalid argument for script invocation.
# 243) Logger utility is not available.
# 244) The list of ids for boundary geometries can not be downloaded.
# 245) Error downloading planet notes file.
#
# Author: Andres Gomez (AngocA)
# Version: 2023-10-06
declare -r VERSION="2023-10-06"

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
# 245: Error downloading planet notes file.
declare -r ERROR_DOWNLOADING_NOTES=245

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

# Flat file to start from load.
declare -r FLAT_NOTES_FILE=${2:-}
declare -r FLAT_NOTE_COMMENTS_FILE=${3:-}

# Name of the PostgreSQL database to insert or update the data.
declare -r DBNAME=notes

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
 echo "This script checks the loaded notes to validate if their state is"
 echo "correct."
 echo
 echo "Written by: Andres Gomez (AngocA)"
 echo "OSM-LatAm, OSM-Colombia, MaptimeBogota."
 exit "${ERROR_HELP_MESSAGE}"
}

# Checks prerequisites to run the script.
function __checkPrereqs {
 __log_start
 if [[ "${PROCESS_TYPE}" != "" ]] && [[ "${PROCESS_TYPE}" != "--help" ]] \
   && [[ "${PROCESS_TYPE}" != "-h" ]] ; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --help"
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 set +e
 # Checks prereqs.
 ## PostgreSQL
 if ! psql --version > /dev/null 2>&1 ; then
  __loge "ERROR: PostgreSQL is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## flock
 if ! flock --version > /dev/null 2>&1 ; then
  __loge "ERROR: flock is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## wget
 if ! wget --version > /dev/null 2>&1 ; then
  __loge "ERROR: wget is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Block-sorting file compressor
 if ! bzip2 --help > /dev/null 2>&1 ; then
  __loge "ERROR: bzip2 is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## XML lint
 if ! xmllint --version > /dev/null 2>&1 ; then
  __loge "ERROR: XMLlint is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Java
 if ! java --version > /dev/null 2>&1 ; then
  __loge "ERROR: Java JRE is missing."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Saxon Jar
 if [[ ! -r "${SAXON_JAR}" ]] ; then
  __loge "ERROR: Saxon jar is missing at ${SAXON_JAR}."
  __loge "You can specify it by export SAXON_CLASSPATH="
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 if ! java -cp "${SAXON_JAR}" net.sf.saxon.Transform -? > /dev/null 2>&1 ; then
  __loge "ERROR: Saxon jar is missing at ${SAXON_JAR}."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Bash 4 or greater.
 if [[ "${BASH_VERSINFO[0]}" -lt 4 ]] ; then
  __loge "ERROR: Requires Bash 4+."
  exit "${ERROR_MISSING_LIBRARY}"
 fi
 ## Checks the flat file if exist.
 if [[ "${FLAT_NOTES_FILE}" != "" ]] && [[ ! -r "${FLAT_NOTES_FILE}" ]] ; then
  __loge "ERROR: The flat file cannot be accessed: ${FLAT_NOTES_FILE}."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 ## Checks the flat file if exist.
 if [[ "${FLAT_NOTE_COMMENTS_FILE}" != "" ]] \
   && [[ ! -r "${FLAT_NOTE_COMMENTS_FILE}" ]] ; then
  __loge "ERROR: The flat file cannot be accessed: ${FLAT_NOTE_COMMENTS_FILE}."
  exit "${ERROR_INVALID_ARGUMENT}"
 fi
 __log_finish
 set -e
}

# Drop check tables.
function __dropCheckTables {
 __log_start
 __logi "Droping check tables."
 psql -d "${DBNAME}" << EOF
  DROP TABLE IF EXISTS note_comments_check;
  DROP TABLE IF EXISTS notes_check;
EOF
 __log_finish
}

# Creates check tables that receives the whole history.
function __createCheckTables {
 __log_start
 __logi "Creating tables"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  CREATE TABLE notes_check (
   note_id INTEGER NOT NULL,
   latitude DECIMAL NOT NULL,
   longitude DECIMAL NOT NULL,
   created_at TIMESTAMP NOT NULL,
   status note_status_enum,
   closed_at TIMESTAMP,
   id_country INTEGER
  );

  CREATE TABLE note_comments_check (
   note_id INTEGER NOT NULL,
   event note_event_enum NOT NULL,
   created_at TIMESTAMP NOT NULL,
   id_user INTEGER,
   username VARCHAR(256)
  );
EOF
 __log_finish
}

# Downloads the notes from the planet.
function __downloadPlanetNotes {
 __log_start
 # Download Planet notes.
 __loge "Retrieving Planet notes file..."
 wget -O "${PLANET_NOTES_FILE}.bz2" \
   "https://planet.openstreetmap.org/notes/${PLANET_NOTES_NAME}.bz2"

 if [[ ! -r "${PLANET_NOTES_FILE}.bz2" ]] ; then
  __loge "ERROR: Downloading notes file."
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
 # XML Schema.
 cat << EOF > "${XMLSCHEMA_PLANET_NOTES}"
<?xml version="1.0"?>
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">

  <!-- Attributes for Notes -->
  <xs:attributeGroup name="attributesNotes">
    <xs:attribute name="id" use="required">
      <xs:simpleType>
        <xs:restriction base="xs:integer">
          <xs:minInclusive value="1"/>
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

    <xs:attribute name="lon" use="required">
      <xs:simpleType>
        <xs:restriction base="xs:decimal">
          <xs:fractionDigits value="7"/>
          <xs:minInclusive value="-180"/>
          <xs:maxInclusive value="180"/>
        </xs:restriction>
      </xs:simpleType>
    </xs:attribute>

    <xs:attribute name="created_at" use="required">
      <xs:simpleType>
        <xs:restriction base="xs:string">
          <xs:pattern value="20[0-3][0-9]-[0-1][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z"/>
        </xs:restriction>
      </xs:simpleType>
    </xs:attribute>

    <xs:attribute name="closed_at" use="optional">
      <xs:simpleType>
        <xs:restriction base="xs:string">
          <xs:pattern value="20[0-3][0-9]-[0-1][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z"/>
        </xs:restriction>
      </xs:simpleType>
    </xs:attribute>
  </xs:attributeGroup>

  <!-- Attrbitues for Comments -->
  <xs:attributeGroup name="attributesComments">
    <xs:attribute name="action" use="required">
      <xs:simpleType>
        <xs:restriction base="xs:string">
          <xs:enumeration value="opened"/>
          <xs:enumeration value="closed"/>
          <xs:enumeration value="reopened"/>
          <xs:enumeration value="commented"/>
          <xs:enumeration value="hidden"/>
        </xs:restriction>
      </xs:simpleType>
    </xs:attribute>

    <xs:attribute name="timestamp" use="required">
      <xs:simpleType>
        <xs:restriction base="xs:string">
          <xs:pattern value="20[0-3][0-9]-[0-1][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z"/>
        </xs:restriction>
      </xs:simpleType>
    </xs:attribute>

    <xs:attribute name="uid" use="optional">
      <xs:simpleType>
        <xs:restriction base="xs:integer">
          <xs:minInclusive value="1"/>
        </xs:restriction>
      </xs:simpleType>
    </xs:attribute>

    <xs:attribute name="user" use="optional">
      <xs:simpleType>
        <xs:restriction base="xs:string">
          <xs:minLength value="1"/>
        </xs:restriction>
      </xs:simpleType>
    </xs:attribute>
  </xs:attributeGroup>

  <!-- Elements for Comments -->
  <xs:element name="comment">
    <xs:complexType>
      <xs:simpleContent>
        <xs:extension base="xs:string">
          <xs:attributeGroup ref="attributesComments"/>
        </xs:extension>
      </xs:simpleContent>
    </xs:complexType>
  </xs:element>

  <!-- Elements for Notes -->
  <xs:element name="note">
    <xs:complexType>
      <xs:sequence>
        <xs:element ref="comment" maxOccurs="unbounded" minOccurs="0"/>
        <!-- There are a couple of notes that do not have comments -->
        <!-- 1555586 and 1555588 -->
      </xs:sequence>
      <xs:attributeGroup ref="attributesNotes"/>
    </xs:complexType>
  </xs:element>

  <!-- Root tag -->
  <xs:element name="osm-notes">
    <xs:complexType>
      <xs:sequence>
        <xs:element ref="note" maxOccurs="unbounded" minOccurs="1"/>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>
EOF

 xmllint --noout --schema "${XMLSCHEMA_PLANET_NOTES}" "${PLANET_NOTES_FILE}.xml"

 rm -f "${XMLSCHEMA_PLANET_NOTES}"
 __log_finish
}

# Creates the XSLT files and process the XML files with them.
function __convertPlanetNotesToFlatFile {
 __log_start
 # Process the notes file.
 # XSLT transformations.
 cat << EOF > "${XSLT_NOTES_FILE}"
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:strip-space elements="*"/>
<xsl:output method="text" />
<xsl:template match="/">
 <xsl:for-each select="osm-notes/note"><xsl:value-of select="@id"/>,<xsl:value-of select="@lat"/>,<xsl:value-of select="@lon"/>,"<xsl:value-of select="@created_at"/>",<xsl:choose><xsl:when test="@closed_at != ''">"<xsl:value-of select="@closed_at"/>","close"
</xsl:when><xsl:otherwise>,"open"<xsl:text>
</xsl:text></xsl:otherwise></xsl:choose>
 </xsl:for-each>
</xsl:template>
</xsl:stylesheet>
EOF

 cat << EOF > "${XSLT_NOTE_COMMENTS_FILE}"
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:strip-space elements="*"/>
<xsl:output method="text" />
<xsl:template match="/">
 <xsl:for-each select="osm-notes/note">
 <xsl:variable name="note_id"><xsl:value-of select="@id"/></xsl:variable>
  <xsl:for-each select="comment">
<xsl:choose> <xsl:when test="@uid != ''"> <xsl:copy-of select="\$note_id" />,'<xsl:value-of select="@action" />','<xsl:value-of select="@timestamp"/>',<xsl:value-of select="@uid"/>,'<xsl:value-of select="replace(@user,'''','''''')"/>'<xsl:text>
</xsl:text></xsl:when><xsl:otherwise>
<xsl:copy-of select="\$note_id" />,'<xsl:value-of select="@action" />','<xsl:value-of select="@timestamp"/>',,<xsl:text>
</xsl:text></xsl:otherwise> </xsl:choose>
  </xsl:for-each>
 </xsl:for-each>
</xsl:template>
</xsl:stylesheet>
EOF

 # Converts the XML into a flat file in CSV format.
 __logi "Processing notes from XML"
 java -Xmx6000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
   -s:"${PLANET_NOTES_FILE}.xml" -xsl:"${XSLT_NOTES_FILE}" -o:"${OUTPUT_NOTES_FILE}"
 __logi "Processing comments from XML"
 java -Xmx6000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
   -s:"${PLANET_NOTES_FILE}.xml" -xsl:"${XSLT_NOTE_COMMENTS_FILE}" \
   -o:"${OUTPUT_NOTE_COMMENTS_FILE}"
 __log_finish
}

# Loads new notes from check.
function __loadCheckNotes {
 __log_start
 # Loads the data in the database.
 # Adds a column to include the country where it belongs.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  TRUNCATE TABLE notes_check;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Uploading check notes' AS Text;
  COPY notes_check (note_id, latitude, longitude, created_at, closed_at, status)
    FROM '${OUTPUT_NOTES_FILE}' csv;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on notes check' as Text;
  ANALYZE notes_check;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Counting check notes' AS Text;
  SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1),
    'Uploaded check notes' AS Type FROM notes_check;

  TRUNCATE TABLE note_comments_check;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Uploading check comments' AS Text;
  COPY note_comments_check FROM '${OUTPUT_NOTE_COMMENTS_FILE}' csv
    DELIMITER ',' QUOTE '''';
  SELECT CURRENT_TIMESTAMP AS Processing, 'Statistics on comments check' as Text;
  ANALYZE note_comments_check;
  SELECT CURRENT_TIMESTAMP AS Processing, 'Counting check comments' AS Text;
  SELECT CURRENT_TIMESTAMP AS Processing, COUNT(1),
    'Uploaded check comments' AS Type FROM note_comments_check;
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

# Cleans files generated during the process.
function __cleanNotesFiles {
 __log_start
 rm -f "${XSLT_NOTES_FILE}" "${XSLT_NOTE_COMMENTS_FILE}" \
   "${PLANET_NOTES_FILE}.xml" "${OUTPUT_NOTES_FILE}" \
   "${OUTPUT_NOTE_COMMENTS_FILE}"
 __log_finish
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
} >> "${LOG_FILE}" 2>&1

# Sets the trap in case of any signal.
__trapOn
if [[ "${PROCESS_TYPE}" != "--flatfile" ]] ; then
 exec 7> "${LOCK}"
 __logw "Validating single execution." | tee -a "${LOG_FILE}"
 flock -n 7
fi

{
 __dropCheckTables
 __createCheckTables
 __downloadPlanetNotes
 __validatePlanetNotesXMLFile
 __convertPlanetNotesToFlatFile
 __loadCheckNotes
 __analyzeAndVacuum
 __cleanNotesFiles
 __logw "Ending process"
} >> "${LOG_FILE}" 2>&1

mv "${LOG_FILE}" "/tmp/${BASENAME}_$(date +%Y-%m-%d_%H-%M-%S || true).log"
rmdir "${TMP_DIR}"

