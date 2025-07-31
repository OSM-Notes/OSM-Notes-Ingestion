#!/usr/bin/env bats

# Tests for database variable validation
# Author: Andres Gomez (AngocA)
# Version: 2025-07-29

load "${BATS_TEST_DIRNAME}/../../test_helper"
source "${BATS_TEST_DIRNAME}/../../test_variables.sh"

setup() {
 # Create temporary test directory
 TEST_DIR=$(mktemp -d)
 export TEST_DIR
}

teardown() {
 # Clean up test files
 rm -rf "${TEST_DIR}"
}

@test "validate_database_variables with all variables set" {
 # Set all required variables
 export DBNAME="test_db"
 export DB_USER="test_user"
 export WMS_DBNAME="wms_db"
 export WMS_DBUSER="wms_user"
 export TEST_DBNAME="test_db"
 export TEST_DBUSER="test_user"

 run __validate_all_database_variables
 [ "$status" -eq 0 ]
 [[ "$output" == *"DEBUG: Database variable validation passed"* ]]
}

@test "validate_database_variables with missing DBNAME" {
 # Set variables except DBNAME
 export DB_USER="test_user"
 export WMS_DBNAME="wms_db"
 export WMS_DBUSER="wms_user"
 export TEST_DBNAME="test_db"
 export TEST_DBUSER="test_user"

 # Unset DBNAME
 unset DBNAME

 run __validate_all_database_variables
 [ "$status" -eq 1 ]
 [[ "$output" == *"ERROR: Database variable validation failed"* ]]
 [[ "$output" == *"DBNAME is not set"* ]]
}

@test "validate_database_variables with missing DB_USER" {
 # Set variables except DB_USER
 export DBNAME="test_db"
 export WMS_DBNAME="wms_db"
 export WMS_DBUSER="wms_user"
 export TEST_DBNAME="test_db"
 export TEST_DBUSER="test_user"

 # Unset DB_USER
 unset DB_USER

 run __validate_all_database_variables
 [ "$status" -eq 1 ]
 [[ "$output" == *"ERROR: Database variable validation failed"* ]]
 [[ "$output" == *"DB_USER is not set"* ]]
}

@test "validate_database_variables with missing WMS variables" {
 # Set only primary variables
 export DBNAME="test_db"
 export DB_USER="test_user"
 export TEST_DBNAME="test_db"
 export TEST_DBUSER="test_user"

 # Unset WMS variables
 unset WMS_DBNAME WMS_DBUSER

 run __validate_all_database_variables
 [ "$status" -eq 0 ]
 [[ "$output" == *"WARNING: Database variable warnings"* ]]
 [[ "$output" == *"WMS_DBNAME is not set"* ]]
 [[ "$output" == *"WMS_DBUSER is not set"* ]]
}

@test "validate_database_variables with missing TEST variables" {
 # Set only primary variables
 export DBNAME="test_db"
 export DB_USER="test_user"
 export WMS_DBNAME="wms_db"
 export WMS_DBUSER="wms_user"

 # Unset TEST variables
 unset TEST_DBNAME TEST_DBUSER

 run __validate_all_database_variables
 [ "$status" -eq 1 ]
 [[ "$output" == *"ERROR: Database variable validation failed"* ]]
 [[ "$output" == *"TEST_DBNAME is not set"* ]]
 [[ "$output" == *"TEST_DBUSER is not set"* ]]
}



@test "validate_database_variables with no variables set" {
 # Unset all variables
 unset DBNAME DB_USER WMS_DBNAME WMS_DBUSER TEST_DBNAME TEST_DBUSER

 run __validate_all_database_variables
 [ "$status" -eq 1 ]
 [[ "$output" == *"ERROR: Database variable validation failed"* ]]
 [[ "$output" == *"DBNAME is not set"* ]]
 [[ "$output" == *"DB_USER is not set"* ]]
 [[ "$output" == *"TEST_DBNAME is not set"* ]]
 [[ "$output" == *"TEST_DBUSER is not set"* ]]
}

@test "validate_database_variables with only primary variables" {
 # Set only primary variables
 export DBNAME="test_db"
 export DB_USER="test_user"

 # Unset all other variables
 unset WMS_DBNAME WMS_DBUSER TEST_DBNAME TEST_DBUSER

 run __validate_database_variables
 [ "$status" -eq 0 ]
 [[ "$output" == *"DEBUG: Database variable validation passed"* ]]
}

@test "validate_database_variables function should be available" {
 # Test that the function exists
 run declare -f __validate_database_variables
 [ "$status" -eq 0 ]
 [[ "$output" == *"__validate_database_variables"* ]]
}

@test "validate_test_database_variables function should be available" {
 # Test that the function exists
 run declare -f __validate_test_database_variables
 [ "$status" -eq 0 ]
 [[ "$output" == *"__validate_test_database_variables"* ]]
}

@test "validate_all_database_variables function should be available" {
 # Test that the function exists
 run declare -f __validate_all_database_variables
 [ "$status" -eq 0 ]
 [[ "$output" == *"__validate_all_database_variables"* ]]
}

@test "validate_test_database_variables with all test variables set" {
 # Set all test variables
 export TEST_DBNAME="test_db"
 export TEST_DBUSER="test_user"
 export WMS_DBNAME="wms_db"
 export WMS_DBUSER="wms_user"

 run __validate_test_database_variables
 [ "$status" -eq 0 ]
 [[ "$output" == *"DEBUG: Test database variable validation passed"* ]]
}

@test "validate_test_database_variables with missing TEST_DBNAME" {
 # Set variables except TEST_DBNAME
 export TEST_DBUSER="test_user"
 export WMS_DBNAME="wms_db"
 export WMS_DBUSER="wms_user"

 # Unset TEST_DBNAME
 unset TEST_DBNAME

 run __validate_test_database_variables
 [ "$status" -eq 1 ]
 [[ "$output" == *"ERROR: Test database variable validation failed"* ]]
 [[ "$output" == *"TEST_DBNAME is not set"* ]]
}

@test "validate_postgres_variables with all variables set" {
 # Set all required POSTGRES variables
 export POSTGRES_11_CHECK_BASE_TABLES="/tmp/test_check.sql"
 export POSTGRES_12_DROP_GENERIC_OBJECTS="/tmp/test_drop.sql"
 export POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY="/tmp/test_function.sql"
 export POSTGRES_22_CREATE_PROC_INSERT_NOTE="/tmp/test_proc_note.sql"
 export POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT="/tmp/test_proc_comment.sql"
 export POSTGRES_31_ORGANIZE_AREAS="/tmp/test_organize.sql"
 export POSTGRES_32_UPLOAD_NOTE_LOCATION="/tmp/test_location.sql"

 # Create test SQL files
 echo "SELECT 1;" > "/tmp/test_check.sql"
 echo "DROP TABLE IF EXISTS test;" > "/tmp/test_drop.sql"
 echo "CREATE FUNCTION test();" > "/tmp/test_function.sql"
 echo "CREATE PROCEDURE test();" > "/tmp/test_proc_note.sql"
 echo "CREATE PROCEDURE test_comment();" > "/tmp/test_proc_comment.sql"
 echo "SELECT 1;" > "/tmp/test_organize.sql"
 echo "SELECT 1;" > "/tmp/test_location.sql"

 run __validate_postgres_variables
 [ "$status" -eq 0 ]
 [[ "$output" == *"DEBUG: PostgreSQL variable validation passed"* ]]

 # Clean up test files
 rm -f /tmp/test_*.sql
}

@test "validate_postgres_variables with missing POSTGRES_11_CHECK_BASE_TABLES" {
 # Set variables except POSTGRES_11_CHECK_BASE_TABLES
 export POSTGRES_12_DROP_GENERIC_OBJECTS="/tmp/test_drop.sql"
 export POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY="/tmp/test_function.sql"
 export POSTGRES_22_CREATE_PROC_INSERT_NOTE="/tmp/test_proc_note.sql"
 export POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT="/tmp/test_proc_comment.sql"
 export POSTGRES_31_ORGANIZE_AREAS="/tmp/test_organize.sql"
 export POSTGRES_32_UPLOAD_NOTE_LOCATION="/tmp/test_location.sql"

 # Unset POSTGRES_11_CHECK_BASE_TABLES
 unset POSTGRES_11_CHECK_BASE_TABLES

 run __validate_postgres_variables
 [ "$status" -eq 1 ]
 [[ "$output" == *"ERROR: PostgreSQL variable validation failed"* ]]
 [[ "$output" == *"POSTGRES_11_CHECK_BASE_TABLES is not set"* ]]
}

@test "validate_postgres_variables with missing SQL files" {
 # Set all required POSTGRES variables
 export POSTGRES_11_CHECK_BASE_TABLES="/tmp/nonexistent_check.sql"
 export POSTGRES_12_DROP_GENERIC_OBJECTS="/tmp/nonexistent_drop.sql"
 export POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY="/tmp/nonexistent_function.sql"
 export POSTGRES_22_CREATE_PROC_INSERT_NOTE="/tmp/nonexistent_proc_note.sql"
 export POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT="/tmp/nonexistent_proc_comment.sql"
 export POSTGRES_31_ORGANIZE_AREAS="/tmp/nonexistent_organize.sql"
 export POSTGRES_32_UPLOAD_NOTE_LOCATION="/tmp/nonexistent_location.sql"

 run __validate_postgres_variables
 [ "$status" -eq 1 ]
 [[ "$output" == *"ERROR: PostgreSQL variable validation failed"* ]]
 [[ "$output" == *"SQL file not found"* ]]
} 