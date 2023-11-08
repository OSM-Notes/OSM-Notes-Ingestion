-- Drop data warehouse objects.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-28

SELECT CURRENT_TIMESTAMP AS Processing, 'Deleting facts' AS Task;
DELETE FROM dwh.facts;
SELECT CURRENT_TIMESTAMP AS Processing, 'Deleting time' AS Task;
DELETE FROM dwh.dimension_time;
SELECT CURRENT_TIMESTAMP AS Processing, 'Deleting users' AS Task;
DELETE FROM dwh.dimension_users;
SELECT CURRENT_TIMESTAMP AS Processing, 'Deleting countries' AS Task;
DELETE FROM dwh.dimension_countries;
