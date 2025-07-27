#!/bin/bash

# Create Test CSV Files for Docker Tests
# Generates proper CSV files with correct note_id values
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-26

set -euo pipefail

# Create test_output directory if it doesn't exist
mkdir -p test_output

echo "Creating test CSV files for Docker tests..."

# Create API notes CSV with correct column order: note_id, latitude, longitude, created_at, closed_at, status, id_country, part_id
cat > test_output/api_notes.csv << 'EOF'
123,40.7128,-74.0060,"2013-04-28T02:39:27Z",,"open",1,1
456,34.0522,-118.2437,"2013-04-30T15:20:45Z","2013-05-01T10:15:30Z","close",1,1
789,51.5074,-0.1278,"2013-05-02T12:00:00Z",,"open",1,1
EOF

# Create API comments CSV: note_id, sequence_action, event, created_at, id_user, username, part_id
cat > test_output/api_comments.csv << 'EOF'
123,1,"opened","2013-04-28T02:39:27Z",123,"user1",1
456,1,"opened","2013-04-30T15:20:45Z",456,"user2",1
456,2,"closed","2013-05-01T10:15:30Z",789,"user3",1
789,1,"opened","2013-05-02T12:00:00Z",123,"user1",1
EOF

# Create API text comments CSV: note_id, sequence_action, body, part_id
cat > test_output/api_text_comments.csv << 'EOF'
123,1,"This is a test comment",1
456,1,"Another test comment",1
456,2,"Closing comment",1
789,1,"Opening comment",1
EOF

# Create Planet notes CSV: note_id, latitude, longitude, created_at, status, closed_at, id_country
cat > test_output/planet_notes.csv << 'EOF'
123,40.7128,-74.0060,"2013-04-28T02:39:27Z","open",,1
456,34.0522,-118.2437,"2013-04-30T15:20:45Z","close","2013-05-01T10:15:30Z",1
789,51.5074,-0.1278,"2013-05-02T12:00:00Z","open",,1
EOF

# Create Planet comments CSV: note_id, sequence_action, event, created_at, id_user, username
cat > test_output/planet_comments.csv << 'EOF'
123,1,"opened","2013-04-28T02:39:27Z",123,"user1"
456,1,"opened","2013-04-30T15:20:45Z",456,"user2"
456,2,"closed","2013-05-01T10:15:30Z",789,"user3"
789,1,"opened","2013-05-02T12:00:00Z",123,"user1"
EOF

# Create Planet text comments CSV: note_id, sequence_action, body
cat > test_output/planet_text_comments.csv << 'EOF'
123,1,"This is a test comment"
456,1,"Another test comment"
456,2,"Closing comment"
789,1,"Opening comment"
EOF

echo "Test CSV files created successfully:"
ls -la test_output/*.csv

echo "CSV file contents:"
echo "=== API Notes ==="
cat test_output/api_notes.csv
echo "=== API Comments ==="
cat test_output/api_comments.csv
echo "=== Planet Notes ==="
cat test_output/planet_notes.csv
echo "=== Planet Comments ==="
cat test_output/planet_comments.csv

echo "Test CSV files creation completed."
