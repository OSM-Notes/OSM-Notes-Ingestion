-- Loads data warehouse data.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-31

SELECT CURRENT_TIMESTAMP AS Processing, 'Inserting facts' AS Task;

CALL staging.process_notes_actions_into_dwh();

SELECT CURRENT_TIMESTAMP AS Processing, 'Facts inserted' AS Task;
