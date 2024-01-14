-- Populates datamart for users.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-08


DO /* Notes-datamartUsers-processOldUsers */
$$
DECLARE
 r RECORD;
 max_date DATE;
 m_count INTEGER;
BEGIN
 m_count := 1;
 RAISE NOTICE 'Started to process old users';
 FOR r IN
  -- Process the datamart only for modified users.
  SELECT /* Notes-datamartUsers */
   f.action_dimension_id_user AS dimension_user_id
  FROM dwh.facts f 
   JOIN dwh.dimension_users u
   ON (f.action_dimension_id_user = u.dimension_user_id)
  WHERE f.action_dimension_id_user IS NOT NULL
   AND u.modified = TRUE
  GROUP BY f.action_dimension_id_user
  HAVING COUNT(1) <= 20
  ORDER BY COUNT(1) DESC
 LOOP
  CALL dwh.update_datamart_user(r.dimension_user_id);

  UPDATE dwh.dimension_users
   SET modified = FALSE
   WHERE dimension_user_id = r.dimension_user_id;

  IF (MOD(m_count, 500) = 0) THEN
   RAISE NOTICE '% processed users', m_count;
  END IF;

  m_count := m_count + 1;
 END LOOP;
 -- TODO Aquí se debería volver a ejecutar en paralelo para los más viejos usuarios sin modificar.
END
$$;
