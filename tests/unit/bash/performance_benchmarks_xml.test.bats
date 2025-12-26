#!/usr/bin/env bats

# Performance Benchmarks: XML Processing
# Benchmarks for XML validation and parsing performance
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

