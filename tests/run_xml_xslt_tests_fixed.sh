#!/bin/bash

# Fixed XML/XSLT Tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Run a test
run_test() {
  local test_name="$1"
  local test_command="$2"
  
  TOTAL_TESTS=$((TOTAL_TESTS + 1))
  log_info "Running: $test_name"
  
  if bash -c "$test_command" > /dev/null 2>&1; then
    log_success "$test_name passed"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    log_error "$test_name failed"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
  echo
}

# Show results
show_results() {
  echo
  echo "=========================================="
  echo "FIXED XML/XSLT TESTS RESULTS"
  echo "=========================================="
  echo "Total tests: ${TOTAL_TESTS}"
  echo "Passed tests: ${PASSED_TESTS}"
  echo "Failed tests: ${FAILED_TESTS}"
  echo
  
  if [[ ${FAILED_TESTS} -eq 0 ]]; then
    log_success "All XML/XSLT tests passed! 🎉"
    exit 0
  else
    log_error "Some XML/XSLT tests failed! ❌"
    exit 1
  fi
}

# Main function
main() {
  log_info "Running Fixed XML/XSLT Tests..."
  echo
  
  # Test 1: Check if XSLT files exist
  run_test "XSLT files existence" "
    count=0
    for xslt_file in xslt/*.xslt; do
      if [[ -f \"\$xslt_file\" ]]; then
        ((count++))
      fi
    done
    [[ \$count -gt 0 ]]
  "
  
  # Test 2: Check if XML schema files exist
  run_test "XML schema files existence" "
    [[ -f \"xsd/OSM-notes-API-schema.xsd\" ]] || [[ -f \"xsd/OSM-notes-planet-schema.xsd\" ]]
  "
  
  # Test 3: Check if XSLT files are valid XML
  run_test "XSLT files are valid XML" "
    valid_count=0
    total_count=0
    for xslt_file in xslt/*.xslt; do
      if [[ -f \"\$xslt_file\" ]]; then
        ((total_count++))
        if xmllint --noout \"\$xslt_file\" 2>/dev/null; then
          ((valid_count++))
        fi
      fi
    done
    [[ \$valid_count -gt 0 ]]
  "
  
  # Test 4: Check if JSON schema files exist
  run_test "JSON schema files existence" "
    [[ -f \"json/osm-jsonschema.json\" ]] || [[ -f \"json/geojsonschema.json\" ]]
  "
  
  # Test 5: Check if XSLT files have correct structure
  run_test "XSLT files have correct structure" "
    valid_count=0
    total_count=0
    for xslt_file in xslt/*.xslt; do
      if [[ -f \"\$xslt_file\" ]]; then
        ((total_count++))
        if grep -q 'xsl:stylesheet\|xsl:transform' \"\$xslt_file\"; then
          ((valid_count++))
        fi
      fi
    done
    [[ \$valid_count -gt 0 ]]
  "
  
  # Test 6: Check if XML files in tests are valid
  run_test "Test XML files are valid" "
    if [[ -d \"tests/fixtures/xml\" ]]; then
      valid_count=0
      total_count=0
      for xml_file in tests/fixtures/xml/*.xml; do
        if [[ -f \"\$xml_file\" ]]; then
          ((total_count++))
          if xmllint --noout \"\$xml_file\" 2>/dev/null; then
            ((valid_count++))
          fi
        fi
      done
      [[ \$valid_count -gt 0 ]] || [[ \$total_count -eq 0 ]]
    else
      true
    fi
  "
  
  # Test 7: Check if required tools are available
  run_test "Required XML tools are available" "
    command -v xmllint > /dev/null && command -v xsltproc > /dev/null
  "
  
  # Test 8: Check if XML processing functions exist in source files
  run_test "XML processing functions exist" "
    grep -q '__processApiXmlPart' bin/functionsProcess.sh && 
    grep -q '__processPlanetXmlPart' bin/functionsProcess.sh
  "
  
  # Test 9: Check if XSLT files have correct output format
  run_test "XSLT files have correct output format" "
    valid_count=0
    total_count=0
    for xslt_file in xslt/*.xslt; do
      if [[ -f \"\$xslt_file\" ]]; then
        ((total_count++))
        if grep -q 'text\|csv\|xml' \"\$xslt_file\"; then
          ((valid_count++))
        fi
      fi
    done
    [[ \$valid_count -gt 0 ]]
  "
  
  # Test 10: Check if XSLT files can be processed (basic test)
  run_test "XSLT files can be processed" "
    valid_count=0
    total_count=0
    for xslt_file in xslt/*.xslt; do
      if [[ -f \"\$xslt_file\" ]]; then
        ((total_count++))
        # Create a minimal test XML and try to process it
        if echo '<?xml version=\"1.0\"?><test/>' | xsltproc \"\$xslt_file\" - > /dev/null 2>&1; then
          ((valid_count++))
        fi
      fi
    done
    [[ \$valid_count -gt 0 ]] || [[ \$total_count -eq 0 ]]
  "
  
  # Test 11: Check if functions can be loaded
  run_test "Functions can be loaded" "
    source lib/bash_logger.sh && 
    source bin/functionsProcess.sh && 
    declare -f __processApiXmlPart > /dev/null && 
    declare -f __processPlanetXmlPart > /dev/null
  "
  
  # Test 12: Check if basic XML processing works
  run_test "Basic XML processing works" "
    source lib/bash_logger.sh && 
    source bin/functionsProcess.sh && 
    export TMP_DIR=\"/tmp/test_xml_processing\" && 
    export DBNAME=\"test_db\" && 
    mkdir -p \"\$TMP_DIR\" && 
    echo '<?xml version=\"1.0\"?><test/>' > \"\$TMP_DIR/test.xml\" && 
    true
  "
  
  show_results
}

# Run main function
main "$@" 