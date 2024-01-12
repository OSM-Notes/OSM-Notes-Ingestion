-- Creates data warehouse relations.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-12

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
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
     date_id
    ) VALUES (
     DATE(new_date)
    )
    RETURNING dimension_day_id
     INTO m_id_date
   ;
  END IF;
  RETURN m_id_date;
 END;
 $$ LANGUAGE plpgsql
;

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
  SELECT /* Notes-ETL */ EXTRACT(isodow FROM m_date)
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

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Extra objects created' AS Task;

