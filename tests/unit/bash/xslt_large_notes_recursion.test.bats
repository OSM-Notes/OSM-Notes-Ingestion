#!/usr/bin/env bats

# XSLT large Planet notes recursion safeguard tests
# Ensures xsltproc handles deep recursion by using configured max depth
# Author: Andres Gomez (AngocA)
# Version: 2025-08-18

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

setup() {
  export XSLT_DIR="${SCRIPT_BASE_DIRECTORY}/xslt"
  export FIXTURES_DIR="${SCRIPT_BASE_DIRECTORY}/tests/fixtures/xml"
  export OUTPUT_DIR="${TEST_TMP_DIR}/xslt_large_outputs"
  mkdir -p "${OUTPUT_DIR}"
}

teardown() {
  rm -rf "${OUTPUT_DIR}" 2>/dev/null || true
}

@test "xsltproc processes large Planet notes (notes CSV) without recursion error" {
  local xml_file="${FIXTURES_DIR}/large_planet_notes.xml"
  [ -f "${xml_file}" ]

  local xslt_file="${XSLT_DIR}/notes-Planet-csv.xslt"
  local out_file="${OUTPUT_DIR}/notes.csv"

  run xsltproc --maxdepth "${XSLT_MAX_DEPTH:-4000}" "${xslt_file}" "${xml_file}"
  [ "$status" -eq 0 ]

  # Redirect output to file in a second run to assert content
  xsltproc --maxdepth "${XSLT_MAX_DEPTH:-4000}" "${xslt_file}" "${xml_file}" > "${out_file}"
  [ -f "${out_file}" ]
  [ "$(wc -l < "${out_file}")" -ge 1 ]
}

@test "xsltproc processes large Planet notes (comments CSV) without recursion error" {
  local xml_file="${FIXTURES_DIR}/large_planet_notes.xml"
  [ -f "${xml_file}" ]

  local xslt_file="${XSLT_DIR}/note_comments-Planet-csv.xslt"
  local out_file="${OUTPUT_DIR}/comments.csv"

  run xsltproc --maxdepth "${XSLT_MAX_DEPTH:-4000}" "${xslt_file}" "${xml_file}"
  [ "$status" -eq 0 ]

  xsltproc --maxdepth "${XSLT_MAX_DEPTH:-4000}" "${xslt_file}" "${xml_file}" > "${out_file}"
  [ -f "${out_file}" ]
  [ "$(wc -l < "${out_file}")" -ge 1 ]
}

@test "xsltproc processes large Planet notes (text comments CSV) without recursion error" {
  local xml_file="${FIXTURES_DIR}/large_planet_notes.xml"
  [ -f "${xml_file}" ]

  local xslt_file="${XSLT_DIR}/note_comments_text-Planet-csv.xslt"
  local out_file="${OUTPUT_DIR}/text_comments.csv"

  run xsltproc --maxdepth "${XSLT_MAX_DEPTH:-4000}" "${xslt_file}" "${xml_file}"
  [ "$status" -eq 0 ]

  xsltproc --maxdepth "${XSLT_MAX_DEPTH:-4000}" "${xslt_file}" "${xml_file}" > "${out_file}"
  [ -f "${out_file}" ]
  [ "$(wc -l < "${out_file}")" -ge 1 ]
}


