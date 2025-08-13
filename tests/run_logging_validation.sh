#!/bin/bash

# Logging Pattern Validation Runner
# Script: run_logging_validation.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13
# Description: Runs the logging pattern validation tool

set -euo pipefail

# Source common functions
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_BASE_DIRECTORY}/lib/bash_logger.sh"

# Configuration
declare -r VALIDATION_SCRIPT="${SCRIPT_BASE_DIRECTORY}/tests/scripts/validate_logging_patterns.sh"

# Main execution
function main() {
 __log_start

 __logi "Running Logging Pattern Validation"
 __logi "This will check all bash functions in the project"

 # Check if validation script exists
 if [[ ! -f "${VALIDATION_SCRIPT}" ]]; then
  __loge "ERROR: Validation script not found: ${VALIDATION_SCRIPT}"
  __log_finish
  exit 1
 fi

 # Check if validation script is executable
 if [[ ! -x "${VALIDATION_SCRIPT}" ]]; then
  __loge "ERROR: Validation script is not executable: ${VALIDATION_SCRIPT}"
  __log_finish
  exit 1
 fi

 __logi "Executing validation script: ${VALIDATION_SCRIPT}"

 # Run validation
 if "${VALIDATION_SCRIPT}"; then
  __logi "Validation completed successfully"
  __log_finish
  exit 0
 else
  __loge "Validation completed with errors"
  __log_finish
  exit 1
 fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 main "$@"
fi
