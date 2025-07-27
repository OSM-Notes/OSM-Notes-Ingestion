#!/bin/bash
# Simple WMS Test Script
# Tests basic WMS functionality
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

# Test database configuration
TEST_DBNAME="osm_notes_wms_test"
TEST_DBUSER="testuser"
TEST_DBPASSWORD="testpass"
TEST_DBHOST="postgres"
TEST_DBPORT="5432"

# WMS script path
WMS_SCRIPT="/app/bin/wms/wmsManager.sh"

print_status "$BLUE" "🚀 Starting Simple WMS Test..."

# Set environment variables
export DBNAME="$TEST_DBNAME"
export DBUSER="$TEST_DBUSER"
export DBPASSWORD="$TEST_DBPASSWORD"
export DBHOST="$TEST_DBHOST"
export DBPORT="$TEST_DBPORT"
export PGPASSWORD="$TEST_DBPASSWORD"

print_status "$BLUE" "📊 Testing WMS status..."
"$WMS_SCRIPT" status

print_status "$BLUE" "📦 Testing WMS installation..."
"$WMS_SCRIPT" install

print_status "$BLUE" "📊 Testing WMS status after installation..."
"$WMS_SCRIPT" status

print_status "$BLUE" "🗑️  Testing WMS deinstallation..."
"$WMS_SCRIPT" deinstall

print_status "$BLUE" "📊 Testing WMS status after deinstallation..."
"$WMS_SCRIPT" status

print_status "$GREEN" "🎉 All simple WMS tests completed successfully!" 