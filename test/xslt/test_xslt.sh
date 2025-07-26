#!/bin/bash
#
# Test the XSLT files to produce the expected output.
#
# xsltproc ../../xslt/note_comments_text-Planet-csv.xslt osm-notes-Planet.xml > note_comments_text-Planet-expected.csv
# xsltproc ../../xslt/note_comments-Planet-csv.xslt osm-notes-Planet.xml > note_comments-Planet-expected.csv
# xsltproc ../../xslt/notes-Planet-csv.xslt osm-notes-Planet.xml > notes-Planet-expected.csv
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-01

XSLT_DIR="../../xslt"

function test() {
 echo "Testing ${TEST} for ${TYPE}."
 xsltproc "${XSLT_DIR}/${TEST}-${TYPE}-csv.xslt" "osm-notes-${TYPE}.xml" > "${TEST}-${TYPE}-actual.csv"
 diff "${TEST}-${TYPE}-actual.csv" "${TEST}-${TYPE}-expected.csv"
 if ! diff "${TEST}-${TYPE}-actual.csv" "${TEST}-${TYPE}-expected.csv" >/dev/null; then
  echo "ERROR: the generated file is different from the expected one - ${TEST}."
 else
  echo "Test passed - ${TEST}."
 fi
 echo
}

# shellcheck disable=SC2035,SC2181
rm -f ./*actual*

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
