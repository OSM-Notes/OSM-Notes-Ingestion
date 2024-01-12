-- Unifies the facts that were loaded in parallel.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-12

-- Set the next number to generate to the sequence.
SELECT /* Notes-ETL */ 
    SETVAL((SELECT PG_GET_SERIAL_SEQUENCE('dwh.facts', 'fact_id')),
    (SELECT (MAX(fact_id) + 1) FROM dwh.facts), FALSE);

CALL staging.unify_facts_from_parallel_load();

ALTER TABLE dwh.facts ALTER COLUMN recent_opened_dimension_id_date SET NOT NULL;