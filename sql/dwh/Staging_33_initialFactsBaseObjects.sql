-- Create base objects for year ${YEAR}.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2027-07-11

SELECT /* Notes-staging */ clock_timestamp() AS Processing,
 'Creating objects for year ${YEAR}' AS Task;

CREATE TABLE staging.facts_${YEAR} AS TABLE dwh.facts;

CREATE SEQUENCE staging.facts_${YEAR}_seq;

ALTER TABLE staging.facts_${YEAR} ALTER fact_id
  SET DEFAULT NEXTVAL('staging.facts_${YEAR}_seq'::regclass);

ALTER TABLE staging.facts_${YEAR} ALTER processing_time
  SET DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE staging.facts_${YEAR} ADD PRIMARY KEY (fact_id);

CREATE INDEX facts_action_at_idx_${YEAR} ON staging.facts_${YEAR} (action_at);
COMMENT ON INDEX staging.facts_action_at_idx_${YEAR} IS
  'Improves queries by action timestamp on ${YEAR}';

CREATE INDEX action_idx_${YEAR}
 ON staging.facts_${YEAR} (action_dimension_id_date, id_note, action_comment);
COMMENT ON INDEX staging.action_idx_${YEAR}
 IS 'Improves queries for reopened notes on ${YEAR}';

CREATE INDEX date_differences_idx_${YEAR}
 ON staging.facts_${YEAR} (action_dimension_id_date,
  recent_opened_dimension_id_date, id_note, action_comment);
COMMENT ON INDEX staging.date_differences_idx_${YEAR}
  IS 'Improves queries for reopened notes on ${YEAR}';

CREATE OR REPLACE FUNCTION staging.update_days_to_resolution_${YEAR}()
  RETURNS TRIGGER AS
 $$
 DECLARE
  m_open_date DATE;
  m_reopen_date DATE;
  m_close_date DATE;
  m_days INTEGER;
 BEGIN
  IF (NEW.action_comment = 'closed') THEN
   -- Days between initial open and most recent close.
   SELECT /* Notes-staging */ date_id
    INTO m_open_date
    FROM dwh.dimension_days
    WHERE dimension_day_id = NEW.opened_dimension_id_date;

   SELECT /* Notes-staging */ date_id
    INTO m_close_date
    FROM dwh.dimension_days
    WHERE dimension_day_id = NEW.action_dimension_id_date;

   m_days := m_close_date - m_open_date;
   UPDATE staging.facts_${YEAR}
    SET days_to_resolution = m_days
    WHERE fact_id = NEW.fact_id;

   -- Days between last reopen and most recent close.
   SELECT /* Notes-staging */ MAX(date_id)
    INTO m_reopen_date
   FROM staging.facts_${YEAR} f
    JOIN dwh.dimension_days d
    ON f.action_dimension_id_date = d.dimension_day_id
    WHERE f.id_note = NEW.id_note
    AND f.action_comment = 'reopened';
   --RAISE NOTICE 'Reopen date: %.', m_reopen_date;
   IF (m_reopen_date IS NOT NULL) THEN
    -- Days from the last reopen.
    m_days := m_close_date - m_reopen_date;
    --RAISE NOTICE 'Difference dates %-%: %.', m_close_date, m_reopen_date,
    -- m_days;
    UPDATE staging.facts_${YEAR}
     SET days_to_resolution_from_reopen = m_days
     WHERE fact_id = NEW.fact_id;

    -- Days in open status
    SELECT /* Notes-staging */ SUM(days_difference)
     INTO m_days
    FROM (
     SELECT /* Notes-staging */ dd.date_id - dd2.date_id days_difference
     FROM staging.facts_${YEAR} f
     JOIN dwh.dimension_days dd
     ON f.action_dimension_id_date = dd.dimension_day_id
     JOIN dwh.dimension_days dd2
     ON f.recent_opened_dimension_id_date = dd2.dimension_day_id
     WHERE f.id_note = NEW.id_note
     AND f.action_comment <> 'closed'
    ) AS t
    ;
    UPDATE staging.facts_${YEAR}
     SET days_to_resolution_active = m_days
     WHERE fact_id = NEW.fact_id;

   END IF;
  END IF;
  RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION staging.update_days_to_resolution_${YEAR} IS
  'Sets the number of days between the creation and the resolution dates on ${YEAR}';

CREATE OR REPLACE TRIGGER update_days_to_resolution_${YEAR}
  AFTER INSERT ON staging.facts_${YEAR}
  FOR EACH ROW
  EXECUTE FUNCTION staging.update_days_to_resolution_${YEAR}()
;
COMMENT ON TRIGGER update_days_to_resolution_${YEAR} ON staging.facts_${YEAR} IS
  'Updates the number of days between creation and resolution dates on ${YEAR}';

DO /* Notes-ETL-addWeekHours */
$$
DECLARE
  m_day_year DATE;
  m_dummy INTEGER;
  m_max_day_year DATE;
BEGIN
  -- Insert all days of the year in the dimension.
  SELECT /* Notes-staging */ DATE('2013-04-24')
    INTO m_day_year;
  SELECT /* Notes-staging */ DATE('${YEAR}-12-31')
    INTO m_max_day_year;
  RAISE NOTICE 'Min and max dates % - %.', m_day_year, m_max_day_year;
  WHILE (m_day_year <= m_max_day_year) LOOP
   m_dummy := dwh.get_date_id(m_day_year);
   --RAISE NOTICE 'Processed date %.', m_day_year;
   SELECT /* Notes-staging */ m_day_year + 1
     INTO m_day_year;
  END LOOP;
  RAISE NOTICE 'All dates generated.';
END
$$;

CREATE INDEX IF NOT EXISTS comments_function_year ON note_comments (EXTRACT(YEAR FROM created_at), created_at);
COMMENT ON INDEX comments_function_year IS
  'Index to improve access when processing ETL per years';

SELECT /* Notes-staging */ clock_timestamp() AS Processing,
 'Objects for year ${YEAR} created' AS Task;
