-- Function to get the country where the note is located.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25
  
 CREATE OR REPLACE FUNCTION get_country (
   lon DECIMAL,
   lat DECIMAL,
   id_note INTEGER
 ) RETURNS INTEGER
 LANGUAGE plpgsql
 AS $func$
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
 $func$
;
COMMENT ON FUNCTION get_country IS
  'Returns the country given the coordinates of a note. The note id is only for logging.';

