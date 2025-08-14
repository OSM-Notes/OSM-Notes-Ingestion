#!/bin/bash

# Check specific functions in functionsProcess.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-08-14

set -e

SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FUNCTIONS_FILE="${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh"

echo "=== CHECKING SPECIFIC FUNCTIONS ==="
echo ""

# Function 1: __checkHistoricalData
echo "1. __checkHistoricalData:"
start_line=$(grep -n "^function __checkHistoricalData" "${FUNCTIONS_FILE}" | head -1 | cut -d: -f1)
echo "  Start line: ${start_line}"

# Check for __log_start
if sed -n "${start_line},$((start_line + 20))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*__log_start"; then
    echo "  ✅ Has __log_start"
else
    echo "  ❌ Missing __log_start"
fi

# Check for __log_finish
if sed -n "${start_line},$((start_line + 100))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*__log_finish"; then
    echo "  ✅ Has __log_finish"
else
    echo "  ❌ Missing __log_finish"
fi

# Check for return
if sed -n "${start_line},$((start_line + 100))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*return"; then
    echo "  ℹ️  Has return statements"
else
    echo "  ℹ️  No return statements"
fi

echo ""

# Function 2: __downloadPlanetNotes
echo "2. __downloadPlanetNotes:"
start_line=$(grep -n "^function __downloadPlanetNotes" "${FUNCTIONS_FILE}" | head -1 | cut -d: -f1)
echo "  Start line: ${start_line}"

# Check for __log_start
if sed -n "${start_line},$((start_line + 20))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*__log_start"; then
    echo "  ✅ Has __log_start"
else
    echo "  ❌ Missing __log_start"
fi

# Check for __log_finish
if sed -n "${start_line},$((start_line + 100))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*__log_finish"; then
    echo "  ✅ Has __log_finish"
else
    echo "  ❌ Missing __log_finish"
fi

# Check for return
if sed -n "${start_line},$((start_line + 100))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*return"; then
    echo "  ℹ️  Has return statements"
else
    echo "  ℹ️  No return statements"
fi

echo ""

# Function 3: __processCountries
echo "3. __processCountries:"
start_line=$(grep -n "^function __processCountries" "${FUNCTIONS_FILE}" | head -1 | cut -d: -f1)
echo "  Start line: ${start_line}"

# Check for __log_start
if sed -n "${start_line},$((start_line + 20))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*__log_start"; then
    echo "  ✅ Has __log_start"
else
    echo "  ❌ Missing __log_start"
fi

# Check for __log_finish
if sed -n "${start_line},$((start_line + 100))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*__log_finish"; then
    echo "  ✅ Has __log_finish"
else
    echo "  ❌ Missing __log_finish"
fi

# Check for return
if sed -n "${start_line},$((start_line + 100))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*return"; then
    echo "  ℹ️  Has return statements"
else
    echo "  ℹ️  No return statements"
fi

echo ""

# Function 4: __processMaritimes
echo "4. __processMaritimes:"
start_line=$(grep -n "^function __processMaritimes" "${FUNCTIONS_FILE}" | head -1 | cut -d: -f1)
echo "  Start line: ${start_line}"

# Check for __log_start
if sed -n "${start_line},$((start_line + 20))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*__log_start"; then
    echo "  ✅ Has __log_start"
else
    echo "  ❌ Missing __log_start"
fi

# Check for __log_finish
if sed -n "${start_line},$((start_line + 100))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*__log_finish"; then
    echo "  ✅ Has __log_finish"
else
    echo "  ❌ Missing __log_finish"
fi

# Check for return
if sed -n "${start_line},$((start_line + 100))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*return"; then
    echo "  ℹ️  Has return statements"
else
    echo "  ℹ️  No return statements"
fi

echo ""

# Function 5: __getLocationNotes
echo "5. __getLocationNotes:"
start_line=$(grep -n "^function __getLocationNotes" "${FUNCTIONS_FILE}" | head -1 | cut -d: -f1)
echo "  Start line: ${start_line}"

# Check for __log_start
if sed -n "${start_line},$((start_line + 20))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*__log_start"; then
    echo "  ✅ Has __log_start"
else
    echo "  ❌ Missing __log_start"
fi

# Check for __log_finish
if sed -n "${start_line},$((start_line + 100))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*__log_finish"; then
    echo "  ✅ Has __log_finish"
else
    echo "  ❌ Missing __log_finish"
fi

# Check for return
if sed -n "${start_line},$((start_line + 100))p" "${FUNCTIONS_FILE}" | grep -q "^[[:space:]]*return"; then
    echo "  ℹ️  Has return statements"
else
    echo "  ℹ️  No return statements"
fi

echo ""
echo "=== CHECK COMPLETE ==="
