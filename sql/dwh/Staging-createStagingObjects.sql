-- Chech staging tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-22

CREATE SCHEMA IF NOT EXISTS staging;
COMMENT ON SCHEMA staging IS
  'Objects to load from base tables to data warehouse';

CREATE OR REPLACE PROCEDURE staging.process_notes_at_date (
  max_processed_timestamp TIMESTAMP
 )
 LANGUAGE plpgsql
 AS $proc$
 DECLARE
  m_dimension_country_id INTEGER;
  m_dimension_user_open INTEGER;
  m_dimension_user_close INTEGER;
  m_dimension_user_action INTEGER;
  m_opened_id_date INTEGER;
  m_opened_id_hour_of_week INTEGER;
  m_closed_id_date INTEGER;
  m_closed_id_hour_of_week INTEGER;
  m_action_id_date INTEGER;
  m_action_id_hour_of_week INTEGER;
  rec_note_action RECORD;
  notes_on_day CURSOR (c_max_processed_timestamp TIMESTAMP) FOR
   SELECT
    c.note_id id_note, n.created_at created_at, o.id_user created_id_user,
    n.id_country id_country, c.event action_comment, c.id_user action_id_user,
    c.created_at action_at
   FROM note_comments c
    JOIN notes n
    ON (c.note_id = n.note_id)
    JOIN note_comments o
    ON (n.note_id = o.note_id AND o.event = 'opened')
   WHERE c.created_at > c_max_processed_timestamp 
    AND DATE(c.created_at) = DATE(c_max_processed_timestamp) -- Notes for the
      -- same date.
   ORDER BY c.note_id, c.id;

 BEGIN
  --RAISE NOTICE 'Processing at %', max_processed_timestamp;

  OPEN notes_on_day(max_processed_timestamp);

  LOOP
    FETCH notes_on_day INTO rec_note_action;
    -- Exit when no more rows to fetch.
    EXIT WHEN NOT FOUND;

    -- Gets the country of the comment.
    SELECT dimension_country_id
     INTO m_dimension_country_id
    FROM dwh.dimension_countries
    WHERE country_id = rec_note_action.id_country;
    IF (m_dimension_country_id IS NULL) THEN
     m_dimension_country_id := 1;
    END IF;

    -- Gets the user who created the note.
    SELECT dimension_user_id
     INTO m_dimension_user_open
    FROM dwh.dimension_users
    WHERE user_id = rec_note_action.created_id_user;
    
    -- Gets the user who performed the action (if action is opened, then it 
    -- is the same).
    SELECT dimension_user_id
     INTO m_dimension_user_action
    FROM dwh.dimension_users
    WHERE user_id = rec_note_action.action_id_user;

    -- Gets the days of the actions
    m_opened_id_date := dwh.get_date_id(rec_note_action.created_at);
    m_opened_id_hour_of_week :=
      dwh.get_hour_of_week_id(rec_note_action.created_at);
    m_action_id_date := dwh.get_date_id(rec_note_action.action_at);
    m_action_id_hour_of_week :=
      dwh.get_hour_of_week_id(rec_note_action.action_at);

    -- When the action is 'closed' it copies the data from the 'action'.
    IF (rec_note_action.action_comment = 'closed') THEN
     m_closed_id_date := m_action_id_date;
     m_closed_id_hour_of_week := m_action_id_hour_of_week;
     m_dimension_user_close := m_dimension_user_action;
    END IF;

    -- Insert the fact.
    INSERT INTO dwh.facts (
      id_note, dimension_id_country,
      action_at, action_comment, action_dimension_id_date,
      action_dimension_id_hour_of_week, action_dimension_id_user, 
      opened_dimension_id_date, opened_dimension_id_hour_of_week,
      opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user
    ) VALUES (
      rec_note_action.id_note, m_dimension_country_id,
      rec_note_action.action_at, rec_note_action.action_comment,
      m_action_id_date, m_action_id_hour_of_week, m_dimension_user_action,
      m_opened_id_date, m_opened_id_hour_of_week, m_dimension_user_open,
      m_closed_id_date, m_closed_id_hour_of_week, m_dimension_user_close
    );

    -- Modifies the dimension user and country for the datamart to identify it.
    UPDATE dwh.dimension_users
     SET modified = TRUE
     WHERE dimension_user_id = m_dimension_user_action;

    UPDATE dwh.dimension_countries
     SET modified = TRUE
     WHERE dimension_country_id = m_dimension_country_id;

    -- Resets the variables.
    m_dimension_country_id := null;

    m_opened_id_date := null;
    m_opened_id_hour_of_week := null;
    m_dimension_user_open := null;

    m_closed_id_date := null;
    m_closed_id_hour_of_week := null;
    m_dimension_user_close := null;

    m_action_id_date := null;
    m_action_id_hour_of_week := null;
    m_dimension_user_action := null;
  END LOOP;

  CLOSE notes_on_day;
  COMMIT;
 END
$proc$
;
COMMENT ON PROCEDURE staging.process_notes_at_date IS
  'Processes all comments from base tables more recent thatn a specific timestamp and loads them in the data warehouse';

CREATE OR REPLACE PROCEDURE staging.process_notes_actions_into_dwh (
 )
 LANGUAGE plpgsql
 AS $proc$
 DECLARE
  qty_dwh_notes INTEGER;
  qty_notes_on_date INTEGER;
  max_note_action_date DATE;
  max_note_on_dwh_timestamp TIMESTAMP;
  max_processed_date DATE;
 BEGIN

  -- Base case, when at least the first day of notes is processed.
  -- There are 231 note actions this day: 2013-04-24 (Epoch's OSM notes).
  SELECT COUNT(1)
   INTO qty_dwh_notes
  FROM dwh.facts;
  IF (qty_dwh_notes = 0) THEN
   RAISE NOTICE '0 facts, processing all history. It could take several hours';
   CALL staging.process_notes_at_date('2013-04-24 00:00:00.000000+00');
  END IF;

  -- Recursive case, when there is at least a day already processed.
  -- Gets the date of the most recent note action from base tables.
  SELECT MAX(DATE(created_at))
   INTO max_note_action_date
  FROM note_comments;
  --RAISE NOTICE 'recursive case %', max_note_action_date;

  -- Gest the date of the most recent note processed on the DWH.
  SELECT MAX(date_id)
   INTO max_processed_date
  FROM dwh.facts f
   JOIN dwh.dimension_days d 
   ON (f.action_dimension_id_date = d.dimension_day_id);
  --RAISE NOTICE 'get max processed date from facts %', max_processed_date;

  IF (max_note_action_date < max_processed_date) THEN
   RAISE EXCEPTION 'DWH has more recent notes than received on base tables.';
  END IF;

  -- Processes notes while the max note received is equal to the most recent
  -- note processed.
  WHILE (max_processed_date <= max_note_action_date) LOOP
  --RAISE NOTICE 'test % < %', max_processed_date, max_note_action_date;
   -- Timestamp of the max processed note on DWH.
   -- It is on the same DATE of max_processed_date.
   SELECT MAX(action_at)
    INTO max_note_on_dwh_timestamp
   FROM dwh.facts
   WHERE DATE(action_at) = max_processed_date;
  --RAISE NOTICE 'max timestamp dwh %', max_note_on_dwh_timestamp;
   IF (max_note_on_dwh_timestamp IS NULL) THEN
    max_note_on_dwh_timestamp := max_processed_date::TIMESTAMP;
   END IF;

   -- Gets the number of notes that have not being processed on the date being
   -- processed.
   SELECT COUNT(1)
    INTO qty_notes_on_date
   FROM note_comments
   WHERE DATE(created_at) = max_processed_date
    AND created_at > max_note_on_dwh_timestamp;
  --RAISE NOTICE 'count notes to process on date %: %', max_processed_date,
  --qty_notes_on_date;

   -- If there are 0 notes to process, then increase one day.
   IF (qty_notes_on_date = 0) THEN
    max_processed_date := max_processed_date + 1;
    --RAISE NOTICE 'Increasing 1 day, processing facts for %',
    -- max_processed_date;

    SELECT COUNT(1)
     INTO qty_notes_on_date
    FROM note_comments
    WHERE DATE(created_at) = max_processed_date
     AND created_at > max_note_on_dwh_timestamp;
    --RAISE NOTICE 'Notes to process for %: %', max_processed_date,
    -- qty_notes_on_date;

    CALL staging.process_notes_at_date(max_note_on_dwh_timestamp);
   ELSE
    -- There are comments not processed on the DHW for the currently processing
    -- day.
    --RAISE NOTICE 'Processing facts for %: %', max_processed_date,
    -- qty_notes_on_date;

    CALL staging.process_notes_at_date(max_note_on_dwh_timestamp);
   END IF;
   --RAISE NOTICE 'loop % - % - %', max_processed_date,
   --max_note_on_dwh_timestamp, qty_notes_on_date;
  END LOOP;
  RAISE NOTICE 'No facts to process (% !> %)', max_processed_date, max_note_action_date;
 END
$proc$
;
COMMENT ON PROCEDURE staging.process_notes_actions_into_dwh IS
  'Processes all non-processes notes';
