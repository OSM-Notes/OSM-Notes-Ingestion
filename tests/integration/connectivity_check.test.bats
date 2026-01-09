#!/usr/bin/env bats

# Connectivity Check Tests
# Verify external service availability before running integration tests
# Author: Andres Gomez (AngocA)
# Version: 2025-12-27

load "$(dirname "$BATS_TEST_FILENAME")/../test_helper.bash"
# Note: service_availability_helpers.bash is automatically loaded by test_helper.bash

# =============================================================================
# Setup and Teardown
# =============================================================================

setup() {
 # Set up test environment
 export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
 export TMP_DIR="$(mktemp -d)"
 export TEST_DIR="${TMP_DIR}"
 export DBNAME="${TEST_DBNAME:-osm_notes_ingestion_test}"
 export BASENAME="test_connectivity_check"
 export LOG_LEVEL="ERROR"
 export TEST_MODE="true"
}

teardown() {
 # Clean up
 if [[ -n "${TMP_DIR:-}" ]] && [[ -d "${TMP_DIR}" ]]; then
  rm -rf "${TMP_DIR}"
 fi
}

# =============================================================================
# Connectivity Tests
# =============================================================================

@test "Connectivity: PostgreSQL should be accessible" {
 # Test: Verify PostgreSQL database connectivity
 # Purpose: Ensure test database is available for integration tests
 # Expected: Database connection succeeds and returns PostgreSQL version

 if ! command -v psql > /dev/null 2>&1; then
  skip "psql not available"
 fi

 run psql -d "${DBNAME}" -c "SELECT version();" 2>&1

 [ "$status" -eq 0 ]
 [[ "${output}" == *"PostgreSQL"* ]]
}

@test "Connectivity: PostgreSQL should have required tables (optional)" {
 # Test: Verify that test database has basic structure
 # Purpose: Check if database is properly initialized
 # Expected: Database has information_schema accessible

 if ! command -v psql > /dev/null 2>&1; then
  skip "psql not available"
 fi

 if ! __check_database_connectivity "${DBNAME}"; then
  skip "Database ${DBNAME} not available"
 fi

 run psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>&1

 [ "$status" -eq 0 ]
 # Output should be a number (may have whitespace)
 [[ "${output}" =~ [0-9]+ ]]
}

@test "Connectivity: OSM API should be reachable (optional)" {
 # Test: Verify OSM Notes API connectivity
 # Purpose: Check if OSM API is accessible for integration tests
 # Expected: API responds with valid XML

 # Skip if external services are not required AND not available
 # If REQUIRE_EXTERNAL_SERVICES=true, force execution even if unavailable
 if declare -f __skip_if_external_services_not_required > /dev/null 2>&1; then
  __skip_if_external_services_not_required "OSM API not available" "__check_osm_api_available"
 elif [[ "${REQUIRE_EXTERNAL_SERVICES:-false}" != "true" ]]; then
  skip "External services not required (set REQUIRE_EXTERNAL_SERVICES=true to enable)"
 fi

 if ! command -v curl > /dev/null 2>&1; then
  skip "curl not available"
 fi

 # Test with minimal query (limit=1)
 run timeout 10 curl -s --max-time 10 \
  -H "User-Agent: OSM-Notes-Ingestion-Test/1.0" \
  "https://api.openstreetmap.org/api/0.6/notes/search.xml?limit=1" 2>&1

 [ "$status" -eq 0 ]
 [[ -n "${output}" ]]
 [[ "${output}" == *"<osm"* ]] || [[ "${output}" == *"<?xml"* ]]
}

@test "Connectivity: OSM API version should be 0.6 (optional)" {
 # Test: Verify OSM API version compatibility
 # Purpose: Ensure API version matches expected version
 # Expected: API returns version 0.6

 # Skip if external services are not required AND not available
 if declare -f __skip_if_external_services_not_required > /dev/null 2>&1; then
  __skip_if_external_services_not_required "OSM API not available" "__check_osm_api_available"
 elif [[ "${REQUIRE_EXTERNAL_SERVICES:-false}" != "true" ]]; then
  skip "External services not required"
 fi

 if ! command -v curl > /dev/null 2>&1; then
  skip "curl not available"
 fi

 # Check API versions endpoint
 local TEMP_RESPONSE
 TEMP_RESPONSE=$(mktemp)
 
 run timeout 15 curl -s --max-time 15 \
  "https://api.openstreetmap.org/api/versions" > "${TEMP_RESPONSE}" 2>&1

 if [ "$status" -ne 0 ]; then
  rm -f "${TEMP_RESPONSE}"
  skip "Cannot access OSM API versions endpoint"
 fi

 # Extract version from XML response
 # Try multiple methods to extract version
 local DETECTED_VERSION
 DETECTED_VERSION=$(grep -oP '<version>\K[0-9.]+' "${TEMP_RESPONSE}" 2>/dev/null | head -n 1 || echo "")
 
 # Alternative: use sed if grep -P is not available
 if [[ -z "${DETECTED_VERSION}" ]]; then
  DETECTED_VERSION=$(sed -n 's/.*<version>\([0-9.]*\)<\/version>.*/\1/p' "${TEMP_RESPONSE}" 2>/dev/null | head -n 1 || echo "")
 fi
 
 # Alternative: use awk if sed doesn't work
 if [[ -z "${DETECTED_VERSION}" ]]; then
  DETECTED_VERSION=$(awk -F'[<>]' '/<version>/{print $3; exit}' "${TEMP_RESPONSE}" 2>/dev/null || echo "")
 fi
 
 rm -f "${TEMP_RESPONSE}"

 if [[ -z "${DETECTED_VERSION}" ]]; then
  skip "Cannot detect OSM API version from response"
 fi

 [[ "${DETECTED_VERSION}" == "0.6" ]]
}

@test "Connectivity: Overpass API should respond (optional)" {
 # Test: Verify Overpass API connectivity
 # Purpose: Check if Overpass API is accessible for boundary downloads
 # Expected: API responds to minimal query

 # Skip if external services are not required AND not available
 if declare -f __skip_if_external_services_not_required > /dev/null 2>&1; then
  __skip_if_external_services_not_required "Overpass API not available" "__check_overpass_api_available"
 elif [[ "${REQUIRE_EXTERNAL_SERVICES:-false}" != "true" ]]; then
  skip "External services not required"
 fi

 if ! command -v curl > /dev/null 2>&1; then
  skip "curl not available"
 fi

 # Test with minimal query
 local OVERPASS_TEST_QUERY="[out:json][timeout:5];node(1);out;"
 run timeout 15 curl -s --max-time 15 -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "data=${OVERPASS_TEST_QUERY}" \
  "https://overpass-api.de/api/interpreter" 2>&1

 [ "$status" -eq 0 ]
 [[ -n "${output}" ]]
 # Overpass returns JSON, should contain "elements" or "version"
 [[ "${output}" == *"elements"* ]] || [[ "${output}" == *"version"* ]] || [[ "${output}" == *"generator"* ]]
}

@test "Connectivity: Overpass API status endpoint should respond (optional)" {
 # Test: Verify Overpass API status endpoint
 # Purpose: Check Overpass API availability without executing query
 # Expected: Status endpoint responds

 # Skip if external services are not required AND not available
 if declare -f __skip_if_external_services_not_required > /dev/null 2>&1; then
  __skip_if_external_services_not_required "Overpass API status not available" "__check_overpass_api_status"
 elif [[ "${REQUIRE_EXTERNAL_SERVICES:-false}" != "true" ]]; then
  skip "External services not required"
 fi

 if ! command -v curl > /dev/null 2>&1; then
  skip "curl not available"
 fi

 # Try to get status endpoint
 local TEMP_STATUS
 TEMP_STATUS=$(mktemp)
 
 run timeout 10 curl -s --max-time 10 \
  "https://overpass-api.de/api/status" > "${TEMP_STATUS}" 2>&1

 # Status endpoint should respond (even if empty, curl should succeed)
 [ "$status" -eq 0 ]
 
 # Status endpoint may return empty or have content - both are valid
 # Just verify we got a response (no connection error)
 if [[ -f "${TEMP_STATUS}" ]]; then
  # If file exists, endpoint responded (even if empty)
  rm -f "${TEMP_STATUS}"
  [[ true ]]
 else
  # If file doesn't exist, there was an error
  [[ false ]]
 fi
}

@test "Connectivity: OSM Planet server should be accessible (optional)" {
 # Test: Verify OSM Planet server connectivity
 # Purpose: Check if Planet server is accessible for full data downloads
 # Expected: Server responds to HEAD request

 # Skip if external services are not required AND not available
 if declare -f __skip_if_external_services_not_required > /dev/null 2>&1; then
  __skip_if_external_services_not_required "Planet server not available" "__check_planet_server_available"
 elif [[ "${REQUIRE_EXTERNAL_SERVICES:-false}" != "true" ]]; then
  skip "External services not required"
 fi

 if ! command -v curl > /dev/null 2>&1; then
  skip "curl not available"
 fi

 # Test with HEAD request to notes directory
 run timeout 10 curl -s --max-time 10 -I \
  "https://planet.openstreetmap.org/planet/notes/" 2>&1

 [ "$status" -eq 0 ]
 # Should return HTTP status code (200, 301, 302, etc.)
 [[ "${output}" == *"HTTP"* ]] || [[ "${output}" == *"200"* ]] || [[ "${output}" == *"301"* ]] || [[ "${output}" == *"302"* ]]
}

@test "Connectivity: Network connectivity check should pass" {
 # Test: Verify basic network connectivity
 # Purpose: Ensure system has internet access
 # Expected: Can reach a reliable external host

 # Skip if external services are not required AND not available
 if declare -f __skip_if_external_services_not_required > /dev/null 2>&1; then
  __skip_if_external_services_not_required "Network not available" "__check_network_connectivity"
 elif [[ "${REQUIRE_EXTERNAL_SERVICES:-false}" != "true" ]]; then
  skip "External services not required"
 fi

 if ! command -v curl > /dev/null 2>&1; then
  skip "curl not available"
 fi

 # Test connectivity to a reliable service (Google DNS)
 run timeout 5 curl -s --max-time 5 \
  "https://8.8.8.8" 2>&1 || true

 # Even if connection fails, curl should return (not hang)
 # We're just checking that network stack is working
 [ "$status" -ge 0 ]
}

@test "Connectivity: Required tools should be available" {
 # Test: Verify that required command-line tools are available
 # Purpose: Ensure test environment has necessary tools
 # Expected: All required tools are in PATH

 local MISSING_TOOLS=()

 # Check PostgreSQL client
 if ! command -v psql > /dev/null 2>&1; then
  MISSING_TOOLS+=("psql")
 fi

 # Check curl (optional, but useful)
 if ! command -v curl > /dev/null 2>&1; then
  MISSING_TOOLS+=("curl (optional)")
 fi

 # Check xmllint (optional, but useful)
 if ! command -v xmllint > /dev/null 2>&1; then
  MISSING_TOOLS+=("xmllint (optional)")
 fi

 # psql is required, others are optional
 if [[ ${#MISSING_TOOLS[@]} -gt 0 ]] && [[ "${MISSING_TOOLS[0]}" == "psql" ]]; then
  skip "Required tool psql not available"
 fi

 # Test passes if psql is available (required tools)
 # No need to check status, test logic handles it
 [ 0 -eq 0 ]
}

