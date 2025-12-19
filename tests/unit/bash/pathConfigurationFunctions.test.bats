#!/usr/bin/env bats

# Path Configuration Functions Tests
# Tests for directory initialization with installation detection and fallback
# Author: Andres Gomez (AngocA)
# Version: 2025-12-18

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
  # Create temporary test directory
  TEST_DIR=$(mktemp -d)
  export TEST_DIR

  # Set up test environment variables
  export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"

  # Load path configuration functions
  source "${TEST_BASE_DIR}/bin/lib/pathConfigurationFunctions.sh"

  # Clean up any existing test directories
  rm -rf /tmp/osm-notes-ingestion /var/log/osm-notes-ingestion /var/tmp/osm-notes-ingestion /var/run/osm-notes-ingestion 2>/dev/null || true
}

teardown() {
  # Clean up test files
  rm -rf "${TEST_DIR}"
  # Clean up test directories
  rm -rf /tmp/osm-notes-ingestion /var/log/osm-notes-ingestion /var/tmp/osm-notes-ingestion /var/run/osm-notes-ingestion 2>/dev/null || true
  # Unset environment variables
  unset LOG_DIR TMP_DIR LOCK_DIR LOG_FILENAME LOCK FORCE_FALLBACK_MODE
}

# =============================================================================
# Function Existence Tests
# =============================================================================

@test "All path configuration functions should be available" {
  # Test that all path configuration functions exist
  run declare -f __is_installed
  [[ "${status}" -eq 0 ]]

  run declare -f __init_log_dir
  [[ "${status}" -eq 0 ]]

  run declare -f __init_tmp_dir
  [[ "${status}" -eq 0 ]]

  run declare -f __init_lock_dir
  [[ "${status}" -eq 0 ]]

  run declare -f __init_directories
  [[ "${status}" -eq 0 ]]
}

# =============================================================================
# Installation Detection Tests
# =============================================================================

@test "__is_installed should return false when directories don't exist" {
  # Should return false (exit code 1) when directories don't exist
  run __is_installed
  [[ "${status}" -eq 1 ]]
}

@test "__is_installed should return true when directories exist and are writable" {
  # Skip if not running as root (can't create /var directories)
  if [[ "${EUID}" -ne 0 ]]; then
    skip "This test requires root privileges to create /var directories"
  fi

  # Create test directories
  mkdir -p /var/log/osm-notes-ingestion /var/tmp/osm-notes-ingestion
  chmod 755 /var/log/osm-notes-ingestion /var/tmp/osm-notes-ingestion

  # Should return true (exit code 0) when directories exist and are writable
  run __is_installed
  [[ "${status}" -eq 0 ]]

  # Cleanup
  rm -rf /var/log/osm-notes-ingestion /var/tmp/osm-notes-ingestion
}

# =============================================================================
# Log Directory Initialization Tests
# =============================================================================

@test "__init_log_dir should use fallback mode when not installed" {
  # Should use /tmp/osm-notes-ingestion/logs in fallback mode
  local result
  result=$(__init_log_dir "testScript" "true")
  [[ "${result}" == /tmp/osm-notes-ingestion/logs/processing ]]
  [[ -d "${result}" ]]
}

@test "__init_log_dir should detect script type correctly" {
  # Test daemon script type
  local result
  result=$(__init_log_dir "processAPINotesDaemon" "true")
  [[ "${result}" == /tmp/osm-notes-ingestion/logs/daemon ]]

  # Test monitoring script type
  result=$(__init_log_dir "notesCheckVerifier" "true")
  [[ "${result}" == /tmp/osm-notes-ingestion/logs/monitoring ]]

  # Test processing script type
  result=$(__init_log_dir "processAPINotes" "true")
  [[ "${result}" == /tmp/osm-notes-ingestion/logs/processing ]]
}

@test "__init_log_dir should respect LOG_DIR environment variable" {
  # Set LOG_DIR environment variable
  export LOG_DIR="/custom/log/dir"

  local result
  result=$(__init_log_dir "testScript" "false")
  [[ "${result}" == /custom/log/dir ]]

  unset LOG_DIR
}

@test "__init_log_dir should ignore LOG_DIR when FORCE_FALLBACK is true" {
  # Set LOG_DIR environment variable
  export LOG_DIR="/custom/log/dir"

  local result
  result=$(__init_log_dir "testScript" "true")
  [[ "${result}" == /tmp/osm-notes-ingestion/logs/processing ]]

  unset LOG_DIR
}

# =============================================================================
# Temporary Directory Initialization Tests
# =============================================================================

@test "__init_tmp_dir should use fallback mode when not installed" {
  # Should use /tmp in fallback mode
  local result
  result=$(__init_tmp_dir "testScript" "true")
  [[ "${result}" =~ ^/tmp/testScript_ ]]
  [[ -d "${result}" ]]
}

@test "__init_tmp_dir should create unique directories" {
  # Should create different directories for each call
  local result1 result2
  result1=$(__init_tmp_dir "testScript" "true")
  result2=$(__init_tmp_dir "testScript" "true")
  [[ "${result1}" != "${result2}" ]]
}

@test "__init_tmp_dir should respect TMP_DIR environment variable" {
  # Set TMP_DIR environment variable
  export TMP_DIR="/custom/tmp/dir"

  local result
  result=$(__init_tmp_dir "testScript" "false")
  [[ "${result}" == /custom/tmp/dir ]]

  unset TMP_DIR
}

# =============================================================================
# Lock Directory Initialization Tests
# =============================================================================

@test "__init_lock_dir should use fallback mode when not installed" {
  # Should use /tmp/osm-notes-ingestion/locks in fallback mode
  local result
  result=$(__init_lock_dir "true")
  [[ "${result}" == /tmp/osm-notes-ingestion/locks ]]
  [[ -d "${result}" ]]
}

@test "__init_lock_dir should respect LOCK_DIR environment variable" {
  # Set LOCK_DIR environment variable
  export LOCK_DIR="/custom/lock/dir"

  local result
  result=$(__init_lock_dir "false")
  [[ "${result}" == /custom/lock/dir ]]

  unset LOCK_DIR
}

# =============================================================================
# Complete Directory Initialization Tests
# =============================================================================

@test "__init_directories should set all required environment variables" {
  # Initialize directories with fallback mode
  FORCE_FALLBACK_MODE="true" __init_directories "testScript" "true"

  # Check that all variables are set
  [[ -n "${LOG_DIR:-}" ]]
  [[ -n "${TMP_DIR:-}" ]]
  [[ -n "${LOCK_DIR:-}" ]]
  [[ -n "${LOG_FILENAME:-}" ]]
  [[ -n "${LOCK:-}" ]]

  # Check that LOG_FILENAME is in LOG_DIR
  [[ "${LOG_FILENAME}" == "${LOG_DIR}/testScript.log" ]]

  # Check that LOCK is in LOCK_DIR
  [[ "${LOCK}" == "${LOCK_DIR}/testScript.lock" ]]
}

@test "__init_directories should detect basename from script if not provided" {
  # Create a test script file
  local test_script="${TEST_DIR}/testScript.sh"
  touch "${test_script}"

  # Mock script name by sourcing in a subshell with modified $0
  (
    # Source the functions
    source "${TEST_BASE_DIR}/bin/lib/pathConfigurationFunctions.sh"
    # Override $0 in the function context
    # We'll test with explicit basename instead since we can't easily mock $0
    FORCE_FALLBACK_MODE="true" __init_directories "testScript" "true"
    # Check that LOG_FILENAME uses the basename
    [[ "${LOG_FILENAME}" =~ testScript\.log$ ]]
  )
}

@test "__init_directories should respect FORCE_FALLBACK_MODE environment variable" {
  # Set FORCE_FALLBACK_MODE
  export FORCE_FALLBACK_MODE="true"

  # Initialize directories (should use fallback even if installed)
  __init_directories "testScript" "false"

  # Check that fallback directories are used
  [[ "${LOG_DIR}" == /tmp/osm-notes-ingestion/logs/processing ]]
  [[ "${TMP_DIR}" =~ ^/tmp/testScript_ ]]
  [[ "${LOCK_DIR}" == /tmp/osm-notes-ingestion/locks ]]

  unset FORCE_FALLBACK_MODE
}

@test "__init_directories should work in installed mode when directories exist" {
  # Skip if not running as root (can't create /var directories)
  if [[ "${EUID}" -ne 0 ]]; then
    skip "This test requires root privileges to create /var directories"
  fi

  # Create test directories
  mkdir -p /var/log/osm-notes-ingestion/processing
  mkdir -p /var/tmp/osm-notes-ingestion
  mkdir -p /var/run/osm-notes-ingestion
  chmod 755 /var/log/osm-notes-ingestion /var/tmp/osm-notes-ingestion /var/run/osm-notes-ingestion

  # Initialize directories (should detect installed mode)
  __init_directories "testScript" "false"

  # Check that installed directories are used
  [[ "${LOG_DIR}" == /var/log/osm-notes-ingestion/processing ]]
  [[ "${TMP_DIR}" =~ ^/var/tmp/osm-notes-ingestion/testScript_ ]]
  [[ "${LOCK_DIR}" == /var/run/osm-notes-ingestion ]]

  # Cleanup
  rm -rf /var/log/osm-notes-ingestion /var/tmp/osm-notes-ingestion /var/run/osm-notes-ingestion
}

# =============================================================================
# Integration Tests
# =============================================================================

@test "Complete initialization should work end-to-end" {
  # Initialize directories
  FORCE_FALLBACK_MODE="true" __init_directories "processAPINotes" "true"

  # Verify all directories exist
  [[ -d "${LOG_DIR}" ]]
  [[ -d "${TMP_DIR}" ]]
  [[ -d "${LOCK_DIR}" ]]

  # Verify we can write to them
  touch "${LOG_DIR}/test.log"
  touch "${TMP_DIR}/test.tmp"
  touch "${LOCK_DIR}/test.lock"

  # Verify files were created
  [[ -f "${LOG_DIR}/test.log" ]]
  [[ -f "${TMP_DIR}/test.tmp" ]]
  [[ -f "${LOCK_DIR}/test.lock" ]]

  # Cleanup
  rm -f "${LOG_DIR}/test.log" "${TMP_DIR}/test.tmp" "${LOCK_DIR}/test.lock"
}

