#!/bin/bash

# Test Properties for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

# Database configuration
# Detect if running in Docker or host
if [[ -f "/app/bin/functionsProcess.sh" ]]; then
  # Running in Docker container
  export TEST_DBNAME="osm_notes_test"
  export TEST_DBUSER="test_user"
  export TEST_DBPASSWORD="test_pass"
  export TEST_DBHOST="test-db"
  export TEST_DBPORT="5432"
else
  # Running on host - use local PostgreSQL
  export TEST_DBNAME="osm_notes_test"
  export TEST_DBUSER="postgres"
  export TEST_DBPASSWORD=""
  export TEST_DBHOST="localhost"
  export TEST_DBPORT="5432"
fi

# Application configuration
export LOG_LEVEL="INFO"
export MAX_THREADS="2"

# Test configuration
export TEST_TIMEOUT="300"
export TEST_RETRIES="3"

# Mock API configuration
export MOCK_API_URL="http://localhost:8001"
export MOCK_API_TIMEOUT="30"

# Performance test configuration
export PERFORMANCE_TIMEOUT="60"
export MEMORY_LIMIT_MB="100"
