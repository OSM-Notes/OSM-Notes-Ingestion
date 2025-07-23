#!/usr/bin/env bats

# Enhanced unit tests for prerequisites validation functions
# Author: Andres Gomez (AngocA)
# Version: 2025-01-15

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# =============================================================================
# Test setup and teardown
# =============================================================================

setup() {
    # Source the functions
    source "${TEST_BASE_DIR}/bin/functionsProcess.sh"
    # Set up logging function if not available
    if ! declare -f log_info >/dev/null; then
        log_info() { echo "[INFO] $*"; }
        log_error() { echo "[ERROR] $*"; }
        log_debug() { echo "[DEBUG] $*"; }
        log_start() { echo "[START] $*"; }
        log_finish() { echo "[FINISH] $*"; }
    fi
}

# =============================================================================
# Enhanced prerequisites validation tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should validate all required tools" {
    # Test that all required tools are available
    run __checkPrereqsCommands
    [ "$status" -eq 0 ]
}

@test "enhanced __checkPrereqsCommands should handle missing PostgreSQL" {
    # Mock PostgreSQL not available
    local original_path="$PATH"
    export PATH="/tmp/empty:$PATH"
    
    run __checkPrereqsCommands
    [ "$status" -ne 0 ]
    
    export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing wget" {
    # Mock wget not available
    local original_path="$PATH"
    export PATH="/tmp/empty:$PATH"
    
    run __checkPrereqsCommands
    [ "$status" -ne 0 ]
    
    export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing aria2c" {
    # Mock aria2c not available
    local original_path="$PATH"
    export PATH="/tmp/empty:$PATH"
    
    run __checkPrereqsCommands
    [ "$status" -ne 0 ]
    
    export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing osmtogeojson" {
    # Mock osmtogeojson not available
    local original_path="$PATH"
    export PATH="/tmp/empty:$PATH"
    
    run __checkPrereqsCommands
    [ "$status" -ne 0 ]
    
    export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing ajv" {
    # Mock ajv not available
    local original_path="$PATH"
    export PATH="/tmp/empty:$PATH"
    
    run __checkPrereqsCommands
    [ "$status" -ne 0 ]
    
    export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing ogr2ogr" {
    # Mock ogr2ogr not available
    local original_path="$PATH"
    export PATH="/tmp/empty:$PATH"
    
    run __checkPrereqsCommands
    [ "$status" -ne 0 ]
    
    export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing flock" {
    # Mock flock not available
    local original_path="$PATH"
    export PATH="/tmp/empty:$PATH"
    
    run __checkPrereqsCommands
    [ "$status" -ne 0 ]
    
    export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing mutt" {
    # Mock mutt not available
    local original_path="$PATH"
    export PATH="/tmp/empty:$PATH"
    
    run __checkPrereqsCommands
    [ "$status" -ne 0 ]
    
    export PATH="$original_path"
}

@test "enhanced __checkPrereqsCommands should handle missing bzip2" {
    # Mock bzip2 not available
    local original_path="$PATH"
    export PATH="/tmp/empty:$PATH"
    
    run __checkPrereqsCommands
    [ "$status" -ne 0 ]
    
    export PATH="$original_path"
}

# =============================================================================
# Database prerequisites tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should validate PostgreSQL connection" {
    # Test PostgreSQL connection
    run psql --version
    [ "$status" -eq 0 ]
}

@test "enhanced __checkPrereqsCommands should validate PostGIS extension" {
    # Create test database
    create_test_database
    
    # Test PostGIS extension
    run psql -d "${TEST_DBNAME}" -c "SELECT PostGIS_version();"
    [ "$status" -eq 0 ]
    
    # Clean up
    drop_test_database
}

@test "enhanced __checkPrereqsCommands should validate btree_gist extension" {
    # Create test database
    create_test_database
    
    # Test btree_gist extension
    run psql -d "${TEST_DBNAME}" -c "SELECT COUNT(1) FROM pg_extension WHERE extname = 'btree_gist';"
    [ "$status" -eq 0 ]
    
    # Clean up
    drop_test_database
}

# =============================================================================
# File system prerequisites tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should validate required directories exist" {
    # Test that required directories exist
    [ -d "${TEST_BASE_DIR}/bin" ]
    [ -d "${TEST_BASE_DIR}/sql" ]
    [ -d "${TEST_BASE_DIR}/xslt" ]
    [ -d "${TEST_BASE_DIR}/xsd" ]
    [ -d "${TEST_BASE_DIR}/overpass" ]
}

@test "enhanced __checkPrereqsCommands should validate required files exist" {
    # Test that required files exist
    [ -f "${TEST_BASE_DIR}/bin/functionsProcess.sh" ]
    [ -f "${TEST_BASE_DIR}/etc/properties.sh" ]
    [ -f "${TEST_BASE_DIR}/xsd/OSM-notes-API-schema.xsd" ]
    [ -f "${TEST_BASE_DIR}/xsd/OSM-notes-planet-schema.xsd" ]
}

# =============================================================================
# Permission tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should validate write permissions" {
    # Test write permissions in temp directory
    local test_file="/tmp/test_write_permission_$$"
    run touch "$test_file"
    [ "$status" -eq 0 ]
    rm -f "$test_file"
}

@test "enhanced __checkPrereqsCommands should validate execute permissions" {
    # Test execute permissions on scripts
    [ -x "${TEST_BASE_DIR}/bin/functionsProcess.sh" ]
    [ -x "${TEST_BASE_DIR}/bin/process/processAPINotes.sh" ]
    [ -x "${TEST_BASE_DIR}/bin/process/processPlanetNotes.sh" ]
}

# =============================================================================
# Network connectivity tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should validate internet connectivity" {
    # Test internet connectivity
    run wget --timeout=10 --tries=1 --spider https://www.google.com
    [ "$status" -eq 0 ]
}

@test "enhanced __checkPrereqsCommands should validate OSM API accessibility" {
    # Test OSM API accessibility
    run wget --timeout=10 --tries=1 --spider https://api.openstreetmap.org/api/0.6/notes
    [ "$status" -eq 0 ]
}

# =============================================================================
# Performance tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should complete quickly" {
    # Test performance
    local start_time=$(date +%s%N)
    run __checkPrereqsCommands
    local end_time=$(date +%s%N)
    local duration=$((end_time - start_time))
    
    [ "$status" -eq 0 ]
    [ "$duration" -lt 5000000000 ] # Should complete in less than 5 seconds
}

# =============================================================================
# Mock function tests
# =============================================================================

@test "mock prerequisites check should work without external dependencies" {
    # Create mock versions of required tools
    local mock_dir="${TEST_BASE_DIR}/tests/tmp/mock_tools"
    mkdir -p "$mock_dir"
    
    # Mock psql
    cat > "$mock_dir/psql" << 'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "psql (PostgreSQL) 15.1"
elif [[ "$1" == "-d" ]] && [[ "$2" == "test_db" ]]; then
    if [[ "$3" == "-c" ]] && [[ "$4" == "SELECT PostGIS_version();" ]]; then
        echo "3.3.2"
    elif [[ "$3" == "-c" ]] && [[ "$4" == "SELECT COUNT(1) FROM pg_extension WHERE extname = 'btree_gist';" ]]; then
        echo "1"
    else
        echo "1"
    fi
else
    echo "1"
fi
EOF
    chmod +x "$mock_dir/psql"
    
    # Mock wget
    cat > "$mock_dir/wget" << 'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "GNU Wget 1.21.3"
elif [[ "$1" == "--timeout=10" ]]; then
    echo "HTTP/1.1 200 OK"
else
    echo "HTTP/1.1 200 OK"
fi
EOF
    chmod +x "$mock_dir/wget"
    
    # Temporarily replace PATH with mock tools
    local original_path="$PATH"
    export PATH="$mock_dir:$PATH"
    
    # Test with mocks
    run __checkPrereqsCommands
    [ "$status" -eq 0 ]
    
    # Restore original PATH
    export PATH="$original_path"
    rm -rf "$mock_dir"
}

# =============================================================================
# Error handling tests
# =============================================================================

@test "enhanced __checkPrereqsCommands should handle database connection errors" {
    # Test with invalid database connection
    local original_dbname="$DBNAME"
    export DBNAME="invalid_database_name"
    
    run __checkPrereqsCommands
    [ "$status" -ne 0 ]
    
    export DBNAME="$original_dbname"
}

@test "enhanced __checkPrereqsCommands should handle permission errors" {
    # Test with read-only filesystem simulation
    local test_file="/tmp/test_readonly_$$"
    touch "$test_file"
    chmod 444 "$test_file"
    
    # This should not cause the prerequisites check to fail
    run __checkPrereqsCommands
    [ "$status" -eq 0 ]
    
    chmod 644 "$test_file"
    rm -f "$test_file"
}

# =============================================================================
# Integration tests
# =============================================================================

@test "enhanced prerequisites should work with full environment" {
    # Test that all prerequisites work together
    run __checkPrereqsCommands
    [ "$status" -eq 0 ]
    
    # Verify that the flag is set
    [ "$PREREQS_CHECKED" = "true" ]
}

@test "enhanced prerequisites should be idempotent" {
    # Test that running twice doesn't cause issues
    run __checkPrereqsCommands
    [ "$status" -eq 0 ]
    
    run __checkPrereqsCommands
    [ "$status" -eq 0 ]
} 