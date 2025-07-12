-- Creates data warehouse relations.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-11

-- Primrary keys
SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Creating primary keys' AS Task;

ALTER TABLE dwh.dimension_users
 ADD CONSTRAINT pk_users_dim
 PRIMARY KEY (dimension_user_id);

ALTER TABLE dwh.dimension_regions
 ADD CONSTRAINT pk_regions_dim
 PRIMARY KEY (dimension_region_id);

ALTER TABLE dwh.dimension_countries
 ADD CONSTRAINT pk_countries_dim
 PRIMARY KEY (dimension_country_id);

ALTER TABLE dwh.dimension_days
 ADD CONSTRAINT pk_days_dim
 PRIMARY KEY (dimension_day_id);

ALTER TABLE dwh.dimension_hours_of_week
 ADD CONSTRAINT pk_HoW_dim
 PRIMARY KEY (dimension_how_id);

ALTER TABLE dwh.dimension_applications
 ADD CONSTRAINT pk_applications_dim
 PRIMARY KEY (dimension_application_id);

-- Foreign keys.
SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Creating foreign keys' AS Task;

ALTER TABLE dwh.dimension_countries
 ADD CONSTRAINT fk_region
 FOREIGN KEY (region_id)
 REFERENCES dwh.dimension_regions (dimension_region_id);

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Creating indexes' AS Task;

-- Unique keys

CREATE UNIQUE INDEX dimension_user_id_uniq
 ON dwh.dimension_users
 (user_id);
COMMENT ON INDEX dwh.dimension_user_id_uniq IS 'OSM User id';

CREATE UNIQUE INDEX dimension_username_uniq
 ON dwh.dimension_users
 (username);
COMMENT ON INDEX dwh.dimension_username_uniq IS 'Unique username';

CREATE UNIQUE INDEX dimension_country_id_uniq
 ON dwh.dimension_countries
 (country_id);
COMMENT ON INDEX dwh.dimension_country_id_uniq IS 'OSM Country relation id';

CREATE UNIQUE INDEX dimension_day_id_uniq
 ON dwh.dimension_days
 (date_id);
COMMENT ON INDEX dwh.dimension_day_id_uniq IS 'Date';

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Creating functions' AS Task;

/**
 * Gets the id of the given timestamp. If the ID does not exist, it creates it.
 * If this function is not called at all for a day, they that day will not have
 * an ID, and it will be missing.
 */
CREATE OR REPLACE FUNCTION dwh.get_date_id(new_date TIMESTAMP)
  RETURNS INTEGER AS
 $$
 DECLARE
  m_id_date INTEGER;
 BEGIN
  SELECT /* Notes-ETL */ dimension_day_id
   INTO m_id_date
  FROM dwh.dimension_days
  WHERE date_id = DATE(new_date);

  IF (m_id_date IS NULL) THEN
   INSERT INTO dwh.dimension_days (
     date_id, year, month, day
    ) VALUES (
     DATE(new_date), EXTRACT(YEAR FROM new_date), EXTRACT(MONTH FROM new_date),
     EXTRACT(DAY FROM new_date)
    )
    ON CONFLICT DO NOTHING -- This should not happen, but happens.
    RETURNING dimension_day_id
     INTO m_id_date
   ;
  END IF;
  RETURN m_id_date;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION dwh.get_date_id IS
  'Returns id of the day';

/**
 * Returns the given hour of a timestamp.
 */
CREATE OR REPLACE FUNCTION dwh.get_hour_of_week_id(m_date TIMESTAMP)
  RETURNS INTEGER AS
 $$
 DECLARE
  m_day_of_week SMALLINT;
  m_hour_of_day SMALLINT;
  m_dimension_how_id SMALLINT;
 BEGIN
  SELECT /* Notes-ETL */ EXTRACT(ISODOW FROM m_date)
   INTO m_day_of_week;

  SELECT /* Notes-ETL */ EXTRACT(HOUR FROM m_date)
   INTO m_hour_of_day;

  SELECT /* Notes-ETL */ dimension_how_id
   INTO m_dimension_how_id
  FROM dwh.dimension_hours_of_week
  WHERE dimension_how_id = m_day_of_week * 100 + m_hour_of_day;

  IF (m_dimension_how_id IS NULL) THEN
   INSERT INTO dwh.dimension_hours_of_week (
     dimension_how_id, day_of_week, hour_of_day
    ) VALUES (
     m_day_of_week * 100 + m_hour_of_day, m_day_of_week, m_hour_of_day
    )
   ;
  END IF;
  RETURN m_dimension_how_id;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION dwh.get_hour_of_week_id IS
  'Returns id of the hour of a week';

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Extra objects created' AS Task;

