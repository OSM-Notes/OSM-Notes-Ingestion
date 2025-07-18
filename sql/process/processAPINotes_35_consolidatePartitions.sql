-- Consolidates data from all partitions into a single table.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-18

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Starting consolidation of partitioned data' AS Text;

-- Create consolidated tables (without partitioning)
CREATE TABLE IF NOT EXISTS notes_api_consolidated (
 note_id INTEGER NOT NULL,
 latitude DECIMAL NOT NULL,
 longitude DECIMAL NOT NULL,
 created_at TIMESTAMP NOT NULL,
 closed_at TIMESTAMP,
 status note_status_enum,
 id_country INTEGER
);

CREATE TABLE IF NOT EXISTS note_comments_api_consolidated (
 id SERIAL,
 note_id INTEGER NOT NULL,
 sequence_action INTEGER,
 event note_event_enum NOT NULL,
 processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 created_at TIMESTAMP NOT NULL,
 id_user INTEGER,
 username VARCHAR(256)
);

CREATE TABLE IF NOT EXISTS note_comments_text_api_consolidated (
 id SERIAL,
 note_id INTEGER NOT NULL,
 sequence_action INTEGER,
 processing_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
 body TEXT
);

-- Truncate consolidated tables
TRUNCATE TABLE notes_api_consolidated;
TRUNCATE TABLE note_comments_api_consolidated;
TRUNCATE TABLE note_comments_text_api_consolidated;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Consolidating notes from all partitions' AS Text;

-- Consolidate notes from all partitions
INSERT INTO notes_api_consolidated (note_id, latitude, longitude, created_at, closed_at, status, id_country)
SELECT note_id, latitude, longitude, created_at, closed_at, status, id_country
FROM notes_api
ORDER BY note_id;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Consolidating comments from all partitions' AS Text;

-- Consolidate comments from all partitions
INSERT INTO note_comments_api_consolidated (note_id, sequence_action, event, processing_time, created_at, id_user, username)
SELECT note_id, sequence_action, event, processing_time, created_at, id_user, username
FROM note_comments_api
ORDER BY note_id, id;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Consolidating text comments from all partitions' AS Text;

-- Consolidate text comments from all partitions
INSERT INTO note_comments_text_api_consolidated (note_id, sequence_action, processing_time, body)
SELECT note_id, sequence_action, processing_time, body
FROM note_comments_text_api
ORDER BY note_id, id;

-- Drop partitioned tables and rename consolidated tables
DROP TABLE IF EXISTS notes_api CASCADE;
DROP TABLE IF EXISTS note_comments_api CASCADE;
DROP TABLE IF EXISTS note_comments_text_api CASCADE;

-- Rename consolidated tables to original names
ALTER TABLE notes_api_consolidated RENAME TO notes_api;
ALTER TABLE note_comments_api_consolidated RENAME TO note_comments_api;
ALTER TABLE note_comments_text_api_consolidated RENAME TO note_comments_text_api;

-- Add comments to consolidated tables
COMMENT ON TABLE notes_api IS 'Stores notes downloaded from API call (consolidated from partitions)';
COMMENT ON TABLE note_comments_api IS 'Stores comments downloaded from API call (consolidated from partitions)';
COMMENT ON TABLE note_comments_text_api IS 'Stores all text associated with comment notes (consolidated from partitions)';

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Final statistics on consolidated data' AS Text;

-- Final statistics
ANALYZE notes_api;
ANALYZE note_comments_api;
ANALYZE note_comments_text_api;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Total consolidated notes' AS Text
FROM notes_api;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Total consolidated comments' AS Text
FROM note_comments_api;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 COUNT(1) AS Qty, 'Total consolidated text comments' AS Text
FROM note_comments_text_api;

SELECT /* Notes-processAPI */ clock_timestamp() AS Processing,
 'Consolidation completed successfully' AS Text; 