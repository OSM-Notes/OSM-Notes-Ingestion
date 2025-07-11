-- Populates datamart for users.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-17

DO /* Notes-datamartUsers-badges */
$$
DECLARE
 r RECORD;
 max_date DATE;
BEGIN
END
$$;

DO /* Notes-datamartUsers-processRecentUsers */
$$
DECLARE
 r RECORD;
 max_date DATE;
BEGIN
 SELECT /* Notes-datamartUsers */ date
  INTO max_date
 FROM dwh.max_date_users_processed;
 IF (max_date < CURRENT_DATE) THEN
  RAISE NOTICE 'Moving activites.';
  -- Updates all users, moving a day.
  UPDATE dwh.datamartUsers
   SET last_year_activity = dwh.move_day(last_year_activity);
  UPDATE dwh.max_date_users_processed
   SET date = CURRENT_DATE;
 END IF;

 -- Inserts the part of the date to reduce calling the function Extract.
 DELETE FROM dwh.properties WHERE key IN ('year', 'month', 'day');
 INSERT INTO dwh.properties VALUES ('year', DATE_PART('year', CURRENT_DATE));
 INSERT INTO dwh.properties VALUES ('month', DATE_PART('month', CURRENT_DATE));
 INSERT INTO dwh.properties VALUES ('day', DATE_PART('day', CURRENT_DATE));

 FOR r IN
  -- Process the datamart only for modified users.
  SELECT /* Notes-datamartUsers */
   f.action_dimension_id_user AS dimension_user_id
  FROM dwh.facts f
   JOIN dwh.dimension_users u
   ON (f.action_dimension_id_user = u.dimension_user_id)
  WHERE u.modified = TRUE
  GROUP BY f.action_dimension_id_user
  ORDER BY MAX(f.action_at) DESC -- TODO datamart - quitar?
  LIMIT 500
 LOOP
  RAISE NOTICE 'Processing user %.', r.dimension_user_id;
  CALL dwh.update_datamart_user(r.dimension_user_id);

  UPDATE dwh.dimension_users
   SET modified = FALSE
   WHERE dimension_user_id = r.dimension_user_id;

 END LOOP;
END
$$;
