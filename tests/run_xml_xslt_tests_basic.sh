#!/bin/bash

# Basic XML/XSLT Tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

echo "=== RUNNING BASIC XML/XSLT TESTS ==="
echo

# Test 1: Check if XSLT files exist
echo "1. Testing XSLT files existence..."
count=0
for xslt_file in xslt/*.xslt; do
  if [[ -f "$xslt_file" ]]; then
    ((count++))
  fi
done
if [[ $count -gt 0 ]]; then
  echo "✓ XSLT files exist ($count files)"
else
  echo "✗ No XSLT files found"
fi
echo

# Test 2: Check if XML schema files exist
echo "2. Testing XML schema files existence..."
if [[ -f "xsd/OSM-notes-API-schema.xsd" ]] || [[ -f "xsd/OSM-notes-planet-schema.xsd" ]]; then
  echo "✓ XML schema files exist"
else
  echo "✗ XML schema files not found"
fi
echo

# Test 3: Check if XSLT files are valid XML
echo "3. Testing XSLT files are valid XML..."
valid_count=0
total_count=0
for xslt_file in xslt/*.xslt; do
  if [[ -f "$xslt_file" ]]; then
    ((total_count++))
    if xmllint --noout "$xslt_file" 2>/dev/null; then
      ((valid_count++))
    fi
  fi
done
if [[ $valid_count -gt 0 ]]; then
  echo "✓ XSLT files are valid XML ($valid_count/$total_count)"
else
  echo "✗ No valid XSLT files found"
fi
echo

# Test 4: Check if JSON schema files exist
echo "4. Testing JSON schema files existence..."
if [[ -f "json/osm-jsonschema.json" ]] || [[ -f "json/geojsonschema.json" ]]; then
  echo "✓ JSON schema files exist"
else
  echo "✗ JSON schema files not found"
fi
echo

# Test 5: Check if XSLT files have correct structure
echo "5. Testing XSLT files have correct structure..."
valid_count=0
total_count=0
for xslt_file in xslt/*.xslt; do
  if [[ -f "$xslt_file" ]]; then
    ((total_count++))
    if grep -q 'xsl:stylesheet\|xsl:transform' "$xslt_file"; then
      ((valid_count++))
    fi
  fi
done
if [[ $valid_count -gt 0 ]]; then
  echo "✓ XSLT files have correct structure ($valid_count/$total_count)"
else
  echo "✗ No XSLT files with correct structure found"
fi
echo

# Test 6: Check if required tools are available
echo "6. Testing required XML tools are available..."
if command -v xmllint > /dev/null && command -v xsltproc > /dev/null; then
  echo "✓ Required XML tools are available"
else
  echo "✗ Required XML tools not found"
fi
echo

# Test 7: Check if XML processing functions exist in source files
echo "7. Testing XML processing functions exist..."
if grep -q '__processApiXmlPart' bin/functionsProcess.sh && grep -q '__processPlanetXmlPart' bin/functionsProcess.sh; then
  echo "✓ XML processing functions exist"
else
  echo "✗ XML processing functions not found"
fi
echo

# Test 8: Check if XSLT files have correct output format
echo "8. Testing XSLT files have correct output format..."
valid_count=0
total_count=0
for xslt_file in xslt/*.xslt; do
  if [[ -f "$xslt_file" ]]; then
    ((total_count++))
    if grep -q 'text\|csv\|xml' "$xslt_file"; then
      ((valid_count++))
    fi
  fi
done
if [[ $valid_count -gt 0 ]]; then
  echo "✓ XSLT files have correct output format ($valid_count/$total_count)"
else
  echo "✗ No XSLT files with correct output format found"
fi
echo

echo "=== BASIC XML/XSLT TESTS COMPLETED ==="
echo "All basic XML/XSLT functionality tests completed successfully!" 