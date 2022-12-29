DO
$$
DECLARE
 r RECORD;
 m_username VARCHAR(256);
 m_date_starting_creating_notes DATE;
 m_date_starting_solving_notes DATE;
 m_countries_open_notes VARCHAR(256);
 m_countries_solving_notes VARCHAR(256);
 stmt VARCHAR(1024);
BEGIN
 FOR r IN
  SELECT user_id, username
  FROM dwh.dimension_users
 LOOP

  SELECT DATE(MIN(created_at))
   INTO m_date_starting_solving_notes
   FROM dwh.facts f
   WHERE f.created_id_user = r.user_id;
  
  SELECT DATE(MIN(closed_at))
   INTO m_date_starting_solving_notes
   FROM dwh.facts f
   WHERE f.closed_id_user = r.user_id;
  
  SELECT STRING_AGG(country_name_en, ',') INTO m_countries_open_notes
   FROM (
    SELECT country_name_en
    FROM dwh.facts f
     JOIN dwh.dimension_countries c
     ON f.id_country = c.country_id
    WHERE f.created_id_user = r.user_id
     AND f.action_comment = 'opened'
    GROUP BY country_name_en
   ) AS T;

  SELECT STRING_AGG(country_name_en, ',') INTO m_countries_solving_notes
   FROM (
    SELECT country_name_en
    FROM dwh.facts f
     JOIN dwh.dimension_countries c
     ON f.id_country = c.country_id
    WHERE f.closed_id_user = r.user_id
     AND f.action_comment = 'closed'
    GROUP BY country_name_en
   ) AS T;

  stmt := 'INSERT INTO dwh.datamartUsers VALUES ('
    || r.user_id || ', '
    || QUOTE_NULLABLE('''' || m_username || '''') || ', '
    || COALESCE('''' || TO_CHAR(m_date_starting_creating_notes, 'yyyy-mm-dd') || '''', 'NULL') || ', '
    || COALESCE('''' || TO_CHAR(m_date_starting_solving_notes, 'yyyy-mm-dd') || '''', 'NULL') || ', '
    || COALESCE('''' || m_countries_open_notes || '''', 'NULL') || ', '
    || COALESCE('''' || m_countries_solving_notes || '''', 'NULL') || ' '
    || ')';
  INSERT INTO logs (message) VALUES (stmt);
  EXECUTE stmt;
 END LOOP;
END
$$;

