-- Chech base staging tables.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-17

SELECT /* Notes-staging */ clock_timestamp() AS Processing,
 'Creating base staging objects' AS Task;

CREATE SCHEMA IF NOT EXISTS staging;
COMMENT ON SCHEMA staging IS
  'Objects to load from base tables to data warehouse';

CREATE OR REPLACE FUNCTION staging.get_application (
 m_text_comment TEXT
) RETURNS INTEGER
 LANGUAGE plpgsql
 AS $func$
 DECLARE
  m_id_dimension_application INTEGER;
  r RECORD;
 BEGIN
  <<application_found>>
  FOR r IN
   SELECT /* Notes-staging */ pattern, dimension_application_id
   FROM dwh.dimension_applications
  LOOP
   IF (r.pattern IS NOT NULL AND m_text_comment SIMILAR TO r.pattern) THEN
    m_id_dimension_application := r.dimension_application_id;
    EXIT application_found;
   END IF;
  END LOOP;
  RETURN m_id_dimension_application;
 END
 $func$
;
COMMENT ON FUNCTION staging.get_application IS
  'Returns the name of the application.';

CREATE OR REPLACE FUNCTION staging.get_hashtag_id (
 m_hashtag_name TEXT
) RETURNS INTEGER
 LANGUAGE plpgsql
 AS $func$
 DECLARE
  m_id_dimension_hashtag INTEGER;
  r RECORD;
 BEGIN
  --RAISE NOTICE 'Requesting id for hashtag: %.', m_hashtag_name;
  IF (m_hashtag_name IS NULL) THEN
   m_id_dimension_hashtag := 1;
  ELSE
   SELECT /* Notes-staging */ dimension_hashtag_id
    INTO m_id_dimension_hashtag
   FROM dwh.dimension_hashtags
   WHERE description = m_hashtag_name;

   IF (m_id_dimension_hashtag IS NULL) THEN
    INSERT INTO dwh.dimension_hashtags (
      description
     ) VALUES (
      m_hashtag_name
     )
     RETURNING dimension_hashtag_id
      INTO m_id_dimension_hashtag
    ;
   END IF;
  END IF;
  RETURN m_id_dimension_hashtag;
 END
 $func$
;
COMMENT ON FUNCTION staging.get_hashtag_id IS
  'Returns the id of the hashtag.';

CREATE OR REPLACE PROCEDURE staging.get_hashtag (
  INOUT m_text_comment TEXT,
  OUT m_hashtag_name TEXT
 )
 LANGUAGE plpgsql
 AS $proc$
 DECLARE
  pos INTEGER;
  substr_after TEXT;
  length INTEGER;
 BEGIN
  pos := STRPOS(m_text_comment, '#');
  IF (pos <> 0) THEN
   --RAISE NOTICE 'Position number sign: %.', pos;
   substr_after := SUBSTR(m_text_comment, pos+1);
   --RAISE NOTICE 'Substring after number sign: %.', substr_after;
   m_hashtag_name := ARRAY_TO_STRING(REGEXP_MATCHES(substr_after, '^\w+'), ';');
   --RAISE NOTICE 'Hashtag name: %.', m_hashtag_name;
   length := LENGTH(m_hashtag_name);
   --RAISE NOTICE 'Length hashtag name: %.', length;
   m_text_comment := SUBSTR(substr_after, length+2);
   --RAISE NOTICE 'New substring: %.', m_text_comment;
  ELSE
   m_text_comment := NULL;
  END IF;
 END
$proc$
;
COMMENT ON PROCEDURE staging.get_hashtag IS
  'Returns the first hashtag of the given string';

SELECT /* Notes-staging */ clock_timestamp() AS Processing,
 'Finished creating base staging objects' AS Task;
