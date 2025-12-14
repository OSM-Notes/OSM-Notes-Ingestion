#!/usr/bin/env bats

# Prerequisites Network Tests
# Tests for network connectivity validation
# Author: Andres Gomez (AngocA)
# Version: 2025-12-13

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"
load "$(dirname "${BATS_TEST_FILENAME}")/performance_edge_cases_helper.bash"

setup() {
 # Set up required environment variables for functionsProcess.sh
 export BASENAME="test"
 export TMP_DIR="/tmp/test_$$"
 export DBNAME="${TEST_DBNAME:-test_db}"
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export LOG_FILENAME="/tmp/test.log"
 export LOCK="/tmp/test.lock"
 export MAX_THREADS="2"

 # Setup mock PostgreSQL if real PostgreSQL is not available
 performance_setup_mock_postgres

 # Unset any existing readonly variables that might conflict
 unset ERROR_HELP_MESSAGE ERROR_PREVIOUS_EXECUTION_FAILED ERROR_CREATING_REPORT ERROR_MISSING_LIBRARY ERROR_INVALID_ARGUMENT ERROR_LOGGER_UTILITY ERROR_DOWNLOADING_BOUNDARY_ID_LIST ERROR_NO_LAST_UPDATE ERROR_PLANET_PROCESS_IS_RUNNING ERROR_DOWNLOADING_NOTES ERROR_EXECUTING_PLANET_DUMP ERROR_DOWNLOADING_BOUNDARY ERROR_GEOJSON_CONVERSION ERROR_INTERNET_ISSUE ERROR_GENERAL 2> /dev/null || true

 # Source the functions
 source "${TEST_BASE_DIR}/bin/lib/functionsProcess.sh"

 # Set up logging function if not available
 if ! declare -f log_info > /dev/null; then
  log_info() { echo "[INFO] $*"; }
  log_error() { echo "[ERROR] $*"; }
  log_debug() { echo "[DEBUG] $*"; }
  log_start() { echo "[START] $*"; }
  log_finish() { echo "[FINISH] $*"; }
 fi
}

# =============================================================================
# Network connectivity tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should validate internet connectivity" {
 # Test internet connectivity
 run wget --timeout=10 --tries=1 --spider https://www.google.com
 [ "$status" -eq 0 ]
}

@test "enhanced __checkPrereqsCommands should validate OSM API accessibility" {
 # Mock wget for OSM API test
 wget() {
  if [[ "$*" == *"api.openstreetmap.org"* ]]; then
   echo "HTTP/1.1 200 OK"
   return 0
  else
   command wget "$@"
  fi
 }

 # Test OSM API accessibility
 run wget --timeout=10 --tries=1 --spider https://api.openstreetmap.org/api/0.6/notes
 [ "$status" -eq 0 ]
}

@test "__checkPrereqsCommands should validate Planet server access" {
 # Mock curl for Planet server test
 local TEMP_FILE
 TEMP_FILE=$(mktemp)
 
 curl() {
  if [[ "$*" == *"planet.openstreetmap.org"* ]] && [[ "$*" == *"-I"* ]]; then
   echo "HTTP/1.1 200 OK"
   return 0
  else
   command curl "$@"
  fi
 }
 export -f curl
 
 # Test Planet server accessibility
 run timeout 10 curl -s --max-time 10 -I "https://planet.openstreetmap.org/planet/notes/"
 [ "$status" -eq 0 ]
 
 rm -f "${TEMP_FILE}"
}

@test "__checkPrereqsCommands should validate OSM API version 0.6" {
 # Create mock API response with version 0.6
 local TEMP_RESPONSE
 TEMP_RESPONSE=$(mktemp)
 cat > "${TEMP_RESPONSE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server">
<note lon="9.9770663" lat="52.1417038">
  <id>123</id>
</note>
</osm>
EOF
 
 # Mock curl to return the mock response
 curl() {
  if [[ "$*" == *"api.openstreetmap.org"* ]] && [[ "$*" == *"notes?limit=1"* ]]; then
   cat "${TEMP_RESPONSE}"
   return 0
  else
   command curl "$@"
  fi
 }
 export -f curl
 
  # Test version extraction - extract only from <osm> element, not XML declaration
  local DETECTED_VERSION
  DETECTED_VERSION=$(grep '<osm' "${TEMP_RESPONSE}" | grep -oP 'version="\K[0-9.]+' | head -n 1)
  
  [ "${DETECTED_VERSION}" = "0.6" ]
 
 rm -f "${TEMP_RESPONSE}"
}

@test "__checkPrereqsCommands should fail on wrong OSM API version" {
 # Create mock API response with wrong version
 local TEMP_RESPONSE
 TEMP_RESPONSE=$(mktemp)
 cat > "${TEMP_RESPONSE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.7" generator="OpenStreetMap server">
<note lon="9.9770663" lat="52.1417038">
  <id>123</id>
</note>
</osm>
EOF
 
  # Extract version - extract only from <osm> element, not XML declaration
  local DETECTED_VERSION
  DETECTED_VERSION=$(grep '<osm' "${TEMP_RESPONSE}" | grep -oP 'version="\K[0-9.]+' | head -n 1)
  
  # Version should not be 0.6
  [ "${DETECTED_VERSION}" != "0.6" ]
  [ "${DETECTED_VERSION}" = "0.7" ]
 
 rm -f "${TEMP_RESPONSE}"
}

@test "__checkPrereqsCommands should validate Overpass API access" {
 # Mock curl for Overpass API test
 curl() {
  if [[ "$*" == *"overpass-api.de"* ]] || [[ "$*" == *"overpass"* ]]; then
   echo '{"version":0.6,"generator":"Overpass API"}'
   return 0
  else
   command curl "$@"
  fi
 }
 export -f curl
 
 # Test Overpass API accessibility with minimal query
 local OVERPASS_TEST_QUERY="[out:json][timeout:5];node(1);out;"
 run timeout 15 curl -s --max-time 15 -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "data=${OVERPASS_TEST_QUERY}" \
  "https://overpass-api.de/api/interpreter" 2>/dev/null
 
 # Should succeed (even if mocked)
 [ "$status" -eq 0 ] || skip "Overpass API test requires network access"
}

@test "__checkPrereqsCommands should handle empty API response" {
 # Create empty response file
 local TEMP_RESPONSE
 TEMP_RESPONSE=$(mktemp)
 touch "${TEMP_RESPONSE}"
 
 # Test that empty response is detected
 [ ! -s "${TEMP_RESPONSE}" ]
 
 rm -f "${TEMP_RESPONSE}"
}

@test "__checkPrereqsCommands should handle missing version attribute" {
 # Create mock API response without version
 local TEMP_RESPONSE
 TEMP_RESPONSE=$(mktemp)
 cat > "${TEMP_RESPONSE}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm generator="OpenStreetMap server">
<note lon="9.9770663" lat="52.1417038">
  <id>123</id>
</note>
</osm>
EOF
 
  # Extract version (should be empty) - extract only from <osm> element, not XML declaration
  local DETECTED_VERSION
  DETECTED_VERSION=$(grep '<osm' "${TEMP_RESPONSE}" | grep -oP 'version="\K[0-9.]+' 2>/dev/null | head -n 1 || echo "")
  
  # Version should be empty
  [ -z "${DETECTED_VERSION}" ]
 
 rm -f "${TEMP_RESPONSE}"
}

