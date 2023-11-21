-- Drop staging objects.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-28

DROP PROCEDURE IF EXISTS staging.process_notes_at_date;

DROP PROCEDURE IF EXISTS staging.process_notes_actions_into_dwh;

DROP SCHEMA IF EXISTS staging;
