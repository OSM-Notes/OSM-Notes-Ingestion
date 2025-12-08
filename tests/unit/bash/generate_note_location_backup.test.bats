#!/usr/bin/env bats

# Generate Note Location Backup Script Tests
# Tests for bin/scripts/generateNoteLocationBackup.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR

 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"

 # Create data directory for output files
 mkdir -p "${TEST_BASE_DIR}/data"

 # Set log level to DEBUG
 export LOG_LEVEL="DEBUG"
 export __log_level="DEBUG"
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
 # Clean up data directory files created during tests
 rm -f "${TEST_BASE_DIR}/data/noteLocation.csv"
 rm -f "${TEST_BASE_DIR}/data/noteLocation.csv.zip"
}

@test "generateNoteLocationBackup.sh should check database connection" {
 # Mock psql to simulate connection failure
 psql() {
  if [[ "$1" == "-d" ]] && [[ "$2" == "test_db" ]] && [[ "$3" == "-c" ]]; then
   return 1
  fi
  return 0
 }
 export -f psql

 # Run script and expect failure
 run bash "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" 2>/dev/null
 [[ "${status}" -eq 1 ]]
}

@test "generateNoteLocationBackup.sh should check if notes have country assignment" {
 # Mock psql to return 0 notes with country
 psql() {
  if [[ "$*" == *"SELECT COUNT(*) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "0"
   return 0
  fi
  return 0
 }
 export -f psql

 # Run script and expect failure
 run bash "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" 2>/dev/null
 [[ "${status}" -eq 1 ]]
}

@test "generateNoteLocationBackup.sh should export notes to CSV" {
 # Mock psql to return valid counts and export data
 psql() {
  if [[ "$*" == *"SELECT COUNT(*) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "100"
   return 0
  elif [[ "$*" == *"SELECT MAX(note_id) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "5000"
   return 0
  elif [[ "$*" == *"\COPY"* ]]; then
   # Simulate CSV export
   echo "1,10" > "${TEST_BASE_DIR}/data/noteLocation.csv"
   echo "2,20" >> "${TEST_BASE_DIR}/data/noteLocation.csv"
   return 0
  fi
  return 0
 }
 export -f psql

 # Mock zip command
 zip() {
  if [[ "$1" == "-q" ]] && [[ "$2" == "-j" ]]; then
   local ZIP_FILE="$3"
   local CSV_FILE="$4"
   # Create a mock zip file
   echo "mock zip content" > "${ZIP_FILE}"
   return 0
  fi
  return 1
 }
 export -f zip

 # Run script
 run bash "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" 2>/dev/null
 [[ "${status}" -eq 0 ]]
}

@test "generateNoteLocationBackup.sh should compress CSV to ZIP" {
 # Mock psql
 psql() {
  if [[ "$*" == *"SELECT COUNT(*) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "50"
   return 0
  elif [[ "$*" == *"SELECT MAX(note_id)"* ]]; then
   echo "1000"
   return 0
  elif [[ "$*" == *"\COPY"* ]]; then
   echo "1,10" > "${TEST_BASE_DIR}/data/noteLocation.csv"
   echo "2,20" >> "${TEST_BASE_DIR}/data/noteLocation.csv"
   return 0
  fi
  return 0
 }
 export -f psql

 # Mock zip to create compressed file
 zip() {
  if [[ "$1" == "-q" ]] && [[ "$2" == "-j" ]]; then
   local ZIP_FILE="$3"
   echo "compressed content" > "${ZIP_FILE}"
   return 0
  fi
  return 1
 }
 export -f zip

 # Run script
 run bash "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" 2>/dev/null
 [[ "${status}" -eq 0 ]]
 [[ -f "${TEST_BASE_DIR}/data/noteLocation.csv.zip" ]]
}

@test "generateNoteLocationBackup.sh should remove uncompressed CSV after compression" {
 # Mock psql
 psql() {
  if [[ "$*" == *"SELECT COUNT(*) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "25"
   return 0
  elif [[ "$*" == *"SELECT MAX(note_id)"* ]]; then
   echo "500"
   return 0
  elif [[ "$*" == *"\COPY"* ]]; then
   echo "1,10" > "${TEST_BASE_DIR}/data/noteLocation.csv"
   return 0
  fi
  return 0
 }
 export -f psql

 # Mock zip
 zip() {
  if [[ "$1" == "-q" ]] && [[ "$2" == "-j" ]]; then
   local ZIP_FILE="$3"
   echo "zip content" > "${ZIP_FILE}"
   return 0
  fi
  return 1
 }
 export -f zip

 # Run script
 run bash "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" 2>/dev/null
 [[ "${status}" -eq 0 ]]
 # CSV should be removed after compression
 [[ ! -f "${TEST_BASE_DIR}/data/noteLocation.csv" ]]
 [[ -f "${TEST_BASE_DIR}/data/noteLocation.csv.zip" ]]
}

@test "generateNoteLocationBackup.sh should handle max note_id query" {
 # Mock psql to return max note_id
 psql() {
  if [[ "$*" == *"SELECT COUNT(*) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "100"
   return 0
  elif [[ "$*" == *"SELECT MAX(note_id) FROM notes WHERE id_country IS NOT NULL"* ]]; then
   echo "12345"
   return 0
  elif [[ "$*" == *"\COPY"* ]]; then
   echo "1,10" > "${TEST_BASE_DIR}/data/noteLocation.csv"
   return 0
  fi
  return 0
 }
 export -f psql

 # Mock zip
 zip() {
  if [[ "$1" == "-q" ]] && [[ "$2" == "-j" ]]; then
   local ZIP_FILE="$3"
   echo "zip" > "${ZIP_FILE}"
   return 0
  fi
  return 1
 }
 export -f zip

 # Run script
 run bash "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" 2>/dev/null
 [[ "${status}" -eq 0 ]]
}

