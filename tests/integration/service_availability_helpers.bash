#!/usr/bin/env bash

# Service Availability Helpers
# Check if external services are available before running tests
# Author: Andres Gomez (AngocA)
# Version: 2025-12-27

# =============================================================================
# Service Availability Check Functions
# =============================================================================

# Check OSM API availability
# Usage: __check_osm_api_available [TIMEOUT]
# Returns: 0 if available, 1 otherwise
# Sets: __OSM_API_AVAILABLE=1 if available, 0 otherwise
__check_osm_api_available() {
 local TIMEOUT="${1:-10}"
 
 if ! command -v curl > /dev/null 2>&1; then
  export __OSM_API_AVAILABLE=0
  return 1
 fi
 
 # Test with minimal query (limit=1)
 if timeout "${TIMEOUT}" curl -s --max-time "${TIMEOUT}" \
  -H "User-Agent: OSM-Notes-Ingestion-Test/1.0" \
  "https://api.openstreetmap.org/api/0.6/notes/search.xml?limit=1" > /dev/null 2>&1; then
  export __OSM_API_AVAILABLE=1
  return 0
 else
  export __OSM_API_AVAILABLE=0
  return 1
 fi
}

# Check OSM API version
# Usage: __check_osm_api_version [EXPECTED_VERSION] [TIMEOUT]
# Returns: 0 if version matches, 1 otherwise
# Sets: __OSM_API_VERSION with detected version
__check_osm_api_version() {
 local EXPECTED_VERSION="${1:-0.6}"
 local TIMEOUT="${2:-15}"
 
 if ! command -v curl > /dev/null 2>&1; then
  export __OSM_API_VERSION=""
  return 1
 fi
 
 # Check API versions endpoint
 local TEMP_RESPONSE
 TEMP_RESPONSE=$(mktemp)
 
 if ! timeout "${TIMEOUT}" curl -s --max-time "${TIMEOUT}" \
  "https://api.openstreetmap.org/api/versions" > "${TEMP_RESPONSE}" 2>/dev/null; then
  rm -f "${TEMP_RESPONSE}"
  export __OSM_API_VERSION=""
  return 1
 fi
 
 # Extract version from XML response
 local DETECTED_VERSION
 DETECTED_VERSION=$(grep -oP '<version>\K[0-9.]+' "${TEMP_RESPONSE}" 2>/dev/null | head -n 1 || echo "")
 rm -f "${TEMP_RESPONSE}"
 
 export __OSM_API_VERSION="${DETECTED_VERSION}"
 
 if [[ -z "${DETECTED_VERSION}" ]]; then
  return 1
 fi
 
 if [[ "${DETECTED_VERSION}" == "${EXPECTED_VERSION}" ]]; then
  return 0
 else
  return 1
 fi
}

# Check Overpass API availability
# Usage: __check_overpass_api_available [TIMEOUT]
# Returns: 0 if available, 1 otherwise
# Sets: __OVERPASS_API_AVAILABLE=1 if available, 0 otherwise
__check_overpass_api_available() {
 local TIMEOUT="${1:-15}"
 local OVERPASS_URL="${OVERPASS_INTERPRETER:-https://overpass-api.de/api/interpreter}"
 
 if ! command -v curl > /dev/null 2>&1; then
  export __OVERPASS_API_AVAILABLE=0
  return 1
 fi
 
 # Test with minimal query
 local OVERPASS_TEST_QUERY="[out:json][timeout:5];node(1);out;"
 if timeout "${TIMEOUT}" curl -s --max-time "${TIMEOUT}" -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "data=${OVERPASS_TEST_QUERY}" \
  "${OVERPASS_URL}" > /dev/null 2>&1; then
  export __OVERPASS_API_AVAILABLE=1
  return 0
 else
  export __OVERPASS_API_AVAILABLE=0
  return 1
 fi
}

# Check Overpass API status endpoint
# Usage: __check_overpass_api_status [TIMEOUT]
# Returns: 0 if status endpoint responds, 1 otherwise
# Sets: __OVERPASS_API_STATUS_AVAILABLE=1 if available, 0 otherwise
__check_overpass_api_status() {
 local TIMEOUT="${1:-10}"
 local OVERPASS_STATUS_URL="${OVERPASS_INTERPRETER%/api/interpreter}/status"
 
 if ! command -v curl > /dev/null 2>&1; then
  export __OVERPASS_API_STATUS_AVAILABLE=0
  return 1
 fi
 
 if timeout "${TIMEOUT}" curl -s --max-time "${TIMEOUT}" \
  "${OVERPASS_STATUS_URL}" > /dev/null 2>&1; then
  export __OVERPASS_API_STATUS_AVAILABLE=1
  return 0
 else
  export __OVERPASS_API_STATUS_AVAILABLE=0
  return 1
 fi
}

# Check OSM Planet server availability
# Usage: __check_planet_server_available [TIMEOUT]
# Returns: 0 if available, 1 otherwise
# Sets: __PLANET_SERVER_AVAILABLE=1 if available, 0 otherwise
__check_planet_server_available() {
 local TIMEOUT="${1:-10}"
 local PLANET_URL="${PLANET:-https://planet.openstreetmap.org}"
 
 if ! command -v curl > /dev/null 2>&1; then
  export __PLANET_SERVER_AVAILABLE=0
  return 1
 fi
 
 # Test with HEAD request to notes directory
 if timeout "${TIMEOUT}" curl -s --max-time "${TIMEOUT}" -I \
  "${PLANET_URL}/planet/notes/" > /dev/null 2>&1; then
  export __PLANET_SERVER_AVAILABLE=1
  return 0
 else
  export __PLANET_SERVER_AVAILABLE=0
  return 1
 fi
}

# Check PostgreSQL availability
# Usage: __check_postgresql_available [DBNAME] [TIMEOUT]
# Returns: 0 if available, 1 otherwise
# Sets: __POSTGRESQL_AVAILABLE=1 if available, 0 otherwise
__check_postgresql_available() {
 local DBNAME_TO_CHECK="${1:-${DBNAME:-osm_notes_ingestion_test}}"
 local TIMEOUT="${2:-5}"
 
 if ! command -v psql > /dev/null 2>&1; then
  export __POSTGRESQL_AVAILABLE=0
  return 1
 fi
 
 # Use timeout to prevent hanging
 if timeout "${TIMEOUT}" psql -d "${DBNAME_TO_CHECK}" -c "SELECT 1;" > /dev/null 2>&1; then
  export __POSTGRESQL_AVAILABLE=1
  return 0
 else
  export __POSTGRESQL_AVAILABLE=0
  return 1
 fi
}

# Check network connectivity
# Usage: __check_network_connectivity [TIMEOUT]
# Returns: 0 if network is available, 1 otherwise
# Sets: __NETWORK_AVAILABLE=1 if available, 0 otherwise
__check_network_connectivity() {
 local TIMEOUT="${1:-5}"
 
 if ! command -v curl > /dev/null 2>&1; then
  export __NETWORK_AVAILABLE=0
  return 1
 fi
 
 # Test connectivity to a reliable service (Google DNS)
 # Even if connection fails, curl should return (not hang)
 if timeout "${TIMEOUT}" curl -s --max-time "${TIMEOUT}" \
  "https://8.8.8.8" > /dev/null 2>&1; then
  export __NETWORK_AVAILABLE=1
  return 0
 else
  # Try alternative: check if we can resolve DNS
  if timeout "${TIMEOUT}" curl -s --max-time "${TIMEOUT}" \
   "https://www.google.com" > /dev/null 2>&1; then
   export __NETWORK_AVAILABLE=1
   return 0
  else
   export __NETWORK_AVAILABLE=0
   return 1
  fi
 fi
}

# =============================================================================
# Skip Test Helpers
# =============================================================================

# Skip test if OSM API is not available
# Usage: __skip_if_osm_api_unavailable [MESSAGE]
__skip_if_osm_api_unavailable() {
 local MESSAGE="${1:-OSM API not available}"
 
 if ! __check_osm_api_available; then
  skip "${MESSAGE}"
 fi
}

# Skip test if Overpass API is not available
# Usage: __skip_if_overpass_api_unavailable [MESSAGE]
__skip_if_overpass_api_unavailable() {
 local MESSAGE="${1:-Overpass API not available}"
 
 if ! __check_overpass_api_available; then
  skip "${MESSAGE}"
 fi
}

# Skip test if Planet server is not available
# Usage: __skip_if_planet_server_unavailable [MESSAGE]
__skip_if_planet_server_unavailable() {
 local MESSAGE="${1:-Planet server not available}"
 
 if ! __check_planet_server_available; then
  skip "${MESSAGE}"
 fi
}

# Skip test if PostgreSQL is not available
# Usage: __skip_if_postgresql_unavailable [DBNAME] [MESSAGE]
__skip_if_postgresql_unavailable() {
 local DBNAME_TO_CHECK="${1:-${DBNAME:-osm_notes_ingestion_test}}"
 local MESSAGE="${2:-PostgreSQL database ${DBNAME_TO_CHECK} not available}"
 
 if ! __check_postgresql_available "${DBNAME_TO_CHECK}"; then
  skip "${MESSAGE}"
 fi
}

# Skip test if network is not available
# Usage: __skip_if_network_unavailable [MESSAGE]
__skip_if_network_unavailable() {
 local MESSAGE="${1:-Network connectivity not available}"
 
 if ! __check_network_connectivity; then
  skip "${MESSAGE}"
 fi
}

# Skip test if external services are not required
# Usage: __skip_if_external_services_not_required [MESSAGE] [SERVICE_CHECK_FUNCTION]
# Behavior:
#   - If REQUIRE_EXTERNAL_SERVICES=true: Always run (force execution)
#   - If REQUIRE_EXTERNAL_SERVICES=false or unset: Check service availability automatically
#     - If available: Run test
#     - If unavailable: Skip test
__skip_if_external_services_not_required() {
 local MESSAGE="${1:-External services not required}"
 local SERVICE_CHECK_FUNCTION="${2:-__check_network_connectivity}"
 
 # If explicitly required, always run (don't skip)
 if [[ "${REQUIRE_EXTERNAL_SERVICES:-false}" == "true" ]]; then
  return 0
 fi
 
 # Otherwise, check if service is available
 # If service check function is provided and available, use it
 if declare -f "${SERVICE_CHECK_FUNCTION}" > /dev/null 2>&1; then
  if "${SERVICE_CHECK_FUNCTION}" > /dev/null 2>&1; then
   # Service is available, run the test
   return 0
  else
   # Service is not available, skip the test
   skip "${MESSAGE} (service not available, set REQUIRE_EXTERNAL_SERVICES=true to force)"
   return 1
  fi
 else
  # No check function available, skip by default
  skip "${MESSAGE} (set REQUIRE_EXTERNAL_SERVICES=true to enable)"
  return 1
 fi
}

# =============================================================================
# Combined Availability Checks
# =============================================================================

# Check all external services availability
# Usage: __check_all_external_services
# Returns: 0 if all required services are available, 1 otherwise
# Sets: Individual service flags (__OSM_API_AVAILABLE, etc.)
__check_all_external_services() {
 local ALL_AVAILABLE=1
 
 # Check each service
 __check_osm_api_available || ALL_AVAILABLE=0
 __check_overpass_api_available || ALL_AVAILABLE=0
 __check_planet_server_available || ALL_AVAILABLE=0
 __check_network_connectivity || ALL_AVAILABLE=0
 
 # PostgreSQL is always checked separately (local service)
 
 return "${ALL_AVAILABLE}"
}

# Get service availability summary
# Usage: __get_service_availability_summary
# Output: Summary of all service availability statuses
__get_service_availability_summary() {
 echo "=== Service Availability Summary ==="
 echo ""
 
 # Check each service
 __check_postgresql_available && echo "✅ PostgreSQL: Available" || echo "❌ PostgreSQL: Not available"
 __check_osm_api_available && echo "✅ OSM API: Available" || echo "❌ OSM API: Not available"
 __check_overpass_api_available && echo "✅ Overpass API: Available" || echo "❌ Overpass API: Not available"
 __check_planet_server_available && echo "✅ Planet Server: Available" || echo "❌ Planet Server: Not available"
 __check_network_connectivity && echo "✅ Network: Available" || echo "❌ Network: Not available"
 
 # Show OSM API version if available
 if __check_osm_api_version; then
  echo "✅ OSM API Version: ${__OSM_API_VERSION}"
 else
  echo "❌ OSM API Version: Cannot determine"
 fi
 
 echo ""
}

