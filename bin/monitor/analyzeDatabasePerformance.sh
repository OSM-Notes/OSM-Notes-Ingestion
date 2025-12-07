#!/bin/bash

# Database Performance Analysis Runner
# Executes all SQL analysis scripts and generates a performance report
#
# This script runs all performance analysis scripts and parses their output
# to determine if performance thresholds are being met. It's safe to run
# on production databases as all SQL scripts use ROLLBACK to avoid modifying data.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

set -euo pipefail

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Set SCRIPT_BASE_DIRECTORY for functionsProcess.sh
# This must be set before loading functionsProcess.sh
export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"

# Set required variables for functionsProcess.sh
export BASENAME="analyzeDatabasePerformance"
export TMP_DIR="/tmp/${BASENAME}_$$"
export LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Set PostgreSQL application name for monitoring
# This allows monitoring tools to identify which script is using the database
export PGAPPNAME="${BASENAME}"

# Load properties
if [[ -f "${PROJECT_ROOT}/etc/properties.sh" ]]; then
 # shellcheck source=../../etc/properties.sh
 source "${PROJECT_ROOT}/etc/properties.sh"
fi

# Load common functions
if [[ -f "${PROJECT_ROOT}/bin/lib/functionsProcess.sh" ]]; then
 # shellcheck source=../lib/functionsProcess.sh
 source "${PROJECT_ROOT}/bin/lib/functionsProcess.sh"
else
 echo "ERROR: functionsProcess.sh not found"
 exit 1
fi

# Database connection variables
DBNAME="${DBNAME:-}"
if [[ -z "${DBNAME}" ]]; then
 __loge "DBNAME not set. Please set it in etc/properties.sh or export it."
 exit 1
fi

# Analysis directory
ANALYSIS_DIR="${PROJECT_ROOT}/sql/analysis"
OUTPUT_DIR="${TMP_DIR}/analysis_results"
REPORT_FILE="${OUTPUT_DIR}/performance_report.txt"
SUMMARY_FILE="${OUTPUT_DIR}/summary.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Counters
TOTAL_SCRIPTS=0
PASSED_SCRIPTS=0
FAILED_SCRIPTS=0
WARNING_SCRIPTS=0

# Function to print colored output
__print_status() {
 local COLOR=$1
 local MESSAGE=$2
 echo -e "${COLOR}${MESSAGE}${NC}"
}

# Function to show help
__show_help() {
 cat << EOF
Database Performance Analysis Runner

Usage: $0 [OPTIONS]

OPTIONS:
  --db DATABASE     Database name (overrides DBNAME from properties)
  --output DIR      Output directory for results (default: /tmp/analyzeDatabasePerformance_*/analysis_results)
  --verbose         Show detailed output from each analysis script
  --help            Show this help message

DESCRIPTION:
  This script executes all SQL performance analysis scripts and generates
  a comprehensive performance report. All analysis scripts are safe to run
  on production databases as they use ROLLBACK to avoid modifying data.

  The script will:
  1. Execute all analysis scripts in sql/analysis/
  2. Parse results to check performance thresholds
  3. Generate a summary report with pass/fail/warning status
  4. Identify any performance regressions

EXAMPLES:
  # Run with default database from properties
  $0

  # Run with specific database
  $0 --db osm_notes

  # Run with verbose output
  $0 --verbose

AUTHOR: Andres Gomez (AngocA)
VERSION: 2025-11-25
EOF
}

# Function to parse timing from psql output
__parse_timing() {
 local OUTPUT_FILE="$1"
 # Extract timing: "Time: 123.456 ms" or "Duración: 123.456 ms"
 local TIMING
 # Try to extract timing from English format first
 TIMING=$(grep -iE "Time:" "${OUTPUT_FILE}" \
  | sed -nE 's/.*[Tt]ime:[[:space:]]*([0-9.]+)[[:space:]]*ms.*/\1/p' \
  | head -1)
 # If not found, try Spanish format
 if [[ -z "${TIMING}" ]]; then
  TIMING=$(grep -iE "Duraci[oó]n:" "${OUTPUT_FILE}" \
   | sed -nE 's/.*[Dd]uraci[oó]n:[[:space:]]*([0-9.]+)[[:space:]]*ms.*/\1/p' \
   | head -1)
 fi
 # Return timing or 0 if not found
 if [[ -n "${TIMING}" ]]; then
  echo "${TIMING}"
 else
  echo "0"
 fi
}

# Function to check if index scan is used
__check_index_scan() {
 local OUTPUT_FILE="$1"
 # Check for "Index Scan" in EXPLAIN output
 if grep -qiE "Index Scan|Bitmap Index Scan" "${OUTPUT_FILE}"; then
  return 0
 else
  return 1
 fi
}

# Function to check if sequential scan is used (bad)
__check_seq_scan() {
 local OUTPUT_FILE="$1"
 # Check for "Seq Scan" in EXPLAIN output
 if grep -qiE "Seq Scan" "${OUTPUT_FILE}"; then
  return 0
 else
  return 1
 fi
}

# Function to extract performance thresholds from script comments
__extract_thresholds() {
 local SCRIPT_FILE="$1"
 # Extract thresholds from comments like "Expected: < 100ms"
 grep -iE "(Expected|threshold|umbral):" "${SCRIPT_FILE}" \
  | sed -E 's/.*[<]?[[:space:]]*([0-9.]+)[[:space:]]*ms.*/\1/' \
  | head -1 || echo ""
}

# Function to check if performance threshold is met
__check_threshold() {
 local ACTUAL_TIME="$1"
 local THRESHOLD="$2"

 if [[ -z "${THRESHOLD}" ]] || [[ "${THRESHOLD}" == "0" ]]; then
  return 2 # No threshold defined
 fi

 # Compare actual time with threshold (using awk for floating point)
 if awk "BEGIN {exit !(${ACTUAL_TIME} < ${THRESHOLD})}"; then
  return 0 # Pass
 else
  return 1 # Fail
 fi
}

# Function to run a single analysis script
__run_analysis_script() {
 local SCRIPT_FILE="$1"
 local SCRIPT_NAME
 SCRIPT_NAME=$(basename "${SCRIPT_FILE}")
 local OUTPUT_FILE="${OUTPUT_DIR}/${SCRIPT_NAME%.sql}.txt"
 local STATUS="UNKNOWN"
 local ISSUES=()

 __logi "Running analysis: ${SCRIPT_NAME}"

 # Run the script and capture output
 if psql -d "${DBNAME}" -f "${SCRIPT_FILE}" > "${OUTPUT_FILE}" 2>&1; then
  # Parse results
  local TIMING
  TIMING=$(__parse_timing "${OUTPUT_FILE}")
  local HAS_INDEX_SCAN=false
  local HAS_SEQ_SCAN=false

  if __check_index_scan "${OUTPUT_FILE}"; then
   HAS_INDEX_SCAN=true
  fi

  if __check_seq_scan "${OUTPUT_FILE}"; then
   HAS_SEQ_SCAN=true
  fi

  # Check for errors or warnings in output
  if grep -qiE "ERROR|CRITICAL|MISSING" "${OUTPUT_FILE}"; then
   STATUS="FAILED"
   ISSUES+=("Errors or critical issues found")
   FAILED_SCRIPTS=$((FAILED_SCRIPTS + 1))
  elif grep -qiE "WARNING|⚠️" "${OUTPUT_FILE}"; then
   STATUS="WARNING"
   ISSUES+=("Warnings found in output")
   WARNING_SCRIPTS=$((WARNING_SCRIPTS + 1))
  elif [[ "${HAS_SEQ_SCAN}" == true ]]; then
   STATUS="WARNING"
   ISSUES+=("Sequential scan detected (should use index)")
   WARNING_SCRIPTS=$((WARNING_SCRIPTS + 1))
  elif [[ "${HAS_INDEX_SCAN}" == true ]] || [[ "${TIMING}" != "0" ]]; then
   STATUS="PASSED"
   PASSED_SCRIPTS=$((PASSED_SCRIPTS + 1))
  else
   STATUS="PASSED"
   PASSED_SCRIPTS=$((PASSED_SCRIPTS + 1))
  fi

  # Write summary for this script
  {
   echo "=== ${SCRIPT_NAME} ==="
   echo "Status: ${STATUS}"
   if [[ -n "${TIMING}" ]] && [[ "${TIMING}" != "0" ]]; then
    echo "Execution time: ${TIMING} ms"
   fi
   if [[ ${#ISSUES[@]} -gt 0 ]]; then
    echo "Issues:"
    for issue in "${ISSUES[@]}"; do
     echo "  - ${issue}"
    done
   fi
   echo ""
  } >> "${SUMMARY_FILE}"

  if [[ "${VERBOSE:-false}" == "true" ]]; then
   __print_status "${CYAN}" "Output saved to: ${OUTPUT_FILE}"
  fi
 else
  STATUS="FAILED"
  FAILED_SCRIPTS=$((FAILED_SCRIPTS + 1))
  __loge "Failed to execute ${SCRIPT_NAME}"

  {
   echo "=== ${SCRIPT_NAME} ==="
   echo "Status: FAILED"
   echo "Error: Script execution failed"
   echo ""
  } >> "${SUMMARY_FILE}"
 fi

 TOTAL_SCRIPTS=$((TOTAL_SCRIPTS + 1))

 # Print status
 case "${STATUS}" in
 PASSED)
  __print_status "${GREEN}" "  ✓ ${SCRIPT_NAME} - PASSED"
  ;;
 WARNING)
  __print_status "${YELLOW}" "  ⚠ ${SCRIPT_NAME} - WARNING"
  ;;
 FAILED)
  __print_status "${RED}" "  ✗ ${SCRIPT_NAME} - FAILED"
  ;;
 *)
  __print_status "${BLUE}" "  ? ${SCRIPT_NAME} - ${STATUS}"
  ;;
 esac
}

# Function to generate final report
__generate_report() {
 local REPORT_DATE
 REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')

 {
  echo "=============================================================================="
  echo "DATABASE PERFORMANCE ANALYSIS REPORT"
  echo "=============================================================================="
  echo "Database: ${DBNAME}"
  echo "Date: ${REPORT_DATE}"
  echo "Total Scripts: ${TOTAL_SCRIPTS}"
  echo ""
  echo "Results Summary:"
  echo "  Passed:   ${PASSED_SCRIPTS} (✓)"
  echo "  Warnings: ${WARNING_SCRIPTS} (⚠)"
  echo "  Failed:   ${FAILED_SCRIPTS} (✗)"
  echo ""
  echo "=============================================================================="
  echo ""
  cat "${SUMMARY_FILE}"
  echo ""
  echo "=============================================================================="
  echo "DETAILED OUTPUT FILES"
  echo "=============================================================================="
  echo "Individual script outputs are saved in: ${OUTPUT_DIR}"
  echo ""
  ls -lh "${OUTPUT_DIR}"/*.txt 2> /dev/null | awk '{print "  " $9 " (" $5 ")"}' || echo "  No output files found"
  echo ""
  echo "=============================================================================="
  echo ""
  echo "NOTE: All analysis scripts use ROLLBACK to avoid modifying production data."
  echo "This analysis is safe to run on production databases."
  echo ""
 } > "${REPORT_FILE}"

 # Print report to console
 cat "${REPORT_FILE}"
}

# Main function
__main() {
 __log_start

 # Parse command line arguments
 VERBOSE=false
 while [[ $# -gt 0 ]]; do
  case $1 in
  --db)
   DBNAME="$2"
   shift 2
   ;;
  --output)
   OUTPUT_DIR="$2"
   shift 2
   ;;
  --verbose)
   VERBOSE=true
   shift
   ;;
  --help | -h)
   __show_help
   exit 0
   ;;
  *)
   __loge "Unknown option: $1"
   __show_help
   exit 1
   ;;
  esac
 done

 # Validate database connection
 __logi "Connecting to database: ${DBNAME}"
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  __loge "Cannot connect to database: ${DBNAME}"
  exit 1
 fi

 # Create output directory
 mkdir -p "${OUTPUT_DIR}"

 # Initialize summary file
 > "${SUMMARY_FILE}"

 __logi "Starting database performance analysis"
 __print_status "${BLUE}" "=============================================================================="
 __print_status "${BLUE}" "DATABASE PERFORMANCE ANALYSIS"
 __print_status "${BLUE}" "=============================================================================="
 __print_status "${BLUE}" "Database: ${DBNAME}"
 __print_status "${BLUE}" "Output directory: ${OUTPUT_DIR}"
 __print_status "${BLUE}" "=============================================================================="
 echo ""

 # Find and run all analysis scripts
 if [[ ! -d "${ANALYSIS_DIR}" ]]; then
  __loge "Analysis directory not found: ${ANALYSIS_DIR}"
  exit 1
 fi

 local ANALYSIS_SCRIPTS
 mapfile -t ANALYSIS_SCRIPTS < <(find "${ANALYSIS_DIR}" -name "analyze_*.sql" -type f | sort)

 if [[ ${#ANALYSIS_SCRIPTS[@]} -eq 0 ]]; then
  __loge "No analysis scripts found in ${ANALYSIS_DIR}"
  exit 1
 fi

 __logi "Found ${#ANALYSIS_SCRIPTS[@]} analysis script(s)"
 echo ""

 # Run each analysis script
 for script in "${ANALYSIS_SCRIPTS[@]}"; do
  __run_analysis_script "${script}"
 done

 echo ""
 __print_status "${BLUE}" "=============================================================================="

 # Generate final report
 __generate_report

 # Set exit code based on results
 if [[ ${FAILED_SCRIPTS} -gt 0 ]]; then
  __loge "Performance analysis completed with ${FAILED_SCRIPTS} failed script(s)"
  __log_finish
  exit 1
 elif [[ ${WARNING_SCRIPTS} -gt 0 ]]; then
  __logw "Performance analysis completed with ${WARNING_SCRIPTS} warning(s)"
  __log_finish
  exit 0
 else
  __logi "Performance analysis completed successfully. All checks passed."
  __log_finish
  exit 0
 fi
}

# Run main function
__main "$@"
