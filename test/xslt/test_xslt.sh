#!/bin/bash
#
# Test the XSLT files to produce the expected output.
#
# xsltproc ../../xslt/note_comments_text-Planet-csv.xslt osm-notes-Planet.xml > note_comments_text-Planet-expected.csv
# xsltproc ../../xslt/note_comments-Planet-csv.xslt osm-notes-Planet.xml > note_comments-Planet-expected.csv
# xsltproc ../../xslt/notes-Planet-csv.xslt osm-notes-Planet.xml > notes-Planet-expected.csv
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-26

XSLT_DIR="../../xslt"
TEST_OUTPUT_DIR="./test_output"

function test() {
 echo "Testing ${TEST} for ${TYPE}."
 # Create test output directory if it doesn't exist
 mkdir -p "${TEST_OUTPUT_DIR}"
 
 # Generate actual CSV file in test output directory
 xsltproc "${XSLT_DIR}/${TEST}-${TYPE}-csv.xslt" "osm-notes-${TYPE}.xml" > "${TEST_OUTPUT_DIR}/${TEST}-${TYPE}-actual.csv"
 
 # Compare with expected file
 if [[ -f "${TEST}-${TYPE}-expected.csv" ]]; then
  diff "${TEST_OUTPUT_DIR}/${TEST}-${TYPE}-actual.csv" "${TEST}-${TYPE}-expected.csv"
  if ! diff "${TEST_OUTPUT_DIR}/${TEST}-${TYPE}-actual.csv" "${TEST}-${TYPE}-expected.csv" > /dev/null; then
   echo "ERROR: the generated file is different from the expected one - ${TEST}."
  else
   echo "Test passed - ${TEST}."
  fi
 else
  echo "WARNING: Expected file not found - ${TEST}-${TYPE}-expected.csv"
 fi
 echo
}

# Clean up previous test output
# shellcheck disable=SC2035,SC2181
rm -rf "${TEST_OUTPUT_DIR}"

TEST="note_comments_text"
TYPE="Planet"
test
TYPE="API"
test
echo

TEST="note_comments"
TYPE="Planet"
test
TYPE="API"
test
echo

TEST="notes"
TYPE="Planet"
test
TYPE="API"
test
