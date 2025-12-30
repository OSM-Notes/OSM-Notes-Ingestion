-- Compare country geometries between countries and countries_new tables
-- This function is used to validate geometry changes before swapping tables
-- during updateCountries.sh execution
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-23

-- Function to compare all country geometries
-- Returns a table with status and change metrics for each country
-- This function compares the entire countries table with countries_new table
-- using efficient SQL joins instead of loops
CREATE OR REPLACE FUNCTION compare_all_country_geometries(
  tolerance_percent NUMERIC DEFAULT 0.01
) RETURNS TABLE (
  country_id INTEGER,
  status TEXT,
  area_change_percent NUMERIC,
  perimeter_change_percent NUMERIC,
  vertices_change INTEGER,
  geometry_changed BOOLEAN
)
LANGUAGE plpgsql
SET search_path TO public
AS $func$
BEGIN
  -- Compare all countries using efficient SQL joins
  -- This processes the entire table at once, not record by record
  RETURN QUERY
  WITH old_countries AS (
    SELECT
      c.country_id,
      c.geom,
      ST_Area(c.geom::geography) AS old_area,
      ST_Perimeter(c.geom::geography) AS old_perimeter,
      ST_NPoints(c.geom) AS old_vertices
    FROM countries c
  ),
  new_countries AS (
    SELECT
      c.country_id,
      c.geom,
      ST_Area(c.geom::geography) AS new_area,
      ST_Perimeter(c.geom::geography) AS new_perimeter,
      ST_NPoints(c.geom) AS new_vertices
    FROM countries_new c
  ),
  compared AS (
    SELECT
      COALESCE(o.country_id, n.country_id) AS country_id,
      CASE
        WHEN o.country_id IS NULL THEN 'new'
        WHEN n.country_id IS NULL THEN 'deleted'
        WHEN ABS((n.new_area - o.old_area) / NULLIF(o.old_area, 0) * 100) < tolerance_percent
         AND ABS((n.new_perimeter - o.old_perimeter) / NULLIF(o.old_perimeter, 0) * 100) < tolerance_percent
         THEN 'unchanged'
        WHEN n.new_area > o.old_area * 1.01 THEN 'increased'
        WHEN n.new_area < o.old_area * 0.99 THEN 'decreased'
        ELSE 'modified'
      END AS status,
      CASE
        WHEN o.old_area > 0 THEN
          ABS((n.new_area - o.old_area) / o.old_area * 100)
        WHEN n.new_area > 0 THEN 100
        ELSE 0
      END AS area_change_percent,
      CASE
        WHEN o.old_perimeter > 0 THEN
          ABS((n.new_perimeter - o.old_perimeter) / o.old_perimeter * 100)
        WHEN n.new_perimeter > 0 THEN 100
        ELSE 0
      END AS perimeter_change_percent,
      COALESCE(n.new_vertices, 0) - COALESCE(o.old_vertices, 0) AS vertices_change,
      CASE
        WHEN o.geom IS NULL OR n.geom IS NULL THEN TRUE
        ELSE NOT ST_Equals(o.geom, n.geom)
      END AS geometry_changed
    FROM old_countries o
    FULL OUTER JOIN new_countries n ON o.country_id = n.country_id
  )
  SELECT
    country_id,
    status,
    area_change_percent,
    perimeter_change_percent,
    vertices_change,
    geometry_changed
  FROM compared
  ORDER BY country_id;
END;
$func$;

COMMENT ON FUNCTION compare_all_country_geometries(NUMERIC) IS
  'Compares geometries between countries and countries_new tables. Returns status and change metrics for each country. Used by updateCountries.sh to validate changes before swapping tables.';
