#!/bin/bash

# Test Properties for OSM-Notes-profile Unit Tests
# Simplified properties file without readonly declarations
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-17

# Database configuration.
if [[ -z "${DBNAME:-}" ]]; then
 declare DBNAME="${DBNAME:-notes}"
fi
if [[ -z "${DB_USER:-}" ]]; then
 declare DB_USER="${DB_USER:-notes}"
fi

# Email configuration for reports.
declare EMAILS="${EMAILS:-username@domain.com}"

# OpenStreetMap API configuration.
declare OSM_API="${OSM_API:-https://api.openstreetmap.org/api/0.6}"

# OpenStreetMap Planet dump URL.
declare PLANET="${PLANET:-https://planet.openstreetmap.org}"

# Overpass interpreter URL. Used to download the countries and maritime boundaries.
declare OVERPASS_INTERPRETER="${OVERPASS_INTERPRETER:-https://overpass-api.de/api/interpreter}"

# Rate limiting configuration.
# Wait between loops when downloading boundaries, to prevent "Too many requests".
declare SECONDS_TO_WAIT="${SECONDS_TO_WAIT:-30}"

# Processing configuration.
# Quantity of notes to process per loop, to get the location of the note.
declare LOOP_SIZE="${LOOP_SIZE:-10000}"

# Maximum number of notes to download from the API.
if [[ -z "${MAX_NOTES:-}" ]]; then
 declare MAX_NOTES="${MAX_NOTES:-10000}"
fi

# Parallel processing configuration.
# Number of threads to use in parallel processing.
# It should be less than the number of cores of the server.
declare MAX_THREADS="${MAX_THREADS:-4}"

# Delay between launching parallel processes to prevent system overload.
# This helps stagger process creation and reduces memory pressure spikes.
# Use production values but make them non-readonly for testing
declare PARALLEL_PROCESS_DELAY="2"

# Minimum number of notes to enable parallel processing.
# If the number of notes is less than this threshold, processing will be sequential.
# This helps avoid the overhead of parallelization for small datasets.
declare MIN_NOTES_FOR_PARALLEL="${MIN_NOTES_FOR_PARALLEL:-10}"

# Set MAX_THREADS based on available cores, with limits
if command -v nproc > /dev/null 2>&1; then
 MAX_THREADS=$(nproc)
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

# Resource monitoring configuration
# Maximum memory usage percentage before triggering delays
if [[ -z "${MAX_MEMORY_PERCENT:-}" ]]; then
 declare MAX_MEMORY_PERCENT="80"
fi

# Maximum system load average before triggering delays
if [[ -z "${MAX_LOAD_AVERAGE:-}" ]]; then
 declare MAX_LOAD_AVERAGE="2.0"
fi
