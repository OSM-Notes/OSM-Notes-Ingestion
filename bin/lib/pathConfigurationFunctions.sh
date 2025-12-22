#!/bin/bash

# Path Configuration Functions for OSM-Notes-Ingestion
# Centralized directory initialization with installation detection and fallback
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-18
VERSION="2025-12-18"

# shellcheck disable=SC2317,SC2155,SC2034

# Detect if system is "installed" (production mode)
# Checks if standard directories exist and are writable
function __is_installed() {
 local INSTALLED_LOG_DIR="${1:-/var/log/osm-notes-ingestion}"
 local INSTALLED_TMP_DIR="${2:-/var/tmp/osm-notes-ingestion}"

 # Check if directories exist and are writable
 if [[ -d "${INSTALLED_LOG_DIR}" ]] && [[ -w "${INSTALLED_LOG_DIR}" ]] \
  && [[ -d "${INSTALLED_TMP_DIR}" ]] && [[ -w "${INSTALLED_TMP_DIR}" ]]; then
  return 0
 fi
 return 1
}

# Initialize log directory
# Returns: LOG_DIR (via echo, capture with: LOG_DIR=$(__init_log_dir))
function __init_log_dir() {
 local SCRIPT_BASENAME="${1:-}"
 local FORCE_FALLBACK="${2:-false}"

 # Use readonly BASENAME if available, otherwise use parameter
 local BASENAME_VALUE
 if [[ -n "${BASENAME:-}" ]] && declare -p BASENAME 2> /dev/null | grep -q "readonly"; then
  BASENAME_VALUE="${BASENAME}"
 else
  BASENAME_VALUE="${SCRIPT_BASENAME}"
 fi

 # Allow override via environment variable
 if [[ -n "${LOG_DIR:-}" ]] && [[ "${FORCE_FALLBACK}" != "true" ]]; then
  echo "${LOG_DIR}"
  return 0
 fi

 # Determine base log directory
 local BASE_LOG_DIR
 if [[ "${FORCE_FALLBACK}" == "true" ]] || ! __is_installed; then
  # Fallback mode: use /tmp (non-persistent, for testing)
  BASE_LOG_DIR="/tmp/osm-notes-ingestion/logs"
  mkdir -p "${BASE_LOG_DIR}" 2> /dev/null || true
 else
  # Installed mode: use /var/log (persistent, production)
  BASE_LOG_DIR="/var/log/osm-notes-ingestion"
 fi

 # Create subdirectory based on script type
 local SCRIPT_TYPE="processing"
 if [[ "${BASENAME_VALUE}" == *"Daemon"* ]] || [[ "${BASENAME_VALUE}" == *"daemon"* ]]; then
  SCRIPT_TYPE="daemon"
 elif [[ "${BASENAME_VALUE}" == *"Monitor"* ]] || [[ "${BASENAME_VALUE}" == *"monitor"* ]] \
  || [[ "${BASENAME_VALUE}" == *"Check"* ]] || [[ "${BASENAME_VALUE}" == *"check"* ]]; then
  SCRIPT_TYPE="monitoring"
 fi

 local LOG_DIR="${BASE_LOG_DIR}/${SCRIPT_TYPE}"
 mkdir -p "${LOG_DIR}" 2> /dev/null || {
  # If creation fails, fallback to /tmp
  LOG_DIR="/tmp/osm-notes-ingestion/logs/${SCRIPT_TYPE}"
  mkdir -p "${LOG_DIR}" 2> /dev/null || true
 }

 echo "${LOG_DIR}"
}

# Initialize temporary files directory
# Returns: TMP_DIR (via echo, capture with: TMP_DIR=$(__init_tmp_dir))
function __init_tmp_dir() {
 local SCRIPT_BASENAME="${1:-}"
 local FORCE_FALLBACK="${2:-false}"

 # Use readonly BASENAME if available, otherwise use parameter
 local BASENAME_VALUE
 if [[ -n "${BASENAME:-}" ]] && declare -p BASENAME 2> /dev/null | grep -q "readonly"; then
  BASENAME_VALUE="${BASENAME}"
 else
  BASENAME_VALUE="${SCRIPT_BASENAME}"
 fi

 # Allow override via environment variable
 if [[ -n "${TMP_DIR:-}" ]] && [[ "${FORCE_FALLBACK}" != "true" ]]; then
  echo "${TMP_DIR}"
  return 0
 fi

 # Determine base temp directory
 local BASE_TMP_DIR
 if [[ "${FORCE_FALLBACK}" == "true" ]] || ! __is_installed; then
  # Fallback mode: use /tmp (non-persistent, for testing)
  BASE_TMP_DIR="/tmp"
 else
  # Installed mode: use /var/tmp (persistent, production)
  BASE_TMP_DIR="/var/tmp/osm-notes-ingestion"
  mkdir -p "${BASE_TMP_DIR}" 2> /dev/null || {
   # If creation fails, fallback to /tmp
   BASE_TMP_DIR="/tmp"
  }
 fi

 # Create unique temporary directory for this execution
 local TMP_DIR
 TMP_DIR=$(mktemp -d "${BASE_TMP_DIR}/${BASENAME_VALUE}_XXXXXX" 2> /dev/null \
  || mktemp -d "/tmp/${BASENAME_VALUE}_XXXXXX")
 chmod 777 "${TMP_DIR}" 2> /dev/null || true

 echo "${TMP_DIR}"
}

# Initialize lock directory
# Returns: LOCK_DIR (via echo, capture with: LOCK_DIR=$(__init_lock_dir))
function __init_lock_dir() {
 local FORCE_FALLBACK="${1:-false}"

 # Allow override via environment variable
 if [[ -n "${LOCK_DIR:-}" ]] && [[ "${FORCE_FALLBACK}" != "true" ]]; then
  echo "${LOCK_DIR}"
  return 0
 fi

 # Determine lock directory
 local LOCK_DIR
 if [[ "${FORCE_FALLBACK}" == "true" ]] || ! __is_installed; then
  # Fallback mode: use /tmp
  LOCK_DIR="/tmp/osm-notes-ingestion/locks"
 else
  # Installed mode: use /var/run (standard for lock files)
  LOCK_DIR="/var/run/osm-notes-ingestion"
 fi

 mkdir -p "${LOCK_DIR}" 2> /dev/null || {
  # If creation fails, fallback to /tmp
  LOCK_DIR="/tmp/osm-notes-ingestion/locks"
  mkdir -p "${LOCK_DIR}" 2> /dev/null || true
 }

 echo "${LOCK_DIR}"
}

# Initialize all directories at once
# Sets: LOG_DIR, TMP_DIR, LOCK_DIR, LOG_FILENAME, LOCK
function __init_directories() {
 local SCRIPT_BASENAME="${1:-}"
 local FORCE_FALLBACK="${2:-false}"

 # Use readonly BASENAME if available, otherwise use parameter or derive from $0
 local BASENAME_VALUE
 if [[ -n "${BASENAME:-}" ]] && declare -p BASENAME 2> /dev/null | grep -q "readonly"; then
  # BASENAME is readonly, use its value directly
  BASENAME_VALUE="${BASENAME}"
 elif [[ -n "${SCRIPT_BASENAME}" ]]; then
  # Use parameter value
  BASENAME_VALUE="${SCRIPT_BASENAME}"
 else
  # Derive from $0
  BASENAME_VALUE=$(basename -s .sh "${0:-unknown}" 2> /dev/null || echo "unknown")
 fi

 # Check FORCE_FALLBACK_MODE environment variable
 if [[ "${FORCE_FALLBACK_MODE:-false}" == "true" ]]; then
  FORCE_FALLBACK="true"
 fi

 # Initialize directories
 local LOG_DIR_VAL
 LOG_DIR_VAL=$(__init_log_dir "${BASENAME_VALUE}" "${FORCE_FALLBACK}")
 local TMP_DIR_VAL
 TMP_DIR_VAL=$(__init_tmp_dir "${BASENAME_VALUE}" "${FORCE_FALLBACK}")
 local LOCK_DIR_VAL
 LOCK_DIR_VAL=$(__init_lock_dir "${FORCE_FALLBACK}")

 # Export for use in scripts
 export LOG_DIR="${LOG_DIR_VAL}"
 export TMP_DIR="${TMP_DIR_VAL}"
 export LOCK_DIR="${LOCK_DIR_VAL}"

 # Set log filename
 export LOG_FILENAME="${LOG_DIR}/${BASENAME_VALUE}.log"

 # Set lock file path
 export LOCK="${LOCK_DIR}/${BASENAME_VALUE}.lock"

 # Log initialization (if logging is available)
 if declare -f __logd > /dev/null 2>&1; then
  __logd "Directory initialization:"
  __logd "  LOG_DIR: ${LOG_DIR}"
  __logd "  TMP_DIR: ${TMP_DIR}"
  __logd "  LOCK_DIR: ${LOCK_DIR}"
  __logd "  LOG_FILENAME: ${LOG_FILENAME}"
  __logd "  LOCK: ${LOCK}"
  if __is_installed; then
   __logd "  Mode: INSTALLED (production)"
  else
   __logd "  Mode: FALLBACK (testing/development)"
  fi
 fi
}
