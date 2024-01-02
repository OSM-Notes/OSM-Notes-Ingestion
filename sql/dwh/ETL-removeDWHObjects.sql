-- Drop data warehouse objects.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2024-01-02

DROP TRIGGER IF EXISTS update_days_to_resolution ON dwh.facts;

DROP FUNCTION IF EXISTS dwh.update_days_to_resolution;

DROP FUNCTION IF EXISTS dwh.get_score_user_activity;

DROP FUNCTION IF EXISTS dwh.get_score_country_activity;

DROP FUNCTION IF EXISTS dwh.move_day;

DROP FUNCTION IF EXISTS dwh.refresh_today_activities;

DROP FUNCTION IF EXISTS get_country_region;

DROP FUNCTION IF EXISTS dwh.get_hour_of_week_id;

DROP FUNCTION IF EXISTS dwh.get_date_id;

DROP TABLE IF EXISTS dwh.properties;

DROP TABLE IF EXISTS dwh.facts;

DROP TABLE IF EXISTS dwh.dimension_hours_of_week;

DROP TABLE IF EXISTS dwh.dimension_days;

DROP TABLE IF EXISTS dwh.dimension_countries;

DROP TABLE IF EXISTS dwh.dimension_regions;

DROP TABLE IF EXISTS dwh.dimension_users;

DROP TABLE IF EXISTS dwh.dimension_applications;

DROP SCHEMA IF EXISTS dwh;
