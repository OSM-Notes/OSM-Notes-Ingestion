#!/usr/bin/env bats

# Monitoring Infrastructure Tests
# Tests for monitoring scripts and database structure
# Version: 2026-01-02

load ../../test_helper

setup() {
 # Set up test environment
 # Calculate PROJECT_ROOT dynamically based on current working directory
 # This approach works better in BATS context and is more robust
 local current_dir="$(pwd)"
 if [[ "${current_dir}" == */tests/unit/bash* ]]; then
  export PROJECT_ROOT="$(echo "${current_dir}" | sed 's|/tests/unit/bash.*||')"
 elif [[ "${current_dir}" == */tests* ]]; then
  export PROJECT_ROOT="$(echo "${current_dir}" | sed 's|/tests.*||')"
 else
  export PROJECT_ROOT="${current_dir}"
 fi
 # Use peer authentication for host environment
 export TEST_DBNAME="notes_test_monitoring"
 export TEST_DBUSER="$(whoami)"
 export TEST_DBPASSWORD=""
 export TEST_DBHOST=""
 export TEST_DBPORT=""

 # Create test database using peer authentication
 dropdb "${TEST_DBNAME}" 2> /dev/null || true
 createdb "${TEST_DBNAME}" 2> /dev/null || true

 # Load base structure
 psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_21_createBaseTables_enum.sql" 2> /dev/null || true
 psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql" 2> /dev/null || true
 psql -d "${TEST_DBNAME}" -f "${PROJECT_ROOT}/sql/monitor/processCheckPlanetNotes_21_createCheckTables.sql" 2> /dev/null || true
}

teardown() {
 # Clean up test database using peer authentication
 dropdb "${TEST_DBNAME}" 2> /dev/null || true
}

@test "monitoring scripts should exist and be executable" {
 # Check if monitoring scripts exist
 [ -f "${PROJECT_ROOT}/bin/monitor/notesCheckVerifier.sh" ]
 [ -f "${PROJECT_ROOT}/bin/monitor/processCheckPlanetNotes.sh" ]

 # Check if scripts are executable
 [ -x "${PROJECT_ROOT}/bin/monitor/notesCheckVerifier.sh" ]
 [ -x "${PROJECT_ROOT}/bin/monitor/processCheckPlanetNotes.sh" ]
}

@test "monitoring database structure should be correct" {
 # Check if database is available
 load "${BATS_TEST_DIRNAME}/../../test_helper"
 if declare -f __skip_if_no_database > /dev/null 2>&1; then
  __skip_if_no_database "${TEST_DBNAME}" "Database not available"
 else
  # Fallback: check psql availability
  if ! command -v psql > /dev/null 2>&1; then
   skip "psql not available"
  fi
  if ! psql -d "${TEST_DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
   skip "Database ${TEST_DBNAME} not accessible"
  fi
 fi

 # Check if check tables exist after setup
 run psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "
 SELECT table_name FROM information_schema.tables 
 WHERE table_schema = 'public' 
 AND table_name LIKE '%_check'
 ORDER BY table_name;
 "

 [ "$status" -eq 0 ]
 [[ "$output" =~ "notes_check" ]]
 [[ "$output" =~ "note_comments_check" ]]
 [[ "$output" =~ "note_comments_text_check" ]]
}
