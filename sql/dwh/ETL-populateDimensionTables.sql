-- Populares DWH tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-31

SELECT CURRENT_TIMESTAMP AS Processing, 'Regions added' AS Task;

INSERT INTO dwh.dimension_regions (region_name_es, region_name_en) VALUES
 ('Indefinida', 'Undefined'),
 ('Norteamérica', 'North America'),
 ('Centroamérica', 'Central America'),
 ('Antillas', 'Antilles'),
 ('Sudamérica', 'South America'),
 ('Europa Occidental', 'Western Europe'),
 ('Europa Oriental', 'Eastern Europe'),
 ('Cáucaso', 'Caucasus'),
 ('Siberia', 'Siberia'),
 ('Asia Central', 'Central Asia'),
 ('Asia Oriental', 'East Asia'),
 ('África del Norte', 'North Africa'),
 ('África subsahariana', 'Sub-Saharan Africa'),
 ('Medio Oriente', 'Middle East'),
 ('Indostán', 'Indian subcontinent'),
 ('Indochina', 'Mainland Southeast Asia'),
 ('Insulindia', 'Malay Archipelago'),
 ('Islas del Pacífico (Melanesia, Micronesia y Polinesia)', 'Pacific Islands (Melanesia, Micronesia and Polynesia)'),
 ('Australia', 'Australia');

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
 SET region_id = get_country_region(country_id);

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

DO
$$
DECLARE
 m_day SMALLINT;
 m_hour SMALLINT;
 m_date VARCHAR(32);
BEGIN
 m_day := 1;
 WHILE (m_day <= 7) LOOP
  m_hour := 1;
  WHILE (m_hour <= 24) LOOP
   IF (m_day < 10) THEN
    IF (m_hour < 10) THEN
     m_date := '2013-07-0' || m_day || ' 0' || m_hour || ':00:00.00000+00';
    ELSE
     m_date := '2013-07-0' || m_day || ' ' || m_hour || ':00:00.00000+00';
    END IF;
   ELSE
    IF (m_hour < 10) THEN
     m_date := '2013-07-' || m_day || ' 0' || m_hour || ':00:00.00000+00';
    ELSE
     m_date := '2013-07-' || m_day || ' ' || m_hour || ':00:00.00000+00';
    END IF;
   END IF;
   PERFORM dwh.get_hour_of_week_id(m_date::timestamp);
   m_hour := m_hour + 1;
  END LOOP;
  m_day := m_day + 1;
 END LOOP;
END
$$;

SELECT CURRENT_TIMESTAMP AS Processing, 'Dimensions populated' AS Task;
