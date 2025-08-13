#!/bin/bash

# Verify CI Environment for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

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
   cat /tmp/test_output.csv
  else
   log_warning "⚠ xsltproc transformation failed"
  fi
 else
  log_error "✗ xsltproc not available"
 fi

 # Test xmllint
 if command -v xmllint &> /dev/null; then
  if xmllint --noout /tmp/test.xml 2> /dev/null; then
   log_success "✓ xmllint validation successful"
  else
   log_warning "⚠ xmllint validation failed"
  fi
 else
  log_error "✗ xmllint not available"
 fi

 # Cleanup
 rm -f /tmp/test.xml /tmp/test.xslt /tmp/test_output.csv
}

# Function to test shell formatting
test_shell_formatting() {
 log_info "Testing shell formatting capabilities..."

 # Create a simple test shell script
 cat > /tmp/test.sh << 'EOF'
#!/bin/bash
# Test script for formatting
VAR1="value1"
VAR2="value2"
echo "$VAR1 $VAR2"
EOF

 # Test shfmt
 if command -v shfmt &> /dev/null; then
  if shfmt -d /tmp/test.sh &> /dev/null; then
   log_success "✓ shfmt formatting check successful"
  else
   log_warning "⚠ shfmt formatting check failed"
  fi
 else
  log_error "✗ shfmt not available"
 fi

 # Test shellcheck
 if command -v shellcheck &> /dev/null; then
  if shellcheck /tmp/test.sh &> /dev/null; then
   log_success "✓ shellcheck linting successful"
  else
   log_warning "⚠ shellcheck linting failed"
  fi
 else
  log_error "✗ shellcheck not available"
 fi

 # Cleanup
 rm -f /tmp/test.sh
}

# Function to test database connectivity
test_database_connectivity() {
 log_info "Testing database connectivity..."

 if command -v psql &> /dev/null; then
  if command -v pg_isready &> /dev/null; then
   log_success "✓ PostgreSQL client tools available"
  else
   log_warning "⚠ pg_isready not available"
  fi
 else
  log_error "✗ psql not available"
 fi
}

# Function to test BATS framework
test_bats_framework() {
 log_info "Testing BATS framework..."

 if command -v bats &> /dev/null; then
  local bats_version
  bats_version=$(bats --version 2> /dev/null || echo "unknown")
  log_success "✓ BATS is available (version: ${bats_version})"

  # Test BATS with a simple test
  cat > /tmp/test_bats.bats << 'EOF'
#!/usr/bin/env bats

@test "simple test" {
  result="$(echo 'hello world')"
  [ "$result" = "hello world" ]
}
EOF

  if bats /tmp/test_bats.bats &> /dev/null; then
   log_success "✓ BATS test execution successful"
  else
   log_warning "⚠ BATS test execution failed"
  fi

  rm -f /tmp/test_bats.bats
 else
  log_error "✗ BATS not available"
 fi
}

# Main execution
main() {
 echo "=========================================="
 echo "OSM-Notes-profile CI Environment Verification"
 echo "=========================================="
 echo

 # Test basic tools
 test_tool "xsltproc" "xsltproc" "xsltproc --version" "XSLT processor"
 test_tool "xmllint" "xmllint" "xmllint --version" "XML validator"
 test_tool "shfmt" "shfmt" "shfmt --version" "Shell formatter"
 test_tool "shellcheck" "shellcheck" "shellcheck --version" "Shell linter"
 test_tool "bats" "bats" "bats --version" "BATS testing framework"
 test_tool "psql" "psql" "psql --version" "PostgreSQL client"
 test_tool "pg_isready" "pg_isready" "pg_isready --version" "PostgreSQL readiness checker"

 echo
 echo "=========================================="
 echo "Advanced Capability Tests"
 echo "=========================================="

 # Test XSLT processing
 test_xslt_processing

 # Test shell formatting
 test_shell_formatting

 # Test database connectivity
 test_database_connectivity

 # Test BATS framework
 test_bats_framework

 echo
 echo "=========================================="
 echo "Verification Summary"
 echo "=========================================="
 echo "Total tools tested: ${TOTAL_TOOLS}"
 echo "Available tools: ${AVAILABLE_TOOLS}"
 echo "Missing/failed tools: ${MISSING_TOOLS}"

 if [[ ${MISSING_TOOLS} -eq 0 ]]; then
  log_success "All tools are available and working! 🎉"
  exit 0
 else
  log_warning "Some tools are missing or not working properly"
  log_info "Please check the installation of missing tools"
  exit 1
 fi
}

# Run main function
main "$@"
