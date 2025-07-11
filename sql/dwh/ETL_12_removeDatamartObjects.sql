-- Drop data warehouse objects.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2027-07-10


DROP FUNCTION IF EXISTS dwh.refresh_today_activities;

DROP FUNCTION IF EXISTS dwh.move_day;

DROP FUNCTION IF EXISTS dwh.get_score_country_activity;

DROP FUNCTION IF EXISTS dwh.get_score_user_activity;

