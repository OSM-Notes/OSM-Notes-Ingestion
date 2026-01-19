-- Get country assignment for a note using 2D grid optimization
-- Determines which country a note belongs to based on coordinates
--
-- Parameters:
--   lon DECIMAL: Note longitude [requerido]
--   lat DECIMAL: Note latitude [requerido]
--   id_note INTEGER: Note ID for optimization [requerido]
--
-- Returns:
--   INTEGER: Country ID (> 0 for valid countries)
--   -1: Known international waters (from international_waters table)
--   -2: Country unknown/not found (should be reassigned later)
--   NULL: Never (always returns INTEGER)
--
-- Exceptions: None (uses RETURN, not RAISE)
--
-- Strategy: See docs/Country_Assignment_2D_Grid.md for complete algorithm
--   1. Check current country first (95% hit rate when updating boundaries)
--   2. Use 2D grid (24 zones) to select relevant countries
--   3. Search terrestrial countries before maritime zones
--   4. Use ST_Intersects as fallback for points on edges (ST_Contains is strict)
--   5. Normalize SRID to 4326 for all geometries (handles SRID 0 from production)
--
-- Performance: See docs/Country_Assignment_2D_Grid.md#performance
--   - Average: <1ms per note
--   - Optimized for boundary updates (checks current country first)
--
-- Examples:
--   SELECT get_country(-74.006, 40.7128, 12345);
--   SELECT get_country(2.3522, 48.8566, 67890);
--
-- Related: docs/Country_Assignment_2D_Grid.md (complete strategy, examples, troubleshooting)
-- Related Functions: insert_note() (calls this function)

 CREATE OR REPLACE FUNCTION get_country (
  lon DECIMAL,
  lat DECIMAL,
  id_note INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql
SET search_path TO public
AS $func$
 DECLARE
  m_id_country INTEGER;
  m_current_country INTEGER;
  m_contains BOOLEAN;
  m_area VARCHAR(50);
  m_order_column VARCHAR(50);
 BEGIN
  -- Initialize as unknown (-2) instead of international waters (-1)
  -- -1 is reserved for KNOWN international waters only
  m_id_country := -2;

  -- OPTIMIZATION: Get current country assignment
  SELECT id_country INTO m_current_country
  FROM notes
  WHERE note_id = id_note;

  -- OPTIMIZATION: Check if note STILL belongs to current country
  -- Fixed: Normalize SRID - production geometries have SRID 0, set to 4326
  -- Improved: Use ST_Intersects as fallback for points on edges (ST_Contains is strict)
  IF m_current_country IS NOT NULL AND m_current_country > 0 THEN
    -- Try ST_Contains first (strict - point must be inside)
    SELECT ST_Contains(
      ST_SetSRID(geom, 4326),
      ST_SetSRID(ST_Point(lon, lat), 4326)
    ) INTO m_contains
    FROM countries
    WHERE country_id = m_current_country;

    -- If ST_Contains fails, try ST_Intersects (more tolerant - includes points on edges)
    -- This handles cases where points are on country boundaries
    IF NOT m_contains THEN
      SELECT ST_Intersects(
        ST_SetSRID(geom, 4326),
        ST_SetSRID(ST_Point(lon, lat), 4326)
      ) INTO m_contains
      FROM countries
      WHERE country_id = m_current_country;
    END IF;

    -- If still in same country, return immediately (95% of cases!)
    IF m_contains THEN
      RETURN m_current_country;
    END IF;

    -- Note changed country - continue searching
    m_area := 'Country changed';
  END IF;

  -- OPTIMIZATION: Check international waters before searching all countries
  -- This avoids expensive country searches for known international waters
  -- Only check if table exists (for backward compatibility)
  -- See docs/Country_Assignment_2D_Grid.md#international-waters for details
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_name = 'international_waters'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM international_waters
      WHERE (
        (geom IS NOT NULL AND (
          ST_Contains(ST_SetSRID(geom, 4326), ST_SetSRID(ST_Point(lon, lat), 4326))
          OR
          ST_Intersects(ST_SetSRID(geom, 4326), ST_SetSRID(ST_Point(lon, lat), 4326))
        ))
        OR
        (point_coords IS NOT NULL AND ST_DWithin(
          point_coords,
          ST_SetSRID(ST_Point(lon, lat), 4326),
          0.001 -- ~100 meters tolerance for special points
        ))
      )
    ) THEN
      RETURN -1; -- Known international waters
    END IF;
  END IF;

  -- Determine the geographic zone using 2D grid (lon AND lat)
  -- This reduces the number of countries to check dramatically
  -- See docs/Country_Assignment_2D_Grid.md#zones for complete zone definitions

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

  -- FALLBACK: Use fallback logic for edge cases not covered by 2D grid
  ELSIF (lon < -30) THEN
    m_area := 'Americas (fallback)';
    m_order_column := 'americas';
  ELSIF (lon < 25) THEN
    m_area := 'Europe/Africa (fallback)';
    m_order_column := 'europe';
  ELSIF (lon < 65) THEN
    m_area := 'Russia/Middle East (fallback)';
    m_order_column := 'russia_middle_east';
  ELSE
    m_area := 'Asia/Oceania (fallback)';
    m_order_column := 'asia_oceania';
  END IF;

  -- Search TERRESTRIAL countries first (is_maritime = false) in priority order
  -- This ensures notes on land are assigned to countries, not maritime zones
  -- OPTIMIZATION: Use direct SQL query instead of loop for better PostgreSQL optimization
  -- This allows PostgreSQL to optimize the entire query and use spatial indexes efficiently
  -- Fixed: Normalize SRID - production geometries have SRID 0, set to 4326
  -- Improved: Use ST_Intersects as fallback for points on edges (ST_Contains is strict)
  -- OPTIMIZATION: Use ST_Envelope(geom) for faster bounding box intersection (uses index)
  SELECT country_id INTO m_id_country
  FROM countries
  WHERE country_id != COALESCE(m_current_country, -1)
    AND is_maritime = false  -- PRIORITY: Search terrestrial boundaries first
    -- First filter by bounding box (fast - uses countries_bbox_box2d or countries_bbox_gist index)
    -- ST_Envelope(geom) && point is more efficient than ST_Intersects with ST_MakeEnvelope
    -- Uses the optimized index created by processPlanetNotes_26_optimizeCountryIndexes.sql
    AND ST_Envelope(ST_SetSRID(geom, 4326)) && ST_SetSRID(ST_Point(lon, lat), 4326)
    -- Then check containment: Try ST_Contains first (strict), fallback to ST_Intersects (tolerant)
    -- This handles points on country boundaries that ST_Contains would reject
    AND (
      ST_Contains(
        ST_SetSRID(geom, 4326),
        ST_SetSRID(ST_Point(lon, lat), 4326)
      )
      OR
      ST_Intersects(
        ST_SetSRID(geom, 4326),
        ST_SetSRID(ST_Point(lon, lat), 4326)
      )
    )
  ORDER BY
    -- Priority: current country first (if exists)
    CASE
      WHEN country_id = m_current_country THEN 0
      ELSE 1
    END,
    -- Then by zone priority (dynamic column based on 2D grid)
    CASE m_order_column
      WHEN 'zone_western_europe' THEN zone_western_europe
      WHEN 'zone_eastern_europe' THEN zone_eastern_europe
      WHEN 'zone_northern_europe' THEN zone_northern_europe
      WHEN 'zone_southern_europe' THEN zone_southern_europe
      WHEN 'zone_us_canada' THEN zone_us_canada
      WHEN 'zone_mexico_central_america' THEN zone_mexico_central_america
      WHEN 'zone_caribbean' THEN zone_caribbean
      WHEN 'zone_northern_south_america' THEN zone_northern_south_america
      WHEN 'zone_southern_south_america' THEN zone_southern_south_america
      WHEN 'zone_northern_africa' THEN zone_northern_africa
      WHEN 'zone_western_africa' THEN zone_western_africa
      WHEN 'zone_eastern_africa' THEN zone_eastern_africa
      WHEN 'zone_southern_africa' THEN zone_southern_africa
      WHEN 'zone_middle_east' THEN zone_middle_east
      WHEN 'zone_arctic' THEN zone_arctic
      WHEN 'zone_antarctic' THEN zone_antarctic
      WHEN 'zone_russia_north' THEN zone_russia_north
      WHEN 'zone_russia_south' THEN zone_russia_south
      WHEN 'zone_central_asia' THEN zone_central_asia
      WHEN 'zone_india_south_asia' THEN zone_india_south_asia
      WHEN 'zone_southeast_asia' THEN zone_southeast_asia
      WHEN 'zone_eastern_asia' THEN zone_eastern_asia
      WHEN 'zone_australia_nz' THEN zone_australia_nz
      WHEN 'zone_pacific_islands' THEN zone_pacific_islands
      WHEN 'americas' THEN americas
      WHEN 'europe' THEN europe
      WHEN 'russia_middle_east' THEN russia_middle_east
      WHEN 'asia_oceania' THEN asia_oceania
      ELSE NULL
    END NULLS LAST
  LIMIT 1;

  -- If not found in terrestrial boundaries, search MARITIME zones (is_maritime = true)
  -- This ensures notes in sea (not in any country) are assigned to maritime zones
  -- Improved: Use ST_Intersects as fallback for points on edges
  IF m_id_country IS NULL THEN
    SELECT country_id INTO m_id_country
    FROM countries
    WHERE country_id != COALESCE(m_current_country, -1)
      AND is_maritime = true  -- FALLBACK: Search maritime boundaries only if not in terrestrial
      -- First filter by bounding box (fast - uses countries_bbox_box2d or countries_bbox_gist index)
      AND ST_Envelope(ST_SetSRID(geom, 4326)) && ST_SetSRID(ST_Point(lon, lat), 4326)
      -- Then check containment: Try ST_Contains first (strict), fallback to ST_Intersects (tolerant)
      AND (
        ST_Contains(
          ST_SetSRID(geom, 4326),
          ST_SetSRID(ST_Point(lon, lat), 4326)
        )
        OR
        ST_Intersects(
          ST_SetSRID(geom, 4326),
          ST_SetSRID(ST_Point(lon, lat), 4326)
        )
      )
    ORDER BY
      -- Priority: current country first (if exists)
      CASE
        WHEN country_id = m_current_country THEN 0
        ELSE 1
      END,
      -- Then by zone priority (dynamic column based on 2D grid)
      CASE m_order_column
        WHEN 'zone_western_europe' THEN zone_western_europe
        WHEN 'zone_eastern_europe' THEN zone_eastern_europe
        WHEN 'zone_northern_europe' THEN zone_northern_europe
        WHEN 'zone_southern_europe' THEN zone_southern_europe
        WHEN 'zone_us_canada' THEN zone_us_canada
        WHEN 'zone_mexico_central_america' THEN zone_mexico_central_america
        WHEN 'zone_caribbean' THEN zone_caribbean
        WHEN 'zone_northern_south_america' THEN zone_northern_south_america
        WHEN 'zone_southern_south_america' THEN zone_southern_south_america
        WHEN 'zone_northern_africa' THEN zone_northern_africa
        WHEN 'zone_western_africa' THEN zone_western_africa
        WHEN 'zone_eastern_africa' THEN zone_eastern_africa
        WHEN 'zone_southern_africa' THEN zone_southern_africa
        WHEN 'zone_middle_east' THEN zone_middle_east
        WHEN 'zone_arctic' THEN zone_arctic
        WHEN 'zone_antarctic' THEN zone_antarctic
        WHEN 'zone_russia_north' THEN zone_russia_north
        WHEN 'zone_russia_south' THEN zone_russia_south
        WHEN 'zone_central_asia' THEN zone_central_asia
        WHEN 'zone_india_south_asia' THEN zone_india_south_asia
        WHEN 'zone_southeast_asia' THEN zone_southeast_asia
        WHEN 'zone_eastern_asia' THEN zone_eastern_asia
        WHEN 'zone_australia_nz' THEN zone_australia_nz
        WHEN 'zone_pacific_islands' THEN zone_pacific_islands
        WHEN 'americas' THEN americas
        WHEN 'europe' THEN europe
        WHEN 'russia_middle_east' THEN russia_middle_east
        WHEN 'asia_oceania' THEN asia_oceania
        ELSE NULL
      END NULLS LAST
    LIMIT 1;
  END IF;

  -- Return -2 (unknown) if no country found, instead of -1 (international waters)
  -- -1 is reserved ONLY for KNOWN international waters from international_waters table
  RETURN COALESCE(m_id_country, -2);
 END
$func$
;
COMMENT ON FUNCTION get_country IS
  'Returns country using intelligent 2D grid (24 zones). Checks current country first. Searches terrestrial boundaries (is_maritime=false) first, then maritime zones (is_maritime=true) if not found. Returns -1 for KNOWN international waters, -2 for unknown/not found. Uses ST_Contains with ST_Intersects fallback to handle points on country boundaries. Normalizes SRID to 4326 for all geometries. Uses direct SQL query with bounding box optimization for better performance.';

