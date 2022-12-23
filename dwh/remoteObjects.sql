DROP TRIGGER IF EXISTS insert_new_dates ON dwh.facts;

DROP FUNCTION IF EXISTS dwh.insert_new_notes();

DROP INDEX IF EXISTS facts_action_date;

DROP TABLE IF EXISTS dwh.dimension_time;

DROP TABLE IF EXISTS dwh.dimension_countries;

DROP TABLE IF EXISTS dwh.dimension_users;

DROP TABLE IF EXISTS dwh.facts;

DROP SCHEMA IF EXISTS dwh;

