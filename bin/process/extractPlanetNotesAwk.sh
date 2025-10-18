#!/bin/bash
# Extracts notes, comments, and comment texts from OSM Planet XML using AWK.
# This script replaces XSLT-based extraction for better performance and
# simpler dependencies.
#
# Usage:
#   extractPlanetNotesAwk.sh <input_xml> <output_dir>
#
# Parameters:
#   input_xml: Path to Planet notes XML file (.xml or .xml.bz2)
#   output_dir: Directory where CSV files will be created
#
# Output files:
#   - <output_dir>/notes.csv
#   - <output_dir>/note_comments.csv
#   - <output_dir>/note_comments_text.csv
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-18

set -e
set -u
set -o pipefail

# Import logger if available
if [[ -n "${SCRIPT_BASE_DIRECTORY:-}" ]] && [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh" ]]; then
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/bash_logger.sh"
else
 # Fallback logger
 __log() { echo "$1: $2"; }
fi

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
# AWK scripts are in awk/ directory (project root)
readonly AWK_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)/awk"
readonly EXTRACT_NOTES_AWK="${AWK_DIR}/extract_notes.awk"
readonly EXTRACT_COMMENTS_AWK="${AWK_DIR}/extract_comments.awk"
readonly EXTRACT_TEXTS_AWK="${AWK_DIR}/extract_comment_texts.awk"

###############################################################################
# Validates that required AWK scripts exist.
#
# Returns:
#   0 if all scripts exist, 1 otherwise
###############################################################################
__validate_awk_scripts() {
 local -i ret=0

 if [[ ! -f "${EXTRACT_NOTES_AWK}" ]]; then
  __log ERROR "AWK script not found: ${EXTRACT_NOTES_AWK}"
  ret=1
 fi

 if [[ ! -f "${EXTRACT_COMMENTS_AWK}" ]]; then
  __log ERROR "AWK script not found: ${EXTRACT_COMMENTS_AWK}"
  ret=1
 fi

 if [[ ! -f "${EXTRACT_TEXTS_AWK}" ]]; then
  __log ERROR "AWK script not found: ${EXTRACT_TEXTS_AWK}"
  ret=1
 fi

 return "${ret}"
}

###############################################################################
# Extracts data from Planet XML to CSV files.
#
# Parameters:
#   $1: Input XML file (can be .bz2)
#   $2: Output directory
###############################################################################
__extract_planet_data() {
 local -r INPUT_FILE="${1}"
 local -r OUTPUT_DIR="${2}"

 __log INFO "Starting AWK-based extraction"
 __log INFO "Input: ${INPUT_FILE}"
 __log INFO "Output: ${OUTPUT_DIR}"

 # Create output directory
 mkdir -p "${OUTPUT_DIR}"

 # Determine decompression command
 local decompress_cmd="cat"
 if [[ "${INPUT_FILE}" == *.bz2 ]]; then
  decompress_cmd="bzcat"
  __log DEBUG "Detected bzip2 compression, using bzcat"
 elif [[ "${INPUT_FILE}" == *.gz ]]; then
  decompress_cmd="zcat"
  __log DEBUG "Detected gzip compression, using zcat"
 fi

 # Extract notes
 __log INFO "Extracting notes to ${OUTPUT_DIR}/notes.csv"
 ${decompress_cmd} "${INPUT_FILE}" \
  | awk -f "${EXTRACT_NOTES_AWK}" \
   > "${OUTPUT_DIR}/notes.csv"

 local notes_count
 notes_count=$(wc -l < "${OUTPUT_DIR}/notes.csv" || true)
 __log INFO "Extracted ${notes_count} notes"

 # Extract comments
 __log INFO "Extracting comments to ${OUTPUT_DIR}/note_comments.csv"
 ${decompress_cmd} "${INPUT_FILE}" \
  | awk -f "${EXTRACT_COMMENTS_AWK}" \
   > "${OUTPUT_DIR}/note_comments.csv"

 local comments_count
 comments_count=$(wc -l < "${OUTPUT_DIR}/note_comments.csv" || true)
 __log INFO "Extracted ${comments_count} comments"

 # Extract comment texts
 __log INFO "Extracting comment texts to ${OUTPUT_DIR}/note_comments_text.csv"
 ${decompress_cmd} "${INPUT_FILE}" \
  | awk -f "${EXTRACT_TEXTS_AWK}" \
   > "${OUTPUT_DIR}/note_comments_text.csv"

 local texts_count
 texts_count=$(wc -l < "${OUTPUT_DIR}/note_comments_text.csv" || true)
 __log INFO "Extracted ${texts_count} comment texts"

 __log INFO "Extraction complete"
}

###############################################################################
# Main function
###############################################################################
main() {
 if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <input_xml> <output_dir>"
  echo ""
  echo "Example:"
  echo "  $0 planet-notes.osn.bz2 /tmp/output"
  exit 1
 fi

 local -r INPUT_FILE="${1}"
 local -r OUTPUT_DIR="${2}"

 # Validate input
 if [[ ! -f "${INPUT_FILE}" ]]; then
  __log ERROR "Input file not found: ${INPUT_FILE}"
  exit 1
 fi

 # Validate AWK scripts
 __validate_awk_scripts || {
  __log ERROR "Required AWK scripts not found"
  exit 1
 }

 # Extract data
 __extract_planet_data "${INPUT_FILE}" "${OUTPUT_DIR}"

 __log INFO "All CSV files created successfully in ${OUTPUT_DIR}"
}

# Execute main if script is run directly
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
 main "$@"
fi
