-- Creates data warehouse relations.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-02

-- Primrary keys
SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Creating primary keys' AS Task;

ALTER TABLE dwh.facts
 ADD CONSTRAINT pk_facts
 PRIMARY KEY (fact_id);

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
SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Creating foreign keys' AS Task;

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_country
 FOREIGN KEY (dimension_id_country)
 REFERENCES dwh.dimension_countries (dimension_country_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_day_action
 FOREIGN KEY (action_dimension_id_date)
 REFERENCES dwh.dimension_days (dimension_day_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_hour_of_week_action
 FOREIGN KEY (action_dimension_id_hour_of_week)
 REFERENCES dwh.dimension_hours_of_week (dimension_how_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_users_action
 FOREIGN KEY (action_dimension_id_user)
 REFERENCES dwh.dimension_users (dimension_user_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_day_opened
 FOREIGN KEY (opened_dimension_id_date)
 REFERENCES dwh.dimension_days (dimension_day_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_time_opened
 FOREIGN KEY (opened_dimension_id_hour_of_week)
 REFERENCES dwh.dimension_hours_of_week (dimension_how_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_users_opened
 FOREIGN KEY (opened_dimension_id_user)
 REFERENCES dwh.dimension_users (dimension_user_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_day_closed
 FOREIGN KEY (closed_dimension_id_date)
 REFERENCES dwh.dimension_days (dimension_day_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_time_closed
 FOREIGN KEY (closed_dimension_id_hour_of_week)
 REFERENCES dwh.dimension_hours_of_week (dimension_how_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_users_closed
 FOREIGN KEY (closed_dimension_id_user)
 REFERENCES dwh.dimension_users (dimension_user_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_application_created
 FOREIGN KEY (dimension_application_creation)
 REFERENCES dwh.dimension_applications (dimension_application_id);

ALTER TABLE dwh.dimension_countries
 ADD CONSTRAINT fk_region
 FOREIGN KEY (region_id)
 REFERENCES dwh.dimension_regions (dimension_region_id);

SELECT /* Notes-ETL */ CURRENT_TIMESTAMP AS Processing,
 'Creating indexes' AS Task;

-- Unique keys

CREATE UNIQUE INDEX dimension_user_id_uniq
 ON dwh.dimension_users
 (user_id);
COMMENT ON INDEX dwh.dimension_user_id_uniq IS 'OSM User id';

CREATE UNIQUE INDEX dimension_country_id_uniq
 ON dwh.dimension_countries
 (country_id);
COMMENT ON INDEX dwh.dimension_country_id_uniq IS 'OSM Country relation id';

CREATE UNIQUE INDEX dimension_day_id_uniq
 ON dwh.dimension_days
 (date_id);
COMMENT ON INDEX dwh.dimension_day_id_uniq IS 'Date';

CREATE INDEX facts_action_date ON dwh.facts (action_at);
COMMENT ON INDEX dwh.facts_action_date IS
  'Improves queries by action timestamp';

CREATE INDEX action_idx 
 ON dwh.facts (action_dimension_id_user, action_comment);
COMMENT ON INDEX dwh.action_idx IS 'Improves queries by user and action type';

CREATE INDEX open_user_date_idx
 ON dwh.facts (opened_dimension_id_date, opened_dimension_id_user);
COMMENT ON INDEX dwh.open_user_date_idx IS
  'Improves queries by creating date and user';

CREATE INDEX open_user_idx
 ON dwh.facts (opened_dimension_id_user);
COMMENT ON INDEX dwh.open_user_idx IS 'Improves queries by creating user';

CREATE INDEX closed_user_date_idx
ON dwh.facts (closed_dimension_id_date, closed_dimension_id_user);
COMMENT ON INDEX dwh.closed_user_date_idx IS
  'Improves queries by closing data and user';

CREATE INDEX closed_user_idx
ON dwh.facts (closed_dimension_id_user);
COMMENT ON INDEX dwh.closed_user_idx IS 'Improves queries by closing user';

CREATE INDEX country_open_user_idx
ON dwh.facts (dimension_id_country, opened_dimension_id_user);
COMMENT ON INDEX dwh.country_open_user_idx IS
  'Improves queries by country and opening user';

CREATE INDEX country_closed_user_idx
ON dwh.facts (dimension_id_country, closed_dimension_id_user);
COMMENT ON INDEX dwh.country_closed_user_idx IS
  'Improves queries by country and closing user';

CREATE INDEX hours_opening_idx
ON dwh.facts (opened_dimension_id_hour_of_week, opened_dimension_id_user);
COMMENT ON INDEX dwh.hours_opening_idx IS
  'Improves queries by opening hour and user';

CREATE INDEX hours_commenting_idx
ON dwh.facts (action_dimension_id_hour_of_week, action_dimension_id_user);
COMMENT ON INDEX dwh.hours_commenting_idx IS
  'Improves queries by action hour and user';

CREATE INDEX hours_closing_idx
ON dwh.facts (closed_dimension_id_hour_of_week, closed_dimension_id_user);
COMMENT ON INDEX dwh.hours_closing_idx IS
  'Improves queries by closing hour and user';

CREATE INDEX date_user_action_idx
ON dwh.facts (action_dimension_id_date, action_dimension_id_user,
 action_comment);
COMMENT ON INDEX dwh.date_user_action_idx IS
  'Improves queries by action date, user and type';

CREATE INDEX date_action_country_idx
ON dwh.facts (action_dimension_id_date, dimension_id_country, action_comment);
COMMENT ON INDEX dwh.date_action_country_idx IS
  'Improves queries by action date, country and type';

CREATE INDEX action_country_idx
ON dwh.facts (dimension_id_country, action_comment);
COMMENT ON INDEX dwh.action_country_idx IS
  'Improves queries by country and action type';

CREATE INDEX modified_users_idx
ON dwh.dimension_users (modified);
COMMENT ON INDEX dwh.modified_users_idx IS
  'Improves queries by user that performed actions';

CREATE INDEX modified_countries_idx
ON dwh.dimension_countries (modified);
COMMENT ON INDEX dwh.modified_countries_idx IS
  'Improves queries by country where performed actions were done';

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

CREATE OR REPLACE FUNCTION dwh.update_days_to_resolution()
  RETURNS TRIGGER AS
 $$
 DECLARE
  open_date DATE;
  reopen_date DATE;
  close_date DATE;
  days INTEGER;
 BEGIN
  IF (NEW.action_comment = 'closed') THEN
   -- Days between initial open and most recent close.
   SELECT date_id
    INTO open_date
    FROM dwh.dimension_days
    WHERE dimension_day_id = NEW.opened_dimension_id_date;

   SELECT date_id
    INTO close_date
    FROM dwh.dimension_days
    WHERE dimension_day_id = NEW.action_dimension_id_date;

   days := close_date - open_date;
   UPDATE dwh.facts
    SET days_to_resolution = days
     WHERE fact_id = NEW.fact_id;

   -- Days between last reopen and most recent close.
   SELECT MAX(date_id)
    INTO reopen_date
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON f.action_dimension_id_date = d.dimension_day_id
    WHERE id_note = NEW.id_note
    AND action_comment = 'reopened';
   --RAISE NOTICE 'Reopen date: %', reopen_date;
   IF (reopen_date IS NOT NULL) THEN
    -- Days from the last reopen.
    days := close_date - reopen_date;
    --RAISE NOTICE 'Difference dates %-%: %', close_date, reopen_date, days;
    UPDATE dwh.facts
     SET days_to_resolution_from_reopen = days
     WHERE fact_id = NEW.fact_id;

    -- Days in open status
    SELECT SUM(days_difference)
     INTO days
    FROM (
     SELECT dd.date_id - dd2.date_id days_difference
     FROM dwh.facts f
     JOIN dwh.dimension_days dd
     ON f.action_dimension_id_date = dd.dimension_day_id
     JOIN dwh.dimension_days dd2
     ON f.recent_opened_dimension_id_date = dd2.dimension_day_id
     WHERE f.id_note = NEW.id_note
     AND f.action_comment <> 'closed'
    ) AS t
    ;
    UPDATE dwh.facts
     SET days_to_resolution_active = days
     WHERE fact_id = NEW.fact_id;

   END IF;
  END IF;
  RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION dwh.update_days_to_resolution IS
  'Sets the number of days between the creation and the resolution dates';

CREATE OR REPLACE TRIGGER update_days_to_resolution
  AFTER INSERT ON dwh.facts
  FOR EACH ROW
  EXECUTE FUNCTION dwh.update_days_to_resolution()
;
COMMENT ON TRIGGER update_days_to_resolution ON dwh.facts IS
  'Updates the number of days between creation and resolution dates';

