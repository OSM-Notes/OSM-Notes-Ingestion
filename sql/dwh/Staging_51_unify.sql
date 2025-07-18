-- Unifies the facts that were loaded in parallel.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-14

-- Set the next number to generate to the sequence.
SELECT /* Notes-staging */
    SETVAL((SELECT PG_GET_SERIAL_SEQUENCE('dwh.facts', 'fact_id')),
    (SELECT (MAX(fact_id) + 1) FROM dwh.facts), FALSE);

DO /* Notes-staging */
 $$
 DECLARE
  m_qty_iterations INTEGER;
  m_iter INTEGER;
  m_recent_opened_dimension_id_date INTEGER;
  m_previous_action_fact_id INTEGER;
  rec_no_recent_open_fact RECORD;
  no_recent_open CURSOR FOR
   SELECT /* Notes-staging */
    fact_id, id_note
   FROM dwh.facts f
   WHERE f.recent_opened_dimension_id_date IS NULL
   ORDER BY id_note, action_at
   FOR UPDATE;

 BEGIN
  -- Calculates how many iterations should be run.
  SELECT /* Notes-staging */ MAX(qty)
   INTO m_qty_iterations
  FROM (
   SELECT COUNT(1) qty, id_note
   FROM dwh.facts f
   WHERE f.recent_opened_dimension_id_date IS NULL
   GROUP BY f.id_note
  ) AS t;

  m_iter := 0;
  WHILE (m_iter < m_qty_iterations) LOOP
   OPEN no_recent_open;

   LOOP
    FETCH no_recent_open INTO rec_no_recent_open_fact;
    -- Exit when no more rows to fetch.
    EXIT WHEN NOT FOUND;

    SELECT /* Notes-staging */ max(fact_id)
     INTO m_previous_action_fact_id
    FROM dwh.facts f
    WHERE f.id_note = rec_no_recent_open_fact.id_note
    AND f.fact_id < rec_no_recent_open_fact.fact_id;

    SELECT /* Notes-staging */ recent_opened_dimension_id_date
     INTO m_recent_opened_dimension_id_date
    FROM dwh.facts f
    WHERE f.fact_id = m_previous_action_fact_id;

    UPDATE dwh.facts
     SET recent_opened_dimension_id_date = m_recent_opened_dimension_id_date
     WHERE CURRENT OF no_recent_open;
    --RAISE NOTICE 'Updating id_note % with fact_id % data %.',
    -- rec_no_recent_open_fact.id_note, m_previous_action_fact_id,
    -- m_recent_opened_dimension_id_date;
   END LOOP;

   m_previous_action_fact_id := null;
   m_recent_opened_dimension_id_date := null;

   CLOSE no_recent_open;
   m_iter := m_iter + 1;
  END LOOP;
 END
 $$
;

-- TODO FIXME This deletes facts that had importing issues. This should be corrected
-- because some facts are being lost. The issue is why these facts had
-- importing issues, like why it did not load all "opens".
DELETE FROM dwh.facts
  WHERE recent_opened_dimension_id_date IS NULL;

ALTER TABLE dwh.facts ALTER COLUMN recent_opened_dimension_id_date SET NOT NULL;
