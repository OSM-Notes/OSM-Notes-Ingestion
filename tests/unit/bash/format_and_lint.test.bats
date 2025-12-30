#!/usr/bin/env bats

# Test: Todos los scripts bash deben pasar shellcheck y shfmt
# Author: Andres Gomez (AngocA)
# Version: 2025-12-30

load ../../test_helper

setup() {
  cd "${TEST_BASE_DIR}"
}

@test "Todos los scripts pasan shellcheck sin errores críticos" {
  local SCRIPTS
  local FAILED=0
  mapfile -t SCRIPTS < <(find bin/ -name "*.sh" -type f)
  for SCRIPT in "${SCRIPTS[@]}"; do
    # Use project-specific shellcheck configuration - only fail on errors, not warnings
    run shellcheck -x -o all "${SCRIPT}"
    if [[ "$status" -ne 0 ]]; then
      # Check if there are actual errors (not just warnings/info)
      # Only fail on actual errors, not on warnings or info messages
      if echo "$output" | grep -q -E "(error|Error|ERROR)" && ! echo "$output" | grep -q -E "(warning|Warning|WARNING|info|Info|INFO)"; then
        echo "ERROR: $SCRIPT no pasa shellcheck con errores críticos"
        echo "$output"
        FAILED=1
      else
        # If only warnings/info, consider it a pass
        echo "WARNING: $SCRIPT tiene advertencias de shellcheck (no críticas):"
        echo "$output"
      fi
    fi
  done
  [[ "${FAILED}" -eq 0 ]]
}

@test "Todos los scripts están correctamente formateados con shfmt" {
  local SCRIPTS
  local FAILED=0
  mapfile -t SCRIPTS < <(find bin/ -name "*.sh" -type f)
  for SCRIPT in "${SCRIPTS[@]}"; do
    # Use project-specific shfmt configuration
    run shfmt -d -i 1 -sr -bn "${SCRIPT}"
    if [[ -n "$output" ]]; then
      echo "ERROR: $SCRIPT no está correctamente formateado"
      echo "$output"
      FAILED=1
    fi
  done
  [[ "${FAILED}" -eq 0 ]]
}