-- Populares DWH tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-28

SELECT CURRENT_TIMESTAMP AS Processing, 'Updating dimension countries';

-- Populates the countries dimension with new countries.
INSERT INTO dwh.dimension_countries
 (country_id, country_name, country_name_es, country_name_en)
 SELECT country_id, country_name, country_name_es, country_name_en
 FROM countries
 WHERE country_id NOT IN (
  SELECT country_id
  FROM dwh.dimension_countries
 ) ON CONFLICT DO NOTHING
;
-- ToDo update countries with regions.

-- Insert an id for notes without a country.
INSERT INTO dwh.dimension_countries 
 (country_id, country_name, country_name_es, )
 SELECT -1, 'Unkown - International waters',
  'Desconocido - Aguas internacionales', 'Unkown - International waters'
 FROM countries
 WHERE -1 NOT IN (
  SELECT country_id
  FROM dwh.dimension_countries
 ) LIMIT 1 
;

-- Shows usernames renamed.
SELECT DISTINCT d.country_name AS OldCountryName, c.country_name AS NewCountryName
 FROM countries c
  JOIN dwh.dimension_countries d
  ON d.country_id = c.country_id
 WHERE c.country_name <> d.country_name
  OR c.country_name_es <> d.country_name_es
  OR c.country_name_en <> d.country_name_en
;
-- TODO esto podría ser parte de un reporte de cambios de nombres - Vandalismo

SELECT CURRENT_TIMESTAMP AS Processing, 'Updating modified country names';

-- Updates the dimension when username is changed.
UPDATE dwh.dimension_countries
 SET country_name = c.country_name,
 country_name_es = c.country_name_es
 country_name_en = c.country_name_en
 FROM countries AS c
  JOIN dwh.dimension_countries d
  ON d.country_id = c.country_id
 WHERE c.country_name <> d.country_name
  OR c.country_name_es <> d.country_name_es
  OR c.country_name_en <> d.country_name_en
;

SELECT CURRENT_TIMESTAMP AS Processing, 'Inserting dimension users';

-- Inserts new users.
INSERT INTO dwh.dimension_users
 (user_id, username)
 SELECT c.user_id, c.username
 FROM users c
 WHERE c.user_id NOT IN (
  SELECT u.user_id
  FROM dwh.dimension_users u
  )
;

SELECT CURRENT_TIMESTAMP AS Processing, 'Showing modified usernames';

-- Shows usernames renamed.
SELECT DISTINCT d.username AS OldUsername, c.username AS NewUsername
 FROM users c
  JOIN dwh.dimension_users d
  ON d.user_id = c.user_id
 WHERE c.username <> d.username
;

SELECT CURRENT_TIMESTAMP AS Processing, 'Updating modified usernames';

-- Updates the dimension when username is changed.
UPDATE dwh.dimension_users
 SET username = c.username
 FROM users AS c
  JOIN dwh.dimension_users d
  ON d.user_id = c.user_id
 WHERE c.username <> d.username
;

SELECT CURRENT_TIMESTAMP AS Processing, 'Inserting facts';

-- TODO Procesar solo las notas que han sido modificadas
-- Inserts new facts.
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
   id_user
  FROM
   note_comments
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
   id_user
  FROM
   note_comments
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
   id_user,
   event
  FROM
   note_comments
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
 FROM notes n
  JOIN opened cop -- open
  ON n.note_id = cop.note_id
  LEFT JOIN closed ccl -- closed
  ON n.note_id = ccl.note_id
  JOIN action cac -- action
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
  FROM dwh.facts
 )
 ORDER BY
  n.note_id,
  cac.created_at
;

-- TODO Create a process montly to get the badges