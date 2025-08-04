#!/bin/bash

# Quick Error Handling Tests for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-03

echo "=== RUNNING QUICK ERROR HANDLING TESTS ==="

# Test 1: Check if error handling files exist
echo "1. Testing error handling files existence..."
if [[ -f "bin/errorHandlingFunctions.sh" ]] && [[ -f "bin/validationFunctions.sh" ]]; then
    echo "✓ Error handling files exist"
else
    echo "✗ Error handling files missing"
    exit 1
fi

# Test 2: Check if files are valid bash
echo "2. Testing bash syntax..."
if bash -n bin/errorHandlingFunctions.sh && bash -n bin/validationFunctions.sh; then
    echo "✓ Bash syntax is valid"
else
    echo "✗ Bash syntax errors found"
    exit 1
fi

# Test 3: Check if functions exist
echo "3. Testing function existence..."
if grep -q "__handle_error" bin/errorHandlingFunctions.sh && grep -q "__validate_input" bin/validationFunctions.sh; then
    echo "✓ Required functions exist"
else
    echo "✗ Required functions missing"
    exit 1
fi

# Test 4: Check if error codes are defined
echo "4. Testing error codes..."
if grep -q "ERROR_" bin/errorHandlingFunctions.sh; then
    echo "✓ Error codes are defined"
else
    echo "✗ Error codes missing"
    exit 1
fi

# Test 5: Check if trap functions exist
echo "5. Testing trap functions..."
if grep -q "trap" bin/errorHandlingFunctions.sh; then
    echo "✓ Trap functions exist"
else
    echo "✗ Trap functions missing"
    exit 1
fi

echo "=== QUICK ERROR HANDLING TESTS COMPLETED ==="
echo "All quick error handling tests passed! 🎉"
exit 0 