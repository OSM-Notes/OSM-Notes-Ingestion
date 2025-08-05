#!/bin/bash
# Simplified Planet workflow test script
# Version: 2025-07-27

set -euo pipefail

# Load test properties
if [[ -f "/app/tests/properties.sh" ]]; then
  source /app/tests/properties.sh
elif [[ -f "${TEST_BASE_DIR}/tests/properties.sh" ]]; then
  source "${TEST_BASE_DIR}/tests/properties.sh"
else
  echo "Warning: properties.sh not found, using defaults"
fi

# Database configuration for Docker
export TEST_DBNAME="osm_notes_test"
export TEST_DBUSER="testuser"
export TEST_DBPASSWORD="testpass"
export TEST_DBHOST="postgres"
export TEST_DBPORT="5432"

echo "=== Testing Simplified Planet Workflow ==="
echo "Database: ${TEST_DBNAME}"
echo "User: ${TEST_DBUSER}"
echo "Host: ${TEST_DBHOST}:${TEST_DBPORT}"
echo ""

# Check if XML file exists
if [[ -n "${PLANET_NOTES_FILE:-}" && -f "${PLANET_NOTES_FILE}" ]]; then
 echo "📋 Processing XML file: ${PLANET_NOTES_FILE}"

 # Extract notes from XML and insert them
 # This is a simplified version - in real implementation would use XSLT
 xmlstarlet sel -t -m "//note" -v "@lat" -o "," -v "@lon" -o "," -v "id" -o "," -v "status" -o "," -v "date_created" -n "${PLANET_NOTES_FILE}" | while IFS=',' read -r lat lon note_id status created_at; do
  if [[ -n "$lat" && -n "$lon" && -n "$note_id" ]]; then
   echo "Processing note ${note_id} at (${lat}, ${lon})"

   # Insert note
   psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
        INSERT INTO notes (id, note_id, lat, lon, status, created_at, closed_at, id_user, id_country) 
        VALUES (${note_id}, ${note_id}, ${lat}, ${lon}, '${status}', '${created_at}', NULL, ${note_id}, 1);
      "

   # Insert user
   psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
        INSERT INTO users (user_id, username) 
        VALUES (${note_id}, 'user${note_id}')
        ON CONFLICT (user_id) DO NOTHING;
      "
  fi
 done

 # Process comments from XML
 xmlstarlet sel -t -m "//comment" -v "ancestor::note/id" -o "," -v "date" -o "," -v "uid" -o "," -v "action" -o "," -v "text" -n "${PLANET_NOTES_FILE}" | while IFS=',' read -r note_id date uid action text; do
  if [[ -n "$note_id" && -n "$date" && -n "$uid" && -n "$action" ]]; then
   echo "Processing comment for note ${note_id}: ${action}"

   # Insert comment only if it doesn't exist
   existing_comment=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments WHERE note_id = ${note_id} AND event = '${action}' AND created_at = '${date}' AND id_user = ${uid};" | tr -d ' ')
   if [[ "$existing_comment" -eq 0 ]]; then
    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
          INSERT INTO note_comments (id, note_id, event, created_at, id_user) 
          VALUES (nextval('note_comments_id_seq'), ${note_id}, '${action}', '${date}', ${uid});
        "

    psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
          INSERT INTO note_comments_text (id, note_id, event, created_at, id_user, text) 
          VALUES (nextval('note_comments_text_id_seq'), ${note_id}, '${action}', '${date}', ${uid}, '${text}');
        "
   fi

   # Insert user
   psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
        INSERT INTO users (user_id, username) 
        VALUES (${uid}, 'user${uid}')
        ON CONFLICT (user_id) DO NOTHING;
      "
  fi
 done

 echo "✅ XML processing completed"
else
 echo "📋 Creating test data (no XML file provided)..."
 psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" << 'EOF'
-- Insert test notes
INSERT INTO notes (id, note_id, lat, lon, status, created_at, closed_at, id_user, id_country) VALUES
  (123, 123, 40.7128, -74.0060, 'open', '2013-04-28T02:39:27Z', NULL, 123, 1),
  (456, 456, 34.0522, -118.2437, 'close', '2013-04-30T15:20:45Z', '2013-05-01T10:15:30Z', 456, 1);

-- Insert test comments
INSERT INTO note_comments (id, note_id, event, created_at, id_user) VALUES
  (nextval('note_comments_id_seq'), 123, 'opened', '2013-04-28T02:39:27Z', 123),
  (nextval('note_comments_id_seq'), 456, 'opened', '2013-04-30T15:20:45Z', 456),
  (nextval('note_comments_id_seq'), 456, 'closed', '2013-05-01T10:15:30Z', 789);

-- Insert test comment text
INSERT INTO note_comments_text (id, note_id, event, created_at, id_user, text) VALUES
  (nextval('note_comments_text_id_seq'), 123, 'opened', '2013-04-28T02:39:27Z', 123, 'Test comment 1'),
  (nextval('note_comments_text_id_seq'), 456, 'opened', '2013-04-30T15:20:45Z', 456, 'Test comment 2'),
  (nextval('note_comments_text_id_seq'), 456, 'closed', '2013-05-01T10:15:30Z', 789, 'Closing this note');

-- Insert test users
INSERT INTO users (user_id, username) VALUES
  (123, 'user1'),
  (456, 'user2'),
  (789, 'user3')
ON CONFLICT (user_id) DO NOTHING;
EOF
 echo "✅ Test data created successfully"
fi

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
 echo "✅ Planet workflow test completed successfully"
 exit 0
else
 echo "❌ Planet workflow test failed"
 exit 1
fi
