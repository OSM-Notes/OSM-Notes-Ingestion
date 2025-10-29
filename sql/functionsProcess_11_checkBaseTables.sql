-- Verifies if the base tables are created in the database.
-- Note: 'tries' table is optional (created by updateCountries.sh) and not
-- required for basic API processing, so it's not checked here.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-29

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
    RAISE EXCEPTION 'Base tables are missing: countries.';
   END IF;

   SELECT /* Notes-base */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'notes'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: notes.';
   END IF;

   SELECT /* Notes-base */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'note_comments'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: note_comments.';
   END IF;

   SELECT /* Notes-base */ COUNT(TABLE_NAME)
    INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'public'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'logs'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Base tables are missing: logs.';
   END IF;

   -- Note: 'tries' table is optional and created by updateCountries.sh
   -- It's not required for basic API processing, so we don't check for it
  END;
  $$;
