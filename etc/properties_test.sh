#!/bin/bash

# Test Properties for OSM-Notes-Ingestion
# This file defines test-specific properties.
# All database connections must be controlled by properties files.
# This file is loaded INSTEAD of etc/properties.sh when in test mode.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-11-24

# Database configuration for tests
# These values override production values for test environments
# shellcheck disable=SC2034
if [[ -z "${DBNAME:-}" ]]; then
  DBNAME="osm-notes-test"
fi
# shellcheck disable=SC2034
if [[ -z "${DB_USER:-}" ]]; then
  DB_USER="${USER:-angoca}"
fi

# Email configuration for reports.
declare EMAILS="${EMAILS:-username@domain.com}"

# Alert configuration for failed executions.
# Email address for immediate failure alerts.
# shellcheck disable=SC2034
declare ADMIN_EMAIL="${ADMIN_EMAIL:-root@localhost}"

# Enable/disable email alerts on failures.
# Set to "true" to send immediate email alerts when critical errors occur.
# Set to "false" to only create failed execution marker files without sending alerts.
# shellcheck disable=SC2034
declare SEND_ALERT_EMAIL="${SEND_ALERT_EMAIL:-false}"

# OpenStreetMap API configuration.
# shellcheck disable=SC2034
declare OSM_API="${OSM_API:-https://api.openstreetmap.org/api/0.6}"

# OpenStreetMap Planet dump URL.
# shellcheck disable=SC2034
if [[ -z "${PLANET:-}" ]]; then
  declare -r PLANET="https://planet.openstreetmap.org"
fi

# Overpass interpreter URL. Used to download the countries and maritime boundaries.
# shellcheck disable=SC2034
if [[ -z "${OVERPASS_INTERPRETER:-}" ]]; then
  declare -r OVERPASS_INTERPRETER="https://overpass-api.de/api/interpreter"
fi

# Overpass fallback and validation configuration.
# Comma-separated list of interpreter endpoints. The first one is primary.
# Example:
#   export OVERPASS_ENDPOINTS="https://overpass-api.de/api/interpreter,https://overpass.kumi.systems/api/interpreter"
declare OVERPASS_ENDPOINTS="${OVERPASS_ENDPOINTS:-${OVERPASS_INTERPRETER}}"

# Max retries per endpoint for a single boundary download attempt.
declare OVERPASS_RETRIES_PER_ENDPOINT="${OVERPASS_RETRIES_PER_ENDPOINT:-7}"

# Base backoff (seconds) between retries within the same endpoint (exponential).
declare OVERPASS_BACKOFF_SECONDS="${OVERPASS_BACKOFF_SECONDS:-20}"

# Continue processing other boundaries on Overpass JSON validation errors.
declare CONTINUE_ON_OVERPASS_ERROR="${CONTINUE_ON_OVERPASS_ERROR:-true}"

# Overpass retry configuration when CONTINUE_ON_OVERPASS_ERROR=true
# Test values may be lower for faster test execution
declare OVERPASS_CONTINUE_MAX_RETRIES_PER_ENDPOINT="${OVERPASS_CONTINUE_MAX_RETRIES_PER_ENDPOINT:-2}"
declare OVERPASS_CONTINUE_BASE_DELAY="${OVERPASS_CONTINUE_BASE_DELAY:-5}"
declare OVERPASS_CONTINUE_VALIDATION_RETRIES="${OVERPASS_CONTINUE_VALIDATION_RETRIES:-2}"

# JSON validator command (must support: jq -e .).
declare JSON_VALIDATOR="${JSON_VALIDATOR:-jq}"

# Generic download User-Agent applied to all HTTP requests when supported.
# Recommended format: ProjectName/Version (+project_url; contact: email)
# Defaults to project identity if not provided.
if [[ -z "${DOWNLOAD_USER_AGENT:-}" ]]; then
  # Do not break lines; keep UA in one line for header correctness
  DOWNLOAD_USER_AGENT="OSM-Notes-Ingestion/2025-10-30 (+https://github.com/osmlatam/OSM-Notes-Ingestion; contact: angoca@osm.lat)"
fi

# Processing configuration.
# Quantity of notes to process per loop, to get the location of the note.
# shellcheck disable=SC2034
if [[ -z "${LOOP_SIZE:-}" ]]; then
  declare -r LOOP_SIZE="10000"
fi

# Maximum number of notes to download from the API.
# shellcheck disable=SC2034
if [[ -z "${MAX_NOTES:-}" ]]; then
  declare -r MAX_NOTES="10000"
fi

# Parallel processing configuration.
# Number of threads to use in parallel processing.
# It should be less than the number of cores of the server.
# shellcheck disable=SC2034
declare MAX_THREADS="4"

# Minimum number of notes to enable parallel processing.
# If the number of notes is less than this threshold, processing will be sequential.
# This helps avoid the overhead of parallelization for small datasets.
# shellcheck disable=SC2034
if [[ -z "${MIN_NOTES_FOR_PARALLEL:-}" ]]; then
  declare -r MIN_NOTES_FOR_PARALLEL="10"
fi

# Set MAX_THREADS based on available cores, leaving some for system
# This prevents system saturation and allows OS, PostgreSQL, and other processes to run
if command -v nproc > /dev/null 2>&1; then
  TOTAL_CORES=$(nproc)
  
  # Leave at least 2 cores free for system and database
  if [[ "${TOTAL_CORES}" -gt 4 ]]; then
    MAX_THREADS=$((TOTAL_CORES - 2))
  elif [[ "${TOTAL_CORES}" -gt 2 ]]; then
    MAX_THREADS=$((TOTAL_CORES - 1))  # Leave at least 1 core free
  else
    MAX_THREADS=1  # Use only 1 thread on systems with 1-2 cores
  fi
  
  # Limit to reasonable values for production
  if [[ "${MAX_THREADS}" -gt 16 ]]; then
    MAX_THREADS=16
  fi
else
  MAX_THREADS=4
fi

# Cleanup configuration
# Controls whether temporary files and directories should be cleaned up after processing
# Set to false to preserve files for debugging purposes
declare CLEAN="${CLEAN:-false}"

# XML Validation configuration
# Skip XML validation for faster processing when using trusted Planet dumps
# Set to false to enable full validation (structure, dates, coordinates)
# Set to true to skip all validations and assume XML is well-formed (FASTER)
# Default: true (skip validation for speed, assuming official OSM Planet is valid)
# WARNING: Only skip validation if you trust the XML source (e.g., official OSM Planet)
declare SKIP_XML_VALIDATION="${SKIP_XML_VALIDATION:-true}"

# Overpass API rate limiting
# Maximum number of concurrent downloads from Overpass API
# Overpass has 2 servers × 4 slots = 8 total concurrent slots
# shellcheck disable=SC2034
declare RATE_LIMIT="${RATE_LIMIT:-8}"

# Assignment chunk size for geolocation queue (notes per batch)
# shellcheck disable=SC2034
declare ASSIGN_CHUNK_SIZE="${ASSIGN_CHUNK_SIZE:-5000}"

# Verification configuration for note location integrity checks
# These values are smaller than production to enable parallel testing with fewer notes
# Verification chunk size (notes per batch) - smaller for tests to activate parallelism
# Production uses 20000, tests use 1000 to activate parallel processing with ~2000+ notes
# shellcheck disable=SC2034
declare VERIFY_CHUNK_SIZE="${VERIFY_CHUNK_SIZE:-1000}"

# SQL sub-chunk size within each verification chunk
# Production uses 20000, tests use 1000 for faster testing and to activate parallelism
# with smaller datasets (larger batches = fewer queries but more memory per query)
# shellcheck disable=SC2034
declare VERIFY_SQL_BATCH_SIZE="${VERIFY_SQL_BATCH_SIZE:-1000}"

# Parallel threads for verification
# Production uses 2, tests use 2 to ensure parallel execution is tested
# shellcheck disable=SC2034
declare VERIFY_THREADS="${VERIFY_THREADS:-2}"
