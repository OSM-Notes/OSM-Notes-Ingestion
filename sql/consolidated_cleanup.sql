-- Consolidated cleanup script for OSM-Notes-profile
-- This script consolidates multiple small cleanup operations into a single file
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-27
-- Description: Consolidated cleanup operations for better maintainability

-- Set statement timeout to 30 seconds for DROP operations
SET statement_timeout = '30s';

-- =====================================================
-- Drop Generic Objects (from functionsProcess_12_dropGenericObjects.sql)
-- =====================================================
DROP PROCEDURE IF EXISTS insert_note_comment CASCADE;
DROP PROCEDURE IF EXISTS insert_note CASCADE;
DROP FUNCTION IF EXISTS get_country CASCADE;

-- =====================================================
-- Drop Country Tables (from processPlanetNotes_14_dropCountryTables.sql)
-- =====================================================
DROP TABLE IF EXISTS tries CASCADE;
DROP TABLE IF EXISTS countries CASCADE;

-- Reset statement timeout
SET statement_timeout = DEFAULT;
