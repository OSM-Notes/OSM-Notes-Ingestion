-- Simple monitoring test SQL script
-- This script generates reports comparing notes from Planet vs API

-- Latest note information
\copy (SELECT /* Notes-check */ * FROM notes WHERE note_id = (SELECT /* Notes-check */ MAX(note_id) FROM notes) ORDER BY created_at) TO '/tmp/lastNote.csv' WITH DELIMITER ',' CSV HEADER;

-- Latest comment information
\copy (SELECT /* Notes-check */ * FROM note_comments WHERE note_id = (SELECT /* Notes-check */ MAX(note_id) FROM notes) ORDER BY sequence_action) TO '/tmp/lastCommentNote.csv' WITH DELIMITER ',' CSV HEADER;

-- Note ids that are not in the API DB, but are in the Planet
DROP TABLE IF EXISTS temp_diff_notes_id;

CREATE TABLE temp_diff_notes_id (
 note_id INTEGER
);

INSERT INTO temp_diff_notes_id
 SELECT /* Notes-check */ note_id
 FROM notes_check
 EXCEPT
 SELECT /* Notes-check */ note_id
 FROM notes;

\copy (SELECT /* Notes-check */ notes_check.* FROM notes_check WHERE note_id IN (SELECT /* Notes-check */ note_id FROM temp_diff_notes_id) ORDER BY note_id, created_at) TO '/tmp/differentNoteIds.csv' WITH DELIMITER ',' CSV HEADER;

DROP TABLE IF EXISTS temp_diff_notes_id;

-- Comment notes id that are not in the API DB, but are in the Planet
DROP TABLE IF EXISTS temp_diff_comments_id;

CREATE TABLE temp_diff_comments_id (
 note_id INTEGER
);

INSERT INTO temp_diff_comments_id
 SELECT /* Notes-check */ note_id
 FROM note_comments_check
 EXCEPT
 SELECT /* Notes-check */ note_id
 FROM note_comments;

\copy (SELECT /* Notes-check */ note_comments_check.* FROM note_comments_check WHERE note_id IN (SELECT /* Notes-check */ note_id FROM temp_diff_comments_id) ORDER BY note_id, created_at) TO '/tmp/differentNoteCommentIds.csv' WITH DELIMITER ',' CSV HEADER;

DROP TABLE IF EXISTS temp_diff_comments_id;

-- Notes differences between the retrieved from API and the Planet
DROP TABLE IF EXISTS temp_diff_notes;

CREATE TABLE temp_diff_notes (
 note_id INTEGER
);

INSERT INTO temp_diff_notes
 SELECT /* Notes-check */ note_id
 FROM (
  SELECT /* Notes-check */ note_id, latitude, longitude, created_at, status, id_country
  FROM notes_check
  EXCEPT
  SELECT /* Notes-check */ note_id, latitude, longitude, created_at, status, id_country
  FROM notes
 ) AS t
 ORDER BY note_id, created_at;

\copy (SELECT /* Notes-check */ * FROM (SELECT /* Notes-check */ 'Planet' AS source, note_id, latitude, longitude, created_at, status, id_country FROM notes_check WHERE note_id IN (SELECT /* Notes-check */ note_id FROM temp_diff_notes) UNION SELECT /* Notes-check */ 'API   ' AS source, note_id, latitude, longitude, created_at, status, id_country FROM notes WHERE note_id IN (SELECT /* Notes-check */ note_id FROM temp_diff_notes)) AS T ORDER BY note_id, created_at, source) TO '/tmp/differentNotes.csv' WITH DELIMITER ',' CSV HEADER;

DROP TABLE IF EXISTS temp_diff_notes;

-- Comment differences between the retrieved from API and the Planet
DROP TABLE IF EXISTS temp_diff_note_comments;

CREATE TABLE temp_diff_note_comments (
 note_id INTEGER
);

INSERT INTO temp_diff_note_comments
 SELECT /* Notes-check */ note_id
 FROM (
  SELECT /* Notes-check */ note_id, sequence_action, event, created_at, id_user
  FROM note_comments_check
  EXCEPT
  SELECT /* Notes-check */ note_id, sequence_action, event, created_at, id_user
  FROM note_comments
 ) AS t
 ORDER BY note_id, sequence_action;

\copy (SELECT /* Notes-check */ * FROM (SELECT /* Notes-check */ 'Planet' AS source, note_id, sequence_action, event, created_at, id_user FROM note_comments_check WHERE note_id IN (SELECT /* Notes-check */ note_id FROM temp_diff_note_comments) UNION SELECT /* Notes-check */ 'API   ' AS source, note_id, sequence_action, event, created_at, id_user FROM note_comments WHERE note_id IN (SELECT /* Notes-check */ note_id FROM temp_diff_note_comments)) AS T ORDER BY note_id, sequence_action, source) TO '/tmp/differentNoteComments.csv' WITH DELIMITER ',' CSV HEADER;

DROP TABLE IF EXISTS temp_diff_note_comments;

-- Text comment differences between the retrieved from API and the Planet
DROP TABLE IF EXISTS temp_diff_text_comments;

CREATE TABLE temp_diff_text_comments (
 note_id INTEGER
);

INSERT INTO temp_diff_text_comments
 SELECT /* Notes-check */ note_id
 FROM (
  SELECT /* Notes-check */ note_id, sequence_action, body
  FROM note_comments_text_check
  EXCEPT
  SELECT /* Notes-check */ note_id, sequence_action, body
  FROM note_comments_text
 ) AS t
 ORDER BY note_id, sequence_action;

\copy (SELECT /* Notes-check */ * FROM (SELECT /* Notes-check */ 'Planet' AS source, note_id, sequence_action, body FROM note_comments_text_check WHERE note_id IN (SELECT /* Notes-check */ note_id FROM temp_diff_text_comments) UNION SELECT /* Notes-check */ 'API   ' AS source, note_id, sequence_action, body FROM note_comments_text WHERE note_id IN (SELECT /* Notes-check */ note_id FROM temp_diff_text_comments)) AS T ORDER BY note_id, sequence_action, source) TO '/tmp/differentTextComments.csv' WITH DELIMITER ',' CSV HEADER;

DROP TABLE IF EXISTS temp_diff_text_comments; 