#!/bin/bash

# Basic integration tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

echo "=== RUNNING BASIC INTEGRATION TESTS ==="

# Test 1: Script loading
echo "1. Testing script loading..."
if source bin/functionsProcess.sh > /dev/null 2>&1; then
  echo "✓ Script loading test passed"
else
  echo "✗ Script loading test failed"
  exit 1
fi

# Test 2: Function availability
echo "2. Testing function availability..."
if declare -f __checkPrereqsCommands > /dev/null 2>&1; then
  echo "✓ Function availability test passed"
else
  echo "✗ Function availability test failed"
  exit 1
fi

# Test 3: Help functionality
echo "3. Testing help functionality..."
# The help command should exit with code 1 (ERROR_HELP_MESSAGE)
if timeout 10s bin/process/processAPINotes.sh --help > /dev/null 2>&1; then
  echo "✗ Help functionality test failed (should exit with code 1)"
else
  echo "✓ Help functionality test passed (exited with expected code 1)"
fi

# Test 4: SQL file validation
echo "4. Testing SQL file validation..."
sql_files_valid=true
for sql_file in sql/process/*.sql; do
  if [[ -f "$sql_file" ]]; then
    if ! grep -q "CREATE\|INSERT\|UPDATE\|SELECT\|DROP\|VACUUM\|ANALYZE" "$sql_file"; then
      echo "✗ SQL file validation failed for $sql_file"
      sql_files_valid=false
    fi
  fi
done

if [[ "$sql_files_valid" == "true" ]]; then
  echo "✓ SQL file validation test passed"
else
  echo "✗ SQL file validation test failed"
  exit 1
fi

# Test 5: XSLT file validation
echo "5. Testing XSLT file validation..."
xslt_files_valid=true
for xslt_file in xslt/*.xslt; do
  if [[ -f "$xslt_file" ]]; then
    if ! grep -q "xsl:stylesheet\|xsl:template" "$xslt_file"; then
      echo "✗ XSLT file validation failed for $xslt_file"
      xslt_files_valid=false
    fi
  fi
done

if [[ "$xslt_files_valid" == "true" ]]; then
  echo "✓ XSLT file validation test passed"
else
  echo "✗ XSLT file validation test failed"
  exit 1
fi

# Test 6: Properties file validation
echo "6. Testing properties file validation..."
if [[ -f etc/etl.properties ]] && [[ -f etc/properties.sh ]]; then
  echo "✓ Properties file validation test passed"
else
  echo "✗ Properties file validation test failed"
  exit 1
fi

echo "=== BASIC INTEGRATION TESTS COMPLETED ==="
echo "All basic integration tests passed! 🎉" 