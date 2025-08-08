-- Procedure to insert datamart country.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-20

/**
 * Inserts a contry in the datamart, with the values that do not change.
 */
CREATE OR REPLACE PROCEDURE dwh.insert_datamart_country (
  m_dimension_country_id INTEGER
)
LANGUAGE plpgsql
AS $proc$
 DECLARE
  m_country_id INTEGER;
  m_country_name VARCHAR(100);
  m_country_name_es VARCHAR(100);
  m_country_name_en VARCHAR(100);
  m_date_starting_creating_notes DATE;
  m_date_starting_solving_notes DATE;
  m_first_open_note_id INTEGER;
  m_first_commented_note_id INTEGER;
  m_first_closed_note_id INTEGER;
  m_first_reopened_note_id INTEGER;
  m_last_year_activity CHAR(371);
  r RECORD;
 BEGIN
  SELECT /* Notes-datamartCountries */ country_id, country_name,
   country_name_es, country_name_en
   INTO m_country_id, m_country_name, m_country_name_es, m_country_name_en
  FROM dwh.dimension_countries
  WHERE dimension_country_id = m_dimension_country_id;

  -- date_starting_creating_notes
  SELECT /* Notes-datamartCountries */ date_id
   INTO m_date_starting_creating_notes
  FROM dwh.dimension_days
  WHERE dimension_day_id = (
   SELECT /* Notes-datamartCountries */ MIN(opened_dimension_id_date)
   FROM dwh.facts f
   WHERE f.dimension_id_country = m_dimension_country_id
  );

  -- date_starting_solving_notes
  SELECT /* Notes-datamartCountries */ date_id
   INTO m_date_starting_solving_notes
  FROM dwh.dimension_days
  WHERE dimension_day_id = (
   SELECT /* Notes-datamartCountries */ MIN(closed_dimension_id_date)
   FROM dwh.facts f
   WHERE f.dimension_id_country = m_dimension_country_id
  );

  -- first_open_note_id
  SELECT /* Notes-datamartCountries */ id_note
   INTO m_first_open_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT /* Notes-datamartCountries */ MIN(fact_id)
   FROM dwh.facts f
   WHERE f.dimension_id_country = m_dimension_country_id
    AND f.action_comment = 'opened'
  );

  -- first_commented_note_id
  SELECT /* Notes-datamartCountries */ id_note
   INTO m_first_commented_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT /* Notes-datamartCountries */ MIN(fact_id)
   FROM dwh.facts f
   WHERE f.dimension_id_country = m_dimension_country_id
    AND f.action_comment = 'commented'
  );

  -- first_closed_note_id
  SELECT /* Notes-datamartCountries */ id_note
   INTO m_first_closed_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT /* Notes-datamartCountries */ MIN(fact_id)
   FROM dwh.facts f
   WHERE f.dimension_id_country = m_dimension_country_id
    AND f.action_comment = 'closed'
  );

  -- first_reopened_note_id
  SELECT /* Notes-datamartCountries */ id_note
   INTO m_first_reopened_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT /* Notes-datamartCountries */ MIN(fact_id)
   FROM dwh.facts f
   WHERE f.dimension_id_country = m_dimension_country_id
    AND f.action_comment = 'reopened'
  );

  m_last_year_activity := '0';
  -- Create the last year activity
  FOR r IN
   SELECT /* Notes-datamartCountries */ t.date_id, qty
   FROM (
    SELECT /* Notes-datamartCountries */ e.date_id AS date_id,
     COALESCE(c.qty, 0) AS qty
    FROM dwh.dimension_days e
    LEFT JOIN (
    SELECT /* Notes-datamartCountries */ d.dimension_day_id day_id, count(1) qty
     FROM dwh.facts f
      JOIN dwh.dimension_days d
      ON (f.action_dimension_id_date = d.dimension_day_id)
     WHERE f.dimension_id_country = m_dimension_country_id
     GROUP BY d.dimension_day_id
    ) c
    ON (e.dimension_day_id = c.day_id)
    ORDER BY e.date_id DESC
    LIMIT 371
   ) AS t
   ORDER BY t.date_id ASC
  LOOP
   m_last_year_activity := dwh.refresh_today_activities(m_last_year_activity,
     (dwh.get_score_user_activity(r.qty::INTEGER)));
  END LOOP;

  INSERT INTO dwh.datamartCountries (
   dimension_country_id,
   country_id,
   country_name,
   country_name_es,
   country_name_en,
   date_starting_creating_notes,
   date_starting_solving_notes,
   first_open_note_id,
   first_commented_note_id,
   first_closed_note_id,
   first_reopened_note_id,
   last_year_activity
  ) VALUES (
   m_dimension_country_id,
   m_country_id,
   m_country_name,
   m_country_name_es,
   m_country_name_en,
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
COMMENT ON PROCEDURE dwh.insert_datamart_country IS
  'Inserts a country in the corresponding datamart';

CREATE OR REPLACE PROCEDURE dwh.update_datamart_country_activity_year (
  m_dimension_country_id INTEGER,
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
  m_ranking_users_opening_year JSON;
  m_ranking_users_closing_year JSON;
  m_current_year SMALLINT;
  m_check_year_populated INTEGER;
  stmt TEXT;
 BEGIN
  SELECT /* Notes-datamartCountries */ EXTRACT(YEAR FROM CURRENT_DATE)
   INTO m_current_year;

  stmt := 'SELECT /* Notes-datamartCountries */ history_' || m_year || '_open '
   || 'FROM dwh.datamartCountries '
   || 'WHERE dimension_country_id = ' || m_dimension_country_id;
  INSERT INTO logs (message) VALUES (stmt);
  EXECUTE stmt
   INTO m_check_year_populated;

  IF (m_check_year_populated IS NULL OR m_check_year_populated = m_current_year) THEN

   -- history_year_open
   SELECT /* Notes-datamartCountries */ COUNT(1)
    INTO m_history_year_open
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON (f.action_dimension_id_date = d.dimension_day_id)
   WHERE f.dimension_id_country = m_dimension_country_id
    AND f.action_comment = 'opened'
    AND EXTRACT(YEAR FROM d.date_id) = m_year;

   -- history_year_commented
   SELECT /* Notes-datamartCountries */ COUNT(1)
    INTO m_history_year_commented
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON (f.action_dimension_id_date = d.dimension_day_id)
   WHERE f.dimension_id_country = m_dimension_country_id
    AND f.action_comment = 'commented'
    AND EXTRACT(YEAR FROM d.date_id) = m_year;

   -- history_year_closed
   SELECT /* Notes-datamartCountries */ COUNT(1)
    INTO m_history_year_closed
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON (f.action_dimension_id_date = d.dimension_day_id)
   WHERE f.dimension_id_country = m_dimension_country_id
    AND f.action_comment = 'closed'
    AND EXTRACT(YEAR FROM d.date_id) = m_year;

   -- history_year_closed_with_comment
   -- TODO datamart - comment's text
   m_history_year_closed_with_comment := 0;

   -- history_year_reopened
   SELECT /* Notes-datamartCountries */ COUNT(1)
    INTO m_history_year_reopened
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON (f.action_dimension_id_date = d.dimension_day_id)
   WHERE f.dimension_id_country = m_dimension_country_id
    AND f.action_comment = 'reopened'
    AND EXTRACT(YEAR FROM d.date_id) = m_year;

   -- m_ranking_users_opening_year
   SELECT /* Notes-datamartCountries */
    JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'username', username,
    'quantity', quantity))
    INTO m_ranking_users_opening_year
   FROM (
    SELECT /* Notes-datamartCountries */
     RANK () OVER (ORDER BY quantity DESC) rank, username, quantity
	  FROM (
     SELECT /* Notes-datamartCountries */ u.username AS username,
      COUNT(1) AS quantity
     FROM dwh.facts f
      JOIN dwh.dimension_users u
      ON f.opened_dimension_id_user = u.dimension_user_id
      JOIN dwh.dimension_days d
      ON f.opened_dimension_id_date = d.dimension_day_id
     WHERE f.dimension_id_country = m_dimension_country_id
     AND EXTRACT(YEAR FROM d.date_id) = m_year
      GROUP BY u.username
     ORDER BY COUNT(1) DESC
     LIMIT 50
    ) AS T
   ) AS S;

   -- m_ranking_users_closing_year
   SELECT /* Notes-datamartCountries */
    JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'username', username,
    'quantity', quantity))
    INTO m_ranking_users_closing_year
   FROM (
    SELECT /* Notes-datamartCountries */
     RANK () OVER (ORDER BY quantity DESC) rank, username, quantity
    FROM (
     SELECT /* Notes-datamartCountries */ u.username AS username,
      COUNT(1) AS quantity
     FROM dwh.facts f
      JOIN dwh.dimension_users u
      ON f.closed_dimension_id_user = u.dimension_user_id
      JOIN dwh.dimension_days d
      ON f.closed_dimension_id_date = d.dimension_day_id
     WHERE f.dimension_id_country = m_dimension_country_id
      AND EXTRACT(YEAR FROM d.date_id) = m_year
     GROUP BY u.username
     ORDER BY COUNT(1) DESC
     LIMIT 50
    ) AS T
   ) AS S;

   stmt := 'UPDATE dwh.datamartCountries SET '
     || 'history_' || m_year || '_open = ' || m_history_year_open || ', '
     || 'history_' || m_year || '_commented = '
     || m_history_year_commented || ', '
     || 'history_' || m_year || '_closed = ' || m_history_year_closed || ', '
     || 'history_' || m_year || '_closed_with_comment = '
     || m_history_year_closed_with_comment || ', '
     || 'history_' || m_year || '_reopened = '
     || m_history_year_reopened || ', '
     || 'ranking_users_opening_' || m_year || ' = '
     || QUOTE_NULLABLE(m_ranking_users_opening_year) || ', '
     || 'ranking_users_closing_' || m_year || ' = '
     || QUOTE_NULLABLE(m_ranking_users_closing_year) || ' '
     || 'WHERE dimension_country_id = ' || m_dimension_country_id;
   INSERT INTO logs (message) VALUES (SUBSTR(stmt, 1, 900));
   EXECUTE stmt;
  END IF;
 END
$proc$;
COMMENT ON PROCEDURE dwh.update_datamart_country_activity_year IS
  'Processes the country''s activity per given year';

/**
 * Updates a datamart country.
 */
CREATE OR REPLACE PROCEDURE dwh.update_datamart_country (
  m_dimension_id_country INTEGER
)
LANGUAGE plpgsql
AS $proc$
 DECLARE
  qty SMALLINT;
  m_todays_activity INTEGER;
  m_last_year_activity CHAR(371);
  m_lastest_open_note_id INTEGER;
  m_lastest_commented_note_id INTEGER;
  m_lastest_closed_note_id INTEGER;
  m_lastest_reopened_note_id INTEGER;
  m_dates_most_open JSON;
  m_dates_most_closed JSON;
  m_hashtags JSON;
  m_users_open_notes JSON;
  m_users_solving_notes JSON;
  m_users_open_notes_current_month JSON;
  m_users_solving_notes_current_month JSON;
  m_users_open_notes_current_day JSON;
  m_users_solving_notes_current_day JSON;
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
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO qty
   FROM dwh.datamartCountries
   WHERE dimension_country_id = m_dimension_id_country;
  IF (qty = 0) THEN
   --RAISE NOTICE 'Inserting country.';
   CALL dwh.insert_datamart_country(m_dimension_id_country);
  END IF;

  -- last_year_activity
  SELECT /* Notes-datamartCountries */ last_year_activity
   INTO m_last_year_activity
  FROM dwh.datamartCountries c
  WHERE c.dimension_country_id = m_dimension_id_country;
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_todays_activity
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = dimension_id_country
  AND d.date_id = CURRENT_DATE;
  m_last_year_activity := dwh.refresh_today_activities(m_last_year_activity,
    dwh.get_score_country_activity(m_todays_activity));

  -- lastest_open_note_id
  SELECT /* Notes-datamartCountries */ id_note
   INTO m_lastest_open_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT /* Notes-datamartCountries */ MAX(fact_id)
   FROM dwh.facts f
   WHERE f.dimension_id_country = m_dimension_id_country
  );

  -- lastest_commented_note_id
  SELECT /* Notes-datamartCountries */ id_note
   INTO m_lastest_commented_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT /* Notes-datamartCountries */ MAX(fact_id)
   FROM dwh.facts f
   WHERE f.dimension_id_country = m_dimension_id_country
    AND f.action_comment = 'commented'
  );

  -- lastest_closed_note_id
  SELECT /* Notes-datamartCountries */ id_note
   INTO m_lastest_closed_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT /* Notes-datamartCountries */ MAX(fact_id)
   FROM dwh.facts f
   WHERE f.dimension_id_country = m_dimension_id_country
  );

  -- lastest_reopened_note_id
  SELECT /* Notes-datamartCountries */ id_note
   INTO m_lastest_reopened_note_id
  FROM dwh.facts
  WHERE fact_id = (
   SELECT /* Notes-datamartCountries */ MAX(fact_id)
   FROM dwh.facts f
   WHERE f.dimension_id_country = m_dimension_id_country
    AND f.action_comment = 'reopened'
  );

  -- dates_most_open
  SELECT /* Notes-datamartCountries */
   JSON_AGG(JSON_BUILD_OBJECT('date', date, 'quantity', quantity))
   INTO m_dates_most_open
  FROM (
   SELECT /* Notes-datamartCountries */ date_id AS date, COUNT(1) AS quantity
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON (f.opened_dimension_id_date = d.dimension_day_id)
   WHERE f.dimension_id_country = m_dimension_id_country
   GROUP BY date_id
   ORDER BY COUNT(1) DESC
   LIMIT 50
  ) AS T;

  -- dates_most_closed
  SELECT /* Notes-datamartCountries */
   JSON_AGG(JSON_BUILD_OBJECT('date', date, 'quantity', quantity))
   INTO m_dates_most_closed
  FROM (
   SELECT /* Notes-datamartCountries */ date_id AS date, COUNT(1) AS quantity
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON (f.closed_dimension_id_date = d.dimension_day_id)
   WHERE f.dimension_id_country = m_dimension_id_country
   GROUP BY date_id
   ORDER BY COUNT(1) DESC
   LIMIT 50
  ) AS T;

  -- hashtags
  -- TODO datamart - comment's text
  m_hashtags := NULL;

  -- users_open_notes
  SELECT /* Notes-datamartCountries */
   JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'username', username,
   'quantity', quantity))
   INTO m_users_open_notes
  FROM (
   SELECT /* Notes-datamartCountries */
    RANK () OVER (ORDER BY quantity DESC) rank, username, quantity
   FROM (
    SELECT /* Notes-datamartCountries */ u.username AS username,
     COUNT(1) AS quantity
    FROM dwh.facts f
     JOIN dwh.dimension_users u
     ON f.opened_dimension_id_user = u.dimension_user_id
    WHERE f.dimension_id_country = m_dimension_id_country
    GROUP BY u.username
    ORDER BY COUNT(1) DESC
    LIMIT 50
   ) AS T
  ) AS S;

  -- users_solving_notes
  SELECT /* Notes-datamartCountries */
   JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'username', username,
   'quantity', quantity))
   INTO m_users_solving_notes
  FROM (
   SELECT /* Notes-datamartCountries */
    RANK () OVER (ORDER BY quantity DESC) rank, username, quantity
   FROM (
    SELECT /* Notes-datamartCountries */ u.username AS username,
     COUNT(1) AS quantity
    FROM dwh.facts f
     JOIN dwh.dimension_users u
     ON F.closed_dimension_id_user = u.dimension_user_id
    WHERE f.dimension_id_country = m_dimension_id_country
    GROUP BY u.username
    ORDER BY COUNT(1) DESC
    LIMIT 50
   ) AS T
  ) AS S;

  SELECT /* Notes-datamartCountries */ EXTRACT(YEAR FROM CURRENT_TIMESTAMP)
   INTO m_current_year;

  SELECT /* Notes-datamartCountries */ EXTRACT(MONTH FROM CURRENT_TIMESTAMP)
   INTO m_current_month;

  SELECT /* Notes-datamartCountries */ EXTRACT(DAY FROM CURRENT_TIMESTAMP)
   INTO m_current_day;

  -- users_open_notes_current_month
  SELECT /* Notes-datamartCountries */
   JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'username', username,
   'quantity', quantity))
   INTO m_users_open_notes_current_month
  FROM (
   SELECT /* Notes-datamartCountries */
    RANK () OVER (ORDER BY quantity DESC) rank, username, quantity
   FROM (
    SELECT /* Notes-datamartCountries */ u.username AS username,
     COUNT(1) AS quantity
    FROM dwh.facts f
     JOIN dwh.dimension_users u
     ON f.opened_dimension_id_user = u.dimension_user_id
     JOIN dwh.dimension_days d
     ON f.opened_dimension_id_date = d.dimension_day_id
    WHERE f.dimension_id_country = m_dimension_id_country
     AND EXTRACT(MONTH FROM d.date_id) = m_current_month
     AND EXTRACT(YEAR FROM d.date_id) = m_current_year
    GROUP BY u.username
    ORDER BY COUNT(1) DESC
    LIMIT 50
   ) AS T
  ) AS S;

  -- users_solving_notes_current_month
  SELECT /* Notes-datamartCountries */
   JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'username', username,
   'quantity', quantity))
   INTO m_users_solving_notes_current_month
  FROM (
   SELECT /* Notes-datamartCountries */
    RANK () OVER (ORDER BY quantity DESC) rank, username, quantity
   FROM (
    SELECT /* Notes-datamartCountries */ u.username AS username,
     COUNT(1) AS quantity
    FROM dwh.facts f
     JOIN dwh.dimension_users u
     ON f.closed_dimension_id_user = u.dimension_user_id
     JOIN dwh.dimension_days d
     ON f.closed_dimension_id_date = d.dimension_day_id
    WHERE f.dimension_id_country = m_dimension_id_country
     AND EXTRACT(MONTH FROM d.date_id) = m_current_month
     AND EXTRACT(YEAR FROM d.date_id) = m_current_year
    GROUP BY u.username
    ORDER BY COUNT(1) DESC
    LIMIT 50
   ) AS T
  ) AS S;

  -- users_open_notes_current_day
  SELECT /* Notes-datamartCountries */
   JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'username', username,
   'quantity', quantity))
   INTO m_users_open_notes_current_day
  FROM (
   SELECT /* Notes-datamartCountries */
    RANK () OVER (ORDER BY quantity DESC) rank, username, quantity
   FROM (
    SELECT /* Notes-datamartCountries */ u.username AS username,
     COUNT(1) AS quantity
    FROM dwh.facts f
     JOIN dwh.dimension_users u
     ON f.opened_dimension_id_user = u.dimension_user_id
     JOIN dwh.dimension_days d
     ON f.opened_dimension_id_date = d.dimension_day_id
    WHERE f.dimension_id_country = m_dimension_id_country
     AND EXTRACT(DAY FROM d.date_id) = m_current_day
     AND EXTRACT(MONTH FROM d.date_id) = m_current_month
     AND EXTRACT(YEAR FROM d.date_id) = m_current_year
    GROUP BY u.username
    ORDER BY COUNT(1) DESC
    LIMIT 50
   ) AS T
  ) AS S;

  -- users_solving_notes_current_day
  SELECT /* Notes-datamartCountries */
   JSON_AGG(JSON_BUILD_OBJECT('rank', rank, 'username', username,
   'quantity', quantity))
   INTO m_users_solving_notes_current_day
  FROM (
   SELECT /* Notes-datamartCountries */
    RANK () OVER (ORDER BY quantity DESC) rank, username, quantity
   FROM (
    SELECT /* Notes-datamartCountries */ u.username AS username,
     COUNT(1) AS quantity
    FROM dwh.facts f
     JOIN dwh.dimension_users u
     ON f.closed_dimension_id_user = u.dimension_user_id
     JOIN dwh.dimension_days d
     ON f.closed_dimension_id_date = d.dimension_day_id
    WHERE f.dimension_id_country = m_dimension_id_country
     AND EXTRACT(DAY FROM d.date_id) = m_current_day
     AND EXTRACT(MONTH FROM d.date_id) = m_current_month
     AND EXTRACT(YEAR FROM d.date_id) = m_current_year
    GROUP BY u.username
    ORDER BY COUNT(1) DESC
    LIMIT 50
   ) AS T
  ) AS S;

  -- working_hours_of_week_opening
  WITH hours AS (
   SELECT /* Notes-datamartCountries */ day_of_week, hour_of_day, COUNT(1)
   FROM dwh.facts f
    JOIN dwh.dimension_time_of_week t
    ON f.opened_dimension_id_hour_of_week = t.dimension_how_id
   WHERE f.dimension_id_country = m_dimension_id_country
    AND f.action_comment = 'opened'
   GROUP BY day_of_week, hour_of_day
   ORDER BY day_of_week, hour_of_day
  )
  SELECT /* Notes-datamartCountries */ JSON_AGG(hours.*)
   INTO m_working_hours_of_week_opening
  FROM hours;

  -- working_hours_of_week_commenting
  WITH hours AS (
   SELECT /* Notes-datamartCountries */ day_of_week, hour_of_day, COUNT(1)
   FROM dwh.facts f
    JOIN dwh.dimension_time_of_week t
    ON f.action_dimension_id_hour_of_week = t.dimension_how_id
   WHERE f.dimension_id_country = m_dimension_id_country
    AND f.action_comment = 'commented'
   GROUP BY day_of_week, hour_of_day
   ORDER BY day_of_week, hour_of_day
  )
  SELECT /* Notes-datamartCountries */ JSON_AGG(hours.*)
   INTO m_working_hours_of_week_commenting
  FROM hours;

  -- working_hours_of_week_closing
  WITH hours AS (
   SELECT /* Notes-datamartCountries */ day_of_week, hour_of_day, COUNT(1)
   FROM dwh.facts f
    JOIN dwh.dimension_time_of_week t
    ON f.closed_dimension_id_hour_of_week = t.dimension_how_id
   WHERE f.dimension_id_country = m_dimension_id_country
   GROUP BY day_of_week, hour_of_day
   ORDER BY day_of_week, hour_of_day
  )
  SELECT /* Notes-datamartCountries */ JSON_AGG(hours.*)
   INTO m_working_hours_of_week_closing
  FROM hours;

  -- history_whole_open
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_whole_open
  FROM dwh.facts f
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'opened';

  -- history_whole_commented
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_whole_commented
  FROM dwh.facts f
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'commented';

  -- history_whole_closed TODO datamart - quitar cuando se cierra multiples veces
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_whole_closed
  FROM dwh.facts f
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'closed';

  -- history_whole_closed_with_comment
  -- TODO comment's text
  m_history_whole_closed_with_comment := 0;

  -- history_whole_reopened TODO datamart - quitar cuando se reabre multiples veces
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_whole_reopened
  FROM dwh.facts f
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'reopened';

  -- history_year_open
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_year_open
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'opened'
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_year_commented
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_year_commented
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'commented'
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_year_closed
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_year_closed
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'closed'
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_year_closed_with_comment
  -- TODO datamart - comment's text
  m_history_year_closed_with_comment := 0;

  -- history_year_reopened
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_year_reopened
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'reopened'
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_month_open
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_month_open
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'opened'
   AND EXTRACT(MONTH FROM d.date_id) = m_current_month
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_month_commented
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_month_commented
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'commented'
   AND EXTRACT(MONTH FROM d.date_id) = m_current_month
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_month_closed
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_month_closed
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'closed'
   AND EXTRACT(MONTH FROM d.date_id) = m_current_month
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_month_closed_with_comment
  -- TODO datamart - comment's text
  m_history_month_closed_with_comment := 0;

  -- history_month_reopened
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_month_reopened
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'reopened'
   AND EXTRACT(MONTH FROM d.date_id) = m_current_month
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_day_open
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_day_open
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'opened'
   AND EXTRACT(DAY FROM d.date_id) = m_current_day
   AND EXTRACT(MONTH FROM d.date_id) = m_current_month
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_day_commented
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_day_commented
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'commented'
   AND EXTRACT(DAY FROM d.date_id) = m_current_day
   AND EXTRACT(MONTH FROM d.date_id) = m_current_month
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_day_closed
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_day_closed
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'closed'
   AND EXTRACT(DAY FROM d.date_id) = m_current_day
   AND EXTRACT(MONTH FROM d.date_id) = m_current_month
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- history_day_closed_with_comment
  -- TODO datamart - comment's text
  m_history_day_closed_with_comment := 0;

  -- history_day_reopened
  SELECT /* Notes-datamartCountries */ COUNT(1)
   INTO m_history_day_reopened
  FROM dwh.facts f
   JOIN dwh.dimension_days d
   ON (f.action_dimension_id_date = d.dimension_day_id)
  WHERE f.dimension_id_country = m_dimension_id_country
   AND f.action_comment = 'reopened'
   AND EXTRACT(DAY FROM d.date_id) = m_current_day
   AND EXTRACT(MONTH FROM d.date_id) = m_current_month
   AND EXTRACT(YEAR FROM d.date_id) = m_current_year;

  -- Updates country with new values.
  UPDATE dwh.datamartCountries
  SET
   last_year_activity = m_last_year_activity,
   lastest_open_note_id = m_lastest_open_note_id,
   lastest_commented_note_id = m_lastest_commented_note_id,
   lastest_closed_note_id = m_lastest_closed_note_id,
   lastest_reopened_note_id = m_lastest_reopened_note_id,
   dates_most_open = m_dates_most_open,
   dates_most_closed = m_dates_most_closed,
   hashtags = m_hashtags,
   users_open_notes = m_users_open_notes,
   users_solving_notes = m_users_solving_notes,
   users_open_notes_current_month = m_users_open_notes_current_month,
   users_solving_notes_current_month = m_users_solving_notes_current_month,
   users_open_notes_current_day = m_users_open_notes_current_day,
   users_solving_notes_current_day = m_users_solving_notes_current_day,
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
  WHERE dimension_country_id = m_dimension_id_country;

  m_year := 2013;
  WHILE (m_year <= m_current_year) LOOP
   CALL dwh.update_datamart_country_activity_year(m_dimension_id_country, m_year);
   m_year := m_year + 1;
  END LOOP;
 END
$proc$;
COMMENT ON PROCEDURE dwh.update_datamart_country IS
  'Processes modifed countries';
