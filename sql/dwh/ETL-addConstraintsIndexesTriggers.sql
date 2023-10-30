-- Creates data warehouse relations.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-28

ALTER TABLE dwh.facts
 ADD CONSTRAINT pk_facts
 PRIMARY KEY (fact_id);

ALTER TABLE dwh.dimension_users
 ADD CONSTRAINT pk_user_dim
 PRIMARY KEY (dimension_user_id);

ALTER TABLE dwh.dimension_countries
 ADD CONSTRAINT pk_countries_dim
 PRIMARY KEY (dimension_country_id);

ALTER TABLE dwh.dimension_days
 ADD CONSTRAINT pk_days_dim
 PRIMARY KEY (dimension_day_id);

ALTER TABLE dwh.dimension_times
 ADD CONSTRAINT pk_times_dim
 PRIMARY KEY (dimension_time_id);

-- Foreign keys.
ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_users_created
 FOREIGN KEY (created_id_user)
 REFERENCES dwh.dimension_users (dimension_user_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_users_closed
 FOREIGN KEY (closed_id_user)
 REFERENCES dwh.dimension_users (dimension_user_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_users_action
 FOREIGN KEY (action_id_user)
 REFERENCES dwh.dimension_users (dimension_user_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_country
 FOREIGN KEY (id_country)
 REFERENCES dwh.dimension_countries (dimension_country_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_day
 FOREIGN KEY (action_id_date)
 REFERENCES dwh.dimension_days (dimension_day_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_time
 FOREIGN KEY (action_id_hour)
 REFERENCES dwh.dimension_times (dimension_time_id);

-- Unique keys
CREATE UNIQUE INDEX fact_id_uniq
 ON  dwh.facts
 (id_note);

CREATE UNIQUE INDEX dimension_user_id_uniq
 ON dwh.dimension_users
 (user_id);

CREATE UNIQUE INDEX dimension_country_id_uniq
 ON dwh.dimension_countries
 (country_id);

CREATE UNIQUE INDEX dimension_day_id_uniq
 ON dwh.dimension_days
 (date_id);

CREATE INDEX IF NOT EXISTS facts_action_date ON dwh.facts (action_at);

-- TODO if there are no action on a given date, then that date will be missing.
CREATE OR REPLACE FUNCTION dwh.get_data_id(new_date TIMESTAMP)
  RETURNS INTEGER AS
 $$
 DECLARE
  id_date INTEGER;
 BEGIN
  SELECT dimension_day_id INTO id_date
  FROM dwh.dimension_days
  WHERE date_id = new_date::DATE;
  
  IF (id_date IS NULL) THEN
   INSERT INTO dwh.dimension_days (
     date_id, days_from_notes_epoch, days_to_next_year
    ) VALUES (
     new_date::DATE,
     DATE_PART('doy', new_date::DATE),
     365 - DATE_PART('doy', new_date::DATE)
    ) RETURNING id_date
   ;
  END IF;
  RETURN id_date;
 END;
 $$ LANGUAGE plpgsql
;

CREATE OR REPLACE FUNCTION dwh.get_time_id(new_date TIMESTAMP)
  RETURNS INTEGER AS
 $$
 DECLARE
  id_time INTEGER;
  morning BOOLEAN;
 BEGIN
  SELECT dimension_time_id INTO id_time
  FROM dwh.dimension_times
  WHERE id_time = HOUR(new_date);
  
  IF (id_time IS NULL) THEN
   IF (HOUR(new_date) <= 12) THEN
    morning := true;
   END IF;
   INSERT INTO dwh.dimension_times (
     hour, morning
    ) VALUES (
     HOUR(new_date),
     morning
    ) RETURNING id_time
   ;
  END IF;
  RETURN id_time;
 END;
 $$ LANGUAGE plpgsql
;
