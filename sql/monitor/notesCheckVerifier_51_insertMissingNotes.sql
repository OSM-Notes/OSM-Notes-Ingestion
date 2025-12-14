-- Inserts missing notes from check tables into main tables.
-- This script is executed after differences are identified.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-12-14
-- Optimized: Changed NOT IN to LEFT JOIN for better performance with large datasets

-- Insert missing notes from check to main tables
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Inserting missing notes from check tables' AS Text;

-- Insert notes that exist in check but not in main
-- Using LEFT JOIN instead of NOT IN for better performance with large datasets
INSERT INTO notes (
  note_id,
  latitude,
  longitude,
  created_at,
  status,
  closed_at
)
SELECT /* Notes-check */
  check_n.note_id,
  check_n.latitude,
  check_n.longitude,
  check_n.created_at,
  check_n.status,
  check_n.closed_at
FROM notes_check check_n
LEFT JOIN notes main_n
  ON check_n.note_id = main_n.note_id
WHERE main_n.note_id IS NULL
ON CONFLICT (note_id) DO UPDATE SET
  latitude = EXCLUDED.latitude,
  longitude = EXCLUDED.longitude,
  created_at = EXCLUDED.created_at,
  status = EXCLUDED.status,
  closed_at = EXCLUDED.closed_at;

-- Show count of inserted notes (using LEFT JOIN for performance)
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty,
  'Inserted missing notes' AS Text
FROM notes_check check_n
LEFT JOIN notes main_n
  ON check_n.note_id = main_n.note_id
WHERE main_n.note_id IS NULL;

-- Update statistics
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Updating notes statistics' AS Text;
ANALYZE notes;

SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Missing notes insertion completed' AS Text;



