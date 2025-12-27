#!/usr/bin/env bash

# Test Selection Based on Changed Files
# Determines which tests to run based on git changes
# Author: Andres Gomez (AngocA)
# Version: 2025-12-23

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

# Default: run all tests if no changes detected or on schedule/manual
RUN_ALL_TESTS="${RUN_ALL_TESTS:-false}"

# =============================================================================
# Helper Functions
# =============================================================================

# Get changed files between two commits
# Usage: __get_changed_files [BASE_COMMIT] [HEAD_COMMIT]
__get_changed_files() {
 local BASE_COMMIT="${1:-}"
 local HEAD_COMMIT="${2:-}"
 
 if [[ -z "${BASE_COMMIT}" ]] || [[ -z "${HEAD_COMMIT}" ]]; then
  # For PRs, use GitHub's base and head
  if [[ -n "${GITHUB_BASE_REF:-}" ]] && [[ -n "${GITHUB_HEAD_REF:-}" ]]; then
   BASE_COMMIT="origin/${GITHUB_BASE_REF}"
   HEAD_COMMIT="HEAD"
  else
   # For pushes, compare with previous commit
   BASE_COMMIT="HEAD~1"
   HEAD_COMMIT="HEAD"
  fi
 fi
 
 # Get changed files
 git diff --name-only "${BASE_COMMIT}" "${HEAD_COMMIT}" 2>/dev/null || echo ""
}

# Check if any changed files match a pattern
# Usage: __has_changes [PATTERN1] [PATTERN2] ...
__has_changes() {
 local CHANGED_FILES="${1:-}"
 shift
 local PATTERNS=("$@")
 
 if [[ -z "${CHANGED_FILES}" ]]; then
  return 1
 fi
 
 for pattern in "${PATTERNS[@]}"; do
  if echo "${CHANGED_FILES}" | grep -qE "${pattern}"; then
   return 0
  fi
 done
 
 return 1
}

# =============================================================================
# Test Selection Logic
# =============================================================================

# Determine which tests to run based on changed files
# Sets output variables: RUN_BOUNDARY_TESTS, RUN_NOTE_TESTS, etc.
determine_test_selection() {
 local CHANGED_FILES
 CHANGED_FILES=$(__get_changed_files "$@")
 
 # If no changes detected or RUN_ALL_TESTS=true, run all tests
 if [[ -z "${CHANGED_FILES}" ]] || [[ "${RUN_ALL_TESTS}" == "true" ]]; then
  echo "Running all tests (no changes detected or RUN_ALL_TESTS=true)"
  export RUN_BOUNDARY_TESTS=true
  export RUN_NOTE_TESTS=true
  export RUN_SECURITY_TESTS=true
  export RUN_VALIDATION_TESTS=true
  export RUN_PERFORMANCE_TESTS=true
  export RUN_INTEGRATION_TESTS=true
  return 0
 fi
 
 echo "Changed files detected, analyzing..."
 echo "${CHANGED_FILES}" | head -20
 
 # Initialize all test flags to false
 export RUN_BOUNDARY_TESTS=false
 export RUN_NOTE_TESTS=false
 export RUN_SECURITY_TESTS=false
 export RUN_VALIDATION_TESTS=false
 export RUN_PERFORMANCE_TESTS=false
 export RUN_INTEGRATION_TESTS=false
 
 # Boundary processing tests
 if __has_changes "${CHANGED_FILES}" \
  "bin/lib/boundaryProcessingFunctions\.sh" \
  "bin/process/updateCountries\.sh" \
  "tests/unit/bash/boundary.*\.bats" \
  "tests/integration/boundaries.*\.bats" \
  "sql/.*boundary.*\.sql" \
  "sql/.*country.*\.sql"; then
  export RUN_BOUNDARY_TESTS=true
  echo "✓ Boundary tests selected"
 fi
 
 # Note processing tests
 if __has_changes "${CHANGED_FILES}" \
  "bin/lib/noteProcessingFunctions\.sh" \
  "bin/process/processAPINotes\.sh" \
  "bin/process/processPlanetNotes\.sh" \
  "bin/process/processAPINotesDaemon\.sh" \
  "tests/unit/bash/note.*\.bats" \
  "tests/unit/bash/processAPI.*\.bats" \
  "tests/unit/bash/processPlanet.*\.bats" \
  "tests/integration/api.*\.bats" \
  "tests/integration/planet.*\.bats" \
  "sql/.*note.*\.sql"; then
  export RUN_NOTE_TESTS=true
  echo "✓ Note processing tests selected"
 fi
 
 # Security tests
 if __has_changes "${CHANGED_FILES}" \
  "bin/lib/securityFunctions\.sh" \
  "tests/unit/bash/security.*\.bats"; then
  export RUN_SECURITY_TESTS=true
  echo "✓ Security tests selected"
 fi
 
 # Validation tests
 if __has_changes "${CHANGED_FILES}" \
  "bin/lib/.*validation.*\.sh" \
  "tests/unit/bash/.*validation.*\.bats" \
  "tests/integration/.*validation.*\.bats"; then
  export RUN_VALIDATION_TESTS=true
  echo "✓ Validation tests selected"
 fi
 
 # Performance tests
 if __has_changes "${CHANGED_FILES}" \
  "tests/unit/bash/performance.*\.bats" \
  "bin/lib/parallelProcessingFunctions\.sh"; then
  export RUN_PERFORMANCE_TESTS=true
  echo "✓ Performance tests selected"
 fi
 
 # Integration tests (run if any core functionality changed)
 if __has_changes "${CHANGED_FILES}" \
  "bin/lib/.*\.sh" \
  "bin/process/.*\.sh" \
  "tests/integration/.*\.bats" \
  "sql/.*\.sql"; then
  export RUN_INTEGRATION_TESTS=true
  echo "✓ Integration tests selected"
 fi
 
 # If no specific tests selected, run all tests (safety)
 if [[ "${RUN_BOUNDARY_TESTS}" != "true" ]] && \
    [[ "${RUN_NOTE_TESTS}" != "true" ]] && \
    [[ "${RUN_SECURITY_TESTS}" != "true" ]] && \
    [[ "${RUN_VALIDATION_TESTS}" != "true" ]] && \
    [[ "${RUN_PERFORMANCE_TESTS}" != "true" ]] && \
    [[ "${RUN_INTEGRATION_TESTS}" != "true" ]]; then
  echo "⚠️  No specific tests selected, running all tests for safety"
  export RUN_BOUNDARY_TESTS=true
  export RUN_NOTE_TESTS=true
  export RUN_SECURITY_TESTS=true
  export RUN_VALIDATION_TESTS=true
  export RUN_PERFORMANCE_TESTS=true
  export RUN_INTEGRATION_TESTS=true
 fi
}

# Generate test selection summary
# Usage: __print_test_selection_summary
__print_test_selection_summary() {
 echo ""
 echo "=== Test Selection Summary ==="
 echo "Boundary tests:     ${RUN_BOUNDARY_TESTS:-false}"
 echo "Note tests:         ${RUN_NOTE_TESTS:-false}"
 echo "Security tests:     ${RUN_SECURITY_TESTS:-false}"
 echo "Validation tests:   ${RUN_VALIDATION_TESTS:-false}"
 echo "Performance tests:  ${RUN_PERFORMANCE_TESTS:-false}"
 echo "Integration tests:  ${RUN_INTEGRATION_TESTS:-false}"
 echo ""
}

# =============================================================================
# Main Execution
# =============================================================================

# If script is executed directly (not sourced), run test selection
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 determine_test_selection "$@"
 __print_test_selection_summary
 
 # Export results for GitHub Actions
 if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
   echo "boundary_tests=${RUN_BOUNDARY_TESTS:-false}"
   echo "note_tests=${RUN_NOTE_TESTS:-false}"
   echo "security_tests=${RUN_SECURITY_TESTS:-false}"
   echo "validation_tests=${RUN_VALIDATION_TESTS:-false}"
   echo "performance_tests=${RUN_PERFORMANCE_TESTS:-false}"
   echo "integration_tests=${RUN_INTEGRATION_TESTS:-false}"
  } >> "${GITHUB_OUTPUT}"
 fi
fi

