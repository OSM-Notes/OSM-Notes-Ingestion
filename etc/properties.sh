#!/bin/bash

# Set of properties for all scripts. This file should be modified for specific
# customization.
#
# Author: Andres Gomez
# Version: 2025-10-19

# Database configuration.
# shellcheck disable=SC2034
if [[ -z "${DBNAME:-}" ]]; then
 declare -r DBNAME="${DBNAME:-osm-notes}"
fi
# shellcheck disable=SC2034
if [[ -z "${DB_USER:-}" ]]; then
 declare -r DB_USER="${DB_USER:-myuser}"
fi

# Email configuration for reports.
declare EMAILS="${EMAILS:-username@domain.com}"

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
declare CLEAN="${CLEAN:-true}"

# XML Validation configuration
# Skip XML validation for faster processing when using trusted Planet dumps
# Set to false to enable full validation (structure, dates, coordinates)
# Set to true to skip all validations and assume XML is well-formed (FASTER)
# Default: true (skip validation for speed, assuming official OSM Planet is valid)
# WARNING: Only skip validation if you trust the XML source (e.g., official OSM Planet)
declare SKIP_XML_VALIDATION="${SKIP_XML_VALIDATION:-true}"
