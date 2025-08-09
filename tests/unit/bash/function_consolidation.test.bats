#!/usr/bin/env bats

# Unit tests for Function Consolidation
# Test file: function_consolidation.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

load "../../test_helper.bash"

setup() {
  # Source the consolidated functions
  source "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"
}

@test "No validation functions should be duplicated between validationFunctions.sh and functionsProcess.sh" {
  local VALIDATION_FUNCTIONS=(
    "__validate_input_file"
    "__validate_input_files"
    "__validate_xml_structure"
    "__validate_csv_structure"
    "__validate_config_file"
    "__validate_sql_structure"
    "__validate_json_structure"
    "__validate_database_connection"
    "__validate_database_tables"
    "__validate_database_extensions"
    "__validate_file_checksum"
    "__validate_file_checksum_from_file"
    "__validate_directory_checksums"
    "__validate_json_schema"
    "__validate_coordinates"
    "__validate_numeric_range"
    "__validate_string_pattern"
    "__validate_csv_coordinates"
    "__validate_csv_dates"
    "__validate_database_variables"
  )
  
  local duplicated_functions=""
  
  for func in "${VALIDATION_FUNCTIONS[@]}"; do
    # Count occurrences in functionsProcess.sh (should only have comments, not actual function definitions)
    local count_in_process
    count_in_process=$(grep -c "^function ${func}()" "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh" 2>/dev/null || echo "0")
    
    if [[ "${count_in_process}" -gt 0 ]]; then
      duplicated_functions+="${func} "
    fi
  done
  
  if [[ -n "${duplicated_functions}" ]]; then
    echo "ERROR: Found duplicated validation functions in functionsProcess.sh: ${duplicated_functions}"
    return 1
  fi
  
  return 0
}

@test "All consolidated validation functions should be available" {
  local VALIDATION_FUNCTIONS=(
    "__validate_input_file"
    "__validate_coordinates"
    "__validate_xml_structure"
    "__validate_json_structure"
    "__validate_database_connection"
  )
  
  for func in "${VALIDATION_FUNCTIONS[@]}"; do
    if ! declare -f "${func}" > /dev/null 2>&1; then
      echo "ERROR: Function ${func} is not available"
      return 1
    fi
  done
  
  return 0
}

@test "Consolidated functions should work correctly" {
  # Test __validate_input_file
  run __validate_input_file "${SCRIPT_BASE_DIRECTORY}/README.md" "Test file"
  [ "$status" -eq 0 ]
  
  # Test __validate_coordinates
  run __validate_coordinates "40.7128" "-74.0060"
  [ "$status" -eq 0 ]
  
  # Test with invalid coordinates
  run __validate_coordinates "100.0" "-74.0060"
  [ "$status" -eq 1 ]
}

@test "functionsProcess.sh should be significantly smaller after consolidation" {
  # Check that functionsProcess.sh has been reduced
  local line_count
  line_count=$(wc -l < "${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh")
  
  # Should be less than 3500 lines (was ~3900 before consolidation)
  if [[ "${line_count}" -gt 3500 ]]; then
    echo "ERROR: functionsProcess.sh still has ${line_count} lines, expected < 3500 after consolidation"
    return 1
  fi
  
  echo "SUCCESS: functionsProcess.sh has ${line_count} lines (reduced from ~3900)"
  return 0
}

@test "validationFunctions.sh should contain enhanced versions of functions" {
  # Test that enhanced features are available
  
  # Test __validate_input_file with directory type
  run __validate_input_file "${SCRIPT_BASE_DIRECTORY}" "Test directory" "dir"
  [ "$status" -eq 0 ]
  
  # Test __validate_coordinates with precision
  run __validate_coordinates "40.7128" "-74.0060" 4
  [ "$status" -eq 0 ]
  
  # Test precision validation (should pass with default precision)
  run __validate_coordinates "40.7128000" "-74.0060000"
  [ "$status" -eq 0 ]
}
