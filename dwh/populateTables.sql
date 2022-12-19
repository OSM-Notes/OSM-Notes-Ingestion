SELECT CURRENT_TIMESTAMP AS Processing, 'Inserting dimension countries';

-- Populates the countries dimension with new countries.
INSERT INTO dwh.dimension_countries
 (country_id, country_name, country_name_es, country_name_en)
 SELECT country_id, country_name, country_name_es, country_name_en
 FROM countries
 WHERE country_id NOT IN (
  SELECT country_id
  FROM dwh.dimension_countries
 )
;

INSERT INTO dwh.dimension_countries 
 (country_id, country_name, country_name_es, country_name_en)
 VALUES
 (-1, 'Unkown - International waters',
  'Desconocido - Aguas internacionales', 'Unkown - International waters')
;
-- ToDo update countries with regions.

SELECT CURRENT_TIMESTAMP AS Processing, 'Inserting dimension users';

-- Inserts new users.
INSERT INTO dwh.dimension_users
 (user_id, username)
 SELECT DISTINCT c.user_id, c.username
 FROM note_comments c
 WHERE c.user_id IS NOT NULL
 AND c.user_id NOT IN (
  SELECT u.user_id
  FROM dwh.dimension_users u
  WHERE u.user_id IS NOT NULL
  GROUP BY u.user_id
  )
 ON CONFLICT DO NOTHING
;

SELECT CURRENT_TIMESTAMP AS Processing, 'Showing modified usernames';

-- Shows usernames renamed.
-- TODO Revisar si es necesario. Toma mucho tiempo la comparacion lexicografica.
SELECT DISTINCT d.username AS OldUsername, c.username AS NewUsername
 FROM note_comments c
  JOIN dwh.dimension_users d
  ON d.user_id = c.user_id
 WHERE c.username <> d.username
;

SELECT CURRENT_TIMESTAMP AS Processing, 'Updating modified usernames';

-- Updates the dimension when username is changed.
-- TODO Revisar si es necesario. Toma mucho tiempo la comparacion lexicografica.
UPDATE dwh.dimension_users AS d
 SET username = c.username
 FROM note_comments c
 WHERE c.username <> d.username
;

SELECT CURRENT_TIMESTAMP AS Processing, 'Inserting facts';

-- Inserts new facts.
-- TODO Cambiar de sample a definitivo
INSERT INTO dwh.facts (
 id_note,
 created_at,
 created_id_user,
 closed_at,
 closed_id_user,
 id_country,
 action_comment,
 action_id_user,
 action_at
 ) 
WITH opened (
  note_id,
  created_at,
  user_id
 ) AS (
  SELECT
   note_id,
   created_at,
   user_id
  FROM
   note_comments_sample
  WHERE
   event = 'opened'
 ), closed (
  note_id,
  created_at,
  user_id
 ) AS (
  SELECT
   note_id,
   created_at,
   user_id
  FROM
   note_comments_sample
  WHERE
   event = 'closed'
 ), action (
  note_id,
  created_at,
  user_id,
  event
 ) AS (
  SELECT
   note_id,
   created_at,
   user_id,
   event
  FROM
   note_comments_sample
 )
 SELECT
  n.note_id,
  n.created_at AS opened_at, -- The same as cop.created_at
  cop.user_id, -- Could be null for annonymous notes. Could be null, if user has been deleted.
  n.closed_at, -- The same as ccl.created_at
  ccl.user_id, -- Could be null, if user has been deleted.
  n.id_country,
  cac.event,
  cac.user_id, -- Could be null, if user has been deleted.
  cac.created_at
 FROM notes_sample n
  JOIN opened cop
  ON n.note_id = cop.note_id
  LEFT JOIN closed ccl
  ON n.note_id = ccl.note_id
  JOIN action cac
  ON n.note_id = cac.note_id
 WHERE (n.closed_at is null OR n.closed_at = ccl.created_at) -- Only last close
 AND (
  n.note_id,
  cac.event,
  cac.user_id,
  cac.created_at) NOT IN (
  SELECT
   id_note,
   action_comment,
   action_id_user,
   action_at
  FROM facts
 )
 ORDER BY
  n.note_id,
  cac.created_at
;

