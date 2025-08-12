#!/usr/bin/env bats

# Unit tests for XML resource limits functions
# Author: Andres Gomez (AngocA)
# Version: 2025-08-07

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# =============================================================================
# Test setup and teardown
# =============================================================================

setup() {
    # Set up required environment variables
    export BASENAME="test"
    export TMP_DIR="/tmp/test_$$"
    export DBNAME="${TEST_DBNAME:-test_db}"
    export SCRIPT_BASE_DIRECTORY="${TEST_BASE_DIR}"
    export LOG_FILENAME="/tmp/test.log"
    export LOCK="/tmp/test.lock"
    export MAX_THREADS="2"
    
    # Create test directory
    mkdir -p "${TMP_DIR}"
    
    # Set up logging functions if not available
    if ! declare -f __logd >/dev/null; then
        __logd() { echo "[DEBUG] $*"; }
        __logi() { echo "[INFO] $*"; }
        __logw() { echo "[WARN] $*"; }
        __loge() { echo "[ERROR] $*"; }
    fi
    
    # Load only the functions we need to test by extracting them
    # from the processPlanetNotes.sh file
    extract_resource_limit_functions
}

teardown() {
    # Clean up test files
    rm -rf "${TMP_DIR}" 2>/dev/null || true
}

# =============================================================================
# Helper functions
# =============================================================================

# Extract only the resource limit functions without loading the entire script
extract_resource_limit_functions() {
    # Extract the __monitor_xmllint_resources function
    sed -n '/^function __monitor_xmllint_resources/,/^}/p' "${TEST_BASE_DIR}/bin/process/processPlanetNotes.sh" > "${TMP_DIR}/monitor_function.sh"
    
    # Extract the __run_xmllint_with_limits function
    sed -n '/^function __run_xmllint_with_limits/,/^}/p' "${TEST_BASE_DIR}/bin/process/processPlanetNotes.sh" > "${TMP_DIR}/limits_function.sh"
    
    # Extract the __validate_xml_structure_only function
    sed -n '/^function __validate_xml_structure_only/,/^}/p' "${TEST_BASE_DIR}/bin/process/processPlanetNotes.sh" > "${TMP_DIR}/validate_function.sh"
    
    # Source the extracted functions
    source "${TMP_DIR}/monitor_function.sh"
    source "${TMP_DIR}/limits_function.sh"
    source "${TMP_DIR}/validate_function.sh"
}

# =============================================================================
# Test resource monitoring function
# =============================================================================

@test "test_monitor_xmllint_resources_function_exists" {
    # Verify function was extracted and loaded
    type __monitor_xmllint_resources
}

@test "test_monitor_xmllint_resources_with_short_process" {
    # Start a short-lived process to monitor
    sleep 3 &
    local test_pid=$!
    
    # Monitor the process for a short time
    local monitor_log="${TMP_DIR}/monitor_test.log"
    local monitor_pid=$(__monitor_xmllint_resources "${test_pid}" 1 "${monitor_log}")
    
    # Wait for the test process to finish
    wait "${test_pid}"
    
    # Stop monitoring
    if [[ -n "${monitor_pid}" ]]; then
        kill "${monitor_pid}" 2>/dev/null || true
    fi
    
    # Check that monitoring log was created
    [ -f "${monitor_log}" ]
    
    # Check log content
    run cat "${monitor_log}"
    echo "Monitor log content: $output"
    [[ "$output" =~ "Starting resource monitoring" ]]
    [[ "$output" =~ "PID: ${test_pid}" ]]
}

# =============================================================================
# Test resource limits function
# =============================================================================

@test "test_run_xmllint_with_limits_function_exists" {
    # Verify function was extracted and loaded
    type __run_xmllint_with_limits
}

@test "test_run_xmllint_with_limits_with_valid_xml" {
    # Create a small valid XML file for testing
    local test_xml="${TMP_DIR}/test_small.xml"
    cat > "${test_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
    <note id="1" lat="40.7128" lon="-74.0060">
        <date_created>2023-01-01T00:00:00Z</date_created>
        <status>open</status>
    </note>
</osm-notes>
EOF
    
    # Test the function with a small timeout and valid XML
    run __run_xmllint_with_limits 30 "--noout --nonet" "${test_xml}"
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Running xmllint with resource limits" ]]
}

@test "test_run_xmllint_with_limits_with_invalid_xml" {
    # Create an invalid XML file for testing
    local test_xml="${TMP_DIR}/test_invalid.xml"
    cat > "${test_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
    <note id="1" lat="40.7128" lon="-74.0060">
        <date_created>2023-01-01T00:00:00Z</date_created>
        <status>open</status>
    <!-- Missing closing note tag -->
</osm-notes>
EOF
    
    # Test the function with invalid XML
    run __run_xmllint_with_limits 30 "--noout --nonet" "${test_xml}"
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -ne 0 ]
    [[ "$output" =~ "xmllint validation failed" ]]
}

@test "test_cpulimit_availability_warning" {
    # Temporarily hide cpulimit if it exists
    local original_path="${PATH}"
    export PATH="/nonexistent:${PATH}"
    
    # Create a small valid XML file for testing
    local test_xml="${TMP_DIR}/test_nocpulimit.xml"
    cat > "${test_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
    <note id="1" lat="40.7128" lon="-74.0060">
        <date_created>2023-01-01T00:00:00Z</date_created>
        <status>open</status>
    </note>
</osm-notes>
EOF
    
    # Test the function without cpulimit available
    run __run_xmllint_with_limits 30 "--noout --nonet" "${test_xml}"
    
    # Restore PATH
    export PATH="${original_path}"
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "cpulimit not available" ]]
}

# =============================================================================
# Test validation function
# =============================================================================

@test "test_validate_xml_structure_only_function_exists" {
    # Verify function was extracted and loaded
    type __validate_xml_structure_only
}

@test "test_validate_xml_structure_only_with_valid_xml" {
    # Create a moderately sized valid XML file for testing
    local test_xml="${TMP_DIR}/test_medium.xml"
    cat > "${test_xml}" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
EOF
    
    # Add multiple notes to make it larger
    for i in {1..10}; do
        cat >> "${test_xml}" << EOF
    <note id="${i}" lat="40.$((i % 9999))" lon="-74.$((i % 9999))">
        <date_created>2023-01-01T00:00:00Z</date_created>
        <status>open</status>
        <comments>
            <comment>
                <date>2023-01-01T00:00:00Z</date>
                <uid>1</uid>
                <user>testuser</user>
                <user_url>http://example.com/user/1</user_url>
                <action>opened</action>
                <text>Test comment ${i}</text>
                <html>&lt;p&gt;Test comment ${i}&lt;/p&gt;</html>
            </comment>
        </comments>
    </note>
EOF
    done
    
    echo "</osm-notes>" >> "${test_xml}"
    
    # Test the function
    run __validate_xml_structure_only "${test_xml}"
    
    echo "Exit code: $status"
    echo "Output: $output"
    
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Structure-only validation passed for very large file" ]]
}
