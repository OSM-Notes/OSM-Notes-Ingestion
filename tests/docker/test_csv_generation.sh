#!/bin/bash

# Test CSV Generation for OSM-Notes-profile
# Tests XSLT transformations to ensure proper CSV generation
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-26

set -euo pipefail

# Load test properties
source "$(dirname "$0")/../properties.sh"

# Create test output directory
mkdir -p test_output

echo "Testing CSV generation with XSLT transformations..."

# Create a simple test XML file
cat > test_output/test_planet.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="123" lat="40.7128" lon="-74.0060" created_at="2013-04-28T02:39:27Z">
    <comment uid="123" user="user1" action="opened" timestamp="2013-04-28T02:39:27Z">Test comment 1</comment>
  </note>
  <note id="456" lat="34.0522" lon="-118.2437" created_at="2013-04-30T15:20:45Z" closed_at="2013-05-01T10:15:30Z">
    <comment uid="456" user="user2" action="opened" timestamp="2013-04-30T15:20:45Z">Test comment 2</comment>
    <comment uid="789" user="user3" action="closed" timestamp="2013-05-01T10:15:30Z">Closing this note</comment>
  </note>
</osm-notes>
EOF

# Test Planet notes transformation
echo "Testing Planet notes transformation..."
xsltproc ../../xslt/notes-Planet-csv.xslt test_output/test_planet.xml > test_output/planet_notes_test.csv

echo "Planet notes CSV generated:"
cat test_output/planet_notes_test.csv

# Test Planet comments transformation
echo "Testing Planet comments transformation..."
xsltproc ../../xslt/note_comments-Planet-csv.xslt test_output/test_planet.xml > test_output/planet_comments_test.csv

echo "Planet comments CSV generated:"
cat test_output/planet_comments_test.csv

# Test Planet text comments transformation
echo "Testing Planet text comments transformation..."
xsltproc ../../xslt/note_comments_text-Planet-csv.xslt test_output/test_planet.xml > test_output/planet_text_comments_test.csv

echo "Planet text comments CSV generated:"
cat test_output/planet_text_comments_test.csv

# Verify that note_id values are not null
echo "Verifying note_id values..."
if grep -q "^," test_output/planet_notes_test.csv; then
 echo "ERROR: Found null note_id values in planet notes CSV"
 exit 1
else
 echo "SUCCESS: All note_id values are properly set in planet notes CSV"
fi

if grep -q "^," test_output/planet_comments_test.csv; then
 echo "ERROR: Found null note_id values in planet comments CSV"
 exit 1
else
 echo "SUCCESS: All note_id values are properly set in planet comments CSV"
fi

echo "CSV generation test completed successfully." 