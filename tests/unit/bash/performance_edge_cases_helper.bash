#!/usr/bin/env bash

# Performance edge cases helper utilities
# Author: Andres Gomez (AngocA)
# Version: 2025-11-11

# Ensures PostgreSQL-dependent tests fall back to mock psql when the real
# service is not accessible. This keeps performance edge case tests runnable
# on hosts without PostgreSQL.
function performance_setup_mock_postgres() {
 # SCRIPT_BASE_DIRECTORY must be defined by the caller.
 if [[ -z "${SCRIPT_BASE_DIRECTORY:-}" ]]; then
  return 0
 fi

 local MOCK_DIR="${SCRIPT_BASE_DIRECTORY}/tests/mock_commands"
 local POSTGRES_READY=false

 if command -v pg_isready > /dev/null 2>&1; then
  if pg_isready -q > /dev/null 2>&1; then
   POSTGRES_READY=true
  fi
 fi

 if [[ "${POSTGRES_READY}" != true ]] && command -v psql > /dev/null 2>&1; then
  if command -v timeout > /dev/null 2>&1; then
   if timeout 3s psql -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    POSTGRES_READY=true
   fi
  else
   if psql -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
    POSTGRES_READY=true
   fi
  fi
 fi

 if [[ "${POSTGRES_READY}" != true ]] && [[ -d "${MOCK_DIR}" ]]; then
  if [[ ":${PATH}:" != *":${MOCK_DIR}:"* ]]; then
   export PATH="${MOCK_DIR}:${PATH}"
  fi
  export PERFORMANCE_EDGE_CASES_USING_MOCK_PSQL="true"
 else
  unset PERFORMANCE_EDGE_CASES_USING_MOCK_PSQL
 fi

 return 0
}
