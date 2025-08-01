#!/bin/bash

# Single Test Runner
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

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

log_error() {
 echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Test file to run
TEST_FILE="${1:-tests/unit/bash/functionsProcess.test.bats}"

log_info "Running single test: ${TEST_FILE}"

if [[ ! -f "${TEST_FILE}" ]]; then
 log_error "Test file not found: ${TEST_FILE}"
 exit 1
fi

if bats "${TEST_FILE}"; then
 log_success "Test passed: ${TEST_FILE}"
 exit 0
else
 log_error "Test failed: ${TEST_FILE}"
 exit 1
fi 