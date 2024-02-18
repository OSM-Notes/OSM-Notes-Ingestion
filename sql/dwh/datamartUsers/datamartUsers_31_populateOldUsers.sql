-- Populates datamart for users.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-17

DO /* Notes-datamartUsers-processOldUsers */
$$
DECLARE
 r RECORD;
 max_date DATE;
 m_count INTEGER;
BEGIN
 m_count := 1;
 RAISE NOTICE 'Started to process old users.';

 -- Inserts the part of the date to reduce calling the function Extract.
 DELETE FROM dwh.properties WHERE key IN ('year', 'month', 'day');
 INSERT INTO dwh.properties VALUES ('year', DATE_PART('year', CURRENT_DATE));
 INSERT INTO dwh.properties VALUES ('month', DATE_PART('month', CURRENT_DATE));
 INSERT INTO dwh.properties VALUES ('day', DATE_PART('day', CURRENT_DATE));

 FOR r IN
  SELECT /* Notes-datamartUsers */
   f.action_dimension_id_user AS dimension_user_id
  FROM dwh.facts f
   JOIN dwh.dimension_users u
   ON (f.action_dimension_id_user = u.dimension_user_id)
  WHERE ${LOWER_VALUE} <= u.user_id
   AND u.user_id < ${HIGH_VALUE}
  GROUP BY f.action_dimension_id_user
  HAVING COUNT(1) <= 20
  ORDER BY COUNT(1) DESC
 LOOP
  CALL dwh.update_datamart_user(r.dimension_user_id);

  UPDATE dwh.dimension_users
   SET modified = FALSE
   WHERE dimension_user_id = r.dimension_user_id;

  IF (MOD(m_count, 500) = 0) THEN
   RAISE NOTICE '% processed users.', m_count;
  END IF;

  m_count := m_count + 1;
 END LOOP;
END
$$;
