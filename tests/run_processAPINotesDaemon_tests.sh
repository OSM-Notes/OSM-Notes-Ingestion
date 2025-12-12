#!/bin/bash

# Run tests specifically for processAPINotesDaemon.sh
# Focuses on sleep logic and daemon functionality
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "Testing processAPINotesDaemon.sh"
echo "=========================================="
echo ""

# Check if bats is available
if ! command -v bats >/dev/null 2>&1; then
 echo -e "${RED}ERROR: bats is not installed${NC}"
 echo "Install with: sudo apt-get install bats || brew install bats-core"
 exit 1
fi

# Check bats version
BATS_VERSION=$(bats --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "0.0")
REQUIRED_VERSION="1.5.0"

if [[ $(echo "${BATS_VERSION} < ${REQUIRED_VERSION}" | bc -l 2>/dev/null || echo "1") == "1" ]]; then
 echo -e "${YELLOW}WARNING: bats version ${BATS_VERSION} may be too old (required: ${REQUIRED_VERSION})${NC}"
fi

echo "Running daemon sleep logic tests..."
echo ""

# Run sleep logic tests
if bats "${SCRIPT_DIR}/unit/bash/processAPINotesDaemon_sleep_logic.test.bats"; then
 echo -e "${GREEN}✓ Sleep logic tests passed${NC}"
else
 echo -e "${RED}✗ Sleep logic tests failed${NC}"
 exit 1
fi

echo ""
echo "Running daemon integration tests..."
echo ""

# Run integration tests
if bats "${SCRIPT_DIR}/unit/bash/processAPINotesDaemon_integration.test.bats"; then
 echo -e "${GREEN}✓ Integration tests passed${NC}"
else
 echo -e "${RED}✗ Integration tests failed${NC}"
 exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}All daemon tests passed!${NC}"
echo "=========================================="
