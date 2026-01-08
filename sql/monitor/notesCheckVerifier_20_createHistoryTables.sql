-- Creates history tables to track missing comments and text comments
-- before they are inserted. This allows analysis of what was missing
-- and when it was detected.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2026-01-08

-- Table to track missing comments detected by notesCheckVerifier
CREATE TABLE IF NOT EXISTS missing_comments_history (
  id SERIAL PRIMARY KEY,
  note_id INTEGER NOT NULL,
  sequence_action INTEGER NOT NULL,
  event note_event_enum,
  created_at TIMESTAMP,
  id_user INTEGER,
  username VARCHAR(256),
  detected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  inserted_at TIMESTAMP,
  inserted BOOLEAN DEFAULT FALSE,
  UNIQUE (note_id, sequence_action, detected_at)
);
COMMENT ON TABLE missing_comments_history IS
  'History of missing comments detected by notesCheckVerifier before insertion';
COMMENT ON COLUMN missing_comments_history.note_id IS 'OSM note id';
COMMENT ON COLUMN missing_comments_history.sequence_action IS
  'Sequence action of the comment';
COMMENT ON COLUMN missing_comments_history.detected_at IS
  'Timestamp when the missing comment was detected';
COMMENT ON COLUMN missing_comments_history.inserted_at IS
  'Timestamp when the comment was inserted (NULL if not inserted yet)';
COMMENT ON COLUMN missing_comments_history.inserted IS
  'Whether the comment was successfully inserted';

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_missing_comments_history_note_id
  ON missing_comments_history (note_id);
CREATE INDEX IF NOT EXISTS idx_missing_comments_history_detected_at
  ON missing_comments_history (detected_at);
CREATE INDEX IF NOT EXISTS idx_missing_comments_history_inserted
  ON missing_comments_history (inserted);

-- Table to track missing text comments detected by notesCheckVerifier
CREATE TABLE IF NOT EXISTS missing_text_comments_history (
  id SERIAL PRIMARY KEY,
  note_id INTEGER NOT NULL,
  sequence_action INTEGER NOT NULL,
  body TEXT,
  detected_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  inserted_at TIMESTAMP,
  inserted BOOLEAN DEFAULT FALSE,
  UNIQUE (note_id, sequence_action, detected_at)
);
COMMENT ON TABLE missing_text_comments_history IS
  'History of missing text comments detected by notesCheckVerifier before insertion';
COMMENT ON COLUMN missing_text_comments_history.note_id IS 'OSM note id';
COMMENT ON COLUMN missing_text_comments_history.sequence_action IS
  'Sequence action of the text comment';
COMMENT ON COLUMN missing_text_comments_history.detected_at IS
  'Timestamp when the missing text comment was detected';
COMMENT ON COLUMN missing_text_comments_history.inserted_at IS
  'Timestamp when the text comment was inserted (NULL if not inserted yet)';
COMMENT ON COLUMN missing_text_comments_history.inserted IS
  'Whether the text comment was successfully inserted';

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_missing_text_comments_history_note_id
  ON missing_text_comments_history (note_id);
CREATE INDEX IF NOT EXISTS idx_missing_text_comments_history_detected_at
  ON missing_text_comments_history (detected_at);
CREATE INDEX IF NOT EXISTS idx_missing_text_comments_history_inserted
  ON missing_text_comments_history (inserted);
