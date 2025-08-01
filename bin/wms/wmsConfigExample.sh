#!/bin/bash
# WMS Configuration Example Script
# Shows how to use WMS properties for customization
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

set -euo pipefail

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Load WMS properties
if [[ -f "${PROJECT_ROOT}/etc/wms.properties.sh" ]]; then
 source "${PROJECT_ROOT}/etc/wms.properties.sh"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
 local COLOR="$1"
 local MESSAGE="$2"
 echo -e "${COLOR}${MESSAGE}${NC}"
}

# Function to show help
show_help() {
 cat << EOF
WMS Configuration Example Script

Usage: $0 [COMMAND] [OPTIONS]

COMMANDS:
  show-config     Show current WMS configuration
  validate        Validate WMS properties
  test-connection Test database and GeoServer connections
  customize       Show customization examples
  help            Show this help message

EXAMPLES:
  $0 show-config              # Show current configuration
  $0 validate                 # Validate properties
  $0 test-connection         # Test connections
  $0 customize               # Show customization examples

EOF
}

# Function to show current configuration
show_current_config() {
 print_status "${BLUE}" "📋 Current WMS Configuration:"
 echo ""
 print_status "${GREEN}" "Database Configuration:"
 echo "  Host: ${WMS_DBHOST}"
 echo "  Port: ${WMS_DBPORT}"
 echo "  Database: ${WMS_DBNAME}"
 echo "  User: ${WMS_DBUSER}"
 echo "  Schema: ${WMS_SCHEMA}"
 echo "  Table: ${WMS_TABLE}"
 echo ""
 print_status "${GREEN}" "GeoServer Configuration:"
 echo "  URL: ${GEOSERVER_URL}"
 echo "  User: ${GEOSERVER_USER}"
 echo "  Workspace: ${GEOSERVER_WORKSPACE}"
 echo "  Store: ${GEOSERVER_STORE}"
 echo "  Layer: ${GEOSERVER_LAYER}"
 echo ""
 print_status "${GREEN}" "WMS Service Configuration:"
 echo "  Title: ${WMS_SERVICE_TITLE}"
 echo "  Description: ${WMS_SERVICE_DESCRIPTION}"
 echo "  SRS: ${WMS_LAYER_SRS}"
 echo "  BBox: ${WMS_BBOX_MINX},${WMS_BBOX_MINY} to ${WMS_BBOX_MAXX},${WMS_BBOX_MAXY}"
 echo ""
 print_status "${GREEN}" "Style Configuration:"
 echo "  Style Name: ${WMS_STYLE_NAME}"
 echo "  Style File: ${WMS_STYLE_FILE}"
 echo "  Fallback: ${WMS_STYLE_FALLBACK}"
 echo ""
 print_status "${GREEN}" "Performance Configuration:"
 echo "  DB Pool Size: ${WMS_DB_POOL_SIZE}"
 echo "  Cache Enabled: ${WMS_CACHE_ENABLED}"
 echo "  Cache TTL: ${WMS_CACHE_TTL}s"
 echo ""
 print_status "${GREEN}" "Security Configuration:"
 echo "  Auth Enabled: ${WMS_AUTH_ENABLED}"
 echo "  CORS Enabled: ${WMS_CORS_ENABLED}"
 echo "  CORS Origin: ${WMS_CORS_ALLOW_ORIGIN}"
 echo ""
 print_status "${GREEN}" "Logging Configuration:"
 echo "  Log Level: ${WMS_LOG_LEVEL}"
 echo "  Log File: ${WMS_LOG_FILE}"
 echo "  Max Size: ${WMS_LOG_MAX_SIZE}"
 echo ""
 print_status "${GREEN}" "Development Configuration:"
 echo "  Dev Mode: ${WMS_DEV_MODE}"
 echo "  Debug Enabled: ${WMS_DEBUG_ENABLED}"
}

# Function to validate properties
validate_properties() {
 print_status "${BLUE}" "🔍 Validating WMS Properties..."

 local ERRORS=0

 # Call the validation function from wms.properties.sh
 if __validate_wms_properties; then
  print_status "${GREEN}" "✅ All WMS properties are valid"
 else
  print_status "${RED}" "❌ WMS properties validation failed"
  ERRORS=1
 fi

 # Additional validations
 if ! __validate_input_file "${WMS_STYLE_FILE}" "WMS style file"; then
  print_status "${YELLOW}" "⚠️  Style file validation failed: ${WMS_STYLE_FILE}"
  ((ERRORS++))
 fi

 if [[ "${WMS_BBOX_MINX}" -ge "${WMS_BBOX_MAXX}" ]]; then
  print_status "${RED}" "❌ Invalid bounding box: minx >= maxx"
  ((ERRORS++))
 fi

 if [[ "${WMS_BBOX_MINY}" -ge "${WMS_BBOX_MAXY}" ]]; then
  print_status "${RED}" "❌ Invalid bounding box: miny >= maxy"
  ((ERRORS++))
 fi

 if [[ "${WMS_DB_POOL_SIZE}" -lt 1 ]]; then
  print_status "${RED}" "❌ Invalid DB pool size: ${WMS_DB_POOL_SIZE}"
  ((ERRORS++))
 fi

 if [[ "${WMS_CACHE_TTL}" -lt 0 ]]; then
  print_status "${RED}" "❌ Invalid cache TTL: ${WMS_CACHE_TTL}"
  ((ERRORS++))
 fi

 if [[ $ERRORS -eq 0 ]]; then
  print_status "${GREEN}" "✅ All validations passed"
 else
  print_status "${RED}" "❌ Found $ERRORS validation errors"
  exit 1
 fi
}

# Function to test connections
test_connections() {
 print_status "${BLUE}" "🔗 Testing Connections..."

 # Test database connection
 print_status "${BLUE}" "Testing database connection..."
 if psql -h "${WMS_DBHOST}" -U "${WMS_DBUSER}" -d "${WMS_DBNAME}" -c "SELECT 1;" &> /dev/null; then
  print_status "${GREEN}" "✅ Database connection successful"
 else
  print_status "${RED}" "❌ Database connection failed"
  return 1
 fi

 # Test GeoServer connection
 print_status "${BLUE}" "Testing GeoServer connection..."
 if curl -s -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" "${GEOSERVER_URL}/rest/about/status" &> /dev/null; then
  print_status "${GREEN}" "✅ GeoServer connection successful"
 else
  print_status "${RED}" "❌ GeoServer connection failed"
  return 1
 fi

 # Test WMS schema
 print_status "${BLUE}" "Testing WMS schema..."
 if psql -h "${WMS_DBHOST}" -U "${WMS_DBUSER}" -d "${WMS_DBNAME}" -c "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = '${WMS_SCHEMA}');" | grep -q 't'; then
  print_status "${GREEN}" "✅ WMS schema exists"
 else
  print_status "${YELLOW}" "⚠️  WMS schema not found"
 fi

 print_status "${GREEN}" "✅ All connection tests completed"
}

# Function to show customization examples
show_customization_examples() {
 print_status "${BLUE}" "🎨 WMS Customization Examples:"
 echo ""
 print_status "${GREEN}" "1. Custom Database Configuration:"
 cat << 'EOF'
# Set in environment or export before running scripts
export WMS_DBNAME="my_osm_notes"
export WMS_DBUSER="myuser"
export WMS_DBPASSWORD="mypassword"
export WMS_DBHOST="my-db-server.com"
export WMS_DBPORT="5432"
EOF
 echo ""
 print_status "${GREEN}" "2. Custom GeoServer Configuration:"
 cat << 'EOF'
# Custom GeoServer settings
export GEOSERVER_URL="https://my-geoserver.com/geoserver"
export GEOSERVER_USER="admin"
export GEOSERVER_PASSWORD="secure_password"
export GEOSERVER_WORKSPACE="my_workspace"
export GEOSERVER_STORE="my_store"
export GEOSERVER_LAYER="my_layer"
EOF
 echo ""
 print_status "${GREEN}" "3. Custom WMS Service Configuration:"
 cat << 'EOF'
# Custom WMS service settings
export WMS_SERVICE_TITLE="My Custom OSM Notes Service"
export WMS_SERVICE_DESCRIPTION="Custom OpenStreetMap Notes WMS Service"
export WMS_LAYER_TITLE="My OSM Notes Layer"
export WMS_LAYER_DESCRIPTION="Custom OSM Notes for WMS"
export WMS_LAYER_SRS="EPSG:3857"
EOF
 echo ""
 print_status "${GREEN}" "4. Custom Bounding Box (Regional):"
 cat << 'EOF'
# Regional bounding box (example: Europe)
export WMS_BBOX_MINX="-10"
export WMS_BBOX_MAXX="40"
export WMS_BBOX_MINY="35"
export WMS_BBOX_MAXY="70"
EOF
 echo ""
 print_status "${GREEN}" "5. Custom Style Configuration:"
 cat << 'EOF'
# Custom style settings
export WMS_STYLE_NAME="my_custom_style"
export WMS_STYLE_FILE="/path/to/my/custom.sld"
export WMS_STYLE_FALLBACK="true"
EOF
 echo ""
 print_status "${GREEN}" "6. Performance Tuning:"
 cat << 'EOF'
# Performance settings
export WMS_DB_POOL_SIZE="20"
export WMS_CACHE_ENABLED="true"
export WMS_CACHE_TTL="7200"
export WMS_CACHE_MAX_SIZE="200"
EOF
 echo ""
 print_status "${GREEN}" "7. Security Configuration:"
 cat << 'EOF'
# Security settings
export WMS_AUTH_ENABLED="true"
export WMS_AUTH_USER="wms_user"
export WMS_AUTH_PASSWORD="wms_password"
export WMS_CORS_ENABLED="true"
export WMS_CORS_ALLOW_ORIGIN="https://myapp.com"
EOF
 echo ""
 print_status "${GREEN}" "8. Development Configuration:"
 cat << 'EOF'
# Development settings
export WMS_DEV_MODE="true"
export WMS_DEBUG_ENABLED="true"
export WMS_LOG_LEVEL="DEBUG"
export WMS_LOG_FILE="/tmp/wms_debug.log"
EOF
 echo ""
 print_status "${BLUE}" "💡 Usage Examples:"
 echo ""
 echo "1. Set custom properties and run WMS manager:"
 echo "   export WMS_DBNAME='custom_db' && ./bin/wms/wmsManager.sh install"
 echo ""
 echo "2. Set custom properties and configure GeoServer:"
 echo "   export GEOSERVER_URL='https://my-geoserver.com/geoserver' && ./bin/wms/geoserverConfig.sh install"
 echo ""
 echo "3. Create a custom configuration file:"
 echo "   cp etc/wms.properties.sh etc/wms.properties.custom.sh"
 echo "   # Edit the custom file with your settings"
 echo "   source etc/wms.properties.custom.sh"
 echo ""
}

# Function to parse command line arguments
parse_arguments() {
 while [[ $# -gt 0 ]]; do
  case $1 in
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

 case "${COMMAND:-}" in
 show-config)
  show_current_config
  ;;
 validate)
  validate_properties
  ;;
 test-connection)
  test_connections
  ;;
 customize)
  show_customization_examples
  ;;
 help)
  show_help
  ;;
 *)
  print_status "${RED}" "❌ ERROR: Unknown command '${COMMAND:-}'"
  print_status "${YELLOW}" "💡 Use '${0}' help' for usage information"
  exit 1
  ;;
 esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 main "$@"
fi
