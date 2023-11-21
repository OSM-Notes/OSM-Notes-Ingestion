-- Populates datamart for users.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-13

DO
$$
DECLARE
 r RECORD;
 max_date DATE;
BEGIN
 SELECT date
  INTO max_date
 FROM dwh.max_date_users_processed;
 IF (max_date < CURRENT_DATE) THEN
  RAISE NOTICE 'Moving activites';
  -- Updates all users, moving a day.
  UPDATE dwh.datamartUsers
   SET last_year_activity = move_day(last_year_activity);
  UPDATE dwh.max_date_users_processed
   SET date = CURRENT_DATE;
 END IF;

 FOR r IN
  -- Process the datamart only for modified users.
  SELECT f.action_dimension_id_user AS dimension_user_id
  FROM dwh.facts f
   JOIN dwh.dimension_users u
   ON (f.action_dimension_id_user = u.dimension_user_id)
  WHERE u.modified = TRUE
  GROUP BY f.action_dimension_id_user
  ORDER BY MAX(f.action_at) DESC
  LIMIT 500
 LOOP
  RAISE NOTICE 'Processing user %', r.dimension_user_id;
  CALL dwh.update_datamart_user(r.dimension_user_id);

  UPDATE dwh.dimension_users
   SET modified = FALSE
   WHERE dimension_user_id = r.dimension_user_id;

  COMMIT;
 END LOOP;
END
$$;
