#!/bin/bash

# Simple verification script for functionsProcess.sh logging patterns
# Author: Andres Gomez (AngocA)
# Version: 2025-08-14

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

echo "=== VERIFYING FUNCTIONS IN functionsProcess.sh ==="
echo "File: ${FUNCTIONS_FILE}"
echo ""

# Get all function names
echo "Functions found:"
grep "^function [a-zA-Z_][a-zA-Z0-9_]*" "${FUNCTIONS_FILE}" | sed 's/^function \([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/' | sort

echo ""
echo "=== CHECKING LOGGING PATTERNS ==="

# Check each function
while IFS= read -r func_name; do
    echo ""
    echo "Function: ${func_name}"
    
    # Find function start line
    start_line=$(grep -n "^function ${func_name}" "${FUNCTIONS_FILE}" | head -1 | cut -d: -f1)
    
    if [[ -z "${start_line}" ]]; then
        echo "  ❌ Function not found"
        continue
    fi
    
    # Check for __log_start
    has_start=false
    if sed -n "${start_line},$((start_line + 20))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*__log_start"; then
        has_start=true
    fi
    
    # Check for __log_finish
    has_finish=false
    if sed -n "${start_line},$((start_line + 50))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*__log_finish"; then
        has_finish=true
    fi
    
    # Check for return statements
    has_return=false
    if sed -n "${start_line},$((start_line + 100))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*return"; then
        has_return=true
    fi
    
    # Display results
    if [[ "${has_start}" == "true" ]]; then
        echo "  ✅ Has __log_start"
    else
        echo "  ❌ Missing __log_start"
    fi
    
    if [[ "${has_finish}" == "true" ]]; then
        echo "  ✅ Has __log_finish"
    else
        echo "  ❌ Missing __log_finish"
    fi
    
    if [[ "${has_return}" == "true" ]]; then
        echo "  ℹ️  Has return statements"
    else
        echo "  ℹ️  No return statements"
    fi
    
done < <(grep "^function [a-zA-Z_][a-zA-Z0-9_]*" "${FUNCTIONS_FILE}" | sed 's/^function \([a-zA-Z_][a-zA-Z0-9_]*\).*/\1/' | sort)

echo ""
echo "=== VERIFICATION COMPLETE ==="
