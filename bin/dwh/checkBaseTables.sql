  DO
  \$\$
  DECLARE
   qty INT;
  BEGIN
   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_countries'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_countries';
   END IF;

   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_users'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_users';
   END IF;

   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'dimension_time'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.dimension_time';
   END IF;

   SELECT COUNT(TABLE_NAME) INTO qty
   FROM INFORMATION_SCHEMA.TABLES
   WHERE TABLE_SCHEMA LIKE 'dwh'
   AND TABLE_TYPE LIKE 'BASE TABLE'
   AND TABLE_NAME = 'facts'
   ;
   IF (qty <> 1) THEN
    RAISE EXCEPTION 'Tables are missing: dwh.facts';
   END IF;
  END;
--TODO include the new ranking tables
  \$\$;