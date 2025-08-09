-- Test for DWH cleanup script
-- Version: 2025-01-08

\echo 'Testing DWH cleanup script...'

-- Create test database for this specific test
CREATE DATABASE test_dwh_cleanup;
\c test_dwh_cleanup

-- Create the schema and some test tables
CREATE SCHEMA dwh;

-- Create some test tables that might exist from previous versions
CREATE TABLE dwh.dimension_hours_of_week (id INT);
CREATE TABLE dwh.dimension_time_of_week (id INT);
CREATE TABLE dwh.dimension_applications (id INT);
CREATE TABLE dwh.dimension_application_versions (id INT);
CREATE TABLE dwh.facts (id INT);

-- Test that the drop script works
\i sql/dwh/ETL_13_removeDWHObjects.sql

-- Verify the schema was dropped
SELECT CASE 
  WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'dwh')
  THEN 'FAIL: Schema dwh still exists'
  ELSE 'PASS: Schema dwh was dropped successfully'
END AS result;

-- Clean up
\c postgres
DROP DATABASE test_dwh_cleanup;

\echo 'DWH cleanup test completed.'

