#!/bin/bash

# Quick verification script to check if Germany modification is working
# in hybrid mode scripts
#
# Author: Andres Gomez (AngocA)
# Version: 2025-11-30

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

echo "=============================================================================="
echo "Verifying Germany modification integration in hybrid scripts"
echo "=============================================================================="
echo ""

# Check if function exists in run_processAPINotes_hybrid.sh
echo "1. Checking run_processAPINotes_hybrid.sh..."
if grep -q "modify_germany_for_hybrid_test" "${SCRIPT_DIR}/run_processAPINotes_hybrid.sh"; then
  echo "   ✅ Function found"
  if grep -q "modify_germany_for_hybrid_test()" "${SCRIPT_DIR}/run_processAPINotes_hybrid.sh"; then
    echo "   ✅ Function definition found"
  fi
  if grep -q "^[[:space:]]*modify_germany_for_hybrid_test$" "${SCRIPT_DIR}/run_processAPINotes_hybrid.sh"; then
    echo "   ✅ Function call found"
    echo "   📍 Called at line: $(grep -n "^[[:space:]]*modify_germany_for_hybrid_test$" "${SCRIPT_DIR}/run_processAPINotes_hybrid.sh" | cut -d: -f1)"
  fi
else
  echo "   ❌ Function NOT found"
fi
echo ""

# Check if function exists in run_updateCountries_hybrid.sh
echo "2. Checking run_updateCountries_hybrid.sh..."
if grep -q "modify_germany_for_hybrid_test" "${SCRIPT_DIR}/run_updateCountries_hybrid.sh"; then
  echo "   ✅ Function found"
  if grep -q "modify_germany_for_hybrid_test()" "${SCRIPT_DIR}/run_updateCountries_hybrid.sh"; then
    echo "   ✅ Function definition found"
  fi
  if grep -q "^[[:space:]]*modify_germany_for_hybrid_test$" "${SCRIPT_DIR}/run_updateCountries_hybrid.sh"; then
    echo "   ✅ Function call found"
    echo "   📍 Called at line: $(grep -n "^[[:space:]]*modify_germany_for_hybrid_test$" "${SCRIPT_DIR}/run_updateCountries_hybrid.sh" | cut -d: -f1)"
  fi
else
  echo "   ❌ Function NOT found"
fi
echo ""

# Check if SQL script exists
echo "3. Checking SQL script..."
SQL_SCRIPT="${SCRIPT_DIR}/../sql/analysis/modify_germany_for_hybrid_test.sql"
if [[ -f "${SQL_SCRIPT}" ]]; then
  echo "   ✅ Script exists: ${SQL_SCRIPT}"
  echo "   📏 Size: $(stat -c%s "${SQL_SCRIPT}" 2>/dev/null || echo "unknown") bytes"
else
  echo "   ❌ Script NOT found: ${SQL_SCRIPT}"
fi
echo ""

# Check what the function does
echo "4. Function behavior:"
echo "   - Checks if Germany (country_id = 51477) exists"
echo "   - Checks if there are notes assigned to Germany"
echo "   - Modifies geometry based on note distribution (~80% coverage)"
echo "   - Marks country as updated = TRUE"
echo ""

echo "=============================================================================="
echo "Verification complete!"
echo "=============================================================================="

