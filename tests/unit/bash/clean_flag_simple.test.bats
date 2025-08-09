#!/usr/bin/env bats

# Simple tests for CLEAN flag handling
# Test file: clean_flag_simple.test.bats
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

load "../../test_helper.bash"

setup() {
  # Create temporary test files
  TEST_FILE_1="/tmp/test_cleanup_file1.txt"
  TEST_FILE_2="/tmp/test_cleanup_file2.txt"
  
  # Create test files
  echo "test content 1" > "${TEST_FILE_1}"
  echo "test content 2" > "${TEST_FILE_2}"
}

teardown() {
  # Clean up test files
  rm -f "${TEST_FILE_1}" "${TEST_FILE_2}"
  unset CLEAN
}

@test "CLEAN flag should be documented in processPlanetNotes" {
  # Check that CLEAN is documented in the script
  grep -q "CLEAN.*false.*left all created files" "${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
}

@test "CLEAN=false should be respected in error functions" {
  # Create a simple test script that uses the error function
  cat > /tmp/test_clean_script.sh << 'EOF'
#!/bin/bash
export CLEAN=false
source "${SCRIPT_BASE_DIRECTORY}/bin/errorHandlingFunctions.sh"

# Create test files
echo "content1" > /tmp/cleanup_test1.txt
echo "content2" > /tmp/cleanup_test2.txt

# Test the error function (mock exit to prevent script termination)
exit() { echo "EXIT_CALLED: $1"; return "$1"; }

# Call error function with cleanup
__handle_error_with_cleanup "1" "Test error" "rm -f /tmp/cleanup_test1.txt /tmp/cleanup_test2.txt"
EOF

  chmod +x /tmp/test_clean_script.sh
  
  # Run the test script
  run bash /tmp/test_clean_script.sh
  
  # Files should still exist because CLEAN=false
  [ -f "/tmp/cleanup_test1.txt" ]
  [ -f "/tmp/cleanup_test2.txt" ]
  
  # Clean up
  rm -f /tmp/test_clean_script.sh /tmp/cleanup_test1.txt /tmp/cleanup_test2.txt
}

@test "CLEAN=true should execute cleanup in error functions" {
  # Create a simple test script that uses the error function
  cat > /tmp/test_clean_script.sh << 'EOF'
#!/bin/bash
export CLEAN=true
source "${SCRIPT_BASE_DIRECTORY}/bin/errorHandlingFunctions.sh"

# Create test files
echo "content1" > /tmp/cleanup_test1.txt
echo "content2" > /tmp/cleanup_test2.txt

# Test the error function (mock exit to prevent script termination)
exit() { echo "EXIT_CALLED: $1"; return "$1"; }

# Call error function with cleanup
__handle_error_with_cleanup "1" "Test error" "rm -f /tmp/cleanup_test1.txt /tmp/cleanup_test2.txt"
EOF

  chmod +x /tmp/test_clean_script.sh
  
  # Run the test script
  run bash /tmp/test_clean_script.sh
  
  # Files should be deleted because CLEAN=true
  [ ! -f "/tmp/cleanup_test1.txt" ]
  [ ! -f "/tmp/cleanup_test2.txt" ]
  
  # Clean up
  rm -f /tmp/test_clean_script.sh
}

@test "Planet Notes checksum validation issue should be fixed" {
  # Test the exact scenario that was failing
  source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
  
  # Create mock Planet file and MD5
  echo "mock planet content" > /tmp/OSM-notes-planet.xml.bz2
  CHECKSUM=$(md5sum /tmp/OSM-notes-planet.xml.bz2 | cut -d' ' -f1)
  echo "${CHECKSUM}  planet-notes-latest.osn.bz2" > /tmp/OSM-notes-planet.xml.bz2.md5
  
  # This should now succeed (it used to fail with "Could not extract checksum")
  run __validate_file_checksum_from_file "/tmp/OSM-notes-planet.xml.bz2" "/tmp/OSM-notes-planet.xml.bz2.md5" "md5"
  [ "$status" -eq 0 ]
  
  # Clean up
  rm -f /tmp/OSM-notes-planet.xml.bz2 /tmp/OSM-notes-planet.xml.bz2.md5
}

@test "Original Planet Notes problem scenario should work" {
  # Simulate the exact failing scenario from the user's logs
  source "${SCRIPT_BASE_DIRECTORY}/bin/validationFunctions.sh"
  
  # Create the exact filename scenario
  echo "f451953cfcb4450a48a779d0a63dde5c  planet-notes-latest.osn.bz2" > /tmp/real_planet.md5
  
  # Create a dummy file with the local name
  echo "dummy content" > /tmp/OSM-notes-planet.xml.bz2
  
  # This should use fallback logic and not fail with "Could not extract checksum"
  # (It will fail with checksum mismatch, but that's expected with dummy content)
  run __validate_file_checksum_from_file "/tmp/OSM-notes-planet.xml.bz2" "/tmp/real_planet.md5" "md5"
  
  # Should not fail with "Could not extract checksum" error
  [[ "$output" != *"Could not extract checksum from file"* ]]
  
  # Clean up
  rm -f /tmp/real_planet.md5 /tmp/OSM-notes-planet.xml.bz2
}
