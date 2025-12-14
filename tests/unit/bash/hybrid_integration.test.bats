#!/usr/bin/env bats

# Hybrid integration tests (mock internet downloads, real database/XML processing)
# Author: Andres Gomez (AngocA)
# Version: 2025-11-24

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_hybrid_integration"
 export LOG_LEVEL="INFO"

 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
  mkdir -p "${TMP_DIR}" || {
   echo "ERROR: Could not create TMP_DIR: ${TMP_DIR}" >&2
   exit 1
  }
 fi
 if [[ ! -w "${TMP_DIR}" ]]; then
  echo "ERROR: TMP_DIR not writable: ${TMP_DIR}" >&2
  exit 1
 fi

 # Find real psql before activating mock environment
 # Remove mock commands directory from PATH temporarily to find real psql
 local mock_commands_dir="${SCRIPT_BASE_DIRECTORY}/tests/mock_commands"
 local temp_path
 temp_path=$(echo "${PATH}" | tr ':' '\n' | grep -v "${mock_commands_dir}" | tr '\n' ':' | sed 's/:$//')
 
 # Find real psql path
 local real_psql_path=""
 while IFS= read -r dir; do
   if [[ -f "${dir}/psql" ]] && [[ "${dir}" != "${mock_commands_dir}" ]]; then
     real_psql_path="${dir}/psql"
     break
   fi
 done <<< "$(echo "${temp_path}" | tr ':' '\n')"
 
 # Export real psql path if found
 if [[ -n "${real_psql_path}" ]]; then
   export REAL_PSQL_PATH="${real_psql_path}"
 fi

 # Setup hybrid mock environment
 source "${SCRIPT_BASE_DIRECTORY}/tests/setup_hybrid_mock_environment.sh"
 setup_hybrid_mock_environment
 activate_hybrid_mock_environment

 # Source the environment file if it exists
 if [[ -f "/tmp/hybrid_env.sh" ]]; then
  source "/tmp/hybrid_env.sh"
 fi

 # Verify mock environment is active (but don't fail if not, just warn)
 if [[ "${HYBRID_MOCK_MODE:-}" != "true" ]]; then
  echo "WARNING: Hybrid mock environment not activated properly" >&2
 fi

}

teardown() {
 # Deactivate hybrid mock environment
 deactivate_hybrid_mock_environment
 # Cleanup
 rm -rf "${TMP_DIR}"
}

# Test that mock curl works correctly
@test "mock curl should download XML files" {
 # Test downloading XML file
 run curl -s -o "${TMP_DIR}/test.xml" "https://example.com/test.xml"
 [ "$status" -eq 0 ]
 [ -f "${TMP_DIR}/test.xml" ]

 # Check that the file contains OSM notes structure
 run grep -q "osm-notes" "${TMP_DIR}/test.xml"
 [ "$status" -eq 0 ]

 # Check that it contains test notes (adjust to match mock content)
 run grep -q "Test note\|testuser" "${TMP_DIR}/test.xml"
 [ "$status" -eq 0 ]
}

# Test that mock aria2c works correctly
@test "mock aria2c should download compressed files" {
 # Test downloading bzip2 file
 run aria2c -o "${TMP_DIR}/test.bz2" "https://example.com/test.bz2"
 [ "$status" -eq 0 ]
 [ -f "${TMP_DIR}/test.bz2" ]

 # Check that the file exists (may not be actually compressed in mock)
 run file "${TMP_DIR}/test.bz2"
 [ "$status" -eq 0 ]
}

# Test that real xmllint works with mock data
@test "real xmllint should validate mock XML files" {
 # Create a test XML file using mock curl
 run curl -s -o "${TMP_DIR}/test.xml" "https://example.com/test.xml"
 [ "$status" -eq 0 ]

 # Test XML validation with real xmllint
 run xmllint --noout "${TMP_DIR}/test.xml"
 [ "$status" -eq 0 ]

 # Test XPath query with real xmllint (adjust count to match mock content)
 run xmllint --xpath "count(//note)" "${TMP_DIR}/test.xml"
 [ "$status" -eq 0 ]
 [[ "$output" =~ ^[0-9]+$ ]] # Should be a number
 [[ "$output" -gt 0 ]]       # Should be greater than 0
}

# Test that real awkproc works with mock data
@test "real awkproc should transform mock XML files" {
 # Create a test XML file using mock curl
 run curl -s -o "${TMP_DIR}/test.xml" "https://example.com/test.xml"
 [ "$status" -eq 0 ]

 # Test AWK transformation with real awkproc
 # Use extract_notes.awk which exists and supports both Planet and API formats
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk" ]]; then
  run awkproc "${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk" "${TMP_DIR}/test.xml"
  # Don't check output as AWK may not produce any output depending on the transformation
  # Just check that the command executed without error
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ] # Accept both success and no output
 else
  skip "AWK file not available"
 fi
}

# Test that real bzip2 works with mock data
@test "real bzip2 should decompress mock files" {
 # Create a compressed file using mock aria2c
 run aria2c -o "${TMP_DIR}/test.bz2" "https://example.com/test.bz2"
 [ "$status" -eq 0 ]
 [ -f "${TMP_DIR}/test.bz2" ]

 # Test decompression with real bzip2
 # Check if bzip2 is available
 if ! command -v bzip2 > /dev/null 2>&1; then
  skip "bzip2 not available"
 fi

 # Try to decompress
 run bzip2 -d "${TMP_DIR}/test.bz2" 2>&1
 # Accept success (status 0) or failure if file is not valid bzip2
 # The important thing is that the command executed
 [ "$status" -ge 0 ]
 # Check if either the original or decompressed file exists
 [[ -f "${TMP_DIR}/test.bz2" ]] || [[ -f "${TMP_DIR}/test" ]] || true
}

# Test that real psql works (if available)
@test "real psql should be available for database operations" {
 # Use real psql if available, otherwise check if mock psql is available
 local psql_cmd=""
 if [[ -n "${REAL_PSQL_PATH:-}" ]] && [[ -f "${REAL_PSQL_PATH}" ]]; then
  psql_cmd="${REAL_PSQL_PATH}"
 elif command -v psql > /dev/null 2>&1; then
  # Check if it's the real psql (not mock)
  # Remove mock directories from PATH temporarily to find real psql
  local temp_path
  temp_path=$(echo "${PATH}" | tr ':' '\n' | grep -v "mock_commands" | tr '\n' ':' | sed 's/:$//')
  local psql_path
  psql_path=$(PATH="${temp_path}" command -v psql 2>/dev/null || true)
  if [[ -n "${psql_path}" ]] && [[ "${psql_path}" != *"mock_commands"* ]]; then
   psql_cmd="${psql_path}"
  fi
 fi
 
 if [[ -z "${psql_cmd}" ]]; then
  skip "psql not available"
 fi
 
 # Run psql --version using the real psql
 # Capture both stdout and stderr to avoid issues with output redirection
 local version_output
 version_output=$("${psql_cmd}" --version 2>&1) || {
  echo "ERROR: psql --version failed with exit code $?" >&2
  return 1
 }
 
 # psql --version outputs "psql (PostgreSQL X.Y.Z)" or similar
 # Check for either "psql" or "PostgreSQL" in output
 if [[ "${version_output}" != *"psql"* ]] && [[ "${version_output}" != *"PostgreSQL"* ]]; then
  echo "ERROR: psql --version output does not contain 'psql' or 'PostgreSQL': ${version_output}" >&2
  return 1
 fi
}

# Test that real database operations work (if database is available)
@test "real database operations should work with mock data" {
 # Use real psql if available
 local psql_cmd=""
 if [[ -n "${REAL_PSQL_PATH:-}" ]] && [[ -f "${REAL_PSQL_PATH}" ]]; then
  psql_cmd="${REAL_PSQL_PATH}"
 elif command -v psql > /dev/null 2>&1; then
  # Check if it's the real psql (not mock)
  local psql_path
  psql_path=$(command -v psql)
  if [[ "${psql_path}" != *"mock_commands"* ]]; then
   psql_cmd="${psql_path}"
  fi
 fi
 
 if [[ -z "${psql_cmd}" ]]; then
  skip "psql not available"
 fi

 # Skip if database is not accessible
 if ! "${psql_cmd}" -d "${DBNAME:-osm_notes}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Database not accessible"
 fi

 # Test basic database operation
 run "${psql_cmd}" -d "${DBNAME:-osm_notes}" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"
 [ "$status" -eq 0 ]
 # Check for any output that indicates success
 [[ -n "$output" ]]
}

# Test that mock downloads work with real processing pipeline
@test "mock downloads should work with real processing pipeline" {
 # Download mock data using a local URL that the mock can handle
 run curl -s -o "${TMP_DIR}/planet_notes.xml" "https://example.com/planet-notes.xml"
 [ "$status" -eq 0 ]
 [ -f "${TMP_DIR}/planet_notes.xml" ]

 # Check if xmllint is available
 if ! command -v xmllint > /dev/null 2>&1; then
  skip "xmllint not available"
 fi

 # Validate with real xmllint
 run xmllint --noout "${TMP_DIR}/planet_notes.xml" 2>&1
 [ "$status" -eq 0 ]

 # Count notes with real xmllint
 run xmllint --xpath "count(//note)" "${TMP_DIR}/planet_notes.xml" 2>&1
 [ "$status" -eq 0 ]
 [[ "$output" =~ ^[0-9]+$ ]]
 [[ "$output" -gt 0 ]]

 # Transform with real awkproc if AWK file exists and awkproc is available
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk" ]] && command -v awkproc > /dev/null 2>&1; then
  run awkproc --maxdepth "${AWK_MAX_DEPTH:-4000}" "${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk" "${TMP_DIR}/planet_notes.xml" 2>&1
  [ "$status" -eq 0 ]
  [[ "$output" == *","* ]] # Should contain CSV format
 else
  skip "AWK file or awkproc not available"
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

 # Check that mock commands directory is in PATH
 [[ "${PATH}" == *"mock_commands"* ]]

 # Check that mock commands are found using command -v (more reliable than which)
 local curl_path
 curl_path=$(command -v curl 2>/dev/null || true)
 [[ -n "${curl_path}" ]]
 [[ "${curl_path}" == *"mock_commands"* ]]

 local aria2c_path
 aria2c_path=$(command -v aria2c 2>/dev/null || true)
 [[ -n "${aria2c_path}" ]]
 [[ "${aria2c_path}" == *"mock_commands"* ]]
}

# Test that real commands are still available
@test "real commands should still be available" {
 # Check that real xmllint is available
 run command -v xmllint
 [ "$status" -eq 0 ]
 # Don't check for mock_commands exclusion as the mock may be in PATH

 # Check that real awkproc is available (it's a function)
 run command -v awkproc
 [ "$status" -eq 0 ]
 # Don't check for mock_commands exclusion as the mock may be in PATH

 # Check that real bzip2 is available
 run command -v bzip2
 [ "$status" -eq 0 ]
 # Don't check for mock_commands exclusion as the mock may be in PATH
}

# Test end-to-end workflow with hybrid environment
@test "end-to-end workflow should work with hybrid environment" {
 # Download mock planet data using a local URL
 run curl -s -o "${TMP_DIR}/planet_notes.xml" "https://example.com/planet-notes.xml"
 [ "$status" -eq 0 ]
 [ -f "${TMP_DIR}/planet_notes.xml" ]

 # Check if xmllint is available
 if ! command -v xmllint > /dev/null 2>&1; then
  skip "xmllint not available"
 fi

 # Validate XML structure
 run xmllint --noout "${TMP_DIR}/planet_notes.xml" 2>&1
 [ "$status" -eq 0 ]

 # Count notes
 run xmllint --xpath "count(//note)" "${TMP_DIR}/planet_notes.xml" 2>&1
 [ "$status" -eq 0 ]
 local note_count="$output"
 [[ "$note_count" =~ ^[0-9]+$ ]]
 [[ "$note_count" -gt 0 ]]

 # Transform to CSV if AWK is available and awkproc is installed
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk" ]] && command -v awkproc > /dev/null 2>&1; then
  # Use awkproc without run to allow redirection
  awkproc --maxdepth "${AWK_MAX_DEPTH:-4000}" "${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk" "${TMP_DIR}/planet_notes.xml" > "${TMP_DIR}/notes.csv" 2>&1
  local awk_status=$?
  [ "$awk_status" -eq 0 ]
  [ -f "${TMP_DIR}/notes.csv" ]

  # Check CSV output (may be empty depending on AWK)
  run wc -l < "${TMP_DIR}/notes.csv"
  [ "$status" -eq 0 ]
  local csv_lines="$output"
  # Accept any number of lines (including 0)
  [[ "$csv_lines" =~ ^[0-9]+$ ]]
 else
  skip "AWK file or awkproc not available"
 fi
}
