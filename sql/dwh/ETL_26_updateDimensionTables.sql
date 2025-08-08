-- Updates the dimensions tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-08-08

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Updates dimension users (SCD2)' AS Task;

-- Inserts new users as current rows
INSERT INTO dwh.dimension_users
 (user_id, username, valid_from, is_current)
 SELECT /* Notes-ETL */ c.user_id, c.username, NOW(), TRUE
 FROM users c
 WHERE c.user_id NOT IN (
  SELECT /* Notes-ETL */ u.user_id
  FROM dwh.dimension_users u
  )
;

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Closing previous current rows when username changes' AS Task;

-- Close current rows where username changed (SCD2)
UPDATE dwh.dimension_users d
SET valid_to = NOW(), is_current = FALSE
FROM users c
WHERE d.user_id = c.user_id
  AND d.is_current = TRUE
  AND c.username IS DISTINCT FROM d.username
;

-- Insert new current row with new username
INSERT INTO dwh.dimension_users (user_id, username, valid_from, is_current)
SELECT c.user_id, c.username, NOW(), TRUE
FROM users c
JOIN dwh.dimension_users d ON d.user_id = c.user_id
WHERE d.is_current = FALSE
  AND NOT EXISTS (
    SELECT 1 FROM dwh.dimension_users d2
    WHERE d2.user_id = c.user_id AND d2.username = c.username AND d2.is_current = TRUE
  )
GROUP BY c.user_id, c.username
;

-- SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
--  'Updating modified usernames' AS Task;
--
-- Updates the dimension when username is changed.
-- TODO datamart - Esta actualizando todos con todos, y se esta demorando
--   2025-07-16 Ya se hizo un cambio, para el alias de dimension. Es raro que actualice todos
UPDATE dwh.dimension_users AS d
 SET username = c.username
 FROM users AS c
 WHERE d.user_id = c.user_id
  AND c.username IS DISTINCT FROM d.username
;

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Updating dimension countries' AS Task;

-- Populates the countries dimension with new countries.
INSERT INTO dwh.dimension_countries
 (country_id, country_name, country_name_es, country_name_en,
  iso_alpha2, iso_alpha3)
 SELECT /* Notes-ETL */ country_id, country_name, country_name_es,
  country_name_en, iso_alpha2, iso_alpha3
 FROM countries
 WHERE country_id NOT IN (
  SELECT /* Notes-ETL */ country_id
  FROM dwh.dimension_countries
 )
;
SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Updating countries with region (takes a while)' AS Task;
-- Updates countries with regions.
UPDATE /* Notes-ETL */ dwh.dimension_countries
 SET region_id = dwh.get_country_region(country_id);

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
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

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Updating modified country names' AS Task;

-- Updates the dimension when username is changed.
UPDATE /* Notes-ETL */ dwh.dimension_countries
 SET country_name = c.country_name,
 country_name_es = c.country_name_es,
 country_name_en = c.country_name_en,
 iso_alpha2 = c.iso_alpha2,
 iso_alpha3 = c.iso_alpha3
 FROM countries AS c
  JOIN dwh.dimension_countries d
  ON d.country_id = c.country_id
 WHERE c.country_name IS DISTINCT FROM d.country_name
  OR c.country_name_es IS DISTINCT FROM d.country_name_es
  OR c.country_name_en IS DISTINCT FROM d.country_name_en
  OR c.iso_alpha2 IS DISTINCT FROM d.iso_alpha2
  OR c.iso_alpha3 IS DISTINCT FROM d.iso_alpha3
;

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Dimensions udpated' AS Task;
