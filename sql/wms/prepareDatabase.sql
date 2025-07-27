-- Installs the method to synchronize notes data with the tables used for WMS.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-27

-- Check if PostGIS extension is available
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'postgis') THEN
    RAISE EXCEPTION 'PostGIS extension is required but not installed. Please install PostGIS first.';
  END IF;
END $$;

-- Check if required columns exist in notes table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notes' 
    AND column_name IN ('note_id', 'created_at', 'closed_at', 'lon', 'lat')
  ) THEN
    RAISE EXCEPTION 'Required columns (note_id, created_at, closed_at, lon, lat) not found in notes table.';
  END IF;
END $$;

-- Creates an independent schema for all objects related to WMS.
CREATE SCHEMA IF NOT EXISTS wms;
COMMENT ON SCHEMA wms IS 'Objects to publish the WMS layer';

-- Creates another table with only the necessary columns for WMS.
-- Use a more efficient approach with WHERE clause to avoid processing all records
CREATE TABLE IF NOT EXISTS wms.notes_wms AS
 SELECT /* Notes-WMS */
  note_id,
  extract(year from created_at) AS year_created_at,
  extract (year from closed_at) AS year_closed_at,
  ST_SetSRID(ST_MakePoint(lon, lat), 4326) AS geometry
 FROM notes
 WHERE lon IS NOT NULL AND lat IS NOT NULL  -- Only include notes with valid coordinates
;
COMMENT ON TABLE wms.notes_wms IS
  'Locations of the notes and its opening and closing year';
COMMENT ON COLUMN wms.notes_wms.note_id IS 'OSM note id';
COMMENT ON COLUMN wms.notes_wms.year_created_at IS
  'Year when the note was created';
COMMENT ON COLUMN wms.notes_wms.year_closed_at IS
  'Year when the note was closed';
COMMENT ON COLUMN wms.notes_wms.geometry IS 'Location of the note';

-- Index for open notes. The most important.
CREATE INDEX IF NOT EXISTS notes_open ON wms.notes_wms (year_created_at);
COMMENT ON INDEX wms.notes_open IS 'Queries based on creation year';

-- Index for closed notes.
CREATE INDEX IF NOT EXISTS notes_closed ON wms.notes_wms (year_closed_at);
COMMENT ON INDEX wms.notes_closed IS 'Queries based on closed year';

-- Add spatial index for better performance
CREATE INDEX IF NOT EXISTS notes_wms_geometry_idx ON wms.notes_wms USING GIST (geometry);
COMMENT ON INDEX wms.notes_wms_geometry_idx IS 'Spatial index for geometry queries';

-- Function for trigger when inserting new notes.
CREATE OR REPLACE FUNCTION wms.insert_new_notes()
  RETURNS TRIGGER AS
 $$
 BEGIN
  -- Only insert if coordinates are valid
  IF NEW.lon IS NOT NULL AND NEW.lat IS NOT NULL THEN
    INSERT INTO wms.notes_wms
     VALUES
     (
      NEW.note_id,
      EXTRACT(YEAR FROM NEW.created_at),
      EXTRACT(YEAR FROM NEW.closed_at),
      ST_SetSRID(ST_MakePoint(NEW.lon, NEW.lat), 4326)
     )
    ;
  END IF;
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

