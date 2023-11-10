-- Verifies if the base tables are created in the database.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-09
  
  DO
  $$
  DECLARE
   qty INT;
  BEGIN
   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_NAME = 'datamartusers'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: datamartUsers';
   END IF;

   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_NAME = 'badges'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: badges';
   END IF;

   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_NAME = 'badges_per_users'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: badges_per_users';
   END IF;

   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_NAME = 'contributor_types'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: contributor_types';
   END IF;
  END;
  $$;
