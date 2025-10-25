#!/bin/bash
# WMS Manager Script
# Manages the installation and deinstallation of WMS components
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-24

set -euo pipefail

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Set required variables for functionsProcess.sh
export BASENAME="wmsManager"
export TMP_DIR="/tmp"
export LOG_LEVEL="INFO"

# Load properties
if [[ -f "${PROJECT_ROOT}/etc/properties.sh" ]]; then
 source "${PROJECT_ROOT}/etc/properties.sh"
fi

# Load WMS specific properties only if not in test mode
if [[ -z "${TEST_DBNAME:-}" ]] && [[ -f "${PROJECT_ROOT}/etc/wms.properties.sh" ]]; then
 source "${PROJECT_ROOT}/etc/wms.properties.sh"
fi

# Set database variables with priority: WMS_* > TEST_* > default
WMS_DB_NAME="${WMS_DBNAME:-${TEST_DBNAME:-osm_notes}}"
WMS_DB_USER="${WMS_DBUSER:-${TEST_DBUSER:-postgres}}"
WMS_DB_PASSWORD="${WMS_DBPASSWORD:-${TEST_DBPASSWORD:-}}"
WMS_DB_HOST="${WMS_DBHOST:-${TEST_DBHOST:-}}"
WMS_DB_PORT="${WMS_DBPORT:-${TEST_DBPORT:-}}"

# Export for psql commands
export WMS_DB_NAME WMS_DB_USER WMS_DB_PASSWORD WMS_DB_HOST WMS_DB_PORT
export PGPASSWORD="${WMS_DB_PASSWORD}"

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
  deinstall   Remove WMS components from the database
  status      Check the status of WMS installation
  help        Show this help message

OPTIONS:
  --force     Force installation even if already installed
  --dry-run   Show what would be done without executing
  --verbose   Show detailed output

EXAMPLES:
  $0 install              # Install WMS components
  $0 deinstall            # Remove WMS components
  $0 status               # Check installation status
  $0 install --force      # Force reinstallation
  $0 install --dry-run    # Show what would be installed

ENVIRONMENT VARIABLES:
  DBNAME      Database name (default: osm_notes)
  DBUSER      Database user (default: postgres)
  DBPASSWORD  Database password
  DBHOST      Database host (default: localhost)
  DBPORT      Database port (default: 5432)

EOF
}

# Function to validate prerequisites
validate_prerequisites() {
 # Check if required SQL files exist
 if [[ ! -f "${WMS_PREPARE_SQL}" ]]; then
  print_status "${RED}" "❌ ERROR: WMS prepare SQL file not found: ${WMS_PREPARE_SQL}"
  exit 1
 fi

 if [[ ! -r "${WMS_PREPARE_SQL}" ]]; then
  print_status "${RED}" "❌ ERROR: WMS prepare SQL file is not readable: ${WMS_PREPARE_SQL}"
  exit 1
 fi

 if [[ ! -f "${WMS_REMOVE_SQL}" ]]; then
  print_status "${RED}" "❌ ERROR: WMS remove SQL file not found: ${WMS_REMOVE_SQL}"
  exit 1
 fi

 if [[ ! -r "${WMS_REMOVE_SQL}" ]]; then
  print_status "${RED}" "❌ ERROR: WMS remove SQL file is not readable: ${WMS_REMOVE_SQL}"
  exit 1
 fi

 # Check database connection and PostGIS
 local PSQL_CMD="psql -U \"${WMS_DB_USER}\" -d \"${WMS_DB_NAME}\""
 if [[ -n "${WMS_DB_HOST}" ]]; then
  PSQL_CMD="psql -h \"${WMS_DB_HOST}\" -U \"${WMS_DB_USER}\" -d \"${WMS_DB_NAME}\""
 fi
 if [[ -n "${WMS_DB_PORT}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p \"${WMS_DB_PORT}\""
 fi

 # Test database connection first
 if ! eval "${PSQL_CMD} -c \"SELECT 1;\"" &> /dev/null; then
  print_status "${RED}" "❌ ERROR: Cannot connect to database: ${WMS_DB_NAME}@${WMS_DB_HOST:-localhost}:${WMS_DB_PORT:-5432}"
  exit 1
 fi

 if ! eval "${PSQL_CMD} -c \"SELECT PostGIS_Version();\"" &> /dev/null; then
  print_status "${RED}" "❌ ERROR: PostGIS extension is not installed or not accessible"
  exit 1
 fi

 print_status "${GREEN}" "✅ Prerequisites validated"
}

# Function to check if WMS is installed
is_wms_installed() {
 local PSQL_CMD="psql -U \"${WMS_DB_USER}\" -d \"${WMS_DB_NAME}\""
 if [[ -n "${WMS_DB_HOST}" ]]; then
  PSQL_CMD="psql -h \"${WMS_DB_HOST}\" -U \"${WMS_DB_USER}\" -d \"${WMS_DB_NAME}\""
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

 if [[ "${SCHEMA_EXISTS}" == "t" ]]; then
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
 local PSQL_CMD="psql -U \"${WMS_DB_USER}\" -d \"${WMS_DB_NAME}\""
 if [[ -n "${WMS_DB_HOST}" ]]; then
  PSQL_CMD="psql -h \"${WMS_DB_HOST}\" -U \"${WMS_DB_USER}\" -d \"${WMS_DB_NAME}\""
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
  exit 1
 fi
}

# Function to deinstall WMS
deinstall_wms() {
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
 local PSQL_CMD="psql -U \"${WMS_DB_USER}\" -d \"${WMS_DB_NAME}\""
 if [[ -n "${WMS_DB_HOST}" ]]; then
  PSQL_CMD="psql -h \"${WMS_DB_HOST}\" -U \"${WMS_DB_USER}\" -d \"${WMS_DB_NAME}\""
 fi
 if [[ -n "${WMS_DB_PORT}" ]]; then
  PSQL_CMD="${PSQL_CMD} -p \"${WMS_DB_PORT}\""
 fi

 # Execute removal SQL
 if eval "${PSQL_CMD} -f \"${WMS_REMOVE_SQL}\""; then
  print_status "${GREEN}" "✅ WMS removal completed successfully"
 else
  print_status "${RED}" "❌ ERROR: WMS removal failed"
  exit 1
 fi
}

# Function to show WMS status
show_status() {
 print_status "${BLUE}" "📊 WMS Status Report"

 if is_wms_installed; then
  print_status "${GREEN}" "✅ WMS is installed"

  # Build psql command
  local PSQL_CMD="psql -U \"${WMS_DB_USER}\" -d \"${WMS_DB_NAME}\""
  if [[ -n "${WMS_DB_HOST}" ]]; then
   PSQL_CMD="psql -h \"${WMS_DB_HOST}\" -U \"${WMS_DB_USER}\" -d \"${WMS_DB_NAME}\""
  fi
  if [[ -n "${WMS_DB_PORT}" ]]; then
   PSQL_CMD="${PSQL_CMD} -p \"${WMS_DB_PORT}\""
  fi

  # Show basic statistics
  local NOTE_COUNT
  NOTE_COUNT=$(eval "${PSQL_CMD} -t -c \"SELECT COUNT(*) FROM wms.notes_wms;\"" | tr -d ' ')

  print_status "${BLUE}" "📈 WMS Statistics:"
  print_status "${BLUE}" "   - Total notes in WMS: ${NOTE_COUNT}"

  # Show trigger information
  local TRIGGER_COUNT
  TRIGGER_COUNT=$(eval "${PSQL_CMD} -t -c \"SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_name IN ('insert_new_notes', 'update_notes');\"" | tr -d ' ')

  print_status "${BLUE}" "   - Active triggers: ${TRIGGER_COUNT}"

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
 # Parse command line arguments
 local COMMAND=""
 local FORCE=false
 local DRY_RUN=false

 while [[ $# -gt 0 ]]; do
  case $1 in
  install | deinstall | status | help)
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

  -h | --help)
   show_help
   exit 0
   ;;
  *)
   print_status "${RED}" "❌ ERROR: Unknown option: $1"
   show_help
   exit 1
   ;;
  esac
 done

 # Execute command
 case "${COMMAND}" in
 install | deinstall | status)
  # Validate prerequisites only for commands that need database access
  validate_prerequisites

  case "${COMMAND}" in
  install)
   install_wms
   ;;
  deinstall)
   deinstall_wms
   ;;
  status)
   show_status
   ;;
  *)
   print_status "${RED}" "❌ ERROR: Unknown subcommand: ${COMMAND}"
   exit 1
   ;;
  esac
  ;;
 help)
  show_help
  ;;
 "")
  print_status "${RED}" "❌ ERROR: No command specified"
  show_help
  exit 1
  ;;
 *)
  print_status "${RED}" "❌ ERROR: Unknown command: ${COMMAND}"
  show_help
  exit 1
  ;;
 esac
}

# Execute main function with all arguments
if [[ "${SKIP_MAIN:-}" != "true" ]]; then
 main "$@"
fi
