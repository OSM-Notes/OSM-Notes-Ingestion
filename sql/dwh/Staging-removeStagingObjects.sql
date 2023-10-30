-- Drop staging objects.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-28

DROP PROCEDURE staging.process_notes_at_date;

DROP PROCEDURE staging.process_notes_actions_into_dwh;

DROP SCHEMA IF EXISTS staging;
