-- Populates datamart for countries.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-13

DO
$$
DECLARE
 r RECORD;

BEGIN
 FOR r IN
  -- Process the datamart only for modified countries.
  SELECT f.dimension_id_country
  FROM dwh.facts f
   JOIN dwh.dimension_countries c
   ON (f.dimension_id_country = c.dimension_country_id)
  WHERE c.modified = TRUE
  GROUP BY f.dimension_id_country
  ORDER BY MAX(f.action_at) DESC
 LOOP
  CALL dwh.update_datamart_country(r.dimension_id_country);

  UPDATE dwh.dimension_countries
   SET modified = FALSE
   WHERE dimension_country_id = r.dimension_id_country;

  COMMIT;
 END LOOP;
END
$$;
