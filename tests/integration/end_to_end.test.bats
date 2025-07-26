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
 export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
 export TEST_DBUSER="${TEST_DBUSER:-test_user}"
 export TEST_DBPASSWORD="${TEST_DBPASSWORD:-test_pass}"
 export TEST_DBHOST="${TEST_DBHOST:-test-db}"
 export TEST_DBPORT="${TEST_DBPORT:-5432}"

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
 export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
 export TEST_DBUSER="${TEST_DBUSER:-test_user}"
 export TEST_DBPASSWORD="${TEST_DBPASSWORD:-test_pass}"
 export TEST_DBHOST="${TEST_DBHOST:-test-db}"
 export TEST_DBPORT="${TEST_DBPORT:-5432}"

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
 export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
 export TEST_DBUSER="${TEST_DBUSER:-test_user}"
 export TEST_DBPASSWORD="${TEST_DBPASSWORD:-test_pass}"
 export TEST_DBHOST="${TEST_DBHOST:-test-db}"
 export TEST_DBPORT="${TEST_DBPORT:-5432}"

 # Measure execution time
 local start_time=$(date +%s)

 # Run the complete workflow
 run bash -c "source ${TEST_BASE_DIR}/tests/docker/test_processPlanetNotes.sh"
 [ "$status" -eq 0 ]

 local end_time=$(date +%s)
 local execution_time=$((end_time - start_time))

 # Verify data was processed correctly
 local notes_count=$(count_rows "notes" "${TEST_DBNAME}")
 local comments_count=$(count_rows "note_comments" "${TEST_DBNAME}")

 [ "$notes_count" -gt 0 ]
 [ "$comments_count" -gt 0 ]

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
 export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
 export TEST_DBUSER="${TEST_DBUSER:-test_user}"
 export TEST_DBPASSWORD="${TEST_DBPASSWORD:-test_pass}"
 export TEST_DBHOST="${TEST_DBHOST:-test-db}"
 export TEST_DBPORT="${TEST_DBPORT:-5432}"

 # Run the complete workflow
 run bash -c "source ${TEST_BASE_DIR}/tests/docker/test_processPlanetNotes.sh"
 [ "$status" -eq 0 ]

 # Verify data was processed correctly
 local notes_count=$(count_rows "notes" "${TEST_DBNAME}")
 local comments_count=$(count_rows "note_comments" "${TEST_DBNAME}")

 [ "$notes_count" -gt 0 ]
 [ "$comments_count" -gt 0 ]

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
 export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
 export TEST_DBUSER="${TEST_DBUSER:-test_user}"
 export TEST_DBPASSWORD="${TEST_DBPASSWORD:-test_pass}"
 export TEST_DBHOST="${TEST_DBHOST:-test-db}"
 export TEST_DBPORT="${TEST_DBPORT:-5432}"

 # Run the workflow - should handle errors gracefully
 run bash -c "source ${TEST_BASE_DIR}/tests/docker/test_processAPINotes.sh"

 # Should not crash, even with invalid data
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ]

 # Cleanup
 drop_test_database
}

@test "complete workflow should handle both Planet and API processing in sequence" {
 # Create test database
 create_test_database

 # Step 1: Create sample XML file for Planet notes (initial load)
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
        <text>Initial comment from Planet</text>
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
        <text>Initial comment from Planet</text>
      </comment>
      <comment>
        <date>2013-05-01T10:15:30Z</date>
        <uid>789</uid>
        <user>user3</user>
        <action>closed</action>
        <text>Closing this note from Planet</text>
      </comment>
    </comments>
  </note>
</osm-notes>
EOF

 # Set environment variables for Planet processing
 export PLANET_NOTES_FILE="${TEST_TMP_DIR}/planet_notes.xml"
 export MAX_THREADS="1"
 export DBNAME="${TEST_DBNAME}"
 export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
 export TEST_DBUSER="${TEST_DBUSER:-test_user}"
 export TEST_DBPASSWORD="${TEST_DBPASSWORD:-test_pass}"
 export TEST_DBHOST="${TEST_DBHOST:-test-db}"
 export TEST_DBPORT="${TEST_DBPORT:-5432}"

 # Step 2: Process Planet notes (initial load)
 echo "Processing Planet notes (initial load)..."
 run bash -c "source ${TEST_BASE_DIR}/tests/docker/test_processPlanetNotes.sh"
 [ "$status" -eq 0 ]

 # Verify initial data was processed correctly
 local notes_count_planet=$(count_rows "notes" "${TEST_DBNAME}")
 local comments_count_planet=$(count_rows "note_comments" "${TEST_DBNAME}")
 local text_count_planet=$(count_rows "note_comments_text" "${TEST_DBNAME}")

 [ "$notes_count_planet" -eq 2 ]
 [ "$comments_count_planet" -eq 3 ]
 [ "$text_count_planet" -eq 3 ]

 echo "Planet processing completed. Notes: $notes_count_planet, Comments: $comments_count_planet, Text: $text_count_planet"

 # Step 3: Create sample XML file for API notes (incremental updates)
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
        <text>Initial comment from Planet</text>
      </comment>
      <comment>
        <date>2013-05-02T14:30:00Z</date>
        <uid>999</uid>
        <user>newuser</user>
        <action>commented</action>
        <text>New comment from API update</text>
      </comment>
    </comments>
  </note>
  <note lat="42.3601" lon="-71.0589">
    <id>789</id>
    <url>https://www.openstreetmap.org/api/0.6/notes/789</url>
    <comment_url>https://www.openstreetmap.org/api/0.6/notes/789/comment</comment_url>
    <close_url>https://www.openstreetmap.org/api/0.6/notes/789/close</close_url>
    <date_created>2013-05-03T09:00:00Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2013-05-03T09:00:00Z</date>
        <uid>111</uid>
        <user>user4</user>
        <action>opened</action>
        <text>New note from API</text>
      </comment>
    </comments>
  </note>
</osm>
EOF

 # Set environment variables for API processing
 export API_NOTES_FILE="${TEST_TMP_DIR}/api_notes.xml"
 export MAX_THREADS="1"
 export DBNAME="${TEST_DBNAME}"
 export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
 export TEST_DBUSER="${TEST_DBUSER:-test_user}"
 export TEST_DBPASSWORD="${TEST_DBPASSWORD:-test_pass}"
 export TEST_DBHOST="${TEST_DBHOST:-test-db}"
 export TEST_DBPORT="${TEST_DBPORT:-5432}"

 # Step 4: Process API notes (incremental updates)
 echo "Processing API notes (incremental updates)..."
 run bash -c "source ${TEST_BASE_DIR}/tests/docker/test_processAPINotes.sh"
 [ "$status" -eq 0 ]

 # Verify final data was processed correctly
 local notes_count_final=$(count_rows "notes" "${TEST_DBNAME}")
 local comments_count_final=$(count_rows "note_comments" "${TEST_DBNAME}")
 local text_count_final=$(count_rows "note_comments_text" "${TEST_DBNAME}")

 # Should have more data after API processing (new note + new comment)
 [ "$notes_count_final" -gt "$notes_count_planet" ]
 [ "$comments_count_final" -gt "$comments_count_planet" ]
 [ "$text_count_final" -gt "$text_count_planet" ]

 echo "API processing completed. Final Notes: $notes_count_final, Comments: $comments_count_final, Text: $text_count_final"

 # Verify specific data integrity
 # Check that note 123 has both original and new comment
 local note_123_comments=$(psql -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments WHERE note_id = 123;" | xargs)
 [ "$note_123_comments" -eq 2 ]

 # Check that new note 789 exists
 local note_789_exists=$(psql -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM notes WHERE note_id = 789;" | xargs)
 [ "$note_789_exists" -eq 1 ]

 # Check that new comment text exists
 local new_comment_exists=$(psql -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_text WHERE note_id = 123 AND body LIKE '%API update%';" | xargs)
 [ "$new_comment_exists" -eq 1 ]

 echo "Data integrity verification passed"

 # Cleanup
 drop_test_database
}
