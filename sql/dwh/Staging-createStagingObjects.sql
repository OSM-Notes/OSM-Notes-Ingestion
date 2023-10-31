-- Chech staging tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-28

CREATE SCHEMA IF NOT EXISTS staging;

CREATE OR REPLACE PROCEDURE staging.process_notes_at_date (
  process_date DATE
 )
 LANGUAGE plpgsql
 AS $proc$
 DECLARE
  m_dimension_country_id INTEGER;
  m_dimension_user_open INTEGER;
  m_dimension_user_close INTEGER;
  m_dimension_user_action INTEGER;
  closed_at TIMESTAMP;
  action_id_date INTEGER;
  action_id_hour INTEGER;
  rec_note_action RECORD;
  notes_on_day CURSOR (c_process_date DATE) FOR
   SELECT
    c.note_id id_note, n.created_at created_at, o.id_user created_id_user,
    n.id_country id_country, c.event action_comment, c.id_user action_id_user,
    c.created_at action_at
   FROM note_comments c
    JOIN notes n
    ON (c.note_id = n.note_id)
    JOIN note_comments o
    ON (n.note_id = o.note_id AND o.event = 'opened')
   WHERE DATE(c.created_at) = c_process_date
   ORDER BY c.note_id, c.created_at;

 BEGIN

  OPEN notes_on_day(process_date);

  LOOP
    FETCH notes_on_day INTO rec_note_action;
    -- Exit when no more row to fetch.
    EXIT WHEN NOT FOUND;

    action_id_date := dwh.get_date_id(rec_note_action.action_at);
    action_id_hour := dwh.get_time_id(rec_note_action.action_at);
    SELECT dimension_user_id INTO m_dimension_user_open
     FROM dwh.dimension_users
     WHERE user_id = rec_note_action.created_id_user;
    SELECT dimension_user_id INTO m_dimension_user_action
     FROM dwh.dimension_users
     WHERE user_id = rec_note_action.action_id_user;
    SELECT dimension_country_id INTO m_dimension_country_id
     FROM dwh.dimension_countries
     WHERE country_id = rec_note_action.id_country;

    IF (rec_note_action.action_comment = 'closed') THEN
     closed_at := rec_note_action.action_at;
     m_dimension_user_close := m_dimension_user_action;
    END IF;

    INSERT INTO dwh.facts (
      id_note, created_at, created_dimension_id_user, closed_at,
      closed_dimension_id_user, dimension_id_country, action_comment, 
      action_dimension_id_user, action_at, action_dimension_id_date,
      action_dimension_id_hour
    ) VALUES (
      rec_note_action.id_note, rec_note_action.created_at,
      m_dimension_user_open, closed_at, m_dimension_user_close,
      m_dimension_country_id, rec_note_action.action_comment,
      m_dimension_user_action, rec_note_action.action_at,
      action_id_date, action_id_hour
    );
  END LOOP;

  CLOSE notes_on_day;
  COMMIT;
 END
$proc$
;

CREATE OR REPLACE PROCEDURE staging.process_notes_actions_into_dwh (
 )
 LANGUAGE plpgsql
 AS $proc$
 DECLARE
  qty_dwh_notes INTEGER;
  qty_notes_on_date INTEGER;
  max_note_action DATE;
  max_note_on_dwh TIMESTAMP;
  max_processed_date DATE;
 BEGIN

  -- Base case, when at least the first day of notes is processed.
  -- There are 231 note actions this day: 2013-04-24 (Epoch's OSM notes).
  SELECT COUNT(1) INTO qty_dwh_notes
    FROM dwh.facts;
  IF (qty_dwh_notes = 0) THEN
   CALL staging.process_notes_at_date ('2013-04-24');
  END IF;

  -- Recursive case, when there is at least a day already processed.
  -- Gets the most recent note action.
  SELECT MAX(DATE(created_at)) INTO max_note_action
    FROM note_comments;

  -- Gest the most recent note processed.
  SELECT MAX(date_id) INTO max_processed_date
  FROM dwh.facts f JOIN dwh.dimension_days d 
  ON (f.action_dimension_id_date = d.dimension_day_id);

  IF (max_note_action < max_processed_date) THEN
   RAISE EXCEPTION 'DWH has recent notes than received.';
  END IF;

  -- Processes notes while the max note received is equal to the most recent
  -- note processed.
  WHILE (max_processed_date < max_note_action) LOOP
   SELECT MAX(action_at) INTO max_note_on_dwh
   FROM dwh.facts;

   -- Gets the number of notes of the date.
   SELECT COUNT(1) INTO qty_notes_on_date
   FROM note_comments
   WHERE DATE(created_at) = max_processed_date
   AND created_at > max_note_on_dwh;
   -- If there are 0 notes to process, then increase one day.
   IF (qty_notes_on_date = 0) THEN
    max_processed_date := max_processed_date + 1;
    CALL staging.process_notes_at_date (max_processed_date);
   ELSE
    CALL staging.process_notes_at_date (max_processed_date);
   END IF;
  END LOOP;
 END
$proc$
