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
  closed_at TIMESTAMP;
  closed_id_user INTEGER;
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

  OPEN notes_on_day(rocess_date);

  LOOP
    FETCH notes_on_day INTO notes_on_day;
    -- Exit when no more row to fetch.
    EXIT WHEN NOT FOUND;

    IF (notes_on_day.action_comment = 'closed') THEN
     closed_at := notes_on_day.action_at;
     closed_id_user := notes_on_day.action_id_user;
    END IF;

    action_id_date := get_data_id(notes_on_day.action_at);
    action_id_hour := get_time_id(notes_on_day.action_at);

    INSERT INTO dwh.facts (
      id_note, created_at, created_id_user, closed_at, closed_id_user,
      id_country, action_comment, action_id_user, action_at, action_id_date,
      action_id_hour
    ) VALUES (
      notes_on_day.id_note, notes_on_day.created_at,
      notes_on_day.created_id_user, closed_at, closed_id_user,
      notes_on_day.id_country, notes_on_day.action_comment,
      notes_on_day.action_id_user, notes_on_day.action_at, action_id_date,
      action_id_hour
    );
  END LOOP;

  CLOSE notes_on_day;
 END
$proc$

CREATE OR REPLACE PROCEDURE staging.process_notes_actions_into_dwh (
 )
 LANGUAGE plpgsql
 AS $proc$
 DECLARE
  qty_dwh_notes INTEGER;
  qty_notes_on_date INTEGER;
  max_note_action DATE;
  max_processed_date DATE;
 BEGIN

  -- Base case, when at least the first day of notes is processed.
  -- There are 231 note actions this day: 2013-04-24 (Epoch's OSM notes).
  SELECT COUNT(1) INTO qty_dwh_notes
    FROM dwh.facts;
  IF (qty_dwh_notes = 0) THEN
   CALL process_notes_at_date ('2013-04-24');
  END IF;

  -- Recursive case, when there is at least a day already processed.
  -- Gets the most recent note action.
  SELECT MAX(DATE(created_at)) INTO max_note_action
    FROM note_comments;

  -- Gest the most recent note processed.
  SELECT MAX(action_id_date) INTO max_processed_date
    FROM dwh.facts;

  IF (max_note_action < max_processed_date) THEN
   RAISE EXCEPTION 'DWH has recent notes than received.';
  END IF;

  -- Processes notes while the max note received is equal to the most recent
  -- note processed.
  WHILE (max_processed_date < max_note_action) DO
   -- Gets the number of notes of the date.
   SELECT COUNT(1) INTO qty_notes_on_date
   FROM note_comments
   WHERE DATE(created_at) = max_processed_date;
  
   -- If there are 0 notes to process, then increase one day.
   IF (qty_notes_on_date = 0) THEN
    max_processed_date = max_processed_date + 1 day;
   ELSE
    CALL process_notes_at_date (max_processed_date);
   END IF;
  END DO;
 END
$proc$
