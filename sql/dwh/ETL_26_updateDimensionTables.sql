-- Updates the dimensions tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-12-08

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Updates dimension users' AS Task;

-- Inserts new users.
INSERT INTO dwh.dimension_users
 (user_id, username)
 SELECT /* Notes-ETL */ c.user_id, c.username
 FROM users c
 WHERE c.user_id NOT IN (
  SELECT /* Notes-ETL */ u.user_id
  FROM dwh.dimension_users u
  )
;

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Showing modified usernames' AS Task;
-- Exports usernames renamed.
COPY (
 SELECT /* Notes-ETL */ DISTINCT d.username AS OldUsername,
  c.username AS NewUsername
 FROM users c
  JOIN dwh.dimension_users d
  ON d.user_id = c.user_id
 WHERE c.username <> d.username
)
TO '/tmp/usernames_changed.csv' WITH DELIMITER ',' CSV HEADER
;

-- SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
--  'Updating modified usernames' AS Task;
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

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Updating dimension countries' AS Task;

-- Populates the countries dimension with new countries.
INSERT INTO dwh.dimension_countries
 (country_id, country_name, country_name_es, country_name_en)
 SELECT /* Notes-ETL */ country_id, country_name, country_name_es,
  country_name_en
 FROM countries
 WHERE country_id NOT IN (
  SELECT /* Notes-ETL */ country_id
  FROM dwh.dimension_countries
 )
;
SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Updating countries with region (takes a while)' AS Task;
-- Updates countries with regions.
UPDATE /* Notes-ETL */ dwh.dimension_countries
 SET region_id = get_country_region(country_id);

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Showing modified countries' AS Task;
-- Shows countries renamed.
COPY (
 SELECT /* Notes-ETL */ DISTINCT d.country_name AS OldCountryName,
  c.country_name AS NewCountryName
 FROM countries c
  JOIN dwh.dimension_countries d
  ON d.country_id = c.country_id
 WHERE c.country_name <> d.country_name
  OR c.country_name_es <> d.country_name_es
  OR c.country_name_en <> d.country_name_en
)
TO '/tmp/countries_changed.csv' WITH DELIMITER ',' CSV HEADER
;

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Updating modified country names' AS Task;

-- Updates the dimension when username is changed.
UPDATE /* Notes-ETL */ dwh.dimension_countries
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

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Dimensions udpated' AS Task;
