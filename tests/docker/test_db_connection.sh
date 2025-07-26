#!/bin/bash

# Test Database Connection Script
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
 echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
 echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
 echo -e "${RED}[ERROR]${NC} $1"
}

echo "=========================================="
echo "Database Connection Test"
echo "=========================================="
echo

# Test 1: Check if PostgreSQL is reachable
log_info "Test 1: Checking if PostgreSQL is reachable..."
if ping -c 1 postgres &> /dev/null; then
 log_success "PostgreSQL host is reachable"
else
 log_error "PostgreSQL host is not reachable"
 exit 1
fi

# Test 2: Check if port 5432 is open
log_info "Test 2: Checking if port 5432 is open..."
if nc -z postgres 5432; then
 log_success "Port 5432 is open"
else
 log_error "Port 5432 is not open"
 exit 1
fi

# Test 3: Test database connection
log_info "Test 3: Testing database connection..."
if psql -h postgres -U testuser -d osm_notes_test -c "SELECT 1;" &> /dev/null; then
 log_success "Database connection successful"
else
 log_error "Database connection failed"
 exit 1
fi

# Test 4: Check if tables exist
log_info "Test 4: Checking if tables exist..."
if psql -h postgres -U testuser -d osm_notes_test -c "\dt" &> /dev/null; then
 log_success "Tables exist"
else
 log_error "Tables do not exist"
 exit 1
fi

# Test 5: Test data insertion
log_info "Test 5: Testing data insertion..."
if psql -h postgres -U testuser -d osm_notes_test -c "INSERT INTO test_notes (note_id, lat, lon, status) VALUES (999, 0.0, 0.0, 'test') ON CONFLICT DO NOTHING;" &> /dev/null; then
 log_success "Data insertion successful"
else
 log_error "Data insertion failed"
 exit 1
fi

log_success "All database connection tests passed!"
