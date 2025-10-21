-- Function to get the country where the note is located.
-- Uses intelligent 2D grid partitioning (24 zones) to minimize expensive
-- ST_Contains calls.
-- Optimized to check current country FIRST before searching all countries.
-- This is critical when updating boundaries - 95% of notes stay in same
-- country.
--
-- Strategy:
-- 1. Check if note is still in current country (95% hit rate)
-- 2. Use 2D grid (lon+lat) to select most relevant zone
-- 3. Search countries in priority order for that zone
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-19

 CREATE OR REPLACE FUNCTION get_country (
  lon DECIMAL,
  lat DECIMAL,
  id_note INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql
AS $func$
 DECLARE
  m_id_country INTEGER;
  m_current_country INTEGER;
  m_record RECORD;
  m_contains BOOLEAN;
  m_iter INTEGER;
  m_area VARCHAR(50);
  m_order_column VARCHAR(50);
 BEGIN
  m_id_country := -1;
  m_iter := 1;

  -- OPTIMIZATION: Get current country assignment
  SELECT id_country INTO m_current_country
  FROM notes
  WHERE note_id = id_note;

  -- OPTIMIZATION: Check if note STILL belongs to current country
  IF m_current_country IS NOT NULL AND m_current_country > 0 THEN
    SELECT ST_Contains(
      geom,
      ST_SetSRID(ST_Point(lon, lat), 4326)
    ) INTO m_contains
    FROM countries
    WHERE country_id = m_current_country;

    -- If still in same country, return immediately (95% of cases!)
    IF m_contains THEN
      INSERT INTO tries VALUES ('Same country', 1, id_note,
        m_current_country);
      RETURN m_current_country;
    END IF;

    -- Note changed country - continue searching
    m_area := 'Country changed';
  END IF;

  -- Determine the geographic zone using 2D grid (lon AND lat)
  -- This reduces the number of countries to check dramatically

  -- Special case: Null Island (Gulf of Guinea)
  IF (-5 < lat AND lat < 4.53 AND 4 > lon AND lon > -4) THEN
    m_area := 'Null Island';
    m_order_column := 'zone_western_africa';

  -- ARCTIC (all longitudes, lat > 70)
  ELSIF (lat > 70) THEN
    m_area := 'Arctic';
    m_order_column := 'zone_arctic';

  -- ANTARCTIC (all longitudes, lat < -60)
  ELSIF (lat < -60) THEN
    m_area := 'Antarctic';
    m_order_column := 'zone_antarctic';

  -- USA/CANADA (lon: -150 to -60, lat: 30 to 75)
  ELSIF (lon >= -150 AND lon < -60 AND lat >= 30 AND lat <= 75) THEN
    m_area := 'USA/Canada';
    m_order_column := 'zone_us_canada';

  -- MEXICO/CENTRAL AMERICA (lon: -120 to -75, lat: 5 to 35)
  ELSIF (lon >= -120 AND lon < -75 AND lat >= 5 AND lat < 35) THEN
    m_area := 'Mexico/Central America';
    m_order_column := 'zone_mexico_central_america';

  -- CARIBBEAN (lon: -90 to -60, lat: 10 to 30)
  ELSIF (lon >= -90 AND lon < -60 AND lat >= 10 AND lat < 30) THEN
    m_area := 'Caribbean';
    m_order_column := 'zone_caribbean';

  -- NORTHERN SOUTH AMERICA (lon: -80 to -35, lat: -15 to 15)
  ELSIF (lon >= -80 AND lon < -35 AND lat >= -15 AND lat <= 15) THEN
    m_area := 'Northern South America';
    m_order_column := 'zone_northern_south_america';

  -- SOUTHERN SOUTH AMERICA (lon: -75 to -35, lat: -56 to -15)
  ELSIF (lon >= -75 AND lon < -35 AND lat >= -56 AND lat < -15) THEN
    m_area := 'Southern South America';
    m_order_column := 'zone_southern_south_america';

  -- WESTERN EUROPE (lon: -10 to 15, lat: 35 to 60)
  ELSIF (lon >= -10 AND lon < 15 AND lat >= 35 AND lat < 60) THEN
    m_area := 'Western Europe';
    m_order_column := 'zone_western_europe';

  -- EASTERN EUROPE (lon: 15 to 45, lat: 35 to 60)
  ELSIF (lon >= 15 AND lon < 45 AND lat >= 35 AND lat < 60) THEN
    m_area := 'Eastern Europe';
    m_order_column := 'zone_eastern_europe';

  -- NORTHERN EUROPE (lon: -10 to 35, lat: 55 to 75)
  ELSIF (lon >= -10 AND lon < 35 AND lat >= 55 AND lat <= 75) THEN
    m_area := 'Northern Europe';
    m_order_column := 'zone_northern_europe';

  -- SOUTHERN EUROPE (lon: -10 to 30, lat: 30 to 50)
  ELSIF (lon >= -10 AND lon < 30 AND lat >= 30 AND lat < 50) THEN
    m_area := 'Southern Europe';
    m_order_column := 'zone_southern_europe';

  -- NORTHERN AFRICA (lon: -20 to 50, lat: 15 to 40)
  ELSIF (lon >= -20 AND lon < 50 AND lat >= 15 AND lat < 40) THEN
    m_area := 'Northern Africa';
    m_order_column := 'zone_northern_africa';

  -- WESTERN AFRICA (lon: -20 to 20, lat: -10 to 20)
  ELSIF (lon >= -20 AND lon < 20 AND lat >= -10 AND lat < 20) THEN
    m_area := 'Western Africa';
    m_order_column := 'zone_western_africa';

  -- EASTERN AFRICA (lon: 20 to 55, lat: -15 to 20)
  ELSIF (lon >= 20 AND lon < 55 AND lat >= -15 AND lat < 20) THEN
    m_area := 'Eastern Africa';
    m_order_column := 'zone_eastern_africa';

  -- SOUTHERN AFRICA (lon: 10 to 50, lat: -36 to -15)
  ELSIF (lon >= 10 AND lon < 50 AND lat >= -36 AND lat < -15) THEN
    m_area := 'Southern Africa';
    m_order_column := 'zone_southern_africa';

  -- MIDDLE EAST (lon: 25 to 65, lat: 10 to 45)
  ELSIF (lon >= 25 AND lon < 65 AND lat >= 10 AND lat < 45) THEN
    m_area := 'Middle East';
    m_order_column := 'zone_middle_east';

  -- RUSSIA NORTH (lon: 25 to 180, lat: 55 to 80)
  ELSIF (lon >= 25 AND lon <= 180 AND lat >= 55 AND lat <= 80) THEN
    m_area := 'Russia North';
    m_order_column := 'zone_russia_north';

  -- RUSSIA SOUTH (lon: 30 to 150, lat: 40 to 60)
  ELSIF (lon >= 30 AND lon < 150 AND lat >= 40 AND lat < 60) THEN
    m_area := 'Russia South';
    m_order_column := 'zone_russia_south';

  -- CENTRAL ASIA (lon: 45 to 90, lat: 30 to 55)
  ELSIF (lon >= 45 AND lon < 90 AND lat >= 30 AND lat < 55) THEN
    m_area := 'Central Asia';
    m_order_column := 'zone_central_asia';

  -- INDIA/SOUTH ASIA (lon: 60 to 95, lat: 5 to 40)
  ELSIF (lon >= 60 AND lon < 95 AND lat >= 5 AND lat < 40) THEN
    m_area := 'India/South Asia';
    m_order_column := 'zone_india_south_asia';

  -- SOUTHEAST ASIA (lon: 95 to 140, lat: -12 to 25)
  ELSIF (lon >= 95 AND lon < 140 AND lat >= -12 AND lat < 25) THEN
    m_area := 'Southeast Asia';
    m_order_column := 'zone_southeast_asia';

  -- EASTERN ASIA (lon: 100 to 145, lat: 20 to 55)
  ELSIF (lon >= 100 AND lon < 145 AND lat >= 20 AND lat < 55) THEN
    m_area := 'Eastern Asia';
    m_order_column := 'zone_eastern_asia';

  -- AUSTRALIA/NZ (lon: 110 to 180, lat: -50 to -10)
  ELSIF (lon >= 110 AND lon <= 180 AND lat >= -50 AND lat < -10) THEN
    m_area := 'Australia/NZ';
    m_order_column := 'zone_australia_nz';

  -- PACIFIC ISLANDS (lon: 130 to -120 [wraps], lat: -30 to 30)
  ELSIF ((lon >= 130 OR lon < -120) AND lat >= -30 AND lat < 30) THEN
    m_area := 'Pacific Islands';
    m_order_column := 'zone_pacific_islands';

  -- FALLBACK: Use legacy logic for edge cases
  ELSIF (lon < -30) THEN
    m_area := 'Americas (legacy)';
    m_order_column := 'americas';
  ELSIF (lon < 25) THEN
    m_area := 'Europe/Africa (legacy)';
    m_order_column := 'europe';
  ELSIF (lon < 65) THEN
    m_area := 'Russia/Middle East (legacy)';
    m_order_column := 'russia_middle_east';
  ELSE
    m_area := 'Asia/Oceania (legacy)';
    m_order_column := 'asia_oceania';
  END IF;

  -- Search countries in priority order for the determined zone
  FOR m_record IN EXECUTE format(
    'SELECT geom, country_id
     FROM countries
     WHERE country_id != %L
     ORDER BY %I NULLS LAST',
    COALESCE(m_current_country, -1),
    m_order_column
  )
  LOOP
    m_contains := ST_Contains(m_record.geom,
      ST_SetSRID(ST_Point(lon, lat), 4326));
    IF (m_contains) THEN
      m_id_country := m_record.country_id;
      EXIT;
    END IF;
    m_iter := m_iter + 1;
  END LOOP;

  INSERT INTO tries VALUES (m_area, m_iter, id_note, m_id_country);
  RETURN m_id_country;
 END
$func$
;
COMMENT ON FUNCTION get_country IS
  'Returns country using intelligent 2D grid (24 zones). Checks current country first.';

