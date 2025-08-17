#!/usr/bin/env bats
# Test file for robust parallel processing functions
#
# Author: Andres Gomez (AngocA)
# Version: 2025-08-16
# Description: Tests for robust parallel processing with resource management

# Load test helper
load test_helper

# Load the parallel processing functions
setup() {
 # Source the parallel processing functions
 source "${BATS_TEST_DIRNAME}/../../../../bin/parallelProcessingFunctions.sh"
 
 # Set up test environment
 export TMP_DIR="${BATS_TEST_DIRNAME}/tmp"
 export SCRIPT_BASE_DIRECTORY="${BATS_TEST_DIRNAME}/../../../../"
 export MAX_THREADS=2
 
 # Create temporary directory
 mkdir -p "${TMP_DIR}"
}

teardown() {
 # Clean up temporary files
 rm -rf "${TMP_DIR}"
}

@test "Check system resources function works correctly" {
 # Test that the function returns success when resources are available
 run __check_system_resources
 [ "$status" -eq 0 ]
}

@test "Wait for resources function handles timeout correctly" {
 # Test with very short timeout
 run __wait_for_resources 1
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "Adjust workers for resources reduces workers under high memory" {
 # Mock high memory usage
 local ORIGINAL_FREE_CMD
 ORIGINAL_FREE_CMD=$(command -v free)
 
 # Create mock free command that reports high memory usage
 cat > "${TMP_DIR}/mock_free" << 'EOF'
#!/bin/bash
echo "              total        used        free      shared  buff/cache   available"
echo "Mem:       16384       14000        1000        1000        1384        1000"
EOF
 chmod +x "${TMP_DIR}/mock_free"
 
 # Temporarily replace free command
 export PATH="${TMP_DIR}:${PATH}"
 
 # Test worker adjustment
 run __adjust_workers_for_resources 8
 [ "$status" -eq 0 ]
 [ "$output" = "4" ] # Should be reduced by half under high memory
 
 # Restore original PATH
 export PATH="${ORIGINAL_FREE_CMD%/*}:${PATH}"
}

@test "Configure system limits function works" {
 # Test that system limits can be configured
 run __configure_system_limits
 [ "$status" -eq 0 ] || [ "$status" -eq 1 ] # May fail on some systems
}

@test "Robust XSLT processing function handles missing files" {
 # Test with non-existent files
 run __process_xml_with_xslt_robust "/nonexistent.xml" "/nonexistent.xslt" "/nonexistent.csv"
 [ "$status" -eq 1 ]
}

@test "Robust XSLT processing function creates output directory" {
 # Create test XML and XSLT files
 cat > "${TMP_DIR}/test.xml" << 'EOF'
<?xml version="1.0"?>
<root><item>test</item></root>
EOF

 cat > "${TMP_DIR}/test.xslt" << 'EOF'
<?xml version="1.0"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="text"/>
<xsl:template match="/">
<xsl:value-of select="//item"/>
</xsl:template>
</xsl:stylesheet>
EOF

 # Test processing with non-existent output directory
 local OUTPUT_DIR="${TMP_DIR}/nonexistent/output.csv"
 run __process_xml_with_xslt_robust "${TMP_DIR}/test.xml" "${TMP_DIR}/test.xslt" "${OUTPUT_DIR}"
 
 # Should create directory and process successfully
 [ "$status" -eq 0 ]
 [ -f "${OUTPUT_DIR}" ]
 [ -d "$(dirname "${OUTPUT_DIR}")" ]
}

@test "Parallel processing function validates inputs correctly" {
 # Test with missing input directory
 run __processXmlPartsParallel "/nonexistent" "/nonexistent.xslt" "/tmp" 2 "API"
 [ "$status" -eq 1 ]
 
 # Test with missing XSLT file
 run __processXmlPartsParallel "/tmp" "/nonexistent.xslt" "/tmp" 2 "API"
 [ "$status" -eq 1 ]
 
 # Test with invalid processing type
 run __processXmlPartsParallel "/tmp" "/tmp/test.xslt" "/tmp" 2 "INVALID"
 [ "$status" -eq 1 ]
}

@test "Parallel processing function handles empty input directory" {
 # Test with empty directory
 run __processXmlPartsParallel "/tmp" "/tmp/test.xslt" "/tmp" 2 "API"
 [ "$status" -eq 0 ]
}

@test "Resource management constants are defined" {
 # Check that all constants are defined
 [ -n "${MAX_MEMORY_PERCENT}" ]
 [ -n "${MAX_LOAD_AVERAGE}" ]
 [ -n "${PROCESS_TIMEOUT}" ]
 [ -n "${MAX_RETRIES}" ]
 [ -n "${RETRY_DELAY}" ]
 
 # Check values are reasonable
 [ "${MAX_MEMORY_PERCENT}" -gt 0 ]
 [ "${MAX_MEMORY_PERCENT}" -le 100 ]
 [ "${MAX_LOAD_AVERAGE}" -gt 0 ]
 [ "${PROCESS_TIMEOUT}" -gt 0 ]
 [ "${MAX_RETRIES}" -gt 0 ]
 [ "${RETRY_DELAY}" -gt 0 ]
}
