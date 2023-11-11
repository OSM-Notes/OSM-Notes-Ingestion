-- Verifies if the base tables are created in the database.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-10
  
ALTER TABLE dwh.datamartCountries
 ADD COLUMN history_${YEAR}_open INTEGER,
 ADD COLUMN history_${YEAR}_commented INTEGER,
 ADD COLUMN history_${YEAR}_closed INTEGER,
 ADD COLUMN history_${YEAR}_closed_with_comment INTEGER,
 ADD COLUMN history_${YEAR}_reopened INTEGER
;
