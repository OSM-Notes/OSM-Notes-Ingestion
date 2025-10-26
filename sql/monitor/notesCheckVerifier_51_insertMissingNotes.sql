-- Inserts missing notes from check tables into main tables.
-- This script is executed after differences are identified.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-21

-- Insert missing notes from check to main tables
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Inserting missing notes from check tables' AS Text;

-- Insert notes that exist in check but not in main
INSERT INTO notes (
  note_id,
  latitude,
  longitude,
  created_at,
  status,
  closed_at
)
SELECT /* Notes-check */
  note_id,
  latitude,
  longitude,
  created_at,
  status,
  closed_at
FROM notes_check
WHERE note_id NOT IN (
  SELECT /* Notes-check */ note_id
  FROM notes
)
ON CONFLICT (note_id) DO UPDATE SET
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  created_at = EXCLUDED.created_at,
  status = EXCLUDED.status,
  closed_at = EXCLUDED.closed_at;

-- Show count of inserted notes
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty,
  'Inserted missing notes' AS Text
FROM notes_check
WHERE note_id NOT IN (
  SELECT /* Notes-check */ note_id
  FROM notes
);

-- Update statistics
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Updating notes statistics' AS Text;
ANALYZE notes;

SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Missing notes insertion completed' AS Text;

