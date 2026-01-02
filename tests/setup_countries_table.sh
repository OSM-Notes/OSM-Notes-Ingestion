#!/bin/bash

# Setup script para poblar la tabla countries con datos de prueba
# Author: Andres Gomez (AngocA)
# Version: 2026-01-02

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
 echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
 echo -e "${GREEN[SUCCESS]${NC} $1"
}

log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
 echo -e "${RED}[ERROR]${NC} $1"
}

# Load properties if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${PROJECT_ROOT}/etc/properties_test.sh" ]]; then
 source "${PROJECT_ROOT}/etc/properties_test.sh"
elif [[ -f "${PROJECT_ROOT}/etc/properties.sh" ]]; then
 source "${PROJECT_ROOT}/etc/properties.sh"
fi

DBNAME="${DBNAME:-osm_notes_ingestion_test}"

log_info "Setting up countries table in database: ${DBNAME}"

# Check if psql is available
if ! command -v psql > /dev/null 2>&1; then
 log_error "psql command not found. Please install PostgreSQL client."
 exit 1
fi

# Check database connectivity
if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
 log_error "Cannot connect to database: ${DBNAME}"
 log_info "Please ensure PostgreSQL is running and the database exists."
 exit 1
fi

log_info "Creating PostGIS extension if needed..."
psql -d "${DBNAME}" -c "CREATE EXTENSION IF NOT EXISTS postgis;" > /dev/null 2>&1 || {
 log_warning "PostGIS extension may not be available. Some tests may fail."
}

log_info "Creating countries table if needed..."
psql -d "${DBNAME}" << 'SQL'
CREATE TABLE IF NOT EXISTS countries (
 country_id INTEGER PRIMARY KEY,
 country_name VARCHAR(256) NOT NULL,
 geom GEOMETRY(POLYGON, 4326),
 is_maritime BOOLEAN DEFAULT FALSE,
 updated BOOLEAN DEFAULT FALSE
);

-- Create index on geometry if PostGIS is available
DO $$
BEGIN
 IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN
  CREATE INDEX IF NOT EXISTS idx_countries_geom ON countries USING GIST (geom);
 END IF;
END $$;
SQL

log_info "Inserting test data into countries table..."
psql -d "${DBNAME}" << 'SQL'
-- Insert test countries (non-maritime)
INSERT INTO countries (country_id, country_name, geom, is_maritime) VALUES
 (16239, 'Austria', ST_GeomFromText('POLYGON((10.0 47.0, 10.0 48.0, 11.0 48.0, 11.0 47.0, 10.0 47.0))', 4326), FALSE),
 (2186646, 'Antarctica', ST_GeomFromText('POLYGON((-180.0 -90.0, -180.0 -60.0, 180.0 -60.0, 180.0 -90.0, -180.0 -90.0))', 4326), FALSE),
 (1, 'United States', ST_GeomFromText('POLYGON((-125 25, -66 25, -66 49, -125 49, -125 25))', 4326), FALSE),
 (2, 'Canada', ST_GeomFromText('POLYGON((-141 42, -52 42, -52 83, -141 83, -141 42))', 4326), FALSE),
 (3, 'Mexico', ST_GeomFromText('POLYGON((-118 14, -86 14, -86 32, -118 32, -118 14))', 4326), FALSE),
 (4, 'United Kingdom', ST_GeomFromText('POLYGON((-8 50, 2 50, 2 61, -8 61, -8 50))', 4326), FALSE),
 (5, 'France', ST_GeomFromText('POLYGON((-5 42, 8 42, 8 51, -5 51, -5 42))', 4326), FALSE),
 (6, 'Germany', ST_GeomFromText('POLYGON((6 47, 15 47, 15 55, 6 55, 6 47))', 4326), FALSE)
ON CONFLICT (country_id) DO NOTHING;
SQL

# Verify data was inserted
COUNTRIES_COUNT=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM countries WHERE is_maritime = false;" 2> /dev/null || echo "0")

if [[ "${COUNTRIES_COUNT}" -gt "0" ]]; then
 log_success "Countries table populated successfully with ${COUNTRIES_COUNT} countries"
else
 log_warning "No countries found in table. Check for errors above."
 exit 1
fi

log_info "Setup completed successfully"
