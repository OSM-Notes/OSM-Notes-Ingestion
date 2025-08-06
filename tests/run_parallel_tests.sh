#!/bin/bash

# Parallel processing tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== RUNNING PARALLEL PROCESSING TESTS ==="
echo "Testing parallel processing functionality..."

# Parallel processing validation tests
echo "1. Testing parallel processing validation..."
bats unit/bash/parallel_processing_validation.test.bats

# Parallel threshold tests
echo "2. Testing parallel threshold..."
bats unit/bash/parallel_threshold.test.bats

# Parallel failed file tests (our recent improvements)
echo "3. Testing parallel failed file handling..."
bats unit/bash/parallel_failed_file.test.bats

# API download verification tests
echo "4. Testing API download verification..."
bats unit/bash/api_download_verification.test.bats

# Prerequisites enhanced tests
echo "5. Testing enhanced prerequisites..."
bats unit/bash/prerequisites_enhanced.test.bats

echo "=== PARALLEL PROCESSING TESTS COMPLETED ===" 