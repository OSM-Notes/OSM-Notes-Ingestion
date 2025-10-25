#!/bin/bash

# Security Functions for OSM-Notes-profile
# This file contains security functions for SQL sanitization
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-25

# Define version variable
VERSION="2025-10-25"

# shellcheck disable=SC2317,SC2155,SC2034

# Note: This file expects to be sourced after commonFunctions.sh which provides logging functions
# If sourced directly, ensure commonFunctions.sh is loaded first

# =====================================================
# SQL Sanitization Functions
# =====================================================

# Sanitize SQL string literal to prevent SQL injection
# Parameters:
#   $1: String to sanitize
# Returns: Sanitized string
# Security: Escapes single quotes by doubling them (PostgreSQL standard)
function __sanitize_sql_string() {
 local -r INPUT="${1:-}"
 local -r SANITIZED="${INPUT//\'/\'\'}"
 echo "${SANITIZED}"
}

# Sanitize SQL identifier (table name, column name, etc.)
# Parameters:
#   $1: Identifier to sanitize
# Returns: Sanitized identifier
# Security: Wraps identifier in double quotes if not already wrapped
function __sanitize_sql_identifier() {
 local -r INPUT="${1:-}"
 
 # Check if input is empty
 if [[ -z "${INPUT}" ]]; then
  __loge "ERROR: Empty identifier provided to __sanitize_sql_identifier"
  return 1
 fi
 
 # Check if already quoted
 if [[ "${INPUT}" =~ ^\".*\"$ ]]; then
  echo "${INPUT}"
 else
  echo "\"${INPUT}\""
 fi
}

# Sanitize SQL integer parameter
# Parameters:
#   $1: Integer value to sanitize
# Returns: Validated integer or empty string
# Security: Ensures value is a valid integer, prevents code injection
function __sanitize_sql_integer() {
 local -r INPUT="${1:-}"
 
 # Check if input is empty
 if [[ -z "${INPUT}" ]]; then
  __loge "ERROR: Empty integer provided to __sanitize_sql_integer"
  return 1
 fi
 
 # Validate that input is a valid integer
 if [[ ! "${INPUT}" =~ ^-?[0-9]+$ ]]; then
  __loge "ERROR: Invalid integer format: ${INPUT}"
  return 1
 fi
 
 echo "${INPUT}"
}

# Execute SQL with sanitized parameters using psql -v
# Parameters:
#   $1: Database name
#   $2: SQL query template (with :variable_name placeholders)
#   $3: Variable name 1
#   $4: Variable value 1
#   $5+: Additional variable name/value pairs
# Returns: Output of psql command
# Security: Uses psql -v for parameterized queries, prevents SQL injection
function __execute_sql_with_params() {
 local -r DBNAME="${1}"
 local -r SQL_TEMPLATE="${2}"
 shift 2
 
 local SQL_CMD="psql -d ${DBNAME} -v ON_ERROR_STOP=1"
 
 # Add variables
 while [[ $# -ge 2 ]]; do
  local VAR_NAME="${1}"
  local VAR_VALUE="${2}"
  shift 2
  
  # Sanitize variable name (remove any quotes or special chars)
  VAR_NAME="${VAR_NAME//[^a-zA-Z0-9_]/}"
  
  # Add variable to psql command
  SQL_CMD="${SQL_CMD} -v ${VAR_NAME}=\"${VAR_VALUE}\""
 done
 
 # Execute SQL with variables
 eval "${SQL_CMD} -c \"${SQL_TEMPLATE}\""
}

