#!/bin/bash

# Set of properties for all scripts. This file should be modified for specific
# customization.
#
# Author: Andres Gomez
# Version: 2025-08-18

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

# Rate limiting configuration.
# Wait between loops when downloading boundaries, to prevent "Too many requests".
# shellcheck disable=SC2034
if [[ -z "${SECONDS_TO_WAIT:-}" ]]; then
 declare -r SECONDS_TO_WAIT="30"
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

# Delay between launching parallel processes to prevent system overload.
# This helps stagger process creation and reduces memory pressure spikes.
# shellcheck disable=SC2034
if [[ -z "${PARALLEL_PROCESS_DELAY:-}" ]]; then
 declare -r PARALLEL_PROCESS_DELAY="2"
fi

# XSLT performance profiling configuration.
# Enable profiling to analyze and optimize XSLT transformations.
# Profile files are saved with .profile extension for analysis.
# shellcheck disable=SC2034
if [[ -z "${ENABLE_XSLT_PROFILING:-}" ]]; then
 declare -r ENABLE_XSLT_PROFILING="${ENABLE_XSLT_PROFILING:-false}"
fi

# XSLT processing maximum recursion depth
# Used for complex notes with long HTML/text to avoid recursion limit errors
# shellcheck disable=SC2034
if [[ -z "${XSLT_MAX_DEPTH:-}" ]]; then
 declare -r XSLT_MAX_DEPTH="4000"
fi

# Minimum number of notes to enable parallel processing.
# If the number of notes is less than this threshold, processing will be sequential.
# This helps avoid the overhead of parallelization for small datasets.
# shellcheck disable=SC2034
if [[ -z "${MIN_NOTES_FOR_PARALLEL:-}" ]]; then
 declare -r MIN_NOTES_FOR_PARALLEL="10"
fi

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
