-- Database initialization script for OSM-Notes-profile tests
-- Author: Andres Gomez (AngocA)
-- Version: 2025-07-27

-- Create test databases
SELECT 'CREATE DATABASE osm_notes_test' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'osm_notes_test')\gexec
SELECT 'CREATE DATABASE osm_notes_wms_test' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'osm_notes_wms_test')\gexec

GRANT ALL PRIVILEGES ON DATABASE osm_notes_test TO testuser;
GRANT ALL PRIVILEGES ON DATABASE osm_notes_wms_test TO testuser;

-- Connect to the main test database and create tables
\c osm_notes_test;

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

-- Connect to WMS test database and set up PostGIS
\c osm_notes_wms_test;

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Create notes table for WMS testing
CREATE TABLE IF NOT EXISTS notes (
    note_id INTEGER PRIMARY KEY,
    created_at TIMESTAMP,
    closed_at TIMESTAMP,
    lon DOUBLE PRECISION,
    lat DOUBLE PRECISION
);

-- Insert test data for WMS
INSERT INTO notes (note_id, created_at, closed_at, lon, lat) VALUES
(1, '2023-01-01 10:00:00', NULL, -74.006, 40.7128),
(2, '2023-02-01 11:00:00', '2023-02-15 12:00:00', -118.2437, 34.0522),
(3, '2023-03-01 09:00:00', NULL, 2.3522, 48.8566)
ON CONFLICT (note_id) DO NOTHING; 