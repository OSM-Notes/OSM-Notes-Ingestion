-- Grant read-only permissions to 'geoserver' user on 'notes' database
-- This allows GeoServer to access WMS data with read-only privileges
--
-- This script should be executed as the database owner (angoca) or postgres superuser
-- Usage: psql -d notes -f sql/wms/grantGeoserverPermissions.sql
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-30

-- Connect to notes database
\c notes

-- Check if geoserver user exists, create if not
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_user WHERE usename = 'geoserver') THEN
    CREATE USER geoserver;
    RAISE NOTICE 'User geoserver created';
  ELSE
    RAISE NOTICE 'User geoserver already exists';
  END IF;
END $$;

-- Grant CONNECT privilege on database
GRANT CONNECT ON DATABASE notes TO geoserver;

-- Grant USAGE on schemas
GRANT USAGE ON SCHEMA public TO geoserver;
GRANT USAGE ON SCHEMA wms TO geoserver;

-- Grant SELECT (read-only) on all existing tables in wms schema
GRANT SELECT ON ALL TABLES IN SCHEMA wms TO geoserver;

-- Grant SELECT on all existing sequences in wms schema (if any)
GRANT SELECT ON ALL SEQUENCES IN SCHEMA wms TO geoserver;

-- Set default privileges for future tables in wms schema
-- This ensures new tables created in wms schema will automatically have read permissions
ALTER DEFAULT PRIVILEGES IN SCHEMA wms GRANT SELECT ON TABLES TO geoserver;
ALTER DEFAULT PRIVILEGES IN SCHEMA wms GRANT SELECT ON SEQUENCES TO geoserver;

-- Grant SELECT on countries table (needed for WMS layers that use country data)
GRANT SELECT ON TABLE countries TO geoserver;

-- Verify permissions
\echo '✅ Permissions granted to geoserver user:'
\echo '   - CONNECT on database notes'
\echo '   - USAGE on schemas public and wms'
\echo '   - SELECT on all tables in wms schema'
\echo '   - SELECT on countries table'
\echo '   - Default privileges set for future tables in wms schema'
\echo ''
\echo 'To verify, run as geoserver user:'
\echo '   psql -U geoserver -d notes -c "SELECT COUNT(*) FROM wms.notes_wms;"'

