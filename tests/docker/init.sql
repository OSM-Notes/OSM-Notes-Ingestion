-- Database initialization script for OSM-Notes-profile tests
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-24
-- Note: The database osm_notes_test is already created by Docker via POSTGRES_DB env var

-- Create basic tables for testing
CREATE TABLE IF NOT EXISTS test_notes (
    id SERIAL PRIMARY KEY,
    note_id BIGINT NOT NULL,
    lat DECIMAL(10,8),
    lon DECIMAL(11,8),
    status VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS test_comments (
    id SERIAL PRIMARY KEY,
    note_id BIGINT NOT NULL,
    user_id BIGINT,
    username VARCHAR(255),
    action VARCHAR(50),
    text TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_test_notes_note_id ON test_notes(note_id);
CREATE INDEX IF NOT EXISTS idx_test_comments_note_id ON test_comments(note_id);

-- Insert some test data
INSERT INTO test_notes (note_id, lat, lon, status) VALUES 
(123, 40.7128, -74.0060, 'open'),
(456, 34.0522, -118.2437, 'closed'),
(789, 51.5074, -0.1278, 'open')
ON CONFLICT DO NOTHING;

INSERT INTO test_comments (note_id, user_id, username, action, text) VALUES 
(123, 123, 'user1', 'opened', 'Test comment 1'),
(456, 456, 'user2', 'opened', 'Test comment 2'),
(456, 789, 'user3', 'closed', 'Closing this note')
ON CONFLICT DO NOTHING;

-- Note: WMS database setup is handled by setup_test_db_docker.sh 