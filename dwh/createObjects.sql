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
 action_at TIMESTAMP,
 action_id_date DATE
);

CREATE TABLE IF NOT EXISTS dwh.dimension_users (
 user_id INTEGER NOT NULL,
 username VARCHAR(256)
);

CREATE TABLE IF NOT EXISTS dwh.dimension_countries (
 country_id INTEGER NOT NULL,
 country_name VARCHAR(100),
 country_name_es VARCHAR(100),
 country_name_en VARCHAR(100)
-- ToDo Include the regions
);

CREATE TABLE IF NOT EXISTS dwh.dimension_time (
 date_id DATE,
 days_from_notes_epoch INTEGER,
 days_to_next_year INTEGER
);

CREATE INDEX IF NOT EXISTS facts_action_date ON dwh.facts (action_at);

-- Function for trigger when inserting new dates.
-- FIXME if there are no action on a given date, then that date will be missing.
CREATE OR REPLACE FUNCTION dwh.insert_new_notes()
  RETURNS TRIGGER AS
 $$
 BEGIN
  INSERT INTO dwh.dimension_time VALUES (
    date(NEW.action_at), -- date_id
    DATE_PART('doy', NEW.action_at), -- days_from_notes_epoch
    365 - DATE_PART('doy', NEW.action_at) -- days_to_next_year
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
