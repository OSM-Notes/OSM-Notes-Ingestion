#!/bin/bash

# Verify CI Environment for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-14

set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Test counters
TOTAL_TOOLS=0
AVAILABLE_TOOLS=0
MISSING_TOOLS=0

# Function to test a tool
test_tool() {
    local tool_name="$1"
    local tool_path="$2"
    local test_command="$3"
    local description="$4"

    ((TOTAL_TOOLS++))

    if [[ -n "${tool_path}" ]] && command -v "${tool_path}" &> /dev/null; then
        log_info "Testing ${tool_name} (${description})..."

        if eval "${test_command}" &> /dev/null; then
            log_success "✓ ${tool_name} is available and working"
            ((AVAILABLE_TOOLS++))
            return 0
        else
            log_warning "⚠ ${tool_name} is available but test failed"
            ((MISSING_TOOLS++))
            return 1
        fi
    else
        log_error "✗ ${tool_name} is not available"
        ((MISSING_TOOLS++))
        return 1
    fi
}

# Function to test XSLT processing
test_xslt_processing() {
    log_info "Testing XSLT processing capabilities..."

    # Create a simple test XML file
    cat > /tmp/test.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<notes>
    <note id="1">
        <status>open</status>
        <created_at>2025-01-01T00:00:00Z</created_at>
    </note>
</notes>
EOF

    # Create a simple test XSLT file
    cat > /tmp/test.xslt << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="text"/>
    <xsl:template match="/">
        <xsl:for-each select="//note">
            <xsl:value-of select="@id"/>,<xsl:value-of select="status"/>,<xsl:value-of select="created_at"/>
            <xsl:text>&#10;</xsl:text>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>
EOF

    # Test xsltproc
    if command -v xsltproc &> /dev/null; then
        if xsltproc /tmp/test.xslt /tmp/test.xml > /tmp/test_output.csv 2> /dev/null; then
            log_success "✓ xsltproc transformation successful"
            echo "Output: $(cat /tmp/test_output.csv)"
        else
            log_error "✗ xsltproc transformation failed"
            return 1
        fi
    else
        log_error "✗ xsltproc not available"
        return 1
    fi

    # Clean up test files
    rm -f /tmp/test.xml /tmp/test.xslt /tmp/test_output.csv
}

# Function to test XML validation
test_xml_validation() {
    log_info "Testing XML validation capabilities..."

    # Create a simple test XML file
    cat > /tmp/test_validation.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<root>
    <element>test</element>
</root>
EOF

    # Test xmllint
    if command -v xmllint &> /dev/null; then
        if xmllint --noout /tmp/test_validation.xml 2> /dev/null; then
            log_success "✓ xmllint validation successful"
        else
            log_error "✗ xmllint validation failed"
            rm -f /tmp/test_validation.xml
            return 1
        fi
    else
        log_error "✗ xmllint not available"
        rm -f /tmp/test_validation.xml
        return 1
    fi

    # Clean up test files
    rm -f /tmp/test_validation.xml
}

# Function to test shell formatting
test_shell_formatting() {
    log_info "Testing shell formatting capabilities..."

    # Create a simple test shell script
    cat > /tmp/test_script.sh << 'EOF'
#!/bin/bash
# Test script
echo "Hello World"
EOF

    # Test shfmt
    if command -v shfmt &> /dev/null; then
        if shfmt -w /tmp/test_script.sh 2> /dev/null; then
            log_success "✓ shfmt formatting successful"
        else
            log_warning "⚠ shfmt formatting failed"
        fi
    else
        log_warning "⚠ shfmt not available"
    fi

    # Clean up test files
    rm -f /tmp/test_script.sh
}

# Function to test shell checking
test_shell_checking() {
    log_info "Testing shell checking capabilities..."

    # Create a simple test shell script
    cat > /tmp/test_check.sh << 'EOF'
#!/bin/bash
# Test script
echo "Hello World"
EOF

    # Test shellcheck
    if command -v shellcheck &> /dev/null; then
        if shellcheck /tmp/test_check.sh 2> /dev/null; then
            log_success "✓ shellcheck validation successful"
        else
            log_warning "⚠ shellcheck validation failed"
        fi
    else
        log_warning "⚠ shellcheck not available"
    fi

    # Clean up test files
    rm -f /tmp/test_check.sh
}

# Function to test BATS framework
test_bats_framework() {
    log_info "Testing BATS framework..."

    if command -v bats &> /dev/null; then
        # Create a simple test file
        cat > /tmp/test_bats.bats << 'EOF'
#!/usr/bin/env bats

@test "simple test" {
    [ 1 -eq 1 ]
}
EOF

        if bats /tmp/test_bats.bats 2> /dev/null; then
            log_success "✓ BATS framework working correctly"
        else
            log_warning "⚠ BATS framework test failed"
        fi

        # Clean up test files
        rm -f /tmp/test_bats.bats
    else
        log_warning "⚠ BATS not available"
    fi
}

# Function to test PostgreSQL client
test_postgresql_client() {
    log_info "Testing PostgreSQL client..."

    if command -v psql &> /dev/null; then
        log_success "✓ psql client available"
        log_info "psql version: $(psql --version)"
    else
        log_error "✗ psql client not available"
        return 1
    fi

    if command -v pg_isready &> /dev/null; then
        log_success "✓ pg_isready utility available"
    else
        log_error "✗ pg_isready utility not available"
        return 1
    fi
}

# Function to test environment variables
test_environment_variables() {
    log_info "Testing environment variables..."

    local required_vars=("TEST_DBNAME" "TEST_DBUSER" "TEST_DBHOST" "TEST_DBPORT")
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            log_success "✓ ${var} is set: ${!var}"
        else
            log_warning "⚠ ${var} is not set"
            missing_vars+=("${var}")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_warning "Some environment variables are missing: ${missing_vars[*]}"
        return 1
    fi

    return 0
}

# Function to test file permissions
test_file_permissions() {
    log_info "Testing file permissions..."

    local test_files=(
        "tests/verify_ci_environment.sh"
        "tests/setup_ci_environment.sh"
        "tests/run_tests.sh"
    )

    for file in "${test_files[@]}"; do
        if [[ -f "${file}" ]]; then
            if [[ -x "${file}" ]]; then
                log_success "✓ ${file} is executable"
            else
                log_warning "⚠ ${file} is not executable"
                chmod +x "${file}"
                log_info "Made ${file} executable"
            fi
        else
            log_warning "⚠ ${file} does not exist"
        fi
    done
}

# Main verification function
main() {
    log_info "Starting CI environment verification..."

    # Test basic tools
    test_tool "xsltproc" "xsltproc" "xsltproc --version" "XSLT processor"
    test_tool "xmllint" "xmllint" "xmllint --version" "XML validator"
    test_tool "shfmt" "shfmt" "shfmt --version" "Shell formatter"
    test_tool "shellcheck" "shellcheck" "shellcheck --version" "Shell linter"
    test_tool "bats" "bats" "bats --version" "BATS testing framework"

    # Test specialized functionality
    test_xslt_processing
    test_xml_validation
    test_shell_formatting
    test_shell_checking
    test_bats_framework
    test_postgresql_client

    # Test environment and permissions
    test_environment_variables
    test_file_permissions

    # Summary
    echo
    log_info "Verification Summary:"
    log_info "Total tools tested: ${TOTAL_TOOLS}"
    log_info "Available tools: ${AVAILABLE_TOOLS}"
    log_info "Missing/failed tools: ${MISSING_TOOLS}"

    if [[ ${MISSING_TOOLS} -eq 0 ]]; then
        log_success "All tools are available and working correctly!"
        exit 0
    else
        log_warning "Some tools are missing or not working correctly."
        log_info "Please check the installation of missing tools."
        exit 1
    fi
}

# Run main function
main "$@"
