#!/bin/bash

# Performance Regression Detection Script
# Compares current benchmark results against baseline and detects regressions
# Author: Andres Gomez (AngocA)
# Version: 2026-01-02

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE_FILE="${BASELINE_FILE:-${SCRIPT_DIR}/benchmark_results/baseline.json}"
CURRENT_RESULTS_DIR="${CURRENT_RESULTS_DIR:-${SCRIPT_DIR}/benchmark_results}"
REGRESSION_THRESHOLD="${REGRESSION_THRESHOLD:-0.10}" # 10% slower is considered regression
IMPROVEMENT_THRESHOLD="${IMPROVEMENT_THRESHOLD:-0.05}" # 5% faster is considered improvement
OUTPUT_FILE="${OUTPUT_FILE:-${SCRIPT_DIR}/benchmark_results/regression_report.json}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Initialize regression report
REGRESSIONS=()
IMPROVEMENTS=()
STABLE=()

###############################################################################
# Helper Functions
###############################################################################

# Log functions
log_info() {
 echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
 echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
 echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check if jq is available
check_dependencies() {
 if ! command -v jq > /dev/null 2>&1; then
  log_error "jq is required but not installed. Please install jq first."
  exit 1
 fi
 
 if ! command -v bc > /dev/null 2>&1; then
  log_warn "bc is recommended for accurate calculations. Some comparisons may be less precise."
 fi
}

# Load baseline metrics
load_baseline() {
 local test_name="${1}"
 local metric_name="${2}"
 
 if [[ ! -f "${BASELINE_FILE}" ]]; then
  echo ""
  return 0
 fi
 
 jq -r ".[] | select(.test_name == \"${test_name}\" and .metric == \"${metric_name}\") | .value" \
  "${BASELINE_FILE}" 2>/dev/null | tail -1 || echo ""
}

# Load current metrics from result files
# Handles both JSONL format (multiple JSON objects separated by newlines)
# and single JSON object format
load_current() {
 local test_name="${1}"
 local metric_name="${2}"
 local result_file="${CURRENT_RESULTS_DIR}/${test_name}.json"
 
 if [[ ! -f "${result_file}" ]]; then
  echo ""
  return 0
 fi
 
 # Try to read as JSONL (multiple JSON objects) first
 # If that fails, try as single JSON object or array
 jq -r -s '.[] | select(.metric == "'"${metric_name}"'") | .value' \
  "${result_file}" 2>/dev/null | tail -1 || \
 jq -r 'select(.metric == "'"${metric_name}"'") | .value' \
  "${result_file}" 2>/dev/null | tail -1 || \
 jq -r '.[] | select(.metric == "'"${metric_name}"'") | .value' \
  "${result_file}" 2>/dev/null | tail -1 || echo ""
}

# Compare two values and determine if it's a regression, improvement, or stable
compare_values() {
 local metric_name="${1}"
 local baseline_value="${2}"
 local current_value="${3}"
 
 if [[ -z "${baseline_value}" ]] || [[ -z "${current_value}" ]]; then
  echo "missing_data"
  return 0
 fi
 
 # Check if values are numeric
 if ! [[ "${baseline_value}" =~ ^[0-9]+\.?[0-9]*$ ]] || ! [[ "${current_value}" =~ ^[0-9]+\.?[0-9]*$ ]]; then
  echo "invalid_data"
  return 0
 fi
 
 # Calculate percentage change
 local percent_change
 if command -v bc > /dev/null 2>&1; then
  if [[ $(echo "${baseline_value} > 0" | bc -l) -eq 1 ]]; then
   percent_change=$(echo "scale=4; (${current_value} - ${baseline_value}) / ${baseline_value}" | bc -l)
  else
   percent_change="0"
  fi
 else
  # Fallback to integer arithmetic
  if [[ "${baseline_value}" -gt 0 ]]; then
   percent_change=$(( (current_value - baseline_value) * 100 / baseline_value ))
   percent_change=$(echo "scale=4; ${percent_change} / 100" | bc -l 2>/dev/null || echo "0")
  else
   percent_change="0"
  fi
 fi
 
 # Determine if it's a regression, improvement, or stable
 # For time/duration metrics: lower is better (negative change is improvement)
 # For throughput metrics: higher is better (positive change is improvement)
 local comparison
 if [[ "${metric_name}" == *"time"* ]] || [[ "${metric_name}" == *"duration"* ]]; then
  # Time metrics: lower is better
  if [[ $(echo "${percent_change} > ${REGRESSION_THRESHOLD}" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
   comparison="regression"
  elif [[ $(echo "${percent_change} < -${IMPROVEMENT_THRESHOLD}" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
   comparison="improvement"
  else
   comparison="stable"
  fi
 else
  # Throughput metrics: higher is better
  if [[ $(echo "${percent_change} < -${REGRESSION_THRESHOLD}" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
   comparison="regression"
  elif [[ $(echo "${percent_change} > ${IMPROVEMENT_THRESHOLD}" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
   comparison="improvement"
  else
   comparison="stable"
  fi
 fi
 
 echo "${comparison}|${percent_change}"
}

# Analyze benchmark results
analyze_benchmarks() {
 log_info "Analyzing benchmark results..."
 log_info "Baseline file: ${BASELINE_FILE}"
 log_info "Current results: ${CURRENT_RESULTS_DIR}"
 log_info "Regression threshold: ${REGRESSION_THRESHOLD} (${REGRESSION_THRESHOLD}%)"
 
 # Check if baseline exists
 if [[ ! -f "${BASELINE_FILE}" ]]; then
  log_warn "Baseline file not found: ${BASELINE_FILE}"
  log_info "Creating baseline from current results..."
  create_baseline
  return 0
 fi
 
 # Find all current result files
 local result_files
 result_files=$(find "${CURRENT_RESULTS_DIR}" -name "*.json" -type f 2>/dev/null || true)
 
 if [[ -z "${result_files}" ]]; then
  log_error "No benchmark result files found in ${CURRENT_RESULTS_DIR}"
  exit 1
 fi
 
 # Process each result file
 local total_tests=0
 local regressions_found=0
 local improvements_found=0
 local stable_found=0
 
 while IFS= read -r result_file; do
  local test_name
  test_name=$(basename "${result_file}" .json)
  
  # Extract metrics from current results
  # Handle both JSONL format (multiple JSON objects) and single JSON object/array
  local metrics
  metrics=$(jq -r -s '.[] | .metric' "${result_file}" 2>/dev/null || \
            jq -r '.metric' "${result_file}" 2>/dev/null || \
            jq -r '.[] | .metric' "${result_file}" 2>/dev/null || true)
  
  while IFS= read -r metric_name; do
   [[ -z "${metric_name}" ]] && continue
   
   total_tests=$((total_tests + 1))
   
   local baseline_value current_value
   baseline_value=$(load_baseline "${test_name}" "${metric_name}")
   current_value=$(load_current "${test_name}" "${metric_name}")
   
   if [[ -z "${baseline_value}" ]]; then
    log_warn "No baseline found for ${test_name}.${metric_name} - skipping"
    continue
   fi
   
   if [[ -z "${current_value}" ]]; then
    log_warn "No current value found for ${test_name}.${metric_name} - skipping"
    continue
   fi
   
   # Compare values
   local comparison_result
   comparison_result=$(compare_values "${metric_name}" "${baseline_value}" "${current_value}")
   local comparison percent_change
   comparison=$(echo "${comparison_result}" | cut -d'|' -f1)
   percent_change=$(echo "${comparison_result}" | cut -d'|' -f2)
   
   # Format percentage for display
   local percent_display
   if command -v bc > /dev/null 2>&1; then
    percent_display=$(echo "scale=2; ${percent_change} * 100" | bc -l)
   else
    percent_display="${percent_change}"
   fi
   
   # Record result
   case "${comparison}" in
    regression)
     regressions_found=$((regressions_found + 1))
     REGRESSIONS+=("${test_name}.${metric_name}: ${baseline_value} -> ${current_value} (${percent_display}% change)")
     log_error "REGRESSION: ${test_name}.${metric_name} - ${percent_display}% change"
     ;;
    improvement)
     improvements_found=$((improvements_found + 1))
     IMPROVEMENTS+=("${test_name}.${metric_name}: ${baseline_value} -> ${current_value} (${percent_display}% change)")
     log_info "IMPROVEMENT: ${test_name}.${metric_name} - ${percent_display}% change"
     ;;
    stable)
     stable_found=$((stable_found + 1))
     STABLE+=("${test_name}.${metric_name}: ${baseline_value} -> ${current_value} (${percent_display}% change)")
     ;;
    *)
     log_warn "Unknown comparison result: ${comparison} for ${test_name}.${metric_name}"
     ;;
   esac
  done <<< "${metrics}"
 done <<< "${result_files}"
 
 # Generate report
 generate_report "${total_tests}" "${regressions_found}" "${improvements_found}" "${stable_found}"
 
 # Exit with error if regressions found
 if [[ ${regressions_found} -gt 0 ]]; then
  log_error "Found ${regressions_found} performance regressions!"
  exit 1
 fi
 
 log_info "No performance regressions detected."
 exit 0
}

# Create baseline from current results
create_baseline() {
 log_info "Creating baseline from current results..."
 
 mkdir -p "$(dirname "${BASELINE_FILE}")"
 
 # Collect all current results into baseline
 local baseline_data="[]"
 
 local result_files
 result_files=$(find "${CURRENT_RESULTS_DIR}" -name "*.json" -type f 2>/dev/null || true)
 
 while IFS= read -r result_file; do
  [[ -z "${result_file}" ]] && continue
  
  # Handle JSONL format (multiple JSON objects separated by newlines)
  # Convert to array format for baseline
  local file_data
  file_data=$(jq -s '.' "${result_file}" 2>/dev/null || \
              jq -c '.' "${result_file}" 2>/dev/null || echo "[]")
  
  # If file_data is an array, merge it; otherwise wrap it in an array
  if echo "${file_data}" | jq -e 'type == "array"' > /dev/null 2>&1; then
   baseline_data=$(echo "${baseline_data}" | jq -c ". + ${file_data}" 2>/dev/null || echo "${baseline_data}")
  else
   baseline_data=$(echo "${baseline_data}" | jq -c ". + [${file_data}]" 2>/dev/null || echo "${baseline_data}")
  fi
 done <<< "${result_files}"
 
 # Save baseline
 echo "${baseline_data}" | jq '.' > "${BASELINE_FILE}" 2>/dev/null || {
  log_error "Failed to create baseline file"
  exit 1
 }
 
 log_info "Baseline created: ${BASELINE_FILE}"
}

# Generate regression report
generate_report() {
 local total_tests="${1}"
 local regressions_found="${2}"
 local improvements_found="${3}"
 local stable_found="${4}"
 
 mkdir -p "$(dirname "${OUTPUT_FILE}")"
 
 # Create JSON report
 local report_json
 report_json=$(cat << EOF
{
  "timestamp": "$(date -Iseconds)",
  "baseline_file": "${BASELINE_FILE}",
  "current_results_dir": "${CURRENT_RESULTS_DIR}",
  "regression_threshold": ${REGRESSION_THRESHOLD},
  "improvement_threshold": ${IMPROVEMENT_THRESHOLD},
  "summary": {
    "total_tests": ${total_tests},
    "regressions": ${regressions_found},
    "improvements": ${improvements_found},
    "stable": ${stable_found}
  },
  "regressions": $(printf '%s\n' "${REGRESSIONS[@]}" | jq -R -s -c 'split("\n") | map(select(. != ""))'),
  "improvements": $(printf '%s\n' "${IMPROVEMENTS[@]}" | jq -R -s -c 'split("\n") | map(select(. != ""))'),
  "stable": $(printf '%s\n' "${STABLE[@]}" | jq -R -s -c 'split("\n") | map(select(. != ""))')
}
EOF
)
 
 echo "${report_json}" | jq '.' > "${OUTPUT_FILE}" 2>/dev/null || {
  log_error "Failed to write report file"
  exit 1
 }
 
 # Print summary
 echo ""
 log_info "=== Performance Regression Report ==="
 echo "Total tests analyzed: ${total_tests}"
 echo "Regressions found: ${regressions_found}"
 echo "Improvements found: ${improvements_found}"
 echo "Stable: ${stable_found}"
 echo ""
 echo "Report saved to: ${OUTPUT_FILE}"
 
 if [[ ${regressions_found} -gt 0 ]]; then
  echo ""
  log_error "Regressions:"
  printf '%s\n' "${REGRESSIONS[@]}" | while IFS= read -r reg; do
   echo "  - ${reg}"
  done
 fi
 
 if [[ ${improvements_found} -gt 0 ]]; then
  echo ""
  log_info "Improvements:"
  printf '%s\n' "${IMPROVEMENTS[@]}" | while IFS= read -r imp; do
   echo "  - ${imp}"
  done
 fi
}

###############################################################################
# Main
###############################################################################

main() {
 local command="${1:-analyze}"
 
 check_dependencies
 
 case "${command}" in
  analyze)
   analyze_benchmarks
   ;;
  create-baseline)
   create_baseline
   ;;
  *)
   echo "Usage: $0 [analyze|create-baseline]"
   echo ""
   echo "Commands:"
   echo "  analyze          - Compare current results against baseline (default)"
   echo "  create-baseline - Create baseline from current results"
   exit 1
   ;;
 esac
}

main "$@"

