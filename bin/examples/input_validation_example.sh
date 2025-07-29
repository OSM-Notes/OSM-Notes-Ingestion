#!/bin/bash

# Example script demonstrating input validation functions
# This script shows how to use the centralized validation functions
# to validate various types of input files before processing.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

# Load the functions
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." &> /dev/null && pwd)"
# shellcheck source=bin/functionsProcess.sh
source "${SCRIPT_BASE_DIRECTORY}/functionsProcess.sh"

# Example function that processes XML files
function process_xml_file() {
 local xml_file="${1}"
 
 echo "Processing XML file: ${xml_file}"
 
 # Validate XML file before processing
 if ! __validate_xml_structure "${xml_file}" "osm-notes"; then
  echo "ERROR: XML file validation failed, skipping processing"
  return 1
 fi
 
 echo "XML file validated successfully, proceeding with processing..."
 # Add your XML processing logic here
 return 0
}

# Example function that processes CSV files
function process_csv_file() {
 local csv_file="${1}"
 local expected_columns="${2:-}"
 
 echo "Processing CSV file: ${csv_file}"
 
 # Validate CSV file before processing
 if ! __validate_csv_structure "${csv_file}" "${expected_columns}"; then
  echo "ERROR: CSV file validation failed, skipping processing"
  return 1
 fi
 
 echo "CSV file validated successfully, proceeding with processing..."
 # Add your CSV processing logic here
 return 0
}

# Example function that processes SQL files
function process_sql_file() {
 local sql_file="${1}"
 
 echo "Processing SQL file: ${sql_file}"
 
 # Validate SQL file before processing
 if ! __validate_sql_structure "${sql_file}"; then
  echo "ERROR: SQL file validation failed, skipping processing"
  return 1
 fi
 
 echo "SQL file validated successfully, proceeding with processing..."
 # Add your SQL processing logic here
 return 0
}

# Example function that validates multiple input files
function validate_input_files() {
 local files=("$@")
 
 echo "Validating multiple input files..."
 
 if ! __validate_input_files "${files[@]}"; then
  echo "ERROR: Input file validation failed"
  return 1
 fi
 
 echo "All input files validated successfully"
 return 0
}

# Example function that validates configuration
function validate_configuration() {
 local config_file="${1}"
 
 echo "Validating configuration file: ${config_file}"
 
 if ! __validate_config_file "${config_file}"; then
  echo "ERROR: Configuration file validation failed"
  return 1
 fi
 
 echo "Configuration file validated successfully"
 return 0
}

# Main function demonstrating usage
function main() {
 echo "=== Input Validation Example ==="
 echo
 
 # Example 1: Validate a single file
 echo "Example 1: Validating a single file"
 if __validate_input_file "/etc/passwd" "System file"; then
  echo "✓ File validation passed"
 else
  echo "✗ File validation failed"
 fi
 echo
 
 # Example 2: Validate XML file
 echo "Example 2: Validating XML file"
 if process_xml_file "${SCRIPT_BASE_DIRECTORY}/../tests/fixtures/xml/planet_notes_sample.xml"; then
  echo "✓ XML processing completed"
 else
  echo "✗ XML processing failed"
 fi
 echo
 
 # Example 3: Validate CSV file
 echo "Example 3: Validating CSV file"
 # Create a temporary CSV file for testing
 temp_csv=$(mktemp)
 echo "id,name,value" > "${temp_csv}"
 echo "1,test,100" >> "${temp_csv}"
 
 if process_csv_file "${temp_csv}" "3"; then
  echo "✓ CSV processing completed"
 else
  echo "✗ CSV processing failed"
 fi
 
 rm -f "${temp_csv}"
 echo
 
 # Example 4: Validate SQL file
 echo "Example 4: Validating SQL file"
 if process_sql_file "${SCRIPT_BASE_DIRECTORY}/../sql/process/processPlanetNotes_21_createBaseTables_enum.sql"; then
  echo "✓ SQL processing completed"
 else
  echo "✗ SQL processing failed"
 fi
 echo
 
 # Example 5: Validate multiple files
 echo "Example 5: Validating multiple files"
 files=(
  "/etc/passwd"
  "/etc/hosts"
  "${SCRIPT_BASE_DIRECTORY}/../sql/process/processPlanetNotes_21_createBaseTables_enum.sql"
 )
 
 if validate_input_files "${files[@]}"; then
  echo "✓ Multiple file validation passed"
 else
  echo "✗ Multiple file validation failed"
 fi
 echo
 
 # Example 6: Validate configuration file
 echo "Example 6: Validating configuration file"
 if validate_configuration "${SCRIPT_BASE_DIRECTORY}/../etc/properties.sh"; then
  echo "✓ Configuration validation passed"
 else
  echo "✗ Configuration validation failed"
 fi
 echo
 
 echo "=== Example completed ==="
}

# Run the example if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 main
fi