-- Populates datamart for users.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-13

DO
$$
DECLARE
 r RECORD;

BEGIN
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
  CALL dwh.update_datamart_user(r.dimension_user_id);

  UPDATE dwh.dimension_users
   SET modified = FALSE
   WHERE dimension_user_id = r.dimension_user_id;

  COMMIT;
 END LOOP;
END
$$;
