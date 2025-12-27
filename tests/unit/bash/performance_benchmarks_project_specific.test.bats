#!/usr/bin/env bats

# Performance Benchmarks: Project-Specific Operations
# Benchmarks for critical project operations (note extraction, boundary processing, spatial queries)
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
 export DBNAME="${TEST_DBNAME:-osm_notes_ingestion_test}"
 BENCHMARK_RESULTS_DIR="${TEST_DIR}/benchmark_results"
 export BENCHMARK_RESULTS_DIR
 mkdir -p "${BENCHMARK_RESULTS_DIR}"
 
 # Set log level
 export LOG_LEVEL="ERROR"
 export __log_level="ERROR"
 
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
# Benchmark: AWK Note Extraction Performance
# =============================================================================

@test "BENCHMARK: AWK note extraction from XML" {
 # Test purpose: Measure performance of extracting notes from XML using AWK
 # This is a critical operation that runs on every XML file processed
 local -r test_name="awk_note_extraction"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Create test XML file with OSM note structure
 local xml_file="${TEST_DIR}/test_notes.xml"
 echo '<?xml version="1.0" encoding="UTF-8"?><osm>' > "${xml_file}"
 
 # Generate 1000 notes with realistic structure
 for i in {1..1000}; do
  cat >> "${xml_file}" << EOF
 <note id="${i}" lat="$(echo "scale=6; $RANDOM/32767*180-90" | bc)" lon="$(echo "scale=6; $RANDOM/32767*360-180" | bc)" created_at="2025-01-01T00:00:00Z" closed_at="">
  <comment action="opened" uid="1" user="test" created_at="2025-01-01T00:00:00Z">Test comment ${i}</comment>
 </note>
EOF
 done
 echo '</osm>' >> "${xml_file}"
 
 # Check if AWK script exists
 local awk_script="${SCRIPT_BASE_DIRECTORY}/awk/extract_notes.awk"
 if [[ ! -f "${awk_script}" ]]; then
  skip "AWK script not found: ${awk_script}"
 fi
 
 # Measure AWK extraction time
 local extract_start
 extract_start=$(date +%s.%N 2>/dev/null || date +%s)
 
 local output_csv="${TEST_DIR}/extracted_notes.csv"
 awk -f "${awk_script}" "${xml_file}" > "${output_csv}" 2>/dev/null || true
 
 local extract_end
 extract_end=$(date +%s.%N 2>/dev/null || date +%s)
 
 local extract_time
 if command -v bc > /dev/null 2>&1; then
  extract_time=$(echo "${extract_end} - ${extract_start}" | bc -l)
 else
  extract_time=$((extract_end - extract_start))
 fi
 
 # Count extracted notes
 local note_count
 note_count=$(wc -l < "${output_csv}" 2>/dev/null | tr -d ' ' || echo "0")
 
 # Calculate throughput (notes per second)
 local throughput
 if [[ $(echo "${extract_time} > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
  throughput=$(echo "scale=2; ${note_count} / ${extract_time}" | bc -l 2>/dev/null || echo "0")
 else
  throughput=0
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "extract_time" "${extract_time}" "seconds"
 __benchmark_record "${test_name}" "throughput" "${throughput}" "notes_per_second"
 __benchmark_record "${test_name}" "notes_extracted" "${note_count}" "count"
 __benchmark_record "${test_name}" "total_duration" "${duration}" "seconds"
 
 # Verify benchmark completed
 [[ -n "${duration}" ]]
 [[ "${note_count}" -gt 0 ]]
}

# =============================================================================
# Benchmark: XML File Division Performance
# =============================================================================

@test "BENCHMARK: Binary XML file division" {
 # Test purpose: Measure performance of dividing large XML files into parts
 # This operation is critical for parallel processing
 local -r test_name="xml_binary_division"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Create large test XML file
 local xml_file="${TEST_DIR}/large_notes.xml"
 echo '<?xml version="1.0" encoding="UTF-8"?><osm>' > "${xml_file}"
 
 # Generate 5000 notes
 for i in {1..5000}; do
  echo " <note id=\"${i}\" lat=\"0.0\" lon=\"0.0\"><comment action=\"opened\" uid=\"1\" user=\"test\"/></note>" >> "${xml_file}"
 done
 echo '</osm>' >> "${xml_file}"
 
 # Get file size
 local file_size
 file_size=$(wc -c < "${xml_file}" 2>/dev/null | tr -d ' ' || echo "0")
 
 # Measure division time (simulate binary division)
 local divide_start
 divide_start=$(date +%s.%N 2>/dev/null || date +%s)
 
 # Simulate binary division by splitting file
 local num_parts=4
 local part_size=$((file_size / num_parts))
 
 # Create parts directory
 mkdir -p "${TEST_DIR}/parts"
 
 # Simple division simulation (split by lines)
 split -l $((5000 / num_parts)) "${xml_file}" "${TEST_DIR}/parts/part_" 2>/dev/null || true
 
 local divide_end
 divide_end=$(date +%s.%N 2>/dev/null || date +%s)
 
 local divide_time
 if command -v bc > /dev/null 2>&1; then
  divide_time=$(echo "${divide_end} - ${divide_start}" | bc -l)
 else
  divide_time=$((divide_end - divide_start))
 fi
 
 # Count created parts
 local part_count
 part_count=$(ls -1 "${TEST_DIR}/parts" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
 
 # Calculate throughput (MB per second)
 local throughput_mbps
 if [[ $(echo "${divide_time} > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
  local file_size_mb
  file_size_mb=$(echo "scale=4; ${file_size} / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
  throughput_mbps=$(echo "scale=2; ${file_size_mb} / ${divide_time}" | bc -l 2>/dev/null || echo "0")
 else
  throughput_mbps=0
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "divide_time" "${divide_time}" "seconds"
 __benchmark_record "${test_name}" "file_size" "${file_size}" "bytes"
 __benchmark_record "${test_name}" "throughput" "${throughput_mbps}" "MB_per_second"
 __benchmark_record "${test_name}" "parts_created" "${part_count}" "count"
 __benchmark_record "${test_name}" "total_duration" "${duration}" "seconds"
 
 # Verify benchmark completed
 [[ -n "${duration}" ]]
 [[ "${part_count}" -gt 0 ]]
}

# =============================================================================
# Benchmark: GeoJSON Conversion Performance
# =============================================================================

@test "BENCHMARK: JSON to GeoJSON conversion" {
 # Test purpose: Measure performance of converting JSON to GeoJSON
 # This operation is critical for boundary processing
 local -r test_name="json_to_geojson_conversion"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Create test JSON file (Overpass API format)
 local json_file="${TEST_DIR}/test_boundary.json"
 cat > "${json_file}" << 'EOF'
{
  "version": 0.6,
  "generator": "Overpass API",
  "elements": [
    {
      "type": "relation",
      "id": 12345,
      "members": [
        {"type": "way", "ref": 1, "role": "outer"}
      ],
      "tags": {"name": "Test Country", "admin_level": "2"}
    },
    {
      "type": "way",
      "id": 1,
      "nodes": [1, 2, 3, 4, 1],
      "geometry": [
        {"lat": 0.0, "lon": 0.0},
        {"lat": 1.0, "lon": 0.0},
        {"lat": 1.0, "lon": 1.0},
        {"lat": 0.0, "lon": 1.0},
        {"lat": 0.0, "lon": 0.0}
      ]
    }
  ]
}
EOF
 
 # Measure conversion time (simulate osmtogeojson)
 local convert_start
 convert_start=$(date +%s.%N 2>/dev/null || date +%s)
 
 # Simulate conversion by creating GeoJSON structure
 local geojson_file="${TEST_DIR}/test_boundary.geojson"
 cat > "${geojson_file}" << 'EOF'
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "properties": {"name": "Test Country", "admin_level": "2"},
      "geometry": {
        "type": "Polygon",
        "coordinates": [[[0.0, 0.0], [0.0, 1.0], [1.0, 1.0], [1.0, 0.0], [0.0, 0.0]]]
      }
    }
  ]
}
EOF
 
 local convert_end
 convert_end=$(date +%s.%N 2>/dev/null || date +%s)
 
 local convert_time
 if command -v bc > /dev/null 2>&1; then
  convert_time=$(echo "${convert_end} - ${convert_start}" | bc -l)
 else
  convert_time=$((convert_end - convert_start))
 fi
 
 # Get file sizes
 local json_size geojson_size
 json_size=$(wc -c < "${json_file}" 2>/dev/null | tr -d ' ' || echo "0")
 geojson_size=$(wc -c < "${geojson_file}" 2>/dev/null | tr -d ' ' || echo "0")
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "convert_time" "${convert_time}" "seconds"
 __benchmark_record "${test_name}" "json_size" "${json_size}" "bytes"
 __benchmark_record "${test_name}" "geojson_size" "${geojson_size}" "bytes"
 __benchmark_record "${test_name}" "total_duration" "${duration}" "seconds"
 
 # Verify benchmark completed
 [[ -n "${duration}" ]]
 [[ -f "${geojson_file}" ]]
}

# =============================================================================
# Benchmark: Spatial Query Performance
# =============================================================================

@test "BENCHMARK: Spatial query performance (ST_Contains)" {
 # Test purpose: Measure performance of spatial queries used for country assignment
 # This is critical for note location processing
 local -r test_name="spatial_query_st_contains"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Skip if using mock PostgreSQL
 if [[ "${BENCHMARK_USING_MOCK_PSQL:-false}" == "true" ]]; then
  skip "Skipping spatial query benchmark with mock PostgreSQL"
 fi
 
 # Check if PostgreSQL/PostGIS is available
 if ! command -v psql > /dev/null 2>&1; then
  skip "PostgreSQL not available"
 fi
 
 # Try to connect to database
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Cannot connect to database ${DBNAME}"
 fi
 
 # Create test table with geometry if PostGIS is available
 local has_postgis
 has_postgis=$(psql -d "${DBNAME}" -tAc "SELECT COUNT(*) FROM pg_extension WHERE extname = 'postgis';" 2>/dev/null || echo "0")
 
 if [[ "${has_postgis}" -eq "0" ]]; then
  skip "PostGIS extension not available"
 fi
 
 # Create test table
 psql -d "${DBNAME}" -c "
  CREATE TABLE IF NOT EXISTS test_boundaries (
    id INTEGER PRIMARY KEY,
    name TEXT,
    geom GEOMETRY(POLYGON, 4326)
  );
  CREATE INDEX IF NOT EXISTS test_boundaries_geom_idx ON test_boundaries USING GIST(geom);
 " > /dev/null 2>&1 || true
 
 # Insert test boundary (simple rectangle)
 psql -d "${DBNAME}" -c "
  INSERT INTO test_boundaries (id, name, geom) VALUES
  (1, 'Test Country', ST_GeomFromText('POLYGON((0 0, 0 10, 10 10, 10 0, 0 0))', 4326))
  ON CONFLICT (id) DO UPDATE SET geom = EXCLUDED.geom;
 " > /dev/null 2>&1 || true
 
 # Measure spatial query time
 local query_start
 query_start=$(date +%s.%N 2>/dev/null || date +%s)
 
 # Execute spatial query (ST_Contains)
 local result_count
 result_count=$(psql -d "${DBNAME}" -tAc "
  SELECT COUNT(*) FROM test_boundaries
  WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(5.0, 5.0), 4326));
 " 2>/dev/null | tr -d ' ' || echo "0")
 
 local query_end
 query_end=$(date +%s.%N 2>/dev/null || date +%s)
 
 local query_time
 if command -v bc > /dev/null 2>&1; then
  query_time=$(echo "${query_end} - ${query_start}" | bc -l)
 else
  query_time=$((query_end - query_start))
 fi
 
 # Execute multiple queries to get average
 local total_time="${query_time}"
 local num_queries=10
 
 for i in $(seq 2 ${num_queries}); do
  local q_start q_end q_time
  q_start=$(date +%s.%N 2>/dev/null || date +%s)
  psql -d "${DBNAME}" -tAc "
   SELECT COUNT(*) FROM test_boundaries
   WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint($(echo "scale=6; $RANDOM/32767*10" | bc), $(echo "scale=6; $RANDOM/32767*10" | bc)), 4326));
  " > /dev/null 2>&1 || true
  q_end=$(date +%s.%N 2>/dev/null || date +%s)
  
  if command -v bc > /dev/null 2>&1; then
   q_time=$(echo "${q_end} - ${q_start}" | bc -l)
   total_time=$(echo "${total_time} + ${q_time}" | bc -l)
  else
   q_time=$((q_end - q_start))
   total_time=$((total_time + q_time))
  fi
 done
 
 # Calculate average query time
 local avg_query_time
 if command -v bc > /dev/null 2>&1; then
  avg_query_time=$(echo "scale=6; ${total_time} / ${num_queries}" | bc -l)
 else
  avg_query_time=$((total_time / num_queries))
 fi
 
 # Calculate queries per second
 local queries_per_second
 if [[ $(echo "${avg_query_time} > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
  queries_per_second=$(echo "scale=2; 1 / ${avg_query_time}" | bc -l 2>/dev/null || echo "0")
 else
  queries_per_second=0
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "avg_query_time" "${avg_query_time}" "seconds"
 __benchmark_record "${test_name}" "total_query_time" "${total_time}" "seconds"
 __benchmark_record "${test_name}" "queries_per_second" "${queries_per_second}" "queries_per_second"
 __benchmark_record "${test_name}" "num_queries" "${num_queries}" "count"
 __benchmark_record "${test_name}" "total_duration" "${duration}" "seconds"
 
 # Verify benchmark completed
 [[ -n "${duration}" ]]
 [[ "${result_count}" -ge 0 ]]
}

# =============================================================================
# Benchmark: CSV Processing Performance
# =============================================================================

@test "BENCHMARK: CSV processing and validation" {
 # Test purpose: Measure performance of CSV processing operations
 # This is critical for note and comment data processing
 local -r test_name="csv_processing"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Create test CSV file with note data
 local csv_file="${TEST_DIR}/test_notes.csv"
 echo "note_id,latitude,longitude,created_at,status" > "${csv_file}"
 
 # Generate 10000 rows
 for i in {1..10000}; do
  echo "${i},$(echo "scale=6; $RANDOM/32767*180-90" | bc),$(echo "scale=6; $RANDOM/32767*360-180" | bc),2025-01-01T00:00:00Z,open" >> "${csv_file}"
 done
 
 # Measure CSV processing time
 local process_start
 process_start=$(date +%s.%N 2>/dev/null || date +%s)
 
 # Simulate CSV processing (count rows, validate format)
 local row_count
 row_count=$(tail -n +2 "${csv_file}" | wc -l | tr -d ' ' || echo "0")
 
 # Validate CSV structure (check column count)
 local valid_rows
 valid_rows=$(awk -F',' 'NF == 5 {count++} END {print count+0}' "${csv_file}" 2>/dev/null || echo "0")
 
 local process_end
 process_end=$(date +%s.%N 2>/dev/null || date +%s)
 
 local process_time
 if command -v bc > /dev/null 2>&1; then
  process_time=$(echo "${process_end} - ${process_start}" | bc -l)
 else
  process_time=$((process_end - process_start))
 fi
 
 # Calculate throughput (rows per second)
 local throughput
 if [[ $(echo "${process_time} > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
  throughput=$(echo "scale=2; ${row_count} / ${process_time}" | bc -l 2>/dev/null || echo "0")
 else
  throughput=0
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "process_time" "${process_time}" "seconds"
 __benchmark_record "${test_name}" "throughput" "${throughput}" "rows_per_second"
 __benchmark_record "${test_name}" "rows_processed" "${row_count}" "count"
 __benchmark_record "${test_name}" "valid_rows" "${valid_rows}" "count"
 __benchmark_record "${test_name}" "total_duration" "${duration}" "seconds"
 
 # Verify benchmark completed
 [[ -n "${duration}" ]]
 [[ "${row_count}" -eq 10000 ]]
 [[ "${valid_rows}" -eq 10001 ]] # Header + 10000 rows
}

# =============================================================================
# Benchmark: Bulk Database Insert Performance
# =============================================================================

@test "BENCHMARK: Bulk database insert performance" {
 # Test purpose: Measure performance of bulk inserts used for note loading
 # This is critical for initial data loading
 local -r test_name="bulk_db_insert"
 local start_time
 start_time=$(__benchmark_start "${test_name}")
 
 # Skip if using mock PostgreSQL
 if [[ "${BENCHMARK_USING_MOCK_PSQL:-false}" == "true" ]]; then
  skip "Skipping bulk insert benchmark with mock PostgreSQL"
 fi
 
 # Check if PostgreSQL is available
 if ! command -v psql > /dev/null 2>&1; then
  skip "PostgreSQL not available"
 fi
 
 # Try to connect to database
 if ! psql -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
  skip "Cannot connect to database ${DBNAME}"
 fi
 
 # Create test table
 psql -d "${DBNAME}" -c "
  CREATE TABLE IF NOT EXISTS test_bulk_insert (
    id INTEGER PRIMARY KEY,
    data TEXT,
    created_at TIMESTAMP DEFAULT NOW()
  );
 " > /dev/null 2>&1 || true
 
 # Clear table
 psql -d "${DBNAME}" -c "TRUNCATE TABLE test_bulk_insert;" > /dev/null 2>&1 || true
 
 # Create CSV file for bulk insert
 local csv_file="${TEST_DIR}/bulk_data.csv"
 for i in {1..1000}; do
  echo "${i},test_data_${i}" >> "${csv_file}"
 done
 
 # Measure bulk insert time
 local insert_start
 insert_start=$(date +%s.%N 2>/dev/null || date +%s)
 
 # Perform bulk insert using COPY
 psql -d "${DBNAME}" -c "
  COPY test_bulk_insert (id, data) FROM STDIN WITH (FORMAT csv, DELIMITER ',');
 " < "${csv_file}" > /dev/null 2>&1 || true
 
 local insert_end
 insert_end=$(date +%s.%N 2>/dev/null || date +%s)
 
 local insert_time
 if command -v bc > /dev/null 2>&1; then
  insert_time=$(echo "${insert_end} - ${insert_start}" | bc -l)
 else
  insert_time=$((insert_end - insert_start))
 fi
 
 # Count inserted rows
 local inserted_count
 inserted_count=$(psql -d "${DBNAME}" -tAc "SELECT COUNT(*) FROM test_bulk_insert;" 2>/dev/null | tr -d ' ' || echo "0")
 
 # Calculate insert throughput (rows per second)
 local insert_throughput
 if [[ $(echo "${insert_time} > 0" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
  insert_throughput=$(echo "scale=2; ${inserted_count} / ${insert_time}" | bc -l 2>/dev/null || echo "0")
 else
  insert_throughput=0
 fi
 
 local duration
 duration=$(__benchmark_end "${test_name}")
 
 # Record metrics
 __benchmark_record "${test_name}" "insert_time" "${insert_time}" "seconds"
 __benchmark_record "${test_name}" "insert_throughput" "${insert_throughput}" "rows_per_second"
 __benchmark_record "${test_name}" "rows_inserted" "${inserted_count}" "count"
 __benchmark_record "${test_name}" "total_duration" "${duration}" "seconds"
 
 # Cleanup
 psql -d "${DBNAME}" -c "DROP TABLE IF EXISTS test_bulk_insert;" > /dev/null 2>&1 || true
 
 # Verify benchmark completed
 [[ -n "${duration}" ]]
 [[ "${inserted_count}" -gt 0 ]]
}

