-- Loads data warehouse data for year ${YEAR}.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-19

DROP PROCEDURE staging.process_notes_actions_into_staging_${YEAR};

DROP PROCEDURE staging.process_notes_at_date_${YEAR};

DROP TABLE staging.facts_${YEAR};

DROP SEQUENCE staging.facts_${YEAR}_seq;