#!/bin/bash
# WMS Manager Script
# Manages the installation and deinstallation of WMS components
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

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

# WMS specific variables
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
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
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
  print_status "$BLUE" "🔍 Validating prerequisites..."
  
  # Check if PostgreSQL is available
  if ! command -v psql &> /dev/null; then
    print_status "$RED" "❌ ERROR: PostgreSQL client (psql) is not installed"
    exit 1
  fi
  
  # Check if PostGIS extension is available
  if ! psql -h "${DBHOST:-localhost}" -U "${DBUSER:-postgres}" -d "${DBNAME:-osm_notes}" -c "SELECT PostGIS_Version();" &> /dev/null; then
    print_status "$RED" "❌ ERROR: PostGIS extension is not installed or not accessible"
    exit 1
  fi
  
  # Check if required SQL files exist
  if [[ ! -f "${WMS_PREPARE_SQL}" ]]; then
    print_status "$RED" "❌ ERROR: WMS prepare SQL file not found: ${WMS_PREPARE_SQL}"
    exit 1
  fi
  
  if [[ ! -f "${WMS_REMOVE_SQL}" ]]; then
    print_status "$RED" "❌ ERROR: WMS remove SQL file not found: ${WMS_REMOVE_SQL}"
    exit 1
  fi
  
  # Check database connection
  if ! psql -h "${DBHOST:-localhost}" -U "${DBUSER:-postgres}" -d "${DBNAME:-osm_notes}" -c "SELECT 1;" &> /dev/null; then
    print_status "$RED" "❌ ERROR: Cannot connect to database"
    exit 1
  fi
  
  print_status "$GREEN" "✅ Prerequisites validation passed"
}

# Function to check if WMS is already installed
check_wms_status() {
  local schema_exists
  schema_exists=$(psql -h "${DBHOST:-localhost}" -U "${DBUSER:-postgres}" -d "${DBNAME:-osm_notes}" -t -c "SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'wms');" | tr -d ' ')
  
  if [[ "$schema_exists" == "t" ]]; then
    return 0  # WMS is installed
  else
    return 1  # WMS is not installed
  fi
}

# Function to install WMS
install_wms() {
  print_status "$BLUE" "🚀 Installing WMS components..."
  
  # Check if already installed
  if check_wms_status; then
    if [[ "${FORCE:-false}" == "true" ]]; then
      print_status "$YELLOW" "⚠️  WMS already installed. Forcing reinstallation..."
      deinstall_wms
    else
      print_status "$YELLOW" "⚠️  WMS is already installed. Use --force to reinstall."
      return 0
    fi
  fi
  
  # Validate prerequisites
  validate_prerequisites
  
  # Execute installation SQL
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    print_status "$YELLOW" "🔍 DRY RUN: Would execute ${WMS_PREPARE_SQL}"
    return 0
  fi
  
  print_status "$BLUE" "📦 Executing WMS installation SQL..."
  if psql -h "${DBHOST:-localhost}" -U "${DBUSER:-postgres}" -d "${DBNAME:-osm_notes}" -v ON_ERROR_STOP=1 -f "${WMS_PREPARE_SQL}"; then
    print_status "$GREEN" "✅ WMS installation completed successfully"
    
    # Show installation summary
    show_installation_summary
  else
    print_status "$RED" "❌ ERROR: WMS installation failed"
    exit 1
  fi
}

# Function to deinstall WMS
deinstall_wms() {
  print_status "$BLUE" "🗑️  Removing WMS components..."
  
  # Check if WMS is installed
  if ! check_wms_status; then
    print_status "$YELLOW" "⚠️  WMS is not installed. Nothing to remove."
    return 0
  fi
  
  # Execute removal SQL
  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    print_status "$YELLOW" "🔍 DRY RUN: Would execute ${WMS_REMOVE_SQL}"
    return 0
  fi
  
  print_status "$BLUE" "📦 Executing WMS removal SQL..."
  if psql -h "${DBHOST:-localhost}" -U "${DBUSER:-postgres}" -d "${DBNAME:-osm_notes}" -v ON_ERROR_STOP=1 -f "${WMS_REMOVE_SQL}"; then
    print_status "$GREEN" "✅ WMS removal completed successfully"
  else
    print_status "$RED" "❌ ERROR: WMS removal failed"
    exit 1
  fi
}

# Function to show installation status
show_status() {
  print_status "$BLUE" "📊 Checking WMS installation status..."
  
  if check_wms_status; then
    print_status "$GREEN" "✅ WMS is installed"
    
    # Show additional information
    local note_count
    note_count=$(psql -h "${DBHOST:-localhost}" -U "${DBUSER:-postgres}" -d "${DBNAME:-osm_notes}" -t -c "SELECT COUNT(*) FROM wms.notes_wms;" | tr -d ' ')
    
    print_status "$BLUE" "📈 WMS Statistics:"
    print_status "$BLUE" "   - Total notes in WMS: ${note_count}"
    
    # Show trigger information
    local trigger_count
    trigger_count=$(psql -h "${DBHOST:-localhost}" -U "${DBUSER:-postgres}" -d "${DBNAME:-osm_notes}" -t -c "SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_name IN ('insert_new_notes', 'update_notes');" | tr -d ' ')
    
    print_status "$BLUE" "   - Active triggers: ${trigger_count}"
    
  else
    print_status "$YELLOW" "⚠️  WMS is not installed"
  fi
}

# Function to show installation summary
show_installation_summary() {
  print_status "$BLUE" "📋 Installation Summary:"
  print_status "$BLUE" "   - Schema 'wms' created"
  print_status "$BLUE" "   - Table 'wms.notes_wms' created"
  print_status "$BLUE" "   - Indexes created for performance"
  print_status "$BLUE" "   - Triggers configured for synchronization"
  print_status "$BLUE" "   - Functions created for data management"
}

# Main function
main() {
  # Parse command line arguments
  local command=""
  local force=false
  local dry_run=false
  local verbose=false
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      install|deinstall|status|help)
        command="$1"
        shift
        ;;
      --force)
        force=true
        shift
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      --verbose)
        verbose=true
        shift
        ;;
      -h|--help)
        show_help
        exit 0
        ;;
      *)
        print_status "$RED" "❌ ERROR: Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
  
  # Set global variables
  FORCE="$force"
  DRY_RUN="$dry_run"
  VERBOSE="$verbose"
  
  # Execute command
  case "$command" in
    install)
      install_wms
      ;;
    deinstall)
      deinstall_wms
      ;;
    status)
      show_status
      ;;
    help)
      show_help
      ;;
    "")
      print_status "$RED" "❌ ERROR: No command specified"
      show_help
      exit 1
      ;;
    *)
      print_status "$RED" "❌ ERROR: Unknown command: $command"
      show_help
      exit 1
      ;;
  esac
}

# Execute main function with all arguments
main "$@" 
