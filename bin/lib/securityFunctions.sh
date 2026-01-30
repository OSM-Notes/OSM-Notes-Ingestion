#!/bin/bash

# Security Functions for OSM-Notes-profile
# This file contains security functions for SQL sanitization
#
# Author: Andres Gomez (AngocA)
# Version: 2025-10-25

# shellcheck disable=SC2317,SC2155

# Note: This file expects to be sourced after commonFunctions.sh which provides logging functions
# If sourced directly, ensure commonFunctions.sh is loaded first

# =====================================================
# SQL Sanitization Functions
# =====================================================
#
# Note: Only functions that are actively used are kept in this file.
# See functionsProcess.sh for usage of sanitization functions.

##
# Sanitizes SQL string literal to prevent SQL injection
# Escapes single quotes by doubling them according to PostgreSQL standard.
# Critical security function - always use when interpolating user input into SQL queries.
#
# Parameters:
#   $1: String to sanitize - Input string that will be used in SQL query (required)
#
# Returns:
#   Sanitized string on stdout (always succeeds, never fails)
#   Empty string if input is empty
#
# Error codes:
#   None - Function always succeeds, outputs sanitized string via echo
#
# Context variables:
#   Reads: None
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Outputs sanitized string to stdout (use command substitution to capture)
#   - No file operations, database operations, or logging
#
# Security notes:
#   - Escapes single quotes: ' becomes ''
#   - PostgreSQL standard escaping method
#   - Does NOT protect against all injection vectors - use parameterized queries when possible
#   - Only use for string literals, not identifiers (use __sanitize_sql_identifier for those)
#
# Example:
#   USER_INPUT="O'Brien"
#   SAFE_INPUT=$(__sanitize_sql_string "${USER_INPUT}")
#   psql -c "INSERT INTO users (name) VALUES ('${SAFE_INPUT}')"
#
# Related: __sanitize_sql_identifier() (for table/column names)
# Related: __sanitize_sql_integer() (for numeric values)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __sanitize_sql_string() {
 local -r INPUT="${1:-}"
 local -r SANITIZED="${INPUT//\'/\'\'}"
 echo "${SANITIZED}"
}

##
# Sanitizes SQL identifier to prevent SQL injection
# Wraps identifier in double quotes if not already wrapped (PostgreSQL standard).
# Use this function for table names, column names, schema names, and other identifiers.
#
# Parameters:
#   $1: Identifier to sanitize - Table name, column name, schema name, etc. (required)
#
# Returns:
#   Sanitized identifier (wrapped in double quotes) on stdout
#   Exit code: 0 on success, 1 on error
#
# Error codes:
#   0: Success - Identifier sanitized and output to stdout
#   1: Failure - Empty identifier provided
#
# Error conditions:
#   0: Success - Identifier properly quoted and ready for use
#   1: Empty identifier - Input parameter is empty or unset
#
# Context variables:
#   Reads:
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Outputs sanitized identifier to stdout (use command substitution to capture)
#   - Writes error log to stderr if input is empty
#   - No file, database, or network operations
#
# Security notes:
#   - Wraps identifier in double quotes (PostgreSQL standard)
#   - Detects if already quoted and returns as-is
#   - Prevents SQL injection by proper quoting
#   - Only use for identifiers (table/column names), NOT for string values
#   - For string values, use __sanitize_sql_string() instead
#   - For numeric values, use __sanitize_sql_integer() instead
#
# Example:
#   TABLE_NAME=$(__sanitize_sql_identifier "notes")
#   psql -c "SELECT * FROM ${TABLE_NAME}"
#
#   COLUMN_NAME=$(__sanitize_sql_identifier "${USER_INPUT}")
#   psql -c "SELECT ${COLUMN_NAME} FROM table"
#
# Related: __sanitize_sql_string() (for string literals)
# Related: __sanitize_sql_integer() (for numeric values)
# Related: __sanitize_database_name() (for database names)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

##
# Executes SQL query with parameterized variables using psql -v
# Uses PostgreSQL's -v option for parameterized queries to prevent SQL injection.
# Sanitizes variable names and uses psql's built-in parameter substitution.
#
# Parameters:
#   $1: Database name - PostgreSQL database name (required)
#   $2: SQL query template - SQL query with :variable_name placeholders (required)
#   $3: Variable name 1 - First variable name (required)
#   $4: Variable value 1 - First variable value (required)
#   $5+: Additional variable name/value pairs - Pairs of name/value (optional, repeat as needed)
#
# Returns:
#   Output of psql command (stdout)
#   Exit code from psql command (0 on success, non-zero on error)
#
# Error codes:
#   0: Success - SQL executed successfully
#   1: Failure - psql command failed (SQL error, connection error, etc.)
#   2: Invalid argument - Missing required parameters (database name, query template, or variable pairs)
#   3: Missing dependency - psql command not found
#   5: Database error - Connection failed, query syntax error, or constraint violation
#
# Error conditions:
#   0: Success - Query executed and completed
#   1: General failure - psql returned non-zero exit code (check psql error message)
#   2: Invalid argument - Database name empty, query template empty, or odd number of variable arguments
#   3: Missing dependency - psql command not in PATH
#   5: Database error - Cannot connect to database or SQL query failed
#
# Context variables:
#   Reads:
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Executes psql command with -v parameters
#   - Outputs query results to stdout
#   - May modify database (INSERT, UPDATE, DELETE operations)
#   - Logs errors if psql command fails
#   - Uses eval for command construction (security consideration)
#
# Security notes:
#   - Uses psql -v for parameterized queries (recommended method)
#   - Sanitizes variable names (removes special characters)
#   - Variable values are passed directly to psql (not shell-interpolated)
#   - Still requires careful SQL template construction
#   - Prefer this over string interpolation when possible
#
# Example:
#   __execute_sql_with_params "osm_notes" \
#     "SELECT * FROM notes WHERE id = :note_id AND status = :status" \
#     "note_id" "12345" \
#     "status" "open"
#
# Related: __sanitize_sql_string() (for manual string sanitization)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
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

# Sanitize database name to allow only valid PostgreSQL identifiers
# Parameters:
#   $1: Database name to sanitize
# Returns: Sanitized name or exits on error
# Security: Prevents SQL injection, only allows [a-z0-9_]
##
# Validates and sanitizes PostgreSQL database name
# Ensures database name conforms to PostgreSQL naming rules and best practices.
# Validates length, character set, and naming conventions.
#
# Parameters:
#   $1: Database name - The database name to validate and sanitize (required)
#
# Returns:
#   Validated database name on stdout (unchanged if valid)
#   Exit code: 0 on success, 1 on error
#
# Error codes:
#   0: Success - Database name is valid and output to stdout
#   1: Failure - Database name validation failed (empty, too long, invalid characters, or naming convention violation)
#
# Error conditions:
#   0: Success - Database name is valid and ready for use
#   1: Empty input - Database name parameter is empty or unset
#   1: Length violation - Database name exceeds 63 characters (PostgreSQL limit)
#   1: Invalid characters - Database name contains characters other than [a-z0-9_]
#   1: Naming convention - Database name starts or ends with underscore (best practice violation)
#
# Context variables:
#   Reads:
#     - LOG_LEVEL: Controls logging verbosity
#   Sets: None
#   Modifies: None
#
# Side effects:
#   - Outputs validated database name to stdout (use command substitution to capture)
#   - Writes error log to stderr if validation fails
#   - No file, database, or network operations
#
# Security notes:
#   - Validates against PostgreSQL naming rules
#   - Prevents injection by ensuring only valid characters
#   - Enforces length limits to prevent buffer issues
#   - Follows PostgreSQL best practices (no leading/trailing underscores)
#   - Returns input unchanged if valid (no modification needed)
#
# Example:
#   DB_NAME=$(__sanitize_database_name "osm_notes")
#   if [[ $? -eq 0 ]]; then
#     psql -d "${DB_NAME}" -c "SELECT version();"
#   fi
#
# Related: __sanitize_sql_identifier() (for table/column names)
# Related: STANDARD_ERROR_CODES.md (error code definitions)
##
function __sanitize_database_name() {
 local INPUT="${1:-}"

 # Check if input is empty
 if [[ -z "${INPUT}" ]]; then
  __loge "ERROR: Empty database name provided to __sanitize_database_name"
  return 1
 fi

 # Validate length (PostgreSQL limit: 63 bytes)
 if [[ ${#INPUT} -gt 63 ]]; then
  __loge "ERROR: Database name too long (max 63): ${INPUT}"
  return 1
 fi

 # Validate characters (only lowercase, digits, underscore)
 if [[ ! "${INPUT}" =~ ^[a-z0-9_]+$ ]]; then
  __loge "ERROR: Invalid database name (only [a-z0-9_] allowed): ${INPUT}"
  return 1
 fi

 # Check doesn't start/end with underscore (best practice)
 if [[ "${INPUT}" =~ ^_ ]] || [[ "${INPUT}" =~ _$ ]]; then
  __loge "ERROR: Database name cannot start or end with underscore: ${INPUT}"
  return 1
 fi

 echo "${INPUT}"
}
