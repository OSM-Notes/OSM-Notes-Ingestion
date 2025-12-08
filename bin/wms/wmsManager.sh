#!/bin/bash
# WMS Manager Script
# Manages the installation and removal of WMS components
#
# This is the list of error codes:
# 1) Help message displayed
# 241) Library or utility missing
# 242) Invalid argument
# 255) General error
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-08

set -euo pipefail

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Set required variables for functionsProcess.sh
export BASENAME="wmsManager"
export TMP_DIR="/tmp"
export LOG_LEVEL="INFO"

# Set PostgreSQL application name for monitoring
# This allows monitoring tools to identify which script is using the database
export PGAPPNAME="${BASENAME}"

# Load properties (use same DB connection as rest of project)
if [[ -f "${PROJECT_ROOT}/etc/properties.sh" ]]; then
 source "${PROJECT_ROOT}/etc/properties.sh"
fi

# Load common functions to get error codes
if [[ -f "${PROJECT_ROOT}/lib/osm-common/commonFunctions.sh" ]]; then
 source "${PROJECT_ROOT}/lib/osm-common/commonFunctions.sh"
fi

# Load WMS specific properties only if not in test mode (for WMS-specific config, not DB connection)
if [[ -z "${TEST_DBNAME:-}" ]] && [[ -f "${PROJECT_ROOT}/etc/wms.properties.sh" ]]; then
 source "${PROJECT_ROOT}/etc/wms.properties.sh"
fi

# Set database variables with priority: WMS_* > DBNAME/DB_USER (from properties.sh) > TEST_* > default
# Use same DB connection variables as rest of project for consistency
# NOTE: wmsManager.sh requires elevated privileges (CREATE, ALTER, etc.)
#       It should use the system user (notes) or DB_USER, NOT the geoserver user
#       If WMS_DBUSER is set to 'geoserver', ignore it and use system user (peer auth)
WMS_DB_NAME="${WMS_DBNAME:-${DBNAME:-${TEST_DBNAME:-notes}}}"
# For wmsManager.sh, always use system user (peer auth) or DB_USER, never geoserver
if [[ "${WMS_DBUSER:-}" == "geoserver" ]]; then
 # Ignore geoserver user for installation - use system user instead
 WMS_DB_USER="${DB_USER:-${TEST_DBUSER:-}}"
else
 WMS_DB_USER="${WMS_DBUSER:-${DB_USER:-${TEST_DBUSER:-}}}"
fi
WMS_DB_PASSWORD="${WMS_DBPASSWORD:-${DB_PASSWORD:-${TEST_DBPASSWORD:-}}}"
WMS_DB_HOST="${WMS_DBHOST:-${DB_HOST:-${TEST_DBHOST:-}}}"
WMS_DB_PORT="${WMS_DBPORT:-${DB_PORT:-${TEST_DBPORT:-}}}"

# Export for psql commands
export WMS_DB_NAME WMS_DB_USER WMS_DB_PASSWORD WMS_DB_HOST WMS_DB_PORT
# Only set PGPASSWORD if password is provided (for peer auth, don't set it)
if [[ -n "${WMS_DB_PASSWORD}" ]]; then
 export PGPASSWORD="${WMS_DB_PASSWORD}"
else
 unset PGPASSWORD 2> /dev/null || true
fi

# WMS specific variables (using properties)
WMS_SQL_DIR="${PROJECT_ROOT}/sql/wms"
WMS_PREPARE_SQL="${WMS_SQL_DIR}/prepareDatabase.sql"
WMS_REMOVE_SQL="${WMS_SQL_DIR}/removeFromDatabase.sql"

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
WMS Manager Script

Usage: $0 [COMMAND] [OPTIONS]

COMMANDS:
  install     Install WMS components in the database
  remove      Remove WMS components from the database
  status      Check the status of WMS installation
  help        Show this help message

OPTIONS:
  --force     Force installation even if already installed
  --dry-run   Show what would be done without executing
  --verbose   Show detailed output

EXAMPLES:
  $0 install              # Install WMS components
  $0 remove               # Remove WMS components
  $0 status               # Check installation status
  $0 install --force      # Force reinstallation
  $0 install --dry-run    # Show what would be installed

ENVIRONMENT VARIABLES:
  Database connection (uses same variables as rest of project):
  DBNAME         Database name (from etc/properties.sh, default: notes)
  DB_USER        Database user (from etc/properties.sh, empty for peer auth)
  
  Note: wmsManager.sh requires elevated privileges (CREATE, ALTER, etc.)
        It uses the system user (notes) via peer authentication, NOT geoserver
    DB_PASSWORD    Database password (from etc/properties.sh)
    DB_HOST        Database host (from etc/properties.sh, empty for peer auth)
    DB_PORT        Database port (from etc/properties.sh, empty for default)
  
  WMS-specific overrides (optional, only if different from main config):
    WMS_DBNAME     Override database name
    WMS_DBUSER     Override database user
    WMS_DBPASSWORD Override database password
    WMS_DBHOST     Override database host
    WMS_DBPORT     Override database port
  
  For peer authentication (local connections), leave DB_USER, DB_HOST, and
  DB_PORT empty or unset in etc/properties.sh. The script will use the current
  system user.

EOF
}

# Function to validate prerequisites
validate_prerequisites() {
 # Check if required SQL files exist
 if [[ ! -f "${WMS_PREPARE_SQL}" ]]; then
  print_status "${RED}" "❌ ERROR: WMS prepare SQL file not found: ${WMS_PREPARE_SQL}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 if [[ ! -r "${WMS_PREPARE_SQL}" ]]; then
  print_status "${RED}" "❌ ERROR: WMS prepare SQL file is not readable: ${WMS_PREPARE_SQL}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 if [[ ! -f "${WMS_REMOVE_SQL}" ]]; then
  print_status "${RED}" "❌ ERROR: WMS remove SQL file not found: ${WMS_REMOVE_SQL}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 if [[ ! -r "${WMS_REMOVE_SQL}" ]]; then
  print_status "${RED}" "❌ ERROR: WMS remove SQL file is not readable: ${WMS_REMOVE_SQL}"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 # Check database connection and PostGIS
 # Use peer authentication if no host/user specified, otherwise use explicit user
 local PSQL_CMD="psql -d \"${WMS_DB_NAME}\""
 if [[ -n "${WMS_DB_HOST}" ]] || [[ -n "${WMS_DB_USER}" ]]; then
  # Remote connection or explicit user - need to specify user
  if [[ -n "${WMS_DB_HOST}" ]]; then
   PSQL_CMD="psql -h \"${WMS_DB_HOST}\" -d \"${WMS_DB_NAME}\""
  else
   PSQL_CMD="psql -d \"${WMS_DB_NAME}\""
  fi
  if [[ -n "${WMS_DB_USER}" ]]; then
   PSQL_CMD="${PSQL_CMD} -U \"${WMS_DB_USER}\""
  fi
 fi
 if [[ -n "${WMS_DB_PORT}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p \"${WMS_DB_PORT}\""
 fi

 # Test database connection first
 if ! eval "${PSQL_CMD} -c \"SELECT 1;\"" &> /dev/null; then
  print_status "${RED}" "❌ ERROR: Cannot connect to database: ${WMS_DB_NAME}@${WMS_DB_HOST:-localhost}:${WMS_DB_PORT:-5432}"
  exit "${ERROR_GENERAL}"
 fi

 if ! eval "${PSQL_CMD} -c \"SELECT PostGIS_Version();\"" &> /dev/null; then
  print_status "${RED}" "❌ ERROR: PostGIS extension is not installed or not accessible"
  exit "${ERROR_MISSING_LIBRARY}"
 fi

 print_status "${GREEN}" "✅ Prerequisites validated"
}

# Function to check if WMS is installed
is_wms_installed() {
 # Use peer authentication if no host/user specified, otherwise use explicit user
 local PSQL_CMD="psql -d \"${WMS_DB_NAME}\""
 if [[ -n "${WMS_DB_HOST}" ]] || [[ -n "${WMS_DB_USER}" ]]; then
  # Remote connection or explicit user - need to specify user
  if [[ -n "${WMS_DB_HOST}" ]]; then
   PSQL_CMD="psql -h \"${WMS_DB_HOST}\" -d \"${WMS_DB_NAME}\""
  else
   PSQL_CMD="psql -d \"${WMS_DB_NAME}\""
  fi
  if [[ -n "${WMS_DB_USER}" ]]; then
   PSQL_CMD="${PSQL_CMD} -U \"${WMS_DB_USER}\""
  fi
 fi
 if [[ -n "${WMS_DB_PORT}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p \"${WMS_DB_PORT}\""
 fi

 # Test database connection first
 if ! eval "${PSQL_CMD} -c \"SELECT 1;\"" &> /dev/null; then
  return 1
 fi

 # Check if WMS schema exists
 local SCHEMA_EXISTS
 SCHEMA_EXISTS=$(eval "${PSQL_CMD} -t -c \"SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'wms');\"" 2> /dev/null | tr -d ' ' || echo "f")

 if [[ "${SCHEMA_EXISTS}" != "t" ]]; then
  return 1
 fi

 # Check if main WMS table exists (more reliable check)
 local TABLE_EXISTS
 TABLE_EXISTS=$(eval "${PSQL_CMD} -t -c \"SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'wms' AND table_name = 'notes_wms');\"" 2> /dev/null | tr -d ' ' || echo "f")

 if [[ "${TABLE_EXISTS}" == "t" ]]; then
  return 0
 else
  return 1
 fi
}

# Function to install WMS
install_wms() {
 print_status "${BLUE}" "🚀 Installing WMS components..."

 # Check if WMS is already installed
 if is_wms_installed; then
  if [[ "${FORCE}" != "true" ]]; then
   print_status "${YELLOW}" "⚠️  WMS is already installed. Use --force to reinstall."
   return 0
  fi
 fi

 if [[ "${DRY_RUN}" == "true" ]]; then
  print_status "${YELLOW}" "DRY RUN: Would install WMS components"
  return 0
 fi

 # Build psql command
 # Use peer authentication if no host/user specified, otherwise use explicit user
 local PSQL_CMD="psql -d \"${WMS_DB_NAME}\""
 if [[ -n "${WMS_DB_HOST}" ]] || [[ -n "${WMS_DB_USER}" ]]; then
  # Remote connection or explicit user - need to specify user
  if [[ -n "${WMS_DB_HOST}" ]]; then
   PSQL_CMD="psql -h \"${WMS_DB_HOST}\" -d \"${WMS_DB_NAME}\""
  else
   PSQL_CMD="psql -d \"${WMS_DB_NAME}\""
  fi
  if [[ -n "${WMS_DB_USER}" ]]; then
   PSQL_CMD="${PSQL_CMD} -U \"${WMS_DB_USER}\""
  fi
 fi
 if [[ -n "${WMS_DB_PORT}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p \"${WMS_DB_PORT}\""
 fi

 # Execute installation SQL
 if eval "${PSQL_CMD} -f \"${WMS_PREPARE_SQL}\""; then
  print_status "${GREEN}" "✅ WMS installation completed successfully"
  show_installation_summary
 else
  print_status "${RED}" "❌ ERROR: WMS installation failed"
  exit "${ERROR_GENERAL}"
 fi
}

# Function to remove WMS
# Alias: deinstall_wms() for backward compatibility
remove_wms() {
 print_status "${BLUE}" "🗑️  Removing WMS components..."

 # Check if WMS is installed
 if ! is_wms_installed; then
  print_status "${YELLOW}" "⚠️  WMS is not installed"
  return 0
 fi

 if [[ "${DRY_RUN}" == "true" ]]; then
  print_status "${YELLOW}" "DRY RUN: Would remove WMS components"
  return 0
 fi

 # Build psql command
 # Use peer authentication if no host/user specified, otherwise use explicit user
 local PSQL_CMD="psql -d \"${WMS_DB_NAME}\""
 if [[ -n "${WMS_DB_HOST}" ]] || [[ -n "${WMS_DB_USER}" ]]; then
  # Remote connection or explicit user - need to specify user
  if [[ -n "${WMS_DB_HOST}" ]]; then
   PSQL_CMD="psql -h \"${WMS_DB_HOST}\" -d \"${WMS_DB_NAME}\""
  else
   PSQL_CMD="psql -d \"${WMS_DB_NAME}\""
  fi
  if [[ -n "${WMS_DB_USER}" ]]; then
   PSQL_CMD="${PSQL_CMD} -U \"${WMS_DB_USER}\""
  fi
 fi
 if [[ -n "${WMS_DB_PORT}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p \"${WMS_DB_PORT}\""
 fi

 # Execute removal SQL
 if eval "${PSQL_CMD} -f \"${WMS_REMOVE_SQL}\""; then
  print_status "${GREEN}" "✅ WMS removal completed successfully"
 else
  print_status "${RED}" "❌ ERROR: WMS removal failed"
  exit "${ERROR_GENERAL}"
 fi
}

# Function to show WMS status
show_status() {
 print_status "${BLUE}" "📊 WMS Status Report"

 if is_wms_installed; then
  print_status "${GREEN}" "✅ WMS is installed"

  # Build psql command
  # Use peer authentication if no host/user specified, otherwise use explicit user
  local PSQL_CMD="psql -d \"${WMS_DB_NAME}\""
  if [[ -n "${WMS_DB_HOST}" ]] || [[ -n "${WMS_DB_USER}" ]]; then
   # Remote connection or explicit user - need to specify user
   if [[ -n "${WMS_DB_HOST}" ]]; then
    PSQL_CMD="psql -h \"${WMS_DB_HOST}\" -d \"${WMS_DB_NAME}\""
   else
    PSQL_CMD="psql -d \"${WMS_DB_NAME}\""
   fi
   if [[ -n "${WMS_DB_USER}" ]]; then
    PSQL_CMD="${PSQL_CMD} -U \"${WMS_DB_USER}\""
   fi
  fi
  if [[ -n "${WMS_DB_PORT}" ]]; then
   PSQL_CMD="${PSQL_CMD} -p \"${WMS_DB_PORT}\""
  fi

  # Show basic statistics (check if table exists first)
  local TABLE_EXISTS
  TABLE_EXISTS=$(eval "${PSQL_CMD} -t -c \"SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_schema = 'wms' AND table_name = 'notes_wms');\"" 2> /dev/null | tr -d ' ' || echo "f")

  if [[ "${TABLE_EXISTS}" == "t" ]]; then
   local NOTE_COUNT
   NOTE_COUNT=$(eval "${PSQL_CMD} -t -c \"SELECT COUNT(*) FROM wms.notes_wms;\"" 2> /dev/null | tr -d ' ' || echo "0")

   print_status "${BLUE}" "📈 WMS Statistics:"
   print_status "${BLUE}" "   - Total notes in WMS: ${NOTE_COUNT}"

   # Show trigger information
   local TRIGGER_COUNT
   TRIGGER_COUNT=$(eval "${PSQL_CMD} -t -c \"SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_name IN ('insert_new_notes', 'update_notes');\"" 2> /dev/null | tr -d ' ' || echo "0")

   print_status "${BLUE}" "   - Active triggers: ${TRIGGER_COUNT}"

   # Check for materialized view
   local MATVIEW_EXISTS
   MATVIEW_EXISTS=$(eval "${PSQL_CMD} -t -c \"SELECT EXISTS(SELECT 1 FROM pg_matviews WHERE schemaname = 'wms' AND matviewname = 'disputed_and_unclaimed_areas');\"" 2> /dev/null | tr -d ' ' || echo "f")
   if [[ "${MATVIEW_EXISTS}" == "t" ]]; then
    local AREAS_COUNT
    AREAS_COUNT=$(eval "${PSQL_CMD} -t -c \"SELECT COUNT(*) FROM wms.disputed_and_unclaimed_areas;\"" 2> /dev/null | tr -d ' ' || echo "0")
    print_status "${BLUE}" "   - Disputed/unclaimed areas: ${AREAS_COUNT}"
   fi
  else
   print_status "${YELLOW}" "⚠️  WMS schema exists but main table (wms.notes_wms) is missing"
   print_status "${YELLOW}" "   Run 'wmsManager.sh install' to complete the installation"
  fi

 else
  print_status "${YELLOW}" "⚠️  WMS is not installed"
 fi
}

# Function to show installation summary
show_installation_summary() {
 print_status "${BLUE}" "📋 Installation Summary:"
 print_status "${BLUE}" "   - Schema 'wms' created"
 print_status "${BLUE}" "   - Table 'wms.notes_wms' created"
 print_status "${BLUE}" "   - Indexes created for performance"
 print_status "${BLUE}" "   - Triggers configured for synchronization"
 print_status "${BLUE}" "   - Functions created for data management"
}

# Main function
main() {
 # Enable bash debug mode if BASH_DEBUG environment variable is set
 if [[ "${BASH_DEBUG:-}" == "true" ]] || [[ "${BASH_DEBUG:-}" == "1" ]]; then
  set -xv
 fi

 # Parse command line arguments
 local COMMAND=""
 local FORCE=false
 local DRY_RUN=false
 local VERBOSE=false

 while [[ $# -gt 0 ]]; do
  case $1 in
  install | remove | deinstall | status | help)
   COMMAND="$1"
   shift
   ;;
  --force)
   FORCE=true
   shift
   ;;
  --dry-run)
   DRY_RUN=true
   shift
   ;;
  --verbose)
   VERBOSE=true
   shift
   ;;
  -h | --help)
   show_help
   exit 0
   ;;
  *)
   print_status "${RED}" "❌ ERROR: Unknown option: $1"
   show_help
   exit "${ERROR_INVALID_ARGUMENT}"
   ;;
  esac
 done

 # Set log level based on verbose flag
 if [[ "${VERBOSE}" == "true" ]]; then
  export LOG_LEVEL="DEBUG"
 fi

 # Execute command
 case "${COMMAND}" in
 install | remove | status)
  # Validate prerequisites only for commands that need database access
  validate_prerequisites

  case "${COMMAND}" in
  install)
   install_wms
   ;;
  remove)
   remove_wms
   ;;
  status)
   show_status
   ;;
  *)
   print_status "${RED}" "❌ ERROR: Unknown subcommand: ${COMMAND}"
   exit "${ERROR_INVALID_ARGUMENT}"
   ;;
  esac
  ;;
 help)
  show_help
  ;;
 "")
  print_status "${RED}" "❌ ERROR: No command specified"
  show_help
  exit "${ERROR_INVALID_ARGUMENT}"
  ;;
 *)
  print_status "${RED}" "❌ ERROR: Unknown command: ${COMMAND}"
  show_help
  exit "${ERROR_INVALID_ARGUMENT}"
  ;;
 esac
}

# Execute main function with all arguments
if [[ "${SKIP_MAIN:-}" != "true" ]]; then
 main "$@"
fi
