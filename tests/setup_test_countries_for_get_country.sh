#!/bin/bash

# Script to load test countries needed for get_country() tests
# This ensures tests can run locally with proper data
#
# Author: Andres Gomez (AngocA)
# Version: 2026-01-19

set -euo pipefail

# Load properties if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Try to load properties, but don't fail if not available
if [[ -f "${PROJECT_ROOT}/etc/properties_test.sh" ]]; then
  # shellcheck source=/dev/null
  source "${PROJECT_ROOT}/etc/properties_test.sh" 2>/dev/null || true
elif [[ -f "${PROJECT_ROOT}/etc/properties.sh" ]]; then
  # shellcheck source=/dev/null
  source "${PROJECT_ROOT}/etc/properties.sh" 2>/dev/null || true
fi

DBNAME="${DBNAME:-osm_notes_ingestion_test}"

echo "Loading test countries for get_country() tests in database: ${DBNAME}"

# Check database connectivity
if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  echo "ERROR: Cannot connect to database: ${DBNAME}" >&2
  exit 1
fi

# Load countries needed for tests
psql -d "${DBNAME}" << 'SQL'
-- Insert/update countries needed for get_country() tests
-- These cover all coordinates tested in get_country_return_values.test.sql
INSERT INTO countries (country_id, country_name, country_name_en, country_name_es, geom, is_maritime) VALUES
-- South America (tested in TEST GROUP 1)
(287286, 'Brazil', 'Brazil', 'Brasil', ST_GeomFromText('POLYGON((-74 -34, -34 -34, -34 6, -74 6, -74 -34))', 4326), FALSE),
(272644, 'Venezuela', 'Venezuela', 'Venezuela', ST_GeomFromText('POLYGON((-73 0, -60 0, -60 12, -73 12, -73 0))', 4326), FALSE),
(167454, 'Chile', 'Chile', 'Chile', ST_GeomFromText('POLYGON((-75 -56, -66 -56, -66 -17, -75 -17, -75 -56))', 4326), FALSE),
(49615, 'Colombia', 'Colombia', 'Colombia', ST_GeomFromText('POLYGON((-79 4, -67 4, -67 12, -79 12, -79 4))', 4326), FALSE),
(286393, 'Argentina', 'Argentina', 'Argentina', ST_GeomFromText('POLYGON((-73 -55, -54 -55, -54 -22, -73 -22, -73 -55))', 4326), FALSE),
(288287, 'Peru', 'Peru', 'Perú', ST_GeomFromText('POLYGON((-81 -18, -68 -18, -68 0, -81 0, -81 -18))', 4326), FALSE),
-- Europe (tested in TEST GROUP 4)
(51477, 'Germany', 'Germany', 'Alemania', ST_GeomFromText('POLYGON((6 47, 15 47, 15 55, 6 55, 6 47))', 4326), FALSE),
(2202162, 'France', 'France', 'Francia', ST_GeomFromText('POLYGON((-5 42, 8 42, 8 51, -5 51, -5 42))', 4326), FALSE),
(62149, 'United Kingdom', 'United Kingdom', 'Reino Unido', ST_GeomFromText('POLYGON((-8 50, 2 50, 2 61, -8 61, -8 50))', 4326), FALSE),
-- North America (tested in TEST GROUP 4)
(148838, 'United States', 'United States', 'Estados Unidos', ST_GeomFromText('POLYGON((-125 25, -66 25, -66 50, -125 50, -125 25))', 4326), FALSE),
-- Asia (tested in TEST GROUP 4)
(382313, 'Japan', 'Japan', 'Japón', ST_GeomFromText('POLYGON((123 24, 146 24, 146 46, 123 46, 123 24))', 4326), FALSE),
(270056, 'China', 'China', 'China', ST_GeomFromText('POLYGON((73 18, 135 18, 135 54, 73 54, 73 18))', 4326), FALSE)
ON CONFLICT (country_id) DO UPDATE SET
  country_name = EXCLUDED.country_name,
  country_name_en = EXCLUDED.country_name_en,
  country_name_es = EXCLUDED.country_name_es,
  geom = EXCLUDED.geom,
  is_maritime = EXCLUDED.is_maritime;
SQL

# Remove international_waters that interfere with test coordinates
echo "Removing international_waters that interfere with test coordinates..."
psql -d "${DBNAME}" << 'SQL'
-- Remove international_waters that cover test coordinates
DELETE FROM international_waters WHERE
  -- South America test coordinates
  ST_Contains(geom, ST_SetSRID(ST_Point(-47.8825, -15.7942), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(-47.8825, -15.7942), 4326)) OR -- Brasília
  ST_Contains(geom, ST_SetSRID(ST_Point(-60.0, -3.0), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(-60.0, -3.0), 4326)) OR -- Manaus
  ST_Contains(geom, ST_SetSRID(ST_Point(-46.6333, -23.5505), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(-46.6333, -23.5505), 4326)) OR -- São Paulo
  ST_Contains(geom, ST_SetSRID(ST_Point(-66.9036, 10.4806), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(-66.9036, 10.4806), 4326)) OR -- Caracas
  ST_Contains(geom, ST_SetSRID(ST_Point(-71.6125, 10.6317), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(-71.6125, 10.6317), 4326)) OR -- Maracaibo
  ST_Contains(geom, ST_SetSRID(ST_Point(-70.6693, -33.4489), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(-70.6693, -33.4489), 4326)) OR -- Santiago
  ST_Contains(geom, ST_SetSRID(ST_Point(-71.6167, -33.0472), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(-71.6167, -33.0472), 4326)) OR -- Valparaíso
  ST_Contains(geom, ST_SetSRID(ST_Point(-74.0721, 4.7110), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(-74.0721, 4.7110), 4326)) OR -- Bogotá
  ST_Contains(geom, ST_SetSRID(ST_Point(-58.3816, -34.6037), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(-58.3816, -34.6037), 4326)) OR -- Buenos Aires
  ST_Contains(geom, ST_SetSRID(ST_Point(-77.0428, -12.0464), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(-77.0428, -12.0464), 4326)) OR -- Lima
  -- Europe test coordinates
  ST_Contains(geom, ST_SetSRID(ST_Point(13.4050, 52.5200), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(13.4050, 52.5200), 4326)) OR -- Berlin
  ST_Contains(geom, ST_SetSRID(ST_Point(2.3522, 48.8566), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(2.3522, 48.8566), 4326)) OR -- Paris
  ST_Contains(geom, ST_SetSRID(ST_Point(-0.1276, 51.5074), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(-0.1276, 51.5074), 4326)) OR -- London
  -- North America test coordinates
  ST_Contains(geom, ST_SetSRID(ST_Point(40.7128, -74.0060), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(40.7128, -74.0060), 4326)) OR -- New York
  -- Asia test coordinates
  ST_Contains(geom, ST_SetSRID(ST_Point(139.6917, 35.6895), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(139.6917, 35.6895), 4326)) OR -- Tokyo
  ST_Contains(geom, ST_SetSRID(ST_Point(116.4074, 39.9042), 4326)) OR ST_Intersects(geom, ST_SetSRID(ST_Point(116.4074, 39.9042), 4326)); -- Beijing
SQL

echo "Test countries loaded successfully!"
echo ""
echo "Countries loaded:"
psql -d "${DBNAME}" -c "SELECT country_id, country_name, country_name_en, country_name_es FROM countries WHERE country_name_en IN ('Brazil', 'Venezuela', 'Chile', 'Colombia', 'Argentina', 'Peru', 'Germany', 'France', 'United Kingdom', 'United States', 'Japan', 'China') OR country_name_es IN ('Brasil', 'Venezuela', 'Chile', 'Colombia', 'Argentina', 'Perú', 'Alemania', 'Francia', 'Reino Unido', 'Estados Unidos', 'Japón', 'China') ORDER BY country_name_en;" 2>&1
