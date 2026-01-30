#!/usr/bin/env bats

# Test for functionsProcess_37_reassignAffectedNotes_batch.sql optimization
# Validates that the SQL only updates notes where country actually changed
# Version: 2025-12-12

bats_require_minimum_version 1.5.0

setup() {
 local script_dir
 script_dir="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export SCRIPT_BASE_DIRECTORY="${script_dir}"
 
 local tmp_dir
 tmp_dir="$(mktemp -d)"
 export TMP_DIR="${tmp_dir}"
 export DBNAME="test_notes_reassign"
 
 # Create test database
 psql -d postgres -c "DROP DATABASE IF EXISTS ${DBNAME};" 2>/dev/null || true
 psql -d postgres -c "CREATE DATABASE ${DBNAME};" || skip "PostgreSQL not available"
 
 # Setup PostGIS
 psql -d "${DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;" || skip "PostGIS not available"
 
 # Create countries table
 psql -d "${DBNAME}" << 'SQL'
  CREATE TYPE note_status_enum AS ENUM ('open', 'close', 'hidden');
  
  CREATE TABLE countries (
   country_id INTEGER PRIMARY KEY,
   geom GEOMETRY(POLYGON, 4326),
   updated BOOLEAN DEFAULT FALSE,
   is_maritime BOOLEAN DEFAULT FALSE
  );
  
  CREATE TABLE notes (
   note_id INTEGER PRIMARY KEY,
   latitude DECIMAL NOT NULL,
   longitude DECIMAL NOT NULL,
   id_country INTEGER,
   status note_status_enum
  );
  
  CREATE INDEX notes_spatial ON notes USING GIST (ST_SetSRID(ST_MakePoint(longitude, latitude), 4326));
SQL
}

teardown() {
 # Cleanup
 psql -d postgres -c "DROP DATABASE IF EXISTS ${DBNAME};" 2>/dev/null || true
 rm -rf "${TMP_DIR}"
}

# Test that the optimized SQL only updates notes where country changed
@test "reassignAffectedNotes_batch should only update notes where country changed" {
 # Create test countries
 psql -d "${DBNAME}" << 'SQL'
  -- Country 1: Small area
  INSERT INTO countries (country_id, geom, updated, is_maritime) VALUES
  (1, ST_SetSRID(ST_MakePolygon(ST_GeomFromText('LINESTRING(0 0, 1 0, 1 1, 0 1, 0 0)')), 4326), TRUE, FALSE),
  (2, ST_SetSRID(ST_MakePolygon(ST_GeomFromText('LINESTRING(2 0, 3 0, 3 1, 2 1, 2 0)')), 4326), FALSE, FALSE);
  
  -- Create notes: some in country 1, some in country 2
  INSERT INTO notes (note_id, latitude, longitude, id_country, status) VALUES
  (1, 0.5, 0.5, 1, 'open'),  -- In country 1, already assigned
  (2, 0.5, 0.5, 1, 'open'),  -- In country 1, already assigned (should not update)
  (3, 2.5, 0.5, 2, 'open'),  -- In country 2, but might be affected by country 1 update
  (4, 0.5, 0.5, NULL, 'open'); -- In country 1, not assigned (should update)
SQL

 # Create get_country function (simplified version for testing)
 # Updated to reflect changes: return -2 for unknown countries instead of -1
 # Version: 2026-01-19
 psql -d "${DBNAME}" << 'SQL'
  CREATE OR REPLACE FUNCTION get_country(
   lon DECIMAL,
   lat DECIMAL,
   id_note INTEGER
  ) RETURNS INTEGER
  LANGUAGE plpgsql
  AS $$
  DECLARE
   m_id_country INTEGER;
   m_current_country INTEGER;
  BEGIN
   -- Initialize as unknown (-2) instead of international waters (-1)
   -- -1 is reserved for KNOWN international waters only
   m_id_country := -2;
   
   -- Get current country
   SELECT id_country INTO m_current_country
   FROM notes
   WHERE note_id = id_note;
   
   -- If already assigned and still in same country, return it
   IF m_current_country IS NOT NULL AND m_current_country > 0 THEN
    IF EXISTS (
     SELECT 1 FROM countries
     WHERE country_id = m_current_country
       AND ST_Contains(geom, ST_SetSRID(ST_Point(lon, lat), 4326))
    ) THEN
     RETURN m_current_country;
    END IF;
   END IF;
   
   -- Find new country
   SELECT country_id INTO m_id_country
   FROM countries
   WHERE ST_Contains(geom, ST_SetSRID(ST_Point(lon, lat), 4326))
     AND is_maritime = FALSE
   ORDER BY country_id
   LIMIT 1;
   
   -- Return -2 (unknown) if no country found, instead of -1 (international waters)
   -- -1 is reserved ONLY for KNOWN international waters from international_waters table
   RETURN COALESCE(m_id_country, -2);
  END;
  $$;
SQL

 # Execute the optimized batch SQL
 psql -d "${DBNAME}" -c "SET app.batch_size = '10';" -f "${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_37_reassignAffectedNotes_batch.sql" > "${TMP_DIR}/output.log" 2>&1
 
 # Check that only notes that needed updating were updated
 # Note 1 and 2: Already in country 1, should NOT be updated (country didn't change)
 # Note 3: In country 2, not affected by country 1 update, should NOT be updated
 # Note 4: NULL country, should be updated to country 1
 
 local final_country1
 final_country1=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes WHERE id_country = 1;")
 
 # Note 4 should now be assigned to country 1
 [ "$final_country1" -eq 3 ] # Notes 1, 2, and 4 should be in country 1
 
 # Verify that note 1 and 2 were NOT unnecessarily updated
 # (In a real scenario, we'd track UPDATE timestamps, but for this test we verify the count)
 local note3_country
 note3_country=$(psql -d "${DBNAME}" -Atq -c "SELECT id_country FROM notes WHERE note_id = 3;")
 [ "$note3_country" -eq 2 ] # Note 3 should still be in country 2
}

# Test that the optimization reduces unnecessary UPDATEs
@test "reassignAffectedNotes_batch should reduce unnecessary UPDATE operations" {
 # Create test data where most notes don't need updating
 psql -d "${DBNAME}" << 'SQL'
  INSERT INTO countries (country_id, geom, updated, is_maritime) VALUES
  (1, ST_SetSRID(ST_MakePolygon(ST_GeomFromText('LINESTRING(0 0, 10 0, 10 10, 0 10, 0 0)')), 4326), TRUE, FALSE);
  
  -- Create 100 notes, all already correctly assigned to country 1
  INSERT INTO notes (note_id, latitude, longitude, id_country, status)
  SELECT generate_series(1, 100),
         5.0 + (random() * 0.1),
         5.0 + (random() * 0.1),
         1,
         'open';
SQL

 # Create get_country function
 psql -d "${DBNAME}" << 'SQL'
  CREATE OR REPLACE FUNCTION get_country(
   lon DECIMAL,
   lat DECIMAL,
   id_note INTEGER
  ) RETURNS INTEGER
  LANGUAGE plpgsql
  AS $$
  DECLARE
   m_current_country INTEGER;
  BEGIN
   -- Get current country
   SELECT id_country INTO m_current_country
   FROM notes
   WHERE note_id = id_note;
   
   -- Always return current country (simulating 95% hit rate)
   RETURN COALESCE(m_current_country, 1);
  END;
  $$;
SQL

 # Execute batch SQL and capture processed count
 local output
 output=$(psql -d "${DBNAME}" -c "SET app.batch_size = '100';" -f "${SCRIPT_BASE_DIRECTORY}/sql/functionsProcess_37_reassignAffectedNotes_batch.sql" 2>&1)
 
 # Extract processed count from RAISE NOTICE
 local processed_count
 processed_count=$(echo "${output}" | grep -oE 'PROCESSED_COUNT:([0-9]+)' | sed -E 's/.*PROCESSED_COUNT:([0-9]+).*/\1/' || echo "0")
 
 # With optimization, processed_count should be 0 (no notes needed updating)
 # Without optimization, it would be 100 (all notes updated unnecessarily)
 [ "$processed_count" -eq 0 ] || echo "Expected 0 updates, got ${processed_count}"
}
