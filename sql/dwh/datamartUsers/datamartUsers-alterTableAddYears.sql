-- Verifies if the base tables are created in the database.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2023-11-09
  
ALTER TABLE dwh.datamartUsers
 ADD COLUMN history_${YEAR}_open INTEGER,
 ADD COLUMN history_${YEAR}_commented INTEGER,
 ADD COLUMN history_${YEAR}_closed INTEGER,
 ADD COLUMN history_${YEAR}_closed_with_comment INTEGER,
 ADD COLUMN history_${YEAR}_reopened INTEGER
;
COMMENT ON COLUMN dwh.datamartUsers.history_${YEAR}_open IS
  'Qty of notes opened in ${YEAR}';
COMMENT ON COLUMN dwh.datamartUsers.history_${YEAR}_commented IS
  'Qty of notes commented in ${YEAR}';
COMMENT ON COLUMN dwh.datamartUsers.history_${YEAR}_closed IS
  'Qty of notes closed in ${YEAR}';
COMMENT ON COLUMN dwh.datamartUsers.history_${YEAR}_closed_with_comment IS
  'Qty of notes closed with comment in ${YEAR}';
COMMENT ON COLUMN dwh.datamartUsers.history_${YEAR}_reopened IS
  'Qty of notes reopened in ${YEAR}';
