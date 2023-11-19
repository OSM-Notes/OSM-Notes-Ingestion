-- Populares DWH tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-31

SELECT CURRENT_TIMESTAMP AS Processing, 'Updating dimension countries' AS Task;

-- Insert an id for notes without a country.
INSERT INTO dwh.dimension_countries 
 (country_id, country_name, country_name_es, country_name_en)
 SELECT -1, 'Unkown - International waters',
  'Desconocido - Aguas internacionales', 'Unkown - International waters'
 FROM countries
 WHERE -1 NOT IN (
  SELECT country_id
  FROM dwh.dimension_countries
 ) LIMIT 1 
;

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
-- Updates countries with regions.
UPDATE dwh.dimension_countries
 SET region_id = get_country_region(country_id)

-- Shows usernames renamed.
-- TODO export to a file
--SELECT DISTINCT d.country_name AS OldCountryName, c.country_name AS NewCountryName
-- FROM countries c
--  JOIN dwh.dimension_countries d
--  ON d.country_id = c.country_id
-- WHERE c.country_name <> d.country_name
--  OR c.country_name_es <> d.country_name_es
--  OR c.country_name_en <> d.country_name_en
--;
-- TODO esto podría ser parte de un reporte de cambios de nombres - Vandalismo

SELECT CURRENT_TIMESTAMP AS Processing, 'Updating modified country names' AS Task;

-- Updates the dimension when username is changed.
UPDATE dwh.dimension_countries
 SET country_name = c.country_name,
 country_name_es = c.country_name_es,
 country_name_en = c.country_name_en
 FROM countries AS c
  JOIN dwh.dimension_countries d
  ON d.country_id = c.country_id
 WHERE c.country_name <> d.country_name
  OR c.country_name_es <> d.country_name_es
  OR c.country_name_en <> d.country_name_en
;

SELECT CURRENT_TIMESTAMP AS Processing, 'Inserting dimension users' AS Task;

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

--SELECT CURRENT_TIMESTAMP AS Processing, 'Showing modified usernames' AS Task;
--
-- TODO send to a file
-- Shows usernames renamed.
--SELECT DISTINCT d.username AS OldUsername, c.username AS NewUsername
-- FROM users c
--  JOIN dwh.dimension_users d
--  ON d.user_id = c.user_id
-- WHERE c.username <> d.username
--;

--SELECT CURRENT_TIMESTAMP AS Processing, 'Updating modified usernames' AS Task;
--
-- Updates the dimension when username is changed.
-- TODO Esta actualizando todos con todos, y se esta demorando
--UPDATE dwh.dimension_users
-- SET username = c.username
-- FROM users AS c
--  JOIN dwh.dimension_users d
--  ON d.user_id = c.user_id
-- WHERE c.username <> d.username
;

SELECT CURRENT_TIMESTAMP AS Processing, 'Adding hour values' AS Task;

SELECT dwh.get_time_id('2013-04-24 01:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 02:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 03:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 04:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 05:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 06:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 07:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 08:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 09:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 10:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 11:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 12:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 13:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 14:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 15:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 16:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 17:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 18:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 19:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 20:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 21:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 22:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 23:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 24:00:00.00000+00');
SELECT dwh.get_time_id('2013-04-24 00:00:00.00000+00');

SELECT CURRENT_TIMESTAMP AS Processing, 'Dimensions populated' AS Task;
