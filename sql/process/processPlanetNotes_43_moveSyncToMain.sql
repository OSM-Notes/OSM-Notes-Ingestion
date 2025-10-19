-- Moves data from sync tables to main tables after consolidation.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-19

-- Move notes from sync to main tables
SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 'Moving notes from sync to main tables' AS Text;

INSERT INTO notes (note_id, latitude, longitude, created_at, status, closed_at, id_country)
SELECT note_id, latitude, longitude, created_at, status, closed_at, id_country
FROM notes_sync
ON CONFLICT (note_id) DO UPDATE SET
 latitude = EXCLUDED.latitude,
 longitude = EXCLUDED.longitude,
 created_at = EXCLUDED.created_at,
 status = EXCLUDED.status,
 closed_at = EXCLUDED.closed_at,
 id_country = EXCLUDED.id_country;

SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty,
 'Moved notes to main table' AS Text
FROM notes_sync;

-- Insert missing users first
SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 'Inserting missing users' AS Text;

INSERT INTO users (user_id, username)
SELECT id_user, MIN(username) AS username
FROM note_comments_sync
WHERE id_user IS NOT NULL
  AND username IS NOT NULL
  AND id_user NOT IN (SELECT user_id FROM users)
GROUP BY id_user
ON CONFLICT (user_id) DO UPDATE SET
 username = EXCLUDED.username;

-- Move comments from sync to main tables
SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 'Moving comments from sync to main tables' AS Text;

INSERT INTO note_comments (id, note_id, sequence_action, event, created_at, id_user)
SELECT id, note_id, sequence_action, event, created_at, id_user
FROM note_comments_sync
WHERE id_user IS NULL OR id_user IN (SELECT user_id FROM users)
ON CONFLICT (id) DO UPDATE SET
 note_id = EXCLUDED.note_id,
 sequence_action = EXCLUDED.sequence_action,
 event = EXCLUDED.event,
 created_at = EXCLUDED.created_at,
 id_user = EXCLUDED.id_user;

SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty,
 'Moved comments to main table' AS Text
FROM note_comments_sync;

-- Move text comments from sync to main tables
SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 'Moving text comments from sync to main tables' AS Text;

INSERT INTO note_comments_text (id, note_id, sequence_action, body)
SELECT id, note_id, sequence_action, body
FROM note_comments_text_sync
ON CONFLICT (id) DO UPDATE SET
 note_id = EXCLUDED.note_id,
 sequence_action = EXCLUDED.sequence_action,
 body = EXCLUDED.body;

SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty,
 'Moved text comments to main table' AS Text
FROM note_comments_text_sync;

-- Update statistics on main tables
ANALYZE notes;
ANALYZE note_comments;
ANALYZE note_comments_text;

SELECT /* Notes-processPlanet */ clock_timestamp() AS Processing,
 'Data movement from sync to main tables completed' AS Text; 