#!/usr/bin/env bats

# XML Validation Dates Tests
# Tests for ISO8601 date validation and lightweight date validation
# Author: Andres Gomez (AngocA)
# Version: 2025-08-07

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
 # Source validation functions
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh" 2>/dev/null || true
}

teardown() {
 # Cleanup test files
 rm -f /tmp/test_*.xml
}

# =============================================================================
# Tests for __validate_iso8601_date
# =============================================================================

@test "test __validate_iso8601_date with valid dates" {
 # Test valid ISO8601 dates
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"
 
 # Test various valid date formats
 run __validate_iso8601_date "2023-01-01T00:00:00Z" "test date"
 [[ "${status}" -eq 0 ]]
 
 run __validate_iso8601_date "2023-12-31T23:59:59Z" "test date"
 [[ "${status}" -eq 0 ]]
 
 run __validate_iso8601_date "2023-06-15T08:30:45Z" "test date"
 [[ "${status}" -eq 0 ]]
}

@test "test __validate_iso8601_date with leading zeros" {
 # Test dates with leading zeros (should work correctly)
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"
 
 # Test dates with leading zeros
 run __validate_iso8601_date "2023-04-08T08:09:05Z" "test date"
 [[ "${status}" -eq 0 ]]
 
 run __validate_iso8601_date "2023-09-12T13:41:32Z" "test date"
 [[ "${status}" -eq 0 ]]
}

@test "test __validate_iso8601_date with invalid dates" {
 # Test invalid date formats
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"
 
 # Test invalid month
 run __validate_iso8601_date "2023-13-01T00:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test invalid day
 run __validate_iso8601_date "2023-01-32T00:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test invalid hour
 run __validate_iso8601_date "2023-01-01T24:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test invalid minute
 run __validate_iso8601_date "2023-01-01T00:60:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test invalid second
 run __validate_iso8601_date "2023-01-01T00:00:60Z" "test date"
 [[ "${status}" -eq 1 ]]
}

@test "test __validate_iso8601_date with invalid characters" {
 # Test dates with invalid characters (should fail)
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"
 
 # Test date with letters instead of numbers
 run __validate_iso8601_date "2023-aa-01T00:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test date with letters in month
 run __validate_iso8601_date "2023-1a-01T00:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test date with letters in day
 run __validate_iso8601_date "2023-01-1bT00:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test date with letters in hour
 run __validate_iso8601_date "2023-01-01T1c:00:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test date with letters in minute
 run __validate_iso8601_date "2023-01-01T00:1d:00Z" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test date with letters in second
 run __validate_iso8601_date "2023-01-01T00:00:1eZ" "test date"
 [[ "${status}" -eq 1 ]]
}

@test "test __validate_iso8601_date with malformed dates" {
 # Test malformed date strings
 source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/validationFunctions.sh"
 
 # Test empty date
 run __validate_iso8601_date "" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test invalid format
 run __validate_iso8601_date "2023-01-01 00:00:00" "test date"
 [[ "${status}" -eq 1 ]]
 
 # Test missing timezone
 run __validate_iso8601_date "2023-01-01T00:00:00" "test date"
 [[ "${status}" -eq 1 ]]
}

# =============================================================================
# Tests for __validate_xml_dates_lightweight
# =============================================================================

@test "test __validate_xml_dates_lightweight with valid dates" {
 # Test lightweight date validation with valid dates
 # Functions are already loaded via functionsProcess.sh
 
 # Create test XML with valid dates
 cat > /tmp/test_dates.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-04-08T08:09:05Z">
  <comment action="opened" timestamp="2023-09-12T13:41:32Z" uid="1" user="test">Test comment</comment>
 </note>
 <note id="2" lat="0.0" lon="0.0" created_at="2023-06-15T14:30:45Z"/>
</osm-notes>
EOF
 
 run __validate_xml_dates_lightweight "/tmp/test_dates.xml"
 [[ "${status}" -eq 0 ]]
 [[ "${output}" == *"XML dates validation passed (sample-based)"* ]]
}

@test "test __validate_xml_dates_lightweight with invalid dates" {
 # Test lightweight date validation with invalid dates
 # Functions are already loaded via functionsProcess.sh
 
 # Create test XML with invalid dates
 cat > /tmp/test_invalid_dates.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-13-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-32T24:00:00Z" uid="1" user="test">Test comment</comment>
 </note>
 <note id="2" lat="0.0" lon="0.0" created_at="2023-01-01T25:00:00Z"/>
</osm-notes>
EOF
 
 run __validate_xml_dates_lightweight "/tmp/test_invalid_dates.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"Too many invalid dates found in sample"* ]]
}

@test "test __validate_xml_dates_lightweight with mixed valid and invalid dates" {
 # Test lightweight date validation with mixed dates
 # Functions are already loaded via functionsProcess.sh
 
 # Create test XML with mixed valid and invalid dates
 cat > /tmp/test_mixed_dates.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-04-08T08:09:05Z">
  <comment action="opened" timestamp="2023-09-12T13:41:32Z" uid="1" user="test">Valid date</comment>
 </note>
 <note id="2" lat="0.0" lon="0.0" created_at="2023-13-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-32T24:00:00Z" uid="2" user="test">Invalid date</comment>
 </note>
 <note id="3" lat="0.0" lon="0.0" created_at="2023-06-15T14:30:45Z"/>
</osm-notes>
EOF
 
 run __validate_xml_dates_lightweight "/tmp/test_mixed_dates.xml"
 # Should fail because more than 10% of dates are invalid
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"Too many invalid dates found in sample"* ]]
}

@test "test __validate_xml_dates_lightweight with invalid characters" {
 # Test lightweight date validation with invalid characters
 # Functions are already loaded via functionsProcess.sh
 
 # Create test XML with invalid characters in dates
 cat > /tmp/test_invalid_chars.xml << 'EOF'
<?xml version="1.0"?>
<osm-notes>
 <note id="1" lat="0.0" lon="0.0" created_at="2023-aa-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-1bT00:00:00Z" uid="1" user="test">Test comment</comment>
 </note>
 <note id="2" lat="0.0" lon="0.0" created_at="2023-01-01T1c:00:00Z"/>
EOF

 # Add many more notes to make the file larger and avoid lite validation
 for i in {3..100}; do
  # Make some dates invalid to ensure validation fails
  if [[ $((i % 3)) -eq 0 ]]; then
   # Invalid date every 3rd note
   cat >> /tmp/test_invalid_chars.xml << EOF
 <note id="${i}" lat="0.0" lon="0.0" created_at="2023-13-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-32T00:00:00Z" uid="${i}" user="test">Test comment ${i}</comment>
 </note>
EOF
  else
   # Valid date
   cat >> /tmp/test_invalid_chars.xml << EOF
 <note id="${i}" lat="0.0" lon="0.0" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="${i}" user="test">Test comment ${i}</comment>
 </note>
EOF
  fi
 done

 echo '</osm-notes>' >> /tmp/test_invalid_chars.xml
 
 run __validate_xml_dates_lightweight "/tmp/test_invalid_chars.xml"
 [[ "${status}" -eq 1 ]]
 [[ "${output}" == *"Invalid date format found in sample"* ]]
}

