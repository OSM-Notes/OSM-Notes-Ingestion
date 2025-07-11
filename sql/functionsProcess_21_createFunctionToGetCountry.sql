-- Function to get the country where the note is located.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-23

 CREATE OR REPLACE FUNCTION get_country (
   lon DECIMAL,
   lat DECIMAL,
   id_note INTEGER
 ) RETURNS INTEGER
 LANGUAGE plpgsql
 AS $func$
  DECLARE
   m_id_country INTEGER;
   m_record RECORD;
   m_contains BOOLEAN;
   m_iter INTEGER;
   m_area VARCHAR(20);
  BEGIN
   m_id_country := -1;
   m_iter := 1;
   IF (-5 < lat AND lat < 4.53 AND 4 > lon AND lon > -4) THEN
    m_area := 'Null Island';
   ELSIF (lon < -30) THEN -- Americas
    m_area := 'Americas';
    FOR m_record IN
      SELECT /* Notes-base */ geom, country_id
      FROM countries
      ORDER BY americas NULLS LAST
     LOOP
      m_contains := ST_Contains(m_record.geom, ST_SetSRID(ST_Point(lon, lat),
       4326));
      IF (m_contains) THEN
       m_id_country := m_record.country_id;
       EXIT;
      END IF;
      m_iter := m_iter + 1;
     END LOOP;
   ELSIF (lon < 25) THEN -- Europe & part of Africa
    m_area := 'Europe/Africa';
    FOR m_record IN
      SELECT /* Notes-base */ geom, country_id
      FROM countries
      ORDER BY europe NULLS LAST
     LOOP
      m_contains := ST_Contains(m_record.geom, ST_SetSRID(ST_Point(lon, lat),
       4326));
      IF (m_contains) THEN
       m_id_country := m_record.country_id;
       EXIT;
      END IF;
      m_iter := m_iter + 1;
     END LOOP;
   ELSIF (lon < 65) THEN -- Russia, Middle East & part of Africa
    m_area := 'Russia/Middle east';
    FOR m_record IN
      SELECT /* Notes-base */ geom, country_id
      FROM countries
      ORDER BY russia_middle_east NULLS LAST
     LOOP
      m_contains := ST_Contains(m_record.geom, ST_SetSRID(ST_Point(lon, lat),
       4326));
      IF (m_contains) THEN
       m_id_country := m_record.country_id;
       EXIT;
      END IF;
      m_iter := m_iter + 1;
     END LOOP;
   ELSE
    m_area := 'Asia/Oceania';
    FOR m_record IN
      SELECT /* Notes-base */ geom, country_id
      FROM countries
      ORDER BY asia_oceania NULLS LAST
     LOOP
      m_contains := ST_Contains(m_record.geom, ST_SetSRID(ST_Point(lon, lat),
       4326));
      IF (m_contains) THEN
       m_id_country := m_record.country_id;
       EXIT;
      END IF;
      m_iter := m_iter + 1;
     END LOOP;
   END IF;
   INSERT INTO tries VALUES (m_area, m_iter, id_note, m_id_country);
   RETURN m_id_country;
  END
 $func$
;
COMMENT ON FUNCTION get_country IS
  'Returns the country given the coordinates of a note. The note id is only for logging.';

