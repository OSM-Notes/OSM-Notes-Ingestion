#!/bin/bash

# Database Connection Pool for Bash
# Provides connection pooling functionality for PostgreSQL operations
#
# This module implements a simple connection pool using bash coprocesses
# to maintain persistent database connections, reducing connection overhead.
#
# Usage:
#   source bin/lib/databaseConnectionPool.sh
#   __db_pool_init
#   __db_pool_execute "SELECT 1;"
#   __db_pool_cleanup
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-27

# Pool configuration
declare -i DB_POOL_SIZE="${DB_POOL_SIZE:-3}"
declare -i DB_POOL_MAX_SIZE="${DB_POOL_MAX_SIZE:-10}"
declare -i DB_POOL_TIMEOUT="${DB_POOL_TIMEOUT:-300}"
declare DB_POOL_DIR="${DB_POOL_DIR:-/tmp/db_pool_$$}"
declare -a DB_POOL_CONNECTIONS=() # Used internally for connection tracking
declare -a DB_POOL_IN_USE=()
declare -i DB_POOL_INITIALIZED=0

# Initialize connection pool
# Parameters: None
# Returns: 0 if successful, 1 if failed
function __db_pool_init() {
 __log_start

 if [[ "${DB_POOL_INITIALIZED}" -eq 1 ]]; then
  __logw "Connection pool already initialized"
  __log_finish
  return 0
 fi

 # Create pool directory
 mkdir -p "${DB_POOL_DIR}"
 chmod 700 "${DB_POOL_DIR}"

 # Build psql connection string
 local PSQL_CMD="psql"
 local PSQL_ARGS=()

 if [[ -n "${DB_HOST:-}" ]]; then
  PSQL_ARGS+=("-h" "${DB_HOST}")
 fi

 if [[ -n "${DB_PORT:-}" ]]; then
  PSQL_ARGS+=("-p" "${DB_PORT}")
 fi

 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_ARGS+=("-U" "${DB_USER}")
 fi

 PSQL_ARGS+=("-d" "${DBNAME}")
 PSQL_ARGS+=("-v" "ON_ERROR_STOP=1")
 PSQL_ARGS+=("-q") # Quiet mode

 # Initialize pool connections
 __logd "Initializing connection pool (size: ${DB_POOL_SIZE})"
 local -i i=0
 while [[ ${i} -lt ${DB_POOL_SIZE} ]]; do
  # Create named pipe for communication
  local PIPE_IN="${DB_POOL_DIR}/pipe_${i}_in"
  local PIPE_OUT="${DB_POOL_DIR}/pipe_${i}_out"
  mkfifo "${PIPE_IN}" "${PIPE_OUT}" 2> /dev/null || true

  # Start coprocess (using eval for dynamic variable names)
  local COPROC_NAME="DB_POOL_${i}"
  if [[ -n "${DB_PASSWORD:-}" ]]; then
   PGPASSWORD="${DB_PASSWORD}" \
    eval 'coproc '"${COPROC_NAME}"' { '"${PSQL_CMD}"' '"$(printf '%q ' "${PSQL_ARGS[@]}")"' < '"${PIPE_IN}"' > '"${PIPE_OUT}"'; }'
  else
   eval 'coproc '"${COPROC_NAME}"' { '"${PSQL_CMD}"' '"$(printf '%q ' "${PSQL_ARGS[@]}")"' < '"${PIPE_IN}"' > '"${PIPE_OUT}"'; }'
  fi

  # Store connection info
  eval "DB_POOL_CONNECTIONS[${i}]=\${${COPROC_NAME}[1]}"
  DB_POOL_IN_USE[i]=0

  eval "__logd \"Connection ${i} initialized (PID: \${${COPROC_NAME}_PID})\""
  i=$((i + 1))
 done

 DB_POOL_INITIALIZED=1
 __logi "Connection pool initialized with ${DB_POOL_SIZE} connections"
 __log_finish
 return 0
}

# Get available connection from pool
# Parameters: None
# Returns: Connection index or -1 if none available
function __db_pool_get_connection() {
 local -i i=0
 local -i MAX_WAIT=10
 local -i WAIT_COUNT=0

 while [[ ${WAIT_COUNT} -lt ${MAX_WAIT} ]]; do
  i=0
  while [[ ${i} -lt ${DB_POOL_SIZE} ]]; do
   if [[ "${DB_POOL_IN_USE[i]}" -eq 0 ]]; then
    DB_POOL_IN_USE[i]=1
    echo "${i}"
    return 0
   fi
   i=$((i + 1))
  done

  # Wait a bit before retrying
  sleep 0.1
  WAIT_COUNT=$((WAIT_COUNT + 1))
 done

 # No connection available
 echo "-1"
 return 1
}

# Release connection back to pool
# Parameters:
#   $1: Connection index
# Returns: 0 if successful, 1 if failed
function __db_pool_release_connection() {
 local -i CONN_IDX="${1:-}"

 if [[ ${CONN_IDX} -lt 0 ]] || [[ ${CONN_IDX} -ge ${DB_POOL_SIZE} ]]; then
  __loge "Invalid connection index: ${CONN_IDX}"
  return 1
 fi

 DB_POOL_IN_USE[CONN_IDX]=0
 return 0
}

# Execute SQL query using pool
# Parameters:
#   $1: SQL query or file path (if starts with @)
#   $2: Output file (optional, defaults to stdout)
# Returns: 0 if successful, 1 if failed
function __db_pool_execute() {
 __log_start
 local SQL="${1:-}"
 local OUTPUT_FILE="${2:-/dev/stdout}"

 if [[ -z "${SQL}" ]]; then
  __loge "SQL query is required"
  __log_finish
  return 1
 fi

 if [[ "${DB_POOL_INITIALIZED}" -eq 0 ]]; then
  __logw "Pool not initialized, initializing now..."
  if ! __db_pool_init; then
   __loge "Failed to initialize pool"
   __log_finish
   return 1
  fi
 fi

 # Get connection from pool
 local -i CONN_IDX
 CONN_IDX=$(__db_pool_get_connection)

 if [[ ${CONN_IDX} -eq -1 ]]; then
  __loge "No available connections in pool, falling back to direct psql"
  # Fallback to direct psql
  if [[ "${SQL}" =~ ^@ ]]; then
   # File path
   local SQL_FILE="${SQL#@}"
   if [[ -n "${DB_PASSWORD:-}" ]]; then
    PGPASSWORD="${DB_PASSWORD}" \
     PGAPPNAME="${PGAPPNAME:-${BASENAME:-psql}}" \
     psql -d "${DBNAME}" -h "${DB_HOST:-}" -p "${DB_PORT:-}" \
     -U "${DB_USER:-}" -f "${SQL_FILE}" > "${OUTPUT_FILE}" 2>&1
   else
    PGAPPNAME="${PGAPPNAME:-${BASENAME:-psql}}" psql -d "${DBNAME}" \
     -f "${SQL_FILE}" > "${OUTPUT_FILE}" 2>&1
   fi
  else
   # SQL query
   if [[ -n "${DB_PASSWORD:-}" ]]; then
    PGPASSWORD="${DB_PASSWORD}" \
     PGAPPNAME="${PGAPPNAME:-${BASENAME:-psql}}" \
     psql -d "${DBNAME}" -h "${DB_HOST:-}" -p "${DB_PORT:-}" \
     -U "${DB_USER:-}" -c "${SQL}" > "${OUTPUT_FILE}" 2>&1
   else
    PGAPPNAME="${PGAPPNAME:-${BASENAME:-psql}}" psql -d "${DBNAME}" \
     -c "${SQL}" > "${OUTPUT_FILE}" 2>&1
   fi
  fi
  __log_finish
  return "${?}"
 fi

 # Use pooled connection
 local PIPE_IN="${DB_POOL_DIR}/pipe_${CONN_IDX}_in"
 local PIPE_OUT="${DB_POOL_DIR}/pipe_${CONN_IDX}_out"

 # Execute query
 if [[ "${SQL}" =~ ^@ ]]; then
  # File path
  local SQL_FILE="${SQL#@}"
  cat "${SQL_FILE}" > "${PIPE_IN}" &
  cat "${PIPE_OUT}" > "${OUTPUT_FILE}" 2>&1
 else
  # SQL query
  echo "${SQL}" > "${PIPE_IN}" &
  cat "${PIPE_OUT}" > "${OUTPUT_FILE}" 2>&1
 fi

 local EXIT_CODE=$?

 # Release connection
 __db_pool_release_connection "${CONN_IDX}"

 __log_finish
 return ${EXIT_CODE}
}

# Cleanup connection pool
# Parameters: None
# Returns: 0 if successful, 1 if failed
function __db_pool_cleanup() {
 __log_start

 if [[ "${DB_POOL_INITIALIZED}" -eq 0 ]]; then
  __log_finish
  return 0
 fi

 __logd "Cleaning up connection pool..."

 # Kill all coprocesses
 local -i i=0
 while [[ ${i} -lt ${DB_POOL_SIZE} ]]; do
  local VAR_NAME="DB_POOL_${i}_PID"
  if [[ -n "${!VAR_NAME:-}" ]]; then
   kill "${!VAR_NAME}" 2> /dev/null || true
   wait "${!VAR_NAME}" 2> /dev/null || true
  fi
  i=$((i + 1))
 done

 # Remove pool directory
 rm -rf "${DB_POOL_DIR}" 2> /dev/null || true

 DB_POOL_INITIALIZED=0
 DB_POOL_CONNECTIONS=()
 DB_POOL_IN_USE=()

 __logi "Connection pool cleaned up"
 __log_finish
 return 0
}

# Alternative: Simple connection reuse using a single persistent connection
# This is simpler and more reliable than full pooling
# Parameters: None
# Returns: 0 if successful, 1 if failed
function __db_simple_pool_init() {
 __log_start

 if [[ "${DB_POOL_INITIALIZED}" -eq 1 ]]; then
  __logw "Simple pool already initialized"
  __log_finish
  return 0
 fi

 # Build psql connection string
 local PSQL_CMD="psql"
 local PSQL_ARGS=()

 if [[ -n "${DB_HOST:-}" ]]; then
  PSQL_ARGS+=("-h" "${DB_HOST}")
 fi

 if [[ -n "${DB_PORT:-}" ]]; then
  PSQL_ARGS+=("-p" "${DB_PORT}")
 fi

 if [[ -n "${DB_USER:-}" ]]; then
  PSQL_ARGS+=("-U" "${DB_USER}")
 fi

 PSQL_ARGS+=("-d" "${DBNAME}")

 # Create named pipes for communication
 local PIPE_IN="${DB_POOL_DIR}/simple_pool_in"
 local PIPE_OUT="${DB_POOL_DIR}/simple_pool_out"
 mkdir -p "${DB_POOL_DIR}"
 mkfifo "${PIPE_IN}" "${PIPE_OUT}" 2> /dev/null || true

 # Export variables before starting psql process
 if [[ -n "${DB_PASSWORD:-}" ]]; then
  export PGPASSWORD="${DB_PASSWORD}"
 fi
 export PGAPPNAME="${PGAPPNAME:-${BASENAME:-psql}}"
 
 # Start persistent psql process in background with named pipes
 # We use background process instead of coproc to avoid issues with script command
 # The process reads from PIPE_IN and writes to PIPE_OUT
 if [[ -n "${DB_PASSWORD:-}" ]]; then
  PGPASSWORD="${DB_PASSWORD}" \
   PGAPPNAME="${PGAPPNAME:-${BASENAME:-psql}}" \
   "${PSQL_CMD}" "${PSQL_ARGS[@]}" < "${PIPE_IN}" > "${PIPE_OUT}" 2>&1 &
  DB_SIMPLE_POOL_PID=$!
 else
  PGAPPNAME="${PGAPPNAME:-${BASENAME:-psql}}" \
   "${PSQL_CMD}" "${PSQL_ARGS[@]}" < "${PIPE_IN}" > "${PIPE_OUT}" 2>&1 &
  DB_SIMPLE_POOL_PID=$!
 fi

 DB_POOL_INITIALIZED=1
 __logi "Simple connection pool initialized (PID: ${DB_SIMPLE_POOL_PID})"
 __log_finish
 return 0
}

# Check if simple pool coprocess is alive and restart if needed
# Parameters: None
# Returns: 0 if pool is alive/restarted, 1 if failed to restart
function __db_simple_pool_ensure_alive() {
 __log_start

 if [[ "${DB_POOL_INITIALIZED}" -eq 0 ]]; then
  if ! __db_simple_pool_init; then
   __loge "Failed to initialize simple pool"
   __log_finish
   return 1
  fi
 fi

 # Check if coprocess is still alive
 if [[ -n "${DB_SIMPLE_POOL_PID:-}" ]]; then
  if ! kill -0 "${DB_SIMPLE_POOL_PID}" 2> /dev/null; then
   __logw "Pool coprocess (PID: ${DB_SIMPLE_POOL_PID}) is dead, restarting..."
   # Cleanup dead coprocess
   rm -rf "${DB_POOL_DIR}" 2> /dev/null || true
   DB_POOL_INITIALIZED=0
   unset DB_SIMPLE_POOL_PID
   # Reinitialize pool
   if ! __db_simple_pool_init; then
    __loge "Failed to reinitialize simple pool after coprocess death"
    __log_finish
    return 1
   fi
   __logi "Pool coprocess restarted successfully (new PID: ${DB_SIMPLE_POOL_PID})"
  fi
 else
  # PID not set, reinitialize
  __logw "Pool PID not set, reinitializing pool..."
  rm -rf "${DB_POOL_DIR}" 2> /dev/null || true
  DB_POOL_INITIALIZED=0
  if ! __db_simple_pool_init; then
   __loge "Failed to reinitialize simple pool"
   __log_finish
   return 1
  fi
 fi

 __log_finish
 return 0
}

# Execute SQL using simple pool
# Parameters:
#   $1: SQL query or file path (if starts with @)
#   $2: Output file (optional)
# Returns: 0 if successful, 1 if failed
function __db_simple_pool_execute() {
 __log_start
 local SQL="${1:-}"
 local OUTPUT_FILE="${2:-/dev/stdout}"

 if [[ -z "${SQL}" ]]; then
  __loge "SQL query is required"
  __log_finish
  return 1
 fi

 # Ensure pool is alive (will initialize if needed, restart if dead)
 if ! __db_simple_pool_ensure_alive; then
  __loge "Failed to ensure pool is alive"
  __log_finish
  return 1
 fi

 # Use named pipes for communication
 local PIPE_IN="${DB_POOL_DIR}/simple_pool_in"
 local PIPE_OUT="${DB_POOL_DIR}/simple_pool_out"

 # Execute query
 local CAT_PID
 if [[ "${SQL}" =~ ^@ ]]; then
  local SQL_FILE="${SQL#@}"
  cat "${SQL_FILE}" > "${PIPE_IN}" &
  cat "${PIPE_OUT}" > "${OUTPUT_FILE}" 2>&1 &
  CAT_PID=$!
  wait "${CAT_PID}" 2> /dev/null || true
 else
  # For queries, add ON_ERROR_STOP if not present
  local SQL_WITH_ERROR_STOP="${SQL}"
  if [[ ! "${SQL}" =~ ON_ERROR_STOP ]]; then
   SQL_WITH_ERROR_STOP="SET ON_ERROR_STOP=1; ${SQL}"
  fi
  echo "${SQL_WITH_ERROR_STOP}" > "${PIPE_IN}" &
  cat "${PIPE_OUT}" > "${OUTPUT_FILE}" 2>&1 &
  CAT_PID=$!
  wait "${CAT_PID}" 2> /dev/null || true
 fi

 # Check if output file contains errors
 local EXIT_CODE=0
 if [[ -f "${OUTPUT_FILE}" ]] && grep -qiE "ERROR|error|FATAL|fatal" "${OUTPUT_FILE}" 2> /dev/null; then
  EXIT_CODE=1
 fi

 __log_finish
 return "${EXIT_CODE}"
}

# Cleanup simple pool
# Parameters: None
# Returns: 0 if successful, 1 if failed
function __db_simple_pool_cleanup() {
 __log_start

 if [[ "${DB_POOL_INITIALIZED}" -eq 0 ]]; then
  __log_finish
  return 0
 fi

 if [[ -n "${DB_SIMPLE_POOL_PID:-}" ]]; then
  kill "${DB_SIMPLE_POOL_PID}" 2> /dev/null || true
  wait "${DB_SIMPLE_POOL_PID}" 2> /dev/null || true
 fi

 rm -rf "${DB_POOL_DIR}" 2> /dev/null || true
 DB_POOL_INITIALIZED=0

 __logi "Simple connection pool cleaned up"
 __log_finish
 return 0
}
