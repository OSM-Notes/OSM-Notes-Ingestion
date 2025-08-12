#!/bin/bash

# Enhanced Bash Logger for OSM-Notes-profile
# Improved version maintaining all original functionality but with better code quality
#
# Original functionality preserved:
# - All log levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL
# - File logging with file descriptors
# - Function timing (start/finish)
# - Call stack tracing
# - Timestamp and location information
#
# Improvements:
# - Robust error handling
# - Better variable initialization
# - Cleaner code structure
# - Export compatibility
# - Test-friendly design
#
# Author: Andres Gomez (AngocA) - Enhanced version
# Version: 2025-08-11
# Based on: Dushyanth Jyothi's bash-logger

# === CONSTANTS AND CONFIGURATION ===
# Declare log levels array (not read-only to avoid BATS conflicts)
if [[ -z "${LOG_LEVELS_ORDER+x}" ]]; then
  declare -ga LOG_LEVELS_ORDER=("TRACE" "DEBUG" "INFO" "WARN" "ERROR" "FATAL")
fi

# Global variables with safe initialization
declare -g __log_level="${LOG_LEVEL:-INFO}"
declare -g __log_fd=""
declare -g __logger_script_start_time=""
declare -g __logger_function_start_time=""
declare -gA __logger_run_times=()

# Initialize timing
__logger_script_start_time=$(date +%s)
__logger_function_start_time=$(date +%s)

# === UTILITY FUNCTIONS ===

# Get numeric level for comparison
__get_log_level_number() {
 local level="$1"
 for i in "${!LOG_LEVELS_ORDER[@]}"; do
   if [[ "${LOG_LEVELS_ORDER[$i]}" == "$level" ]]; then
     echo "$i"
     return 0
   fi
 done
 echo "2"  # Default to INFO level
}

# Check if message should be logged based on level
__should_log_message() {
 local message_level="$1"
 local current_level_num
 local message_level_num
 
 current_level_num=$(__get_log_level_number "${__log_level}")
 message_level_num=$(__get_log_level_number "$message_level")
 
 [[ "$message_level_num" -ge "$current_level_num" ]]
}

# Get caller information safely
__get_caller_info() {
 local script_name="${BASH_SOURCE[2]:-unknown}"
 local function_name="${FUNCNAME[2]:-main}"
 local line_number="${BASH_LINENO[1]:-0}"
 
 # Clean script name (remove path)
 script_name="${script_name##*/}"
 
 echo "${script_name}:${function_name}:${line_number}"
}

# Generate timestamp
__get_timestamp() {
 date '+%Y-%m-%d %H:%M:%S'
}

# Format log message
__format_log_message() {
 local level="$1"
 local message="$2"
 local caller_info="$3"
 local timestamp
 
 timestamp=$(__get_timestamp)
 if [[ "$level" == "INFO" && "$message" == \#--* ]]; then
   # Special format for __log_start messages
   echo "${timestamp} - ${caller_info} - ${message}"
 elif [[ "$level" == "INFO" && "$message" == \|--* ]]; then
   # Special format for __log_finish messages  
   echo "${timestamp} - ${caller_info} - ${message}"
 else
   # Standard format with level
   echo "${timestamp} - ${caller_info} - ${level} - ${message}"
 fi
}

# === CORE LOGGING FUNCTIONS ===

# Set log level with validation
__set_log_level() {
 local level="${1:-INFO}"
 
 if [[ -z "$level" ]]; then
   echo "No log level provided, setting to INFO log level"
   __log_level="INFO"
   return 0
 fi
 
 # Validate level
 for valid_level in "${LOG_LEVELS_ORDER[@]}"; do
   if [[ "$level" == "$valid_level" ]]; then
     __log_level="$level"
     return 0
   fi
 done
 
 echo "Log level provided '$level' is not valid, setting to INFO log level"
 __log_level="INFO"
 return 1
}

# Set log file with validation
__set_log_file() {
 local -r LOG_FILE="${1}"
 
 if [[ -z "${LOG_FILE}" ]]; then
   echo "Log file not defined."
   return 1
 else
   if ! touch "${LOG_FILE}"; then
     echo "It is not possible to create this file: ${LOG_FILE}."
     return 1
   else
     if [[ ! -w "${LOG_FILE}" ]]; then
       echo "It is not possible to write in this file: ${LOG_FILE}."
       return 1
     else
       __log_fd="${LOG_FILE}"
       exec {__log_fd}<> "${LOG_FILE}"
       return 0
     fi
   fi
 fi
}

# Output log message to appropriate destination
__output_log() {
 local message="$1"
 local to_stderr="${2:-false}"
 
 if [[ -n "$__log_fd" ]]; then
   echo "$message" >&${__log_fd}
 else
   if [[ "$to_stderr" == "true" ]]; then
     echo "$message" >&2
   else
     echo "$message"
   fi
 fi
}

# Generate call stack for TRACE levels
__generate_call_stack() {
 local __bl_functions_length="${#FUNCNAME[@]}"
 local __bl_script_name="${BASH_SOURCE[0]}"
 local __bl_function_name="${FUNCNAME[0]}"
 local __bl_called_line_number="${BASH_LINENO[0]}"
 local __bl_time_and_date
 
 __bl_script_name="${__bl_script_name##*/}"
 __bl_time_and_date="$(date '+%Y-%m-%d %H:%M:%S')"
 
 # First, log the stack header
 local LOG="${__bl_time_and_date} - ${__bl_script_name}:${__bl_function_name}:${__bl_called_line_number} - TRACE - Execution call stack:"
 if [[ -z "${__log_fd}" ]]; then
   echo "${LOG}"
 else
   echo "${LOG}" >&${__log_fd}
 fi
 
 for ((i = 0; i < __bl_functions_length; i++)); do
   if (($i != $((__bl_functions_length - 1)))); then
     if [[ "${BASH_SOURCE[$i]}" != *"bash_logger"* ]]; then
       LOG="   ${BASH_SOURCE[$i]//.\//}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}(..)"
       if [[ -z "${__log_fd}" ]]; then
         echo "${LOG}"
       else
         echo "${LOG}" >&${__log_fd}
       fi
     fi
   else
     LOG="    ${BASH_SOURCE[$i]//.\//}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}(..)"
     if [[ -z "${__log_fd}" ]]; then
       echo "${LOG}"
     else
       echo "${LOG}" >&${__log_fd}
     fi
   fi
 done
}

# Generate call stack for ERROR levels
__generate_call_stack_error() {
 local __bl_functions_length="${#FUNCNAME[@]}"
 local __bl_script_name="${BASH_SOURCE[0]}"
 local __bl_function_name="${FUNCNAME[0]}"
 local __bl_called_line_number="${BASH_LINENO[0]}"
 local __bl_time_and_date
 
 __bl_script_name="${__bl_script_name##*/}"
 __bl_time_and_date="$(date '+%Y-%m-%d %H:%M:%S')"
 
 # First, log the stack header
 local LOG="${__bl_time_and_date} - ${__bl_script_name}:${__bl_function_name}:${__bl_called_line_number} - ERROR - Execution call stack:"
 if [[ -z "${__log_fd}" ]]; then
   echo "${LOG}" >&2
 else
   echo "${LOG}" >&${__log_fd}
 fi
 
 for ((i = 0; i < __bl_functions_length; i++)); do
   if (($i != $((__bl_functions_length - 1)))); then
     if [[ "${BASH_SOURCE[$i]}" != *"bash_logger"* ]]; then
       LOG="   ${BASH_SOURCE[$i]//.\//}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}(..)"
       if [[ -z "${__log_fd}" ]]; then
         echo "${LOG}" >&2
       else
         echo "${LOG}" >&${__log_fd}
       fi
     fi
   else
     LOG="    ${BASH_SOURCE[$i]//.\//}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}(..)"
     if [[ -z "${__log_fd}" ]]; then
       echo "${LOG}" >&2
     else
       echo "${LOG}" >&${__log_fd}
     fi
   fi
 done
}

# Generate call stack for FATAL levels
__generate_call_stack_fatal() {
 local __bl_functions_length="${#FUNCNAME[@]}"
 local __bl_script_name="${BASH_SOURCE[0]}"
 local __bl_function_name="${FUNCNAME[0]}"
 local __bl_called_line_number="${BASH_LINENO[0]}"
 local __bl_time_and_date
 
 __bl_script_name="${__bl_script_name##*/}"
 __bl_time_and_date="$(date '+%Y-%m-%d %H:%M:%S')"
 
 # First, log the stack header
 local LOG="${__bl_time_and_date} - ${__bl_script_name}:${__bl_function_name}:${__bl_called_line_number} - FATAL - Execution call stack:"
 if [[ -z "${__log_fd}" ]]; then
   echo "${LOG}" >&2
 else
   echo "${LOG}" >&${__log_fd}
 fi
 
 for ((i = 0; i < __bl_functions_length; i++)); do
   if (($i != $((__bl_functions_length - 1)))); then
     if [[ "${BASH_SOURCE[$i]}" != *"bash_logger"* ]]; then
       LOG="   ${BASH_SOURCE[$i]//.\//}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}(..)"
       if [[ -z "${__log_fd}" ]]; then
         echo "${LOG}" >&2
       else
         echo "${LOG}" >&${__log_fd}
       fi
     fi
   else
     LOG="    ${BASH_SOURCE[$i]//.\//}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}(..)"
     if [[ -z "${__log_fd}" ]]; then
       echo "${LOG}" >&2
     else
       echo "${LOG}" >&${__log_fd}
     fi
   fi
 done
}

# === LOG LEVEL FUNCTIONS ===

# TRACE: Most detailed logging
__logt() {
 if ! __should_log_message "TRACE"; then
   return 0
 fi
 
 local caller_info
 local formatted_message
 
 caller_info=$(__get_caller_info)
 formatted_message=$(__format_log_message "TRACE" "$*" "$caller_info")
 
 __output_log "$formatted_message"
 
 # Show call stack for TRACE
 if [[ "${#FUNCNAME[@]}" -gt 1 ]]; then
   __generate_call_stack
 fi
}

# DEBUG: Detailed information for debugging
__logd() {
 if ! __should_log_message "DEBUG"; then
   return 0
 fi
 
 local caller_info
 local formatted_message
 
 caller_info=$(__get_caller_info)
 formatted_message=$(__format_log_message "DEBUG" "$*" "$caller_info")
 
 __output_log "$formatted_message"
}

# INFO: General information
__logi() {
 if ! __should_log_message "INFO"; then
   return 0
 fi
 
 local caller_info
 local formatted_message
 
 caller_info=$(__get_caller_info)
 formatted_message=$(__format_log_message "INFO" "$*" "$caller_info")
 
 __output_log "$formatted_message"
}

# WARN: Warning messages
__logw() {
 if ! __should_log_message "WARN"; then
   return 0
 fi
 
 local caller_info
 local formatted_message
 
 caller_info=$(__get_caller_info)
 formatted_message=$(__format_log_message "WARN" "$*" "$caller_info")
 
 __output_log "$formatted_message" "true"
}

# ERROR: Error messages with call stack
__loge() {
 declare -A __bl_allowed_log_levels
 __bl_allowed_log_levels=([TRACE]=TRACE [DEBUG]=DEBUG [INFO]=INFO [WARN]=WARN [ERROR]=ERROR)
 if [[ "${__bl_allowed_log_levels[${__log_level}]+isset}" ]]; then
   local caller_info
   local formatted_message
   
   caller_info=$(__get_caller_info)
   formatted_message=$(__format_log_message "ERROR" "$*" "$caller_info")
   
   __output_log "$formatted_message" "true"
   
   # Show call stack for ERROR
   if [[ "${#FUNCNAME[@]}" -gt 1 ]]; then
     __generate_call_stack_error
   fi
 fi
}

# FATAL: Fatal error messages
__logf() {
 declare -A __bl_allowed_log_levels
 __bl_allowed_log_levels=([TRACE]=TRACE [DEBUG]=DEBUG [INFO]=INFO [WARN]=WARN [ERROR]=ERROR [FATAL]=FATAL)
 if [[ "${__bl_allowed_log_levels[${__log_level}]+isset}" ]]; then
   local caller_info
   local formatted_message
   
   caller_info=$(__get_caller_info)
   formatted_message=$(__format_log_message "FATAL" "$*" "$caller_info")
   
   __output_log "$formatted_message" "true"
   
   # Show call stack for FATAL
   if [[ "${#FUNCNAME[@]}" -gt 1 ]]; then
     __generate_call_stack_fatal
   fi
 fi
}

# === TIMING FUNCTIONS ===

# Start timing a function
__log_start() {
 declare -A __bl_allowed_log_levels
 __bl_allowed_log_levels=([TRACE]=TRACE [DEBUG]=DEBUG [INFO]=INFO)
 if [[ "${__bl_allowed_log_levels[${__log_level}]+isset}" ]]; then
   local caller_info
   local function_name="${FUNCNAME[1]:-main}"
   local script_name="${BASH_SOURCE[1]:-unknown}"
   
   # Clean names
   script_name="${script_name##*/}"
   
   # Store start time
   __logger_function_start_time=$(date +%s)
   __logger_run_times["${script_name}:${function_name}"]="$__logger_function_start_time"
   
   caller_info=$(__get_caller_info)
   if [[ -n "$__log_fd" ]]; then
     echo "" >&${__log_fd}
     echo "$(__format_log_message "INFO" "#-- STARTED ${function_name^^} --#" "$caller_info")" >&${__log_fd}
   else
     echo ""
     echo "$(__format_log_message "INFO" "#-- STARTED ${function_name^^} --#" "$caller_info")"
   fi
 fi
}

# Finish timing a function
__log_finish() {
 declare -A __bl_allowed_log_levels
 __bl_allowed_log_levels=([TRACE]=TRACE [DEBUG]=DEBUG [INFO]=INFO)
 if [[ "${__bl_allowed_log_levels[${__log_level}]+isset}" ]]; then
   local caller_info
   local function_name="${FUNCNAME[1]:-main}"
   local script_name="${BASH_SOURCE[1]:-unknown}"
   local start_time
   local end_time
   local run_time
   local hours
   local minutes
   local seconds
   
   # Clean names
   script_name="${script_name##*/}"
   
   # Calculate timing
   end_time=$(date +%s)
   
   if [[ "${function_name^^}" == "MAIN" ]]; then
     start_time="$__logger_script_start_time"
   else
     start_time="${__logger_run_times["${script_name}:${function_name}"]:-$__logger_script_start_time}"
   fi
   
   run_time=$((end_time - start_time))
   hours=$((run_time / 3600))
   minutes=$(((run_time % 3600) / 60))
   seconds=$(((run_time % 3600) % 60))
   
   caller_info=$(__get_caller_info)
   if [[ -n "$__log_fd" ]]; then
     echo "$(__format_log_message "INFO" "|-- FINISHED ${function_name^^} - Took: ${hours}h:${minutes}m:${seconds}s --|" "$caller_info")" >&${__log_fd}
     echo "" >&${__log_fd}
   else
     echo "$(__format_log_message "INFO" "|-- FINISHED ${function_name^^} - Took: ${hours}h:${minutes}m:${seconds}s --|" "$caller_info")"
     echo ""
   fi
 fi
}

# Default log function (original behavior)
__log() {
 local __bl_script_name="${BASH_SOURCE[1]}"
 __bl_script_name="${__bl_script_name##*/}"
 
 local __bl_function_name="${FUNCNAME[1]}"
 local __bl_called_line_number="${BASH_LINENO[0]}"
 local __bl_log_message="$*"
 local __bl_time_and_date
 
 __bl_time_and_date="$(date '+%Y-%m-%d %H:%M:%S')"
 
 local LOG="${__bl_time_and_date} - ${__bl_script_name}:${__bl_function_name}:${__bl_called_line_number} - ${__bl_log_message}"
 
 if [[ -z "${__log_fd}" ]]; then
   echo "${LOG}"
 else
   echo "${LOG}" >&${__log_fd}
 fi
}

# === EXPORTS FOR GLOBAL AVAILABILITY ===

# Export all configuration variables
export __log_level
export __log_fd
export __logger_script_start_time
export __logger_function_start_time

# Export arrays (with safety check)
if declare -p __logger_run_times >/dev/null 2>&1; then
  export __logger_run_times
fi

# Export all functions
export -f __get_log_level_number
export -f __should_log_message
export -f __get_caller_info
export -f __get_timestamp
export -f __format_log_message
export -f __set_log_level
export -f __set_log_file
export -f __output_log
export -f __generate_call_stack
export -f __generate_call_stack_error
export -f __generate_call_stack_fatal
export -f __logt
export -f __logd
export -f __logi
export -f __logw
export -f __loge
export -f __logf
export -f __log_start
export -f __log_finish
export -f __log

# === INITIALIZATION ===

# Set initial log level if LOG_LEVEL environment variable is set
if [[ -n "${LOG_LEVEL:-}" ]]; then
  __set_log_level "$LOG_LEVEL"
fi

# Set initial log file if LOG_FILE environment variable is set
if [[ -n "${LOG_FILE:-}" ]]; then
  __set_log_file "$LOG_FILE"
fi
