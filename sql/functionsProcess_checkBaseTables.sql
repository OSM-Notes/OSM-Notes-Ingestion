-- Verifies if the base tables are created in the database.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-10-25

  DO /* Notes-base-checkTables */
  $$
  DECLARE
   qty INT;
  BEGIN
   SELECT /* Notes-base */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'countries'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: countries';
   END IF;

   SELECT /* Notes-base */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'notes'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: notes';
   END IF;

   SELECT /* Notes-base */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'note_comments'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: note_comments';
   END IF;

   SELECT /* Notes-base */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'logs'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: logs';
   END IF;

   SELECT /* Notes-base */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'tries'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: tries';
   END IF;
  END;
  $$;
