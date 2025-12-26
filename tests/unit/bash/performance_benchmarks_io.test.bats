#!/usr/bin/env bats

# Performance Benchmarks: File I/O Operations
# Benchmarks for file read and write performance
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

load "${BATS_TEST_DIRNAME}/../../test_helper"
load "${BATS_TEST_DIRNAME}/performance_benchmarks_helper.bash"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR
 
 # Set up test environment variables
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="${TEST_DIR}"
 export DBNAME="${TEST_DBNAME:-test_db}"
 BENCHMARK_RESULTS_DIR="${TEST_DIR}/benchmark_results"
 export BENCHMARK_RESULTS_DIR
 mkdir -p "${BENCHMARK_RESULTS_DIR}"
 
 # Set log level
 export LOG_LEVEL="INFO"
 export __log_level="INFO"
 
 # Setup mock PostgreSQL if needed
 __benchmark_setup_mock_postgres
}

teardown() {
 # Clean up test files
 if [[ -n "${TEST_DIR:-}" ]] && [[ -d "${TEST_DIR}" ]]; then
  rm -rf "${TEST_DIR}"
 fi
}

# =============================================================================
# Benchmark: File I/O Performance
# =============================================================================

@test "BENCHMARK: File read performance" {
 local -r test_name="file_read_performance"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Create test file
 local test_file="${TEST_DIR}/read_test.txt"
 dd if=/dev/urandom of="${test_file}" bs=1M count=10 2>/dev/null || true
 
 # Measure read time
 local read_start
 read_start=$(date +%s.%N 2>/dev/null || date +%s)
 
 if [[ -f "${test_file}" ]]; then
  cat "${test_file}" > /dev/null 2>&1 || true
 fi
 
 local read_end
 read_end=$(date +%s.%N 2>/dev/null || date +%s)
 local read_time
 if command -v bc > /dev/null 2>&1; then
  read_time=$(echo "${read_end} - ${read_start}" | bc -l)
 else
  read_time=$((read_end - read_start))
 fi
 
 # Calculate read throughput (MB/s)
 local file_size_mb=10
 local read_throughput
 if [[ $(echo "${read_time} > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
  read_throughput=$(echo "scale=2; ${file_size_mb} / ${read_time}" | bc -l 2>/dev/null || echo "0")
 else
  read_throughput=0
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "read_time" "${read_time}" "seconds"
 __benchmark_record "${test_name}" "read_throughput" "${read_throughput}" "MB_per_second"
 __benchmark_record "${test_name}" "file_size" "${file_size_mb}" "MB"
 
 # Verify benchmark completed
 [[ -n "${duration}" ]]
}

@test "BENCHMARK: File write performance" {
 local -r test_name="file_write_performance"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Measure write time
 local write_start
 write_start=$(date +%s.%N 2>/dev/null || date +%s)
 
 local test_file="${TEST_DIR}/write_test.txt"
 local write_size_mb=10
 dd if=/dev/urandom of="${test_file}" bs=1M count=${write_size_mb} 2>/dev/null || true
 
 local write_end
 write_end=$(date +%s.%N 2>/dev/null || date +%s)
 local write_time
 if command -v bc > /dev/null 2>&1; then
  write_time=$(echo "${write_end} - ${write_start}" | bc -l)
 else
  write_time=$((write_end - write_start))
 fi
 
 # Calculate write throughput (MB/s)
 local write_throughput
 if [[ $(echo "${write_time} > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
  write_throughput=$(echo "scale=2; ${write_size_mb} / ${write_time}" | bc -l 2>/dev/null || echo "0")
 else
  write_throughput=0
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "write_time" "${write_time}" "seconds"
 __benchmark_record "${test_name}" "write_throughput" "${write_throughput}" "MB_per_second"
 __benchmark_record "${test_name}" "file_size" "${write_size_mb}" "MB"
 
 # Verify benchmark completed
 [[ -n "${duration}" ]]
}

