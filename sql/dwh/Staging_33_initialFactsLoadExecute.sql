-- Loads data warehouse data for year ${YEAR}.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-22

SELECT /* Notes-staging */ CURRENT_TIMESTAMP AS Processing,
 'Processing year ${YEAR}' AS Text;

CALL staging.process_notes_actions_into_staging_${YEAR}();

SELECT /* Notes-staging */ CURRENT_TIMESTAMP AS Processing,
 'Year ${YEAR} processed' AS Text;
