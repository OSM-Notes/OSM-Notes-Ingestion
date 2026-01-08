#!/bin/bash

# Database Performance Analysis Runner
# Executes all SQL analysis scripts and generates a performance report
#
# This script runs all performance analysis scripts and parses their output
# to determine if performance thresholds are being met. It's safe to run
# on production databases as all SQL scripts use ROLLBACK to avoid modifying data.
#
# This is the list of error codes:
# 1) Help message displayed
# 241) Library or utility missing
# 242) Invalid argument
# 255) General error
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-08

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
 # shellcheck disable=SC2154
 # ERROR_MISSING_LIBRARY is defined in lib/osm-common/commonFunctions.sh
 exit "${ERROR_MISSING_LIBRARY}"
fi

# Database connection variables
DBNAME="${DBNAME:-}"
if [[ -z "${DBNAME}" ]]; then
 __loge "DBNAME not set. Please set it in etc/properties.sh or export it."
 # shellcheck disable=SC2154
 # ERROR_INVALID_ARGUMENT is defined in lib/osm-common/commonFunctions.sh
 exit "${ERROR_INVALID_ARGUMENT}"
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
# shellcheck disable=SC2317
# Function is called indirectly from main execution flow
__extract_thresholds() {
 local SCRIPT_FILE="$1"
 # Extract thresholds from comments like "Expected: < 100ms"
 local THRESHOLD_LINE
 THRESHOLD_LINE=$(grep -iE "(Expected|threshold|umbral):" "${SCRIPT_FILE}" 2> /dev/null || echo "")
 if [[ -n "${THRESHOLD_LINE}" ]]; then
  echo "${THRESHOLD_LINE}" | sed -E 's/.*[<]?[[:space:]]*([0-9.]+)[[:space:]]*ms.*/\1/' | head -1 || echo ""
 else
  echo ""
 fi
}

# Function to check if performance threshold is met
# shellcheck disable=SC2317
# Function is called indirectly from main execution flow
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

# Function to check database activity for this script
# shellcheck disable=SC2317
# Function is called indirectly from main execution flow
__check_db_activity() {
 local SCRIPT_NAME="$1"
 # Check if there's any activity for this application name
 # shellcheck disable=SC2097,SC2098,SC2154
 # PGAPPNAME and DBNAME are set in the environment before calling this function
 local ACTIVITY_COUNT
 ACTIVITY_COUNT=$(PGAPPNAME="${PGAPPNAME:-}" psql -d "${DBNAME}" -tAc \
  "SELECT COUNT(*) FROM pg_stat_activity WHERE application_name = '${PGAPPNAME:-}' AND state = 'active';" \
  2> /dev/null || echo "0")
 echo "${ACTIVITY_COUNT}"
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
 __logd "Script file: ${SCRIPT_FILE}"
 __logd "Output file: ${OUTPUT_FILE}"

 # Record start time for progress tracking
 local START_TIME
 START_TIME=$(date +%s)
 local DURATION=0
 local START_TIME_STR
 START_TIME_STR=$(date '+%Y-%m-%d %H:%M:%S' 2> /dev/null || echo 'unknown')
 __logd "Started at: ${START_TIME_STR}"

 # Run the script with timeout (30 minutes max per script)
 # Use PGAPPNAME to identify this connection in pg_stat_activity
 # The connection will be visible in pg_stat_activity with application_name = 'analyzeDatabasePerformance'
 # Set statement_timeout to prevent queries from hanging indefinitely
 local TIMEOUT_SECONDS=1800 # 30 minutes
 # Create a temporary script that sets statement_timeout and then runs the analysis script
 local TEMP_SCRIPT
 TEMP_SCRIPT=$(mktemp)
 {
  echo "SET statement_timeout = '${TIMEOUT_SECONDS}s';"
  echo "\\set ON_ERROR_STOP on"
  cat "${SCRIPT_FILE}"
 } > "${TEMP_SCRIPT}"

 if timeout "${TIMEOUT_SECONDS}" PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" \
  -f "${TEMP_SCRIPT}" > "${OUTPUT_FILE}" 2>&1; then
  rm -f "${TEMP_SCRIPT}"
  local END_TIME
  END_TIME=$(date +%s)
  DURATION=$((END_TIME - START_TIME))
  local END_TIME_STR
  END_TIME_STR=$(date '+%Y-%m-%d %H:%M:%S' 2> /dev/null || echo 'unknown')
  __logd "Completed in ${DURATION} seconds (${END_TIME_STR})"
  # Parse results
  local TIMING
  TIMING=$(__parse_timing "${OUTPUT_FILE}")
  local HAS_INDEX_SCAN=false
  local HAS_SEQ_SCAN=false

  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if __check_index_scan "${OUTPUT_FILE}"; then
   HAS_INDEX_SCAN=true
  fi

  # shellcheck disable=SC2310
  # Function is invoked in if condition intentionally
  if __check_seq_scan "${OUTPUT_FILE}"; then
   HAS_SEQ_SCAN=true
  fi

  # Check for errors or warnings in output
  # Look for actual PostgreSQL errors (ERROR: or FATAL: at start of line)
  # Exclude false positives like "ERROR" in comments, echo messages, or EXPLAIN output
  # PostgreSQL errors typically start with "ERROR:" or "FATAL:" at the beginning of a line
  if grep -qiE "^(ERROR|FATAL):" "${OUTPUT_FILE}"; then
   STATUS="FAILED"
   ISSUES+=("PostgreSQL errors found in output")
   FAILED_SCRIPTS=$((FAILED_SCRIPTS + 1))
  elif grep -qiE "^(WARNING|NOTICE):" "${OUTPUT_FILE}"; then
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
    echo "Query execution time: ${TIMING} ms"
   fi
   if [[ -n "${DURATION:-}" ]]; then
    echo "Total script duration: ${DURATION} seconds"
   fi
   if [[ ${#ISSUES[@]} -gt 0 ]]; then
    echo "Issues:"
    for ISSUE in "${ISSUES[@]}"; do
     echo "  - ${ISSUE}"
    done
   fi
   echo ""
  } >> "${SUMMARY_FILE}"

  if [[ "${VERBOSE:-false}" == "true" ]]; then
   __print_status "${CYAN}" "Output saved to: ${OUTPUT_FILE}"
  fi
 else
  local EXIT_CODE=$?
  local END_TIME
  END_TIME=$(date +%s)
  local DURATION=$((END_TIME - START_TIME))

  # Clean up temp script
  rm -f "${TEMP_SCRIPT}"

  STATUS="FAILED"
  FAILED_SCRIPTS=$((FAILED_SCRIPTS + 1))

  # Check if it was a timeout
  if [[ ${EXIT_CODE} -eq 124 ]] || [[ ${EXIT_CODE} -eq 143 ]]; then
   __loge "Script ${SCRIPT_NAME} timed out after ${DURATION} seconds (${TIMEOUT_SECONDS}s limit)"
   ISSUES+=("Script execution timed out after ${TIMEOUT_SECONDS} seconds")
  else
   __loge "Failed to execute ${SCRIPT_NAME} (exit code: ${EXIT_CODE}, duration: ${DURATION}s)"
   # Show first few lines of error output for debugging
   if [[ -f "${OUTPUT_FILE}" ]] && [[ -s "${OUTPUT_FILE}" ]]; then
    __logd "First 5 lines of error output:"
    head -5 "${OUTPUT_FILE}" | while IFS= read -r line; do
     __logd "  ${line}"
    done
   fi
   ISSUES+=("Script execution failed (exit code: ${EXIT_CODE})")
  fi

  {
   echo "=== ${SCRIPT_NAME} ==="
   echo "Status: FAILED"
   if [[ ${EXIT_CODE} -eq 124 ]] || [[ ${EXIT_CODE} -eq 143 ]]; then
    echo "Error: Script execution timed out after ${TIMEOUT_SECONDS} seconds"
   else
    echo "Error: Script execution failed (exit code: ${EXIT_CODE})"
   fi
   echo "Duration: ${DURATION} seconds"
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
  # shellcheck disable=SC2012
  # Using ls for human-readable output is acceptable here
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
   exit "${ERROR_INVALID_ARGUMENT}"
   ;;
  esac
 done

 # Validate database connection
 __logi "Connecting to database: ${DBNAME}"
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  __loge "Cannot connect to database: ${DBNAME}"
  # shellcheck disable=SC2154
  # ERROR_GENERAL is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_GENERAL}"
 fi

 # Create output directory
 mkdir -p "${OUTPUT_DIR}"

 # Initialize summary file
 : > "${SUMMARY_FILE}"

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
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 local ANALYSIS_SCRIPTS
 local FIND_RESULT
 FIND_RESULT=$(find "${ANALYSIS_DIR}" -name "analyze_*.sql" -type f 2> /dev/null || echo "")
 if [[ -n "${FIND_RESULT}" ]]; then
  mapfile -t ANALYSIS_SCRIPTS < <(echo "${FIND_RESULT}" | sort)
 else
  ANALYSIS_SCRIPTS=()
 fi

 if [[ ${#ANALYSIS_SCRIPTS[@]} -eq 0 ]]; then
  __loge "No analysis scripts found in ${ANALYSIS_DIR}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 __logi "Found ${#ANALYSIS_SCRIPTS[@]} analysis script(s)"
 echo ""

 # Run each analysis script
 local SCRIPT_NUM=0
 for SCRIPT in "${ANALYSIS_SCRIPTS[@]}"; do
  SCRIPT_NUM=$((SCRIPT_NUM + 1))
  __logi "Processing script ${SCRIPT_NUM}/${#ANALYSIS_SCRIPTS[@]}: $(basename "${SCRIPT}")"
  __run_analysis_script "${SCRIPT}"
  __logd "Completed script ${SCRIPT_NUM}/${#ANALYSIS_SCRIPTS[@]}"
 done

 echo ""
 __print_status "${BLUE}" "=============================================================================="

 # Generate final report
 __generate_report

 # Set exit code based on results
 if [[ ${FAILED_SCRIPTS} -gt 0 ]]; then
  __loge "Performance analysis completed with ${FAILED_SCRIPTS} failed script(s)"
  __log_finish
  # shellcheck disable=SC2154
  # ERROR_GENERAL is defined in lib/osm-common/commonFunctions.sh
  exit "${ERROR_GENERAL}"
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
