#!/bin/bash
# Test script for processing API notes in Docker
# Version: 2025-07-27

set -euo pipefail

# Load test properties
source /app/tests/properties.sh

# Database configuration for Docker
export TEST_DBNAME="osm_notes_test"
export TEST_DBUSER="testuser"
export TEST_DBPASSWORD="testpass"
export TEST_DBHOST="postgres"
export TEST_DBPORT="5432"

echo "=== Testing API Notes Processing ==="
echo "Database: ${TEST_DBNAME}"
echo "User: ${TEST_DBUSER}"
echo "Host: ${TEST_DBHOST}:${TEST_DBPORT}"
echo ""

# Clean and create test database
echo "🧹 Cleaning database state..."
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" 2> /dev/null || true
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d postgres -c "CREATE DATABASE ${TEST_DBNAME};" 2> /dev/null || true

# Create all database objects in a single persistent connection
echo "📋 Creating database objects in single connection..."
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" << 'EOF'
-- Start transaction
BEGIN;

-- Create ENUM types
CREATE TYPE note_status_enum AS ENUM (
  'open',
  'close',
  'hidden'
);

CREATE TYPE note_event_enum AS ENUM (
 'opened',
 'closed',
 'reopened',
 'commented',
 'hidden'
);

-- Create base tables
CREATE TABLE IF NOT EXISTS users (
 user_id INTEGER NOT NULL PRIMARY KEY,
 username VARCHAR(256) NOT NULL
);

CREATE TABLE IF NOT EXISTS notes (
 id INTEGER NOT NULL,
 note_id INTEGER NOT NULL,
 lat DECIMAL(10,8) NOT NULL,
 lon DECIMAL(11,8) NOT NULL,
 status note_status_enum NOT NULL,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL,
 closed_at TIMESTAMP WITH TIME ZONE,
 id_user INTEGER,
 id_country INTEGER
);

CREATE TABLE IF NOT EXISTS note_comments (
 id INTEGER NOT NULL,
 note_id INTEGER NOT NULL,
 event note_event_enum NOT NULL,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL,
 id_user INTEGER
);

CREATE TABLE IF NOT EXISTS note_comments_text (
 id INTEGER NOT NULL,
 note_id INTEGER NOT NULL,
 event note_event_enum NOT NULL,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL,
 id_user INTEGER,
 text TEXT
);

CREATE TABLE IF NOT EXISTS properties (
 key VARCHAR(32) PRIMARY KEY,
 value TEXT,
 updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS logs (
 id SERIAL PRIMARY KEY,
 message TEXT,
 created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create sequences
CREATE SEQUENCE IF NOT EXISTS note_comments_id_seq;
CREATE SEQUENCE IF NOT EXISTS note_comments_text_id_seq;

-- Create simplified countries table
CREATE TABLE IF NOT EXISTS countries (
  country_id INTEGER PRIMARY KEY,
  name VARCHAR(100),
  americas BOOLEAN DEFAULT FALSE,
  europe BOOLEAN DEFAULT FALSE,
  russia_middle_east BOOLEAN DEFAULT FALSE,
  asia_oceania BOOLEAN DEFAULT FALSE
);

-- Insert test countries
INSERT INTO countries (country_id, name, americas, europe, russia_middle_east, asia_oceania) VALUES
  (1, 'United States', TRUE, FALSE, FALSE, FALSE),
  (2, 'United Kingdom', FALSE, TRUE, FALSE, FALSE),
  (3, 'Germany', FALSE, TRUE, FALSE, FALSE),
  (4, 'Japan', FALSE, FALSE, FALSE, TRUE),
  (5, 'Australia', FALSE, FALSE, FALSE, TRUE)
ON CONFLICT (country_id) DO NOTHING;

-- Create tries table for logging
CREATE TABLE IF NOT EXISTS tries (
  area VARCHAR(20),
  iter INTEGER,
  id_note INTEGER,
  id_country INTEGER
);

-- Create simplified get_country function
CREATE OR REPLACE FUNCTION get_country (
  lon DECIMAL,
  lat DECIMAL,
  id_note INTEGER
) RETURNS INTEGER
LANGUAGE plpgsql
AS $func$
DECLARE
  m_id_country INTEGER;
  m_area VARCHAR(20);
BEGIN
  m_id_country := 1; -- Default to US for testing
  
  -- Simple logic based on longitude for testing
  IF (lon < -30) THEN
    m_area := 'Americas';
    m_id_country := 1; -- US
  ELSIF (lon < 25) THEN
    m_area := 'Europe/Africa';
    m_id_country := 2; -- UK
  ELSIF (lon < 65) THEN
    m_area := 'Russia/Middle east';
    m_id_country := 3; -- Germany
  ELSE
    m_area := 'Asia/Oceania';
    m_id_country := 4; -- Japan
  END IF;
  
  INSERT INTO tries VALUES (m_area, 1, id_note, m_id_country);
  RETURN m_id_country;
END
$func$;

-- Create lock procedures
CREATE OR REPLACE PROCEDURE put_lock (
  m_process_id VARCHAR(32)
)
LANGUAGE plpgsql
AS $proc$
BEGIN
  INSERT INTO properties (key, value, updated_at) VALUES
    ('lock', m_process_id, CURRENT_TIMESTAMP)
  ON CONFLICT (key) DO UPDATE SET
    value = EXCLUDED.value,
    updated_at = CURRENT_TIMESTAMP;
END
$proc$;

CREATE OR REPLACE PROCEDURE remove_lock (
  m_process_id VARCHAR(32)
)
LANGUAGE plpgsql
AS $proc$
BEGIN
  DELETE FROM properties WHERE key = 'lock';
END
$proc$;

-- Create insert procedures
CREATE OR REPLACE PROCEDURE insert_note (
  m_note_id INTEGER,
  m_lat DECIMAL(10,8),
  m_lon DECIMAL(11,8),
  m_status note_status_enum,
  m_created_at TIMESTAMP WITH TIME ZONE,
  m_closed_at TIMESTAMP WITH TIME ZONE,
  m_id_user INTEGER,
  m_username VARCHAR(256),
  m_process_id_bash INTEGER
)
LANGUAGE plpgsql
AS $proc$
DECLARE
  m_process_id_db INTEGER;
  m_id_country INTEGER;
BEGIN
  SELECT value
    INTO m_process_id_db
  FROM properties
  WHERE key = 'lock';
  IF (m_process_id_db IS NULL) THEN
   RAISE EXCEPTION 'This call does not have a lock.';
  ELSIF (m_process_id_bash <> m_process_id_db) THEN
   RAISE EXCEPTION 'The process that holds the lock (%) is different from the current one (%).',
     m_process_id_db, m_process_id_bash;
  END IF;

  INSERT INTO logs (message) VALUES (m_note_id || ' - Inserting note - ' || m_status || '.');

  -- Insert a new username, or update the username to an existing userid.
  IF (m_id_user IS NOT NULL AND m_username IS NOT NULL) THEN
   INSERT INTO users (
    user_id,
    username
   ) VALUES (
    m_id_user,
    m_username
   ) ON CONFLICT (user_id) DO UPDATE
     SET username = EXCLUDED.username;
  END IF;

  m_id_country := get_country(m_lon, m_lat, m_note_id);

  INSERT INTO notes (
   id,
   note_id,
   lat,
   lon,
   status,
   created_at,
   closed_at,
   id_user,
   id_country
  ) VALUES (
   m_note_id,
   m_note_id,
   m_lat,
   m_lon,
   m_status,
   m_created_at,
   m_closed_at,
   m_id_user,
   m_id_country
  );
END
$proc$;

CREATE OR REPLACE PROCEDURE insert_note_comment (
  m_note_id INTEGER,
  m_event note_event_enum,
  m_created_at TIMESTAMP WITH TIME ZONE,
  m_id_user INTEGER,
  m_username VARCHAR(256),
  m_process_id_bash INTEGER
)
LANGUAGE plpgsql
AS $proc$
DECLARE
  m_process_id_db INTEGER;
BEGIN
  SELECT value
    INTO m_process_id_db
  FROM properties
  WHERE key = 'lock';
  IF (m_process_id_db IS NULL) THEN
   RAISE EXCEPTION 'This call does not have a lock.';
  ELSIF (m_process_id_bash <> m_process_id_db) THEN
   RAISE EXCEPTION 'The process that holds the lock (%) is different from the current one (%).',
     m_process_id_db, m_process_id_bash;
  END IF;

  INSERT INTO logs (message) VALUES (m_note_id || ' - Inserting comment - ' || m_event || '.');

  -- Insert a new username, or update the username to an existing userid.
  IF (m_id_user IS NOT NULL AND m_username IS NOT NULL) THEN
   INSERT INTO users (
    user_id,
    username
   ) VALUES (
    m_id_user,
    m_username
   ) ON CONFLICT (user_id) DO UPDATE
     SET username = EXCLUDED.username;
  END IF;

  INSERT INTO note_comments (
   id,
   note_id,
   event,
   created_at,
   id_user
  ) VALUES (
   nextval('note_comments_id_seq'),
   m_note_id,
   m_event,
   m_created_at,
   m_id_user
  );
END
$proc$;

-- Insert initial properties
INSERT INTO properties (key, value) VALUES
  ('initialLoadNotes', 'true'),
  ('initialLoadComments', 'true')
ON CONFLICT (key) DO NOTHING;

-- Commit transaction
COMMIT;

-- Verify ENUM types exist
SELECT 'ENUM types verification:' as status;
SELECT typname, enumlabel 
FROM pg_enum e 
JOIN pg_type t ON e.enumtypid = t.oid 
WHERE t.typname IN ('note_status_enum', 'note_event_enum')
ORDER BY t.typname, e.enumsortorder;

-- Test procedure creation
SELECT 'Procedures verification:' as status;
SELECT proname, prokind 
FROM pg_proc 
WHERE proname IN ('insert_note', 'insert_note_comment', 'put_lock', 'remove_lock')
ORDER BY proname;
EOF

echo "✅ Database objects created successfully"

# Load test data
echo "📋 Loading test data..."
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "\COPY notes FROM '/app/test_output/api_notes.csv' WITH (FORMAT csv, HEADER true);"
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "\COPY note_comments FROM '/app/test_output/api_comments.csv' WITH (FORMAT csv, HEADER true);"
psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "\COPY note_comments_text FROM '/app/test_output/api_text_comments.csv' WITH (FORMAT csv, HEADER true);"

echo "✅ Test data loaded successfully"

# Verify data
echo "📋 Verifying data..."
notes_count=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM notes;" | tr -d ' ')
comments_count=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments;" | tr -d ' ')
text_count=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_text;" | tr -d ' ')

echo "📊 Results:"
echo "  Notes: ${notes_count}"
echo "  Comments: ${comments_count}"
echo "  Text Comments: ${text_count}"

if [ "$notes_count" -gt 0 ] && [ "$comments_count" -gt 0 ] && [ "$text_count" -gt 0 ]; then
 echo "✅ API notes processing test completed successfully"
else
 echo "❌ API notes processing test failed"
 exit 1
fi
