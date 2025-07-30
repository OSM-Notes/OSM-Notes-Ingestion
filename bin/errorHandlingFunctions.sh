#!/bin/bash

# Error Handling Functions for OSM-Notes-profile
# This file contains error handling and retry functions used across different scripts.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

# shellcheck disable=SC2317,SC2155

# Circuit breaker state
declare -A CIRCUIT_BREAKER_STATE
declare -A CIRCUIT_BREAKER_FAILURE_COUNT
declare -A CIRCUIT_BREAKER_LAST_FAILURE_TIME

# Retry with backoff
function __retry_with_backoff() {
 local max_attempts="${1:-3}"
 local base_delay="${2:-1}"
 local max_delay="${3:-60}"
 local command="${4:-}"

 if [[ -z "${command}" ]]; then
  __loge "ERROR: No command provided for retry"
  return 1
 fi

 local attempt=1
 local delay="${base_delay}"

 while [[ "${attempt}" -le "${max_attempts}" ]]; do
  __logd "Attempt ${attempt}/${max_attempts}: ${command}"

  if eval "${command}"; then
   __logi "Command succeeded on attempt ${attempt}"
   return 0
  else
   local exit_code=$?
   __logw "Command failed on attempt ${attempt} with exit code ${exit_code}"

   if [[ "${attempt}" -eq "${max_attempts}" ]]; then
    __loge "ERROR: Command failed after ${max_attempts} attempts"
    return "${exit_code}"
   fi

   # Calculate delay with exponential backoff
   delay=$((delay * 2))
   if [[ "${delay}" -gt "${max_delay}" ]]; then
    delay="${max_delay}"
   fi

   __logd "Waiting ${delay} seconds before retry"
   sleep "${delay}"
   ((attempt++))
  fi
 done

 return 1
}

# Circuit breaker execute
function __circuit_breaker_execute() {
 local operation_name="${1}"
 local command="${2}"
 local failure_threshold="${3:-5}"
 local timeout="${4:-30}"
 local reset_timeout="${5:-60}"

 if [[ -z "${operation_name}" ]] || [[ -z "${command}" ]]; then
  __loge "ERROR: Operation name and command are required"
  return 1
 fi

 # Check circuit breaker state
 local current_time
 current_time=$(date +%s)
 local last_failure_time="${CIRCUIT_BREAKER_LAST_FAILURE_TIME[${operation_name}]:-0}"
 local failure_count="${CIRCUIT_BREAKER_FAILURE_COUNT[${operation_name}]:-0}"
 local state="${CIRCUIT_BREAKER_STATE[${operation_name}]:-CLOSED}"

 # Check if circuit breaker is open and should be reset
 if [[ "${state}" == "OPEN" ]]; then
  local time_since_last_failure
  time_since_last_failure=$((current_time - last_failure_time))

  if [[ "${time_since_last_failure}" -ge "${reset_timeout}" ]]; then
   __logi "Circuit breaker for ${operation_name} resetting to HALF_OPEN"
   CIRCUIT_BREAKER_STATE[${operation_name}]="HALF_OPEN"
   state="HALF_OPEN"
  else
   __logw "Circuit breaker for ${operation_name} is OPEN, skipping execution"
   return 1
  fi
 fi

 # Execute command with timeout
 local exit_code
 if timeout "${timeout}" bash -c "${command}"; then
  exit_code=0
 else
  exit_code=$?
 fi

 # Update circuit breaker state based on result
 if [[ "${exit_code}" -eq 0 ]]; then
  # Success - close circuit breaker
  CIRCUIT_BREAKER_STATE[${operation_name}]="CLOSED"
  CIRCUIT_BREAKER_FAILURE_COUNT[${operation_name}]=0
  __logd "Circuit breaker for ${operation_name} is CLOSED"
  return 0
 else
  # Failure - update failure count and potentially open circuit breaker
  CIRCUIT_BREAKER_FAILURE_COUNT[${operation_name}]=$((failure_count + 1))
  CIRCUIT_BREAKER_LAST_FAILURE_TIME[${operation_name}]="${current_time}"

  if [[ "${CIRCUIT_BREAKER_FAILURE_COUNT[${operation_name}]}" -ge "${failure_threshold}" ]]; then
   CIRCUIT_BREAKER_STATE[${operation_name}]="OPEN"
   __logw "Circuit breaker for ${operation_name} is now OPEN"
  fi

  return "${exit_code}"
 fi
}

# Download with retry
function __download_with_retry() {
 local url="${1}"
 local output_file="${2}"
 local max_attempts="${3:-3}"
 local timeout="${4:-30}"

 if [[ -z "${url}" ]] || [[ -z "${output_file}" ]]; then
  __loge "ERROR: URL and output file are required"
  return 1
 fi

 local command="curl -s -o '${output_file}' '${url}'"
 __circuit_breaker_execute "download_${url}" "${command}" 3 "${timeout}" 120
}

# API call with retry
function __api_call_with_retry() {
 local url="${1}"
 local output_file="${2}"
 local max_attempts="${3:-3}"
 local timeout="${4:-30}"

 if [[ -z "${url}" ]] || [[ -z "${output_file}" ]]; then
  __loge "ERROR: URL and output file are required"
  return 1
 fi

 local command="curl -s -o '${output_file}' '${url}'"
 __circuit_breaker_execute "api_call_${url}" "${command}" 3 "${timeout}" 120
}

# Database operation with retry
function __database_operation_with_retry() {
 local sql_file="${1}"
 local max_attempts="${2:-3}"
 local timeout="${3:-60}"

 if [[ -z "${sql_file}" ]]; then
  __loge "ERROR: SQL file is required"
  return 1
 fi

 if ! __validate_input_file "${sql_file}" "SQL file"; then
  return 1
 fi

 local command="PGPASSWORD='${DB_PASSWORD}' psql -h '${DB_HOST}' -p '${DB_PORT}' -U '${DB_USER}' -d '${DBNAME}' -f '${sql_file}'"
 __circuit_breaker_execute "database_operation_${sql_file}" "${command}" 3 "${timeout}" 300
}

# File operation with retry
function __file_operation_with_retry() {
 local operation="${1}"
 local source="${2}"
 local destination="${3}"
 local max_attempts="${4:-3}"

 if [[ -z "${operation}" ]] || [[ -z "${source}" ]]; then
  __loge "ERROR: Operation and source are required"
  return 1
 fi

 local command
 case "${operation}" in
 copy)
  if [[ -z "${destination}" ]]; then
   __loge "ERROR: Destination is required for copy operation"
   return 1
  fi
  command="cp '${source}' '${destination}'"
  ;;
 move)
  if [[ -z "${destination}" ]]; then
   __loge "ERROR: Destination is required for move operation"
   return 1
  fi
  command="mv '${source}' '${destination}'"
  ;;
 delete)
  command="rm -f '${source}'"
  ;;
 *)
  __loge "ERROR: Unsupported operation: ${operation}"
  return 1
  ;;
 esac

 __circuit_breaker_execute "file_operation_${operation}_${source}" "${command}" 3 30 120
}

# Check network connectivity
function __check_network_connectivity() {
 local timeout="${1:-10}"
 local test_url="${2:-https://www.google.com}"

 __logd "Checking network connectivity to ${test_url} with timeout ${timeout}s"

 if timeout "${timeout}" curl -s --max-time "${timeout}" "${test_url}" > /dev/null 2>&1; then
  __logi "Network connectivity confirmed"
  return 0
 else
  __loge "ERROR: Network connectivity check failed"
  return 1
 fi
}

# Handle error with cleanup
function __handle_error_with_cleanup() {
 local error_code="${1}"
 local error_message="${2}"
 local cleanup_command="${3:-}"

 __loge "ERROR: Error occurred: ${error_message}"

 # Execute cleanup command if provided
 if [[ -n "${cleanup_command}" ]]; then
  __logd "Executing cleanup command: ${cleanup_command}"
  if eval "${cleanup_command}"; then
   __logd "Cleanup command executed successfully"
  else
   __logw "WARNING: Cleanup command failed"
  fi
 fi

 # Generate failed execution file if enabled
 if [[ "${GENERATE_FAILED_FILE}" == "true" ]]; then
  echo "$(date): ${error_message}" >> "${FAILED_EXECUTION_FILE}"
 fi

 return "${error_code}"
}

# Get circuit breaker status
function __get_circuit_breaker_status() {
 local operation_name="${1}"

 if [[ -z "${operation_name}" ]]; then
  __loge "ERROR: Operation name is required"
  return 1
 fi

 local state="${CIRCUIT_BREAKER_STATE[${operation_name}]:-CLOSED}"
 local failure_count="${CIRCUIT_BREAKER_FAILURE_COUNT[${operation_name}]:-0}"
 local last_failure_time="${CIRCUIT_BREAKER_LAST_FAILURE_TIME[${operation_name}]:-0}"

 echo "Operation: ${operation_name}"
 echo "State: ${state}"
 echo "Failure Count: ${failure_count}"
 echo "Last Failure Time: ${last_failure_time}"
}

# Reset circuit breaker
function __reset_circuit_breaker() {
 local operation_name="${1}"

 if [[ -z "${operation_name}" ]]; then
  __loge "ERROR: Operation name is required"
  return 1
 fi

 __logi "Resetting circuit breaker for ${operation_name}"
 CIRCUIT_BREAKER_STATE[${operation_name}]="CLOSED"
 CIRCUIT_BREAKER_FAILURE_COUNT[${operation_name}]=0
 CIRCUIT_BREAKER_LAST_FAILURE_TIME[${operation_name}]=0
}

# Retry file operation
function __retry_file_operation() {
 local operation="${1}"
 local source="${2}"
 local destination="${3:-}"
 local max_attempts="${4:-3}"
 local cleanup_command="${5:-}"

 if [[ -z "${operation}" ]] || [[ -z "${source}" ]]; then
  __loge "ERROR: Operation and source are required"
  return 1
 fi

 local attempt=1
 local delay=1

 while [[ "${attempt}" -le "${max_attempts}" ]]; do
  __logd "File operation attempt ${attempt}/${max_attempts}: ${operation} ${source}"

  case "${operation}" in
  copy)
   if [[ -z "${destination}" ]]; then
    __loge "ERROR: Destination is required for copy operation"
    return 1
   fi
   if cp "${source}" "${destination}" 2> /dev/null; then
    __logi "File copy succeeded on attempt ${attempt}"
    return 0
   fi
   ;;
  move)
   if [[ -z "${destination}" ]]; then
    __loge "ERROR: Destination is required for move operation"
    return 1
   fi
   if mv "${source}" "${destination}" 2> /dev/null; then
    __logi "File move succeeded on attempt ${attempt}"
    return 0
   fi
   ;;
  delete)
   if rm -f "${source}" 2> /dev/null; then
    __logi "File deletion succeeded on attempt ${attempt}"
    return 0
   fi
   ;;
  *)
   __loge "ERROR: Unsupported operation: ${operation}"
   return 1
   ;;
  esac

  __logw "File operation failed on attempt ${attempt}"

  if [[ "${attempt}" -eq "${max_attempts}" ]]; then
   __loge "ERROR: File operation failed after ${max_attempts} attempts"
   if [[ -n "${cleanup_command}" ]]; then
    __logd "Executing cleanup command: ${cleanup_command}"
    eval "${cleanup_command}" || true
   fi
   return 1
  fi

  # Exponential backoff
  delay=$((delay * 2))
  if [[ "${delay}" -gt 60 ]]; then
   delay=60
  fi

  __logd "Waiting ${delay} seconds before retry"
  sleep "${delay}"
  ((attempt++))
 done

 return 1
}
