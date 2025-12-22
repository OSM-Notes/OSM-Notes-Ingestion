#!/bin/bash

# HTTP Optimizations Benchmark Script
# Compares performance with and without HTTP optimizations
# Generates detailed metrics and comparison reports
#
# Usage: ./benchmark_http_optimizations.sh [--iterations N] [--output-dir DIR]
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-20
VERSION="2025-12-20"

set -euo pipefail

# Default configuration
ITERATIONS="${BENCHMARK_ITERATIONS:-5}"
OUTPUT_DIR="${BENCHMARK_OUTPUT_DIR:-./benchmark_results}"
OSM_API_URL="${OSM_API_URL:-https://api.openstreetmap.org/api/0.6/notes/search.xml?limit=100}"
OVERPASS_QUERY="${OVERPASS_QUERY:-[out:json][timeout:10];node(1);out;}"

# Parse arguments
while [[ $# -gt 0 ]]; do
 case $1 in
 --iterations)
  ITERATIONS="$2"
  shift 2
  ;;
 --output-dir)
  OUTPUT_DIR="$2"
  shift 2
  ;;
 --help | -h)
  echo "Usage: $0 [--iterations N] [--output-dir DIR]"
  echo ""
  echo "Benchmarks HTTP optimizations (keep-alive, HTTP/2, compression, caching)"
  echo ""
  echo "Options:"
  echo "  --iterations N    Number of iterations per test (default: 5)"
  echo "  --output-dir DIR  Output directory for results (default: ./benchmark_results)"
  echo "  --help, -h        Show this help message"
  exit 0
  ;;
 *)
  echo "Unknown option: $1"
  exit 1
  ;;
 esac
done

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SCRIPT_BASE_DIRECTORY="${SCRIPT_DIR}"

# Load required functions
if [[ -f "${SCRIPT_DIR}/bin/lib/noteProcessingFunctions.sh" ]]; then
 source "${SCRIPT_DIR}/bin/lib/noteProcessingFunctions.sh"
else
 echo "ERROR: Cannot find noteProcessingFunctions.sh"
 exit 1
fi

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Results file
RESULTS_FILE="${OUTPUT_DIR}/http_optimizations_benchmark_$(date +%Y%m%d_%H%M%S).json"
TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)

echo "=========================================="
echo "HTTP Optimizations Benchmark"
echo "=========================================="
echo "Iterations: ${ITERATIONS}"
echo "Output: ${RESULTS_FILE}"
echo ""

# Function to record a metric
record_metric() {
 local test_name="$1"
 local metric_name="$2"
 local value="$3"
 local unit="${4:-}"

 local json_entry
 json_entry=$(
  cat << EOF
{
  "test_name": "${test_name}",
  "metric": "${metric_name}",
  "value": ${value},
  "unit": "${unit}",
  "timestamp": "${TIMESTAMP}",
  "version": "${VERSION}"
}
EOF
 )

 echo "${json_entry}" >> "${RESULTS_FILE}"
}

# Function to measure time
measure_time() {
 local start_time
 start_time=$(date +%s.%N 2> /dev/null || date +%s)

 "$@" > /dev/null 2>&1

 local end_time
 end_time=$(date +%s.%N 2> /dev/null || date +%s)

 if command -v bc > /dev/null 2>&1; then
  echo "${end_time} - ${start_time}" | bc -l
 else
  echo "$((end_time - start_time))"
 fi
}

# Function to run benchmark for a single configuration
run_benchmark() {
 local config_name="$1"
 local enable_optimizations="${2:-true}"
 local enable_cache="${3:-true}"
 local url="$4"
 # shellcheck disable=SC2034
 local output_file="$5"
 local iterations="${6:-${ITERATIONS}}"

 export ENABLE_HTTP_OPTIMIZATIONS="${enable_optimizations}"
 export ENABLE_HTTP_CACHE="${enable_cache}"

 local total_time=0
 local success_count=0
 local i

 echo "Running ${config_name} (${iterations} iterations)..."

 for ((i = 1; i <= iterations; i++)); do
  local temp_file
  temp_file=$(mktemp)

  local duration
  duration=$(measure_time __retry_osm_api "${url}" "${temp_file}" 1 1 30)

  if [[ -f "${temp_file}" ]] && [[ -s "${temp_file}" ]]; then
   total_time=$(echo "${total_time} + ${duration}" | bc -l 2> /dev/null || echo "${total_time}")
   success_count=$((success_count + 1))
  fi

  rm -f "${temp_file}"

  # Small delay between requests
  sleep 0.5
 done

 local avg_time=0
 if [[ ${success_count} -gt 0 ]]; then
  avg_time=$(echo "scale=4; ${total_time} / ${success_count}" | bc -l 2> /dev/null || echo "0")
 fi

 record_metric "http_optimizations" "${config_name}_avg_time" "${avg_time}" "seconds"
 record_metric "http_optimizations" "${config_name}_total_time" "${total_time}" "seconds"
 record_metric "http_optimizations" "${config_name}_success_count" "${success_count}" "count"

 echo "  Average: ${avg_time}s (${success_count}/${iterations} successful)"
 echo ""

 echo "${avg_time}"
}

# Run benchmarks
echo "Benchmark 1: Single OSM API Request"
echo "-----------------------------------"

WITH_OPT=$(run_benchmark "osm_api_with_optimizations" "true" "true" \
 "${OSM_API_URL}" "/tmp/benchmark_with" "${ITERATIONS}")

WITHOUT_OPT=$(run_benchmark "osm_api_without_optimizations" "false" "false" \
 "${OSM_API_URL}" "/tmp/benchmark_without" "${ITERATIONS}")

# Calculate improvement
if command -v bc > /dev/null 2>&1 && [[ -n "${WITHOUT_OPT}" ]] && [[ -n "${WITH_OPT}" ]]; then
 IMPROVEMENT=$(echo "scale=2; (${WITHOUT_OPT} - ${WITH_OPT}) / ${WITHOUT_OPT} * 100" | bc -l)
 record_metric "http_optimizations" "osm_api_improvement_percent" "${IMPROVEMENT}" "percent"

 echo "Results:"
 echo "  With optimizations:    ${WITH_OPT}s"
 echo "  Without optimizations: ${WITHOUT_OPT}s"
 echo "  Improvement:          ${IMPROVEMENT}%"
 echo ""
fi

# Benchmark: Multiple sequential requests (connection reuse)
echo "Benchmark 2: Multiple Sequential Requests (Connection Reuse)"
echo "------------------------------------------------------------"

NUM_REQUESTS=5

# With optimizations
export ENABLE_HTTP_OPTIMIZATIONS="true"
export ENABLE_HTTP_CACHE="true"

TOTAL_WITH=0
SUCCESS_WITH=0

echo "Running with optimizations (${NUM_REQUESTS} requests)..."
START_TIME=$(date +%s.%N 2> /dev/null || date +%s)

for ((i = 1; i <= NUM_REQUESTS; i++)); do
 TEMP_FILE=$(mktemp)
 if __retry_osm_api "${OSM_API_URL}" "${TEMP_FILE}" 1 1 30 > /dev/null 2>&1; then
  if [[ -f "${TEMP_FILE}" ]] && [[ -s "${TEMP_FILE}" ]]; then
   SUCCESS_WITH=$((SUCCESS_WITH + 1))
  fi
 fi
 rm -f "${TEMP_FILE}"
 sleep 0.2
done

END_TIME=$(date +%s.%N 2> /dev/null || date +%s)
if command -v bc > /dev/null 2>&1; then
 TOTAL_WITH=$(echo "${END_TIME} - ${START_TIME}" | bc -l)
else
 TOTAL_WITH=$((END_TIME - START_TIME))
fi

record_metric "http_optimizations" "multiple_requests_with_time" "${TOTAL_WITH}" "seconds"

# Without optimizations
export ENABLE_HTTP_OPTIMIZATIONS="false"
export ENABLE_HTTP_CACHE="false"

TOTAL_WITHOUT=0
SUCCESS_WITHOUT=0

echo "Running without optimizations (${NUM_REQUESTS} requests)..."
START_TIME=$(date +%s.%N 2> /dev/null || date +%s)

for ((i = 1; i <= NUM_REQUESTS; i++)); do
 TEMP_FILE=$(mktemp)
 if __retry_osm_api "${OSM_API_URL}" "${TEMP_FILE}" 1 1 30 > /dev/null 2>&1; then
  if [[ -f "${TEMP_FILE}" ]] && [[ -s "${TEMP_FILE}" ]]; then
   SUCCESS_WITHOUT=$((SUCCESS_WITHOUT + 1))
  fi
 fi
 rm -f "${TEMP_FILE}"
 sleep 0.2
done

END_TIME=$(date +%s.%N 2> /dev/null || date +%s)
if command -v bc > /dev/null 2>&1; then
 TOTAL_WITHOUT=$(echo "${END_TIME} - ${START_TIME}" | bc -l)
else
 TOTAL_WITHOUT=$((END_TIME - START_TIME))
fi

record_metric "http_optimizations" "multiple_requests_without_time" "${TOTAL_WITHOUT}" "seconds"

# Calculate improvement for multiple requests
if command -v bc > /dev/null 2>&1 && [[ -n "${TOTAL_WITHOUT}" ]] && [[ -n "${TOTAL_WITH}" ]]; then
 IMPROVEMENT_MULTI=$(echo "scale=2; (${TOTAL_WITHOUT} - ${TOTAL_WITH}) / ${TOTAL_WITHOUT} * 100" | bc -l)
 record_metric "http_optimizations" "connection_reuse_improvement_percent" "${IMPROVEMENT_MULTI}" "percent"

 echo "Results:"
 echo "  With optimizations:    ${TOTAL_WITH}s"
 echo "  Without optimizations: ${TOTAL_WITHOUT}s"
 echo "  Improvement:          ${IMPROVEMENT_MULTI}%"
 echo ""
fi

# Generate summary
echo "=========================================="
echo "Benchmark Complete"
echo "=========================================="
echo "Results saved to: ${RESULTS_FILE}"
echo ""
echo "To view results:"
echo "  cat ${RESULTS_FILE} | jq '.'"
echo ""
echo "To compare with previous runs:"
echo "  diff ${RESULTS_FILE} <previous_file>"
