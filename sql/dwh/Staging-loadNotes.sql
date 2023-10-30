-- Loads data warehouse data.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-29

SELECT CURRENT_TIMESTAMP AS Processing, 'Inserting facts';

CALL staging.process_notes_actions_into_dwh;
