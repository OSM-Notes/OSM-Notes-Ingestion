CREATE SCHEMA IF NOT EXISTS dwh;

CREATE TABLE IF NOT EXISTS dwh.facts (
 id_note INTEGER NOT NULL, -- id
 created_at TIMESTAMP NOT NULL,
 created_id_user INTEGER,
 closed_at TIMESTAMP,
 closed_id_user INTEGER,
 id_country INTEGER,
 action_comment note_event_enum,
 action_id_user INTEGER,
 action_at TIMESTAMP
 action_id_date DATE
);

CREATE TABLE IF NOT EXISTS dwh.dimension_users (
 user_id INTEGER NOT NULL,
 username VARCHAR(256)
);

ALTER TABLE dwh.dimension_users
 ADD CONSTRAINT pk_user_dim
 PRIMARY KEY (user_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_users_created
 FOREIGN KEY (created_id_user)
 REFERENCES dwh.dimension_users (user_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_users_closed
 FOREIGN KEY (closed_id_user)
 REFERENCES dwh.dimension_users (user_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_users_action
 FOREIGN KEY (action_id_user)
 REFERENCES dwh.dimension_users (user_id);

CREATE TABLE IF NOT EXISTS dwh.dimension_countries (
 country_id INTEGER NOT NULL,
 country_name VARCHAR(100),
 country_name_es VARCHAR(100),
 country_name_en VARCHAR(100)
-- ToDo Include the regions
);

ALTER TABLE dwh.dimension_countries
 ADD CONSTRAINT pk_countries_dim
 PRIMARY KEY (country_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_country
 FOREIGN KEY (id_country)
 REFERENCES dwh.dimension_countries (country_id);

CREATE TABLE IF NOT EXISTS dwh.dimension_time (
 date_id DATE,
 days_from_notes_epoch INTEGER
);

ALTER TABLE dwh.dimension_time
 ADD CONSTRAINT pk_date_dim
 PRIMARY KEY (date_id);

ALTER TABLE dwh.facts
 ADD CONSTRAINT fk_date
 FOREIGN KEY (action_id_date)
 REFERENCES dwh.dimension_time (date_id);

CREATE INDEX facts_action_date ON dwh.facts (action_at);

-- Function for trigger when inserting new dates.
-- FIXME if there are no action on a given date, then that date will be missing.
CREATE OR REPLACE FUNCTION dwh.insert_new_notes()
  RETURNS TRIGGER AS
 $$
 BEGIN
  INSERT INTO dwh.dimension_time
   VALUES
   (
    date(NEW.action_at),
    DATE_PART('doy', NEW.action_at),
    365 - DATE_PART('doy', NEW.action_at)
   ) ON CONFLICT DO NOTHING
  ;
  RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;

-- Trigger for new notes.
CREATE OR REPLACE TRIGGER insert_new_dates
  AFTER INSERT ON dwh.facts
  FOR EACH ROW
  EXECUTE FUNCTION dwh.insert_new_notes()
;
