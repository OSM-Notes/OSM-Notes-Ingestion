#!/bin/bash

# Test Properties for OSM-Notes-profile
# Independent test configuration - separate from production properties
#
# Author: Andres Gomez (AngocA)
# Version: 2026-01-15

# Database configuration for tests
# Respect environment variables already set (e.g., by GitHub Actions)
# Only set defaults if variables are not already configured
# Detect if running in CI/CD environment
if [[ -f "/app/bin/functionsProcess.sh" ]]; then
 # Running in Docker container
 if [[ "${TEST_DEBUG:-}" == "true" ]]; then
  echo "DEBUG: Detected Docker environment" >&2
 fi
 export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
 export TEST_DBUSER="${TEST_DBUSER:-testuser}"
 export TEST_DBPASSWORD="${TEST_DBPASSWORD:-testpass}"
 export TEST_DBHOST="${TEST_DBHOST:-postgres}"
 export TEST_DBPORT="${TEST_DBPORT:-5432}"
elif [[ "${CI:-}" == "true" ]] || [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
 # Running in GitHub Actions CI
 # Respect variables already set by GitHub Actions workflow
 # Only set defaults if not already configured
 if [[ "${TEST_DEBUG:-}" == "true" ]]; then
  echo "DEBUG: Detected CI environment" >&2
 fi
 export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
 export TEST_DBUSER="${TEST_DBUSER:-postgres}"
 export TEST_DBPASSWORD="${TEST_DBPASSWORD:-postgres}"
 export TEST_DBHOST="${TEST_DBHOST:-localhost}"
 export TEST_DBPORT="${TEST_DBPORT:-5432}"
 # Set PGPASSWORD for PostgreSQL client tools
 export PGPASSWORD="${TEST_DBPASSWORD}"
else
 # Running on host - use local PostgreSQL with peer authentication
 if [[ "${TEST_DEBUG:-}" == "true" ]]; then
  echo "DEBUG: Detected host environment" >&2
 fi
 export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
 export TEST_DBUSER="${TEST_DBUSER:-$(whoami)}"
 export TEST_DBPASSWORD="${TEST_DBPASSWORD:-}"
 export TEST_DBHOST="${TEST_DBHOST:-}"
 export TEST_DBPORT="${TEST_DBPORT:-}"

 # Ensure host and port are empty for local connection
 unset TEST_DBHOST TEST_DBPORT

 # Ensure user is current user for local connection
 unset TEST_DBUSER

 # For peer authentication, ensure these variables are not set
 unset PGPASSWORD 2> /dev/null || true
 unset DB_HOST 2> /dev/null || true
 unset DB_PORT 2> /dev/null || true
 unset DB_USER 2> /dev/null || true
 unset DB_PASSWORD 2> /dev/null || true
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

# Test sleep multiplier for CI optimization
# In CI, reduce sleep times by 90% to speed up tests
# Local tests use realistic delays, CI uses minimal delays
export TEST_SLEEP_MULTIPLIER="${TEST_SLEEP_MULTIPLIER:-1}"
export CI_TEST_SLEEP_MULTIPLIER="${CI_TEST_SLEEP_MULTIPLIER:-0.1}" # 10x faster in CI

# Determine which multiplier to use
if [[ "${CI:-false}" == "true" ]] || [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
 export ACTIVE_SLEEP_MULTIPLIER="${CI_TEST_SLEEP_MULTIPLIER}"
else
 export ACTIVE_SLEEP_MULTIPLIER="${TEST_SLEEP_MULTIPLIER}"
fi

# Test Docker configuration
export DOCKER_TIMEOUT="300"    # 5 minutes for Docker operations
export DOCKER_MAX_RETRIES="10" # Docker-specific retries

# Test parallel processing configuration
export PARALLEL_ENABLED="false" # Default to sequential for stability
export PARALLEL_THREADS="2"     # Conservative parallel processing

# Test validation configuration
export VALIDATION_TIMEOUT="60" # 1 minute for validation tests
export VALIDATION_RETRIES="3"  # Standard validation retries
