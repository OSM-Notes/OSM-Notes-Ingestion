#!/bin/bash

# Test variables validation functions
# Author: Andres Gomez (AngocA)
# Version: 2025-07-29

# Validates test database variables
# This function ensures that test database variables are properly set
# Parameters: None
# Returns: 0 if validation passes, 1 if validation fails
function __validate_test_database_variables() {
 local validation_errors=()
 local warnings=()

 # Check test database variables
 if [[ -z "${TEST_DBNAME:-}" ]]; then
  validation_errors+=("TEST_DBNAME is not set")
 fi

 if [[ -z "${TEST_DBUSER:-}" ]]; then
  validation_errors+=("TEST_DBUSER is not set")
 fi

 # Check WMS-specific variables (optional for tests)
 if [[ -z "${WMS_DBNAME:-}" ]]; then
  warnings+=("WMS_DBNAME is not set (WMS tests may be affected)")
 fi

 if [[ -z "${WMS_DBUSER:-}" ]]; then
  warnings+=("WMS_DBUSER is not set (WMS tests may be affected)")
 fi

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: Test database variable validation failed:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 # Report warnings
 if [[ ${#warnings[@]} -gt 0 ]]; then
  echo "WARNING: Test database variable warnings:" >&2
  for warning in "${warnings[@]}"; do
   echo "  - ${warning}" >&2
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
 local validation_errors=()
 local warnings=()

 # Check production database variables
 if [[ -z "${DBNAME:-}" ]]; then
  validation_errors+=("DBNAME is not set")
 fi

 if [[ -z "${DB_USER:-}" ]]; then
  validation_errors+=("DB_USER is not set")
 fi

 # Check test database variables
 if [[ -z "${TEST_DBNAME:-}" ]]; then
  validation_errors+=("TEST_DBNAME is not set")
 fi

 if [[ -z "${TEST_DBUSER:-}" ]]; then
  validation_errors+=("TEST_DBUSER is not set")
 fi

 # Check WMS-specific variables
 if [[ -z "${WMS_DBNAME:-}" ]]; then
  warnings+=("WMS_DBNAME is not set (WMS functionality may be affected)")
 fi

 if [[ -z "${WMS_DBUSER:-}" ]]; then
  warnings+=("WMS_DBUSER is not set (WMS functionality may be affected)")
 fi

 # Report validation errors
 if [[ ${#validation_errors[@]} -gt 0 ]]; then
  echo "ERROR: Database variable validation failed:" >&2
  for error in "${validation_errors[@]}"; do
   echo "  - ${error}" >&2
  done
  return 1
 fi

 # Report warnings
 if [[ ${#warnings[@]} -gt 0 ]]; then
  echo "WARNING: Database variable warnings:" >&2
  for warning in "${warnings[@]}"; do
   echo "  - ${warning}" >&2
  done
 fi

 echo "DEBUG: Database variable validation passed" >&2
 return 0
} 