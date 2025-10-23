-- Create API tables with partitioning for parallel processing.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-22

-- Create partitioned table for notes_api
CREATE TABLE notes_api (
 note_id INTEGER NOT NULL,
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 closed_at TIMESTAMP,
 status note_status_enum,
 id_country INTEGER,
 part_id INTEGER NOT NULL
) PARTITION BY RANGE (part_id);

-- Create partitions for notes_api dynamically based on MAX_THREADS
-- This will be handled by the application logic

COMMENT ON TABLE notes_api IS 'Stores notes downloaded from API call with partitioning for parallel processing';
COMMENT ON COLUMN notes_api.note_id IS 'OSM note id';
COMMENT ON COLUMN notes_api.latitude IS 'Latitude';
COMMENT ON COLUMN notes_api.longitude IS 'Longitude';
COMMENT ON COLUMN notes_api.created_at IS
  'Timestamp of the creation of the note';
COMMENT ON COLUMN notes_api.status IS
  'Current status of the note (opened, closed; hidden is not possible)';
COMMENT ON COLUMN notes_api.closed_at IS 'Timestamp when the note was closed';
COMMENT ON COLUMN notes_api.id_country IS
  'Country id where the note is located';
COMMENT ON COLUMN notes_api.part_id IS
  'Partition ID for parallel processing';

-- Create partitioned table for note_comments_api
CREATE TABLE note_comments_api (
 id SERIAL,
 note_id INTEGER NOT NULL,
 sequence_action INTEGER,
 event note_event_enum NOT NULL,
 processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 created_at TIMESTAMP NOT NULL,
 id_user INTEGER,
 username VARCHAR(256),
 part_id INTEGER NOT NULL
) PARTITION BY RANGE (part_id);

-- Create partitions for note_comments_api dynamically based on MAX_THREADS
-- This will be handled by the application logic

COMMENT ON TABLE note_comments_api IS
  'Stores comments downloaded from API call with partitioning for parallel processing.';
COMMENT ON COLUMN note_comments_api.id IS
  'Generated ID to keep track of the comments order';
COMMENT ON COLUMN note_comments_api.note_id IS
  'Id of the associated note of this comment';
COMMENT ON COLUMN note_comments_api.sequence_action IS
  'Comment sequence generated from this tool';
COMMENT ON COLUMN note_comments_api.event IS
  'Type of action was performed on the note';
COMMENT ON COLUMN note_comments_api.processing_time IS
  'Registers when this comment was inserted in the database. Automatic value';
COMMENT ON COLUMN note_comments_api.created_at IS
  'Timestamps when the comment/action was done';
COMMENT ON COLUMN note_comments_api.id_user IS
  'OSM id of the user who performed the action';
COMMENT ON COLUMN note_comments_api.part_id IS
  'Partition ID for parallel processing';

-- Create partitioned table for note_comments_text_api
CREATE TABLE IF NOT EXISTS note_comments_text_api (
 id SERIAL,
 note_id INTEGER NOT NULL,
 sequence_action INTEGER,
 processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 body TEXT,
 part_id INTEGER NOT NULL
) PARTITION BY RANGE (part_id);

-- Create partitions for note_comments_text_api dynamically based on MAX_THREADS
-- This will be handled by the application logic

COMMENT ON TABLE note_comments_text_api IS
  'Stores all text associated with comment notes with partitioning for parallel processing';
COMMENT ON COLUMN note_comments_text_api.id IS
  'ID of the comment. Same value from the other table';
COMMENT ON COLUMN note_comments_text_api.note_id IS
  'OSM Note Id associated to this comment';
COMMENT ON COLUMN note_comments_text_api.sequence_action IS
  'Comment sequence, first is open, then any action in the creation order';
COMMENT ON COLUMN note_comments_text_api.processing_time IS
  'Registers when this comment was inserted in the database. Automatic value';
COMMENT ON COLUMN note_comments_text_api.body IS
  'Text of the note comment';
COMMENT ON COLUMN note_comments_text_api.part_id IS
  'Partition ID for parallel processing';

-- Create table for tracking data gaps
CREATE TABLE IF NOT EXISTS data_gaps (
  id SERIAL PRIMARY KEY,
  gap_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  gap_type VARCHAR(50) NOT NULL,
  gap_count INTEGER NOT NULL,
  total_count INTEGER NOT NULL,
  gap_percentage DECIMAL(5,2) NOT NULL,
  notes_without_comments TEXT,
  error_details TEXT,
  processed BOOLEAN DEFAULT FALSE,
  processed_at TIMESTAMP
);

COMMENT ON TABLE data_gaps IS 'Tracks data integrity gaps detected during processing';
COMMENT ON COLUMN data_gaps.gap_timestamp IS 'When the gap was detected';
COMMENT ON COLUMN data_gaps.gap_type IS 'Type of gap: notes_without_comments, comments_without_text, etc.';
COMMENT ON COLUMN data_gaps.gap_count IS 'Number of items with gaps';
COMMENT ON COLUMN data_gaps.total_count IS 'Total number of items processed';
COMMENT ON COLUMN data_gaps.gap_percentage IS 'Percentage of items with gaps';
COMMENT ON COLUMN data_gaps.notes_without_comments IS 'List of note_ids without comments (JSON array)';
COMMENT ON COLUMN data_gaps.error_details IS 'Details about the errors that caused gaps';
COMMENT ON COLUMN data_gaps.processed IS 'Whether this gap has been addressed';
COMMENT ON COLUMN data_gaps.processed_at IS 'When this gap was marked as processed';
