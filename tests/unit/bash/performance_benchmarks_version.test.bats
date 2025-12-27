#!/usr/bin/env bats

# Performance Benchmarks: Version Comparison
# Benchmarks for comparing performance across versions
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
# Benchmark: Version Comparison
# =============================================================================

@test "BENCHMARK: Compare with previous version" {
 # Test: Benchmark version comparison functionality
 # Purpose: Verify that benchmark comparison system works correctly
 # Expected: Should establish baseline, record second run, and compare results
 # Note: This test verifies the benchmark infrastructure for performance tracking

 local -r test_name="xml_validation"
 
 # Run benchmark first to establish baseline
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 sleep 0.1
 local duration
 duration=$(__benchmark_end "${test_name}")
 __benchmark_record "${test_name}" "total_duration" "${duration}" "seconds"
 
 # Run again to compare
 local start_time2
 start_time2=$(__benchmark_start "${test_name}")
 sleep 0.1
 local duration2
 duration2=$(__benchmark_end "${test_name}")
 __benchmark_record "${test_name}" "total_duration" "${duration2}" "seconds"
 
 # Get comparison
 local comparison
 comparison=$(__benchmark_compare "${test_name}" "total_duration" "${duration2}")
 
 # Verify comparison works
 [[ -n "${comparison}" ]]
 [[ "${comparison}" == "baseline" ]] || [[ "${comparison}" == "improvement" ]] || [[ "${comparison}" == "regression" ]] || [[ "${comparison}" == "stable" ]]
}

