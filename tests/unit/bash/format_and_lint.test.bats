#!/usr/bin/env bats

# Test: Todos los scripts bash deben pasar shellcheck y shfmt
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

load ../../test_helper

setup() {
  cd "${TEST_BASE_DIR}"
}

@test "Todos los scripts pasan shellcheck sin errores" {
  local SCRIPTS
  mapfile -t SCRIPTS < <(find bin/ -name "*.sh" -type f)
  for SCRIPT in "${SCRIPTS[@]}"; do
    # Use project-specific shellcheck configuration
    run shellcheck -x "${SCRIPT}"
    if [[ "$status" -ne 0 ]]; then
      echo "ERROR: $SCRIPT no pasa shellcheck"
      echo "$output"
      return 1
    fi
  done
}

@test "Todos los scripts están correctamente formateados con shfmt" {
  local SCRIPTS
  mapfile -t SCRIPTS < <(find bin/ -name "*.sh" -type f)
  for SCRIPT in "${SCRIPTS[@]}"; do
    # Use project-specific shfmt configuration
    run shfmt -d -i 1 -sr -bn "${SCRIPT}"
    if [[ -n "$output" ]]; then
      echo "ERROR: $SCRIPT no está correctamente formateado"
      echo "$output"
      return 1
    fi
  done
}