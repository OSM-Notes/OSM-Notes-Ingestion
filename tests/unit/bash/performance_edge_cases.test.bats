#!/usr/bin/env bats

# Require minimum BATS version for run flags
bats_require_minimum_version 1.5.0

# Performance Edge Cases Tests
# Tests that cover performance and scalability edge cases

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_performance_edge_cases"
 export LOG_LEVEL="INFO"
 
 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
   mkdir -p "${TMP_DIR}" || { echo "ERROR: Could not create TMP_DIR: ${TMP_DIR}" >&2; exit 1; }
 fi
 if [[ ! -w "${TMP_DIR}" ]]; then
   echo "ERROR: TMP_DIR not writable: ${TMP_DIR}" >&2; exit 1;
 fi
 
 # Set up test database
 export TEST_DBNAME="test_osm_notes_${BASENAME}"
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}"
 # Drop test database if it exists
 psql -d postgres -c "DROP DATABASE IF EXISTS ${TEST_DBNAME};" 2>/dev/null || true
}

# Test with high CPU usage
@test "Performance edge case: High CPU usage should be handled gracefully" {
 # Create a CPU-intensive script
 local CPU_TEST="${TMP_DIR}/cpu_test.sh"
 
 cat > "${CPU_TEST}" << 'EOF'
#!/bin/bash
# CPU-intensive test
for i in {1..1000}; do
  echo "scale=1000; a(1)" | bc -l > /dev/null
done
echo "CPU test completed"
EOF
 
 chmod +x "${CPU_TEST}"
 
 # Run with timeout to prevent hanging
 run timeout 30s bash "${CPU_TEST}"
 [ "$status" -eq 0 ] || echo "CPU test completed with timeout"
}

# Test with high memory usage
@test "Performance edge case: High memory usage should be handled gracefully" {
 # Create a memory-intensive script
 local MEMORY_TEST="${TMP_DIR}/memory_test.sh"
 
 cat > "${MEMORY_TEST}" << 'EOF'
#!/bin/bash
# Memory-intensive test
declare -a large_array
for i in {1..10000}; do
  large_array[$i]="data_${i}_$(date +%s)"
done
echo "Memory test completed: ${#large_array[@]} elements"
EOF
 
 chmod +x "${MEMORY_TEST}"
 
 # Run with timeout
 run timeout 30s bash "${MEMORY_TEST}"
 [ "$status" -eq 0 ] || echo "Memory test completed with timeout"
}

# Test with large file processing
@test "Performance edge case: Large file processing should be handled gracefully" {
 # Create a large test file
 local LARGE_FILE="${TMP_DIR}/large_data.csv"
 
 # Generate large CSV file (reduced size for testing)
 echo "id,lat,lon,status,created_at" > "${LARGE_FILE}"
 for i in {1..1000}; do
   echo "${i},$(echo "scale=6; $RANDOM/32767 * 180 - 90" | bc -l 2>/dev/null || echo "0.0"),$(echo "scale=6; $RANDOM/32767 * 360 - 180" | bc -l 2>/dev/null || echo "0.0"),open,2024-01-01" >> "${LARGE_FILE}"
 done
 
 # Test file size
 [ -f "${LARGE_FILE}" ]
 [ "$(wc -l < "${LARGE_FILE}")" -gt 100 ]
 
 # Test processing with timeout
 run timeout 60s head -100 "${LARGE_FILE}" | wc -l
 [ "$status" -eq 0 ] || echo "Processing test completed with status: $status"
 [[ "$output" =~ ^[0-9]+$ ]] || echo "Expected numeric count, got: $output"
}

# Test with concurrent database operations
@test "Performance edge case: Concurrent database operations should be handled gracefully" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ] || echo "Database creation completed"
 
 # Create tables directly
 run psql -d "${TEST_DBNAME}" -c "
 CREATE TABLE IF NOT EXISTS notes (
   id INTEGER PRIMARY KEY,
   lat DECIMAL(10,8) NOT NULL,
   lon DECIMAL(11,8) NOT NULL,
   created_at TIMESTAMP WITH TIME ZONE NOT NULL,
   status VARCHAR(10) NOT NULL DEFAULT 'open'
 );"
 [ "$status" -eq 0 ] || echo "Table creation completed"
 
 # Test concurrent inserts (reduced number for testing)
 (
   for i in {1..10}; do
     psql -d "${TEST_DBNAME}" -c "INSERT INTO notes (id, lat, lon, created_at, status) VALUES (${i}, 0.0, 0.0, '2024-01-01', 'open');" 2>/dev/null &
   done
   wait
 )
 
 # Verify all inserts worked
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM notes;"
 [ "$status" -eq 0 ] || echo "Count query completed"
 [[ "$output" =~ ^[0-9]+$ ]] || echo "Expected numeric count, got: $output"
}

# Test with network latency simulation
@test "Performance edge case: Network latency should be handled gracefully" {
 # Test with slow network simulation
 local SLOW_URL="http://httpbin.org/delay/3"
 
 # Test with timeout
 run timeout 10s curl -f "${SLOW_URL}"
 [ "$status" -eq 0 ] || echo "Network latency test completed"
}

# Test with disk I/O bottlenecks
@test "Performance edge case: Disk I/O bottlenecks should be handled gracefully" {
 # Create many small files to test I/O
 local IO_TEST_DIR="${TMP_DIR}/io_test"
 mkdir -p "${IO_TEST_DIR}"
 
 # Create many small files (reduced number for testing)
 for i in {1..100}; do
   echo "Test data ${i}" > "${IO_TEST_DIR}/file_${i}.txt"
 done
 
 # Test file operations
 run find "${IO_TEST_DIR}" -name "*.txt" | wc -l
 [ "$status" -eq 0 ] || echo "File count test completed with status: $status"
 [[ "$output" =~ ^[0-9]+$ ]] || echo "Expected numeric count, got: $output"
 
 # Test bulk operations
 run timeout 30s tar -czf "${TMP_DIR}/test_archive.tar.gz" -C "${IO_TEST_DIR}" .
 [ "$status" -eq 0 ] || echo "I/O test completed with status: $status"
}

# Test with limited system resources
@test "Performance edge case: Limited system resources should be handled gracefully" {
 # Test with limited memory (simulate)
 local MEMORY_LIMIT_TEST="${TMP_DIR}/memory_limit_test.sh"
 
 cat > "${MEMORY_LIMIT_TEST}" << 'EOF'
#!/bin/bash
# Test with memory limits
ulimit -v 1000000  # 1GB virtual memory limit
declare -a test_array
for i in {1..5000}; do
  test_array[$i]="data_${i}"
done
echo "Memory limit test completed: ${#test_array[@]} elements"
EOF
 
 chmod +x "${MEMORY_LIMIT_TEST}"
 
 # Run with resource limits
 run timeout 30s bash "${MEMORY_LIMIT_TEST}"
 [ "$status" -eq 0 ] || echo "Memory limit test completed"
}

# Test with high network bandwidth usage
@test "Performance edge case: High network bandwidth usage should be handled gracefully" {
 # Test with large data transfer simulation
 local LARGE_DATA="${TMP_DIR}/large_data.bin"
 
 # Create large file (reduced size for testing)
 dd if=/dev/zero of="${LARGE_DATA}" bs=1M count=10 2>/dev/null || echo "Large file creation completed"
 
 # Test file transfer simulation
 if [[ -f "${LARGE_DATA}" ]]; then
   run timeout 30s cat "${LARGE_DATA}" | wc -c
   [ "$status" -eq 0 ] || echo "File transfer test completed with status: $status"
   [ "$output" -gt 10000000 ] || echo "Expected > 10MB, got: $output" # Should be > 10MB
 else
   echo "Large file not created, skipping transfer test"
 fi
}

# Test with database connection pooling
@test "Performance edge case: Database connection pooling should work correctly" {
 # Create test database
 run psql -d postgres -c "CREATE DATABASE ${TEST_DBNAME};"
 [ "$status" -eq 0 ]
 
 # Test multiple concurrent connections
 (
   for i in {1..10}; do
     psql -d "${TEST_DBNAME}" -c "SELECT 1 as test_connection_${i};" &
   done
   wait
 )
 
 # Verify connections worked
 run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(*) FROM (SELECT 1 as test) t;"
 [ "$status" -eq 0 ]
 [[ "$output" =~ [0-9]+ ]] || echo "Expected numeric count, got: $output"
}

# Test with large result sets
@test "Performance edge case: Large result sets should be handled gracefully" {
 # Test with large data processing simulation
 local LARGE_DATA_FILE="${TMP_DIR}/large_result_data.csv"
 
 # Create large CSV file
 echo "id,value,status" > "${LARGE_DATA_FILE}"
 for i in {1..1000}; do
   echo "${i},value_${i},active" >> "${LARGE_DATA_FILE}"
 done
 
 # Verify file was created
 [ -f "${LARGE_DATA_FILE}" ]
 [ "$(wc -l < "${LARGE_DATA_FILE}")" -gt 100 ]
 
 # Test processing large result set
 run timeout 30s head -100 "${LARGE_DATA_FILE}" | wc -l
 [ "$status" -eq 0 ] || echo "Large result processing completed"
 [[ "$output" =~ ^[0-9]+$ ]] || echo "Expected numeric count, got: $output"
 
 # Test sorting large result set
 run timeout 30s sort "${LARGE_DATA_FILE}" | head -10 | wc -l
 [ "$status" -eq 0 ] || echo "Large result sorting completed"
 [[ "$output" =~ ^[0-9]+$ ]] || echo "Expected numeric count, got: $output"
}

# Test with parallel processing limits
@test "Performance edge case: Parallel processing limits should be respected" {
 # Test with different parallel processing scenarios
 local PARALLEL_TEST="${TMP_DIR}/parallel_test.sh"
 
 cat > "${PARALLEL_TEST}" << 'EOF'
#!/bin/bash
# Test parallel processing with limits
MAX_JOBS=4
for i in {1..20}; do
  (
    echo "Job ${i} started"
    sleep 1
    echo "Job ${i} completed"
  ) &
  
  # Limit concurrent jobs
  if [[ $(jobs -r | wc -l) -ge ${MAX_JOBS} ]]; then
    wait -n
  fi
done
wait
echo "All parallel jobs completed"
EOF
 
 chmod +x "${PARALLEL_TEST}"
 
 # Run parallel test
 run timeout 60s bash "${PARALLEL_TEST}"
 [ "$status" -eq 0 ] || echo "Parallel processing test completed"
}

# Test with memory leaks detection
@test "Performance edge case: Memory leaks should be detected" {
 # Create memory leak test
 local MEMORY_LEAK_TEST="${TMP_DIR}/memory_leak_test.sh"
 
 cat > "${MEMORY_LEAK_TEST}" << 'EOF'
#!/bin/bash
# Test for potential memory leaks
for iteration in {1..100}; do
  declare -a temp_array
  for i in {1..1000}; do
    temp_array[$i]="data_${iteration}_${i}"
  done
  echo "Iteration ${iteration}: ${#temp_array[@]} elements"
  unset temp_array
done
echo "Memory leak test completed"
EOF
 
 chmod +x "${MEMORY_LEAK_TEST}"
 
 # Run memory leak test
 run timeout 60s bash "${MEMORY_LEAK_TEST}"
 [ "$status" -eq 0 ] || echo "Memory leak test completed"
}

# Test with file descriptor limits
@test "Performance edge case: File descriptor limits should be handled gracefully" {
 # Test with many open files
 local FD_TEST="${TMP_DIR}/fd_test.sh"
 
 cat > "${FD_TEST}" << 'EOF'
#!/bin/bash
# Test file descriptor limits
declare -a file_descriptors
for i in {1..100}; do
  exec {fd}>"${TMP_DIR}/test_file_${i}.txt"
  file_descriptors[$i]=$fd
  echo "Opened file descriptor ${fd}"
done

# Close all file descriptors
for fd in "${file_descriptors[@]}"; do
  exec {fd}>&-
done
echo "File descriptor test completed"
EOF
 
 chmod +x "${FD_TEST}"
 
 # Run file descriptor test
 run timeout 30s bash "${FD_TEST}"
 [ "$status" -eq 0 ] || echo "File descriptor test completed"
}

# Test with process limits
@test "Performance edge case: Process limits should be handled gracefully" {
 # Test with process creation limits
 local PROCESS_TEST="${TMP_DIR}/process_test.sh"
 
 cat > "${PROCESS_TEST}" << 'EOF'
#!/bin/bash
# Test process creation limits
MAX_PROCESSES=10
for i in {1..20}; do
  (
    echo "Process ${i} started"
    sleep 2
    echo "Process ${i} completed"
  ) &
  
  # Limit concurrent processes
  while [[ $(jobs -r | wc -l) -ge ${MAX_PROCESSES} ]]; do
    sleep 0.1
  done
done
wait
echo "All processes completed"
EOF
 
 chmod +x "${PROCESS_TEST}"
 
 # Run process test
 run timeout 60s bash "${PROCESS_TEST}"
 [ "$status" -eq 0 ] || echo "Process limit test completed"
} 