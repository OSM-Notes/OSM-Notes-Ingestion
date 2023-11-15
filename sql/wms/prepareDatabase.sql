-- Installs the method to synchronize notes data with the tables used for WMS.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2022-12-10

-- Creates an independent schema for all objects related to WMS.
CREATE SCHEMA IF NOT EXISTS wms;
COMMENT ON SCHEMA wms IS 'Objects to publish the WMS layer';

-- Creates another table with only the necessary columns for WMS.
CREATE TABLE IF NOT EXISTS wms.notes_wms AS
 SELECT
  note_id,
  extract(year from created_at) AS year_created_at,
  extract (year from closed_at) AS year_closed_at,
  ST_SetSRID(ST_MakePoint(longitude, latitude), 4326) AS geometry
 FROM notes
;
COMMENT ON TABLE wms.notes_wms IS
  'Locations of the notes and its opening and closing year';
COMMENT ON COLUMN wms.notes_wms.note_id IS 'OSM note id';
COMMENT ON COLUMN wms.notes_wms.year_created_at IS
  'Year when the note was created';
COMMENT ON COLUMN wms.notes_wms.year_closed_at IS
  'Yead when the note was closed';
COMMENT ON COLUMN wms.notes_wms.geometry IS 'Location of the note';

-- Index for open notes. The most important.
CREATE INDEX IF NOT EXISTS notes_open ON wms.notes_wms (year_created_at);
COMMENT ON INDEX wms.notes_open IS 'Queries based on creation year';

-- Index for closed notes.
CREATE INDEX IF NOT EXISTS notes_closed ON wms.notes_wms (year_closed_at);
COMMENT ON INDEX wms.notes_closed IS 'Queries based on closed year';

-- Function for trigger when inserting new notes.
CREATE OR REPLACE FUNCTION wms.insert_new_notes()
  RETURNS TRIGGER AS
 $$
 BEGIN
  INSERT INTO wms.notes_wms
   VALUES
   (
    NEW.note_id,
    extract(year from NEW.created_at),
    extract(year from NEW.closed_at),
    ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)
   )
  ;
  RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION wms.insert_new_notes IS 'Insert new notes for the WMS';

-- Function for trigger when updating notes. This applies for 2 cases:
-- * From open to close (solving).
-- * From close to open (reopening).
-- It is not used when adding a comment.
CREATE OR REPLACE FUNCTION wms.update_notes()
  RETURNS TRIGGER AS
 $$
 BEGIN
  UPDATE wms.notes_wms
   SET year_closed_at = extract (year from NEW.closed_at)
   WHERE note_id = NEW.note_id
  ;
  RETURN NEW;
 END;
 $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION wms.update_notes IS
  'Updates the closing year of a note when solved';

-- Trigger for new notes.
CREATE OR REPLACE TRIGGER insert_new_notes
  AFTER INSERT ON notes
  FOR EACH ROW
  EXECUTE FUNCTION wms.insert_new_notes()
;
COMMENT ON TRIGGER insert_new_notes ON notes IS
  'Replicates the insertion of a note in the WMS';

-- Trigger for updated notes.
CREATE OR REPLACE TRIGGER update_notes
  AFTER UPDATE ON notes
  FOR EACH ROW
  WHEN (OLD.closed_at IS DISTINCT FROM NEW.closed_at)
  EXECUTE FUNCTION wms.update_notes()
;
COMMENT ON TRIGGER update_notes ON notes IS
  'Replicates the update of a note in the WMS when closed';
