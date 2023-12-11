-- Loads data warehouse data for year ${YEAR}.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-09

CREATE TABLE dwh.facts_${YEAR} AS TABLE dwh.facts;

CREATE SEQUENCE dwh.facts_${YEAR}_seq;

ALTER TABLE dwh.facts_${YEAR} ALTER fact_id
  SET DEFAULT NEXTVAL('dwh.facts_${YEAR}_seq'::regclass);

ALTER TABLE dwh.facts_${YEAR} ALTER processing_time
  SET DEFAULT CURRENT_TIMESTAMP;

CREATE OR REPLACE PROCEDURE staging.process_notes_at_date_${YEAR} (
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
  m_application INTEGER;
  m_count INTEGER;
  m_text_comment TEXT;
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
    AND EXTRACT(YEAR FROM c.created_at) = EXTRACT(YEAR FROM c_max_processed_timestamp)
   ORDER BY c.note_id, c.id;

 BEGIN
  SELECT /* Notes-staging */ COUNT(1)
   INTO m_count
  FROM dwh.facts_${YEAR};

  --RAISE NOTICE 'Processing at %', max_processed_timestamp;

  OPEN notes_on_day(max_processed_timestamp);

  LOOP
   FETCH notes_on_day INTO rec_note_action;
   -- Exit when no more rows to fetch.
   EXIT WHEN NOT FOUND;

   -- Gets the country of the comment.
   SELECT /* Notes-staging */ dimension_country_id
    INTO m_dimension_country_id
   FROM dwh.dimension_countries
   WHERE country_id = rec_note_action.id_country;
   IF (m_dimension_country_id IS NULL) THEN
    m_dimension_country_id := 1;
   END IF;

   -- Gets the user who created the note.
   SELECT /* Notes-staging */ dimension_user_id
    INTO m_dimension_user_open
   FROM dwh.dimension_users
   WHERE user_id = rec_note_action.created_id_user;
    
   -- Gets the user who performed the action (if action is opened, then it 
   -- is the same).
   SELECT /* Notes-staging */ dimension_user_id
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

   -- Gets the id of the app, if the action is opening.
   IF (rec_note_action.action_comment = 'opened') THEN
    SELECT /* Notes-staging */ body
     INTO m_text_comment
    FROM note_comments_text
    WHERE note_id = rec_note_action.id_note;
    m_application := staging.get_application(m_text_comment);
   ELSE
    m_application := NULL;
   END IF;

   -- Insert the fact.
   INSERT INTO dwh.facts_${YEAR} (
     id_note, dimension_id_country,
     action_at, action_comment, action_dimension_id_date,
     action_dimension_id_hour_of_week, action_dimension_id_user, 
     opened_dimension_id_date, opened_dimension_id_hour_of_week,
     opened_dimension_id_user,
     closed_dimension_id_date, closed_dimension_id_hour_of_week,
     closed_dimension_id_user, dimension_application_creation
   ) VALUES (
     rec_note_action.id_note, m_dimension_country_id,
     rec_note_action.action_at, rec_note_action.action_comment,
     m_action_id_date, m_action_id_hour_of_week, m_dimension_user_action,
     m_opened_id_date, m_opened_id_hour_of_week, m_dimension_user_open,
     m_closed_id_date, m_closed_id_hour_of_week, m_dimension_user_close,
     m_application
   );

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

   SELECT /* Notes-staging */ COUNT(1)
    INTO m_count
   FROM dwh.facts_${YEAR};
   IF (MOD(m_count, 1000) = 0) THEN
    RAISE NOTICE '%: % processed facts for % until %', CURRENT_TIMESTAMP,
     m_count, ${YEAR}, max_processed_timestamp;
   END IF;

   m_count := m_count + 1;
  END LOOP;

  CLOSE notes_on_day;
  COMMIT;
 END
$proc$
;
COMMENT ON PROCEDURE staging.process_notes_at_date_${YEAR} IS
  'Processes comments for ${YEAR} from base tables more recent than a specific timestamp and loads them in the data warehouse';

CREATE OR REPLACE PROCEDURE staging.process_notes_actions_into_dwh_${YEAR} (
 )
 LANGUAGE plpgsql
 AS
$$
 DECLARE
  qty_dwh_notes INTEGER;
  qty_notes_on_date INTEGER;
  max_note_action_date DATE;
  max_note_on_dwh_timestamp TIMESTAMP;
  max_processed_date DATE;
  min_timestamp TIMESTAMP;
  m_day_year DATE;
  m_dummy INTEGER;
  m_max_day_year DATE;
 BEGIN
  -- Insert all days of the year in the dimension.
  SELECT /* Notes-staging */ DATE('${YEAR}-01-01')
    INTO m_day_year;
  SELECT /* Notes-staging */ DATE('${YEAR}-12-31')
    INTO m_max_day_year;
  RAISE NOTICE 'Min and max dates % - %', m_day_year, m_max_day_year;
  WHILE (m_day_year <= m_max_day_year) LOOP
   m_dummy := dwh.get_date_id(m_day_year);
   -- RAISE NOTICE 'Processed date %', m_day_year;
   SELECT /* Notes-staging */ m_day_year + 1
     INTO m_day_year;
  END LOOP;

  -- Base case, when at least the first day of notes of the year is processed.
  SELECT /* Notes-staging */ COUNT(1)
   INTO qty_dwh_notes
  FROM dwh.facts_${YEAR};
  IF (qty_dwh_notes = 0) THEN
   -- This is usually January 1st, except for 2013.
   RAISE NOTICE '0 facts, processing all year ${YEAR}. It could take several hours';
   SELECT /* Notes-staging */ MIN(created_at)
    INTO min_timestamp
   FROM note_comments
   WHERE EXTRACT(YEAR FROM created_at) = ${YEAR};
   CALL staging.process_notes_at_date_${YEAR}(min_timestamp);
  END IF;

  -- Recursive case, when there is at least a day already processed.
  -- Gets the date of the most recent note action from base tables.
  SELECT /* Notes-staging */ MAX(DATE(created_at))
   INTO max_note_action_date
  FROM note_comments
  WHERE EXTRACT(YEAR FROM created_at) = ${YEAR};
  --RAISE NOTICE 'recursive case %', max_note_action_date;

  -- Gets the date of the most recent note processed on the DWH.
  SELECT /* Notes-staging */ MAX(date_id)
   INTO max_processed_date
  FROM dwh.facts_${YEAR} f
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
   SELECT /* Notes-staging */ MAX(action_at)
    INTO max_note_on_dwh_timestamp
   FROM dwh.facts_${YEAR}
   WHERE DATE(action_at) = max_processed_date;
   --RAISE NOTICE 'max timestamp dwh %', max_note_on_dwh_timestamp;
   IF (max_note_on_dwh_timestamp IS NULL) THEN
    max_note_on_dwh_timestamp := max_processed_date::TIMESTAMP;
   END IF;

   -- Gets the number of notes that have not being processed on the date being
   -- processed.
   SELECT /* Notes-staging */ COUNT(1)
    INTO qty_notes_on_date
   FROM note_comments
   WHERE DATE(created_at) = max_processed_date
    AND created_at > max_note_on_dwh_timestamp
     AND EXTRACT(YEAR FROM created_at) = ${YEAR};
   --RAISE NOTICE 'count notes to process on date %: %', max_processed_date,
   -- qty_notes_on_date;

   -- If there are 0 notes to process, then increase one day.
   IF (qty_notes_on_date = 0) THEN
    max_processed_date := max_processed_date + 1;
    --RAISE NOTICE 'Increasing 1 day, processing facts for %',
    -- max_processed_date;

    SELECT /* Notes-staging */ COUNT(1)
     INTO qty_notes_on_date
    FROM note_comments
    WHERE DATE(created_at) = max_processed_date
     AND created_at > max_note_on_dwh_timestamp
     AND EXTRACT(YEAR FROM created_at) = ${YEAR};
    --RAISE NOTICE 'Notes to process for %: %', max_processed_date,
    -- qty_notes_on_date;

    CALL staging.process_notes_at_date_${YEAR}(max_note_on_dwh_timestamp);
   ELSE
    -- There are comments not processed on the DHW for the currently processing
    -- day.
    --RAISE NOTICE 'Processing facts for %: %', max_processed_date,
    -- qty_notes_on_date;

    CALL staging.process_notes_at_date_${YEAR}(max_note_on_dwh_timestamp);
   END IF;
   --RAISE NOTICE 'loop % - % - %', max_processed_date,
   -- max_note_on_dwh_timestamp, qty_notes_on_date;
  END LOOP;
  --RAISE NOTICE 'No facts to process (% !> %)', max_processed_date, max_note_action_date;
 END
$$
;
COMMENT ON PROCEDURE staging.process_notes_actions_into_dwh_${YEAR} IS
  'Inserts facts for year ${YEAR}';
