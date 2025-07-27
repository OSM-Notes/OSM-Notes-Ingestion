#!/bin/bash

# Generate Test Data for OSM-Notes-profile
# Creates proper CSV files for testing database operations
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-26

set -euo pipefail

# Load test properties
source "$(dirname "$0")/../properties.sh"

# Create test data directory
mkdir -p mock_data

echo "Generating test CSV files..."

# Generate API notes CSV
cat > mock_data/api_notes.csv << 'EOF'
123,40.7128,-74.0060,"2013-04-28T02:39:27Z","open",,1
456,34.0522,-118.2437,"2013-04-30T15:20:45Z","close","2013-05-01T10:15:30Z",1
789,51.5074,-0.1278,"2013-05-02T12:00:00Z","open",,1
EOF

# Generate API comments CSV
cat > mock_data/api_comments.csv << 'EOF'
123,1,"opened","2013-04-28T02:39:27Z",123,"user1"
456,1,"opened","2013-04-30T15:20:45Z",456,"user2"
456,2,"closed","2013-05-01T10:15:30Z",789,"user3"
789,1,"opened","2013-05-02T12:00:00Z",123,"user1"
EOF

# Generate API text comments CSV
cat > mock_data/api_text_comments.csv << 'EOF'
123,1,"Test comment 1"
456,1,"Test comment 2"
456,2,"Closing this note"
789,1,"Another test comment"
EOF

# Generate Planet notes CSV
cat > mock_data/planet_notes.csv << 'EOF'
123,40.7128,-74.0060,"2013-04-28T02:39:27Z","open",,1
456,34.0522,-118.2437,"2013-04-30T15:20:45Z","close","2013-05-01T10:15:30Z",1
789,51.5074,-0.1278,"2013-05-02T12:00:00Z","open",,1
EOF

# Generate Planet comments CSV
cat > mock_data/planet_comments.csv << 'EOF'
123,1,"opened","2013-04-28T02:39:27Z",123,"user1"
456,1,"opened","2013-04-30T15:20:45Z",456,"user2"
456,2,"closed","2013-05-01T10:15:30Z",789,"user3"
789,1,"opened","2013-05-02T12:00:00Z",123,"user1"
EOF

# Generate Planet text comments CSV
cat > mock_data/planet_text_comments.csv << 'EOF'
123,1,"Test comment 1"
456,1,"Test comment 2"
456,2,"Closing this note"
789,1,"Another test comment"
EOF

echo "Test CSV files generated successfully:"
ls -la mock_data/*.csv

echo "Test data generation completed." 