-- Creates a stub version of get_country function.
-- This stub returns NULL when countries table doesn't exist,
-- allowing procedures to work without country assignment.
--
-- This is used when the full get_country function cannot be created
-- because the countries table doesn't exist yet.
--
-- To create the full function, run updateCountries.sh --base
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-11-25

CREATE OR REPLACE FUNCTION get_country (
  lon DECIMAL,
  lat DECIMAL,
  id_note INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql
AS $func$
BEGIN
  -- Stub function: returns NULL when countries table doesn't exist
  -- This allows procedures to work without country assignment
  RETURN NULL;
END;
$func$;

COMMENT ON FUNCTION get_country IS
  'Stub function: returns NULL when countries table does not exist. Run updateCountries.sh --base to create full function.';

