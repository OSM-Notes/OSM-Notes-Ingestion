-- Loads data warehouse data for year ${YEAR}.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2027-07-11

SELECT /* Notes-staging */ clock_timestamp() AS Processing,
 'Processing year ${YEAR}' AS Text;

CALL staging.process_notes_actions_into_staging_${YEAR}();

SELECT /* Notes-staging */ clock_timestamp() AS Processing,
 'Year ${YEAR} processed' AS Text;

SELECT /* Notes-staging */ clock_timestamp() AS Processing,
 'Analyzing facts_${YEAR}' AS Text;

ANALYZE staging.facts_${YEAR};

SELECT /* Notes-staging */ clock_timestamp() AS Processing,
 'Analysis finished facts_${YEAR}' AS Text;
