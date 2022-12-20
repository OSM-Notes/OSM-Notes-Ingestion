SELECT CURRENT_TIMESTAMP AS Processing, 'Deleting facts';
DELETE FROM dwh.facts;
SELECT CURRENT_TIMESTAMP AS Processing, 'Deleting users';
DELETE FROM dwh.dimension_users;
SELECT CURRENT_TIMESTAMP AS Processing, 'Deleting countries';
DELETE FROM dwh.dimension_countries;

