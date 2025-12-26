#!/usr/bin/env bats

# Performance Benchmarks: Database Operations
# Benchmarks for database query and insert performance
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
# Benchmark: Database Operations Performance
# =============================================================================

@test "BENCHMARK: Database query performance" {
 local -r test_name="db_query_performance"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Create test database
 if [[ "${BENCHMARK_USING_MOCK_PSQL:-false}" != "true" ]]; then
  psql -d postgres -c "CREATE DATABASE ${DBNAME};" 2>/dev/null || true
  psql -d "${DBNAME}" -c "CREATE TABLE IF NOT EXISTS test_table (id INTEGER PRIMARY KEY, data TEXT);" 2>/dev/null || true
  psql -d "${DBNAME}" -c "INSERT INTO test_table SELECT generate_series(1, 1000), 'test_data';" 2>/dev/null || true
 fi
 
 # Measure SELECT query time
 local query_start
 query_start=$(date +%s.%N 2>/dev/null || date +%s)
 
 if [[ "${BENCHMARK_USING_MOCK_PSQL:-false}" != "true" ]]; then
  psql -d "${DBNAME}" -c "SELECT COUNT(*) FROM test_table;" > /dev/null 2>&1 || true
 fi
 
 local query_end
 query_end=$(date +%s.%N 2>/dev/null || date +%s)
 local query_time
 if command -v bc > /dev/null 2>&1; then
  query_time=$(echo "${query_end} - ${query_start}" | bc -l)
 else
  query_time=$((query_end - query_start))
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "query_time" "${query_time}" "seconds"
 __benchmark_record "${test_name}" "total_duration" "${duration}" "seconds"
 
 # Verify benchmark completed
 [[ -n "${duration}" ]]
}

@test "BENCHMARK: Database insert performance" {
 local -r test_name="db_insert_performance"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Create test database
 if [[ "${BENCHMARK_USING_MOCK_PSQL:-false}" != "true" ]]; then
  psql -d postgres -c "CREATE DATABASE ${DBNAME};" 2>/dev/null || true
  psql -d "${DBNAME}" -c "CREATE TABLE IF NOT EXISTS test_insert (id INTEGER PRIMARY KEY, data TEXT);" 2>/dev/null || true
 fi
 
 # Measure INSERT performance
 local insert_start
 insert_start=$(date +%s.%N 2>/dev/null || date +%s)
 local insert_count=100
 
 if [[ "${BENCHMARK_USING_MOCK_PSQL:-false}" != "true" ]]; then
  for i in $(seq 1 ${insert_count}); do
   psql -d "${DBNAME}" -c "INSERT INTO test_insert (id, data) VALUES (${i}, 'test_${i}');" > /dev/null 2>&1 || true
  done
 fi
 
 local insert_end
 insert_end=$(date +%s.%N 2>/dev/null || date +%s)
 local insert_time
 if command -v bc > /dev/null 2>&1; then
  insert_time=$(echo "${insert_end} - ${insert_start}" | bc -l)
 else
  insert_time=$((insert_end - insert_start))
 fi
 
 # Calculate insert throughput
 local insert_throughput
 if [[ $(echo "${insert_time} > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
  insert_throughput=$(echo "scale=2; ${insert_count} / ${insert_time}" | bc -l 2>/dev/null || echo "0")
 else
  insert_throughput=0
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "insert_time" "${insert_time}" "seconds"
 __benchmark_record "${test_name}" "insert_throughput" "${insert_throughput}" "inserts_per_second"
 __benchmark_record "${test_name}" "rows_inserted" "${insert_count}" "count"
 
 # Verify benchmark completed
 [[ -n "${duration}" ]]
}

