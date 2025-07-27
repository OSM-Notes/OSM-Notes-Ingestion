DROP FUNCTION IF EXISTS dwh.update_days_to_resolution;
DROP TRIGGER IF EXISTS update_days_to_resolution ON dwh.facts;
ALTER TABLE dwh.facts DROP CONSTRAINT fk_application_created;
ALTER TABLE dwh.facts DROP CONSTRAINT fk_country;
ALTER TABLE dwh.facts DROP CONSTRAINT fk_day_action;
ALTER TABLE dwh.facts DROP CONSTRAINT fk_day_closed;
ALTER TABLE dwh.facts DROP CONSTRAINT fk_day_opened;
ALTER TABLE dwh.facts DROP CONSTRAINT fk_hour_of_week_action;
ALTER TABLE dwh.facts DROP CONSTRAINT fk_time_closed;
ALTER TABLE dwh.facts DROP CONSTRAINT fk_time_opened;
ALTER TABLE dwh.facts DROP CONSTRAINT fk_users_action;
ALTER TABLE dwh.facts DROP CONSTRAINT fk_users_closed;
ALTER TABLE dwh.facts DROP CONSTRAINT fk_users_opened;
DROP INDEX dwh.action_country_idx;
DROP INDEX dwh.action_idx;
DROP INDEX dwh.closed_user_date_idx;
DROP INDEX dwh.closed_user_idx;
DROP INDEX dwh.country_closed_user_idx;
DROP INDEX dwh.country_open_user_idx;
DROP INDEX dwh.date_action_country_idx;
DROP INDEX dwh.date_user_action_idx;
DROP INDEX dwh.facts_action_date;
DROP INDEX dwh.hours_closing_idx;
DROP INDEX dwh.hours_commenting_idx;
DROP INDEX dwh.hours_opening_idx;
DROP INDEX dwh.open_user_date_idx;
DROP INDEX dwh.open_user_idx;
DROP INDEX dwh.recent_opened_idx;
DROP INDEX dwh.resolution_idx;

delete from dwh.facts ;
SELECT /* Notes-ETL */
    SETVAL((SELECT PG_GET_SERIAL_SEQUENCE('dwh.facts', 'fact_id')),
    1, FALSE);

    INSERT INTO dwh.facts (
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
      )
     SELECT /* Notes-ETL */
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
     FROM staging.facts_2013
     ORDER BY fact_id
     ;
    INSERT INTO dwh.facts (
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
      )
     SELECT /* Notes-ETL */
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
     FROM staging.facts_2014
     ORDER BY fact_id
     ;
    INSERT INTO dwh.facts (
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
      )
     SELECT /* Notes-ETL */
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
     FROM staging.facts_2015
     ORDER BY fact_id
     ;
    INSERT INTO dwh.facts (
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
      )
     SELECT /* Notes-ETL */
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
     FROM staging.facts_2016
     ORDER BY fact_id
     ;
    INSERT INTO dwh.facts (
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
      )
     SELECT /* Notes-ETL */
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
     FROM staging.facts_2017
     ORDER BY fact_id
     ;
    INSERT INTO dwh.facts (
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
      )
     SELECT /* Notes-ETL */
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
     FROM staging.facts_2018
     ORDER BY fact_id
     ;
    INSERT INTO dwh.facts (
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
      )
     SELECT /* Notes-ETL */
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
     FROM staging.facts_2019
     ORDER BY fact_id
     ;

    INSERT INTO dwh.facts (
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
      )
     SELECT /* Notes-ETL */
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
     FROM staging.facts_2020
     ORDER BY fact_id
     ;
    INSERT INTO dwh.facts (
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
      )
     SELECT /* Notes-ETL */
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
     FROM staging.facts_2021
     ORDER BY fact_id
     ;
    INSERT INTO dwh.facts (
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
      )
     SELECT /* Notes-ETL */
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
     FROM staging.facts_2022
     ORDER BY fact_id
     ;
    INSERT INTO dwh.facts (
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
      )
     SELECT /* Notes-ETL */
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
     FROM staging.facts_2023
     ORDER BY fact_id
     ;
    INSERT INTO dwh.facts (
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
      )
     SELECT /* Notes-ETL */
      id_note, dimension_id_country, processing_time, action_at, action_comment,
      action_dimension_id_date, action_dimension_id_hour_of_week,
      action_dimension_id_user, opened_dimension_id_date,
      opened_dimension_id_hour_of_week, opened_dimension_id_user,
      closed_dimension_id_date, closed_dimension_id_hour_of_week,
      closed_dimension_id_user, dimension_application_creation,
      recent_opened_dimension_id_date, days_to_resolution,
      days_to_resolution_active, days_to_resolution_from_reopen, hashtag_1,
      hashtag_2, hashtag_3, hashtag_4, hashtag_5, hashtag_number
     FROM staging.facts_2024
     ORDER BY fact_id
     ;

-- Foreign keys.
SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
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

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Creating indexes' AS Task;

-- Unique keys

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

CREATE INDEX recent_opened_idx
 ON dwh.facts (recent_opened_dimension_id_date);
COMMENT ON INDEX dwh.recent_opened_idx IS 'Improves queries for reopened notes';

CREATE INDEX resolution_idx
 ON dwh.facts (id_note, fact_id);
COMMENT ON INDEX dwh.resolution_idx IS 'Improves queries to get resolve notes';

SELECT /* Notes-ETL */ clock_timestamp() AS Processing,
 'Creating triggers' AS Task;

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
   SELECT /* Notes-ETL */ date_id
    INTO open_date
    FROM dwh.dimension_days
    WHERE dimension_day_id = NEW.opened_dimension_id_date;

   SELECT /* Notes-ETL */ date_id
    INTO close_date
    FROM dwh.dimension_days
    WHERE dimension_day_id = NEW.action_dimension_id_date;

   days := close_date - open_date;
   UPDATE dwh.facts
    SET days_to_resolution = days
     WHERE fact_id = NEW.fact_id;

   -- Days between last reopen and most recent close.
   SELECT /* Notes-ETL */ MAX(date_id)
    INTO reopen_date
   FROM dwh.facts f
    JOIN dwh.dimension_days d
    ON f.action_dimension_id_date = d.dimension_day_id
    WHERE id_note = NEW.id_note
    AND action_comment = 'reopened';
   --RAISE NOTICE 'Reopen date: %.', reopen_date;
   IF (reopen_date IS NOT NULL) THEN
    -- Days from the last reopen.
    days := close_date - reopen_date;
    --RAISE NOTICE 'Difference dates %-%: %.', close_date, reopen_date, days;
    UPDATE dwh.facts
     SET days_to_resolution_from_reopen = days
     WHERE fact_id = NEW.fact_id;

    -- Days in open status
    SELECT /* Notes-ETL */ SUM(days_difference)
     INTO days
    FROM (
     SELECT /* Notes-ETL */ dd.date_id - dd2.date_id days_difference
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

-- Set the next number to generate to the sequence.
SELECT /* Notes-ETL */
    SETVAL((SELECT PG_GET_SERIAL_SEQUENCE('dwh.facts', 'fact_id')),
    (SELECT (MAX(fact_id) + 1) FROM dwh.facts), FALSE);

DO /* Notes-ETL */
 $$
 DECLARE
  m_qty_iterations INTEGER;
  m_iter INTEGER;
  m_recent_opened_dimension_id_date INTEGER;
  m_previous_action_fact_id INTEGER;
  rec_no_recent_open_fact RECORD;
  no_recent_open CURSOR FOR
   SELECT /* Notes-staging */
    fact_id, id_note
   FROM dwh.facts f
   WHERE f.recent_opened_dimension_id_date IS NULL
   ORDER BY id_note, action_at
   FOR UPDATE;

 BEGIN

  SELECT MAX(qty)
   INTO m_qty_iterations
  FROM (
   SELECT COUNT(1) qty, id_note
   FROM dwh.facts f
   WHERE f.recent_opened_dimension_id_date IS NULL
   GROUP BY f.id_note
  ) AS t;
  m_iter := 0;
  WHILE (m_iter < m_qty_iterations) LOOP
   OPEN no_recent_open;

   LOOP
    FETCH no_recent_open INTO rec_no_recent_open_fact;
    -- Exit when no more rows to fetch.
    EXIT WHEN NOT FOUND;

    SELECT /* Notes-staging */ max(fact_id)
     INTO m_previous_action_fact_id
    FROM dwh.facts f
    WHERE f.id_note = rec_no_recent_open_fact.id_note
 --   AND f.days_to_resolution_active IS NOT NULL
    AND f.fact_id < rec_no_recent_open_fact.fact_id;

    SELECT /* Notes-staging */ recent_opened_dimension_id_date
     INTO m_recent_opened_dimension_id_date
    FROM dwh.facts f
    WHERE f.fact_id = m_previous_action_fact_id;

    UPDATE dwh.facts
     SET recent_opened_dimension_id_date = m_recent_opened_dimension_id_date
     WHERE CURRENT OF no_recent_open;
    RAISE NOTICE 'Updating id_note % with fact_id % data %.',
      rec_no_recent_open_fact.id_note, m_previous_action_fact_id,
      m_recent_opened_dimension_id_date;
   END LOOP;

   m_previous_action_fact_id := null;
   m_recent_opened_dimension_id_date := null;

   CLOSE no_recent_open;
   m_iter := m_iter + 1;
  END LOOP;
 END
 $$
;

DELETE FROM dwh.facts
  WHERE recent_opened_dimension_id_date IS NULL;

ALTER TABLE dwh.facts ALTER COLUMN recent_opened_dimension_id_date SET NOT NULL;
