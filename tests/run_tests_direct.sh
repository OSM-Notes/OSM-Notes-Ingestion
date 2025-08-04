#!/bin/bash

# Direct Test Runner - Bypasses terminal issues
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

# Disable all prompt functions that might cause issues
unset PROMPT_COMMAND 2>/dev/null || true
unset __vsc_prompt_cmd 2>/dev/null || true
unset __vsc_precmd 2>/dev/null || true
unset __vsc_postcmd 2>/dev/null || true
unset __vsc_current_command 2>/dev/null || true
unset __vsc_first_prompt 2>/dev/null || true
unset __vsc_in_command_execution 2>/dev/null || true

# Set a simple prompt
PS1='$ '

echo "=========================================="
echo "Direct Test Runner"
echo "=========================================="

# Check if we can run basic commands
echo "Testing basic command execution..."
if command -v bats >/dev/null 2>&1; then
    echo "✓ BATS is available"
else
    echo "✗ BATS is not available"
    exit 1
fi

if command -v psql >/dev/null 2>&1; then
    echo "✓ PostgreSQL client is available"
else
    echo "✗ PostgreSQL client is not available"
    exit 1
fi

# Run the first integration test
echo "Running end-to-end integration test..."
if bats tests/integration/end_to_end.test.bats; then
    echo "✓ end_to_end.test.bats passed"
else
    echo "✗ end_to_end.test.bats failed"
fi

echo "Test execution completed" 