#!/bin/bash
# GeoServer Configuration Script for OSM-Notes-profile
# Automates GeoServer setup for WMS layers
#
# Author: Andres Gomez (AngocA)
# Version: 2025-11-30

set -euo pipefail

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Set required variables for functionsProcess.sh
# SCRIPT_BASE_DIRECTORY must be set BEFORE loading functionsProcess.sh
# so it can find commonFunctions.sh correctly
export SCRIPT_BASE_DIRECTORY="${PROJECT_ROOT}"
export BASENAME="geoserverConfig"
export TMP_DIR="/tmp"
export LOG_LEVEL="INFO"

# Load properties
if [[ -f "${PROJECT_ROOT}/etc/properties.sh" ]]; then
 source "${PROJECT_ROOT}/etc/properties.sh"
fi

# Load WMS specific properties
if [[ -f "${PROJECT_ROOT}/etc/wms.properties.sh" ]]; then
 source "${PROJECT_ROOT}/etc/wms.properties.sh"
fi

# Load common functions (provides __validate_input_file, etc.)
# Note: We don't use __retry_geoserver_api from functionsProcess.sh, we implement
# our own retry logic directly with curl for better control
if [[ -f "${PROJECT_ROOT}/bin/lib/functionsProcess.sh" ]]; then
 source "${PROJECT_ROOT}/bin/lib/functionsProcess.sh"
fi

# Use WMS properties for configuration
# Database connection for GeoServer (from WMS properties or main properties)
# Priority: GEOSERVER_DBUSER > WMS_DBUSER > defaults
# Note: GeoServer should use the 'geoserver' user with read-only permissions
#       This user is used to configure GeoServer datastores and verify data access
#       GeoServer CANNOT use peer authentication, so host/port must be set
# Default DBNAME is 'notes' to match production, but can be overridden via WMS_DBNAME
DBNAME="${WMS_DBNAME:-${DBNAME:-notes}}"
# Use GEOSERVER_DBUSER if set, otherwise WMS_DBUSER, otherwise default to geoserver
DBUSER="${GEOSERVER_DBUSER:-${WMS_DBUSER:-geoserver}}"
DBPASSWORD="${WMS_DBPASSWORD:-${DB_PASSWORD:-}}"
# GeoServer cannot use peer authentication, so default to localhost:5432 if not set
DBHOST="${WMS_DBHOST:-${DB_HOST:-localhost}}"
DBPORT="${WMS_DBPORT:-${DB_PORT:-5432}}"

# GeoServer configuration (from wms.properties.sh)
# Priority: Environment variables > wms.properties.sh > defaults
# Allow override via environment variables or command line
# Note: These are loaded from wms.properties.sh above, but we set defaults here
#       if they weren't set in the properties file
GEOSERVER_URL="${GEOSERVER_URL:-http://localhost:8080/geoserver}"
GEOSERVER_USER="${GEOSERVER_USER:-admin}"
GEOSERVER_PASSWORD="${GEOSERVER_PASSWORD:-geoserver}"
GEOSERVER_WORKSPACE="${GEOSERVER_WORKSPACE:-osm_notes}"
# Namespace URI should be a unique identifier (URN format recommended)
# This is used as a unique identifier for the workspace, not a web URL
GEOSERVER_NAMESPACE="${GEOSERVER_NAMESPACE:-urn:osm-notes-profile}"
GEOSERVER_STORE="${GEOSERVER_STORE:-notes_wms}"
GEOSERVER_LAYER="${GEOSERVER_LAYER:-notes_wms_layer}"

# Debug: Show loaded credentials (for troubleshooting, only in verbose mode)
if [[ "${VERBOSE:-false}" == "true" ]]; then
 print_status "${BLUE}" "🔐 GeoServer credentials loaded:"
 print_status "${BLUE}" "   URL: ${GEOSERVER_URL}"
 print_status "${BLUE}" "   User: ${GEOSERVER_USER}"
 print_status "${BLUE}" "   Password: ${GEOSERVER_PASSWORD:+*** (${#GEOSERVER_PASSWORD} chars)}"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
 local COLOR=$1
 local MESSAGE=$2
 echo -e "${COLOR}${MESSAGE}${NC}"
}

# Function to show help
show_help() {
 cat << EOF
GeoServer Configuration Script for OSM-Notes-profile

Usage: $0 [COMMAND] [OPTIONS]

COMMANDS:
  install     Install and configure GeoServer for OSM notes WMS
  status      Check GeoServer configuration status
  remove      Remove GeoServer configuration
  help        Show this help message

OPTIONS:
  --force     Force configuration even if already configured
  --dry-run   Show what would be done without executing
  --verbose   Show detailed output
  --geoserver-home DIR    GeoServer installation directory
  --geoserver-url URL     GeoServer REST API URL
  --geoserver-user USER   GeoServer admin username
  --geoserver-pass PASS   GeoServer admin password

EXAMPLES:
  $0 install                    # Install and configure GeoServer
  $0 status                     # Check configuration status
  $0 remove                     # Remove configuration
  $0 install --dry-run          # Show what would be configured

ENVIRONMENT VARIABLES:
  GEOSERVER_HOME      GeoServer installation directory
  GEOSERVER_DATA_DIR  GeoServer data directory
  GEOSERVER_URL       GeoServer REST API URL
  GEOSERVER_USER      GeoServer admin username
  GEOSERVER_PASSWORD  GeoServer admin password
  DBNAME              Database name (default: osm_notes)
  DBUSER              Database user (default: postgres)
  DBPASSWORD          Database password
  DBHOST              Database host (default: localhost)
  DBPORT              Database port (default: 5432)

EOF
}

# Function to validate prerequisites
validate_prerequisites() {
 print_status "${BLUE}" "🔍 Validating prerequisites..."

 # Check if curl is available
 if ! command -v curl &> /dev/null; then
  print_status "${RED}" "❌ ERROR: curl is not installed"
  exit 1
 fi

 # Check if jq is available
 if ! command -v jq &> /dev/null; then
  print_status "${RED}" "❌ ERROR: jq is not installed"
  exit 1
 fi

 # Check if GeoServer is accessible
 # Try to connect to GeoServer with retry logic and verify HTTP status code
 local GEOSERVER_STATUS_URL="${GEOSERVER_URL}/rest/about/status"
 local TEMP_STATUS_FILE="${TMP_DIR}/geoserver_status_$$.tmp"
 local TEMP_ERROR_FILE="${TMP_DIR}/geoserver_error_$$.tmp"
 local MAX_RETRIES=3
 local RETRY_COUNT=0
 local CONNECTED=false
 local HTTP_CODE

 while [[ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]]; do
  HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_STATUS_FILE}" \
   --connect-timeout 10 --max-time 30 \
   -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
   "${GEOSERVER_STATUS_URL}" 2> "${TEMP_ERROR_FILE}")
  
  if [[ "${HTTP_CODE}" == "200" ]]; then
   if [[ -f "${TEMP_STATUS_FILE}" ]] && [[ -s "${TEMP_STATUS_FILE}" ]]; then
    CONNECTED=true
    break
   fi
  elif [[ "${HTTP_CODE}" == "401" ]]; then
   # Authentication failed - don't retry, show error immediately
   local ERROR_MSG
   ERROR_MSG=$(cat "${TEMP_ERROR_FILE}" 2> /dev/null || echo "Authentication failed")
   rm -f "${TEMP_STATUS_FILE}" "${TEMP_ERROR_FILE}" 2> /dev/null || true
   print_status "${RED}" "❌ ERROR: Authentication failed (HTTP 401)"
   print_status "${YELLOW}" "   Invalid credentials for GeoServer at ${GEOSERVER_URL}"
   print_status "${YELLOW}" "   User: ${GEOSERVER_USER}"
   print_status "${YELLOW}" "   💡 Check credentials in etc/wms.properties.sh:"
   print_status "${YELLOW}" "      GEOSERVER_USER=\"${GEOSERVER_USER}\""
   print_status "${YELLOW}" "      GEOSERVER_PASSWORD=\"your_password\""
   print_status "${YELLOW}" "   💡 Or set environment variables:"
   print_status "${YELLOW}" "      export GEOSERVER_USER=admin"
   print_status "${YELLOW}" "      export GEOSERVER_PASSWORD=your_password"
   exit 1
  elif [[ "${HTTP_CODE}" == "404" ]]; then
   # GeoServer URL might be wrong
   print_status "${YELLOW}" "⚠️  GeoServer endpoint not found (HTTP 404) - checking URL..."
  fi
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [[ ${RETRY_COUNT} -lt ${MAX_RETRIES} ]]; then
   sleep 2
  fi
 done

 rm -f "${TEMP_STATUS_FILE}" "${TEMP_ERROR_FILE}" 2> /dev/null || true

 if [[ "${CONNECTED}" != "true" ]]; then
  print_status "${RED}" "❌ ERROR: Cannot connect to GeoServer at ${GEOSERVER_URL}"
  if [[ -n "${HTTP_CODE}" ]]; then
   print_status "${RED}" "   HTTP Status Code: ${HTTP_CODE}"
   if [[ "${HTTP_CODE}" == "000" ]]; then
    print_status "${YELLOW}" "   Connection failed - GeoServer may not be running or URL is incorrect"
    if [[ -f "${TEMP_ERROR_FILE}" ]]; then
     local CURL_ERROR
     CURL_ERROR=$(cat "${TEMP_ERROR_FILE}" 2> /dev/null || echo "")
     if [[ -n "${CURL_ERROR}" ]]; then
      print_status "${YELLOW}" "   Error details: ${CURL_ERROR}"
     fi
    fi
   fi
  fi
  print_status "${YELLOW}" "💡 Make sure GeoServer is running and credentials are correct"
  print_status "${YELLOW}" "💡 You can override the URL with: export GEOSERVER_URL=https://geoserver.osm.lat/geoserver"
  print_status "${YELLOW}" "💡 Or set it in etc/wms.properties.sh: GEOSERVER_URL=\"https://geoserver.osm.lat/geoserver\""
  print_status "${YELLOW}" "💡 To find GeoServer port, try: netstat -tlnp | grep java | grep LISTEN"
  exit 1
 fi

 # Check if PostgreSQL is accessible
 local PSQL_CMD="psql -d \"${DBNAME}\""
 if [[ -n "${DBHOST}" ]]; then
  PSQL_CMD="psql -h \"${DBHOST}\" -d \"${DBNAME}\""
 fi
 if [[ -n "${DBUSER}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U \"${DBUSER}\""
 fi
 if [[ -n "${DBPORT}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p \"${DBPORT}\""
 fi
 if [[ -n "${DBPASSWORD}" ]]; then
  export PGPASSWORD="${DBPASSWORD}"
 else
  unset PGPASSWORD 2> /dev/null || true
 fi

 # Test connection and capture error message
 # Note: This validation is optional - GeoServer will validate the connection when creating the datastore
 # If password is not provided, skip validation (GeoServer may have different credentials)
 if [[ -n "${DBPASSWORD}" ]]; then
  # Ensure PGPASSWORD is set and exported for psql
  export PGPASSWORD="${DBPASSWORD}"
  local TEMP_ERROR_FILE="${TMP_DIR}/psql_error_$$.tmp"
  # Use PGPASSWORD environment variable to avoid interactive password prompt
  if ! eval "${PSQL_CMD} -c \"SELECT 1;\" > /dev/null 2> \"${TEMP_ERROR_FILE}\""; then
   local ERROR_MSG
   ERROR_MSG=$(cat "${TEMP_ERROR_FILE}" 2> /dev/null | head -1 || echo "Unknown error")
   rm -f "${TEMP_ERROR_FILE}" 2> /dev/null || true
   unset PGPASSWORD 2> /dev/null || true
   
   print_status "${YELLOW}" "⚠️  WARNING: Cannot validate PostgreSQL connection to '${DBNAME}'"
   print_status "${YELLOW}" "   Error: ${ERROR_MSG}"
   print_status "${YELLOW}" "   This is not fatal - GeoServer will validate the connection when creating the datastore"
   if [[ -n "${DBHOST}" ]]; then
    print_status "${YELLOW}" "   Host: ${DBHOST}"
   fi
   if [[ -n "${DBPORT}" ]]; then
    print_status "${YELLOW}" "   Port: ${DBPORT}"
   fi
   if [[ -n "${DBUSER}" ]]; then
    print_status "${YELLOW}" "   User: ${DBUSER}"
   fi
  else
   print_status "${GREEN}" "✅ PostgreSQL connection validated"
   unset PGPASSWORD 2> /dev/null || true
  fi
 else
  print_status "${YELLOW}" "⚠️  Skipping PostgreSQL validation (no password provided)"
  print_status "${YELLOW}" "   GeoServer will validate the connection when creating the datastore"
  print_status "${YELLOW}" "   💡 To enable validation, set WMS_DBPASSWORD or DBPASSWORD environment variable"
 fi

 # Check if WMS schema exists (only if we can connect to PostgreSQL)
 if [[ -n "${DBPASSWORD}" ]]; then
  # Ensure PGPASSWORD is set for the schema check
  export PGPASSWORD="${DBPASSWORD}"
  if ! eval "${PSQL_CMD} -c \"SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'wms');\"" 2> /dev/null | grep -q 't'; then
   unset PGPASSWORD 2> /dev/null || true
   print_status "${RED}" "❌ ERROR: WMS schema not found. Please install WMS components first:"
   print_status "${YELLOW}" "   bin/wms/wmsManager.sh install"
   exit 1
  fi
  unset PGPASSWORD 2> /dev/null || true
 else
  print_status "${YELLOW}" "⚠️  Skipping WMS schema validation (no password provided)"
  print_status "${YELLOW}" "   Make sure WMS components are installed: bin/wms/wmsManager.sh install"
 fi

 print_status "${GREEN}" "✅ Prerequisites validated"
}

# Function to check if GeoServer is configured
# Returns 0 if configured (workspace and datastore exist), 1 otherwise
is_geoserver_configured() {
 local WORKSPACE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}"
 local DATASTORE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}"
 local TEMP_FILE="${TMP_DIR}/geoserver_check_$$.tmp"
 local HTTP_CODE
 local WORKSPACE_EXISTS=false
 local DATASTORE_EXISTS=false
 
 # Check if workspace exists (verify HTTP status code is 200)
 HTTP_CODE=$(curl -s -o "${TEMP_FILE}" -w "%{http_code}" --connect-timeout 10 --max-time 30 \
  -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  "${WORKSPACE_URL}" 2> /dev/null)
 
 if [[ "${HTTP_CODE}" == "200" ]]; then
  # Check if response contains workspace name (verify it's not empty or error)
  if [[ -s "${TEMP_FILE}" ]] && grep -q "\"name\".*\"${GEOSERVER_WORKSPACE}\"" "${TEMP_FILE}" 2> /dev/null; then
   WORKSPACE_EXISTS=true
  fi
 fi
 
 # Check if datastore exists (only if workspace exists)
 if [[ "${WORKSPACE_EXISTS}" == "true" ]]; then
  HTTP_CODE=$(curl -s -o "${TEMP_FILE}" -w "%{http_code}" --connect-timeout 10 --max-time 30 \
   -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
   "${DATASTORE_URL}" 2> /dev/null)
  
  if [[ "${HTTP_CODE}" == "200" ]]; then
   # Check if response contains datastore name (verify it's not empty or error)
   if [[ -s "${TEMP_FILE}" ]] && grep -q "\"name\".*\"${GEOSERVER_STORE}\"" "${TEMP_FILE}" 2> /dev/null; then
    DATASTORE_EXISTS=true
   fi
  fi
 fi
 
 rm -f "${TEMP_FILE}" 2> /dev/null || true

 # Consider configured if workspace and datastore exist
 # Layers are optional (they may fail to create but configuration is still valid)
 if [[ "${WORKSPACE_EXISTS}" == "true" ]] && [[ "${DATASTORE_EXISTS}" == "true" ]]; then
  return 0
 else
  return 1
 fi
}

# Function to create workspace
create_workspace() {
 print_status "${BLUE}" "🏗️  Creating GeoServer workspace..."

 # Check if workspace already exists
 local WORKSPACE_CHECK_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}"
 local CHECK_HTTP_CODE
 CHECK_HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${WORKSPACE_CHECK_URL}" 2> /dev/null | tail -1)

 if [[ "${CHECK_HTTP_CODE}" == "200" ]]; then
  print_status "${YELLOW}" "⚠️  Workspace '${GEOSERVER_WORKSPACE}' already exists"
  return 0
 fi

 # Workspace doesn't exist, create it
 local WORKSPACE_DATA="{
   \"workspace\": {
     \"name\": \"${GEOSERVER_WORKSPACE}\",
     \"isolated\": false
   }
 }"

 local TEMP_RESPONSE_FILE="${TMP_DIR}/workspace_response_$$.tmp"
 local HTTP_CODE
 HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
  -X POST \
  -H "Content-Type: application/json" \
  -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -d "${WORKSPACE_DATA}" \
  "${GEOSERVER_URL}/rest/workspaces" 2> /dev/null | tail -1)

 local RESPONSE_BODY
 RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")

 if [[ "${HTTP_CODE}" == "201" ]] || [[ "${HTTP_CODE}" == "200" ]]; then
  print_status "${GREEN}" "✅ Workspace '${GEOSERVER_WORKSPACE}' created"
  rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
  return 0
 elif [[ "${HTTP_CODE}" == "409" ]]; then
  print_status "${YELLOW}" "⚠️  Workspace '${GEOSERVER_WORKSPACE}' already exists"
  rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
  return 0
 else
  print_status "${RED}" "❌ ERROR: Failed to create workspace (HTTP ${HTTP_CODE})"
  if [[ -n "${RESPONSE_BODY}" ]]; then
   print_status "${YELLOW}" "   Response:"
   echo "${RESPONSE_BODY}" | head -10 | sed 's/^/      /'
  fi
  rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
  return 1
 fi
}

# Function to create namespace
create_namespace() {
 print_status "${BLUE}" "🏷️  Creating GeoServer namespace..."

 # Check if namespace already exists
 # Note: GeoServer automatically creates a namespace when a workspace is created
 local NAMESPACE_CHECK_URL="${GEOSERVER_URL}/rest/namespaces/${GEOSERVER_WORKSPACE}"
 local CHECK_HTTP_CODE
 CHECK_HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${NAMESPACE_CHECK_URL}" 2> /dev/null | tail -1)

 if [[ "${CHECK_HTTP_CODE}" == "200" ]]; then
  print_status "${GREEN}" "✅ Namespace '${GEOSERVER_WORKSPACE}' already exists (created automatically with workspace)"
  return 0
 fi

 # Namespace doesn't exist, create it
 local NAMESPACE_DATA="{
   \"namespace\": {
     \"prefix\": \"${GEOSERVER_WORKSPACE}\",
     \"uri\": \"${GEOSERVER_NAMESPACE}\",
     \"isolated\": false
   }
 }"

 local TEMP_RESPONSE_FILE="${TMP_DIR}/namespace_response_$$.tmp"
 local HTTP_CODE
 HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
  -X POST \
  -H "Content-Type: application/json" \
  -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -d "${NAMESPACE_DATA}" \
  "${GEOSERVER_URL}/rest/namespaces" 2> /dev/null | tail -1)

 local RESPONSE_BODY
 RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")

 if [[ "${HTTP_CODE}" == "201" ]] || [[ "${HTTP_CODE}" == "200" ]]; then
  print_status "${GREEN}" "✅ Namespace '${GEOSERVER_WORKSPACE}' created"
  rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
  return 0
 elif [[ "${HTTP_CODE}" == "409" ]]; then
  print_status "${YELLOW}" "⚠️  Namespace '${GEOSERVER_WORKSPACE}' already exists"
  rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
  return 0
 else
  # Check if error message indicates it already exists (some GeoServer versions return 500 for this)
  if echo "${RESPONSE_BODY}" | grep -qi "already exists"; then
   print_status "${YELLOW}" "⚠️  Namespace '${GEOSERVER_WORKSPACE}' already exists"
   rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
   return 0
  else
   print_status "${RED}" "❌ ERROR: Failed to create namespace (HTTP ${HTTP_CODE})"
   if [[ -n "${RESPONSE_BODY}" ]]; then
    print_status "${YELLOW}" "   Response:"
    echo "${RESPONSE_BODY}" | head -10 | sed 's/^/      /'
   fi
   rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
   return 1
  fi
 fi
}

# Function to create or update datastore
create_datastore() {
 print_status "${BLUE}" "🗄️  Creating/updating GeoServer datastore..."

 # Check if datastore already exists
 local DATASTORE_CHECK_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}"
 local CHECK_RESPONSE
 CHECK_RESPONSE=$(curl -s -w "\n%{http_code}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${DATASTORE_CHECK_URL}" 2> /dev/null)
 local CHECK_HTTP_CODE
 CHECK_HTTP_CODE=$(echo "${CHECK_RESPONSE}" | tail -1)

 # Note: We specify 'public' as the default schema in the datastore
 # SQL views can still access other schemas (like 'wms') by using fully qualified names
 # This prevents GeoServer from interpreting layer names as schemas
 local DATASTORE_DATA="{
   \"dataStore\": {
     \"name\": \"${GEOSERVER_STORE}\",
     \"type\": \"PostGIS\",
     \"enabled\": true,
     \"connectionParameters\": {
       \"entry\": [
         {\"@key\": \"host\", \"$\": \"${DBHOST}\"},
         {\"@key\": \"port\", \"$\": \"${DBPORT}\"},
         {\"@key\": \"database\", \"$\": \"${DBNAME}\"},
         {\"@key\": \"schema\", \"$\": \"public\"},
         {\"@key\": \"user\", \"$\": \"${DBUSER}\"},
         {\"@key\": \"passwd\", \"$\": \"${DBPASSWORD}\"},
         {\"@key\": \"dbtype\", \"$\": \"postgis\"},
         {\"@key\": \"validate connections\", \"$\": \"true\"}
       ]
     }
   }
 }"

 local TEMP_RESPONSE_FILE="${TMP_DIR}/datastore_response_$$.tmp"
 local HTTP_CODE
 local DATASTORE_URL

 if [[ "${CHECK_HTTP_CODE}" == "200" ]]; then
  # Datastore exists, read current configuration to check for schema parameter
  local CURRENT_CONFIG
  CURRENT_CONFIG=$(echo "${CHECK_RESPONSE}" | head -n -1) # Remove HTTP code line
  if echo "${CURRENT_CONFIG}" | grep -q "\"schema\""; then
   print_status "${YELLOW}" "   ⚠️  Datastore has 'schema' parameter set, attempting to remove it..."
   # Try to delete and recreate to ensure clean state
   local DELETE_HTTP_CODE
   DELETE_HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X DELETE "${DATASTORE_CHECK_URL}" 2> /dev/null)
   if [[ "${DELETE_HTTP_CODE}" == "200" ]] || [[ "${DELETE_HTTP_CODE}" == "204" ]]; then
    print_status "${BLUE}" "   Old datastore removed, creating new one without schema parameter..."
    # Create new datastore
    DATASTORE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores"
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
     -X POST \
     -H "Content-Type: application/json" \
     -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
     -d "${DATASTORE_DATA}" \
     "${DATASTORE_URL}" 2> /dev/null | tail -1)
   else
    # If deletion fails (e.g., HTTP 403), try to update with explicit schema removal
    print_status "${YELLOW}" "   ⚠️  Could not remove datastore (HTTP ${DELETE_HTTP_CODE}), updating without schema parameter..."
    print_status "${YELLOW}" "   Note: If update fails, you may need to manually remove the 'schema' parameter from the datastore in GeoServer UI"
    DATASTORE_URL="${DATASTORE_CHECK_URL}"
    HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
     -X PUT \
     -H "Content-Type: application/json" \
     -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
     -d "${DATASTORE_DATA}" \
     "${DATASTORE_URL}" 2> /dev/null | tail -1)
   fi
  else
   # No schema parameter, just update normally
   print_status "${BLUE}" "   Datastore exists, updating connection parameters..."
   DATASTORE_URL="${DATASTORE_CHECK_URL}"
   HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
    -X PUT \
    -H "Content-Type: application/json" \
    -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
    -d "${DATASTORE_DATA}" \
    "${DATASTORE_URL}" 2> /dev/null | tail -1)
  fi
 else
  # Datastore doesn't exist, create it
  print_status "${BLUE}" "   Creating new datastore..."
  DATASTORE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores"
  HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
   -X POST \
   -H "Content-Type: application/json" \
   -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
   -d "${DATASTORE_DATA}" \
   "${DATASTORE_URL}" 2> /dev/null | tail -1)
 fi

 local RESPONSE_BODY
 RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")

 if [[ "${HTTP_CODE}" == "201" ]] || [[ "${HTTP_CODE}" == "200" ]]; then
  if [[ "${CHECK_HTTP_CODE}" == "200" ]]; then
   print_status "${GREEN}" "✅ Datastore '${GEOSERVER_STORE}' updated"
  else
   print_status "${GREEN}" "✅ Datastore '${GEOSERVER_STORE}' created"
  fi
 elif [[ "${HTTP_CODE}" == "409" ]]; then
  print_status "${YELLOW}" "⚠️  Datastore '${GEOSERVER_STORE}' already exists"
 else
  print_status "${RED}" "❌ ERROR: Failed to create/update datastore (HTTP ${HTTP_CODE})"
  if [[ -n "${RESPONSE_BODY}" ]]; then
   print_status "${YELLOW}" "   Response: $(echo "${RESPONSE_BODY}" | head -10)"
  fi
  rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
  return 1
 fi

 rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
}

# Function to calculate bounding box from PostgreSQL table/view
calculate_bbox_from_table() {
 local TABLE_NAME="${1}"
 
 # Query PostgreSQL to get the actual bounding box of the data
 local BBOX_QUERY="SELECT ST_XMin(bbox)::numeric, ST_YMin(bbox)::numeric, ST_XMax(bbox)::numeric, ST_YMax(bbox)::numeric FROM (SELECT ST_Extent(geometry)::box2d as bbox FROM ${TABLE_NAME} WHERE geometry IS NOT NULL) t;"
 
 local PSQL_CMD="psql -d \"${DBNAME}\" -t -A"
 if [[ -n "${DBHOST}" ]]; then
  PSQL_CMD="psql -h \"${DBHOST}\" -d \"${DBNAME}\" -t -A"
 fi
 if [[ -n "${DBUSER}" ]]; then
  PSQL_CMD="${PSQL_CMD} -U \"${DBUSER}\""
 fi
 if [[ -n "${DBPORT}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p \"${DBPORT}\""
 fi
 if [[ -n "${DBPASSWORD}" ]]; then
  export PGPASSWORD="${DBPASSWORD}"
 else
  unset PGPASSWORD 2> /dev/null || true
 fi
 
 local BBOX_RESULT
 # PostgreSQL returns values separated by | when using -A, convert to comma-separated
 BBOX_RESULT=$(eval "${PSQL_CMD} -c \"${BBOX_QUERY}\"" 2> /dev/null | tr '|' ',' | tr -d ' ' || echo "")
 
 if [[ -n "${DBPASSWORD}" ]]; then
  unset PGPASSWORD 2> /dev/null || true
 fi
 
 # If we got a valid bounding box, use it; otherwise use defaults
 if [[ -n "${BBOX_RESULT}" ]] && echo "${BBOX_RESULT}" | grep -qE '^-?[0-9]+\.[0-9]+,-?[0-9]+\.[0-9]+,-?[0-9]+\.[0-9]+,-?[0-9]+\.[0-9]+$'; then
  echo "${BBOX_RESULT}"
 else
  # Return default bounding box (worldwide) - GeoServer will recalculate from data
  echo "${WMS_BBOX_MINX},${WMS_BBOX_MINY},${WMS_BBOX_MAXX},${WMS_BBOX_MAXY}"
 fi
}

# Function to create feature type from table
create_feature_type_from_table() {
 local LAYER_NAME="${1}"
 local TABLE_NAME="${2}"
 local LAYER_TITLE="${3}"
 local LAYER_DESCRIPTION="${4}"

 print_status "${BLUE}" "🗺️  Creating GeoServer feature type '${LAYER_NAME}' from table '${TABLE_NAME}'..."

 # Calculate actual bounding box from PostgreSQL data
 local BBOX
 BBOX=$(calculate_bbox_from_table "${TABLE_NAME}")
 local BBOX_MINX BBOX_MINY BBOX_MAXX BBOX_MAXY
 IFS=',' read -r BBOX_MINX BBOX_MINY BBOX_MAXX BBOX_MAXY <<< "${BBOX}"

 # For views and materialized views, we need to specify attributes explicitly
 # Check if it's a view (contains 'view' in the name, case insensitive)
 # or a materialized view (disputed_and_unclaimed_areas)
 local IS_VIEW=0
 if echo "${TABLE_NAME}" | grep -qi "view"; then
  IS_VIEW=1
 elif echo "${TABLE_NAME}" | grep -qi "disputed_and_unclaimed_areas"; then
  IS_VIEW=1
 fi

 # Build attributes JSON based on table/view type
 local ATTRIBUTES_JSON=""
 if [[ ${IS_VIEW} -eq 1 ]]; then
  # Check if it's disputed areas (materialized view) or notes views
  if echo "${TABLE_NAME}" | grep -qi "disputed_and_unclaimed_areas"; then
   # For disputed areas materialized view
   ATTRIBUTES_JSON=",
     \"attributes\": {
       \"attribute\": [
         {
           \"name\": \"id\",
           \"minOccurs\": 0,
           \"maxOccurs\": 1,
           \"nillable\": true,
           \"binding\": \"java.lang.Integer\"
         },
         {
           \"name\": \"geometry\",
           \"minOccurs\": 1,
           \"maxOccurs\": 1,
           \"nillable\": false,
           \"binding\": \"org.locationtech.jts.geom.Geometry\"
         },
         {
           \"name\": \"zone_type\",
           \"minOccurs\": 0,
           \"maxOccurs\": 1,
           \"nillable\": true,
           \"binding\": \"java.lang.String\"
         },
         {
           \"name\": \"country_ids\",
           \"minOccurs\": 0,
           \"maxOccurs\": 1,
           \"nillable\": true,
           \"binding\": \"java.lang.String\"
         },
         {
           \"name\": \"country_names\",
           \"minOccurs\": 0,
           \"maxOccurs\": 1,
           \"nillable\": true,
           \"binding\": \"java.lang.String\"
         }
       ]
     }"
  else
   # For notes views (notes_open_view and notes_closed_view)
   ATTRIBUTES_JSON=",
     \"attributes\": {
       \"attribute\": [
         {
           \"name\": \"note_id\",
           \"minOccurs\": 0,
           \"maxOccurs\": 1,
           \"nillable\": true,
           \"binding\": \"java.lang.Integer\"
         },
         {
           \"name\": \"year_created_at\",
           \"minOccurs\": 0,
           \"maxOccurs\": 1,
           \"nillable\": true,
           \"binding\": \"java.lang.Double\"
         },
         {
           \"name\": \"year_closed_at\",
           \"minOccurs\": 0,
           \"maxOccurs\": 1,
           \"nillable\": true,
           \"binding\": \"java.lang.Double\"
         },
         {
           \"name\": \"geometry\",
           \"minOccurs\": 1,
           \"maxOccurs\": 1,
           \"nillable\": false,
           \"binding\": \"org.locationtech.jts.geom.Geometry\"
         }
       ]
     }"
  fi
 fi

 local FEATURE_TYPE_DATA="{
   \"featureType\": {
     \"name\": \"${LAYER_NAME}\",
     \"nativeName\": \"${TABLE_NAME}\",
     \"title\": \"${LAYER_TITLE}\",
     \"description\": \"${LAYER_DESCRIPTION}\",
     \"enabled\": true,
     \"srs\": \"${WMS_LAYER_SRS}\",
     \"nativeBoundingBox\": {
       \"minx\": ${BBOX_MINX},
       \"maxx\": ${BBOX_MAXX},
       \"miny\": ${BBOX_MINY},
       \"maxy\": ${BBOX_MAXY},
       \"crs\": \"${WMS_LAYER_SRS}\"
     },
     \"latLonBoundingBox\": {
       \"minx\": ${BBOX_MINX},
       \"maxx\": ${BBOX_MAXX},
       \"miny\": ${BBOX_MINY},
       \"maxy\": ${BBOX_MAXY},
       \"crs\": \"${WMS_LAYER_SRS}\"
     }${ATTRIBUTES_JSON},
     \"store\": {
       \"@class\": \"dataStore\",
       \"name\": \"${GEOSERVER_STORE}\"
     }
   }
 }"

 local FEATURE_TYPE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}/featuretypes"
 local FEATURE_TYPE_UPDATE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}/featuretypes/${LAYER_NAME}"

 local TEMP_RESPONSE_FILE="${TMP_DIR}/featuretype_response_${LAYER_NAME}_$$.tmp"
 local HTTP_CODE
 HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
  -X POST \
  -H "Content-Type: application/json" \
  -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -d "${FEATURE_TYPE_DATA}" \
  "${FEATURE_TYPE_URL}" 2> /dev/null | tail -1)

 local RESPONSE_BODY
 RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")

 if [[ "${HTTP_CODE}" == "201" ]] || [[ "${HTTP_CODE}" == "200" ]]; then
  print_status "${GREEN}" "✅ Feature type '${LAYER_NAME}' created"
  # Force GeoServer to recalculate bounding boxes from actual data
  print_status "${BLUE}" "📐 Recalculating bounding boxes from data..."
  # Use the recalculate endpoint to compute bounding boxes from actual data
  local RECALC_URL="${FEATURE_TYPE_UPDATE_URL}?recalculate=nativebbox,latlonbbox"
  local TEMP_RECALC_FILE="${TMP_DIR}/recalc_${LAYER_NAME}_$$.tmp"
  local RECALC_CODE
  RECALC_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RECALC_FILE}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X PUT "${RECALC_URL}" 2> /dev/null | tail -1)
  if [[ "${RECALC_CODE}" == "200" ]]; then
   print_status "${GREEN}" "✅ Bounding boxes recalculated"
  else
   print_status "${YELLOW}" "⚠️  Could not recalculate bounding boxes (HTTP ${RECALC_CODE})"
   print_status "${YELLOW}" "   GeoServer will use the provided bounding box"
  fi
  rm -f "${TEMP_RECALC_FILE}" 2> /dev/null || true
  rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
  return 0
 elif [[ "${HTTP_CODE}" == "409" ]] || echo "${RESPONSE_BODY}" | grep -qi "already exists"; then
  # Check if layer exists - if not, delete feature type and recreate to force layer creation
  local LAYER_CHECK_URL="${GEOSERVER_URL}/rest/layers/${GEOSERVER_WORKSPACE}:${LAYER_NAME}"
  local LAYER_CHECK_CODE
  LAYER_CHECK_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${LAYER_CHECK_URL}" 2> /dev/null | tail -1)
  
  if [[ "${LAYER_CHECK_CODE}" != "200" ]]; then
   # Layer doesn't exist, delete feature type and recreate
   print_status "${YELLOW}" "⚠️  Feature type '${LAYER_NAME}' exists but layer doesn't, recreating..."
   curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
    -X DELETE "${FEATURE_TYPE_UPDATE_URL}?recurse=true" 2> /dev/null | tail -1 > /dev/null
   sleep 2
   # Retry creation
   HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
    -X POST \
    -H "Content-Type: application/json" \
    -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
    -d "${FEATURE_TYPE_DATA}" \
    "${FEATURE_TYPE_URL}" 2> /dev/null | tail -1)
   RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")
   if [[ "${HTTP_CODE}" == "201" ]] || [[ "${HTTP_CODE}" == "200" ]]; then
    print_status "${GREEN}" "✅ Feature type '${LAYER_NAME}' recreated"
    # Force GeoServer to recalculate bounding boxes from actual data
    print_status "${BLUE}" "📐 Recalculating bounding boxes from data..."
    local RECALC_URL="${FEATURE_TYPE_UPDATE_URL}?recalculate=nativebbox,latlonbbox"
    local TEMP_RECALC_FILE="${TMP_DIR}/recalc_${LAYER_NAME}_$$.tmp"
    local RECALC_CODE
    RECALC_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RECALC_FILE}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X PUT "${RECALC_URL}" 2> /dev/null | tail -1)
    if [[ "${RECALC_CODE}" == "200" ]]; then
     print_status "${GREEN}" "✅ Bounding boxes recalculated"
    else
     print_status "${YELLOW}" "⚠️  Could not recalculate bounding boxes (HTTP ${RECALC_CODE})"
     print_status "${YELLOW}" "   GeoServer will use the provided bounding box"
    fi
    rm -f "${TEMP_RECALC_FILE}" 2> /dev/null || true
    rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
    return 0
   fi
  fi
  
  # Layer exists or recreation failed, try to update
  print_status "${YELLOW}" "⚠️  Feature type '${LAYER_NAME}' already exists, updating..."
  # Recalculate bounding box from actual data
  local BBOX_UPDATE
  BBOX_UPDATE=$(calculate_bbox_from_table "${TABLE_NAME}")
  local BBOX_MINX_UPDATE BBOX_MINY_UPDATE BBOX_MAXX_UPDATE BBOX_MAXY_UPDATE
  IFS=',' read -r BBOX_MINX_UPDATE BBOX_MINY_UPDATE BBOX_MAXX_UPDATE BBOX_MAXY_UPDATE <<< "${BBOX_UPDATE}"
  # For update, include calculated bounding boxes
  local FEATURE_TYPE_UPDATE_DATA="{
   \"featureType\": {
     \"name\": \"${LAYER_NAME}\",
     \"nativeName\": \"${TABLE_NAME}\",
     \"title\": \"${LAYER_TITLE}\",
     \"description\": \"${LAYER_DESCRIPTION}\",
     \"enabled\": true,
     \"srs\": \"${WMS_LAYER_SRS}\",
     \"nativeBoundingBox\": {
       \"minx\": ${BBOX_MINX_UPDATE},
       \"maxx\": ${BBOX_MAXX_UPDATE},
       \"miny\": ${BBOX_MINY_UPDATE},
       \"maxy\": ${BBOX_MAXY_UPDATE},
       \"crs\": \"${WMS_LAYER_SRS}\"
     },
     \"latLonBoundingBox\": {
       \"minx\": ${BBOX_MINX_UPDATE},
       \"maxx\": ${BBOX_MAXX_UPDATE},
       \"miny\": ${BBOX_MINY_UPDATE},
       \"maxy\": ${BBOX_MAXY_UPDATE},
       \"crs\": \"${WMS_LAYER_SRS}\"
     }${ATTRIBUTES_JSON},
     \"store\": {
       \"@class\": \"dataStore\",
       \"name\": \"${GEOSERVER_STORE}\"
     }
   }
 }"
  # Try to update using PUT (without bounding boxes - GeoServer will recalculate)
  HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
   -X PUT \
   -H "Content-Type: application/json" \
   -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
   -d "${FEATURE_TYPE_UPDATE_DATA}" \
   "${FEATURE_TYPE_UPDATE_URL}" 2> /dev/null | tail -1)
  RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")
  if [[ "${HTTP_CODE}" == "200" ]]; then
   print_status "${GREEN}" "✅ Feature type '${LAYER_NAME}' updated"
   print_status "${GREEN}" "✅ GeoServer will recalculate bounding boxes automatically"
   rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
   return 0
  else
   print_status "${YELLOW}" "⚠️  Feature type '${LAYER_NAME}' already exists (update not needed)"
   rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
   return 0
  fi
 else
  print_status "${YELLOW}" "⚠️  Failed to create feature type '${LAYER_NAME}' (HTTP ${HTTP_CODE})"
  if [[ -n "${RESPONSE_BODY}" ]]; then
   print_status "${YELLOW}" "   Response:"
   echo "${RESPONSE_BODY}" | head -10 | sed 's/^/      /'
  fi
  rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
  return 1
 fi
}

# Function to create SQL view layer
create_sql_view_layer() {
 local LAYER_NAME="${1}"
 local SQL_QUERY="${2}"
 local LAYER_TITLE="${3}"
 local LAYER_DESCRIPTION="${4}"
 local GEOMETRY_COLUMN="${5:-geometry}"

 print_status "${BLUE}" "🗺️  Creating GeoServer SQL view layer '${LAYER_NAME}'..."

 # Escape SQL query for XML (escape <, >, &, ", ')
 # Note: We need to escape for XML first, then for JSON
 # Replace newlines with spaces and collapse multiple spaces
 local CLEANED_SQL
 CLEANED_SQL=$(echo "${SQL_QUERY}" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//' | sed 's/ *$//')
 
 # Escape for XML: & must be first, then < and >
 local ESCAPED_SQL
 ESCAPED_SQL=$(echo "${CLEANED_SQL}" | sed 's/&/\&amp;/g' | sed 's/</\&lt;/g' | sed 's/>/\&gt;/g' | sed 's/"/\&quot;/g' | sed "s/'/\&apos;/g")

 # Escape the XML for JSON (escape backslashes first, then quotes, then newlines)
 # Order matters: backslashes first, then quotes
 # Create virtual table XML file (temporary) to ensure proper formatting
 # Note: Use a simple fixed name for virtual table to avoid GeoServer schema interpretation
 # The virtual table name should not match any schema or table names
 local VIRTUAL_TABLE_NAME="vtable"
 local TEMP_VIRTUAL_TABLE="${TMP_DIR}/virtual_table_${LAYER_NAME}_$$.xml"
 cat > "${TEMP_VIRTUAL_TABLE}" <<EOF
<virtualTable>
  <name>${VIRTUAL_TABLE_NAME}</name>
  <sql>${ESCAPED_SQL}</sql>
  <geometry>
    <name>${GEOMETRY_COLUMN}</name>
    <type>Geometry</type>
    <srid>4326</srid>
  </geometry>
</virtualTable>
EOF

 # Read the XML and escape it for JSON
 local VIRTUAL_TABLE_CONTENT
 VIRTUAL_TABLE_CONTENT=$(cat "${TEMP_VIRTUAL_TABLE}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
 rm -f "${TEMP_VIRTUAL_TABLE}" 2> /dev/null || true

 # Create JSON payload using a temporary file to avoid escaping issues
 # Note: For SQL views, we don't specify nativeName to avoid GeoServer schema interpretation issues
 # The virtual table name in JDBC_VIRTUAL_TABLE metadata is what GeoServer uses
 local TEMP_JSON="${TMP_DIR}/featuretype_${LAYER_NAME}_$$.json"
 cat > "${TEMP_JSON}" <<EOF
{
  "featureType": {
    "name": "${LAYER_NAME}",
    "title": "${LAYER_TITLE}",
    "description": "${LAYER_DESCRIPTION}",
    "enabled": true,
    "srs": "${WMS_LAYER_SRS}",
    "nativeBoundingBox": {
      "minx": ${WMS_BBOX_MINX},
      "maxx": ${WMS_BBOX_MAXX},
      "miny": ${WMS_BBOX_MINY},
      "maxy": ${WMS_BBOX_MAXY},
      "crs": "${WMS_LAYER_SRS}"
    },
    "latLonBoundingBox": {
      "minx": ${WMS_BBOX_MINX},
      "maxx": ${WMS_BBOX_MAXX},
      "miny": ${WMS_BBOX_MINY},
      "maxy": ${WMS_BBOX_MAXY},
      "crs": "${WMS_LAYER_SRS}"
    },
    "metadata": {
      "entry": [
        {
          "@key": "JDBC_VIRTUAL_TABLE",
          "$": "${VIRTUAL_TABLE_CONTENT}"
        }
      ]
    }
  }
}
EOF

 local FEATURE_TYPE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}/featuretypes"
 local FEATURE_TYPE_UPDATE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}/featuretypes/${LAYER_NAME}"

 local TEMP_RESPONSE_FILE="${TMP_DIR}/sqlview_response_${LAYER_NAME}_$$.tmp"
 local HTTP_CODE
 HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
  -X POST \
  -H "Content-Type: application/json" \
  -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -d "@${TEMP_JSON}" \
  "${FEATURE_TYPE_URL}" 2> /dev/null | tail -1)
  
 local RESPONSE_BODY
 RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")

 if [[ "${HTTP_CODE}" == "201" ]] || [[ "${HTTP_CODE}" == "200" ]]; then
  print_status "${GREEN}" "✅ SQL view layer '${LAYER_NAME}' created"
  rm -f "${TEMP_JSON}" "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
  return 0
 elif [[ "${HTTP_CODE}" == "409" ]]; then
  print_status "${YELLOW}" "⚠️  SQL view layer '${LAYER_NAME}' already exists, updating..."
  # Try to update using PUT
  HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
   -X PUT \
   -H "Content-Type: application/json" \
   -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
   -d "@${TEMP_JSON}" \
   "${FEATURE_TYPE_UPDATE_URL}" 2> /dev/null | tail -1)
  RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")
  if [[ "${HTTP_CODE}" == "200" ]]; then
   print_status "${GREEN}" "✅ SQL view layer '${LAYER_NAME}' updated"
   rm -f "${TEMP_JSON}" "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
   return 0
  else
   print_status "${YELLOW}" "⚠️  SQL view layer '${LAYER_NAME}' already exists (update not needed)"
   rm -f "${TEMP_JSON}" "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
   return 0
  fi
 else
  # Check if error message indicates it already exists (some GeoServer versions return 500 for this)
  if echo "${RESPONSE_BODY}" | grep -qi "already exists"; then
   print_status "${YELLOW}" "⚠️  SQL view layer '${LAYER_NAME}' already exists, updating..."
   # Try to update using PUT
   HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
    -X PUT \
    -H "Content-Type: application/json" \
    -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
    -d "@${TEMP_JSON}" \
    "${FEATURE_TYPE_UPDATE_URL}" 2> /dev/null | tail -1)
   RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")
   if [[ "${HTTP_CODE}" == "200" ]]; then
    print_status "${GREEN}" "✅ SQL view layer '${LAYER_NAME}' updated"
    rm -f "${TEMP_JSON}" "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
    return 0
   else
    print_status "${YELLOW}" "⚠️  SQL view layer '${LAYER_NAME}' already exists (update not needed)"
    rm -f "${TEMP_JSON}" "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
    return 0
   fi
  else
   print_status "${YELLOW}" "⚠️  Failed to create SQL view layer '${LAYER_NAME}' (HTTP ${HTTP_CODE})"
   if [[ -n "${RESPONSE_BODY}" ]]; then
    print_status "${YELLOW}" "   Response:"
    echo "${RESPONSE_BODY}" | head -30 | sed 's/^/      /'
   fi
   print_status "${YELLOW}" "   Troubleshooting:"
   print_status "${YELLOW}" "   - Verify SQL query is valid: ${SQL_QUERY}"
   print_status "${YELLOW}" "   - Check datastore connection to database"
   print_status "${YELLOW}" "   - Verify geometry column name: ${GEOMETRY_COLUMN}"
   rm -f "${TEMP_JSON}" "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
   return 1
  fi
 fi
}

# Legacy function for backward compatibility
create_feature_type() {
 create_feature_type_from_table "${GEOSERVER_LAYER}" "${WMS_TABLE}" "${WMS_LAYER_TITLE}" "${WMS_LAYER_DESCRIPTION}"
}

# Function to extract style name from SLD file
extract_style_name_from_sld() {
 local SLD_FILE="${1}"
 # Extract the first <se:Name> or <Name> tag content from the SLD
 local STYLE_NAME
 STYLE_NAME=$(grep -oP '<(se:)?Name[^>]*>.*?</(se:)?Name>' "${SLD_FILE}" 2> /dev/null | head -1 | sed 's/.*>\(.*\)<.*/\1/' | tr -d ' ')
 echo "${STYLE_NAME}"
}

# Function to upload style
upload_style() {
 local SLD_FILE="${1}"
 local STYLE_NAME="${2}"
 local FORCE_UPLOAD="${FORCE:-false}"

 # Validate SLD file using centralized validation
 if ! __validate_input_file "${SLD_FILE}" "SLD style file"; then
  print_status "${YELLOW}" "⚠️  SLD file validation failed: ${SLD_FILE}"
  if [[ "${FORCE_UPLOAD}" == "true" ]]; then
   return 0  # Continue with --force
  fi
  return 1
 fi

 # Extract actual style name from SLD (may differ from STYLE_NAME parameter)
 local ACTUAL_STYLE_NAME
 ACTUAL_STYLE_NAME=$(extract_style_name_from_sld "${SLD_FILE}")
 if [[ -z "${ACTUAL_STYLE_NAME}" ]]; then
  # Fallback to provided name if extraction fails
  ACTUAL_STYLE_NAME="${STYLE_NAME}"
 fi

 # Check if style already exists (try both the provided name and the actual name)
 local STYLE_CHECK_URL="${GEOSERVER_URL}/rest/styles/${ACTUAL_STYLE_NAME}"
 local TEMP_CHECK_FILE="${TMP_DIR}/style_check_${STYLE_NAME}_$$.tmp"
 local CHECK_HTTP_CODE
 CHECK_HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_CHECK_FILE}" \
  -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  "${STYLE_CHECK_URL}" 2> /dev/null | tail -1)

 # If not found with actual name, try with provided name
 if [[ "${CHECK_HTTP_CODE}" != "200" ]] && [[ "${ACTUAL_STYLE_NAME}" != "${STYLE_NAME}" ]]; then
  STYLE_CHECK_URL="${GEOSERVER_URL}/rest/styles/${STYLE_NAME}"
  CHECK_HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_CHECK_FILE}" \
   -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
   "${STYLE_CHECK_URL}" 2> /dev/null | tail -1)
  if [[ "${CHECK_HTTP_CODE}" == "200" ]]; then
   ACTUAL_STYLE_NAME="${STYLE_NAME}"
  fi
 fi

 local TEMP_RESPONSE_FILE="${TMP_DIR}/style_response_${STYLE_NAME}_$$.tmp"
 local HTTP_CODE
 local RESPONSE_BODY

 # If style exists, update it; otherwise create it
 if [[ "${CHECK_HTTP_CODE}" == "200" ]]; then
  # Style exists, update it
  HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
   -X PUT \
   -H "Content-Type: application/vnd.ogc.sld+xml" \
   -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
   -d "@${SLD_FILE}" \
   "${STYLE_CHECK_URL}" 2> /dev/null | tail -1)
 else
  # Style doesn't exist, create it (use the name from SLD, not the parameter)
  # GeoServer will extract the name from the SLD file itself
  HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
   -X POST \
   -H "Content-Type: application/vnd.ogc.sld+xml" \
   -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
   -d "@${SLD_FILE}" \
   "${GEOSERVER_URL}/rest/styles?name=${ACTUAL_STYLE_NAME}" 2> /dev/null | tail -1)
 fi

 RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")

 local STYLE_UPLOADED=false
 if [[ "${HTTP_CODE}" == "201" ]] || [[ "${HTTP_CODE}" == "200" ]]; then
  if [[ "${CHECK_HTTP_CODE}" == "200" ]]; then
   print_status "${GREEN}" "✅ Style '${ACTUAL_STYLE_NAME}' updated"
  else
   print_status "${GREEN}" "✅ Style '${ACTUAL_STYLE_NAME}' uploaded"
  fi
  STYLE_UPLOADED=true
 elif [[ "${HTTP_CODE}" == "409" ]] || [[ "${HTTP_CODE}" == "403" ]]; then
  # 403 or 409 means style already exists - try to update it
  if [[ "${CHECK_HTTP_CODE}" != "200" ]]; then
   # Style exists but we couldn't find it by name, try updating with actual name
   HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
    -X PUT \
    -H "Content-Type: application/vnd.ogc.sld+xml" \
    -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
    -d "@${SLD_FILE}" \
    "${GEOSERVER_URL}/rest/styles/${ACTUAL_STYLE_NAME}" 2> /dev/null | tail -1)
   RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")
   if [[ "${HTTP_CODE}" == "200" ]]; then
    print_status "${GREEN}" "✅ Style '${ACTUAL_STYLE_NAME}' updated"
    STYLE_UPLOADED=true
   else
    print_status "${YELLOW}" "⚠️  Style '${ACTUAL_STYLE_NAME}' already exists (could not update)"
    if [[ "${FORCE_UPLOAD}" == "true" ]]; then
     STYLE_UPLOADED=true  # Continue with --force
    fi
   fi
  else
   print_status "${YELLOW}" "⚠️  Style '${ACTUAL_STYLE_NAME}' already exists"
   STYLE_UPLOADED=true
  fi
 else
  print_status "${YELLOW}" "⚠️  Style upload failed (HTTP ${HTTP_CODE})"
  if [[ -n "${RESPONSE_BODY}" ]]; then
   print_status "${YELLOW}" "   Error:"
   echo "${RESPONSE_BODY}" | head -20 | sed 's/^/      /'
  else
   print_status "${YELLOW}" "   (No error message returned - check GeoServer logs)"
   print_status "${YELLOW}" "   Common causes:"
   print_status "${YELLOW}" "   - Invalid SLD format"
   print_status "${YELLOW}" "   - GeoServer out of memory"
   print_status "${YELLOW}" "   - File too large"
   print_status "${YELLOW}" "   - Check GeoServer logs: tail -f /opt/geoserver/logs/geoserver.log"
  fi
  if [[ "${FORCE_UPLOAD}" == "true" ]]; then
   print_status "${YELLOW}" "   Continuing with --force..."
   STYLE_UPLOADED=true  # Continue with --force
  fi
 fi

 rm -f "${TEMP_RESPONSE_FILE}" "${TEMP_CHECK_FILE}" 2> /dev/null || true

 if [[ "${STYLE_UPLOADED}" == "true" ]]; then
  return 0
 else
  return 1
 fi
}

# Function to create layer from feature type
create_layer_from_feature_type() {
 local LAYER_NAME="${1}"
 local STYLE_NAME="${2}"

 # Check if layer already exists
 local LAYER_CHECK_URL="${GEOSERVER_URL}/rest/layers/${GEOSERVER_WORKSPACE}:${LAYER_NAME}"
 local LAYER_CHECK_CODE
 LAYER_CHECK_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${LAYER_CHECK_URL}" 2> /dev/null | tail -1)

 if [[ "${LAYER_CHECK_CODE}" == "200" ]]; then
  # Layer already exists
  return 0
 fi

 # Layer doesn't exist, wait a moment and check again
 # GeoServer may create the layer automatically after feature type creation
 print_status "${BLUE}" "📋 Waiting for layer '${LAYER_NAME}' to be available..."
 sleep 2

 # Check again if layer exists (GeoServer may have created it automatically)
 LAYER_CHECK_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${LAYER_CHECK_URL}" 2> /dev/null | tail -1)

 if [[ "${LAYER_CHECK_CODE}" == "200" ]]; then
  # Layer was created automatically by GeoServer
  print_status "${GREEN}" "✅ Layer '${LAYER_NAME}' is now available"
  return 0
 fi

 # Layer still doesn't exist, try to create it manually
 print_status "${BLUE}" "📋 Creating layer '${LAYER_NAME}' from feature type..."

 # Use the correct format for GeoServer layer creation
 local LAYER_DATA="{
   \"layer\": {
     \"name\": \"${LAYER_NAME}\",
     \"type\": \"VECTOR\",
     \"defaultStyle\": {
       \"name\": \"${STYLE_NAME}\"
     },
     \"resource\": {
       \"@class\": \"featureType\",
       \"name\": \"${LAYER_NAME}\"
     },
     \"path\": \"/${GEOSERVER_WORKSPACE}:${LAYER_NAME}\"
   }
 }"

 # Try creating using POST to workspace layers endpoint
 local LAYER_CREATE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/layers"
 local TEMP_LAYER_FILE="${TMP_DIR}/layer_create_${LAYER_NAME}_$$.tmp"
 local HTTP_CODE
 HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_LAYER_FILE}" \
  -X POST \
  -H "Content-Type: application/json" \
  -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -d "${LAYER_DATA}" \
  "${LAYER_CREATE_URL}" 2> /dev/null | tail -1)

 local RESPONSE_BODY
 RESPONSE_BODY=$(cat "${TEMP_LAYER_FILE}" 2> /dev/null || echo "")

 # If that fails with 405, the endpoint might not support POST
 # In that case, GeoServer should have created the layer automatically
 # We'll just return success and let the style assignment handle it
 if [[ "${HTTP_CODE}" == "405" ]]; then
  print_status "${YELLOW}" "⚠️  Layer creation endpoint not available (HTTP 405)"
  print_status "${YELLOW}" "   GeoServer should create layers automatically from feature types"
  print_status "${YELLOW}" "   Layer may be available after a short delay"
  rm -f "${TEMP_LAYER_FILE}" 2> /dev/null || true
  # Return success - we'll let the style assignment retry
  return 0
 fi

 rm -f "${TEMP_LAYER_FILE}" 2> /dev/null || true

 if [[ "${HTTP_CODE}" == "201" ]] || [[ "${HTTP_CODE}" == "200" ]]; then
  print_status "${GREEN}" "✅ Layer '${LAYER_NAME}' created"
  return 0
 elif [[ "${HTTP_CODE}" == "409" ]]; then
  # Layer already exists (race condition)
  print_status "${GREEN}" "✅ Layer '${LAYER_NAME}' already exists"
  return 0
 else
  print_status "${YELLOW}" "⚠️  Failed to create layer '${LAYER_NAME}' (HTTP ${HTTP_CODE})"
  if [[ -n "${RESPONSE_BODY}" ]]; then
   print_status "${YELLOW}" "   Response:"
   echo "${RESPONSE_BODY}" | head -10 | sed 's/^/      /'
  fi
  print_status "${YELLOW}" "   Note: Layer may be created automatically by GeoServer"
  # Return success anyway - style assignment will handle if layer doesn't exist
  return 0
 fi
}

# Function to assign style to layer
assign_style_to_layer() {
 local LAYER_NAME="${1}"
 local STYLE_NAME="${2}"

 print_status "${BLUE}" "🎨 Assigning style '${STYLE_NAME}' to layer '${LAYER_NAME}'..."

 # Wait a moment after layer creation/update to ensure GeoServer has initialized it
 # This helps avoid "original is null" errors when assigning styles immediately after update
 sleep 1

 # Ensure layer exists before assigning style
 if ! create_layer_from_feature_type "${LAYER_NAME}" "${STYLE_NAME}"; then
  print_status "${YELLOW}" "⚠️  Could not create layer '${LAYER_NAME}', skipping style assignment"
  return 1
 fi

 # Verify layer exists and is accessible before assigning style
 local LAYER_CHECK_URL="${GEOSERVER_URL}/rest/layers/${GEOSERVER_WORKSPACE}:${LAYER_NAME}"
 local LAYER_CHECK_CODE
 LAYER_CHECK_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${LAYER_CHECK_URL}" 2> /dev/null | tail -1)

 if [[ "${LAYER_CHECK_CODE}" != "200" ]]; then
  print_status "${YELLOW}" "⚠️  Layer '${LAYER_NAME}' not found or not accessible (HTTP ${LAYER_CHECK_CODE})"
  print_status "${YELLOW}" "   Skipping style assignment - layer may need to be recreated"
  return 1
 fi

 local LAYER_STYLE_DATA="{
   \"layer\": {
     \"defaultStyle\": {
       \"name\": \"${STYLE_NAME}\"
     }
   }
 }"

 local TEMP_STYLE_ASSIGN_FILE="${TMP_DIR}/style_assign_${LAYER_NAME}_$$.tmp"
 local ASSIGN_HTTP_CODE
 ASSIGN_HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_STYLE_ASSIGN_FILE}" \
  -X PUT \
  -H "Content-Type: application/json" \
  -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -d "${LAYER_STYLE_DATA}" \
  "${GEOSERVER_URL}/rest/layers/${GEOSERVER_WORKSPACE}:${LAYER_NAME}" 2> /dev/null | tail -1)

 if [[ "${ASSIGN_HTTP_CODE}" == "200" ]] || [[ "${ASSIGN_HTTP_CODE}" == "204" ]]; then
  print_status "${GREEN}" "✅ Style '${STYLE_NAME}' assigned to layer '${LAYER_NAME}'"
  rm -f "${TEMP_STYLE_ASSIGN_FILE}" 2> /dev/null || true
  return 0
 else
  print_status "${YELLOW}" "⚠️  Style assignment failed (HTTP ${ASSIGN_HTTP_CODE})"
  local ASSIGN_RESPONSE
  ASSIGN_RESPONSE=$(cat "${TEMP_STYLE_ASSIGN_FILE}" 2> /dev/null || echo "")
  if [[ -n "${ASSIGN_RESPONSE}" ]]; then
   print_status "${YELLOW}" "   Response:"
   echo "${ASSIGN_RESPONSE}" | head -10 | sed 's/^/      /'
  fi
  print_status "${YELLOW}" "   Note: Style can be assigned manually from GeoServer UI if needed"
  rm -f "${TEMP_STYLE_ASSIGN_FILE}" 2> /dev/null || true
  return 1
 fi
}

# Function to install GeoServer configuration
install_geoserver_config() {
 print_status "${BLUE}" "🚀 Installing GeoServer configuration..."

 # Check if GeoServer is already configured
 if is_geoserver_configured; then
  if [[ "${FORCE:-false}" != "true" ]]; then
   print_status "${YELLOW}" "⚠️  GeoServer is already configured. Use --force to reconfigure."
   return 0
  fi
 fi

 if [[ "${DRY_RUN:-false}" == "true" ]]; then
  print_status "${YELLOW}" "DRY RUN: Would configure GeoServer for OSM notes WMS"
  return 0
 fi

 # Create workspace and namespace
 create_workspace
 create_namespace

 # Create datastore
 if ! create_datastore; then
  print_status "${RED}" "❌ ERROR: GeoServer configuration failed (datastore)"
  exit 1
 fi

 # Upload all styles first
 print_status "${BLUE}" "🎨 Uploading styles..."
 local STYLE_ERRORS=0
 if ! upload_style "${WMS_STYLE_OPEN_FILE}" "${WMS_STYLE_OPEN_NAME}"; then
  ((STYLE_ERRORS++))
 fi
 if ! upload_style "${WMS_STYLE_CLOSED_FILE}" "${WMS_STYLE_CLOSED_NAME}"; then
  ((STYLE_ERRORS++))
 fi
 if ! upload_style "${WMS_STYLE_COUNTRIES_FILE}" "${WMS_STYLE_COUNTRIES_NAME}"; then
  ((STYLE_ERRORS++))
 fi
 if ! upload_style "${WMS_STYLE_DISPUTED_FILE}" "${WMS_STYLE_DISPUTED_NAME}"; then
  ((STYLE_ERRORS++))
 fi

 # If styles failed and not using --force, exit
 if [[ ${STYLE_ERRORS} -gt 0 ]] && [[ "${FORCE:-false}" != "true" ]]; then
  print_status "${RED}" "❌ ERROR: Failed to upload ${STYLE_ERRORS} style(s)"
  print_status "${YELLOW}" "   Use --force to continue despite style upload errors"
  exit 1
 elif [[ ${STYLE_ERRORS} -gt 0 ]]; then
  print_status "${YELLOW}" "⚠️  ${STYLE_ERRORS} style(s) failed to upload, continuing with --force"
 fi

# Create layer 1: Open Notes (PostgreSQL view)
# Use PostgreSQL view instead of SQL view to avoid "Schema does not exist" error
print_status "${BLUE}" "📊 Creating layer 1/4: Open Notes..."
local OPEN_LAYER_NAME="notesopen"
local OPEN_VIEW_NAME="wms.notes_open_view"
if create_feature_type_from_table "${OPEN_LAYER_NAME}" "${OPEN_VIEW_NAME}" "${WMS_LAYER_OPEN_NAME}" "${WMS_LAYER_OPEN_DESCRIPTION}"; then
  # Extract actual style name from SLD
  local OPEN_STYLE_NAME
  OPEN_STYLE_NAME=$(extract_style_name_from_sld "${WMS_STYLE_OPEN_FILE}")
  if [[ -z "${OPEN_STYLE_NAME}" ]]; then
   OPEN_STYLE_NAME="${WMS_STYLE_OPEN_NAME}"
  fi
  assign_style_to_layer "${OPEN_LAYER_NAME}" "${OPEN_STYLE_NAME}"
 fi

# Create layer 2: Closed Notes (PostgreSQL view)
# Use PostgreSQL view instead of SQL view to avoid "Schema does not exist" error
print_status "${BLUE}" "📊 Creating layer 2/4: Closed Notes..."
local CLOSED_LAYER_NAME="notesclosed"
local CLOSED_VIEW_NAME="wms.notes_closed_view"
if create_feature_type_from_table "${CLOSED_LAYER_NAME}" "${CLOSED_VIEW_NAME}" "${WMS_LAYER_CLOSED_NAME}" "${WMS_LAYER_CLOSED_DESCRIPTION}"; then
  # Extract actual style name from SLD
  local CLOSED_STYLE_NAME
  CLOSED_STYLE_NAME=$(extract_style_name_from_sld "${WMS_STYLE_CLOSED_FILE}")
  if [[ -z "${CLOSED_STYLE_NAME}" ]]; then
   CLOSED_STYLE_NAME="${WMS_STYLE_CLOSED_NAME}"
  fi
  assign_style_to_layer "${CLOSED_LAYER_NAME}" "${CLOSED_STYLE_NAME}"
 fi

 # Create layer 3: Countries (SQL view)
 # Note: countries table is in public schema, not wms schema
 # Use SQL view to access public schema from wms datastore
 print_status "${BLUE}" "📊 Creating layer 3/4: Countries..."
 local COUNTRIES_LAYER_NAME="countries"
 local COUNTRIES_TITLE="Countries and Maritime Areas"
 local COUNTRIES_DESCRIPTION="Country boundaries and maritime zones from OpenStreetMap"
 local COUNTRIES_SQL="SELECT country_id, country_name, country_name_en, geom AS geometry FROM public.countries ORDER BY country_name"
 if create_sql_view_layer "${COUNTRIES_LAYER_NAME}" "${COUNTRIES_SQL}" "${COUNTRIES_TITLE}" "${COUNTRIES_DESCRIPTION}" "geometry"; then
  # Extract actual style name from SLD
  local COUNTRIES_STYLE_NAME
  COUNTRIES_STYLE_NAME=$(extract_style_name_from_sld "${WMS_STYLE_COUNTRIES_FILE}")
  if [[ -z "${COUNTRIES_STYLE_NAME}" ]]; then
   COUNTRIES_STYLE_NAME="${WMS_STYLE_COUNTRIES_NAME}"
  fi
  assign_style_to_layer "${COUNTRIES_LAYER_NAME}" "${COUNTRIES_STYLE_NAME}"
 fi

# Create layer 4: Disputed and Unclaimed Areas (materialized view)
# Use materialized view directly instead of SQL view to avoid "Schema does not exist" error
print_status "${BLUE}" "📊 Creating layer 4/4: Disputed and Unclaimed Areas..."
local DISPUTED_LAYER_NAME="disputedareas"
local DISPUTED_TABLE_NAME="wms.disputed_and_unclaimed_areas"
if create_feature_type_from_table "${DISPUTED_LAYER_NAME}" "${DISPUTED_TABLE_NAME}" "${WMS_LAYER_DISPUTED_NAME}" "${WMS_LAYER_DISPUTED_DESCRIPTION}"; then
  # Extract actual style name from SLD
  local DISPUTED_STYLE_NAME
  DISPUTED_STYLE_NAME=$(extract_style_name_from_sld "${WMS_STYLE_DISPUTED_FILE}")
  if [[ -z "${DISPUTED_STYLE_NAME}" ]]; then
   DISPUTED_STYLE_NAME="${WMS_STYLE_DISPUTED_NAME}"
  fi
  assign_style_to_layer "${DISPUTED_LAYER_NAME}" "${DISPUTED_STYLE_NAME}"
 fi

 print_status "${GREEN}" "✅ GeoServer configuration completed successfully"
 show_configuration_summary
}

# Function to show configuration status
show_status() {
 print_status "${BLUE}" "📊 GeoServer Configuration Status"

 # Debug: Show credentials being used (without exposing password)
 print_status "${BLUE}" "🔐 Using credentials: User='${GEOSERVER_USER}', Password='${GEOSERVER_PASSWORD:+***}' (${#GEOSERVER_PASSWORD} chars)"
 print_status "${BLUE}" "🌐 GeoServer URL: ${GEOSERVER_URL}"

 # Check if GeoServer is accessible
 local STATUS_RESPONSE
 STATUS_RESPONSE=$(curl -s -w "\n%{http_code}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${GEOSERVER_URL}/rest/about/status" 2> /dev/null)
 local HTTP_CODE
 HTTP_CODE=$(echo "${STATUS_RESPONSE}" | tail -1)
 
 if [[ "${HTTP_CODE}" == "200" ]]; then
  print_status "${GREEN}" "✅ GeoServer is accessible at ${GEOSERVER_URL}"
 else
  print_status "${RED}" "❌ GeoServer is not accessible (HTTP ${HTTP_CODE})"
  print_status "${YELLOW}" "   Check: ${GEOSERVER_URL}/rest/about/status"
  if [[ "${HTTP_CODE}" == "401" ]]; then
   print_status "${YELLOW}" "   💡 Authentication failed - check credentials in etc/wms.properties.sh"
   print_status "${YELLOW}" "   💡 Or set: export GEOSERVER_USER=admin GEOSERVER_PASSWORD=your_password"
  fi
  return 1
 fi

 # Check workspace
 local WORKSPACE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}"
 local WORKSPACE_RESPONSE
 WORKSPACE_RESPONSE=$(curl -s -w "\n%{http_code}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${WORKSPACE_URL}" 2> /dev/null)
 HTTP_CODE=$(echo "${WORKSPACE_RESPONSE}" | tail -1)
 
 if [[ "${HTTP_CODE}" == "200" ]] && echo "${WORKSPACE_RESPONSE}" | grep -q "\"name\".*\"${GEOSERVER_WORKSPACE}\""; then
  print_status "${GREEN}" "✅ Workspace '${GEOSERVER_WORKSPACE}' exists"
 else
  print_status "${YELLOW}" "⚠️  Workspace '${GEOSERVER_WORKSPACE}' not found (HTTP ${HTTP_CODE})"
  print_status "${YELLOW}" "   URL: ${WORKSPACE_URL}"
  print_status "${YELLOW}" "   List all workspaces: ${GEOSERVER_URL}/rest/workspaces.xml"
 fi

 # Check namespace
 local NAMESPACE_URL="${GEOSERVER_URL}/rest/namespaces/${GEOSERVER_WORKSPACE}"
 local NAMESPACE_RESPONSE
 NAMESPACE_RESPONSE=$(curl -s -w "\n%{http_code}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${NAMESPACE_URL}" 2> /dev/null)
 HTTP_CODE=$(echo "${NAMESPACE_RESPONSE}" | tail -1)
 
 if [[ "${HTTP_CODE}" == "200" ]] && echo "${NAMESPACE_RESPONSE}" | grep -q "\"prefix\".*\"${GEOSERVER_WORKSPACE}\""; then
  print_status "${GREEN}" "✅ Namespace '${GEOSERVER_WORKSPACE}' exists"
 else
  print_status "${YELLOW}" "⚠️  Namespace '${GEOSERVER_WORKSPACE}' not found (HTTP ${HTTP_CODE})"
 fi

 # Check datastore
 local DATASTORE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}"
 local DATASTORE_RESPONSE
 DATASTORE_RESPONSE=$(curl -s -w "\n%{http_code}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${DATASTORE_URL}" 2> /dev/null)
 HTTP_CODE=$(echo "${DATASTORE_RESPONSE}" | tail -1)
 
 if [[ "${HTTP_CODE}" == "200" ]] && echo "${DATASTORE_RESPONSE}" | grep -q "\"name\".*\"${GEOSERVER_STORE}\""; then
  print_status "${GREEN}" "✅ Datastore '${GEOSERVER_STORE}' exists"
 else
  print_status "${YELLOW}" "⚠️  Datastore '${GEOSERVER_STORE}' not found (HTTP ${HTTP_CODE})"
  print_status "${YELLOW}" "   URL: ${DATASTORE_URL}"
  print_status "${YELLOW}" "   List all datastores: ${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores.xml"
 fi

 # Check layers
 print_status "${BLUE}" ""
 print_status "${BLUE}" "📊 Checking layers..."
 local LAYERS=("opennotes" "closednotes" "countries" "disputedunclaimedareas")
 local LAYER_NAMES=("Open Notes" "Closed Notes" "Countries" "Disputed/Unclaimed Areas")
 local LAYER_COUNT=0
 for i in "${!LAYERS[@]}"; do
  local LAYER_NAME="${LAYERS[$i]}"
  local LAYER_DISPLAY="${LAYER_NAMES[$i]}"
  local LAYER_URL="${GEOSERVER_URL}/rest/layers/${GEOSERVER_WORKSPACE}:${LAYER_NAME}"
  local LAYER_RESPONSE
  LAYER_RESPONSE=$(curl -s -w "\n%{http_code}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${LAYER_URL}" 2> /dev/null)
  HTTP_CODE=$(echo "${LAYER_RESPONSE}" | tail -1)
  
  if [[ "${HTTP_CODE}" == "200" ]] && echo "${LAYER_RESPONSE}" | grep -q "\"name\".*\"${LAYER_NAME}\""; then
   print_status "${GREEN}" "✅ Layer '${LAYER_DISPLAY}' (${LAYER_NAME}) exists"
   ((LAYER_COUNT++))
  else
   print_status "${YELLOW}" "⚠️  Layer '${LAYER_DISPLAY}' (${LAYER_NAME}) not found (HTTP ${HTTP_CODE})"
  fi
 done

 if [[ ${LAYER_COUNT} -gt 0 ]]; then
  # Show WMS URL
  local WMS_URL="${GEOSERVER_URL}/wms"
  print_status "${BLUE}" ""
  print_status "${BLUE}" "🌐 WMS Service URL: ${WMS_URL}"
  print_status "${BLUE}" "📋 Available layers: ${LAYER_COUNT}/4"
 fi

 # Show web interface URLs
 print_status "${BLUE}" ""
 print_status "${BLUE}" "📱 GeoServer Web Interface:"
 print_status "${BLUE}" "   ${GEOSERVER_URL}/web"
 print_status "${BLUE}" "   Workspaces: ${GEOSERVER_URL}/web/?wicket:bookmarkablePage=:org.geoserver.web.data.workspace.WorkspacePage"
 print_status "${BLUE}" "   Stores: ${GEOSERVER_URL}/web/?wicket:bookmarkablePage=:org.geoserver.web.data.store.DataStoresPage"
 print_status "${BLUE}" "   Layers: ${GEOSERVER_URL}/web/?wicket:bookmarkablePage=:org.geoserver.web.data.layers.LayersPage"
 print_status "${BLUE}" "   Styles: ${GEOSERVER_URL}/web/?wicket:bookmarkablePage=:org.geoserver.web.data.style.StylesPage"
}

# Function to remove a layer
remove_layer() {
 local LAYER_NAME="${1}"

 # Remove layer
 local LAYER_URL="${GEOSERVER_URL}/rest/layers/${GEOSERVER_WORKSPACE}:${LAYER_NAME}"
 local HTTP_CODE
 HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X DELETE "${LAYER_URL}" 2> /dev/null)
 if [[ "${HTTP_CODE}" == "200" ]] || [[ "${HTTP_CODE}" == "204" ]]; then
  print_status "${GREEN}" "✅ Layer '${LAYER_NAME}' removed"
 elif [[ "${HTTP_CODE}" == "404" ]]; then
  print_status "${YELLOW}" "⚠️  Layer '${LAYER_NAME}' not found (already removed)"
 else
  print_status "${YELLOW}" "⚠️  Layer '${LAYER_NAME}' removal failed (HTTP ${HTTP_CODE})"
 fi

 # Remove feature type
 local FEATURE_TYPE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}/featuretypes/${LAYER_NAME}"
 HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X DELETE "${FEATURE_TYPE_URL}" 2> /dev/null)
 if [[ "${HTTP_CODE}" == "200" ]] || [[ "${HTTP_CODE}" == "204" ]]; then
  print_status "${GREEN}" "✅ Feature type '${LAYER_NAME}' removed"
 elif [[ "${HTTP_CODE}" == "404" ]]; then
  print_status "${YELLOW}" "⚠️  Feature type '${LAYER_NAME}' not found (already removed)"
 else
  print_status "${YELLOW}" "⚠️  Feature type '${LAYER_NAME}' removal failed (HTTP ${HTTP_CODE})"
 fi
}

# Function to remove GeoServer configuration
remove_geoserver_config() {
 print_status "${BLUE}" "🗑️  Removing GeoServer configuration..."

 if [[ "${DRY_RUN:-false}" == "true" ]]; then
  print_status "${YELLOW}" "DRY RUN: Would remove GeoServer configuration"
  return 0
 fi

 # Check if workspace exists first
 local WORKSPACE_CHECK_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}"
 local WORKSPACE_CHECK_CODE
 WORKSPACE_CHECK_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${WORKSPACE_CHECK_URL}" 2> /dev/null | tail -1)

 if [[ "${WORKSPACE_CHECK_CODE}" != "200" ]]; then
  print_status "${YELLOW}" "⚠️  Workspace '${GEOSERVER_WORKSPACE}' not found"
  print_status "${GREEN}" "✅ GeoServer configuration already removed (workspace does not exist)"
  return 0
 fi

 # Step 1: Remove all feature types first (they depend on datastore)
 # Check if datastore exists before trying to remove feature types
 local DATASTORE_CHECK_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}"
 local DATASTORE_EXISTS
 DATASTORE_EXISTS=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${DATASTORE_CHECK_URL}" 2> /dev/null | tail -1)

 if [[ "${DATASTORE_EXISTS}" == "200" ]]; then
  print_status "${BLUE}" "🗑️  Removing feature types..."
  local LAYERS=("notesopen" "notesclosed" "countries" "disputedareas")
  local REMOVED_COUNT=0
  for LAYER_NAME in "${LAYERS[@]}"; do
   local FEATURE_TYPE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}/featuretypes/${LAYER_NAME}"
   local HTTP_CODE
   HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X DELETE "${FEATURE_TYPE_URL}" 2> /dev/null)
   if [[ "${HTTP_CODE}" == "200" ]] || [[ "${HTTP_CODE}" == "204" ]]; then
    print_status "${GREEN}" "✅ Feature type '${LAYER_NAME}' removed"
    ((REMOVED_COUNT++))
   elif [[ "${HTTP_CODE}" != "404" ]]; then
    print_status "${YELLOW}" "⚠️  Feature type '${LAYER_NAME}' removal failed (HTTP ${HTTP_CODE})"
   fi
  done
  if [[ ${REMOVED_COUNT} -eq 0 ]]; then
   print_status "${YELLOW}" "   No feature types found to remove"
  fi
 else
  print_status "${YELLOW}" "⚠️  Datastore not found, skipping feature type removal"
 fi

 # Step 2: Remove all layers
 print_status "${BLUE}" "🗑️  Removing layers..."
 local LAYERS=("notesopen" "notesclosed" "countries" "disputedareas")
 local REMOVED_COUNT=0
 for LAYER_NAME in "${LAYERS[@]}"; do
  local LAYER_URL="${GEOSERVER_URL}/rest/layers/${GEOSERVER_WORKSPACE}:${LAYER_NAME}"
  local HTTP_CODE
  HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X DELETE "${LAYER_URL}" 2> /dev/null)
  if [[ "${HTTP_CODE}" == "200" ]] || [[ "${HTTP_CODE}" == "204" ]]; then
   print_status "${GREEN}" "✅ Layer '${LAYER_NAME}' removed"
   ((REMOVED_COUNT++))
  elif [[ "${HTTP_CODE}" != "404" ]]; then
   print_status "${YELLOW}" "⚠️  Layer '${LAYER_NAME}' removal failed (HTTP ${HTTP_CODE})"
  fi
 done
 if [[ ${REMOVED_COUNT} -eq 0 ]]; then
  print_status "${YELLOW}" "   No layers found to remove"
 fi

 # Step 3: Remove datastore (must be empty of feature types)
 # Check if datastore exists before attempting to remove
 local DATASTORE_CHECK_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}"
 local DATASTORE_CHECK_CODE
 DATASTORE_CHECK_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${DATASTORE_CHECK_URL}" 2> /dev/null | tail -1)

 if [[ "${DATASTORE_CHECK_CODE}" == "200" ]]; then
  print_status "${BLUE}" "🗑️  Removing datastore..."
  local DATASTORE_URL="${DATASTORE_CHECK_URL}"
  local TEMP_RESPONSE="${TMP_DIR}/datastore_delete_$$.tmp"
  local HTTP_CODE
  HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X DELETE "${DATASTORE_URL}" 2> /dev/null)
  local RESPONSE_BODY
  RESPONSE_BODY=$(cat "${TEMP_RESPONSE}" 2> /dev/null || echo "")
  rm -f "${TEMP_RESPONSE}" 2> /dev/null || true

  if [[ "${HTTP_CODE}" == "200" ]] || [[ "${HTTP_CODE}" == "204" ]]; then
   print_status "${GREEN}" "✅ Datastore removed"
  elif [[ "${HTTP_CODE}" == "404" ]]; then
   print_status "${YELLOW}" "⚠️  Datastore not found (already removed)"
  elif [[ "${HTTP_CODE}" == "403" ]]; then
   print_status "${YELLOW}" "⚠️  Datastore removal failed (HTTP 403 - Forbidden)"
   print_status "${YELLOW}" "   User '${GEOSERVER_USER}' may not have permission to delete datastores"
   print_status "${YELLOW}" "   Datastore may still have feature types - try removing them first"
   if [[ -n "${RESPONSE_BODY}" ]]; then
    print_status "${YELLOW}" "   Response: $(echo "${RESPONSE_BODY}" | head -3 | tr '\n' ' ')"
   fi
  elif [[ "${HTTP_CODE}" == "401" ]]; then
   print_status "${YELLOW}" "⚠️  Datastore removal failed (HTTP 401 - Authentication failed)"
   print_status "${YELLOW}" "   Check GeoServer credentials: ${GEOSERVER_USER}"
  else
   print_status "${YELLOW}" "⚠️  Datastore removal failed (HTTP ${HTTP_CODE})"
   if [[ -n "${RESPONSE_BODY}" ]]; then
    print_status "${YELLOW}" "   Response: $(echo "${RESPONSE_BODY}" | head -3 | tr '\n' ' ')"
   fi
  fi
 else
  print_status "${YELLOW}" "⚠️  Datastore not found (already removed or workspace was removed)"
 fi

 # Step 4: Remove namespace (before workspace, as namespace is linked to workspace)
 # Check if namespace exists before attempting to remove
 local NAMESPACE_CHECK_URL="${GEOSERVER_URL}/rest/namespaces/${GEOSERVER_WORKSPACE}"
 local NAMESPACE_CHECK_CODE
 NAMESPACE_CHECK_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${NAMESPACE_CHECK_URL}" 2> /dev/null | tail -1)

 if [[ "${NAMESPACE_CHECK_CODE}" == "200" ]]; then
  print_status "${BLUE}" "🗑️  Removing namespace..."
  local NAMESPACE_URL="${NAMESPACE_CHECK_URL}"
  local TEMP_RESPONSE="${TMP_DIR}/namespace_delete_$$.tmp"
  HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X DELETE "${NAMESPACE_URL}" 2> /dev/null)
  RESPONSE_BODY=$(cat "${TEMP_RESPONSE}" 2> /dev/null || echo "")
  rm -f "${TEMP_RESPONSE}" 2> /dev/null || true

  if [[ "${HTTP_CODE}" == "200" ]] || [[ "${HTTP_CODE}" == "204" ]]; then
   print_status "${GREEN}" "✅ Namespace removed"
  elif [[ "${HTTP_CODE}" == "404" ]]; then
   print_status "${YELLOW}" "⚠️  Namespace not found (already removed)"
  elif [[ "${HTTP_CODE}" == "401" ]]; then
   print_status "${YELLOW}" "⚠️  Namespace removal failed (HTTP 401 - Authentication failed)"
   print_status "${YELLOW}" "   Check GeoServer credentials: ${GEOSERVER_USER}"
  elif [[ "${HTTP_CODE}" == "403" ]]; then
   print_status "${YELLOW}" "⚠️  Namespace removal failed (HTTP 403 - Forbidden)"
   print_status "${YELLOW}" "   User '${GEOSERVER_USER}' may not have permission to delete namespaces"
   print_status "${YELLOW}" "   Namespace may be linked to workspace - will be removed with workspace"
   print_status "${YELLOW}" "   You may need to remove it manually from GeoServer UI or use admin user"
  else
   print_status "${YELLOW}" "⚠️  Namespace removal failed (HTTP ${HTTP_CODE})"
   if [[ -n "${RESPONSE_BODY}" ]]; then
    print_status "${YELLOW}" "   Response: $(echo "${RESPONSE_BODY}" | head -3 | tr '\n' ' ')"
   fi
  fi
 else
  print_status "${YELLOW}" "⚠️  Namespace not found (already removed or workspace was removed)"
 fi

 # Step 5: Remove workspace (this will also remove linked namespace if permissions allow)
 print_status "${BLUE}" "🗑️  Removing workspace..."
 local WORKSPACE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}?recurse=true"
 local TEMP_RESPONSE="${TMP_DIR}/workspace_delete_$$.tmp"
 HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X DELETE "${WORKSPACE_URL}" 2> /dev/null)
 RESPONSE_BODY=$(cat "${TEMP_RESPONSE}" 2> /dev/null || echo "")
 rm -f "${TEMP_RESPONSE}" 2> /dev/null || true

 if [[ "${HTTP_CODE}" == "200" ]] || [[ "${HTTP_CODE}" == "204" ]]; then
  print_status "${GREEN}" "✅ Workspace removed (with recurse=true, this also removes linked resources)"
 elif [[ "${HTTP_CODE}" == "404" ]]; then
  print_status "${YELLOW}" "⚠️  Workspace not found (already removed)"
 elif [[ "${HTTP_CODE}" == "401" ]]; then
  print_status "${YELLOW}" "⚠️  Workspace removal failed (HTTP 401 - Authentication failed)"
  print_status "${YELLOW}" "   Check GeoServer credentials: ${GEOSERVER_USER}"
 elif [[ "${HTTP_CODE}" == "403" ]]; then
  print_status "${YELLOW}" "⚠️  Workspace removal failed (HTTP 403 - Forbidden)"
  print_status "${YELLOW}" "   User '${GEOSERVER_USER}' may not have permission to delete workspaces"
  print_status "${YELLOW}" "   Workspace may still have layers/datastores - ensure they are removed first"
  print_status "${YELLOW}" "   You may need to remove it manually from GeoServer UI or use admin user"
  if [[ -n "${RESPONSE_BODY}" ]]; then
   print_status "${YELLOW}" "   Response: $(echo "${RESPONSE_BODY}" | head -5 | tr '\n' ' ')"
  fi
 else
  print_status "${YELLOW}" "⚠️  Workspace removal failed (HTTP ${HTTP_CODE})"
  if [[ -n "${RESPONSE_BODY}" ]]; then
   print_status "${YELLOW}" "   Response: $(echo "${RESPONSE_BODY}" | head -5 | tr '\n' ' ')"
  fi
 fi

 print_status "${GREEN}" "✅ GeoServer configuration removal completed"
}

# Function to show configuration summary
 show_configuration_summary() {
 print_status "${BLUE}" "📋 Configuration Summary:"
 print_status "${BLUE}" "   - Workspace: ${GEOSERVER_WORKSPACE}"
 print_status "${BLUE}" "   - Datastore: ${GEOSERVER_STORE}"
 print_status "${BLUE}" "   - Database: ${DBHOST}:${DBPORT}/${DBNAME}"
 print_status "${BLUE}" "   - Schemas: wms, public (specified in SQL views)"
 print_status "${BLUE}" "   - WMS URL: ${GEOSERVER_URL}/wms"
 print_status "${BLUE}" ""
 print_status "${BLUE}" "📊 Layers created:"
 print_status "${BLUE}" "   1. ${GEOSERVER_WORKSPACE}:notesopen (Open Notes)"
 print_status "${BLUE}" "   2. ${GEOSERVER_WORKSPACE}:notesclosed (Closed Notes)"
 print_status "${BLUE}" "   3. ${GEOSERVER_WORKSPACE}:countries (Countries)"
 print_status "${BLUE}" "   4. ${GEOSERVER_WORKSPACE}:disputedareas (Disputed/Unclaimed Areas)"
}

# Function to parse command line arguments
parse_arguments() {
 FORCE="false"
 DRY_RUN="false"
 VERBOSE="false"

 while [[ $# -gt 0 ]]; do
  case $1 in
  --force)
   FORCE="true"
   shift
   ;;
  --dry-run)
   DRY_RUN="true"
   shift
   ;;
  --verbose)
   VERBOSE="true"
   shift
   ;;
  --geoserver-home)
   GEOSERVER_HOME="$2"
   shift 2
   ;;
  --geoserver-url)
   GEOSERVER_URL="$2"
   shift 2
   ;;
  --geoserver-user)
   GEOSERVER_USER="$2"
   shift 2
   ;;
  --geoserver-pass)
   GEOSERVER_PASSWORD="$2"
   shift 2
   ;;
  --help | -h)
   show_help
   exit 0
   ;;
  *)
   COMMAND="$1"
   shift
   ;;
  esac
 done
}

# Main function
main() {
 # Parse command line arguments
 parse_arguments "$@"

 # Set log level based on verbose flag
 if [[ "${VERBOSE}" == "true" ]]; then
  export LOG_LEVEL="DEBUG"
 fi

 case "${COMMAND:-}" in
 install)
  validate_prerequisites
  install_geoserver_config
  ;;
 status)
  show_status
  ;;
 remove)
  remove_geoserver_config
  ;;
 help)
  show_help
  ;;
 *)
  print_status "${RED}" "❌ ERROR: Unknown command '${COMMAND:-}'"
  print_status "${YELLOW}" "💡 Use '$0 help' for usage information"
  exit 1
  ;;
 esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 main "$@"
fi
