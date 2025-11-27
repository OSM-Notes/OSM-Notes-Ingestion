-- Consolidated cleanup script for OSM-Notes-profile
-- This script consolidates multiple small cleanup operations into a single file
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-13
-- Description: Consolidated cleanup operations for better maintainability
--
-- NOTE: This script is used in two contexts:
-- 1. Full cleanup (cleanupAll.sh): Drops all objects including countries table
-- 2. Analyze and Vacuum (processPlanetNotes.sh): Only performs VACUUM and ANALYZE
--
-- When used for analyze/vacuum, the countries table should NOT be dropped
-- as it is required for the system to function. The countries table is managed
-- by updateCountries.sh and should only be dropped during full cleanup.

-- Set statement timeout to 30 seconds for DROP operations
SET statement_timeout = '30s';

-- =====================================================
-- Drop Generic Objects (from functionsProcess_12_dropGenericObjects.sql)
-- =====================================================
-- NOTE: These are dropped during full cleanup, but NOT during analyze/vacuum
-- The analyze/vacuum operation should preserve these objects
DROP PROCEDURE IF EXISTS insert_note_comment CASCADE;
DROP PROCEDURE IF EXISTS insert_note CASCADE;
DROP FUNCTION IF EXISTS get_country CASCADE;

-- =====================================================
-- Drop Country Tables (from processPlanetNotes_14_dropCountryTables.sql)
-- =====================================================
-- NOTE: These are ONLY dropped during full cleanup (cleanupAll.sh)
-- They should NOT be dropped during analyze/vacuum operations
-- as they are required for the system to function.
-- The countries table is managed by updateCountries.sh.
-- DROP TABLE IF EXISTS countries CASCADE;

-- =====================================================
-- Analyze and Vacuum operations
-- =====================================================
-- Perform VACUUM and ANALYZE on all tables to optimize performance
-- This is safe to run after any operation and does not drop any data
VACUUM ANALYZE;

-- Reset statement timeout
SET statement_timeout = DEFAULT;
