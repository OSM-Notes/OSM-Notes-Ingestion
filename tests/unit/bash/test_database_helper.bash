#!/bin/bash

# Test Database Helper Functions
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

# This file contains helper functions for managing test databases
# in a way that's compatible with both local and CI environments

# Function to check if we're in a CI environment
is_ci_environment() {
 [[ -n "${CI:-}" ]] && [[ -n "${TEST_DBNAME:-}" ]] && [[ -n "${TEST_DBUSER:-}" ]]
}

# Function to get database connection parameters
get_db_connection_params() {
 if is_ci_environment; then
   echo "-h ${TEST_DBHOST:-localhost} -p ${TEST_DBPORT:-5432} -U ${TEST_DBUSER}"
 else
   echo ""
 fi
}

# Function to create or use test database
setup_test_database() {
 local db_name="${1:-${TEST_DBNAME}}"
 local db_user="${2:-${TEST_DBUSER:-}}"
 local db_host="${3:-${TEST_DBHOST:-}}"
 local db_port="${4:-${TEST_DBPORT:-}}"
 
 if is_ci_environment; then
   # In CI, use existing database
   log_info "Using existing CI database: ${db_name}"
   
   # Test connection to existing database
   local connection_params="-h ${db_host:-localhost} -p ${db_port:-5432} -U ${db_user}"
   if psql ${connection_params} -d "${db_name}" -c "SELECT 1;" >/dev/null 2>&1; then
     log_info "Successfully connected to CI database: ${db_name}"
     return 0
   else
     log_error "Failed to connect to CI database: ${db_name}"
     return 1
   fi
 else
   # Local environment - create new test database
   log_info "Creating new test database: ${db_name}"
   
   if psql -d postgres -c "CREATE DATABASE ${db_name};" >/dev/null 2>&1; then
     log_info "Successfully created test database: ${db_name}"
     return 0
   else
     log_error "Failed to create test database: ${db_name}"
     return 1
   fi
 fi
}

# Function to execute SQL file on test database
execute_sql_file() {
 local sql_file="$1"
 local db_name="${2:-${TEST_DBNAME}}"
 
 if [[ ! -f "${sql_file}" ]]; then
   log_error "SQL file not found: ${sql_file}"
   return 1
 fi
 
 local connection_params
 connection_params=$(get_db_connection_params)
 
 if psql ${connection_params} -d "${db_name}" -f "${sql_file}" >/dev/null 2>&1; then
   log_info "Successfully executed SQL file: ${sql_file}"
   return 0
 else
   log_error "Failed to execute SQL file: ${sql_file}"
   return 1
 fi
}

# Function to execute SQL command on test database
execute_sql_command() {
 local sql_command="$1"
 local db_name="${2:-${TEST_DBNAME}}"
 
 local connection_params
 connection_params=$(get_db_connection_params)
 
 if psql ${connection_params} -d "${db_name}" -c "${sql_command}" >/dev/null 2>&1; then
   log_info "Successfully executed SQL command: ${sql_command}"
   return 0
 else
   log_error "Failed to execute SQL command: ${sql_command}"
   return 1
 fi
}

# Function to check if table exists
table_exists() {
 local table_name="$1"
 local db_name="${2:-${TEST_DBNAME}}"
 
 local connection_params
 connection_params=$(get_db_connection_params)
 
 local result
 result=$(psql ${connection_params} -d "${db_name}" -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = '${table_name}');" 2>/dev/null | tr -d ' ')
 
 [[ "${result}" == "t" ]]
}

# Function to get table count
get_table_count() {
 local table_name="$1"
 local db_name="${2:-${TEST_DBNAME}}"
 
 local connection_params
 connection_params=$(get_db_connection_params)
 
 psql ${connection_params} -d "${db_name}" -t -c "SELECT COUNT(*) FROM ${table_name};" 2>/dev/null | tr -d ' '
}

# Function to cleanup test database
cleanup_test_database() {
 local db_name="${1:-${TEST_DBNAME}}"
 
 if is_ci_environment; then
   # In CI, just drop tables, don't drop the database
   log_info "Cleaning up CI database tables: ${db_name}"
   
   local connection_params
   connection_params=$(get_db_connection_params)
   
   # Drop all tables in the test database
   psql ${connection_params} -d "${db_name}" -c "
     DO \$\$ 
     DECLARE 
       r RECORD;
     BEGIN
       FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'public') LOOP
         EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident(r.tablename) || ' CASCADE';
       END LOOP;
     END \$\$;
   " >/dev/null 2>&1 || true
   
   log_info "CI database cleanup completed"
 else
   # Local environment - drop the entire database
   log_info "Dropping local test database: ${db_name}"
   
   if psql -d postgres -c "DROP DATABASE IF EXISTS ${db_name};" >/dev/null 2>&1; then
     log_info "Successfully dropped test database: ${db_name}"
   else
     log_warning "Failed to drop test database: ${db_name}"
   fi
 fi
}

# Function to run database test with proper setup/cleanup
run_database_test() {
 local test_name="$1"
 local db_name="${2:-${TEST_DBNAME}}"
 local sql_files=("${@:3}")
 
 log_info "Running database test: ${test_name}"
 
 # Setup test database
 if ! setup_test_database "${db_name}"; then
   skip "Cannot setup test database: ${db_name}"
   return 1
 fi
 
 # Execute SQL files if provided
 for sql_file in "${sql_files[@]}"; do
   if [[ -n "${sql_file}" ]]; then
     if ! execute_sql_file "${sql_file}" "${db_name}"; then
       log_error "Failed to execute SQL file: ${sql_file}"
       cleanup_test_database "${db_name}"
       return 1
     fi
   fi
 done
 
 # Run the actual test (this should be implemented by the caller)
 log_info "Database test setup completed: ${test_name}"
 return 0
}

# Logging functions (if not already defined)
if ! declare -F log_info >/dev/null; then
 log_info() {
   echo "[INFO] $1" >&2
 }
fi

if ! declare -F log_error >/dev/null; then
 log_error() {
   echo "[ERROR] $1" >&2
 }
fi

if ! declare -F log_warning >/dev/null; then
 log_warning() {
   echo "[WARNING] $1" >&2
 }
fi
