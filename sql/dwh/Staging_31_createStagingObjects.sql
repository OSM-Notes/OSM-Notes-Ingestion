-- Chech staging tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-13

CREATE SCHEMA IF NOT EXISTS staging;
COMMENT ON SCHEMA staging IS
  'Objects to load from base tables to data warehouse';

CREATE OR REPLACE FUNCTION staging.get_application (
 m_text_comment TEXT
) RETURNS INTEGER
 LANGUAGE plpgsql
 AS $func$
 DECLARE
  m_id_dimension_application INTEGER;
  r RECORD;
 BEGIN
  <<application_found>>
  FOR r IN
   SELECT /* Notes-staging */ pattern, dimension_application_id
   FROM dwh.dimension_applications
  LOOP
   IF (r.pattern IS NOT NULL AND m_text_comment SIMILAR TO r.pattern) THEN
    m_id_dimension_application := r.dimension_application_id;
    EXIT application_found;
   END IF;
  END LOOP;
  RETURN m_id_dimension_application;
 END
 $func$
;
COMMENT ON FUNCTION staging.get_application IS
  'Returns the name of the application.';

CREATE OR REPLACE FUNCTION staging.get_hashtag_id (
 m_hashtag_name TEXT
) RETURNS INTEGER
 LANGUAGE plpgsql
 AS $func$
 DECLARE
  m_id_dimension_hashtag INTEGER;
  r RECORD;
 BEGIN
  --RAISE NOTICE 'Requesting id for hashtag: %', m_hashtag_name;
  IF (m_hashtag_name IS NULL) THEN
   m_id_dimension_hashtag := 1;
  ELSE
   SELECT /* Notes-staging */ dimension_hashtag_id
    INTO m_id_dimension_hashtag
   FROM dwh.dimension_hashtags
   WHERE description = m_hashtag_name;

   IF (m_id_dimension_hashtag IS NULL) THEN
    INSERT INTO dwh.dimension_hashtags (
      description
     ) VALUES (
      m_hashtag_name
     )
     RETURNING dimension_hashtag_id
      INTO m_id_dimension_hashtag
    ;
   END IF;
  END IF;
  RETURN m_id_dimension_hashtag;
 END
 $func$
;
COMMENT ON FUNCTION staging.get_hashtag_id IS
  'Returns the id of the hashtag.';

CREATE OR REPLACE PROCEDURE staging.get_hashtag (
  INOUT m_text_comment TEXT,
  OUT m_hashtag_name TEXT
 )
 LANGUAGE plpgsql
 AS $proc$
 DECLARE
  pos INTEGER;
  substr_after TEXT;
  length INTEGER;
 BEGIN
  pos := STRPOS(m_text_comment, '#');
  IF (pos <> 0) THEN
   --RAISE NOTICE 'Position number sign: %', pos;
   substr_after := SUBSTR(m_text_comment, pos+1);
   --RAISE NOTICE 'Substring after number sign: %', substr_after;
   m_hashtag_name := ARRAY_TO_STRING(REGEXP_MATCHES(substr_after, '^\w+'), ';');
   --RAISE NOTICE 'Hashtag name: %', m_hashtag_name;
   length := LENGTH(m_hashtag_name);
   --RAISE NOTICE 'Length hashtag name: %', length;
   m_text_comment := SUBSTR(substr_after, length+2);
   --RAISE NOTICE 'New substring: %', m_text_comment;
  ELSE
   m_text_comment := NULL;
  END IF;
 END
$proc$
;
COMMENT ON PROCEDURE staging.get_hashtag IS
  'Returns the first hashtag of the given string';

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
  m_application INTEGER;
  m_recent_opened_dimension_id_date INTEGER;
  m_hashtag_id_1 INTEGER;
  m_hashtag_id_2 INTEGER;
  m_hashtag_id_3 INTEGER;
  m_hashtag_id_4 INTEGER;
  m_hashtag_id_5 INTEGER;
  m_hashtag_number INTEGER;
  m_previous_action_fact_id INTEGER;
  m_count INTEGER;
  m_text_comment TEXT;
  m_hashtag_name TEXT;
  rec_note_action RECORD;
  notes_on_day CURSOR (c_max_processed_timestamp TIMESTAMP) FOR
   SELECT /* Notes-staging */
    c.fact_id fact_id, c.note_id id_note, n.created_at created_at,
    o.id_user created_id_user, n.id_country id_country, c.sequence_action seq,
    c.event action_comment, c.id_user action_id_user, c.created_at action_at,
    t.body
   FROM note_comments c
    JOIN notes n
    ON (c.note_id = n.note_id)
    JOIN note_comments o
    ON (n.note_id = o.note_id AND o.event = 'opened')
    JOIN note_comments_text t
    ON (c.note_id = t.note_id AND c.sequence_action = t.sequence_action)
   WHERE c.created_at > c_max_processed_timestamp 
    AND DATE(c.created_at) = DATE(c_max_processed_timestamp) -- Notes for the
      -- same date.
   ORDER BY c.note_id, c.id;

 BEGIN
  SELECT /* Notes-staging */ COUNT(1)
   INTO m_count
  FROM dwh.facts;

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
    WHERE note_id = rec_note_action.id_note
     AND sequence_action = rec_note_action.seq; -- Sequence should be 1.
    m_application := staging.get_application(m_text_comment);
   ELSE
    m_application := NULL;
   END IF;

   -- Gets the most recent opening action: creation or reopening.
   IF (rec_note_action.action_comment = 'opened') THEN
    m_recent_opened_dimension_id_date := m_opened_id_date;
   ELSIF (rec_note_action.action_comment = 'reopened') THEN
    m_recent_opened_dimension_id_date := m_action_id_date;
   ELSE
    SELECT /* Notes-staging */ max(fact_id)
     INTO m_previous_action_fact_id
    FROM dwh.facts f
    WHERE f.id_note = rec_note_action.id_note
     AND f.fact_id < rec_note_action.fact_id;
  
    SELECT /* Notes-staging */ recent_opened_dimension_id_date
     INTO m_recent_opened_dimension_id_date
    FROM dwh.facts f
    WHERE f.fact_id = m_previous_action_fact_id;
   END IF;

   -- Gets hashtags.
   IF (rec_note_action.body LIKE '%#%') THEN
    m_text_comment := rec_note_action.body;
    --RAISE NOTICE 'Requesting id for hashtag: %', m_hashtag_name;
    CALL staging.get_hashtag(m_text_comment, m_hashtag_name);
    m_hashtag_id_1 := staging.get_hashtag_id(m_hashtag_name);
    m_hashtag_number := 1;
    --RAISE NOTICE 'hashtag: %: %', m_hashtag_id_1, m_hashtag_name;
    IF (m_text_comment LIKE '%#%') THEN
     CALL staging.get_hashtag(m_text_comment, m_hashtag_name);
     m_hashtag_id_2 := staging.get_hashtag_id(m_hashtag_name);
     m_hashtag_number := 2;
     IF (m_text_comment LIKE '%#%') THEN
      CALL staging.get_hashtag(m_text_comment, m_hashtag_name);
      m_hashtag_id_3 := staging.get_hashtag_id(m_hashtag_name);
      m_hashtag_number := 3;
      IF (m_text_comment LIKE '%#%') THEN
       CALL staging.get_hashtag(m_text_comment, m_hashtag_name);
       m_hashtag_id_4 := staging.get_hashtag_id(m_hashtag_name);
       m_hashtag_number := 4;
       IF (m_text_comment LIKE '%#%') THEN
        CALL staging.get_hashtag(m_text_comment, m_hashtag_name);
        m_hashtag_id_5 := staging.get_hashtag_id(m_hashtag_name);
        m_hashtag_number := 5;
        WHILE (m_text_comment LIKE '%#%') DO
         CALL staging.get_hashtag(m_text_comment, m_hashtag_name);
         -- If there are new hashtags, it does not insert them in the dimension.
         m_hashtag_number := m_hashtag_number + 1;
        END WHILE;
       END IF;
      END IF;
     END IF;
    END IF;
   END IF;

   -- Insert the fact.
   INSERT INTO dwh.facts (
     id_note, dimension_id_country,
     action_at, action_comment, action_dimension_id_date,
     action_dimension_id_hour_of_week, action_dimension_id_user, 
     opened_dimension_id_date, opened_dimension_id_hour_of_week,
     opened_dimension_id_user,
     closed_dimension_id_date, closed_dimension_id_hour_of_week,
     closed_dimension_id_user, dimension_application_creation,
     recent_opened_dimension_id_date, hashtag_1, hashtag_2, hashtag_3,
     hashtag_4, hashtag_5, hashtag_number
   ) VALUES (
     rec_note_action.id_note, m_dimension_country_id,
     rec_note_action.action_at, rec_note_action.action_comment,
     m_action_id_date, m_action_id_hour_of_week, m_dimension_user_action,
     m_opened_id_date, m_opened_id_hour_of_week, m_dimension_user_open,
     m_closed_id_date, m_closed_id_hour_of_week, m_dimension_user_close,
     m_application, m_recent_opened_dimension_id_date, m_hashtag_id_1,
     m_hashtag_id_2, m_hashtag_id_3, m_hashtag_id_4, m_hashtag_id_5,
     m_hashtag_number
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

   m_text_comment := null;
   m_hashtag_name := null;
   m_hashtag_id_1 := null;
   m_hashtag_id_2 := null;
   m_hashtag_id_3 := null;
   m_hashtag_id_4 := null;
   m_hashtag_id_5 := null;
   hashtag_number := 0;

   SELECT /* Notes-staging */ COUNT(1)
    INTO m_count
   FROM dwh.facts;
   IF (MOD(m_count, 1000) = 0) THEN
    RAISE NOTICE '%: % processed facts until %', CURRENT_TIMESTAMP, m_count,
     max_processed_timestamp;
   END IF;

   m_count := m_count + 1;
  END LOOP;

  CLOSE notes_on_day;
  COMMIT;
 END
$proc$
;
COMMENT ON PROCEDURE staging.process_notes_at_date IS
  'Processes all comments from base tables more recent than a specific timestamp and loads them in the data warehouse';

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
  SELECT /* Notes-staging */ COUNT(1)
   INTO qty_dwh_notes
  FROM dwh.facts;
  IF (qty_dwh_notes = 0) THEN
   RAISE NOTICE '0 facts, processing all history. It could take several hours';
   CALL staging.process_notes_at_date('2013-04-24 00:00:00.000000+00');
  END IF;

  -- Recursive case, when there is at least a day already processed.
  -- Gets the date of the most recent note action from base tables.
  SELECT /* Notes-staging */ MAX(DATE(created_at))
   INTO max_note_action_date
  FROM note_comments;
  --RAISE NOTICE 'recursive case %', max_note_action_date;

  -- Gets the date of the most recent note processed on the DWH.
  SELECT /* Notes-staging */ MAX(date_id)
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
   SELECT /* Notes-staging */ MAX(action_at)
    INTO max_note_on_dwh_timestamp
   FROM dwh.facts
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
    AND created_at > max_note_on_dwh_timestamp;
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
   -- max_note_on_dwh_timestamp, qty_notes_on_date;
  END LOOP;
  --RAISE NOTICE 'No facts to process (% !> %)', max_processed_date, max_note_action_date;
 END
$proc$
;
COMMENT ON PROCEDURE staging.process_notes_actions_into_dwh IS
  'Processes all non-processes notes';
