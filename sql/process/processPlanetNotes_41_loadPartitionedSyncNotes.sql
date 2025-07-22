-- Loads partitioned sync notes from CSV files into the database.
-- This script is designed for parallel processing of Planet notes.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-20

-- Load notes into partitioned table
COPY notes_sync_part_${PART_ID} (note_id, latitude, longitude, created_at, status, closed_at, 
                id_country, part_id) 
FROM '${OUTPUT_NOTES_PART}' 
WITH (FORMAT csv, DELIMITER ',', QUOTE '"', ENCODING 'UTF8');

-- Update part_id to correct partition number
UPDATE notes_sync_part_${PART_ID} SET part_id = ${PART_ID} WHERE part_id IS NULL;

-- Load comments into partitioned table
COPY note_comments_sync_part_${PART_ID} (note_id, event, created_at, id_user, 
                        username, part_id) 
FROM '${OUTPUT_COMMENTS_PART}' 
WITH (FORMAT csv, DELIMITER ',', QUOTE '"', ENCODING 'UTF8');

-- Update part_id to correct partition number for comments
UPDATE note_comments_sync_part_${PART_ID} SET part_id = ${PART_ID} WHERE part_id IS NULL;

-- Load text comments into partitioned table
COPY note_comments_text_sync_part_${PART_ID} (note_id, sequence_action, body, part_id) 
FROM '${OUTPUT_TEXT_PART}' 
WITH (FORMAT csv, DELIMITER ',', QUOTE '"', ENCODING 'UTF8');

-- Update part_id to correct partition number for text comments
UPDATE note_comments_text_sync_part_${PART_ID} SET part_id = ${PART_ID} WHERE part_id IS NULL; 