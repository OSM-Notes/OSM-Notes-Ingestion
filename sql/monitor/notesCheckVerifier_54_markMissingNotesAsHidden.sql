-- Marks notes as hidden that exist in main table but not in check table.
-- These are notes that were created before the initial planet dump used to
-- populate the database, and were later hidden by the Data Working Group.
-- Since hidden notes don't appear in planet dumps, they exist in our system
-- but not in the planet.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-01-23

-- Mark missing notes as hidden
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Marking notes as hidden that are not in planet' AS Text;

-- Update notes that exist in main but not in check
-- Only update notes that are not already hidden
-- Using EXCEPT to find notes that are in main but not in check table
UPDATE notes main_n
SET status = 'hidden',
  closed_at = COALESCE(main_n.closed_at, CURRENT_TIMESTAMP),
  update_time = CURRENT_TIMESTAMP
FROM (
  SELECT /* Notes-check */ note_id
  FROM notes
  WHERE DATE(created_at) < CURRENT_DATE  -- All history except today
    AND status != 'hidden'  -- Only update notes that are not already hidden
  EXCEPT
  SELECT /* Notes-check */ note_id
  FROM notes_check
  WHERE DATE(created_at) < CURRENT_DATE  -- All history except today
) AS missing_notes
WHERE main_n.note_id = missing_notes.note_id;

-- Show count of updated notes
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  COUNT(1) AS Qty,
  'Notes marked as hidden (not in planet)' AS Text
FROM notes main_n
WHERE DATE(main_n.created_at) < CURRENT_DATE
  AND main_n.status = 'hidden'
  AND NOT EXISTS (
    SELECT 1
    FROM notes_check check_n
    WHERE check_n.note_id = main_n.note_id
      AND DATE(check_n.created_at) < CURRENT_DATE
  );

-- Update statistics
SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Updating notes statistics' AS Text;
ANALYZE notes;

SELECT /* Notes-check */ clock_timestamp() AS Processing,
  'Missing notes marking as hidden completed' AS Text;

