#!/bin/bash
#
# Test the XSLT files to produce the expected output.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-01

XSLT_DIR="../../xslt"

function test() {
 echo "Testing ${TEST} for ${TYPE}."
 xsltproc "${XSLT_DIR}/${TEST}-${TYPE}-csv.xslt" "osm-notes-${TYPE}.xml" > "${TEST}-${TYPE}-actual.csv"
 diff "${TEST}-${TYPE}-actual.csv" "${TEST}-${TYPE}-expected.csv"
 if [ "${?}" -ne 0 ]; then
  echo "ERROR: the generated file is different from the expected one - ${TEST}."
 else
  echo "Test passed - ${TEST}."
 fi
 echo
}

rm -f *actual*

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

