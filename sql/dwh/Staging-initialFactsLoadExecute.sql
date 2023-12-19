-- Loads data warehouse data for year ${YEAR}.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-19

CALL staging.process_notes_actions_into_staging_${YEAR}();
