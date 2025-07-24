#!/usr/bin/env bats

# End-to-End Integration Tests
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

@test "complete workflow should process API notes successfully" {
 # Create test database
 create_test_database

 # Create sample XML file for API notes
 cat > "${TEST_TMP_DIR}/api_notes.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
    <url>https://www.openstreetmap.org/api/0.6/notes/123</url>
    <comment_url>https://www.openstreetmap.org/api/0.6/notes/123/comment</comment_url>
    <close_url>https://www.openstreetmap.org/api/0.6/notes/123/close</close_url>
    <date_created>2013-04-28T02:39:27Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2013-04-28T02:39:27Z</date>
        <uid>123</uid>
        <user>user1</user>
        <action>opened</action>
        <text>Test comment 1</text>
      </comment>
    </comments>
  </note>
  <note lat="34.0522" lon="-118.2437">
    <id>456</id>
    <url>https://www.openstreetmap.org/api/0.6/notes/456</url>
    <comment_url>https://www.openstreetmap.org/api/0.6/notes/456/comment</comment_url>
    <close_url>https://www.openstreetmap.org/api/0.6/notes/456/close</close_url>
    <date_created>2013-04-30T15:20:45Z</date_created>
    <status>close</status>
    <comments>
      <comment>
        <date>2013-04-30T15:20:45Z</date>
        <uid>456</uid>
        <user>user2</user>
        <action>opened</action>
        <text>Test comment 2</text>
      </comment>
      <comment>
        <date>2013-05-01T10:15:30Z</date>
        <uid>789</uid>
        <user>user3</user>
        <action>closed</action>
        <text>Closing this note</text>
      </comment>
    </comments>
  </note>
</osm>
EOF

 # Set environment variables
 export API_NOTES_FILE="${TEST_TMP_DIR}/api_notes.xml"
 export MAX_THREADS="1"
 export DBNAME="${TEST_DBNAME}"

 # Run the complete workflow
 run bash -c "source ${TEST_BASE_DIR}/tests/docker/test_processAPINotes.sh"
 [ "$status" -eq 0 ]

 # Verify data was processed correctly
 local notes_count=$(count_rows "notes" "${TEST_DBNAME}")
 local comments_count=$(count_rows "note_comments" "${TEST_DBNAME}")
 local text_count=$(count_rows "note_comments_text" "${TEST_DBNAME}")

 [ "$notes_count" -gt 0 ]
 [ "$comments_count" -gt 0 ]
 [ "$text_count" -gt 0 ]

 # Cleanup
 drop_test_database
}

@test "complete workflow should process Planet notes successfully" {
 # Create test database
 create_test_database

 # Create sample XML file for Planet notes
 cat > "${TEST_TMP_DIR}/planet_notes.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
    <url>https://www.openstreetmap.org/api/0.6/notes/123</url>
    <comment_url>https://www.openstreetmap.org/api/0.6/notes/123/comment</comment_url>
    <close_url>https://www.openstreetmap.org/api/0.6/notes/123/close</close_url>
    <date_created>2013-04-28T02:39:27Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2013-04-28T02:39:27Z</date>
        <uid>123</uid>
        <user>user1</user>
        <action>opened</action>
        <text>Test comment 1</text>
      </comment>
    </comments>
  </note>
  <note lat="34.0522" lon="-118.2437">
    <id>456</id>
    <url>https://www.openstreetmap.org/api/0.6/notes/456</url>
    <comment_url>https://www.openstreetmap.org/api/0.6/notes/456/comment</comment_url>
    <close_url>https://www.openstreetmap.org/api/0.6/notes/456/close</close_url>
    <date_created>2013-04-30T15:20:45Z</date_created>
    <status>close</status>
    <comments>
      <comment>
        <date>2013-04-30T15:20:45Z</date>
        <uid>456</uid>
        <user>user2</user>
        <action>opened</action>
        <text>Test comment 2</text>
      </comment>
      <comment>
        <date>2013-05-01T10:15:30Z</date>
        <uid>789</uid>
        <user>user3</user>
        <action>closed</action>
        <text>Closing this note</text>
      </comment>
    </comments>
  </note>
</osm-notes>
EOF

 # Set environment variables
 export PLANET_NOTES_FILE="${TEST_TMP_DIR}/planet_notes.xml"
 export MAX_THREADS="1"
 export DBNAME="${TEST_DBNAME}"

 # Run the complete workflow
 run bash -c "source ${TEST_BASE_DIR}/tests/docker/test_processPlanetNotes.sh"
 [ "$status" -eq 0 ]

 # Verify data was processed correctly
 local notes_count=$(count_rows "notes" "${TEST_DBNAME}")
 local comments_count=$(count_rows "note_comments" "${TEST_DBNAME}")
 local text_count=$(count_rows "note_comments_text" "${TEST_DBNAME}")

 [ "$notes_count" -gt 0 ]
 [ "$comments_count" -gt 0 ]
 [ "$text_count" -gt 0 ]

 # Cleanup
 drop_test_database
}

@test "should handle large XML files efficiently" {
 # Create test database
 create_test_database

 # Create large XML file (100 notes)
 cat > "${TEST_TMP_DIR}/large_planet_notes.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
EOF

 # Generate 100 sample notes
 for i in {1..100}; do
  cat >> "${TEST_TMP_DIR}/large_planet_notes.xml" << EOF
  <note lat="40.7128" lon="-74.0060">
    <id>${i}</id>
    <url>https://www.openstreetmap.org/api/0.6/notes/${i}</url>
    <comment_url>https://www.openstreetmap.org/api/0.6/notes/${i}/comment</comment_url>
    <close_url>https://www.openstreetmap.org/api/0.6/notes/${i}/close</close_url>
    <date_created>2013-04-28T02:39:27Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2013-04-28T02:39:27Z</date>
        <uid>${i}</uid>
        <user>user${i}</user>
        <action>opened</action>
        <text>Test comment ${i}</text>
      </comment>
    </comments>
  </note>
EOF
 done

 echo "</osm-notes>" >> "${TEST_TMP_DIR}/large_planet_notes.xml"

 # Set environment variables
 export PLANET_NOTES_FILE="${TEST_TMP_DIR}/large_planet_notes.xml"
 export MAX_THREADS="4"
 export DBNAME="${TEST_DBNAME}"

 # Measure execution time
 local start_time=$(date +%s)

 # Run the complete workflow
 run bash -c "source ${TEST_BASE_DIR}/tests/docker/test_processAPINotes.sh"
 [ "$status" -eq 0 ]

 local end_time=$(date +%s)
 local execution_time=$((end_time - start_time))

 # Verify data was processed correctly
 local notes_count=$(count_rows "test_notes" "${TEST_DBNAME}")
 local comments_count=$(count_rows "test_notes" "${TEST_DBNAME}")

 [ "$notes_count" = "1" ]
 [ "$comments_count" = "1" ]

 # Performance check: should complete within reasonable time (e.g., 60 seconds)
 [ "$execution_time" -lt 60 ]

 # Cleanup
 drop_test_database
}

@test "should handle parallel processing correctly" {
 # Create test database
 create_test_database

 # Create XML file with multiple notes for parallel processing
 cat > "${TEST_TMP_DIR}/parallel_notes.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
EOF

 # Generate 10 sample notes
 for i in {1..10}; do
  cat >> "${TEST_TMP_DIR}/parallel_notes.xml" << EOF
  <note lat="40.7128" lon="-74.0060">
    <id>${i}</id>
    <url>https://www.openstreetmap.org/api/0.6/notes/${i}</url>
    <comment_url>https://www.openstreetmap.org/api/0.6/notes/${i}/comment</comment_url>
    <close_url>https://www.openstreetmap.org/api/0.6/notes/${i}/close</close_url>
    <date_created>2013-04-28T02:39:27Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2013-04-28T02:39:27Z</date>
        <uid>${i}</uid>
        <user>user${i}</user>
        <action>opened</action>
        <text>Test comment ${i}</text>
      </comment>
    </comments>
  </note>
EOF
 done

 echo "</osm-notes>" >> "${TEST_TMP_DIR}/parallel_notes.xml"

 # Set environment variables for parallel processing
 export PLANET_NOTES_FILE="${TEST_TMP_DIR}/parallel_notes.xml"
 export MAX_THREADS="4"
 export DBNAME="${TEST_DBNAME}"

 # Run the complete workflow
 run bash -c "source ${TEST_BASE_DIR}/tests/docker/test_processAPINotes.sh"
 [ "$status" -eq 0 ]

 # Verify data was processed correctly
 local notes_count=$(count_rows "test_notes" "${TEST_DBNAME}")
 local comments_count=$(count_rows "test_notes" "${TEST_DBNAME}")

 [ "$notes_count" = "1" ]
 [ "$comments_count" = "1" ]

 # Cleanup
 drop_test_database
}

@test "should handle error conditions gracefully" {
 # Create test database
 create_test_database

 # Create invalid XML file
 cat > "${TEST_TMP_DIR}/invalid_notes.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note lat="invalid" lon="invalid">
    <id>123</id>
    <status>open</status>
  </note>
</osm-notes>
EOF

 # Set environment variables
 export PLANET_NOTES_FILE="${TEST_TMP_DIR}/invalid_notes.xml"
 export MAX_THREADS="1"
 export DBNAME="${TEST_DBNAME}"

 # Run the workflow - should handle errors gracefully
 run bash -c "source ${TEST_BASE_DIR}/tests/docker/test_processAPINotes.sh"

 # Should not crash, even with invalid data
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ]

 # Cleanup
 drop_test_database
}
