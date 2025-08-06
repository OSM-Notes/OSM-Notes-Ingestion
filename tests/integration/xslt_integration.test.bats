#!/usr/bin/env bats

# XSLT Integration Tests
# Tests XSLT transformations as part of the complete workflow
# Integrates XSLT testing with the broader system
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"

# Test configuration
XSLT_DIR="${SCRIPT_BASE_DIRECTORY}/xslt"
TEST_OUTPUT_DIR="${TEST_TMP_DIR}/xslt_integration_output"

setup() {
 # Create test output directory
 mkdir -p "${TEST_OUTPUT_DIR}"
 
 # Set up test environment
 export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
 export TEST_DBUSER="${TEST_DBUSER:-test_user}"
 export TEST_DBPASSWORD="${TEST_DBPASSWORD:-test_pass}"
 export TEST_DBHOST="${TEST_DBHOST:-localhost}"
 export TEST_DBPORT="${TEST_DBPORT:-5432}"
}

teardown() {
 # Clean up test output directory
 rm -rf "${TEST_OUTPUT_DIR}" 2>/dev/null || true
}

@test "XSLT should integrate with API notes processing workflow" {
 # Create test database
 create_test_database

 # Create sample API XML file
 cat > "${BATS_TEST_TMPDIR}/api_notes.xml" << 'EOF'
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
</osm>
EOF

 # Test XSLT transformation for notes
 local notes_xslt="${XSLT_DIR}/notes-API-csv.xslt"
 local notes_output="${TEST_OUTPUT_DIR}/notes_api.csv"
 
 run xsltproc "${notes_xslt}" "${BATS_TEST_TMPDIR}/api_notes.xml" > "${notes_output}"
 [ "$status" -eq 0 ]
 [ -f "${notes_output}" ]

 # Test XSLT transformation for comments
 local comments_xslt="${XSLT_DIR}/note_comments-API-csv.xslt"
 local comments_output="${TEST_OUTPUT_DIR}/comments_api.csv"
 
 run xsltproc "${comments_xslt}" "${BATS_TEST_TMPDIR}/api_notes.xml" > "${comments_output}"
 [ "$status" -eq 0 ]
 [ -f "${comments_output}" ]

 # Test XSLT transformation for text comments
 local text_xslt="${XSLT_DIR}/note_comments_text-API-csv.xslt"
 local text_output="${TEST_OUTPUT_DIR}/text_api.csv"
 
 run xsltproc "${text_xslt}" "${BATS_TEST_TMPDIR}/api_notes.xml" > "${text_output}"
 [ "$status" -eq 0 ]
 [ -f "${text_output}" ]

 # Verify CSV files have expected content
 run grep -q "123" "${notes_output}"
 [ "$status" -eq 0 ]

 run grep -q "123" "${comments_output}"
 [ "$status" -eq 0 ]

 run grep -q "Test comment 1" "${text_output}"
 [ "$status" -eq 0 ]

 # Cleanup
 drop_test_database
}

@test "XSLT should integrate with Planet notes processing workflow" {
 # Create test database
 create_test_database

 # Create sample Planet XML file
 cat > "${BATS_TEST_TMPDIR}/planet_notes.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
  <note id="123" lat="40.7128" lon="-74.0060" created_at="2013-04-28T02:39:27Z" closed_at="">
    <comment action="opened" timestamp="2013-04-28T02:39:27Z" uid="123" user="user1">
      <text>Test comment 1</text>
    </comment>
  </note>
</osm-notes>
EOF

 # Test XSLT transformation for notes
 local notes_xslt="${XSLT_DIR}/notes-Planet-csv.xslt"
 local notes_output="${TEST_OUTPUT_DIR}/notes_planet.csv"
 
 run xsltproc "${notes_xslt}" "${BATS_TEST_TMPDIR}/planet_notes.xml" > "${notes_output}"
 [ "$status" -eq 0 ]
 [ -f "${notes_output}" ]

 # Test XSLT transformation for comments
 local comments_xslt="${XSLT_DIR}/note_comments-Planet-csv.xslt"
 local comments_output="${TEST_OUTPUT_DIR}/comments_planet.csv"
 
 run xsltproc "${comments_xslt}" "${BATS_TEST_TMPDIR}/planet_notes.xml" > "${comments_output}"
 [ "$status" -eq 0 ]
 [ -f "${comments_output}" ]

 # Test XSLT transformation for text comments
 local text_xslt="${XSLT_DIR}/note_comments_text-Planet-csv.xslt"
 local text_output="${TEST_OUTPUT_DIR}/text_planet.csv"
 
 run xsltproc "${text_xslt}" "${BATS_TEST_TMPDIR}/planet_notes.xml" > "${text_output}"
 [ "$status" -eq 0 ]
 [ -f "${text_output}" ]

 # Verify CSV files have expected content
 run grep -q "123" "${notes_output}"
 [ "$status" -eq 0 ]

 run grep -q "123" "${comments_output}"
 [ "$status" -eq 0 ]

 run grep -q "Test comment 1" "${text_output}"
 [ "$status" -eq 0 ]

 # Cleanup
 drop_test_database
}

@test "XSLT should work with real data from fixtures" {
 # Test with real XML data from fixtures
 local fixtures_dir="${SCRIPT_BASE_DIRECTORY}/tests/fixtures/xml"
 
 if [[ -d "${fixtures_dir}" ]]; then
  # Find real XML files
  local api_xml=$(find "${fixtures_dir}" -name "*api*.xml" | head -1)
  local planet_xml=$(find "${fixtures_dir}" -name "*planet*.xml" | head -1)
  
  if [[ -f "${api_xml}" ]]; then
   # Test API XSLT transformations with real data
   local notes_xslt="${XSLT_DIR}/notes-API-csv.xslt"
   local notes_output="${TEST_OUTPUT_DIR}/real_notes_api.csv"
   
   run xsltproc "${notes_xslt}" "${api_xml}" > "${notes_output}"
   [ "$status" -eq 0 ]
   [ -f "${notes_output}" ]
   
   # Verify output has content
   run wc -l < "${notes_output}"
   [ "$output" -gt 0 ]
  fi
  
  if [[ -f "${planet_xml}" ]]; then
   # Test Planet XSLT transformations with real data
   local notes_xslt="${XSLT_DIR}/notes-Planet-csv.xslt"
   local notes_output="${TEST_OUTPUT_DIR}/real_notes_planet.csv"
   
   run xsltproc "${notes_xslt}" "${planet_xml}" > "${notes_output}"
   [ "$status" -eq 0 ]
   [ -f "${notes_output}" ]
   
   # Verify output has content
   run wc -l < "${notes_output}"
   [ "$output" -gt 0 ]
  fi
 fi
}

@test "XSLT should handle parallel processing scenarios" {
 # Create multiple XML files for parallel processing test
 for i in {1..3}; do
  cat > "${BATS_TEST_TMPDIR}/api_notes_${i}.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.712${i}" lon="-74.006${i}">
    <id>${i}23</id>
    <date_created>2013-04-28T02:39:27Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2013-04-28T02:39:27Z</date>
        <uid>${i}23</uid>
        <user>user${i}</user>
        <action>opened</action>
        <text>Test comment ${i}</text>
      </comment>
    </comments>
  </note>
</osm>
EOF
 done

 # Test parallel XSLT processing
 local notes_xslt="${XSLT_DIR}/notes-API-csv.xslt"
 local pids=()
 local outputs=()

 for i in {1..3}; do
  local output="${TEST_OUTPUT_DIR}/parallel_notes_${i}.csv"
  outputs+=("${output}")
  
  # Run XSLT transformation in background
  xsltproc "${notes_xslt}" "${BATS_TEST_TMPDIR}/api_notes_${i}.xml" > "${output}" &
  pids+=($!)
 done

 # Wait for all transformations to complete
 for pid in "${pids[@]}"; do
  wait "${pid}"
 done

 # Verify all outputs were created
 for output in "${outputs[@]}"; do
  [ -f "${output}" ]
  run wc -l < "${output}"
  [ "$output" -gt 0 ]
 done
}

@test "XSLT should integrate with database loading workflow" {
 # Create test database
 create_test_database

 # Create sample XML file
 cat > "${BATS_TEST_TMPDIR}/test_notes.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
    <date_created>2013-04-28T02:39:27Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2013-04-28T02:39:27Z</date>
        <uid>123</uid>
        <user>user1</user>
        <action>opened</action>
        <text>Test comment for database</text>
      </comment>
    </comments>
  </note>
</osm>
EOF

 # Generate CSV files using XSLT
 local notes_xslt="${XSLT_DIR}/notes-API-csv.xslt"
 local comments_xslt="${XSLT_DIR}/note_comments-API-csv.xslt"
 local text_xslt="${XSLT_DIR}/note_comments_text-API-csv.xslt"
 
 local notes_csv="${TEST_OUTPUT_DIR}/db_notes.csv"
 local comments_csv="${TEST_OUTPUT_DIR}/db_comments.csv"
 local text_csv="${TEST_OUTPUT_DIR}/db_text.csv"
 
 # Run XSLT transformations
 run xsltproc "${notes_xslt}" "${BATS_TEST_TMPDIR}/test_notes.xml" > "${notes_csv}"
 [ "$status" -eq 0 ]
 
 run xsltproc "${comments_xslt}" "${BATS_TEST_TMPDIR}/test_notes.xml" > "${comments_csv}"
 [ "$status" -eq 0 ]
 
 run xsltproc "${text_xslt}" "${BATS_TEST_TMPDIR}/test_notes.xml" > "${text_csv}"
 [ "$status" -eq 0 ]

 # Verify CSV files were created and have content
 [ -f "${notes_csv}" ]
 [ -f "${comments_csv}" ]
 [ -f "${text_csv}" ]
 
 run wc -l < "${notes_csv}"
 [ "$output" -gt 0 ]
 
 run wc -l < "${comments_csv}"
 [ "$output" -gt 0 ]
 
 run wc -l < "${text_csv}"
 [ "$output" -gt 0 ]

 # Test database loading (if database is available)
 if command -v psql &> /dev/null; then
  # Load notes CSV into database
  run psql -d "${TEST_DBNAME}" -c "\COPY notes FROM '${notes_csv}' CSV;"
  [ "$status" -eq 0 ]
  
  # Verify data was loaded
  run psql -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM notes;"
  [ "$status" -eq 0 ]
  [[ "$output" -gt 0 ]]
 fi

 # Cleanup
 drop_test_database
}

@test "XSLT should handle error scenarios gracefully" {
 # Test with non-existent XSLT file
 local non_existent_xslt="${XSLT_DIR}/non_existent.xslt"
 local test_xml="${BATS_TEST_TMPDIR}/test.xml"
 local output="${TEST_OUTPUT_DIR}/error_test.csv"
 
 # Create test XML
 cat > "${test_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6">
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
  </note>
</osm>
EOF

 # Test with non-existent XSLT file
 run xsltproc "${non_existent_xslt}" "${test_xml}" > "${output}" 2>&1
 [ "$status" -ne 0 ]

 # Test with malformed XML
 local valid_xslt="${XSLT_DIR}/notes-API-csv.xslt"
 local malformed_xml="${BATS_TEST_TMPDIR}/malformed.xml"
 
 cat > "${malformed_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6">
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
    <!-- Missing closing tag -->
EOF

 run xsltproc "${valid_xslt}" "${malformed_xml}" > "${output}" 2>&1
 [ "$status" -ne 0 ]
}

@test "XSLT should maintain data integrity across transformations" {
 # Create XML with known data
 cat > "${BATS_TEST_TMPDIR}/integrity_test.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
  <note lat="40.7128" lon="-74.0060">
    <id>123</id>
    <date_created>2013-04-28T02:39:27Z</date_created>
    <status>open</status>
    <comments>
      <comment>
        <date>2013-04-28T02:39:27Z</date>
        <uid>123</uid>
        <user>user1</user>
        <action>opened</action>
        <text>Test comment with special chars: áéíóúñ & "quotes"</text>
      </comment>
    </comments>
  </note>
</osm>
EOF

 # Test all XSLT transformations
 local xslt_files=(
  "${XSLT_DIR}/notes-API-csv.xslt"
  "${XSLT_DIR}/note_comments-API-csv.xslt"
  "${XSLT_DIR}/note_comments_text-API-csv.xslt"
 )

 for xslt_file in "${xslt_files[@]}"; do
  if [[ -f "${xslt_file}" ]]; then
   local output="${TEST_OUTPUT_DIR}/integrity_$(basename "${xslt_file}" .xslt).csv"
   
   # Run transformation
   run xsltproc "${xslt_file}" "${BATS_TEST_TMPDIR}/integrity_test.xml" > "${output}"
   [ "$status" -eq 0 ]
   [ -f "${output}" ]
   
   # Verify data integrity
   run grep -q "123" "${output}"
   [ "$status" -eq 0 ]
   
   # Verify special characters are preserved
   run grep -q "áéíóúñ" "${output}"
   [ "$status" -eq 0 ]
  fi
 done
} 