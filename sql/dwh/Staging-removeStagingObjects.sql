-- Drop staging objects.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-19

DROP PROCEDURE IF EXISTS staging.process_notes_at_date;

DROP PROCEDURE IF EXISTS staging.process_notes_actions_into_dwh;

DROP FUNCTION IF EXISTS staging.get_application;

DROP SCHEMA IF EXISTS staging CASCADE;
