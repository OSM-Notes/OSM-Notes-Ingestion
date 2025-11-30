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
  configure   Configure existing GeoServer installation
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
  $0 configure                  # Configure existing GeoServer
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
  fi
  print_status "${YELLOW}" "💡 Make sure GeoServer is running and credentials are correct"
  print_status "${YELLOW}" "💡 You can override the URL with: GEOSERVER_URL=http://host:port/geoserver"
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
  local TEMP_ERROR_FILE="${TMP_DIR}/psql_error_$$.tmp"
  if ! eval "${PSQL_CMD} -c \"SELECT 1;\" > /dev/null 2> \"${TEMP_ERROR_FILE}\""; then
   local ERROR_MSG
   ERROR_MSG=$(cat "${TEMP_ERROR_FILE}" 2> /dev/null | head -1 || echo "Unknown error")
   rm -f "${TEMP_ERROR_FILE}" 2> /dev/null || true
   
   print_status "${YELLOW}" "⚠️  WARNING: Cannot validate PostgreSQL connection to '${DBNAME}'"
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
  fi
  unset PGPASSWORD 2> /dev/null || true
 else
  print_status "${YELLOW}" "⚠️  Skipping PostgreSQL validation (no password provided)"
  print_status "${YELLOW}" "   GeoServer will validate the connection when creating the datastore"
 fi

 # Check if WMS schema exists (only if we can connect to PostgreSQL)
 if [[ -n "${DBPASSWORD}" ]]; then
  if ! eval "${PSQL_CMD} -c \"SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'wms');\"" | grep -q 't'; then
   print_status "${RED}" "❌ ERROR: WMS schema not found. Please install WMS components first:"
   print_status "${YELLOW}" "   bin/wms/wmsManager.sh install"
   exit 1
  fi
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
 
 # Only return true if both workspace and datastore exist
 if [[ "${WORKSPACE_EXISTS}" == "true" ]] && [[ "${DATASTORE_EXISTS}" == "true" ]]; then
  return 0
 else
  return 1
 fi
}

# Function to create workspace
create_workspace() {
 print_status "${BLUE}" "🏗️  Creating GeoServer workspace..."

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
 elif [[ "${HTTP_CODE}" == "409" ]]; then
  print_status "${YELLOW}" "⚠️  Workspace '${GEOSERVER_WORKSPACE}' already exists"
 else
  print_status "${RED}" "❌ ERROR: Failed to create workspace (HTTP ${HTTP_CODE})"
  if [[ -n "${RESPONSE_BODY}" ]]; then
   print_status "${YELLOW}" "   Response: ${RESPONSE_BODY}" | head -5
  fi
 fi

 rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
}

# Function to create namespace
create_namespace() {
 print_status "${BLUE}" "🏷️  Creating GeoServer namespace..."

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
 elif [[ "${HTTP_CODE}" == "409" ]]; then
  print_status "${YELLOW}" "⚠️  Namespace '${GEOSERVER_WORKSPACE}' already exists"
 else
  # Check if error message indicates it already exists (some GeoServer versions return 500 for this)
  if echo "${RESPONSE_BODY}" | grep -qi "already exists"; then
   print_status "${YELLOW}" "⚠️  Namespace '${GEOSERVER_WORKSPACE}' already exists"
  else
   print_status "${RED}" "❌ ERROR: Failed to create namespace (HTTP ${HTTP_CODE})"
   if [[ -n "${RESPONSE_BODY}" ]]; then
    print_status "${YELLOW}" "   Response:"
    echo "${RESPONSE_BODY}" | head -10 | sed 's/^/      /'
   fi
  fi
 fi

 rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
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
         {\"@key\": \"schema\", \"$\": \"${WMS_SCHEMA}\"},
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
  # Datastore exists, update it
  print_status "${BLUE}" "   Datastore exists, updating connection parameters..."
  DATASTORE_URL="${DATASTORE_CHECK_URL}"
  HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
   -X PUT \
   -H "Content-Type: application/json" \
   -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
   -d "${DATASTORE_DATA}" \
   "${DATASTORE_URL}" 2> /dev/null | tail -1)
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

# Function to create feature type
create_feature_type() {
 print_status "${BLUE}" "🗺️  Creating GeoServer feature type..."

 local FEATURE_TYPE_DATA="{
   \"featureType\": {
     \"name\": \"${GEOSERVER_LAYER}\",
     \"nativeName\": \"${WMS_TABLE}\",
     \"title\": \"${WMS_LAYER_TITLE}\",
     \"description\": \"${WMS_LAYER_DESCRIPTION}\",
     \"enabled\": true,
     \"srs\": \"${WMS_LAYER_SRS}\",
     \"nativeBoundingBox\": {
       \"minx\": ${WMS_BBOX_MINX},
       \"maxx\": ${WMS_BBOX_MAXX},
       \"miny\": ${WMS_BBOX_MINY},
       \"maxy\": ${WMS_BBOX_MAXY},
       \"crs\": \"${WMS_LAYER_SRS}\"
     },
     \"latLon\": {
       \"minx\": ${WMS_BBOX_MINX},
       \"maxx\": ${WMS_BBOX_MAXX},
       \"miny\": ${WMS_BBOX_MINY},
       \"maxy\": ${WMS_BBOX_MAXY},
       \"crs\": \"${WMS_LAYER_SRS}\"
     }
   }
 }"

 local FEATURE_TYPE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}/featuretypes"

 local TEMP_RESPONSE_FILE="${TMP_DIR}/featuretype_response_$$.tmp"
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
  print_status "${GREEN}" "✅ Feature type '${GEOSERVER_LAYER}' created"
 elif [[ "${HTTP_CODE}" == "409" ]]; then
  print_status "${YELLOW}" "⚠️  Feature type '${GEOSERVER_LAYER}' already exists"
 else
  print_status "${RED}" "❌ ERROR: Failed to create feature type (HTTP ${HTTP_CODE})"
  if [[ -n "${RESPONSE_BODY}" ]]; then
   print_status "${YELLOW}" "   Response:"
   echo "${RESPONSE_BODY}" | head -30 | sed 's/^/      /'
  else
   print_status "${YELLOW}" "   (No error message returned - check GeoServer logs)"
   print_status "${YELLOW}" "   Common causes:"
   print_status "${YELLOW}" "   - Table '${WMS_SCHEMA}.${WMS_TABLE}' does not exist"
   print_status "${YELLOW}" "   - User '${DBUSER}' lacks permissions"
   print_status "${YELLOW}" "   - Datastore cannot connect to PostgreSQL"
   print_status "${YELLOW}" "   - Check GeoServer logs: tail -f /opt/geoserver/logs/geoserver.log"
  fi
  rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
  return 1
 fi

 rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true
}

# Function to upload style
upload_style() {
 local SLD_FILE="${WMS_STYLE_FILE}"
 local STYLE_NAME="${WMS_STYLE_NAME}"

 # Validate SLD file using centralized validation
 if ! __validate_input_file "${SLD_FILE}" "SLD style file"; then
  print_status "${YELLOW}" "⚠️  SLD file validation failed: ${SLD_FILE}"
  return 0
 fi

 # Upload SLD file
 local TEMP_RESPONSE_FILE="${TMP_DIR}/style_response_$$.tmp"
 local HTTP_CODE
 HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_RESPONSE_FILE}" \
  -X POST \
  -H "Content-Type: application/vnd.ogc.sld+xml" \
  -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -d "@${SLD_FILE}" \
  "${GEOSERVER_URL}/rest/styles" 2> /dev/null | tail -1)

 local RESPONSE_BODY
 RESPONSE_BODY=$(cat "${TEMP_RESPONSE_FILE}" 2> /dev/null || echo "")

 local STYLE_UPLOADED=false
 if [[ "${HTTP_CODE}" == "201" ]] || [[ "${HTTP_CODE}" == "200" ]]; then
  print_status "${GREEN}" "✅ Style '${STYLE_NAME}' uploaded"
  STYLE_UPLOADED=true
 elif [[ "${HTTP_CODE}" == "409" ]]; then
  print_status "${YELLOW}" "⚠️  Style '${STYLE_NAME}' already exists"
  STYLE_UPLOADED=true
 else
  print_status "${YELLOW}" "⚠️  Style upload failed (HTTP ${HTTP_CODE})"
  if [[ -n "${RESPONSE_BODY}" ]]; then
   print_status "${YELLOW}" "   Error:"
   echo "${RESPONSE_BODY}" | head -10 | sed 's/^/      /'
  fi
 fi

 rm -f "${TEMP_RESPONSE_FILE}" 2> /dev/null || true

 # Assign style to layer (only if style was uploaded or already exists)
 if [[ "${STYLE_UPLOADED}" == "true" ]]; then
  local LAYER_STYLE_DATA="{
    \"layer\": {
      \"defaultStyle\": {
        \"name\": \"${STYLE_NAME}\"
      }
    }
  }"

  local TEMP_STYLE_ASSIGN_FILE="${TMP_DIR}/style_assign_response_$$.tmp"
  local ASSIGN_HTTP_CODE
  ASSIGN_HTTP_CODE=$(curl -s -w "%{http_code}" -o "${TEMP_STYLE_ASSIGN_FILE}" \
   -X PUT \
   -H "Content-Type: application/json" \
   -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
   -d "${LAYER_STYLE_DATA}" \
   "${GEOSERVER_URL}/rest/layers/${GEOSERVER_WORKSPACE}:${GEOSERVER_LAYER}" 2> /dev/null | tail -1)

  if [[ "${ASSIGN_HTTP_CODE}" == "200" ]] || [[ "${ASSIGN_HTTP_CODE}" == "204" ]]; then
   print_status "${GREEN}" "✅ Style assigned to layer"
  else
   print_status "${YELLOW}" "⚠️  Style assignment failed (HTTP ${ASSIGN_HTTP_CODE})"
   local ASSIGN_RESPONSE
   ASSIGN_RESPONSE=$(cat "${TEMP_STYLE_ASSIGN_FILE}" 2> /dev/null || echo "")
   if [[ -n "${ASSIGN_RESPONSE}" ]]; then
    print_status "${YELLOW}" "   Response:"
    echo "${ASSIGN_RESPONSE}" | head -5 | sed 's/^/      /'
   fi
  fi
  rm -f "${TEMP_STYLE_ASSIGN_FILE}" 2> /dev/null || true
 else
  print_status "${YELLOW}" "⚠️  Skipping style assignment (style upload failed)"
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

 # Create datastore and feature type
 if create_datastore; then
  if create_feature_type; then
   upload_style
   print_status "${GREEN}" "✅ GeoServer configuration completed successfully"
   show_configuration_summary
  else
   print_status "${RED}" "❌ ERROR: Failed to create feature type"
   print_status "${YELLOW}" "   Configuration is incomplete. Some components may have been created."
   exit 1
  fi
 else
  print_status "${RED}" "❌ ERROR: GeoServer configuration failed"
  exit 1
 fi
}

# Function to configure existing GeoServer
configure_geoserver() {
 print_status "${BLUE}" "⚙️  Configuring existing GeoServer installation..."

 validate_prerequisites
 install_geoserver_config
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

 # Check layer
 local LAYER_URL="${GEOSERVER_URL}/rest/layers/${GEOSERVER_WORKSPACE}:${GEOSERVER_LAYER}"
 local LAYER_RESPONSE
 LAYER_RESPONSE=$(curl -s -w "\n%{http_code}" -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${LAYER_URL}" 2> /dev/null)
 HTTP_CODE=$(echo "${LAYER_RESPONSE}" | tail -1)
 
 if [[ "${HTTP_CODE}" == "200" ]] && echo "${LAYER_RESPONSE}" | grep -q "\"name\".*\"${GEOSERVER_LAYER}\""; then
  print_status "${GREEN}" "✅ Layer '${GEOSERVER_LAYER}' exists"

  # Show WMS URL
  local WMS_URL="${GEOSERVER_URL}/wms"
  print_status "${BLUE}" "🌐 WMS Service URL: ${WMS_URL}"
  print_status "${BLUE}" "📋 Layer Name: ${GEOSERVER_WORKSPACE}:${GEOSERVER_LAYER}"
 else
  print_status "${YELLOW}" "⚠️  Layer '${GEOSERVER_LAYER}' not found (HTTP ${HTTP_CODE})"
  print_status "${YELLOW}" "   URL: ${LAYER_URL}"
  print_status "${YELLOW}" "   List all layers: ${GEOSERVER_URL}/rest/layers.xml"
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

# Function to remove GeoServer configuration
remove_geoserver_config() {
 print_status "${BLUE}" "🗑️  Removing GeoServer configuration..."

 if [[ "${DRY_RUN:-false}" == "true" ]]; then
  print_status "${YELLOW}" "DRY RUN: Would remove GeoServer configuration"
  return 0
 fi

 # Remove layer
 local LAYER_URL="${GEOSERVER_URL}/rest/layers/${GEOSERVER_WORKSPACE}:${GEOSERVER_LAYER}"
 local HTTP_CODE
 HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X DELETE "${LAYER_URL}" 2> /dev/null)
 if [[ "${HTTP_CODE}" == "200" ]] || [[ "${HTTP_CODE}" == "204" ]]; then
  print_status "${GREEN}" "✅ Layer removed"
 elif [[ "${HTTP_CODE}" == "404" ]]; then
  print_status "${YELLOW}" "⚠️  Layer not found (already removed)"
 else
  print_status "${YELLOW}" "⚠️  Layer removal failed (HTTP ${HTTP_CODE})"
 fi

 # Remove feature type
 local FEATURE_TYPE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}/featuretypes/${GEOSERVER_LAYER}"
 HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X DELETE "${FEATURE_TYPE_URL}" 2> /dev/null)
 if [[ "${HTTP_CODE}" == "200" ]] || [[ "${HTTP_CODE}" == "204" ]]; then
  print_status "${GREEN}" "✅ Feature type removed"
 elif [[ "${HTTP_CODE}" == "404" ]]; then
  print_status "${YELLOW}" "⚠️  Feature type not found (already removed)"
 else
  print_status "${YELLOW}" "⚠️  Feature type removal failed (HTTP ${HTTP_CODE})"
 fi

 # Remove datastore
 local DATASTORE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}/datastores/${GEOSERVER_STORE}"
 HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X DELETE "${DATASTORE_URL}" 2> /dev/null)
 if [[ "${HTTP_CODE}" == "200" ]] || [[ "${HTTP_CODE}" == "204" ]]; then
  print_status "${GREEN}" "✅ Datastore removed"
 elif [[ "${HTTP_CODE}" == "404" ]]; then
  print_status "${YELLOW}" "⚠️  Datastore not found (already removed)"
 else
  print_status "${YELLOW}" "⚠️  Datastore removal failed (HTTP ${HTTP_CODE})"
 fi

 # Remove namespace (before workspace, as namespace is linked to workspace)
 local NAMESPACE_URL="${GEOSERVER_URL}/rest/namespaces/${GEOSERVER_WORKSPACE}"
 HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X DELETE "${NAMESPACE_URL}" 2> /dev/null)
 if [[ "${HTTP_CODE}" == "200" ]] || [[ "${HTTP_CODE}" == "204" ]]; then
  print_status "${GREEN}" "✅ Namespace removed"
 elif [[ "${HTTP_CODE}" == "404" ]]; then
  print_status "${YELLOW}" "⚠️  Namespace not found (already removed)"
 else
  print_status "${YELLOW}" "⚠️  Namespace removal failed (HTTP ${HTTP_CODE})"
 fi

 # Remove workspace
 local WORKSPACE_URL="${GEOSERVER_URL}/rest/workspaces/${GEOSERVER_WORKSPACE}"
 HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" -X DELETE "${WORKSPACE_URL}" 2> /dev/null)
 if [[ "${HTTP_CODE}" == "200" ]] || [[ "${HTTP_CODE}" == "204" ]]; then
  print_status "${GREEN}" "✅ Workspace removed"
 elif [[ "${HTTP_CODE}" == "404" ]]; then
  print_status "${YELLOW}" "⚠️  Workspace not found (already removed)"
 else
  print_status "${YELLOW}" "⚠️  Workspace removal failed (HTTP ${HTTP_CODE})"
 fi

 print_status "${GREEN}" "✅ GeoServer configuration removal completed"
}

# Function to show configuration summary
show_configuration_summary() {
 print_status "${BLUE}" "📋 Configuration Summary:"
 print_status "${BLUE}" "   - Workspace: ${GEOSERVER_WORKSPACE}"
 print_status "${BLUE}" "   - Datastore: ${GEOSERVER_STORE}"
 print_status "${BLUE}" "   - Layer: ${GEOSERVER_LAYER}"
 print_status "${BLUE}" "   - Database: ${DBHOST}:${DBPORT}/${DBNAME}"
 print_status "${BLUE}" "   - Schema: wms"
 print_status "${BLUE}" "   - WMS URL: ${GEOSERVER_URL}/wms"
 print_status "${BLUE}" "   - Layer Name: ${GEOSERVER_WORKSPACE}:${GEOSERVER_LAYER}"
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
 configure)
  configure_geoserver
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
