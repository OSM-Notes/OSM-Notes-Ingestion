-- Procedure to insert datamart user.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-17

/**
 * Inserts a user in the datamart, with the values that do not change.
 */
CREATE OR REPLACE PROCEDURE dwh.insert_datamart_user (
  m_dimension_user_id INTEGER
)
LANGUAGE plpgsql
AS $proc$
 DECLARE
  m_user_id INTEGER;
  m_username VARCHAR(256);
  m_date_starting_creating_notes DATE;
  m_date_starting_solving_notes DATE;
  m_first_open_note_id INTEGER;
  m_first_commented_note_id INTEGER;
  m_first_closed_note_id INTEGER;
  m_first_reopened_note_id INTEGER;
  m_last_year_activity CHAR(371);
  r RECORD;
 BEGIN
  -- Gets the OSM user id and the username.
  SELECT /* Notes-datamartUsers */ user_id, username
   INTO m_user_id, m_username
  FROM dwh.dimension_users
  WHERE dimension_user_id = m_dimension_user_id;

  -- Gets the date of the first note created by the current user.
  -- date_starting_creating_notes
  SELECT /* Notes-datamartUsers */ MIN(date_id)
   INTO m_date_starting_creating_notes
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.opened_dimension_id_date = d.dimension_day_id)
  WHERE f.opened_dimension_id_user = m_dimension_user_id;

  -- Gets the date of the first note resolved by the current user.
  -- date_starting_solving_notes
  SELECT /* Notes-datamartUsers */ MIN(date_id)
   INTO m_date_starting_solving_notes
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.closed_dimension_id_date = d.dimension_day_id)
   WHERE f.closed_dimension_id_user = m_dimension_user_id;

  -- first_open_note_id
  SELECT /* Notes-datamartUsers */ MIN(id_note)
   INTO m_first_open_note_id
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'opened';

  -- first_commented_note_id
  SELECT /* Notes-datamartUsers */ MIN(id_note)
   INTO m_first_commented_note_id
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'commented';

  -- first_closed_note_id
  SELECT /* Notes-datamartUsers */ MIN(id_note)
   INTO m_first_closed_note_id
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'closed';

  -- first_reopened_note_id
  SELECT /* Notes-datamartUsers */ MIN(id_note)
   INTO m_first_reopened_note_id
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'reopened';

  -- Creates the activity array.
  m_last_year_activity := '0';
  --RAISE NOTICE 'Activity array %.', m_last_year_activity;
  -- Create the last year activity
  FOR r IN
   SELECT /* Notes-datamartUsers */ t.date_id, qty
   FROM (
    SELECT /* Notes-datamartUsers */ e.date_id, COALESCE(u.qty, 0) qty
    FROM dwh.dimension_days e
    LEFT JOIN (
     SELECT /* Notes-datamartUsers */ d.dimension_day_id day_id, count(1) qty
     FROM dwh.facts f
      JOIN dwh.dimension_days d
      ON (f.action_dimension_id_date = d.dimension_day_id)
     WHERE f.action_dimension_id_user = m_dimension_user_id
     GROUP BY d.dimension_day_id
    ) u
    ON (e.dimension_day_id = u.day_id)
    ORDER BY e.date_id DESC
    LIMIT 371
   ) AS t
   ORDER BY t.date_id ASC
 LOOP
   m_last_year_activity := dwh.refresh_today_activities(m_last_year_activity,
     (dwh.get_score_user_activity(r.qty::INTEGER)));
  END LOOP;
  --RAISE NOTICE 'Activity array %.', m_last_year_activity;

  INSERT INTO dwh.datamartUsers (
   dimension_user_id,
   user_id,
   username,
   date_starting_creating_notes,
   date_starting_solving_notes,
   first_open_note_id,
   first_commented_note_id,
   first_closed_note_id,
   first_reopened_note_id,
   last_year_activity
  ) VALUES (
   m_dimension_user_id,
   m_user_id,
   m_username,
   m_date_starting_creating_notes,
   m_date_starting_solving_notes,
   m_first_open_note_id,
   m_first_commented_note_id,
   m_first_closed_note_id,
   m_first_reopened_note_id,
   m_last_year_activity
  ) ON CONFLICT DO NOTHING;
 END
$proc$;
COMMENT ON PROCEDURE dwh.insert_datamart_user IS
  'Inserts a user in the corresponding datamart';

/*
 * Updates the datamart for a specific year.
 */
CREATE OR REPLACE PROCEDURE dwh.update_datamart_user_activity_year (
  m_dimension_user_id INTEGER,
  m_year SMALLINT
)
LANGUAGE plpgsql
AS $proc$
 DECLARE
  m_history_year_open INTEGER;
  m_history_year_commented INTEGER;
  m_history_year_closed INTEGER;
  m_history_year_closed_with_comment INTEGER;
  m_history_year_reopened INTEGER;
  m_ranking_countries_opening_year JSON;
  m_ranking_countries_closing_year JSON;
  m_current_year SMALLINT;
  m_check_year_populated INTEGER;
  stmt TEXT;
 BEGIN
  SELECT /* Notes-datamartUsers */ EXTRACT(YEAR FROM CURRENT_DATE)
   INTO m_current_year;

  stmt := 'SELECT /* Notes-datamartUsers */ history_' || m_year || '_open '
   || 'FROM dwh.datamartUsers '
   || 'WHERE dimension_user_id = ' || m_dimension_user_id;
  INSERT INTO logs (message) VALUES (stmt);
  EXECUTE stmt
   INTO m_check_year_populated;

  IF (m_check_year_populated IS NULL
   OR m_check_year_populated = m_current_year) THEN

   -- history_year_open
   SELECT /* Notes-datamartUsers */ COUNT(1)
    INTO m_history_year_open
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON (f.action_dimension_id_date = d.dimension_day_id)
   WHERE f.action_dimension_id_user = m_dimension_user_id
    AND f.action_comment = 'opened'
    AND d.year = m_year;

   -- history_year_commented
   SELECT /* Notes-datamartUsers */ COUNT(1)
    INTO m_history_year_commented
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON (f.action_dimension_id_date = d.dimension_day_id)
   WHERE f.action_dimension_id_user = m_dimension_user_id
    AND f.action_comment = 'commented'
    AND d.year = m_year;

   -- history_year_closed
   SELECT /* Notes-datamartUsers */ COUNT(1)
    INTO m_history_year_closed
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON (f.action_dimension_id_date = d.dimension_day_id)
   WHERE f.action_dimension_id_user = m_dimension_user_id
    AND f.action_comment = 'closed'
    AND d.year = m_year;

   -- history_year_closed_with_comment
   -- TODO datamart - comment's text
   m_history_year_closed_with_comment := 0;

   -- history_year_reopened
   SELECT /* Notes-datamartUsers */ COUNT(1)
    INTO m_history_year_reopened
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON (f.action_dimension_id_date = d.dimension_day_id)
   WHERE f.action_dimension_id_user = m_dimension_user_id
    AND f.action_comment = 'reopened'
    AND d.year = m_year;

   -- m_ranking_countries_opening_year
   SELECT /* Notes-datamartUsers */
    JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'country_name', country_name,
    'quantity', quantity))
    INTO m_ranking_countries_opening_year
   FROM (
    SELECT /* Notes-datamartUsers */
     RANK () OVER (ORDER BY quantity DESC) rank, country_name, quantity
	  FROM (
     SELECT /* Notes-datamartUsers */ c.country_name_es AS country_name,
      COUNT(1) AS quantity
     FROM dwh.facts f
      JOIN dwh.dimension_countries c
      ON f.dimension_id_country = c.dimension_country_id
      JOIN dwh.dimension_days d
      ON f.opened_dimension_id_date = d.dimension_day_id
     WHERE f.opened_dimension_id_user = m_dimension_user_id
      AND d.year = m_year
     GROUP BY c.country_name_es
     ORDER BY COUNT(1) DESC
     LIMIT 50
    ) AS T
   ) AS S;

   -- m_ranking_countries_closing_year
   SELECT /* Notes-datamartUsers */
    JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'country_name', country_name,
    'quantity', quantity))
    INTO m_ranking_countries_closing_year
   FROM (
    SELECT /* Notes-datamartUsers */
     RANK () OVER (ORDER BY quantity DESC) rank, country_name, quantity
    FROM (
     SELECT /* Notes-datamartUsers */ c.country_name_es AS country_name,
      COUNT(1) AS quantity
     FROM dwh.facts f
      JOIN dwh.dimension_countries c
      ON f.dimension_id_country = c.dimension_country_id
      JOIN dwh.dimension_days d
      ON f.closed_dimension_id_date = d.dimension_day_id
     WHERE f.closed_dimension_id_user = m_dimension_user_id
      AND d.year = m_year
     GROUP BY c.country_name_es
     ORDER BY COUNT(1) DESC
     LIMIT 50
    ) AS T
   ) AS S;

   stmt := 'UPDATE dwh.datamartUsers SET '
     || 'history_' || m_year || '_open = ' || m_history_year_open || ', '
     || 'history_' || m_year || '_commented = '
     || m_history_year_commented || ', '
     || 'history_' || m_year || '_closed = ' || m_history_year_closed || ', '
     || 'history_' || m_year || '_closed_with_comment = '
     || m_history_year_closed_with_comment || ', '
     || 'history_' || m_year || '_reopened = '
     || m_history_year_reopened || ', '
     || 'ranking_countries_opening_' || m_year || ' = '
     || QUOTE_NULLABLE(m_ranking_countries_opening_year) || ', '
     || 'ranking_countries_closing_' || m_year || ' = '
     || QUOTE_NULLABLE(m_ranking_countries_closing_year) || ' '
     || 'WHERE dimension_user_id = ' || m_dimension_user_id;
   INSERT INTO logs (message) VALUES (SUBSTR(stmt, 1, 900));
   EXECUTE stmt;
  END IF;
 END
$proc$;
COMMENT ON PROCEDURE dwh.update_datamart_user_activity_year IS
  'Processes the user''s activity per given year';

/**
 * Returns the type of type of contributor.
 */
 CREATE OR REPLACE FUNCTION dwh.get_contributor_type (
   m_dimension_user_id INTEGER
 ) RETURNS SMALLINT AS
 $$
 DECLARE
  m_cointributor_id SMALLINT;
  m_oldest_action DATE;
  m_oldest_action_year SMALLINT;
  m_current_year SMALLINT;
  m_recent_action DATE;
  m_total_actions INTEGER;
  m_total_opened INTEGER;
  m_total_closed INTEGER;
  coeficient DECIMAL;
 BEGIN
  SELECT /* Notes-datamartUsers */ MIN(d.date_id), MAX(d.date_id)
   INTO m_oldest_action, m_recent_action
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id;

  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_total_actions
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = m_dimension_user_id;

  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_total_closed
  FROM dwh.facts f
  WHERE f.closed_dimension_id_user = m_dimension_user_id;

  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_total_opened
  FROM dwh.facts f
  WHERE f.opened_dimension_id_user = m_dimension_user_id;

  coeficient := m_total_closed / (m_total_opened + 1);

  m_oldest_action_year := EXTRACT(YEAR FROM m_oldest_action);
  m_current_year := EXTRACT(YEAR FROM CURRENT_DATE);
  m_cointributor_id := 0;
  IF (m_oldest_action > CURRENT_DATE - 30) THEN
   m_cointributor_id := 2; -- Just starting notero
  ELSIF (m_oldest_action > CURRENT_DATE - 90) THEN
   m_cointributor_id := 3; -- Newbie notero.
  ELSIF (m_oldest_action_year = 2013
    AND m_oldest_action_year = m_current_year) THEN
   m_cointributor_id := 4; -- All-time notero.
   -- It has contributed since the first year, and the current year.
   -- The assumption is that is has contributed all years in between.
  ELSIF (m_oldest_action = m_recent_action) THEN
   m_cointributor_id := 5; -- Hit and run.
   -- It contibuted only one day older than 90 days.
  ELSIF (m_oldest_action_year = m_current_year
    OR m_oldest_action_year = m_current_year - 1) THEN
   m_cointributor_id := 6; -- Junior notero.
   -- It has been contributed in the last 2 calendar years.
  ELSIF (m_recent_action < CURRENT_DATE - 720) THEN
   m_cointributor_id := 7; -- Inactive notero.
   -- It has not contributed in the last 2 years.
  ELSIF (m_recent_action < CURRENT_DATE - 1800) THEN
   m_cointributor_id := 8; -- Retired notero.
   -- It has not contributed in the last 5 years.
  ELSIF (m_recent_action < CURRENT_DATE - 2000) THEN
   m_cointributor_id := 9; -- Forgotten notero.
   -- It has not contributed in the last 7 years.
  ELSIF (m_total_actions < 25) THEN
   m_cointributor_id := 10; -- Exporadic notero.
   -- Less than 100 contributions, in more than 2 years.
  ELSIF (m_total_closed < 100 AND coeficient > 1) THEN
   m_cointributor_id := 11; -- Start closing notero.
   -- Less than 100 closed, in more than 2 years.
  ELSIF (m_total_actions < 100) THEN
   m_cointributor_id := 12; -- Casual notero.
   -- Less than 100 contributions, in more than 2 years.
  ELSIF (m_total_closed < 400 AND coeficient > 1) THEN
   m_cointributor_id := 13; -- Heavy closing notero.
   -- Less than 400 contributions, in more than 2 years.
  ELSIF (m_total_actions < 400) THEN
   m_cointributor_id := 14; -- Heavy notero.
   -- Less than 400 contributions, in more than 2 years.
  ELSIF (m_total_closed < 1600 AND coeficient > 1) THEN
   m_cointributor_id := 15; -- Crazy closing notero.
   -- Less than 1600 contributions, in more than 2 years.
  ELSIF (m_total_actions < 1600) THEN
   m_cointributor_id := 16; -- Crazy notero.
   -- Less than 1600 contributions, in more than 2 years.
  ELSIF (m_total_closed < 6400 AND coeficient > 1) THEN
   m_cointributor_id := 17; -- Addicted closing notero.
   -- Less than 6400 contributions, in more than 2 years.
  ELSIF (m_total_actions < 6400) THEN
   m_cointributor_id := 18; -- Addicted notero.
   -- Less than 6400 contributions, in more than 2 years.
  ELSIF (m_total_closed < 25600 AND coeficient > 1) THEN
   m_cointributor_id := 19; -- Epic closing notero.
   -- Less than 25600 contributions, in more than 2 years.
  ELSIF (m_total_actions < 25600) THEN
   m_cointributor_id := 20; -- Epic notero.
   -- Less than 25600 contributions, in more than 2 years.
  ELSIF (m_total_closed < 102400 AND coeficient > 1) THEN
   m_cointributor_id := 21; -- Bot closing notero.
   -- Less than 102400 contributions, in more than 2 years.
  ELSIF (m_total_actions < 102400) THEN
   m_cointributor_id := 22; -- Robot notero.
   -- Less than 102400 contributions, in more than 2 years.
  ELSIF (m_total_actions >= 102400) THEN
   m_cointributor_id := 23; -- OoM exception notero.
   -- More than 102400 contributions, in more than 2 years.
   -- Out of memory execption notero.
  ELSE
   m_cointributor_id := 1; -- Normal noter.
   -- It should never return this.
   RAISE NOTICE 'Unkown contributor type %.', m_dimension_user_id;
  END IF;
  RETURN m_cointributor_id;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION dwh.get_contributor_type IS
  'Returns the type of contributor';

/**
 * Updates a datamart user.
 */
CREATE OR REPLACE PROCEDURE dwh.update_datamart_user (
  m_dimension_user_id INTEGER
)
LANGUAGE plpgsql
AS $proc$
 DECLARE
  qty SMALLINT;
  m_start_time TIMESTAMP;
  m_end_time TIMESTAMP;
  m_id_contributor_type SMALLINT;
  m_todays_activity INTEGER;
  m_last_year_activity CHAR(371);
  m_lastest_open_note_id INTEGER;
  m_lastest_commented_note_id INTEGER;
  m_lastest_closed_note_id INTEGER;
  m_lastest_reopened_note_id INTEGER;
  m_dates_most_open JSON;
  m_dates_most_closed JSON;
  m_hashtags JSON;
  m_countries_open_notes JSON;
  m_countries_solving_notes JSON;
  m_countries_open_notes_current_month JSON;
  m_countries_solving_notes_current_month JSON;
  m_countries_open_notes_current_day JSON;
  m_countries_solving_notes_current_day JSON;
  m_working_hours_of_week_opening JSON;
  m_working_hours_of_week_commenting JSON;
  m_working_hours_of_week_closing JSON;
  m_history_whole_open INTEGER; -- Qty opened notes.
  m_history_whole_commented INTEGER; -- Qty commented notes.
  m_history_whole_closed INTEGER; -- Qty closed notes.
  m_history_whole_closed_with_comment INTEGER; -- Qty closed notes with comments.
  m_history_whole_reopened INTEGER; -- Qty reopened notes.
  m_history_year_open INTEGER; -- Qty in the current year.
  m_history_year_commented INTEGER;
  m_history_year_closed INTEGER;
  m_history_year_closed_with_comment INTEGER;
  m_history_year_reopened INTEGER;
  m_history_month_open INTEGER; -- Qty in the current month.
  m_history_month_commented INTEGER;
  m_history_month_closed INTEGER;
  m_history_month_closed_with_comment INTEGER;
  m_history_month_reopened INTEGER;
  m_history_day_open INTEGER; -- Qty in the current day.
  m_history_day_commented INTEGER;
  m_history_day_closed INTEGER;
  m_history_day_closed_with_comment INTEGER;
  m_history_day_reopened INTEGER;

  m_year SMALLINT;
  m_current_year SMALLINT;
  m_current_month SMALLINT;
  m_current_day SMALLINT;
 BEGIN
  --m_start_time := CLOCK_TIMESTAMP();
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO qty
  FROM dwh.datamartUsers
  WHERE dimension_user_id = m_dimension_user_id;
  -- Checks if the user is already in the datamart.
  IF (qty = 0) THEN
   --RAISE NOTICE 'Inserting user in the datamart - %.', CLOCK_TIMESTAMP();
   CALL dwh.insert_datamart_user(m_dimension_user_id);
  END IF;

  -- id_contributor_type
  m_id_contributor_type := dwh.get_contributor_type(m_dimension_user_id);

  -- last_year_activity
  SELECT /* Notes-datamartUsers */ last_year_activity
   INTO m_last_year_activity
  FROM dwh.datamartUsers u
  WHERE u.dimension_user_id = m_dimension_user_id;

  -- Retrieves the curent activity array from the user, and updates with the
  -- current day's activities.
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_todays_activity
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
  AND d.date_id = CURRENT_DATE;
  m_last_year_activity := dwh.refresh_today_activities(m_last_year_activity,
    dwh.get_score_user_activity(m_todays_activity));
  --RAISE NOTICE 'Activity array %.', m_last_year_activity;

  -- lastest_open_note_id
  SELECT /* Notes-datamartUsers */ MAX(id_note)
  FROM dwh.facts f
   INTO m_lastest_open_note_id
  WHERE f.opened_dimension_id_user = m_dimension_user_id;

  -- lastest_commented_note_id
  SELECT /* Notes-datamartUsers */ MAX(id_note)
   INTO m_lastest_commented_note_id
  FROM dwh.facts f
   WHERE f.action_dimension_id_user = m_dimension_user_id
    AND f.action_comment = 'commented';

  -- lastest_closed_note_id
  SELECT /* Notes-datamartUsers */ MAX(id_note)
   INTO m_lastest_closed_note_id
  FROM dwh.facts f
  WHERE f.closed_dimension_id_user = m_dimension_user_id;

  -- lastest_reopened_note_id
  SELECT /* Notes-datamartUsers */ MAX(id_note)
   INTO m_lastest_reopened_note_id
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'reopened';

  -- dates_most_open
  SELECT /* Notes-datamartUsers */
   JSON_AGG(JSON_BUILD_OBJECT('date', date, 'quantity', quantity))
   INTO m_dates_most_open
  FROM (
   SELECT /* Notes-datamartUsers */ date_id AS date, COUNT(1) AS quantity
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON (f.opened_dimension_id_date = d.dimension_day_id)
   WHERE f.opened_dimension_id_user = m_dimension_user_id
   GROUP BY date_id
   ORDER BY COUNT(1) DESC
   LIMIT 50
  ) AS T;

  -- dates_most_closed
  SELECT /* Notes-datamartUsers */
   JSON_AGG(JSON_BUILD_OBJECT('date', date, 'quantity', quantity))
   INTO m_dates_most_closed
  FROM (
   SELECT /* Notes-datamartUsers */ date_id AS date, COUNT(1) AS quantity
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON (f.closed_dimension_id_date = d.dimension_day_id)
   WHERE f.closed_dimension_id_user = m_dimension_user_id
   GROUP BY date_id
   ORDER BY COUNT(1) DESC
   LIMIT 50
  ) AS T;

  -- hashtags
  -- TODO datamart - comment's text
  m_hashtags := NULL;

  -- countries_open_notes
  SELECT /* Notes-datamartUsers */
   JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'country', country_name,
   'quantity', quantity))
   INTO m_countries_open_notes
  FROM (
   SELECT /* Notes-datamartUsers */
    RANK () OVER (ORDER BY quantity DESC) rank, country_name, quantity
   FROM (
    SELECT /* Notes-datamartUsers */ c.country_name_es AS country_name,
     COUNT(1) AS quantity
    FROM dwh.facts f
     JOIN dwh.dimension_countries c
     ON f.dimension_id_country = c.dimension_country_id
    WHERE f.opened_dimension_id_user = m_dimension_user_id
    GROUP BY c.country_name_es
    ORDER BY COUNT(1) DESC
    LIMIT 50
   ) AS T
  ) AS S;

  -- countries_solving_notes
  SELECT /* Notes-datamartUsers */
   JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'country', country_name,
   'quantity', quantity))
   INTO m_countries_solving_notes
  FROM (
   SELECT /* Notes-datamartUsers */
    RANK () OVER (ORDER BY quantity DESC) rank, country_name, quantity
   FROM (
    SELECT /* Notes-datamartUsers */
     c.country_name_es AS country_name, COUNT(1) AS quantity
    FROM dwh.facts f
     JOIN dwh.dimension_countries c
     ON f.dimension_id_country = c.dimension_country_id
    WHERE f.closed_dimension_id_user = m_dimension_user_id
    GROUP BY c.country_name_es
    ORDER BY COUNT(1) DESC
    LIMIT 50
   ) AS T
  ) AS S;

  -- PEFR: high impact.
  -- 22 per second.
  SELECT /* Notes-datamartUsers */ EXTRACT(YEAR FROM CURRENT_DATE)
   INTO m_current_year;
  SELECT /* Notes-datamartUsers */ EXTRACT(MONTH FROM CURRENT_DATE)
   INTO m_current_month;
  SELECT /* Notes-datamartUsers */ EXTRACT(DAY FROM CURRENT_DATE)
   INTO m_current_day;

  -- 21 per second
--  SELECT /* Notes-datamartUsers */ DATE_PART('year', CURRENT_DATE)
--   INTO m_current_year;
--  SELECT /* Notes-datamartUsers */ DATE_PART('month', CURRENT_DATE)
--   INTO m_current_month;
--  SELECT /* Notes-datamartUsers */ DATE_PART('day', CURRENT_DATE)
--   INTO m_current_day;

  -- 21 per second
--  SELECT /* Notes-datamartUsers */ value
--   INTO m_current_year
--  FROM dwh.properties
--  WHERE key = 'year';
--  SELECT /* Notes-datamartUsers */ value
--   INTO m_current_month
--  FROM dwh.properties
--  WHERE key = 'month';
--  SELECT /* Notes-datamartUsers */ value
--   INTO m_current_day
--  FROM dwh.properties
--  WHERE key = 'day';

  -- countries_open_notes_current_month
  SELECT /* Notes-datamartUsers */
   JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'country', country_name,
   'quantity', quantity))
   INTO m_countries_open_notes_current_month
  FROM (
   SELECT /* Notes-datamartUsers */
    RANK () OVER (ORDER BY quantity DESC) rank, country_name, quantity
   FROM (
    SELECT /* Notes-datamartUsers */ c.country_name_es AS country_name,
     COUNT(1) AS quantity
    FROM dwh.facts f
     JOIN dwh.dimension_countries c
     ON f.dimension_id_country = c.dimension_country_id
     JOIN dwh.dimension_days d
     ON f.action_dimension_id_date = d.dimension_day_id
    WHERE f.opened_dimension_id_user = m_dimension_user_id
     AND d.month = m_current_month
     AND d.year = m_current_year
    GROUP BY c.country_name_es
    ORDER BY COUNT(1) DESC
    LIMIT 50
   ) AS T
  ) AS S;

  -- countries_solving_notes_current_month
  SELECT /* Notes-datamartUsers */
   JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'country', country_name,
   'quantity', quantity))
   INTO m_countries_solving_notes_current_month
  FROM (
   SELECT /* Notes-datamartUsers */
    RANK () OVER (ORDER BY quantity DESC) rank, country_name, quantity
   FROM (
    SELECT /* Notes-datamartUsers */ c.country_name_es AS country_name,
     COUNT(1) AS quantity
    FROM dwh.facts f
     JOIN dwh.dimension_countries c
     ON f.dimension_id_country = c.dimension_country_id
     JOIN dwh.dimension_days d
     ON f.action_dimension_id_date = d.dimension_day_id
    WHERE f.closed_dimension_id_user = m_dimension_user_id
     AND d.month = m_current_month
     AND d.year = m_current_year
    GROUP BY c.country_name_es
    ORDER BY COUNT(1) DESC
    LIMIT 50
   ) AS T
  ) AS S;

  -- countries_open_notes_current_day
  SELECT /* Notes-datamartUsers */
   JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'country', country_name,
   'quantity', quantity))
   INTO m_countries_open_notes_current_day
  FROM (
   SELECT /* Notes-datamartUsers */
    RANK () OVER (ORDER BY quantity DESC) rank, country_name, quantity
   FROM (
    SELECT /* Notes-datamartUsers */ c.country_name_es AS country_name,
     COUNT(1) AS quantity
    FROM dwh.facts f
     JOIN dwh.dimension_countries c
     ON f.dimension_id_country = c.dimension_country_id
     JOIN dwh.dimension_days d
     ON f.action_dimension_id_date = d.dimension_day_id
    WHERE f.opened_dimension_id_user = m_dimension_user_id
     AND d.day = m_current_day
     AND d.month = m_current_month
     AND d.year = m_current_year
    GROUP BY c.country_name_es
    ORDER BY COUNT(1) DESC
    LIMIT 50
   ) AS T
  ) AS S;

  -- countries_solving_notes_current_day
  SELECT /* Notes-datamartUsers */
   JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'country', country_name,
   'quantity', quantity))
   INTO m_countries_solving_notes_current_day
  FROM (
   SELECT /* Notes-datamartUsers */
    RANK () OVER (ORDER BY quantity DESC) rank, country_name, quantity
   FROM (
    SELECT /* Notes-datamartUsers */ c.country_name_es AS country_name,
     COUNT(1) AS quantity
    FROM dwh.facts f
     JOIN dwh.dimension_countries c
     ON f.dimension_id_country = c.dimension_country_id
     JOIN dwh.dimension_days d
     ON f.action_dimension_id_date = d.dimension_day_id
    WHERE f.closed_dimension_id_user = m_dimension_user_id
     AND d.day = m_current_day
     AND d.month = m_current_month
     AND d.year = m_current_year
    GROUP BY c.country_name_es
    ORDER BY COUNT(1) DESC
    LIMIT 50
   ) AS T
  ) AS S;

  -- working_hours_of_week_opening
  WITH hours AS (
   SELECT /* Notes-datamartUsers */ day_of_week, hour_of_day, COUNT(1)
   FROM dwh.facts f
    JOIN dwh.dimension_time_of_week t
    ON f.opened_dimension_id_hour_of_week = t.dimension_how_id
   WHERE f.opened_dimension_id_user = m_dimension_user_id
   GROUP BY day_of_week, hour_of_day
   ORDER BY day_of_week, hour_of_day
  )
  SELECT /* Notes-datamartUsers */ JSON_AGG(hours.*)
   INTO m_working_hours_of_week_opening
  FROM hours;

  -- working_hours_of_week_commenting
  WITH hours AS (
   SELECT /* Notes-datamartUsers */ day_of_week, hour_of_day, COUNT(1)
   FROM dwh.facts f
    JOIN dwh.dimension_time_of_week t
    ON f.action_dimension_id_hour_of_week = t.dimension_how_id
   WHERE f.action_dimension_id_user = m_dimension_user_id
    AND f.action_comment = 'commented'
   GROUP BY day_of_week, hour_of_day
   ORDER BY day_of_week, hour_of_day
  )
  SELECT /* Notes-datamartUsers */ JSON_AGG(hours.*)
   INTO m_working_hours_of_week_commenting
  FROM hours;

  -- working_hours_of_week_closing
  WITH hours AS (
   SELECT /* Notes-datamartUsers */ day_of_week, hour_of_day, COUNT(1)
   FROM dwh.facts f
    JOIN dwh.dimension_time_of_week t
    ON f.closed_dimension_id_hour_of_week = t.dimension_how_id
   WHERE f.closed_dimension_id_user = m_dimension_user_id
   GROUP BY day_of_week, hour_of_day
   ORDER BY day_of_week, hour_of_day
  )
  SELECT /* Notes-datamartUsers */ JSON_AGG(hours.*)
   INTO m_working_hours_of_week_closing
  FROM hours;

  -- history_whole_open
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_whole_open
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'opened';

  -- history_whole_commented
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_whole_commented
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'commented';

  -- history_whole_closed
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_whole_closed
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'closed';

  -- history_whole_closed_with_comment
  -- TODO datamart - comment's text
  m_history_whole_closed_with_comment := 0;

  -- history_whole_reopened
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_whole_reopened
  FROM dwh.facts f
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'reopened';

  -- history_year_open
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_year_open
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'opened'
   AND d.year = m_current_year;

  -- history_year_commented
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_year_commented
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'commented'
   AND d.year = m_current_year;

  -- history_year_closed
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_year_closed
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'closed'
   AND d.year = m_current_year;

  -- history_year_closed_with_comment
  -- TODO datamart - comment's text
  m_history_year_closed_with_comment := 0;

  -- history_year_reopened
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_year_reopened
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'reopened'
   AND d.year = m_current_year;

  -- history_month_open
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_month_open
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'opened'
   AND d.month = m_current_month
   AND d.year = m_current_year;

  -- history_month_commented
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_month_commented
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'commented'
   AND d.month = m_current_month
   AND d.year = m_current_year;

  -- history_month_closed
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_month_closed
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'closed'
   AND d.month = m_current_month
   AND d.year = m_current_year;

  -- history_month_closed_with_comment
  -- TODO datamart - comment's text
  m_history_month_closed_with_comment := 0;

  -- history_month_reopened
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_month_reopened
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'reopened'
   AND d.month = m_current_month
   AND d.year = m_current_year;

  -- history_day_open
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_day_open
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'opened'
   AND d.day = m_current_day
   AND d.month = m_current_month
   AND d.year = m_current_year;

  -- history_day_commented
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_day_commented
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'commented'
   AND d.day = m_current_day
   AND d.month = m_current_month
   AND d.year = m_current_year;

  -- history_day_closed
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_day_closed
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'closed'
   AND d.day = m_current_day
   AND d.month = m_current_month
   AND d.year = m_current_year;

  -- history_day_closed_with_comment
  -- TODO datamart - comment's text
  m_history_day_closed_with_comment := 0;

  -- history_day_reopened
  SELECT /* Notes-datamartUsers */ COUNT(1)
   INTO m_history_day_reopened
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.action_dimension_id_user = m_dimension_user_id
   AND f.action_comment = 'reopened'
   AND d.day = m_current_day
   AND d.month = m_current_month
   AND d.year = m_current_year;

  -- Updates user with new values.
  UPDATE dwh.datamartUsers
  SET id_contributor_type = m_id_contributor_type,
   last_year_activity = m_last_year_activity,
   lastest_open_note_id = m_lastest_open_note_id,
   lastest_commented_note_id = m_lastest_commented_note_id,
   lastest_closed_note_id = m_lastest_closed_note_id,
   lastest_reopened_note_id = m_lastest_reopened_note_id,
   dates_most_open = m_dates_most_open,
   dates_most_closed = m_dates_most_closed,
   hashtags = m_hashtags,
   countries_open_notes = m_countries_open_notes,
   countries_solving_notes = m_countries_solving_notes,
   countries_open_notes_current_month = m_countries_open_notes_current_month,
   countries_solving_notes_current_month = m_countries_solving_notes_current_month,
   countries_open_notes_current_day = m_countries_open_notes_current_day,
   countries_solving_notes_current_day = m_countries_solving_notes_current_day,
   working_hours_of_week_opening = m_working_hours_of_week_opening,
   working_hours_of_week_commenting = m_working_hours_of_week_commenting,
   working_hours_of_week_closing = m_working_hours_of_week_closing,
   history_whole_open = m_history_whole_open,
   history_whole_commented = m_history_whole_commented,
   history_whole_closed = m_history_whole_closed,
   history_whole_reopened = m_history_whole_reopened,
   history_year_open = m_history_year_open,
   history_year_commented = m_history_year_commented,
   history_year_closed = m_history_year_closed,
   history_year_closed_with_comment = m_history_year_closed_with_comment,
   history_year_reopened = m_history_year_reopened,
   history_month_open = m_history_month_open,
   history_month_commented = m_history_month_commented,
   history_month_closed = m_history_month_closed,
   history_month_closed_with_comment = m_history_month_closed_with_comment,
   history_month_reopened = m_history_month_reopened,
   history_day_open = m_history_day_open,
   history_day_commented = m_history_day_commented,
   history_day_closed = m_history_day_closed,
   history_day_closed_with_comment = m_history_day_closed_with_comment,
   history_day_reopened =m_history_day_reopened
  WHERE dimension_user_id = m_dimension_user_id;

  m_year := 2013;
  WHILE (m_year <= m_current_year) LOOP
   CALL dwh.update_datamart_user_activity_year(m_dimension_user_id, m_year);
   m_year := m_year + 1;
 END LOOP;
 --m_end_time := CLOCK_TIMESTAMP();
 --RAISE NOTICE 'Duration  %.', m_end_time - m_start_time;
END
$proc$;
COMMENT ON PROCEDURE dwh.update_datamart_user IS
  'Processes modifed user';
