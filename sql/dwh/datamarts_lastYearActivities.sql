-- Populates datamart for countries.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-20

/**
 * Returns the score, from 0 to 9 for the activities of a user in a day.
 */
CREATE OR REPLACE FUNCTION dwh.get_score_user_activity (
  qty INTEGER
) RETURNS SMALLINT
 LANGUAGE plpgsql
 AS $func$
  DECLARE
   score SMALLINT;
  BEGIN
   IF (qty = 0) THEN
    score := 0;
   ELSIF (1 <= qty AND qty <= 2) THEN
    score := 1;
   ELSIF (3 <= qty AND qty <= 6) THEN
    score := 2;
   ELSIF (7 <= qty AND qty <= 14) THEN
    score := 3;
   ELSIF (15 <= qty AND qty <= 30) THEN
    score := 4;
   ELSIF (31 <= qty AND qty <= 62) THEN
    score := 5;
   ELSIF (63 <= qty AND qty <= 126) THEN
    score := 6;
   ELSIF (127 <= qty AND qty <= 254) THEN
    score := 7;
   ELSIF (255 <= qty AND qty <= 510) THEN
    score := 8;
   ELSIF (511 <= qty ) THEN
    score := 9;
   END IF;
   RETURN score;
  END
 $func$
;
COMMENT ON FUNCTION dwh.get_score_user_activity IS
  'Returns the score (0-9) for the given numer of actions for a user';

/**
 * Returns the score, from 0 to 9 for the activities in a country in a day.
 */
CREATE OR REPLACE FUNCTION dwh.get_score_country_activity (
  qty INTEGER
) RETURNS SMALLINT
 LANGUAGE plpgsql
 AS $func$
  DECLARE
   score SMALLINT;
  BEGIN
   IF (qty = 0) THEN
    score := 0;
   ELSIF (1 <= qty AND qty <= 2) THEN
    score := 1;
   ELSIF (3 <= qty AND qty <= 6) THEN
    score := 2;
   ELSIF (7 <= qty AND qty <= 14) THEN
    score := 3;
   ELSIF (15 <= qty AND qty <= 30) THEN
    score := 4;
   ELSIF (31 <= qty AND qty <= 62) THEN
    score := 5;
   ELSIF (63 <= qty AND qty <= 126) THEN
    score := 6;
   ELSIF (127 <= qty AND qty <= 254) THEN
    score := 7;
   ELSIF (255 <= qty AND qty <= 510) THEN
    score := 8;
   ELSIF (511 <= qty ) THEN
    score := 9;
   END IF;
   RETURN score;
  END
 $func$
;
COMMENT ON FUNCTION dwh.get_score_country_activity IS
  'Returns the score (0-9) for the given numer of actions for a country';

/**
 * Moves the activities day, removing the oldest day at the right, and
 * inserting a new day with 0 at the left.
 */
CREATE OR REPLACE FUNCTION dwh.move_day (
  activity CHAR(371)
) RETURNS CHAR(371)
 LANGUAGE plpgsql
 AS $func$
  DECLARE
   m_new_activity CHAR(371);
  BEGIN
   m_new_activity := SUBSTRING(activity, 2) || '0';
   --RAISE NOTICE 'New vector %.', m_new_activity;
   RETURN m_new_activity;
  END
 $func$
;
COMMENT ON FUNCTION dwh.move_day IS
  'Moves the activities by one position. First is removed (oldest at left), new is a 0 (newest at right)';

/**
 * Updates today's value, which is at the left.
 */
CREATE OR REPLACE FUNCTION dwh.refresh_today_activities (
  activity CHAR(371),
  score SMALLINT
) RETURNS CHAR(371)
 LANGUAGE plpgsql
 AS $func$
  DECLARE
   m_new_activity CHAR(371);
  BEGIN
   m_new_activity := SUBSTRING(activity, 1, 370) || score;
   --RAISE NOTICE 'Updated %-%.', m_new_activity, score;
   RETURN m_new_activity;
  END
 $func$
;
COMMENT ON FUNCTION dwh.refresh_today_activities IS
  'Updates the today''activities with the new value given';
