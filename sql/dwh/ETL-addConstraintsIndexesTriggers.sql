-- Creates data warehouse relations.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-28

-- Primary keys.
ALTER TABLE dwh.facts
 ADD CONSTRAINT pk_facts
 PRIMARY KEY (fact_id);

ALTER TABLE dwh.dimension_users
 ADD CONSTRAINT pk_user_dim
 PRIMARY KEY (dimension_user_id);

ALTER TABLE dwh.dimension_countries
 ADD CONSTRAINT pk_countries_dim
 PRIMARY KEY (dimension_country_id);

ALTER TABLE dwh.dimension_time
 ADD CONSTRAINT pk_date_dim
 PRIMARY KEY (dimension_day_id);

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
 ADD CONSTRAINT fk_date
 FOREIGN KEY (action_id_date)
 REFERENCES dwh.dimension_time (dimension_day_id);

-- Unique keys
CREATE UNIQUE INDEX fact_id_uniq
 ON TABLE dwh.facts
 (id_note);

CREATE UNIQUE INDEX dimension_user_id_uniq
 ON TABLE dwh.dimension_users
 (user_id);

CREATE UNIQUE INDEX dimension_country_id_uniq
 ON TABLE dwh.dimension_countries
 (country_id);

CREATE UNIQUE INDEX dimension_day_id_uniq
 ON TABLE dwh.dimension_days
 (date_id);

CREATE INDEX IF NOT EXISTS facts_action_date ON dwh.facts (action_at);

-- Function for trigger when inserting new dates.
-- FIXME if there are no action on a given date, then that date will be missing.
CREATE OR REPLACE FUNCTION dwh.insert_new_dates()
  RETURNS TRIGGER AS
 $$
 BEGIN
  INSERT INTO dwh.dimension_days VALUES (
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
  EXECUTE FUNCTION dwh.insert_new_dates()
;
