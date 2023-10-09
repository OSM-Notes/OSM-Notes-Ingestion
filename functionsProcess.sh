#!/bin/bash

# This is a script for sourcing from another scripts. It contains functions
# used in different scripts
#
# Author: Andres Gomez (AngocA)
# Version: 2023-10-07

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
function log() { :; }
function log_trace() { :; }
function log_debug() { :; }
function log_info() { :; }
function log_warn() { :; }
function log_error() { :; }
function log_fatal() { :; }
function log_start() { :; }
function log_finish() { :; }

function __log() {  log        ${@}; }
function __logt() { log_trace  ${@}; }
function __logd() { log_debug  ${@}; }
function __logi() { log_info   ${@}; }
function __logw() { log_warn   ${@}; }
function __loge() { log_error  ${@}; }
function __logf() {  log_fatal ${@}; }
function __log_start() {  log_start; }
function __log_finish() { log_finish; }

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
  set_log_level "${LOG_LEVEL}"
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

   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'logs'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: logs';
   END IF;

   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'tries'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: tries';
   END IF;
  END;
  \$\$;
EOF
 RET=${?}
 set -e
 if [[ "${RET}" -ne 0 ]] ; then
  __createBaseTables
 fi
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

# Creates a function to get the country or maritime area from coordinates.
function __createsFunctionToGetCountry {
 __log_start
 # Creates a function that performs a basic triage according to its longitude:
 # * -180 - -30: Americas.
 # * -30 - 25: West Europe and West Africa.
 # * 25 - 65: Middle East, East Africa and Russia.
 # * 65 - 180: Southeast Asia and Oceania.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
 CREATE OR REPLACE FUNCTION get_country (
   lon DECIMAL,
   lat DECIMAL,
   id_note INTEGER
 ) RETURNS INTEGER
 LANGUAGE plpgsql
 AS \$func\$
  DECLARE
   id_country INTEGER;
   f RECORD;
   contains BOOLEAN;
   iter INTEGER;
   area VARCHAR(20);
  BEGIN
   id_country := -1;
   iter := 1;
   IF (-5 < lat AND lat < 4.53 AND 4 > lon AND lon > -4) THEN
    area := 'Null Island';
   ELSIF (lon < -30) THEN -- Americas
    area := 'Americas';
    FOR f IN
      SELECT geom, country_id
      FROM countries
      ORDER BY americas NULLS LAST
     LOOP
      contains := ST_Contains(f.geom, ST_SetSRID(ST_Point(lon, lat), 4326));
      IF (contains) THEN
       id_country := f.country_id;
       EXIT;
      END IF;
      iter := iter + 1;
     END LOOP;
   ELSIF (lon < 25) THEN -- Europe & part of Africa
    area := 'Europe/Africa';
    FOR f IN
      SELECT geom, country_id
      FROM countries
      ORDER BY europe NULLS LAST
     LOOP
      contains := ST_Contains(f.geom, ST_SetSRID(ST_Point(lon, lat), 4326));
      IF (contains) THEN
       id_country := f.country_id;
       EXIT;
      END IF;
      iter := iter + 1;
     END LOOP;
   ELSIF (lon < 65) THEN -- Russia, Middle East & part of Africa
    area := 'Russia/Middle east';
    FOR f IN
      SELECT geom, country_id
      FROM countries
      ORDER BY russia_middle_east NULLS LAST
     LOOP
      contains := ST_Contains(f.geom, ST_SetSRID(ST_Point(lon, lat), 4326));
      IF (contains) THEN
       id_country := f.country_id;
       EXIT;
      END IF;
      iter := iter + 1;
     END LOOP;
   ELSE
    area := 'Asia/Oceania';
    FOR f IN
      SELECT geom, country_id
      FROM countries
      ORDER BY asia_oceania NULLS LAST
     LOOP
      contains := ST_Contains(f.geom, ST_SetSRID(ST_Point(lon, lat), 4326));
      IF (contains) THEN
       id_country := f.country_id;
       EXIT;
      END IF;
      iter := iter + 1;
     END LOOP;
   END IF;
   INSERT INTO tries VALUES (area, iter, id_note, id_country);
   RETURN id_country;
  END
 \$func\$
EOF
 __log_finish
}

# Creates procedures to insert notes and comments.
function __createsProcedures {
 __log_start
 # Creates a procedure that inserts a note.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
 CREATE OR REPLACE PROCEDURE insert_note (
   m_note_id INTEGER,
   m_latitude DECIMAL,
   m_longitude DECIMAL,
   m_created_at TIMESTAMP WITH TIME ZONE,
   m_closed_at TIMESTAMP WITH TIME ZONE,
   m_status note_status_enum
 )
 LANGUAGE plpgsql
 AS \$proc\$
  DECLARE
   id_country INTEGER;
  BEGIN
   INSERT INTO logs (message) VALUES ('Inserting note: ' || m_note_id);
   id_country := get_country(m_longitude, m_latitude, m_note_id);

   INSERT INTO notes (
    note_id,
    latitude,
    longitude,
    created_at,
    closed_at,
    status,
    id_country
   ) VALUES (
    m_note_id,
    m_latitude,
    m_longitude,
    m_created_at,
    m_closed_at,
    m_status,
    id_country
   ) ON CONFLICT (note_id) DO UPDATE
     SET conflict = Current_timestamp || '-' || m_status;
    -- DO NOTHING;
   -- TODO Insertar nota en la lista de notas a analizar
  END
 \$proc\$
EOF

 # Creates a procedure that inserts a note comment.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
 CREATE OR REPLACE PROCEDURE insert_note_comment (
   m_note_id INTEGER,
   m_event note_event_enum,
   m_created_at TIMESTAMP WITH TIME ZONE,
   m_id_user INTEGER,
   m_username VARCHAR(256)
 )
 LANGUAGE plpgsql
 AS \$proc\$
  BEGIN
   INSERT INTO logs (message) VALUES ('Inserting comment: ' || m_note_id || '-'
     || m_event);

   -- Insert a new username, or update the username to an existing userid.
   IF (m_id_user IS NOT NULL AND m_username IS NOT NULL) THEN
    INSERT INTO users (
     user_id,
     username
    ) VALUES (
     m_id_user,
     m_username
    ) ON CONFLICT (user_id) DO UPDATE
     SET username = EXCLUDED.username;
   END IF;

   INSERT INTO note_comments (
    note_id,
    event,
    created_at,
    id_user
   ) VALUES (
    m_note_id,
    m_event,
    m_created_at,
    m_id_user
   ) ON CONFLICT 
    --(note_id) DO UPDATE
    -- SET conflict = Current_timestamp || '-' || m_event;
    DO NOTHING;

   IF (m_event = 'closed') THEN
    UPDATE notes
      SET status = 'close',
      closed_at = m_created_at
      WHERE note_id = m_note_id;
    INSERT INTO logs (message) VALUES ('Close note ' || m_note_id);
   ELSIF (m_event = 'reopened') THEN
    UPDATE notes
      SET status = 'open',
      closed_at = NULL
      WHERE note_id = m_note_id;
    INSERT INTO logs (message) VALUES ('Reopen note ' || m_note_id);
   ELSE
    INSERT INTO logs (message) VALUES ('Another event ' || m_note_id || '-' || m_event);
   END IF;

   -- TODO HAcer algo en los conflictos, como registrar en otra tabla.
   -- TODO Insertar en otra tabla el usuario que hay que recalcular.
   -- TODO Insertar en otra tabla el país que hay que recalcular.
  END
 \$proc\$
EOF
 __log_finish
}

# Assigns a value to each area to find it easily.
function __organizeAreas {
 __log_start
 # Insert values for representative countries in each area.

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  -- More than 200K
  UPDATE countries SET americas = 1 WHERE country_name_en IN ('United States');
  -- More than 50K
  UPDATE countries SET americas = 2 WHERE country_name_en IN ('Brazil',
    'Canada');
  -- More than 20K
  UPDATE countries SET americas = 3 WHERE country_name_en IN ('Argentina',
    'Mexico', 'Ecuador');
  -- More than 10K
  UPDATE countries SET americas = 4 WHERE country_name_en IN ('Peru',
    'Colombia', 'Chile', 'Cuba', 'Nicaragua', 'Bolivia');
  -- More than 5K
  UPDATE countries SET americas = 5 WHERE country_name_en IN ('Venezuela',
    'Haiti');
  -- More than 2K
  UPDATE countries SET americas = 6 WHERE country_name_en IN ('Costa Rica',
    'Guatemala', 'France', 'Dominican Republic', 'Uruguay', 'Paraguay');
  -- More than 1K
  UPDATE countries SET americas = 7 WHERE country_name_en IN (
    'Trinidad and Tobago', 'Panama', 'Honduras', 'El Salvador', 'Netherlands');
  -- Less than 1K
  UPDATE countries SET americas = 8 WHERE country_name_en IN ('Jamaica');
  -- Less than 500
  UPDATE countries SET americas = 9 WHERE country_name_en IN ('Greenland',
    'Suriname', 'Guyana', 'Belize', 'The Bahamas', 'Falkland Islands',
    'Saint Lucia', 'Barbados', 'Saint Vincent and the Grenadines', 'Tonga',
    'Cook Islands', 'Dominica', 'Grenada', 'Samoa', 'Bermuda',
    'Cayman Islands', 'Turks and Caicos Islands',
    'South Georgia and the South Sandwich Islands', 'Saint Kitts and Nevis',
    'Antigua and Barbuda', 'Russia', 'Portugal', 'British Virgin Islands',
    'New Zealand', 'Anguilla', 'Fiji', 'Pitcairn Islands', 'Montserrat',
    'Kiribati', 'Niue', 'British Overseas Territories', 'French Polynesia',
    'French Guiana', 'Aruba'
    );
  -- Maritimes areas
  UPDATE countries SET americas = 10 WHERE country_name_en IN ('Brazil (EEZ)',
    'Chile (EEZ)', 'Brazil (Contiguous Zone)', 'United States (EEZ)',
    'Colombia (EEZ)', 'Ecuador (EEZ)', 'Argentina (EEZ)', 'Guadeloupe (EEZ)',
    'Nicaragua (EEZ)', 'French Polynesia (EEZ)',
    'Contiguous Zone of the Netherlands', 'Costa Rica (EEZ)',
    'New Zealand (EEZ)');
EOF

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  -- More than 500K
  UPDATE countries SET europe = 1 WHERE country_name_en IN ('Germany');
  -- More than 200K
  UPDATE countries SET europe = 2 WHERE country_name_en IN ('France');
  -- More than 100K
  UPDATE countries SET europe = 3 WHERE country_name_en IN ('Spain',
    'United Kingdom', 'Italy', 'Poland');
  -- More than 50K
  UPDATE countries SET europe = 4 WHERE country_name_en IN ('Netherlands');
  -- More than 20K
  UPDATE countries SET europe = 5 WHERE country_name_en IN ('Belgium',
    'Austria', 'Switzerland', 'Croatia', 'Sweden', 'Czechia');
  -- More than 10K
  UPDATE countries SET europe = 6 WHERE country_name_en IN ('Greece',
    'Ireland', 'Hungary','Ukraine', 'Portugal', 'Slovakia', 'Denmark',
    'Côte d''Ivoire', 'Algeria');
  -- More than 5K
  UPDATE countries SET europe = 7 WHERE country_name_en IN ('Norway',
    'Finland', 'Romania', 'Serbia', 'Libya', 'Latvia'
    );
  -- More than 2K
  UPDATE countries SET europe = 8 WHERE country_name_en IN ('Morocco',
    'Democratic Republic of the Congo', 'Bosnia and Herzegovina', 'Bulgaria',
    'Ghana', 'Slovenia', 'Belarus', 'Kosovo', 'Iceland', 'Lithuania', 'Albania',
    'Russia', 'South Africa', 'Estonia', 'Montenegro', 'Luxembourg', 'Angola',
    'Tunisia');
  -- More than 1K
  UPDATE countries SET europe = 9 WHERE country_name_en IN ('Nigeria',
    'Togo', 'North Macedonia', 'Jersey', 'Cameroon', 'Burkina Faso',
    'Namibia', 'Senegal', 'Mali');
  -- Less than 1K
  UPDATE countries SET europe = 10 WHERE country_name_en IN ('Malta', 'Benin',
    'Niger', 'Guinea');
  -- Less than 500
  UPDATE countries SET europe = 11 WHERE country_name_en IN ('Sierra Leone',
    'Mauritania', 'Congo-Brazzaville', 'Chad', 'Cape Verde', 'Botswana',
    'Andorra', 'Guernsey', 'Isle of Man', 'Central African Republic',
    'Faroe Islands', 'Guinea-Bissau', 'Liberia', 'The Gambia', 'San Marino',
    'Gabon', 'Liechtenstein', 'Gibraltar', 'Monaco', 'Equatorial Guinea',
    'Sahrawi Arab Democratic Republic', 'Vatican City', 'Zambia',
    'São Tomé and Príncipe', 'Greenland',
    'Saint Helena, Ascension and Tristan da Cunha',
    'Sudan', 'Brazil');
  -- Maritimes areas
  UPDATE countries SET europe = 12 WHERE country_name_en IN ('Spain (EEZ)',
    'United Kingdom (EEZ)', 'Italy (EEZ)', 'Germany (EEZ)', 'Norway (EEZ)',
    'France (EEZ) - Mediterranean Sea', 'Denmark (EEZ)', 'Ireland (EEZ)',
    'Dutch Exclusive Economic Zone', 'Sweden (EEZ)',
    'Contiguous Zone of the Netherlands', 'France (Contiguous Zone)',
    'South Africa (EEZ)', 'Brazil (EEZ)', 'Belgium (EEZ)', 'Poland (EEZ)',
    'Russia (EEZ)', 'Iceland (EEZ)',
    'Fisheries protection zone around Jan Mayen',
    'South Georgia and the South Sandwich Islands',
    'Fishing territory around the Faroe Islands',
    'France (contiguous area in the Gulf of Biscay and west of English Channel)');
EOF

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  -- More than 200K
  UPDATE countries SET russia_middle_east = 1 WHERE country_name_en IN (
    'Russia');
  -- More than 50K
  UPDATE countries SET russia_middle_east = 2 WHERE country_name_en IN ('Iran',
    'Ukraine');
  -- More than 20K
  UPDATE countries SET russia_middle_east = 3 WHERE country_name_en IN (
    'Iraq', 'Belarus', 'Turkey');
  -- More than 10K
  UPDATE countries SET russia_middle_east = 4 WHERE country_name_en IN ('');
  -- More than 5K
  UPDATE countries SET russia_middle_east = 5 WHERE country_name_en IN (
    'Romania', 'Saudi Arabia', 'Georgia', 'Armenia', 'Egypt', 'Israel',
    'Finland', 'Azerbaijan', 'Democratic Republic of the Congo', 'Moldova'
    );
  -- More than 2K
  UPDATE countries SET russia_middle_east = 6 WHERE country_name_en IN (
    'United Arab Emirates', 'Cyprus', 'South Africa', 'Tanzania', 'Yemen',
    'Kazakhstan', 'Greece', 'Syria', 'Uganda', 'France', 'Ethiopia',
    'Bulgaria', 'Jordan');
  -- More than 1K
  UPDATE countries SET russia_middle_east = 7 WHERE country_name_en IN (
    'Uzbekistan', 'Lithuania', 'Oman', 'Turkmenistan', 'Kenya', 'Lebanon',
    'Madagascar', 'Latvia', 'Zimbabwe');
  -- Less than 1K
  UPDATE countries SET russia_middle_east = 8 WHERE country_name_en IN (
    'Estonia', 'Sudan', 'Kuwait', 'Somalia', 'Mozambique', 'Qatar', 'Zambia',
    'Mauritius');
  -- Less than 500
  UPDATE countries SET russia_middle_east = 9 WHERE country_name_en IN (
    'Botswana', 'Rwanda', 'Bahrain', 'Malawi', 'Seychelles', 'South Sudan',
    'Lesotho', 'Burundi', 'Eritrea', 'Norway', 'Djibouti', 'Afghanistan',
    'Comoros', 'Eswatini', 'Central African Republic', 'Pakistan',
    'Libya', 'Namibia', 'Gaza Strip');
  -- Maritimes areas
  UPDATE countries SET russia_middle_east = 10 WHERE country_name_en IN (
    'British Sovereign Base Areas', 'Fisheries protection zone around Svalbard',
    'NEAFC (EEZ)', 'South Africa (EEZ)', 'Palestinian Territories',
    'France - La Réunion - Tromelin Island (EEZ)');
EOF

 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  -- More than 20K
  UPDATE countries SET asia_oceania = 1 WHERE country_name_en IN ('Australia',
    'India', 'Russia', 'China', 'Philippines', 'Japan', 'Taiwan',
    'Indonesia');
  -- More than 10K
  UPDATE countries SET asia_oceania = 2 WHERE country_name_en IN ('Thailand',
    'South Korea', 'Vietnam', 'Malaysia');
  -- More than 5K
  UPDATE countries SET asia_oceania = 3 WHERE country_name_en IN ('New Zealand',
    'Kazakhstan', 'Uzbekistan', 'Myanmar', 'Nepal', 'Pakistan');
  -- More than 2K
  UPDATE countries SET asia_oceania = 4 WHERE country_name_en IN ('Kyrgyzstan',
    'Cambodia', 'Sri Lanka', 'Bangladesh', 'Laos', 'Singapore',
    'Tajikistan');
  -- More than 1K
  UPDATE countries SET asia_oceania = 5 WHERE country_name_en IN ('Mongolia');
  -- Less than 1K
  UPDATE countries SET asia_oceania = 6 WHERE country_name_en IN ('France',
    'Afghanistan');
  -- Less than 500
  UPDATE countries SET asia_oceania = 7 WHERE country_name_en IN ('Maldives',
    'Bhutan', 'Vanuatu', 'East Timor', 'Fiji', 'Papua New Guinea',
    'United States', 'North Korea', 'Brunei', 'Solomon Islands', 'Palau',
    'Federated States of Micronesia', 'Marshall Islands', 'Kiribati',
    'Turkmenistan', 'Tuvalu', 'Nauru');
  -- Maritimes areas
  UPDATE countries SET asia_oceania = 8 WHERE country_name_en IN (
    'Philippine (EEZ)', 'Australia (EEZ)', 'British Indian Ocean Territory',
    'New Caledonia (EEZ)', 'New Zealand (EEZ)',
    'New Zealand (Contiguous Zone)');
EOF
 __log_finish
}


