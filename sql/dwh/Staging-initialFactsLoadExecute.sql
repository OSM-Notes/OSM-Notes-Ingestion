-- Loads data warehouse data for year ${YEAR}.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-08

CALL staging.process_notes_actions_into_dwh_${YEAR}();
