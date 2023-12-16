-- Loads data warehouse data for year ${YEAR}.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-16

DROP PROCEDURE staging.process_notes_actions_into_dwh_${YEAR};

DROP PROCEDURE staging.process_notes_at_date_${YEAR};

DROP TABLE dwh.facts_${YEAR};

DROP SEQUENCE dwh.facts_${YEAR}_seq;