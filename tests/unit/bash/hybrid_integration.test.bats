#!/usr/bin/env bats

# Hybrid integration tests (mock internet downloads, real database/XML processing)
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_hybrid_integration"
 export LOG_LEVEL="INFO"
 
 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
   mkdir -p "${TMP_DIR}" || { echo "ERROR: Could not create TMP_DIR: ${TMP_DIR}" >&2; exit 1; }
 fi
 if [[ ! -w "${TMP_DIR}" ]]; then
   echo "ERROR: TMP_DIR not writable: ${TMP_DIR}" >&2; exit 1;
 fi
 
 # Setup hybrid mock environment
 "${SCRIPT_BASE_DIRECTORY}/tests/setup_hybrid_mock_environment.sh" setup
 "${SCRIPT_BASE_DIRECTORY}/tests/setup_hybrid_mock_environment.sh" activate
}

teardown() {
 # Deactivate hybrid mock environment
 "${SCRIPT_BASE_DIRECTORY}/tests/setup_hybrid_mock_environment.sh" deactivate
 # Cleanup
 rm -rf "${TMP_DIR}"
}

# Test that mock wget works correctly
@test "mock wget should download XML files" {
 # Test downloading XML file
 run wget -O "${TMP_DIR}/test.xml" "https://example.com/test.xml"
 [ "$status" -eq 0 ]
 [ -f "${TMP_DIR}/test.xml" ]
 
 # Check that the file contains OSM notes structure
 run grep -q "osm-notes" "${TMP_DIR}/test.xml"
 [ "$status" -eq 0 ]
 
 # Check that it contains test notes
 run grep -q "Test note" "${TMP_DIR}/test.xml"
 [ "$status" -eq 0 ]
}

# Test that mock aria2c works correctly
@test "mock aria2c should download compressed files" {
 # Test downloading bzip2 file
 run aria2c -o "${TMP_DIR}/test.bz2" "https://example.com/test.bz2"
 [ "$status" -eq 0 ]
 [ -f "${TMP_DIR}/test.bz2" ]
 
 # Check that the file is compressed
 run file "${TMP_DIR}/test.bz2"
 [ "$status" -eq 0 ]
 [[ "$output" == *"bzip2"* ]] || [[ "$output" == *"data"* ]]
}

# Test that real xmllint works with mock data
@test "real xmllint should validate mock XML files" {
 # Create a test XML file using mock wget
 wget -O "${TMP_DIR}/test.xml" "https://example.com/test.xml"
 
 # Test XML validation with real xmllint
 run xmllint --noout "${TMP_DIR}/test.xml"
 [ "$status" -eq 0 ]
 
 # Test XPath query with real xmllint
 run xmllint --xpath "count(//note)" "${TMP_DIR}/test.xml"
 [ "$status" -eq 0 ]
 [[ "$output" == "2" ]] || [[ "$output" == "3" ]] || [[ "$output" == "4" ]] || [[ "$output" == "5" ]]
}

# Test that real xsltproc works with mock data
@test "real xsltproc should transform mock XML files" {
 # Create a test XML file using mock wget
 wget -O "${TMP_DIR}/test.xml" "https://example.com/test.xml"
 
 # Test XSLT transformation with real xsltproc
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/xslt/notes-API-csv.xslt" ]]; then
   run xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/notes-API-csv.xslt" "${TMP_DIR}/test.xml"
   [ "$status" -eq 0 ]
   [[ "$output" == *"123"* ]] || [[ "$output" == *"124"* ]]
 fi
}

# Test that real bzip2 works with mock data
@test "real bzip2 should decompress mock files" {
 # Create a compressed file using mock aria2c
 aria2c -o "${TMP_DIR}/test.bz2" "https://example.com/test.bz2"
 
 # Test decompression with real bzip2
 run bzip2 -d "${TMP_DIR}/test.bz2"
 [ "$status" -eq 0 ]
 [ -f "${TMP_DIR}/test" ]
 
 # Check that decompressed file contains XML
 run grep -q "osm-notes" "${TMP_DIR}/test"
 [ "$status" -eq 0 ]
}

# Test that real psql works (if available)
@test "real psql should be available for database operations" {
 # Check if psql is available
 if command -v psql >/dev/null 2>&1; then
   run psql --version
   [ "$status" -eq 0 ]
   [[ "$output" == *"psql"* ]]
 else
   skip "psql not available"
 fi
}

# Test that real database operations work (if database is available)
@test "real database operations should work with mock data" {
 # Skip if psql is not available
 if ! command -v psql >/dev/null 2>&1; then
   skip "psql not available"
 fi
 
 # Skip if database is not accessible
 if ! psql -d "${DBNAME:-osm_notes}" -c "SELECT 1;" >/dev/null 2>&1; then
   skip "Database not accessible"
 fi
 
 # Test basic database operation
 run psql -d "${DBNAME:-osm_notes}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"
 [ "$status" -eq 0 ]
 [[ "$output" == *"count"* ]] || [[ "$output" == *"[0-9]"* ]]
}

# Test that mock downloads work with real processing pipeline
@test "mock downloads should work with real processing pipeline" {
 # Download mock data
 wget -O "${TMP_DIR}/planet_notes.xml" "https://planet.openstreetmap.org/notes/planet-notes-latest.osm.bz2"
 
 # Validate with real xmllint
 run xmllint --noout "${TMP_DIR}/planet_notes.xml"
 [ "$status" -eq 0 ]
 
 # Count notes with real xmllint
 run xmllint --xpath "count(//note)" "${TMP_DIR}/planet_notes.xml"
 [ "$status" -eq 0 ]
 [[ "$output" =~ ^[0-9]+$ ]]
 
 # Transform with real xsltproc if XSLT file exists
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt" ]]; then
   run xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt" "${TMP_DIR}/planet_notes.xml"
   [ "$status" -eq 0 ]
   [[ "$output" == *","* ]]  # Should contain CSV format
 fi
}

# Test that hybrid environment variables are set correctly
@test "hybrid environment variables should be set correctly" {
 # Check that mock environment is active
 [[ "${HYBRID_MOCK_MODE:-}" == "true" ]]
 [[ "${TEST_MODE:-}" == "true" ]]
 
 # Check that database variables are set
 [[ -n "${DBNAME:-}" ]]
 [[ -n "${DB_USER:-}" ]]
 
 # Check that mock commands are in PATH
 run which wget
 [ "$status" -eq 0 ]
 [[ "$output" == *"mock_commands"* ]]
 
 run which aria2c
 [ "$status" -eq 0 ]
 [[ "$output" == *"mock_commands"* ]]
}

# Test that real commands are still available
@test "real commands should still be available" {
 # Check that real xmllint is available
 run which xmllint
 [ "$status" -eq 0 ]
 [[ "$output" != *"mock_commands"* ]]
 
 # Check that real xsltproc is available
 run which xsltproc
 [ "$status" -eq 0 ]
 [[ "$output" != *"mock_commands"* ]]
 
 # Check that real bzip2 is available
 run which bzip2
 [ "$status" -eq 0 ]
 [[ "$output" != *"mock_commands"* ]]
}

# Test end-to-end workflow with hybrid environment
@test "end-to-end workflow should work with hybrid environment" {
 # Download mock planet data
 wget -O "${TMP_DIR}/planet_notes.xml" "https://planet.openstreetmap.org/notes/planet-notes-latest.osm.bz2"
 
 # Validate XML structure
 run xmllint --noout "${TMP_DIR}/planet_notes.xml"
 [ "$status" -eq 0 ]
 
 # Count notes
 run xmllint --xpath "count(//note)" "${TMP_DIR}/planet_notes.xml"
 [ "$status" -eq 0 ]
 local note_count="$output"
 [[ "$note_count" =~ ^[0-9]+$ ]]
 [[ "$note_count" -gt 0 ]]
 
 # Transform to CSV if XSLT is available
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt" ]]; then
   run xsltproc "${SCRIPT_BASE_DIRECTORY}/xslt/notes-Planet-csv.xslt" "${TMP_DIR}/planet_notes.xml" > "${TMP_DIR}/notes.csv"
   [ "$status" -eq 0 ]
   [ -f "${TMP_DIR}/notes.csv" ]
   
   # Check CSV output
   run wc -l < "${TMP_DIR}/notes.csv"
   [ "$status" -eq 0 ]
   local csv_lines="$output"
   [[ "$csv_lines" -gt 0 ]]
 fi
} 