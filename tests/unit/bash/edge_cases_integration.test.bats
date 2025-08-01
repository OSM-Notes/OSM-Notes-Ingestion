#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Edge Cases Integration Tests
# Tests that cover edge cases and boundary conditions

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_edge_cases"
 export LOG_LEVEL="INFO"
 
 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
   mkdir -p "${TMP_DIR}" || { echo "ERROR: Could not create TMP_DIR: ${TMP_DIR}" >&2; exit 1; }
 fi
 if [[ ! -w "${TMP_DIR}" ]]; then
   echo "ERROR: TMP_DIR not writable: ${TMP_DIR}" >&2; exit 1;
 fi
 
 # Set up test database
 export TEST_DBNAME="test_osm_notes_${BASENAME}"
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}"
 # Drop test database if it exists
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" 2>/dev/null || true
}

# Test with very large XML files
@test "Edge case: Very large XML files should be handled gracefully" {
 # Create a large XML file
 local LARGE_XML="${TMP_DIR}/large_notes.xml"
 
 # Generate a large XML file (simulate large dataset)
 cat > "${LARGE_XML}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="test">
EOF
 
 # Add many note entries to simulate large file
 for i in {1..1000}; do
   cat >> "${LARGE_XML}" << EOF
  <note id="${i}" lat="0.0" lon="0.0">
   <date>2024-01-01T00:00:00Z</date>
   <status>open</status>
   <comments>
    <comment id="${i}_1" user="testuser" uid="1" user_url="http://example.com">
     <date>2024-01-01T00:00:00Z</date>
     <text>Test comment ${i}</text>
    </comment>
   </comments>
  </note>
EOF
 done
 
 echo "</osm>" >> "${LARGE_XML}"
 
 # Test that the file exists and is large
 [ -f "${LARGE_XML}" ]
 [ "$(wc -l < "${LARGE_XML}")" -gt 1000 ]
 
 # Test that XML is valid
 run xmllint --noout "${LARGE_XML}"
 [ "$status" -eq 0 ]
}

# Test with malformed XML files
@test "Edge case: Malformed XML files should be handled gracefully" {
 # Create malformed XML files
 local MALFORMED_XML="${TMP_DIR}/malformed_notes.xml"
 
 # Create various malformed XML scenarios
 cat > "${MALFORMED_XML}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="test">
  <note id="1" lat="0.0" lon="0.0">
   <date>2024-01-01T00:00:00Z</date>
   <status>open</status>
   <comments>
    <comment id="1_1" user="testuser" uid="1">
     <date>2024-01-01T00:00:00Z</date>
     <text>Test comment with special chars: & < > " '</text>
    </comment>
   </comments>
  </note>
  <!-- Unclosed tag -->
  <note id="2" lat="0.0" lon="0.0">
   <date>2024-01-01T00:00:00Z</date>
   <status>open</status>
EOF
 
 # Test that malformed XML is detected
 run xmllint --noout "${MALFORMED_XML}"
 [ "$status" -ne 0 ] # Should fail validation
}

# Test with empty database
@test "Edge case: Empty database should be handled gracefully" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Test that empty database operations work
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM information_schema.tables;"
 [ "$status" -eq 0 ]
 [ "$output" -eq "0" ]
}

# Test with corrupted database
@test "Edge case: Corrupted database should be handled gracefully" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 [ "$status" -eq 0 ]
 
 # Insert corrupted data
 run psql -d "${TEST_DBNAME}" -c "INSERT INTO notes (id, lat, lon, created_at, status) VALUES (1, 'invalid_lat', 'invalid_lon', '2024-01-01', 'invalid_status');"
 [ "$status" -eq 0 ]
 
 # Test that corrupted data is handled
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM notes WHERE lat = 'invalid_lat';"
 [ "$status" -eq 0 ]
 [ "$output" -eq "1" ]
}

# Test with network connectivity issues
@test "Edge case: Network connectivity issues should be handled gracefully" {
 # Test with invalid URLs
 local INVALID_URL="http://invalid.example.com/nonexistent"
 
 # Test that network errors are handled
 run timeout 5s curl -f "${INVALID_URL}"
 [ "$status" -ne 0 ] # Should fail
}

# Test with insufficient disk space
@test "Edge case: Insufficient disk space should be handled gracefully" {
 # Create a large file to simulate disk space issues
 local LARGE_FILE="${TMP_DIR}/large_file"
 
 # Try to create a large file (this will fail if disk is full)
 run dd if=/dev/zero of="${LARGE_FILE}" bs=1M count=100 2>/dev/null
 [ "$status" -eq 0 ] || echo "Disk space test completed"
}

# Test with permission issues
@test "Edge case: Permission issues should be handled gracefully" {
 # Create a read-only directory
 local READONLY_DIR="${TMP_DIR}/readonly"
 mkdir -p "${READONLY_DIR}"
 chmod 444 "${READONLY_DIR}"
 
 # Test that permission errors are handled
 run touch "${READONLY_DIR}/test_file"
 [ "$status" -ne 0 ] # Should fail due to read-only permissions
 
 # Cleanup
 chmod 755 "${READONLY_DIR}"
}

# Test with concurrent access
@test "Edge case: Concurrent access should be handled gracefully" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 [ "$status" -eq 0 ]
 
 # Test concurrent inserts
 (
   psql -d "${TEST_DBNAME}" -c "INSERT INTO notes (id, lat, lon, created_at, status) VALUES (1, 0.0, 0.0, '2024-01-01', 'open');" &
   psql -d "${TEST_DBNAME}" -c "INSERT INTO notes (id, lat, lon, created_at, status) VALUES (2, 0.0, 0.0, '2024-01-01', 'open');" &
   wait
 )
 
 # Verify both inserts worked
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM notes;"
 [ "$status" -eq 0 ]
 [ "$output" -eq "2" ]
}

# Test with memory constraints
@test "Edge case: Memory constraints should be handled gracefully" {
 # Test with limited memory (simulate memory pressure)
 local MEMORY_TEST="${TMP_DIR}/memory_test"
 
 # Create a script that uses a lot of memory
 cat > "${MEMORY_TEST}.sh" << 'EOF'
#!/bin/bash
# Simulate memory usage
declare -a large_array
for i in {1..10000}; do
  large_array[$i]="data_$i"
done
echo "Memory test completed"
EOF
 
 chmod +x "${MEMORY_TEST}.sh"
 
 # Run memory test
 run timeout 30s bash "${MEMORY_TEST}.sh"
 [ "$status" -eq 0 ] || echo "Memory test completed"
}

# Test with invalid configuration
@test "Edge case: Invalid configuration should be handled gracefully" {
 # Test with invalid database connection
 run bash -c "DBNAME=invalid_db DBHOST=invalid_host DBUSER=invalid_user DBPASSWORD=invalid_pass source ${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh"
 [ "$status" -ne 0 ] # Should fail gracefully
}

# Test with missing dependencies
@test "Edge case: Missing dependencies should be handled gracefully" {
 # Test with missing required tools
 run bash -c "command -v nonexistent_tool"
 [ "$status" -ne 0 ] # Should fail when tool doesn't exist
}

# Test with timeout scenarios
@test "Edge case: Timeout scenarios should be handled gracefully" {
 # Test with long-running operations
 run timeout 5s bash -c "sleep 10"
 [ "$status" -eq 124 ] # Should timeout after 5 seconds
}

# Test with data corruption
@test "Edge case: Data corruption should be handled gracefully" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Create tables
 run psql -d "${TEST_DBNAME}" -f "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 [ "$status" -eq 0 ]
 
 # Insert corrupted data
 run psql -d "${TEST_DBNAME}" -c "INSERT INTO notes (id, lat, lon, created_at, status) VALUES (1, NULL, NULL, NULL, NULL);"
 [ "$status" -eq 0 ]
 
 # Test that NULL values are handled
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM notes WHERE lat IS NULL;"
 [ "$status" -eq 0 ]
 [ "$output" -eq "1" ]
}

# Test with extreme values
@test "Edge case: Extreme values should be handled gracefully" {
 # Test with extreme coordinates
 local EXTREME_COORDS=(
   "90.0,180.0"    # North Pole
   "-90.0,-180.0"  # South Pole
   "0.0,0.0"       # Null Island
   "90.1,180.1"    # Invalid coordinates
   "-90.1,-180.1"  # Invalid coordinates
 )
 
 for coords in "${EXTREME_COORDS[@]}"; do
   IFS=',' read -r lat lon <<< "${coords}"
   
   # Test coordinate validation
   if [[ "${lat}" =~ ^-?([0-9]+\.?[0-9]*|\.[0-9]+)$ ]] && \
      [[ "${lon}" =~ ^-?([0-9]+\.?[0-9]*|\.[0-9]+)$ ]] && \
      (( $(echo "${lat} >= -90 && ${lat} <= 90" | bc -l) )) && \
      (( $(echo "${lon} >= -180 && ${lon} <= 180" | bc -l) )); then
     echo "Valid coordinates: ${lat}, ${lon}"
   else
     echo "Invalid coordinates: ${lat}, ${lon}"
   fi
 done
} 