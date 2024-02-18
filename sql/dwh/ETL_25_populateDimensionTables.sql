-- Populates the dimensions tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-11

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Inserting Regions' AS Task;

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
 ('Islas del Pacífico (Melanesia, Micronesia y Polinesia)',
   'Pacific Islands (Melanesia, Micronesia and Polynesia)'),
 ('Australia', 'Australia'),
 ('Antártida','Antarctica');

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Inserting dimension countries' AS Task;

-- Insert an id for notes without a country. It does not insert again if it
-- already exist on the table (-1 NOT IN).
INSERT INTO dwh.dimension_countries
 (country_id, country_name, country_name_es, country_name_en)
 SELECT /* Notes-ETL */ -1, 'Unkown - International waters',
  'Desconocido - Aguas internacionales', 'Unkown - International waters'
 FROM countries
 WHERE -1 NOT IN (
  SELECT /* Notes-ETL */ country_id
  FROM dwh.dimension_countries
 ) LIMIT 1
;

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Adding hour values' AS Task;

DO /* Notes-ETL-addWeekHours */
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
   PERFORM dwh.get_hour_of_week_id(m_date::TIMESTAMP);
   m_hour := m_hour + 1;
  END LOOP;
  m_day := m_day + 1;
 END LOOP;
END
$$;

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Adding application names' AS Task;

INSERT INTO dwh.dimension_applications (application_name, pattern) VALUES
('Unknown', NULL),
('StreetComplete', '%via StreetComplete%'),
('Maps.me', '%#mapsme'),
('EveryDoor', '%#EveryDoor'),
('OsmAnd', '%#OsmAnd'),
('LocusMap', '%#LocusMap'),
('OrganicMaps', '%#organicmaps'),
('OSM Report', '%#osmreport')
;

INSERT INTO dwh.dimension_applications (application_name, pattern, platform) VALUES
('OrganicMaps', '%#organicmaps android', 'android'),
('OrganicMaps', '%#organicmaps ios', 'ios'),
('OnOSM.org', 'onosm.org %', 'web'),
('MapComplete', '%#MapComplete #notes', 'web'),
('Mapy.cz', '(%#Mapy.cz%|%#Mapycz%|#Mapy.cz%|%#mapycz%)', 'web'),
('msftopenmaps', '%(#msftopenmaps|%#MSFTOpenMaps)%', 'web'),
('OnOSM.OSMiranorg', 'onosm.osmiran.org %', 'web')
;

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Dimensions populated' AS Task;
