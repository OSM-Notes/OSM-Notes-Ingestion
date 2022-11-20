#!/bin/bash

# This script prepares a database for note analysis, and loads the notes from
# the planet, completely or the missing ones.
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
# When running under MacOS or zsh:
# setopt interactivecomments
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
# select iter, area, count(1)
# from tries
# group by iter, area 
# order by ITER desc;
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
# order by area, count(1) desc
#
# This is the list of error codes:
# 1) Library or utility missing.
# 2) Invalid argument.
# 3) Id list cannot be downloaded, for boundary geometries.
#
# Author: Andres Gomez (AngocA)
# Version: 2022-11-18

#set -xv
set -euo pipefail
CLEAN=true

DBNAME=notes
LOG_FILE=${0%.sh}.log
COUNTRIES_FILE=countries
MARITIMES_FILE=maritimes
QUERY_FILE=query
XSLT_NOTES_FILE=notes-csv.xslt
XSLT_NOTE_COMMENTS_FILE=note_comments-csv.xslt
XMLSCHEMA_PLANET_NOTES=OSM-notes-planet-schema.xsd
OUTPUT_NOTES_FILE=output-notes.csv
OUTPUT_NOTE_COMMENTS_FILE=output-note_comments.csv
PLANET_NOTES_FILE=planet-notes-latest.osn
SAXON_JAR=${SAXON_CLASSPATH:-.}/saxon-he-11.4.jar
SECONDS_TO_WAIT=5
LOOP_SIZE=10000
MAX_NOTE_ID=3500000
PROCESS_TYPE=${1:-}

function checkPrereqs {
 if [ "${PROCESS_TYPE}" != "" ] && [ "${PROCESS_TYPE}" != "--base" ]  ; then
  echo "ERROR: Invalid parameter. It should be:"
  echo " * Empty string, nothing."
  echo " * --base"
  echo " * --boundaries"
  exit 2
 fi
 set +e
 # Checks prereqs.
 ## PostgreSQL
 if ! psql --version > /dev/null 2>&1 ; then
  echo "ERROR: PostgreSQL is missing."
  exit 1
 fi
 ## Wget
 if ! wget --version > /dev/null 2>&1 ; then
  echo "ERROR: Wget is missing."
  exit 1
 fi
 ## osmtogeojson
 if ! osmtogeojson --version > /dev/null 2>&1 ; then
  echo "ERROR: osmtogeojson is missing."
  exit 1
 fi
 ## gdal ogr2ogr
 if ! ogr2ogr --version > /dev/null 2>&1 ; then
  echo "ERROR: ogr2ogr is missing."
  exit 1
 fi
 ## cURL
 if ! curl --version > /dev/null 2>&1 ; then
  echo "ERROR: curl is missing."
  exit 1
 fi
 ## Block-sorting file compressor
 if ! bzip2 --help > /dev/null 2>&1 ; then
  echo "ERROR: bzip2 is missing."
  exit 1
 fi
 ## Java
 if ! java --version > /dev/null 2>&1 ; then
  echo "ERROR: Java JRE is missing."
  exit 1
 fi
 ## XML lint
 if ! xmllint --version > /dev/null 2>&1 ; then
  echo "ERROR: XMLlint is missing."
  exit 1
 fi
 ## Saxon Jar
 if [ ! -r "${SAXON_JAR}" ] ; then
  echo "ERROR: Saxon jar is missing at ${SAXON_JAR}."
  exit 1
 fi
 set -e
}

function dropBaseTables {
 echo "Droping tables."
 psql -d "${DBNAME}" << EOF
  DROP TABLE tries;
  DROP TABLE note_comments;
  DROP TABLE notes;
  DROP TYPE note_event_enum;
  DROP TYPE note_status_enum;
  DROP TABLE countries;
EOF
}

function dropSyncTables {
 echo "Droping tables."
 psql -d "${DBNAME}" << EOF
  DROP TABLE note_comments_sync;
  DROP TABLE notes_sync;
EOF
}

function createBaseTables {
 echo "Creating tables"
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
 
  CREATE TABLE notes (
   note_id INTEGER NOT NULL, -- id
   latitude DECIMAL NOT NULL,
   longitude DECIMAL NOT NULL,
   created_at TIMESTAMP NOT NULL,
   status note_status_enum,
   closed_at TIMESTAMP,
   id_country INTEGER
  );
 
  ALTER TABLE notes
   ADD CONSTRAINT pk_notes
   PRIMARY KEY (note_id);
 
  CREATE TABLE note_comments (
   note_id INTEGER NOT NULL,
   created_at TIMESTAMP NOT NULL,
   user_id INTEGER,
   event note_event_enum NOT NULL,
   username VARCHAR(256)
  );
 
  -- ToDo primary key duplicated error.
  --ALTER TABLE note_comments
  -- ADD CONSTRAINT pk_note_comments
  -- PRIMARY KEY (note_id, event, created_at);

  ALTER TABLE note_comments
   ADD CONSTRAINT fk_notes
   FOREIGN KEY (note_id)
   REFERENCES notes (note_id);

  CREATE TABLE tries (
   area VARCHAR(20),
   iter INTEGER,
   id_note INTEGER,
   id_country INTEGER
  );
EOF
}

function createSyncTables {
 echo "Creating tables"
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF 
  CREATE TABLE notes_sync (
   note_id INTEGER NOT NULL,
   latitude DECIMAL NOT NULL,
   longitude DECIMAL NOT NULL,
   created_at TIMESTAMP NOT NULL,
   closed_at TIMESTAMP,
   status note_status_enum,
   id_country INTEGER
  );
 
  CREATE TABLE note_comments_sync (
   note_id INTEGER NOT NULL,
   event note_event_enum NOT NULL,
   created_at TIMESTAMP NOT NULL,
   user_id INTEGER,
   username VARCHAR(256)
  );
EOF
}

function processCountries {
 echo "DELETE FROM countries" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1 

 # Extracts ids of all country relations into a JSON.
 echo "Obtaining the countries ids."
 cat << EOF > "${QUERY_FILE}"
  [out:csv(::id)];
  (
    relation["type"="boundary"]["boundary"="administrative"]["admin_level"="2"];
  );
  out ids;
EOF

 set +e
 wget -O "${COUNTRIES_FILE}" --post-file="${QUERY_FILE}" \
   "https://overpass-api.de/api/interpreter"
 RET=${?}
 set -e
 if [ "${RET}" -ne 0 ] ; then
  echo "ERROR: Country list could not be downloaded."
  exit 3
 fi
 
 tail -n +2 "${COUNTRIES_FILE}" > "${COUNTRIES_FILE}.tmp"
 mv "${COUNTRIES_FILE}.tmp" "${COUNTRIES_FILE}"
 
 # Adds the Gaza Strip, as it is not at country level.
 echo "1703814" "${COUNTRIES_FILE}"
 
 echo "Retrieving the countries' boundaries."
 while read -r LINE ; do
  ID=$(echo "${LINE}" | awk '{print $1}')
  echo "----> ${ID} $(date)"
  cat << EOF > "${QUERY_FILE}"
   [out:json];
   rel(${ID});
   (._;>;);
   out; 
EOF
  echo "Retrieving shape."
  wget -O "${ID}.json" --post-file="${QUERY_FILE}" \
    "https://overpass-api.de/api/interpreter"
 
  echo "Converting into geoJSON."
  osmtogeojson "${ID}.json" > "${ID}.geojson"
  set +e
  COUNTRY=$(grep "\"name\":" "${ID}.geojson" | head -1 \
    | awk -F\" '{print $4}' | sed "s/'/''/")
  COUNTRY_ES=$(grep "\"name:es\":" "${ID}.geojson" | head -1 \
    | awk -F\" '{print $4}' | sed "s/'/''/")
  COUNTRY_EN=$(grep "\"name:en\":" "${ID}.geojson" | head -1 \
    | awk -F\" '{print $4}' | sed "s/'/''/")
  set -e
 
  # Taiwan cannot be imported directly. Thus, a simplification is done.
  # ERROR:  row is too big: size 8616, maximum size 8160
  grep -v "official_name" "${ID}.geojson" | \
    grep -v "alt_name" > "${ID}.geojson-new"
  mv "${ID}.geojson-new" "${ID}.geojson"
 
  echo "Importing into Postgres."
  ogr2ogr -f "PostgreSQL" PG:"dbname=${DBNAME} user=${USER}" "${ID}.geojson" \
    -nln import -overwrite
 
  echo "Inserting into final table."
  if [ "${ID}" -ne 16239 ] ; then
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
  echo "${STATEMENT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1 
 
  if [ -n "${CLEAN}" ] && [ "${CLEAN}" = true ] ; then
   rm -f "${ID}.json" "${ID}.geojson"
  fi
  echo "Waiting ${SECONDS_TO_WAIT} seconds..."
  sleep "${SECONDS_TO_WAIT}"
 done < "${COUNTRIES_FILE}"
}

function processMaritimes {
 # Extracts ids of all EEZ relations into a JSON.
 echo "Obtaining the eez ids."
 cat << EOF > "${QUERY_FILE}"
  [out:csv(::id)];
  (
    relation["border_type"]["border_type"~"contiguous|eez"];
  );
  out ids;
EOF

 set +e
 wget -O "${MARITIMES_FILE}" --post-file="${QUERY_FILE}" \
   "https://overpass-api.de/api/interpreter"
 RET=${?}
 set -e
 if [ "${RET}" -ne 0 ] ; then
  echo "ERROR: Maritimes border list could not be downloaded."
  exit 3
 fi
 
 tail -n +2 "${MARITIMES_FILE}" > "${MARITIMES_FILE}.tmp"
 mv "${MARITIMES_FILE}.tmp" "${MARITIMES_FILE}"
 
 echo "Retrieving the maritimes' boundaries."
 while read -r LINE ; do
  ID=$(echo "${LINE}" | awk '{print $1}')
  echo "----> ${ID} $(date)" 
  cat << EOF > "${QUERY_FILE}"
   [out:json];
   rel(${ID});
   (._;>;);
   out; 
EOF
  echo "Retrieving shape."
  wget -O "${ID}.json" --post-file="${QUERY_FILE}" \
    "https://overpass-api.de/api/interpreter"
 
  echo "Converting into geoJSON."
  osmtogeojson "${ID}.json" > "${ID}.geojson"
  set +e
  NAME=$(grep "\"name\":" "${ID}.geojson" | head -1 \
    | awk -F\" '{print $4}' | sed "s/'/''/")
  NAME_ES=$(grep "\"name:es\":" "${ID}.geojson" | head -1 \
    | awk -F\" '{print $4}' | sed "s/'/''/")
  NAME_EN=$(grep "\"name:en\":" "${ID}.geojson" | head -1 \
    | awk -F\" '{print $4}' | sed "s/'/''/")
  set -e
 
  echo "Importing into Postgres."
  ogr2ogr -f "PostgreSQL" PG:"dbname=${DBNAME} user=${USER}" "${ID}.geojson" \
    -nln import -overwrite
 
  echo "Inserting into final table."
  STATEMENT="INSERT INTO countries (country_id, country_name, country_name_es, 
    country_name_en, geom) select ${ID}, '${NAME}', '${NAME_ES:-${NAME}}', 
    '${NAME_EN:-${NAME}}', ST_Union(wkb_geometry) from import group by 1"
  echo "${STATEMENT}" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1 
 
  if [ -n "${CLEAN}" ] && [ "${CLEAN}" = true ] ; then
   rm -f "${ID}.json" "${ID}.geojson"
  fi
  echo "Waiting ${SECONDS_TO_WAIT} seconds..."
  sleep "${SECONDS_TO_WAIT}"
 done < "${MARITIMES_FILE}"
}

function cleanPartial {
 if [ -n "${CLEAN}" ] && [ "${CLEAN}" = true ] ; then
  rm query "${COUNTRIES_FILE}" "${MARITIMES_FILE}"
  echo "DROP TABLE import" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1 
 fi
}

function downloadPlanetNotes {
 # Download Planet notes.
 echo "Retrieving Planet notes file... $(date)"
 curl --output planet-notes-latest.osn.bz2 \
   "https://planet.openstreetmap.org/notes/${PLANET_NOTES_FILE}.bz2"
 
 echo "Extracting Planet notes..."
 bzip2 -d "${PLANET_NOTES_FILE}.bz2"
 mv "${PLANET_NOTES_FILE}" "${PLANET_NOTES_FILE}.xml"
}

function validatePlanetNotesXMLFile {
 xmllint --noout --schema "${XMLSCHEMA_PLANET_NOTES}" "${PLANET_NOTES_FILE}.xml"
}

function convertPlanetNotesToFlatFile {
 # Process the notes file.
 # XSLT transformations.
 cat << EOF > "${XSLT_NOTES_FILE}"
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
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
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
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
 java -Xmx6000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
   -s:"${PLANET_NOTES_FILE}.xml" -xsl:"${XSLT_NOTES_FILE}" -o:"${OUTPUT_NOTES_FILE}"
 java -Xmx6000m -cp "${SAXON_JAR}" net.sf.saxon.Transform \
   -s:"${PLANET_NOTES_FILE}.xml" -xsl:"${XSLT_NOTE_COMMENTS_FILE}" \
   -o:"${OUTPUT_NOTE_COMMENTS_FILE}"
}

function loadBaseNotes {
 # Loads the data in the database.
 # Adds a column to include the country where it belongs.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  COPY notes (note_id, latitude, longitude, created_at, closed_at, status)
    FROM '$(pwd)/${OUTPUT_NOTES_FILE}' csv;
  COPY note_comments FROM '$(pwd)/${OUTPUT_NOTE_COMMENTS_FILE}' csv
    DELIMITER ',' QUOTE '''';
EOF
}

function loadSyncNotes {
 # Loads the data in the database.
 # Adds a column to include the country where it belongs.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  DELETE FROM notes_sync;
  COPY notes_sync (note_id, latitude, longitude, created_at, closed_at, status)
    FROM '$(pwd)/${OUTPUT_NOTES_FILE}' csv;
  DELETE FROM note_comments_sync;
  COPY note_comments_sync FROM '$(pwd)/${OUTPUT_NOTE_COMMENTS_FILE}' csv
    DELIMITER ',' QUOTE '''';
EOF
}

function createsFunctionToGetCountry {
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
   IF (-5 < lat AND lat < 5 AND 4 > lon AND lon > -4) THEN
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
} 

function createsProcedures {
 # Creates a procedure that inserts a note.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
 CREATE OR REPLACE PROCEDURE insert_note (
   m_note_id INTEGER,
   m_latitude DECIMAL,
   m_longitude DECIMAL,
   m_created_at TIMESTAMP,
   m_closed_at TIMESTAMP,
   m_status note_status_enum
 )
 LANGUAGE plpgsql
 AS \$proc\$
  DECLARE
   id_country INTEGER;
  BEGIN
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
  );
 END
 \$proc\$
EOF

 # Creates a procedure that inserts a note comment.
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
 CREATE OR REPLACE PROCEDURE insert_note_comment (
   m_note_id INTEGER,
   m_event note_event_enum,
   m_created_at TIMESTAMP,
   m_user_id INTEGER,
   m_username VARCHAR(256)
 )
 LANGUAGE plpgsql
 AS \$proc\$
  BEGIN
   INSERT INTO note_comments (
   note_id,
   event,
   created_at,
   user_id,
   username
  ) VALUES (
   m_note_id,
   m_event,
   m_created_at,
   m_user_id,
   m_username
  );
  IF (m_event = 'closed') THEN
   UPDATE notes
     SET status = 'close',
     closed_at = m_created_at
     WHERE note_id = m_note_id;
  ELSIF (m_event = 'reopened') THEN
   UPDATE notes
     SET status = 'open',
     closed_at = NULL
     WHERE note_id = m_note_id;
  END IF;
 END
 \$proc\$
EOF
}

function removeDuplicates {
 psql -d "${DBNAME}" -v ON_ERROR_STOP=1 << EOF
  DELETE FROM notes_sync
    WHERE note_id IN (SELECT note_id FROM notes);
  DO
  \$\$
  DECLARE
   r RECORD;
   closed_time VARCHAR(100);
  BEGIN
   FOR r IN
    SELECT note_id, latitude, longitude, created_at, closed_at, status
    FROM notes_sync
   LOOP
    closed_time := 'TO_DATE(''' || r.closed_at
      || ''', ''YYYY-MM-DD HH24:MI:SS'')';
    EXECUTE 'CALL insert_note (' || r.note_id || ', ' || r.latitude || ', '
      || r.longitude || ', ' 
      || 'TO_DATE(''' || r.created_at || ''', ''YYYY-MM-DD HH24:MI:SS''), '
      || COALESCE (closed_time, 'NULL') || ','
      || '''' || r.status || '''::note_status_enum)';
   END LOOP;
  END;
  \$\$;

  DELETE FROM note_comments_sync
    WHERE (note_id, event, created_at) IN
      (SELECT note_id, event, created_at FROM note_comments);

  DO
  \$\$
  DECLARE
   r RECORD;
   created_time VARCHAR(100);
  BEGIN
   FOR r IN
    SELECT note_id, event, created_at, user_id, username
    FROM note_comments_sync
   LOOP
    created_time := 'TO_DATE(''' || r.created_at
      || ''', ''YYYY-MM-DD HH24:MI:SS'')';
    EXECUTE 'CALL insert_note_comment (' || r.note_id || ', '
      || '''' || r.event || '''::note_event_enum, '
      || COALESCE (created_time, 'NULL') || ', ' 
      || COALESCE (r.user_id || '', 'NULL') || ', '
      || COALESCE ('''' || r.username || '''', 'NULL') || ')';
   END LOOP;
  END
  \$\$;

BEGIN
EOF
}

function cleanNotesFiles {
 if [ -n "${CLEAN}" ] && [ "${CLEAN}" = true ] ; then
  rm "${XSLT_NOTES_FILE}" "${XSLT_NOTE_COMMENTS_FILE}" \
    "${PLANET_NOTES_FILE}.xml" "${OUTPUT_NOTES_FILE}" \
    "${OUTPUT_NOTE_COMMENTS_FILE}" 
 fi
}

function organizeAreas {
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
    'NEAFC (EEZ)', 'South Africa (EEZ)',
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
}

# ToDo Parallelize.
function getLocationNotes {
 for i in $(seq -f %1.0f ${LOOP_SIZE} ${LOOP_SIZE} "${MAX_NOTE_ID}") ; do
  echo "${i} $(date)"
  echo "UPDATE notes
    SET id_country = get_country(longitude, latitude, note_id)
    WHERE $((i - LOOP_SIZE)) <= note_id AND note_id <= ${i}
    AND id_country IS NULL" | psql -d "${DBNAME}" -v ON_ERROR_STOP=1 
 done
}

checkPrereqs
{
 echo "$(date) Starting process"
 if [ "${PROCESS_TYPE}" == "--base" ] ; then
  dropSyncTables
  dropBaseTables
  createBaseTables
 else
  dropSyncTables
  createSyncTables
 fi
 if [ "${PROCESS_TYPE}" == "--base" ] \
   || [ "${PROCESS_TYPE}" == "--boundaries" ] ; then
  processCountries
  processMaritimes
  cleanPartial
  if [ "${PROCESS_TYPE}" == "--boundaries" ] ; then
   echo "$(date) Ending process"
   exit 0
  fi
 fi
 downloadPlanetNotes
 validatePlanetNotesXMLFile
 convertPlanetNotesToFlatFile
 createsFunctionToGetCountry
 createsProcedures
 if [ "${PROCESS_TYPE}" == "--base" ] ; then
  loadBaseNotes
 else
  loadSyncNotes
  removeDuplicates
  dropSyncTables
 fi
 cleanNotesFiles
 organizeAreas
 getLocationNotes
 echo "$(date) Ending process"
} >> "${LOG_FILE}" 2>&1

if [ -n "${CLEAN}" ] && [ "${CLEAN}" = true ] ; then
 rm -f "${LOG_FILE}"
fi
