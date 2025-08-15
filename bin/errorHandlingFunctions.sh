#!/bin/bash

# Error Handling Functions for OSM-Notes-profile
# This file contains error handling and retry functions.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

# Define version variable
VERSION="2025-08-13"

# shellcheck disable=SC2317,SC2155

# Circuit breaker state
declare -A CIRCUIT_BREAKER_STATE
declare -A CIRCUIT_BREAKER_FAILURE_COUNT
declare -A CIRCUIT_BREAKER_LAST_FAILURE_TIME

# Show help function
function __show_help() {
 echo "Error Handling Functions for OSM-Notes-profile"
 echo "This file contains error handling and retry functions."
 echo
 echo "Usage: source bin/errorHandlingFunctions.sh"
 echo
 echo "Available functions:"

 echo "  __circuit_breaker_execute   - Circuit breaker pattern"
 echo "  __download_with_retry       - Download with retry logic"
 echo "  __api_call_with_retry       - API calls with retry"
 echo "  __database_operation_with_retry - Database operations with retry"
 echo "  __file_operation_with_retry - File operations with retry"
 echo "  __check_network_connectivity - Network connectivity check"
 echo "  __handle_error_with_cleanup - Error handling with cleanup"
 echo
 echo "Author: Andres Gomez (AngocA)"
 echo "Version: ${VERSION}"
 exit 1
}

# Circuit breaker pattern implementation
function __circuit_breaker_execute() {
 __log_start
 local OPERATION_NAME="${1}"
 local COMMAND="${2}"
 local FAILURE_THRESHOLD="${3:-5}"
 local TIMEOUT="${4:-30}"
 local RESET_TIMEOUT="${5:-60}"

 if [[ -z "${OPERATION_NAME}" ]] || [[ -z "${COMMAND}" ]]; then
  __loge "ERROR: Operation name and command are required"
  __log_finish
  return 1
 fi

 local CURRENT_TIME
 CURRENT_TIME=$(date +%s)

 local LAST_FAILURE_TIME="${CIRCUIT_BREAKER_LAST_FAILURE_TIME[${OPERATION_NAME}]:-0}"
 local FAILURE_COUNT="${CIRCUIT_BREAKER_FAILURE_COUNT[${OPERATION_NAME}]:-0}"
 local STATE="${CIRCUIT_BREAKER_STATE[${OPERATION_NAME}]:-CLOSED}"

 # Check if circuit breaker is open
 if [[ "${STATE}" == "OPEN" ]]; then
  local TIME_SINCE_LAST_FAILURE
  TIME_SINCE_LAST_FAILURE=$((CURRENT_TIME - LAST_FAILURE_TIME))

  if [[ "${TIME_SINCE_LAST_FAILURE}" -lt "${RESET_TIMEOUT}" ]]; then
   __logw "WARNING: Circuit breaker is OPEN for ${OPERATION_NAME}. Skipping operation."
   __log_finish
   return 1
  else
   __logi "Circuit breaker reset to HALF_OPEN for ${OPERATION_NAME}"
   CIRCUIT_BREAKER_STATE[${OPERATION_NAME}]="HALF_OPEN"
   STATE="HALF_OPEN"
  fi
 fi

 # Execute command with timeout
 local EXIT_CODE
 if timeout "${TIMEOUT}" bash -c "${COMMAND}"; then
  __logi "Operation ${OPERATION_NAME} succeeded"

  # Reset failure count on success
  CIRCUIT_BREAKER_FAILURE_COUNT[${OPERATION_NAME}]=0
  CIRCUIT_BREAKER_STATE[${OPERATION_NAME}]="CLOSED"

  __log_finish
  return 0
 else
  EXIT_CODE=$?
  __loge "ERROR: Operation ${OPERATION_NAME} failed with exit code ${EXIT_CODE}"

  # Update failure tracking
  CIRCUIT_BREAKER_FAILURE_COUNT[${OPERATION_NAME}]=$((FAILURE_COUNT + 1))
  CIRCUIT_BREAKER_LAST_FAILURE_TIME[${OPERATION_NAME}]=${CURRENT_TIME}

  # Check if threshold exceeded
  if [[ "${CIRCUIT_BREAKER_FAILURE_COUNT[${OPERATION_NAME}]}" -ge "${FAILURE_THRESHOLD}" ]]; then
   __logw "WARNING: Circuit breaker opened for ${OPERATION_NAME}"
   CIRCUIT_BREAKER_STATE[${OPERATION_NAME}]="OPEN"
  fi

  __log_finish
  return "${EXIT_CODE}"
 fi
}

# Download with retry
function __download_with_retry() {
 __log_start
 local URL="${1}"
 local OUTPUT_FILE="${2}"
 local MAX_ATTEMPTS="${3:-3}"
 local TIMEOUT="${4:-30}"

 if [[ -z "${URL}" ]] || [[ -z "${OUTPUT_FILE}" ]]; then
  __loge "ERROR: URL and output file are required"
  __log_finish
  return 1
 fi

 local COMMAND="curl -s -o '${OUTPUT_FILE}' '${URL}'"
 __circuit_breaker_execute "download_${URL}" "${COMMAND}" 3 "${TIMEOUT}" 120
 __log_finish
}

# API call with retry
function __api_call_with_retry() {
 __log_start
 local URL="${1}"
 local OUTPUT_FILE="${2}"
 local MAX_ATTEMPTS="${3:-3}"
 local TIMEOUT="${4:-30}"

 if [[ -z "${URL}" ]] || [[ -z "${OUTPUT_FILE}" ]]; then
  __loge "ERROR: URL and output file are required"
  __log_finish
  return 1
 fi

 local COMMAND="curl -s -o '${OUTPUT_FILE}' '${URL}'"
 __circuit_breaker_execute "api_call_${URL}" "${COMMAND}" 3 "${TIMEOUT}" 120
 __log_finish
}

# Database operation with retry
function __database_operation_with_retry() {
 __log_start
 local SQL_FILE="${1}"
 local MAX_ATTEMPTS="${2:-3}"
 local TIMEOUT="${3:-60}"

 if [[ -z "${SQL_FILE}" ]]; then
  __loge "ERROR: SQL file is required"
  __log_finish
  return 1
 fi

 if ! __validate_input_file "${SQL_FILE}" "SQL file"; then
  __log_finish
  return 1
 fi

 local COMMAND="PGPASSWORD='${DB_PASSWORD}' psql -h '${DB_HOST}' -p '${DB_PORT}' -U '${DB_USER}' -d '${DBNAME}' -f '${SQL_FILE}'"
 __circuit_breaker_execute "database_operation_${SQL_FILE}" "${COMMAND}" 3 "${TIMEOUT}" 300
 __log_finish
}

# File operation with retry
function __file_operation_with_retry() {
 __log_start
 local OPERATION="${1}"
 local SOURCE="${2}"
 local DESTINATION="${3}"
 local MAX_ATTEMPTS="${4:-3}"

 if [[ -z "${OPERATION}" ]] || [[ -z "${SOURCE}" ]]; then
  __loge "ERROR: Operation and source are required"
  __log_finish
  return 1
 fi

 local COMMAND
 case "${OPERATION}" in
 copy)
  if [[ -z "${DESTINATION}" ]]; then
   __loge "ERROR: Destination is required for copy operation"
   __log_finish
   return 1
  fi
  COMMAND="cp '${SOURCE}' '${DESTINATION}'"
  ;;
 move)
  if [[ -z "${DESTINATION}" ]]; then
   __loge "ERROR: Destination is required for move operation"
   __log_finish
   return 1
  fi
  COMMAND="mv '${SOURCE}' '${DESTINATION}'"
  ;;
 delete)
  COMMAND="rm -f '${SOURCE}'"
  ;;
 *)
  __loge "ERROR: Unsupported operation: ${OPERATION}"
  __log_finish
  return 1
  ;;
 esac

 __circuit_breaker_execute "file_operation_${OPERATION}_${SOURCE}" "${COMMAND}" 3 30 120
 __log_finish
}

# Check network connectivity
function __check_network_connectivity() {
 __log_start
 local TIMEOUT="${1:-10}"
 local TEST_URL="${2:-https://www.google.com}"

 __logi "=== CHECKING NETWORK CONNECTIVITY ==="
 __logd "Testing connectivity to ${TEST_URL} with timeout ${TIMEOUT}s"

 if timeout "${TIMEOUT}" curl -s --max-time "${TIMEOUT}" "${TEST_URL}" > /dev/null 2>&1; then
  __logi "Network connectivity confirmed"
  __logi "=== NETWORK CONNECTIVITY CHECK COMPLETED SUCCESSFULLY ==="
  __log_finish
  return 0
 else
  __loge "ERROR: Network connectivity failed"
  __logi "=== NETWORK CONNECTIVITY CHECK FAILED ==="
  __log_finish
  return 1
 fi
}

# Handle error with cleanup
function __handle_error_with_cleanup() {
 __log_start
 local ERROR_CODE="${1}"
 local ERROR_MESSAGE="${2}"
 local CLEANUP_COMMAND="${3:-}"

 __loge "=== ERROR HANDLING WITH CLEANUP === Error occurred: ${ERROR_MESSAGE}"

 # Execute cleanup command if provided and CLEAN is true
 if [[ -n "${CLEANUP_COMMAND}" ]] && [[ "${CLEAN:-true}" == "true" ]]; then
  echo "Executing cleanup command: ${CLEANUP_COMMAND}"
  __logd "Executing cleanup command: ${CLEANUP_COMMAND}"
  if eval "${CLEANUP_COMMAND}"; then
   __logd "Cleanup command executed successfully"
  else
   __logw "WARNING: Cleanup command failed"
  fi
 elif [[ -n "${CLEANUP_COMMAND}" ]]; then
  echo "Skipping cleanup command due to CLEAN=false: ${CLEANUP_COMMAND}"
  __logd "Skipping cleanup command due to CLEAN=false: ${CLEANUP_COMMAND}"
 fi

 # Generate failed execution file if enabled
 if [[ "${GENERATE_FAILED_FILE}" == "true" ]]; then
  echo "$(date): ${ERROR_MESSAGE}" >> "${FAILED_EXECUTION_FILE}"
 fi

 __log_finish
 return "${ERROR_CODE}"
}

# Get circuit breaker status
function __get_circuit_breaker_status() {
 __log_start
 local OPERATION_NAME="${1}"

 if [[ -z "${OPERATION_NAME}" ]]; then
  __loge "ERROR: Operation name is required"
  __log_finish
  return 1
 fi

 local STATE="${CIRCUIT_BREAKER_STATE[${OPERATION_NAME}]:-CLOSED}"
 local FAILURE_COUNT="${CIRCUIT_BREAKER_FAILURE_COUNT[${OPERATION_NAME}]:-0}"
 local LAST_FAILURE_TIME="${CIRCUIT_BREAKER_LAST_FAILURE_TIME[${OPERATION_NAME}]:-0}"

 echo "Operation: ${OPERATION_NAME}"
 echo "State: ${STATE}"
 echo "Failure Count: ${FAILURE_COUNT}"
 echo "Last Failure Time: ${LAST_FAILURE_TIME}"
 __log_finish
}

# Reset circuit breaker
function __reset_circuit_breaker() {
 local OPERATION_NAME="${1}"
 __log_start

 if [[ -z "${OPERATION_NAME}" ]]; then
  __loge "ERROR: Operation name is required"
  __log_finish
  return 1
 fi

 __logi "Resetting circuit breaker for ${OPERATION_NAME}"
 CIRCUIT_BREAKER_STATE[${OPERATION_NAME}]="CLOSED"
 CIRCUIT_BREAKER_FAILURE_COUNT[${OPERATION_NAME}]=0
 CIRCUIT_BREAKER_LAST_FAILURE_TIME[${OPERATION_NAME}]=0
 __log_finish
}

# Retry file operation
function __retry_file_operation() {
 __log_start
 local OPERATION="${1}"
 local SOURCE="${2}"
 local DESTINATION="${3:-}"
 local MAX_ATTEMPTS="${4:-3}"
 local CLEANUP_COMMAND="${5:-}"

 if [[ -z "${OPERATION}" ]] || [[ -z "${SOURCE}" ]]; then
  __loge "ERROR: Operation and source are required"
  __log_finish
  return 1
 fi

 local ATTEMPT=1
 local DELAY=1

 while [[ "${ATTEMPT}" -le "${MAX_ATTEMPTS}" ]]; do
  __logd "File operation attempt ${ATTEMPT}/${MAX_ATTEMPTS}: ${OPERATION} ${SOURCE}"

  case "${OPERATION}" in
  copy)
   if [[ -z "${DESTINATION}" ]]; then
    __loge "ERROR: Destination is required for copy operation"
    __log_finish
    return 1
   fi
   if cp "${SOURCE}" "${DESTINATION}" 2> /dev/null; then
    __logi "File copy succeeded on attempt ${ATTEMPT}"
    __log_finish
    return 0
   fi
   ;;
  move)
   if [[ -z "${DESTINATION}" ]]; then
    __loge "ERROR: Destination is required for move operation"
    __log_finish
    return 1
   fi
   if mv "${SOURCE}" "${DESTINATION}" 2> /dev/null; then
    __logi "File move succeeded on attempt ${ATTEMPT}"
    __log_finish
    return 0
   fi
   ;;
  delete)
   if rm -f "${SOURCE}" 2> /dev/null; then
    __logi "File delete succeeded on attempt ${ATTEMPT}"
    __log_finish
    return 0
   fi
   ;;
  *)
   __loge "ERROR: Unsupported operation: ${OPERATION}"
   __log_finish
   return 1
   ;;
  esac

  __logw "WARNING: File operation failed on attempt ${ATTEMPT}"

  # Execute cleanup command if provided
  if [[ -n "${CLEANUP_COMMAND}" ]]; then
   __logd "Executing cleanup command: ${CLEANUP_COMMAND}"
   eval "${CLEANUP_COMMAND}" || true
  fi

  if [[ "${ATTEMPT}" -eq "${MAX_ATTEMPTS}" ]]; then
   __loge "ERROR: File operation failed after ${MAX_ATTEMPTS} attempts"
   __log_finish
   return 1
  fi

  __logd "Waiting ${DELAY} seconds before retry"
  sleep "${DELAY}"

  ATTEMPT=$((ATTEMPT + 1))
  DELAY=$((DELAY * 2))
  if [[ "${DELAY}" -gt 60 ]]; then
   DELAY=60
  fi
 done

 __log_finish
 return 1
}
