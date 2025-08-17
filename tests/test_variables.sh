#!/bin/bash

# Test variables validation functions
# Author: Andres Gomez (AngocA)
# Version: 2025-08-16

# Validates test database variables
# This function ensures that test database variables are properly set
# Parameters: None
# Returns: 0 if validation passes, 1 if validation fails
function __validate_test_database_variables() {
 local VALIDATION_ERRORS=()
 local WARNINGS=()

 # Check test database variables
 if [[ -z "${TEST_DBNAME:-}" ]]; then
  VALIDATION_ERRORS+=("TEST_DBNAME is not set")
 fi

 if [[ -z "${TEST_DBUSER:-}" ]]; then
  VALIDATION_ERRORS+=("TEST_DBUSER is not set")
 fi

 # Check WMS-specific variables (optional for tests)
 if [[ -z "${WMS_DBNAME:-}" ]]; then
  WARNINGS+=("WMS_DBNAME is not set (WMS tests may be affected)")
 fi

 if [[ -z "${WMS_DBUSER:-}" ]]; then
  WARNINGS+=("WMS_DBUSER is not set (WMS tests may be affected)")
 fi

 # Report validation errors
 if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
  echo "ERROR: Test database variable validation failed:" >&2
  for ERROR in "${VALIDATION_ERRORS[@]}"; do
   echo "  - ${ERROR}" >&2
  done
  return 1
 fi

 # Report warnings
 if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo "WARNING: Test database variable warnings:" >&2
  for WARNING in "${WARNINGS[@]}"; do
   echo "  - ${WARNING}" >&2
  done
 fi

 echo "DEBUG: Test database variable validation passed" >&2
 return 0
}

# Validates all database variables (production and test)
# This function ensures that all database variables are properly set
# Parameters: None
# Returns: 0 if validation passes, 1 if validation fails
function __validate_all_database_variables() {
 local VALIDATION_ERRORS=()
 local WARNINGS=()

 # Check production database variables
 if [[ -z "${DBNAME:-}" ]]; then
  VALIDATION_ERRORS+=("DBNAME is not set")
 fi

 if [[ -z "${DB_USER:-}" ]]; then
  VALIDATION_ERRORS+=("DB_USER is not set")
 fi

 # Check test database variables
 if [[ -z "${TEST_DBNAME:-}" ]]; then
  VALIDATION_ERRORS+=("TEST_DBNAME is not set")
 fi

 if [[ -z "${TEST_DBUSER:-}" ]]; then
  VALIDATION_ERRORS+=("TEST_DBUSER is not set")
 fi

 # Check WMS-specific variables
 if [[ -z "${WMS_DBNAME:-}" ]]; then
  WARNINGS+=("WMS_DBNAME is not set (WMS functionality may be affected)")
 fi

 if [[ -z "${WMS_DBUSER:-}" ]]; then
  WARNINGS+=("WMS_DBUSER is not set (WMS functionality may be affected)")
 fi

 # Report validation errors
 if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
  echo "ERROR: Database variable validation failed:" >&2
  for ERROR in "${VALIDATION_ERRORS[@]}"; do
   echo "  - ${ERROR}" >&2
  done
  return 1
 fi

 # Report warnings
 if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo "WARNING: Database variable warnings:" >&2
  for WARNING in "${WARNINGS[@]}"; do
   echo "  - ${WARNING}" >&2
  done
 fi

 echo "DEBUG: Database variable validation passed" >&2
 return 0
}

# Validates PostgreSQL variables
# This function ensures that all PostgreSQL variables are properly set
# Parameters: None
# Returns: 0 if validation passes, 1 if validation fails
function __validate_postgres_variables() {
 local VALIDATION_ERRORS=()

 # Check PostgreSQL variables
 if [[ -z "${POSTGRES_11_CHECK_BASE_TABLES:-}" ]]; then
  VALIDATION_ERRORS+=("POSTGRES_11_CHECK_BASE_TABLES is not set")
 fi

 if [[ -z "${POSTGRES_12_DROP_GENERIC_OBJECTS:-}" ]]; then
  VALIDATION_ERRORS+=("POSTGRES_12_DROP_GENERIC_OBJECTS is not set")
 fi

 if [[ -z "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY:-}" ]]; then
  VALIDATION_ERRORS+=("POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY is not set")
 fi

 if [[ -z "${POSTGRES_22_CREATE_PROC_INSERT_NOTE:-}" ]]; then
  VALIDATION_ERRORS+=("POSTGRES_22_CREATE_PROC_INSERT_NOTE is not set")
 fi

 if [[ -z "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT:-}" ]]; then
  VALIDATION_ERRORS+=("POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT is not set")
 fi

 if [[ -z "${POSTGRES_31_ORGANIZE_AREAS:-}" ]]; then
  VALIDATION_ERRORS+=("POSTGRES_31_ORGANIZE_AREAS is not set")
 fi

 if [[ -z "${POSTGRES_32_UPLOAD_NOTE_LOCATION:-}" ]]; then
  VALIDATION_ERRORS+=("POSTGRES_32_UPLOAD_NOTE_LOCATION is not set")
 fi

 # Check if SQL files exist
 if [[ -n "${POSTGRES_11_CHECK_BASE_TABLES:-}" ]] && [[ ! -f "${POSTGRES_11_CHECK_BASE_TABLES}" ]]; then
  VALIDATION_ERRORS+=("SQL file not found: ${POSTGRES_11_CHECK_BASE_TABLES}")
 fi

 if [[ -n "${POSTGRES_12_DROP_GENERIC_OBJECTS:-}" ]] && [[ ! -f "${POSTGRES_12_DROP_GENERIC_OBJECTS}" ]]; then
  VALIDATION_ERRORS+=("SQL file not found: ${POSTGRES_12_DROP_GENERIC_OBJECTS}")
 fi

 if [[ -n "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY:-}" ]] && [[ ! -f "${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}" ]]; then
  VALIDATION_ERRORS+=("SQL file not found: ${POSTGRES_21_CREATE_FUNCTION_GET_COUNTRY}")
 fi

 if [[ -n "${POSTGRES_22_CREATE_PROC_INSERT_NOTE:-}" ]] && [[ ! -f "${POSTGRES_22_CREATE_PROC_INSERT_NOTE}" ]]; then
  VALIDATION_ERRORS+=("SQL file not found: ${POSTGRES_22_CREATE_PROC_INSERT_NOTE}")
 fi

 if [[ -n "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT:-}" ]] && [[ ! -f "${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}" ]]; then
  VALIDATION_ERRORS+=("SQL file not found: ${POSTGRES_23_CREATE_PROC_INSERT_NOTE_COMMENT}")
 fi

 if [[ -n "${POSTGRES_31_ORGANIZE_AREAS:-}" ]] && [[ ! -f "${POSTGRES_31_ORGANIZE_AREAS}" ]]; then
  VALIDATION_ERRORS+=("SQL file not found: ${POSTGRES_31_ORGANIZE_AREAS}")
 fi

 if [[ -n "${POSTGRES_32_UPLOAD_NOTE_LOCATION:-}" ]] && [[ ! -f "${POSTGRES_32_UPLOAD_NOTE_LOCATION}" ]]; then
  VALIDATION_ERRORS+=("SQL file not found: ${POSTGRES_32_UPLOAD_NOTE_LOCATION}")
 fi

 # Report validation errors
 if [[ ${#VALIDATION_ERRORS[@]} -gt 0 ]]; then
  echo "ERROR: PostgreSQL variable validation failed:" >&2
  for ERROR in "${VALIDATION_ERRORS[@]}"; do
   echo "  - ${ERROR}" >&2
  done
  return 1
 fi

 echo "DEBUG: PostgreSQL variable validation passed" >&2
 return 0
}


