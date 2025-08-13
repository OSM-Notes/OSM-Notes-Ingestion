-- Consolidated cleanup script for OSM-Notes-profile
-- This script consolidates multiple small cleanup operations into a single file
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-27
-- Description: Consolidated cleanup operations for better maintainability

-- =====================================================
-- Drop Generic Objects (from functionsProcess_12_dropGenericObjects.sql)
-- =====================================================
DROP PROCEDURE IF EXISTS insert_note_comment;
DROP PROCEDURE IF EXISTS insert_note;
DROP FUNCTION IF EXISTS get_country;

-- =====================================================
-- Drop Country Tables (from processPlanetNotes_14_dropCountryTables.sql)
-- =====================================================
DROP TABLE IF EXISTS tries;
DROP TABLE IF EXISTS countries;

-- =====================================================
-- Performance Tuning (from processPlanetNotes_31_analyzeVacuum.sql)
-- =====================================================
VACUUM;
ANALYZE;
