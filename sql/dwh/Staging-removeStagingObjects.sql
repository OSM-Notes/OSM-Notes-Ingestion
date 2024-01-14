-- Drop staging objects.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-13

DROP PROCEDURE IF EXISTS staging.process_notes_at_date;

DROP PROCEDURE IF EXISTS staging.process_notes_actions_into_dwh;

DROP FUNCTION IF EXISTS staging.get_application;

DROP FUNCTION IF EXISTS staging.get_hashtag_id;

DROP PROCEDURE IF EXISTS staging.get_hashtag;

DROP SCHEMA IF EXISTS staging CASCADE;
