#!/usr/bin/env bash

# Performance Benchmarks Helper Utilities
# Provides functions for measuring and recording performance metrics
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

# Directory for storing benchmark results
# Only set if not already declared (e.g., when sourced from test)
if ! declare -p BENCHMARK_RESULTS_DIR > /dev/null 2>&1; then
 BENCHMARK_RESULTS_DIR="${BENCHMARK_RESULTS_DIR:-${SCRIPT_BASE_DIRECTORY:-.}/tests/benchmark_results}"
fi

# Ensure benchmark results directory exists
if [[ ! -d "${BENCHMARK_RESULTS_DIR}" ]]; then
 mkdir -p "${BENCHMARK_RESULTS_DIR}" 2>/dev/null || true
fi

# Start performance measurement
# Usage: __benchmark_start "test_name"
# Returns: timestamp in seconds
__benchmark_start() {
 local -r test_name="${1:-unknown}"
 local timestamp
 timestamp=$(date +%s.%N 2>/dev/null || date +%s)
 export "BENCHMARK_START_${test_name}=${timestamp}"
 export "BENCHMARK_TEST_NAME=${test_name}"
 echo "${timestamp}"
}

# End performance measurement and calculate duration
# Usage: __benchmark_end "test_name"
# Returns: duration in seconds
__benchmark_end() {
 local -r test_name="${1:-${BENCHMARK_TEST_NAME:-unknown}}"
 local end_time
 end_time=$(date +%s.%N 2>/dev/null || date +%s)
 local -r start_time_var="BENCHMARK_START_${test_name}"
 local start_time
 start_time="${!start_time_var:-${end_time}}"
 
 # Calculate duration
 local duration
 if command -v bc > /dev/null 2>&1; then
  duration=$(echo "${end_time} - ${start_time}" | bc -l 2>/dev/null || echo "0")
 else
  duration=$((end_time - start_time))
 fi
 
 echo "${duration}"
}

# Measure memory usage
# Usage: __benchmark_memory
# Returns: memory usage in KB
__benchmark_memory() {
 if command -v ps > /dev/null 2>&1; then
  ps -o rss= -p $$ 2>/dev/null | tr -d ' ' || echo "0"
 else
  echo "0"
 fi
}

# Measure CPU usage (percentage)
# Usage: __benchmark_cpu "duration_seconds"
# Returns: CPU percentage
__benchmark_cpu() {
 local -r duration="${1:-1}"
 if command -v top > /dev/null 2>&1; then
  top -bn2 -d "${duration}" -p $$ 2>/dev/null | grep -E "^%Cpu" | tail -1 | awk '{print $2}' | sed 's/%us,//' || echo "0"
 else
  echo "0"
 fi
}

# Record benchmark result
# Usage: __benchmark_record "test_name" "metric_name" "value" "unit"
__benchmark_record() {
 local -r test_name="${1}"
 local -r metric_name="${2}"
 local -r value="${3}"
 local -r unit="${4:-}"
 local timestamp
 timestamp=$(date +%Y-%m-%dT%H:%M:%S 2>/dev/null || date +%Y-%m-%d)
 local -r version="${VERSION:-unknown}"
 local -r result_file="${BENCHMARK_RESULTS_DIR}/${test_name}.json"
 
 # Create JSON entry
 local json_entry
 json_entry=$(cat << EOF
{
  "test_name": "${test_name}",
  "metric": "${metric_name}",
  "value": ${value},
  "unit": "${unit}",
  "timestamp": "${timestamp}",
  "version": "${version}"
}
EOF
)
 
 # Append to results file
 echo "${json_entry}" >> "${result_file}" 2>/dev/null || true
}

# Get previous benchmark result for comparison
# Usage: __benchmark_get_previous "test_name" "metric_name"
# Returns: previous value or empty
__benchmark_get_previous() {
 local -r test_name="${1}"
 local -r metric_name="${2}"
 local -r result_file="${BENCHMARK_RESULTS_DIR}/${test_name}.json"
 
 if [[ -f "${result_file}" ]] && command -v jq > /dev/null 2>&1; then
  jq -r "select(.metric == \"${metric_name}\") | .value" "${result_file}" 2>/dev/null | tail -1 || echo ""
 else
  echo ""
 fi
}

# Compare current vs previous benchmark
# Usage: __benchmark_compare "test_name" "metric_name" "current_value"
# Returns: comparison result (improvement, regression, or stable)
__benchmark_compare() {
 local -r test_name="${1}"
 local -r metric_name="${2}"
 local -r current_value="${3}"
 local previous_value
 previous_value=$(__benchmark_get_previous "${test_name}" "${metric_name}")
 
 if [[ -z "${previous_value}" ]]; then
  echo "baseline"
  return 0
 fi
 
 # For time/duration metrics, lower is better
 # For throughput metrics, higher is better
 local comparison
 if [[ "${metric_name}" == *"time"* ]] || [[ "${metric_name}" == *"duration"* ]]; then
  # Lower is better
  if (( $(echo "${current_value} < ${previous_value}" | bc -l 2>/dev/null || echo "0") )); then
   comparison="improvement"
  elif (( $(echo "${current_value} > ${previous_value}" | bc -l 2>/dev/null || echo "0") )); then
   comparison="regression"
  else
   comparison="stable"
  fi
 else
  # Higher is better (throughput, etc.)
  if (( $(echo "${current_value} > ${previous_value}" | bc -l 2>/dev/null || echo "0") )); then
   comparison="improvement"
  elif (( $(echo "${current_value} < ${previous_value}" | bc -l 2>/dev/null || echo "0") )); then
   comparison="regression"
  else
   comparison="stable"
  fi
 fi
 
 echo "${comparison}"
}

# Setup mock PostgreSQL for benchmarks
__benchmark_setup_mock_postgres() {
 if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
  return 0
 fi
 
 local MOCK_DIR="${SCRIPT_BASE_DIRECTORY}/tests/mock_commands"
 local POSTGRES_READY=false
 
 if command -v pg_isready > /dev/null 2>&1; then
  if pg_isready -q > /dev/null 2>&1; then
   POSTGRES_READY=true
  fi
 fi
 
 if [[ "${POSTGRES_READY}" != true ]] && command -v psql > /dev/null 2>&1; then
  if command -v timeout > /dev/null 2>&1; then
   if timeout 3s psql -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    POSTGRES_READY=true
   fi
  else
   if psql -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    POSTGRES_READY=true
   fi
  fi
 fi
 
 if [[ "${POSTGRES_READY}" != true ]] && [[ -d "${MOCK_DIR}" ]]; then
  if [[ ":${PATH}:" != *":${MOCK_DIR}:"* ]]; then
   export PATH="${MOCK_DIR}:${PATH}"
  fi
  export BENCHMARK_USING_MOCK_PSQL="true"
 else
  unset BENCHMARK_USING_MOCK_PSQL
 fi
 
 return 0
}

