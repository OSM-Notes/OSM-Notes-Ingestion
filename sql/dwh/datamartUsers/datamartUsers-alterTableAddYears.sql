-- Verifies if the base tables are created in the database.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-09
  
ALTER TABLE dwh.datamartUsers
 ADD COLUMN history_$YEAR_open INTEGER,
 ADD COLUMN history_$YEAR_commented INTEGER,
 ADD COLUMN history_$YEAR_closed INTEGER,
 ADD COLUMN history_$YEAR_closed_with_comment INTEGER,
 ADD COLUMN history_$YEAR_reopened INTEGER
;
