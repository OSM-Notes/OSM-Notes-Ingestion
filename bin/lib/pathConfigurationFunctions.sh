#!/bin/bash

# Path Configuration Functions for OSM-Notes-Ingestion
# Centralized directory initialization with installation detection and fallback
#
# Author: Andres Gomez (AngocA)
# Version: 2026-02-01
# shellcheck disable=SC2034
# VERSION is used for version tracking but may not be referenced in code
VERSION="2026-02-01"

# shellcheck disable=SC2317,SC2155

# Detect if system is "installed" (production mode)
# Checks if standard directories exist and are writable
# shellcheck disable=SC2120
# Parameters are optional with default values; function can be called without arguments
function __is_installed() {
 local INSTALLED_LOG_DIR="${1:-/var/log/osm-notes-ingestion}"
 local INSTALLED_TMP_DIR="${2:-/var/tmp/osm-notes-ingestion}"
 local INSTALLED_LOCK_DIR="${3:-/var/run/osm-notes-ingestion}"

 # Check if directories exist and are writable
 if [[ -d "${INSTALLED_LOG_DIR}" ]] && [[ -w "${INSTALLED_LOG_DIR}" ]] \
  && [[ -d "${INSTALLED_TMP_DIR}" ]] && [[ -w "${INSTALLED_TMP_DIR}" ]] \
  && [[ -d "${INSTALLED_LOCK_DIR}" ]] && [[ -w "${INSTALLED_LOCK_DIR}" ]]; then
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
 # shellcheck disable=SC2119
 # __is_installed is called without arguments intentionally (uses default values)
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
 # shellcheck disable=SC2119
 # __is_installed is called without arguments intentionally (uses default values)
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
# Uses fallback mode when FORCE_FALLBACK=true or when installed directories don't exist
# Returns error code if LOCK_DIR override is invalid (does not fallback silently)
function __init_lock_dir() {
 local FORCE_FALLBACK="${1:-false}"

 # Allow override via environment variable
 if [[ -n "${LOCK_DIR:-}" ]] && [[ "${FORCE_FALLBACK}" != "true" ]]; then
  # Verify the override directory exists and is writable
  if [[ ! -d "${LOCK_DIR}" ]] || [[ ! -w "${LOCK_DIR}" ]]; then
   echo "ERROR: LOCK_DIR override '${LOCK_DIR}' does not exist or is not writable" >&2
   # Return error instead of silently falling back when override is explicitly set
   return "${ERROR_MISSING_LIBRARY:-241}"
  else
   echo "${LOCK_DIR}"
   return 0
  fi
 fi

 # Determine base lock directory
 local BASE_LOCK_DIR
 # shellcheck disable=SC2119
 # __is_installed is called without arguments intentionally (uses default values)
 if [[ "${FORCE_FALLBACK}" == "true" ]] || ! __is_installed; then
  # Fallback mode: use /tmp (non-persistent, for testing)
  BASE_LOCK_DIR="/tmp/osm-notes-ingestion/locks"
  if ! mkdir -p "${BASE_LOCK_DIR}" 2> /dev/null; then
   # If creation fails, try alternative location
   BASE_LOCK_DIR="/tmp/osm-notes-ingestion-locks"
   if ! mkdir -p "${BASE_LOCK_DIR}" 2> /dev/null; then
    # Last resort: use /tmp directly
    BASE_LOCK_DIR="/tmp"
   fi
  fi
  # Ensure directory is writable
  chmod 777 "${BASE_LOCK_DIR}" 2> /dev/null || true
 else
  # Installed mode: use /var/run (standard for lock files)
  BASE_LOCK_DIR="/var/run/osm-notes-ingestion"
  # Verify directory exists and is writable
  if [[ ! -d "${BASE_LOCK_DIR}" ]] || [[ ! -w "${BASE_LOCK_DIR}" ]]; then
   # Fallback to /tmp if installed directory doesn't work
   echo "WARNING: Lock directory '${BASE_LOCK_DIR}' does not exist or is not writable, using fallback" >&2
   BASE_LOCK_DIR="/tmp/osm-notes-ingestion/locks"
   mkdir -p "${BASE_LOCK_DIR}" 2> /dev/null || {
    BASE_LOCK_DIR="/tmp"
   }
   chmod 777 "${BASE_LOCK_DIR}" 2> /dev/null || true
  fi
 fi

 echo "${BASE_LOCK_DIR}"
}

##
# Initializes all directories at once (logs, temp, locks)
# Initializes log, temporary, and lock directories based on installation status and script type.
# Detects if system is installed (production mode) or uses fallback mode (testing). Creates
# directories if needed and exports environment variables for use by calling scripts.
# Handles script type detection (daemon, monitoring, processing) for subdirectory organization.
#
# Parameters:
#   $1: SCRIPT_BASENAME - Script basename for directory naming (optional, uses BASENAME or $0 if not provided)
#   $2: FORCE_FALLBACK - If "true", forces fallback mode (/tmp) even if installed (optional, default: false)
#
# Returns:
#   0: Success - All directories initialized successfully
#   ERROR_MISSING_LIBRARY: Failure - Directory initialization failed
#
# Error codes:
#   0: Success - All directories initialized and exported
#   ERROR_MISSING_LIBRARY: Log directory initialization failed
#   ERROR_MISSING_LIBRARY: Temporary directory initialization failed
#   ERROR_MISSING_LIBRARY: Lock directory initialization failed
#
# Error conditions:
#   0: Success - All directories initialized successfully
#   ERROR_MISSING_LIBRARY: Failed to initialize log directory
#   ERROR_MISSING_LIBRARY: Failed to initialize temporary directory
#   ERROR_MISSING_LIBRARY: Failed to initialize lock directory
#
# Context variables:
#   Reads:
#     - BASENAME: Script basename (readonly, optional)
#     - FORCE_FALLBACK_MODE: If "true", forces fallback mode (optional)
#     - LOG_DIR: Override log directory (optional, if set uses this instead)
#     - TMP_DIR: Override temporary directory (optional, if set uses this instead)
#     - LOCK_DIR: Override lock directory (optional, if set uses this instead)
#     - ERROR_MISSING_LIBRARY: Error code for missing library (optional, default: 241)
#   Sets:
#     - LOG_DIR: Log directory path (exported)
#     - TMP_DIR: Temporary directory path (exported)
#     - LOCK_DIR: Lock directory path (exported)
#     - LOG_FILENAME: Log file path (exported)
#     - LOCK: Lock file path (exported)
#   Modifies:
#     - Creates directories if they don't exist
#
# Side effects:
#   - Detects installation status (production vs fallback mode)
#   - Creates log directory (with subdirectory based on script type)
#   - Creates temporary directory (with subdirectory based on script type)
#   - Creates lock directory (production: /var/run, fallback: /tmp)
#   - Exports directory paths as environment variables
#   - Sets log filename and lock file path
#   - Writes log messages (if logging available)
#   - File operations: Creates directories (mkdir -p)
#   - No database or network operations
#
# Notes:
#   - Detects installation status by checking standard directories (/var/log, /var/tmp, /var/run)
#   - Production mode: Uses /var/log, /var/tmp, /var/run (persistent)
#   - Fallback mode: Uses /tmp subdirectories (non-persistent, for testing)
#   - Script type detection: daemon, monitoring, processing (for subdirectory organization)
#   - Respects FORCE_FALLBACK_MODE environment variable
#   - Respects directory override environment variables (LOG_DIR, TMP_DIR, LOCK_DIR)
#   - Critical function: Required before any file operations in scripts
#   - Used by all processing scripts for directory initialization
#
# Example:
#   __init_directories "processAPINotes"
#   # Initializes directories and exports LOG_DIR, TMP_DIR, LOCK_DIR, LOG_FILENAME, LOCK
#
#   export FORCE_FALLBACK_MODE=true
#   __init_directories "processAPINotesDaemon" "true"
#   # Forces fallback mode even if installed
#
# Related: __init_log_dir() (initializes log directory)
# Related: __init_tmp_dir() (initializes temporary directory)
# Related: __init_lock_dir() (initializes lock directory)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

 # Initialize directories with error handling
 local LOG_DIR_VAL
 LOG_DIR_VAL=$(__init_log_dir "${BASENAME_VALUE}" "${FORCE_FALLBACK}" 2> /dev/null)
 if [[ -z "${LOG_DIR_VAL}" ]]; then
  # Try fallback mode as last resort
  if [[ "${FORCE_FALLBACK}" != "true" ]]; then
   LOG_DIR_VAL=$(__init_log_dir "${BASENAME_VALUE}" "true" 2> /dev/null)
   if [[ -z "${LOG_DIR_VAL}" ]]; then
    echo "ERROR: Failed to initialize log directory even in fallback mode" >&2
    return "${ERROR_MISSING_LIBRARY:-241}"
   fi
  else
   echo "ERROR: Failed to initialize log directory" >&2
   return "${ERROR_MISSING_LIBRARY:-241}"
  fi
 fi

 local TMP_DIR_VAL
 TMP_DIR_VAL=$(__init_tmp_dir "${BASENAME_VALUE}" "${FORCE_FALLBACK}" 2> /dev/null)
 if [[ -z "${TMP_DIR_VAL}" ]]; then
  # Try fallback mode as last resort
  if [[ "${FORCE_FALLBACK}" != "true" ]]; then
   TMP_DIR_VAL=$(__init_tmp_dir "${BASENAME_VALUE}" "true" 2> /dev/null)
   if [[ -z "${TMP_DIR_VAL}" ]]; then
    echo "ERROR: Failed to initialize temporary directory even in fallback mode" >&2
    return "${ERROR_MISSING_LIBRARY:-241}"
   fi
  else
   echo "ERROR: Failed to initialize temporary directory" >&2
   return "${ERROR_MISSING_LIBRARY:-241}"
  fi
 fi

 local LOCK_DIR_VAL
 local LOCK_DIR_ERROR
 LOCK_DIR_ERROR=$(mktemp) || {
  echo "ERROR: Cannot create temporary file for error capture" >&2
  return "${ERROR_MISSING_LIBRARY:-241}"
 }
 LOCK_DIR_VAL=$(__init_lock_dir "${FORCE_FALLBACK}" 2> "${LOCK_DIR_ERROR}")
 local LOCK_DIR_EXIT_CODE=$?
 # Display any error messages
 if [[ -s "${LOCK_DIR_ERROR}" ]]; then
  cat "${LOCK_DIR_ERROR}" >&2
 fi
 rm -f "${LOCK_DIR_ERROR}"
 # If function returned error code, handle it
 if [[ ${LOCK_DIR_EXIT_CODE} -ne 0 ]]; then
  # If LOCK_DIR override was invalid, fail immediately (don't fallback silently)
  if [[ -n "${LOCK_DIR:-}" ]] && [[ "${FORCE_FALLBACK}" != "true" ]]; then
   echo "ERROR: Invalid LOCK_DIR override detected. Cannot proceed." >&2
   return "${ERROR_MISSING_LIBRARY:-241}"
  fi
  # For other errors, try fallback mode
  if [[ "${FORCE_FALLBACK}" != "true" ]]; then
   LOCK_DIR_ERROR=$(mktemp) || {
    echo "ERROR: Cannot create temporary file for error capture" >&2
    return "${ERROR_MISSING_LIBRARY:-241}"
   }
   LOCK_DIR_VAL=$(__init_lock_dir "true" 2> "${LOCK_DIR_ERROR}")
   LOCK_DIR_EXIT_CODE=$?
   if [[ -s "${LOCK_DIR_ERROR}" ]]; then
    cat "${LOCK_DIR_ERROR}" >&2
   fi
   rm -f "${LOCK_DIR_ERROR}"
   if [[ ${LOCK_DIR_EXIT_CODE} -ne 0 ]] || [[ -z "${LOCK_DIR_VAL}" ]]; then
    echo "ERROR: Failed to initialize lock directory even in fallback mode" >&2
    return "${ERROR_MISSING_LIBRARY:-241}"
   fi
  else
   echo "ERROR: Failed to initialize lock directory" >&2
   return "${ERROR_MISSING_LIBRARY:-241}"
  fi
 fi
 if [[ -z "${LOCK_DIR_VAL}" ]]; then
  echo "ERROR: Lock directory initialization returned empty value" >&2
  return "${ERROR_MISSING_LIBRARY:-241}"
 fi

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
  # shellcheck disable=SC2119
  # __is_installed is called without arguments intentionally (uses default values)
  if __is_installed; then
   __logd "  Mode: INSTALLED (production)"
  else
   __logd "  Mode: FALLBACK (testing/development)"
  fi
 fi
}
