#!/bin/bash
# XSLT Profile Analyzer Script
# This script demonstrates how to use XSLT profiling for performance optimization
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-16
# Description: Analyze XSLT performance profiles and generate optimization reports

set -euo pipefail

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../etc/properties.sh"
source "${SCRIPT_DIR}/commonFunctions.sh"
source "${SCRIPT_DIR}/parallelProcessingFunctions.sh"

# Function to display usage information
function __show_usage() {
 cat << EOF
XSLT Profile Analyzer - Performance Optimization Tool

Usage: $0 [OPTIONS] COMMAND [ARGS]

Commands:
  analyze <profile_file> [format]     Analyze a single profile file
  report <profile_dir> [output_file]  Generate report from multiple profiles
  enable <xml_file> <xslt_file>       Process XML with profiling enabled
  compare <dir1> <dir2>               Compare performance between two directories

Options:
  -h, --help                          Show this help message
  -v, --verbose                       Enable verbose output
  -f, --format <format>               Output format: summary, detailed, csv

Formats:
  summary                             Brief performance summary (default)
  detailed                            Detailed performance information
  csv                                 CSV format for data analysis

Examples:
  # Analyze a single profile file
  $0 analyze output.csv.profile

  # Generate detailed analysis
  $0 analyze output.csv.profile detailed

  # Generate performance report from all profiles in directory
  $0 report /tmp/profiles/ performance_report.txt

  # Process XML with profiling enabled
  $0 enable input.xml transform.xslt

  # Compare performance between two processing runs
  $0 compare /tmp/run1/ /tmp/run2/

EOF
}

# Function to analyze a single profile
function __analyze_profile() {
 local PROFILE_FILE="${1}"
 local FORMAT="${2:-summary}"

 if [[ ! -f "${PROFILE_FILE}" ]]; then
  __loge "Profile file not found: ${PROFILE_FILE}"
  return 1
 fi

 __logi "Analyzing profile: ${PROFILE_FILE}"
 __analyze_xslt_profile "${PROFILE_FILE}" "${FORMAT}"
}

# Function to generate performance report
function __generate_report() {
 local PROFILE_DIR="${1}"
 local OUTPUT_FILE="${2:-}"

 if [[ ! -d "${PROFILE_DIR}" ]]; then
  __loge "Profile directory not found: ${PROFILE_DIR}"
  return 1
 fi

 __logi "Generating performance report from: ${PROFILE_DIR}"
 __generate_performance_report "${PROFILE_DIR}" "${OUTPUT_FILE}"
}

# Function to process XML with profiling enabled
function __process_with_profiling() {
 local XML_FILE="${1}"
 local XSLT_FILE="${2}"
 local OUTPUT_FILE="${3:-}"

 if [[ ! -f "${XML_FILE}" ]]; then
  __loge "XML file not found: ${XML_FILE}"
  return 1
 fi

 if [[ ! -f "${XSLT_FILE}" ]]; then
  __loge "XSLT file not found: ${XSLT_FILE}"
  return 1
 fi

 # Generate output filename if not provided
 if [[ -z "${OUTPUT_FILE}" ]]; then
  local BASE_NAME
  BASE_NAME=$(basename "${XML_FILE}" .xml)
  OUTPUT_FILE="/tmp/${BASE_NAME}_profiled.csv"
 fi

 __logi "Processing XML with profiling enabled:"
 __logd "  Input: ${XML_FILE}"
 __logd "  XSLT: ${XSLT_FILE}"
 __logd "  Output: ${OUTPUT_FILE}"

 # Process with profiling enabled
 __logd "ENABLE_XSLT_PROFILING before call: '${ENABLE_XSLT_PROFILING:-false}'"
 __logd "Calling __process_xml_with_xslt_robust with 6 parameters: '${XML_FILE}' '${XSLT_FILE}' '${OUTPUT_FILE}' '' '' 'true'"

 if __process_xml_with_xslt_robust "${XML_FILE}" "${XSLT_FILE}" "${OUTPUT_FILE}" "" "" "true"; then
  __logi "Processing completed successfully"
  __logi "Profile saved to: ${OUTPUT_FILE}.profile"

  # Analyze the generated profile
  __logi "=== PERFORMANCE ANALYSIS ==="
  __analyze_xslt_profile "${OUTPUT_FILE}.profile" "summary"
 else
  __loge "Processing failed"
  return 1
 fi
}

# Function to compare performance between two directories
function __compare_performance() {
 local DIR1="${1}"
 local DIR2="${2}"

 if [[ ! -d "${DIR1}" ]] || [[ ! -d "${DIR2}" ]]; then
  __loge "One or both directories not found"
  return 1
 fi

 __logi "Comparing performance between:"
 __logd "  Directory 1: ${DIR1}"
 __logd "  Directory 2: ${DIR2}"

 # Generate reports for both directories
 local REPORT1="/tmp/performance_report_1.txt"
 local REPORT2="/tmp/performance_report_2.txt"

 __generate_performance_report "${DIR1}" "${REPORT1}"
 __generate_performance_report "${DIR2}" "${REPORT2}"

 # Display comparison
 __logi "=== PERFORMANCE COMPARISON ==="
 echo "Directory 1 (${DIR1}):"
 cat "${REPORT1}" 2> /dev/null || echo "No profiles found"
 echo ""
 echo "Directory 2 (${DIR2}):"
 cat "${REPORT2}" 2> /dev/null || echo "No profiles found"

 # Cleanup temporary files
 rm -f "${REPORT1}" "${REPORT2}"
}

# Main function
function __main() {
 local COMMAND="${1:-}"

 case "${COMMAND}" in
 "analyze")
  if [[ $# -lt 2 ]]; then
   __loge "Missing profile file argument"
   __show_usage
   exit 1
  fi
  __analyze_profile "${2}" "${3:-summary}"
  ;;
 "report")
  if [[ $# -lt 2 ]]; then
   __loge "Missing profile directory argument"
   __show_usage
   exit 1
  fi
  __generate_report "${2}" "${3:-}"
  ;;
 "enable")
  if [[ $# -lt 3 ]]; then
   __loge "Missing XML and XSLT file arguments"
   __show_usage
   exit 1
  fi
  __process_with_profiling "${2}" "${3}" "${4:-}"
  ;;
 "compare")
  if [[ $# -lt 3 ]]; then
   __loge "Missing directory arguments for comparison"
   __show_usage
   exit 1
  fi
  __compare_performance "${2}" "${3}"
  ;;
 "-h" | "--help" | "help")
  __show_usage
  ;;
 "")
  __loge "No command specified"
  __show_usage
  exit 1
  ;;
 *)
  __loge "Unknown command: ${COMMAND}"
  __show_usage
  exit 1
  ;;
 esac
}

# Run main function with all arguments
__main "$@"
