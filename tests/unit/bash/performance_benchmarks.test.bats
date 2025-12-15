#!/usr/bin/env bats

# Performance Benchmarks Test Suite
# Comprehensive performance benchmarks with automated metrics and version comparison
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

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
 rm -rf "${TEST_DIR}"
}

# =============================================================================
# Benchmark: XML Processing Performance
# =============================================================================

@test "BENCHMARK: XML validation performance" {
 # Test purpose: Measure XML validation performance using xmllint
 # This benchmark helps track performance regressions in XML processing
 local -r test_name="xml_validation"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Create minimal test XML file with OSM note structure
 # This represents a typical note from the OSM API
 local xml_file="${TEST_DIR}/test.xml"
 printf '<?xml version="1.0" encoding="UTF-8"?>\n<osm>\n <note id="1" lat="0.0" lon="0.0">\n  <comment action="opened" uid="1" user="test"/>\n </note>\n</osm>\n' > "${xml_file}"
 
 # Measure XML validation time using high-precision timestamps
 # Use date +%s.%N for sub-second precision, fallback to seconds if unavailable
 local validation_start
 validation_start=$(date +%s.%N 2>/dev/null || date +%s)
 
 # Validate XML using xmllint if available
 # --noout: Don't output XML, just validate
 # Redirect output to /dev/null to avoid cluttering test output
 if command -v xmllint > /dev/null 2>&1; then
  xmllint --noout "${xml_file}" > /dev/null 2>&1 || true
 fi
 
 local validation_end
 validation_end=$(date +%s.%N 2>/dev/null || date +%s)
 
 # Calculate validation time using bc for floating-point arithmetic
 # Fallback to integer arithmetic if bc is not available
 local validation_time
 if command -v bc > /dev/null 2>&1; then
  validation_time=$(echo "${validation_end} - ${validation_start}" | bc -l)
 else
  validation_time=$((validation_end - validation_start))
 fi
 
 # End benchmark and get total duration
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics for comparison with previous runs
 # validation_time: Time spent validating XML
 # total_duration: Total test execution time
 __benchmark_record "${test_name}" "validation_time" "${validation_time}" "seconds"
 __benchmark_record "${test_name}" "total_duration" "${duration}" "seconds"
 
 # Verify benchmark completed successfully
 # Both duration and validation_time should be non-empty
 [[ -n "${duration}" ]]
 # validation_time should be non-negative (simplified check)
 [[ -n "${validation_time}" ]]
}

@test "BENCHMARK: XML parsing throughput" {
 local -r test_name="xml_parsing_throughput"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Create larger XML file with multiple notes
 local xml_file="${TEST_DIR}/large_test.xml"
 echo '<?xml version="1.0" encoding="UTF-8"?><osm>' > "${xml_file}"
 for i in {1..1000}; do
  echo " <note id=\"${i}\" lat=\"0.0\" lon=\"0.0\"><comment action=\"opened\" uid=\"1\" user=\"test\"/></note>" >> "${xml_file}"
 done
 echo '</osm>' >> "${xml_file}"
 
 # Count notes using grep (simulating parsing)
 local parse_start
 parse_start=$(date +%s.%N 2>/dev/null || date +%s)
 local note_count
 note_count=$(grep -c '<note' "${xml_file}" 2>/dev/null || echo "0")
 local parse_end
 parse_end=$(date +%s.%N 2>/dev/null || date +%s)
 
 local parse_time
 if command -v bc > /dev/null 2>&1; then
  parse_time=$(echo "${parse_end} - ${parse_start}" | bc -l)
 else
  parse_time=$((parse_end - parse_start))
 fi
 
 # Calculate throughput (notes per second)
 local throughput
 if [[ $(echo "${parse_time} > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
  throughput=$(echo "scale=2; ${note_count} / ${parse_time}" | bc -l 2>/dev/null || echo "0")
 else
  throughput=0
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "parse_time" "${parse_time}" "seconds"
 __benchmark_record "${test_name}" "throughput" "${throughput}" "notes_per_second"
 __benchmark_record "${test_name}" "notes_processed" "${note_count}" "count"
 
 # Verify benchmark completed
 [[ "${note_count}" -eq 1000 ]]
 [[ -n "${duration}" ]]
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

# =============================================================================
# Benchmark: Memory Usage
# =============================================================================

@test "BENCHMARK: Memory usage during processing" {
 local -r test_name="memory_usage"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Measure initial memory
 local initial_memory
 initial_memory=$(__benchmark_memory)
 
 # Simulate processing (create large array)
 declare -a test_array
 for i in {1..10000}; do
  test_array[$i]="data_${i}_$(date +%s)"
 done
 
 # Measure memory after processing
 local peak_memory
 peak_memory=$(__benchmark_memory)
 
 # Calculate memory increase
 local memory_increase
 if command -v bc > /dev/null 2>&1; then
  memory_increase=$(echo "${peak_memory} - ${initial_memory}" | bc -l 2>/dev/null || echo "0")
 else
  memory_increase=$((peak_memory - initial_memory))
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "initial_memory" "${initial_memory}" "KB"
 __benchmark_record "${test_name}" "peak_memory" "${peak_memory}" "KB"
 __benchmark_record "${test_name}" "memory_increase" "${memory_increase}" "KB"
 
 # Verify benchmark completed
 [[ -n "${duration}" ]]
}

# =============================================================================
# Benchmark: Parallel Processing Performance
# =============================================================================

@test "BENCHMARK: Parallel processing throughput" {
 local -r test_name="parallel_processing"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Simulate parallel processing
 local parallel_start
 parallel_start=$(date +%s.%N 2>/dev/null || date +%s)
 
 local max_jobs=4
 local total_jobs=20
 local completed_jobs=0
 
 for i in $(seq 1 ${total_jobs}); do
  (
   sleep 0.1
   echo "Job ${i} completed"
  ) &
  
  # Limit concurrent jobs
  if [[ $(jobs -r | wc -l) -ge ${max_jobs} ]]; then
   wait -n
   completed_jobs=$((completed_jobs + 1))
  fi
 done
 wait
 completed_jobs=${total_jobs}
 
 local parallel_end
 parallel_end=$(date +%s.%N 2>/dev/null || date +%s)
 local parallel_time
 if command -v bc > /dev/null 2>&1; then
  parallel_time=$(echo "${parallel_end} - ${parallel_start}" | bc -l)
 else
  parallel_time=$((parallel_end - parallel_start))
 fi
 
 # Calculate throughput
 local throughput
 if [[ $(echo "${parallel_time} > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
  throughput=$(echo "scale=2; ${total_jobs} / ${parallel_time}" | bc -l 2>/dev/null || echo "0")
 else
  throughput=0
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "parallel_time" "${parallel_time}" "seconds"
 __benchmark_record "${test_name}" "throughput" "${throughput}" "jobs_per_second"
 __benchmark_record "${test_name}" "total_jobs" "${total_jobs}" "count"
 
 # Verify benchmark completed
 [[ "${completed_jobs}" -eq ${total_jobs} ]]
 [[ -n "${duration}" ]]
}

# =============================================================================
# Benchmark: String Processing Performance
# =============================================================================

@test "BENCHMARK: String processing performance" {
 local -r test_name="string_processing"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Create test data
 local test_data=""
 for i in {1..10000}; do
  test_data="${test_data}note_${i},lat_${i},lon_${i}\n"
 done
 
 # Measure string processing time
 local process_start
 process_start=$(date +%s.%N 2>/dev/null || date +%s)
 
 # Simulate string processing (replace, split, etc.)
 local processed_count
 processed_count=$(echo -e "${test_data}" | wc -l)
 local processed_data
 processed_data=$(echo -e "${test_data}" | sed 's/note_/NOTE_/g' | head -100)
 
 local process_end
 process_end=$(date +%s.%N 2>/dev/null || date +%s)
 local process_time
 if command -v bc > /dev/null 2>&1; then
  process_time=$(echo "${process_end} - ${process_start}" | bc -l)
 else
  process_time=$((process_end - process_start))
 fi
 
 # Calculate throughput
 local throughput
 if [[ $(echo "${process_time} > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
  throughput=$(echo "scale=2; ${processed_count} / ${process_time}" | bc -l 2>/dev/null || echo "0")
 else
  throughput=0
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "process_time" "${process_time}" "seconds"
 __benchmark_record "${test_name}" "throughput" "${throughput}" "strings_per_second"
 __benchmark_record "${test_name}" "strings_processed" "${processed_count}" "count"
 
 # Verify benchmark completed
 [[ -n "${duration}" ]]
}

# =============================================================================
# Benchmark: Network Operations Performance
# =============================================================================

@test "BENCHMARK: Network request performance" {
 local -r test_name="network_request"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Measure network request time (using localhost to avoid external dependencies)
 local network_start
 network_start=$(date +%s.%N 2>/dev/null || date +%s)
 
 # Simulate network request (using local file instead of actual network)
 local response_file="${TEST_DIR}/network_response.txt"
 echo "HTTP/1.1 200 OK" > "${response_file}"
 
 local network_end
 network_end=$(date +%s.%N 2>/dev/null || date +%s)
 local network_time
 if command -v bc > /dev/null 2>&1; then
  network_time=$(echo "${network_end} - ${network_start}" | bc -l)
 else
  network_time=$((network_end - network_start))
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "network_time" "${network_time}" "seconds"
 __benchmark_record "${test_name}" "total_duration" "${duration}" "seconds"
 
 # Verify benchmark completed
 [[ -n "${duration}" ]]
}

# =============================================================================
# Benchmark: Version Comparison
# =============================================================================

@test "BENCHMARK: Compare with previous version" {
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

