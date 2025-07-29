#!/bin/bash

# Test Properties for OSM-Notes-profile
# Independent test configuration - separate from production properties
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-28

# Database configuration for tests
# Detect if running in CI/CD environment
if [[ -f "/app/bin/functionsProcess.sh" ]]; then
 # Running in Docker container
 echo "DEBUG: Detected Docker environment" >&2
 export TEST_DBNAME="osm_notes_test"
 export TEST_DBUSER="testuser"
 export TEST_DBPASSWORD="testpass"
 export TEST_DBHOST="postgres"
 export TEST_DBPORT="5432"
elif [[ "${CI:-}" == "true" ]] || [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
 # Running in GitHub Actions CI
 echo "DEBUG: Detected CI environment" >&2
 export TEST_DBNAME="osm_notes_test"
 export TEST_DBUSER="testuser"
 export TEST_DBPASSWORD="testpass"
 export TEST_DBHOST="postgres"
 export TEST_DBPORT="5432"
else
 # Running on host - use local PostgreSQL with current user
 echo "DEBUG: Detected host environment" >&2
 export TEST_DBNAME="osm_notes_test"
 TEST_DBUSER="$(whoami)"
 export TEST_DBUSER
 export TEST_DBPASSWORD=""
 export TEST_DBHOST=""
 export TEST_DBPORT=""
fi

# Force override if variables are already set
if [[ "${CI:-}" == "true" ]] || [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
 unset TEST_DBUSER TEST_DBPASSWORD 2> /dev/null || true
 TEST_DBUSER="testuser"
 export TEST_DBUSER
 TEST_DBPASSWORD="testpass"
 export TEST_DBPASSWORD
fi

# Test application configuration
export LOG_LEVEL="INFO"
export MAX_THREADS="2"

# Test timeout and retry configuration
export TEST_TIMEOUT="300" # 5 minutes for general tests
export TEST_RETRIES="3"   # Standard retry count
export MAX_RETRIES="30"   # Maximum retries for service startup
export RETRY_INTERVAL="2" # Seconds between retries

# Mock API configuration
export MOCK_API_URL="http://localhost:8001"
export MOCK_API_TIMEOUT="30" # 30 seconds for mock API

# Test performance configuration
export TEST_PERFORMANCE_TIMEOUT="60" # 1 minute for performance tests
export MEMORY_LIMIT_MB="100"         # Memory limit for tests

# Test CI/CD specific configuration
export CI_TIMEOUT="600"    # 10 minutes for CI/CD tests
export CI_MAX_RETRIES="20" # More retries for CI environment
export CI_MAX_THREADS="2"  # Conservative threading for CI

# Test Docker configuration
export DOCKER_TIMEOUT="300"    # 5 minutes for Docker operations
export DOCKER_MAX_RETRIES="10" # Docker-specific retries

# Test parallel processing configuration
export PARALLEL_ENABLED="false" # Default to sequential for stability
export PARALLEL_THREADS="2"     # Conservative parallel processing

# Test validation configuration
export VALIDATION_TIMEOUT="60" # 1 minute for validation tests
export VALIDATION_RETRIES="3"  # Standard validation retries
