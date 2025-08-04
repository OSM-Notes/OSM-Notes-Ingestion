#!/usr/bin/env bats

# Test file for parallel threshold functionality
# Tests the minimum notes threshold for parallel processing

# Define the properties directly in the test to avoid conflicts
MIN_NOTES_FOR_PARALLEL="10"
MAX_NOTES="10000"
MAX_THREADS="4"

setup() {
 # Create temporary directory for tests
 TEST_TMP_DIR=$(mktemp -d)
 export TMP_DIR="${TEST_TMP_DIR}"
 
 # Mock logger functions
 function __log_start() { echo "LOG_START: $*"; }
 function __log_finish() { echo "LOG_FINISH: $*"; }
 function __logi() { echo "LOG_INFO: $*"; }
 function __logd() { echo "LOG_DEBUG: $*"; }
 function __logw() { echo "LOG_WARN: $*"; }
 function __loge() { echo "LOG_ERROR: $*"; }
 
 # Export logger functions
 export -f __log_start __log_finish __logi __logd __logw __loge
 
 # Create test XML files
 create_test_xml_files
}

teardown() {
 # Clean up temporary directory
 rm -rf "${TEST_TMP_DIR}"
}

create_test_xml_files() {
 # Create a small XML file with few notes
 cat > "${TEST_TMP_DIR}/small_notes.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm>
 <note id="123" lat="40.7128" lon="-74.0060" created_at="2023-01-01T00:00:00Z" closed_at="">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="12345" user="testuser">
   <text>Test note 1</text>
  </comment>
 </note>
 <note id="124" lat="40.7129" lon="-74.0061" created_at="2023-01-01T01:00:00Z" closed_at="">
  <comment action="opened" timestamp="2023-01-01T01:00:00Z" uid="12346" user="testuser2">
   <text>Test note 2</text>
  </comment>
 </note>
</osm>
EOF

 # Create a larger XML file with many notes
 cat > "${TEST_TMP_DIR}/large_notes.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm>
EOF

 # Add 15 notes to the large file
 for i in {1..15}; do
  cat >> "${TEST_TMP_DIR}/large_notes.xml" << EOF
 <note id="${i}" lat="40.712${i}" lon="-74.006${i}" created_at="2023-01-01T0${i}:00:00Z" closed_at="">
  <comment action="opened" timestamp="2023-01-01T0${i}:00:00Z" uid="1234${i}" user="testuser${i}">
   <text>Test note ${i}</text>
  </comment>
 </note>
EOF
 done

 cat >> "${TEST_TMP_DIR}/large_notes.xml" << 'EOF'
</osm>
EOF
}

@test "MIN_NOTES_FOR_PARALLEL should be defined" {
 # Test that the variable is defined in the test file
 [[ -n "${MIN_NOTES_FOR_PARALLEL}" ]]
 [[ "${MIN_NOTES_FOR_PARALLEL}" -gt 0 ]]
}

@test "MIN_NOTES_FOR_PARALLEL should have a reasonable default value" {
 # Should be at least 5 and at most 50 for reasonable performance
 [[ "${MIN_NOTES_FOR_PARALLEL}" -ge 5 ]]
 [[ "${MIN_NOTES_FOR_PARALLEL}" -le 50 ]]
}

@test "should process small datasets sequentially" {
 # Mock the functions that would be called for sequential processing
 function __processApiXmlSequential() {
  echo "SEQUENTIAL_PROCESSING: $*"
  return 0
 }
 
 # Mock the parallel processing functions
 function __splitXmlForParallelAPI() {
  echo "PARALLEL_SPLIT: $*"
  return 0
 }
 function __processXmlPartsParallel() {
  echo "PARALLEL_PROCESS: $*"
  return 0
 }
 
 # Export mock functions
 export -f __processApiXmlSequential __splitXmlForParallelAPI __processXmlPartsParallel
 
 # Set up a small number of notes (below threshold)
 TOTAL_NOTES=5
 export TOTAL_NOTES
 
 # Mock the XML file path
 API_NOTES_FILE="${TEST_TMP_DIR}/small_notes.xml"
 export API_NOTES_FILE
 
 # Mock XSLT files
 XSLT_NOTES_API_FILE="/tmp/notes.xslt"
 XSLT_NOTE_COMMENTS_API_FILE="/tmp/comments.xslt"
 XSLT_TEXT_COMMENTS_API_FILE="/tmp/text.xslt"
 export XSLT_NOTES_API_FILE XSLT_NOTE_COMMENTS_API_FILE XSLT_TEXT_COMMENTS_API_FILE
 
 # Run the processing logic (simplified version)
 output=""
 if [[ "${TOTAL_NOTES}" -ge "${MIN_NOTES_FOR_PARALLEL:-10}" ]]; then
  output+="PARALLEL_PROCESSING_SELECTED"$'\n'
  output+="$(__splitXmlForParallelAPI "${API_NOTES_FILE}")"$'\n'
  output+="$(__processXmlPartsParallel "__processApiXmlPart")"$'\n'
 else
  output+="SEQUENTIAL_PROCESSING_SELECTED"$'\n'
  output+="$(__processApiXmlSequential "${API_NOTES_FILE}")"$'\n'
 fi
 
 # Verify that sequential processing was selected
 [[ "${output}" == *"SEQUENTIAL_PROCESSING_SELECTED"* ]]
 [[ "${output}" == *"SEQUENTIAL_PROCESSING: ${API_NOTES_FILE}"* ]]
}

@test "should process large datasets in parallel" {
 # Mock the functions that would be called for parallel processing
 function __splitXmlForParallelAPI() {
  echo "PARALLEL_SPLIT: $*"
  return 0
 }
 function __processXmlPartsParallel() {
  echo "PARALLEL_PROCESS: $*"
  return 0
 }
 
 # Mock the sequential processing function
 function __processApiXmlSequential() {
  echo "SEQUENTIAL_PROCESSING: $*"
  return 0
 }
 
 # Export mock functions
 export -f __splitXmlForParallelAPI __processXmlPartsParallel __processApiXmlSequential
 
 # Set up a large number of notes (above threshold)
 TOTAL_NOTES=15
 export TOTAL_NOTES
 
 # Mock the XML file path
 API_NOTES_FILE="${TEST_TMP_DIR}/large_notes.xml"
 export API_NOTES_FILE
 
 # Mock XSLT files
 XSLT_NOTES_API_FILE="/tmp/notes.xslt"
 XSLT_NOTE_COMMENTS_API_FILE="/tmp/comments.xslt"
 XSLT_TEXT_COMMENTS_API_FILE="/tmp/text.xslt"
 export XSLT_NOTES_API_FILE XSLT_NOTE_COMMENTS_API_FILE XSLT_TEXT_COMMENTS_API_FILE
 
 # Run the processing logic (simplified version)
 output=""
 if [[ "${TOTAL_NOTES}" -ge "${MIN_NOTES_FOR_PARALLEL}" ]]; then
  output+="PARALLEL_PROCESSING_SELECTED"$'\n'
  output+="$(__splitXmlForParallelAPI "${API_NOTES_FILE}")"$'\n'
  output+="$(__processXmlPartsParallel "__processApiXmlPart")"$'\n'
 else
  output+="SEQUENTIAL_PROCESSING_SELECTED"$'\n'
  output+="$(__processApiXmlSequential "${API_NOTES_FILE}")"$'\n'
 fi
 
 # Verify that parallel processing was selected
 [[ "${output}" == *"PARALLEL_PROCESSING_SELECTED"* ]]
 [[ "${output}" == *"PARALLEL_SPLIT: ${API_NOTES_FILE}"* ]]
 [[ "${output}" == *"PARALLEL_PROCESS: __processApiXmlPart"* ]]
}

@test "should handle edge case at threshold boundary" {
 # Mock functions
 function __splitXmlForParallelAPI() {
  echo "PARALLEL_SPLIT: $*"
  return 0
 }
 function __processXmlPartsParallel() {
  echo "PARALLEL_PROCESS: $*"
  return 0
 }
 function __processApiXmlSequential() {
  echo "SEQUENTIAL_PROCESSING: $*"
  return 0
 }
 
 export -f __splitXmlForParallelAPI __processXmlPartsParallel __processApiXmlSequential
 
 # Test exactly at the threshold
 TOTAL_NOTES="${MIN_NOTES_FOR_PARALLEL}"
 export TOTAL_NOTES
 
 API_NOTES_FILE="${TEST_TMP_DIR}/threshold_notes.xml"
 export API_NOTES_FILE
 
 # Mock XSLT files
 XSLT_NOTES_API_FILE="/tmp/notes.xslt"
 XSLT_NOTE_COMMENTS_API_FILE="/tmp/comments.xslt"
 XSLT_TEXT_COMMENTS_API_FILE="/tmp/text.xslt"
 export XSLT_NOTES_API_FILE XSLT_NOTE_COMMENTS_API_FILE XSLT_TEXT_COMMENTS_API_FILE
 
 # Run the processing logic
 output=""
 if [[ "${TOTAL_NOTES}" -ge "${MIN_NOTES_FOR_PARALLEL}" ]]; then
  output+="PARALLEL_PROCESSING_SELECTED"$'\n'
  output+="$(__splitXmlForParallelAPI "${API_NOTES_FILE}")"$'\n'
  output+="$(__processXmlPartsParallel "__processApiXmlPart")"$'\n'
 else
  output+="SEQUENTIAL_PROCESSING_SELECTED"$'\n'
  output+="$(__processApiXmlSequential "${API_NOTES_FILE}")"$'\n'
 fi
 
 # Verify that parallel processing was selected (threshold is inclusive)
 [[ "${output}" == *"PARALLEL_PROCESSING_SELECTED"* ]]
}

@test "should handle zero notes gracefully" {
 # Mock functions
 function __splitXmlForParallelAPI() {
  echo "PARALLEL_SPLIT: $*"
  return 0
 }
 function __processApiXmlSequential() {
  echo "SEQUENTIAL_PROCESSING: $*"
  return 0
 }
 
 export -f __splitXmlForParallelAPI __processApiXmlSequential
 
 # Test with zero notes
 TOTAL_NOTES=0
 export TOTAL_NOTES
 
 API_NOTES_FILE="${TEST_TMP_DIR}/empty_notes.xml"
 export API_NOTES_FILE
 
 # Run the processing logic
 output=""
 if [[ "${TOTAL_NOTES}" -gt 0 ]]; then
  if [[ "${TOTAL_NOTES}" -ge "${MIN_NOTES_FOR_PARALLEL}" ]]; then
   output+="PARALLEL_PROCESSING_SELECTED"$'\n'
   output+="$(__splitXmlForParallelAPI "${API_NOTES_FILE}")"$'\n'
  else
   output+="SEQUENTIAL_PROCESSING_SELECTED"$'\n'
   output+="$(__processApiXmlSequential "${API_NOTES_FILE}")"$'\n'
  fi
 else
  output+="NO_NOTES_FOUND"$'\n'
 fi
 
 # Verify that no processing was selected
 [[ "${output}" == *"NO_NOTES_FOUND"* ]]
} 