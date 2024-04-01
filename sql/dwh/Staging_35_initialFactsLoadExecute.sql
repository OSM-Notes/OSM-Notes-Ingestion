-- Loads data warehouse data for year ${YEAR}.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-03-30

SELECT /* Notes-staging */ CURRENT_TIMESTAMP AS Processing,
 'Processing year ${YEAR}' AS Text;

CALL staging.process_notes_actions_into_staging_${YEAR}();

SELECT /* Notes-staging */ CURRENT_TIMESTAMP AS Processing,
 'Year ${YEAR} processed' AS Text;

SELECT /* Notes-staging */ CURRENT_TIMESTAMP AS Processing,
 'Analyzing facts_${YEAR}' AS Text;

ANALYZE staging.facts_${YEAR};

SELECT /* Notes-staging */ CURRENT_TIMESTAMP AS Processing,
 'Analysis finished facts_${YEAR}' AS Text;
