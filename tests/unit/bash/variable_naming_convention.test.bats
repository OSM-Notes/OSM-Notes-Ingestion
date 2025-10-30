#!/usr/bin/env bats

# Test file for variable naming convention validation
# Validates that all variables and constants in bash scripts are declared in uppercase
# Author: Andres Gomez (AngocA)
# Version: 2025-07-30

load ../../test_helper

setup() {
  cd "${TEST_BASE_DIR}"
}

# Test that local variables are declared in uppercase
@test "local variables should be declared in uppercase" {
  # Find all bash scripts in bin directory
  local BASH_SCRIPTS
  mapfile -t BASH_SCRIPTS < <(find bin/ -name "*.sh" -type f)
  
  for SCRIPT in "${BASH_SCRIPTS[@]}"; do
    # Check for local variables declared in lowercase
    run awk '/^[[:space:]]*local[[:space:]]+[a-z_]+=/{print FILENAME ":" NR ": " $0}' "${SCRIPT}"
    if [[ -n "${output}" ]]; then
      echo "ERROR: Found local variables in lowercase in ${SCRIPT}:"
      echo "${output}"
      return 1
    fi
  done
}

# Test that declare statements use uppercase
@test "declare statements should use uppercase" {
  # Find all bash scripts in bin directory
  local BASH_SCRIPTS
  mapfile -t BASH_SCRIPTS < <(find bin/ -name "*.sh" -type f)
  
  for SCRIPT in "${BASH_SCRIPTS[@]}"; do
    # Check for declare statements with lowercase variable names
    run awk '/^[[:space:]]*declare[[:space:]]+[^=]*[a-z_]+=/{print FILENAME ":" NR ": " $0}' "${SCRIPT}"
    if [[ -n "${output}" ]]; then
      echo "ERROR: Found declare statements with lowercase variables in ${SCRIPT}:"
      echo "${output}"
      return 1
    fi
  done
}

# Test that for loop variables are in uppercase
@test "for loop variables should be in uppercase" {
  # Find all bash scripts in bin directory
  local BASH_SCRIPTS
  mapfile -t BASH_SCRIPTS < <(find bin/ -name "*.sh" -type f)
  
  for SCRIPT in "${BASH_SCRIPTS[@]}"; do
    # Check for for loops with lowercase variables
    run awk '/^[[:space:]]*for[[:space:]]+[a-z_]+[[:space:]]+in/{print FILENAME ":" NR ": " $0}' "${SCRIPT}"
    if [[ -n "${output}" ]]; then
      echo "ERROR: Found for loops with lowercase variables in ${SCRIPT}:"
      echo "${output}"
      return 1
    fi
  done
}

# Test that array references use uppercase
@test "array references should use uppercase" {
  # Find all bash scripts in bin directory
  local BASH_SCRIPTS
  mapfile -t BASH_SCRIPTS < <(find bin/ -name "*.sh" -type f)
  
  for SCRIPT in "${BASH_SCRIPTS[@]}"; do
    # Check for array references with lowercase names
    run awk '/\$\{[a-z_]+\[@\]\}/{print FILENAME ":" NR ": " $0}' "${SCRIPT}"
    if [[ -n "${output}" ]]; then
      echo "ERROR: Found array references with lowercase names in ${SCRIPT}:"
      echo "${output}"
      return 1
    fi
  done
}

# Test that variable assignments use uppercase
@test "variable assignments should use uppercase" {
  # Find all bash scripts in bin directory
  local BASH_SCRIPTS
  mapfile -t BASH_SCRIPTS < <(find bin/ -name "*.sh" -type f)
  
  local TOTAL_ERRORS=0
  
  for SCRIPT in "${BASH_SCRIPTS[@]}"; do
    # Check for variable assignments with lowercase names (excluding special cases)
    local SCRIPT_ERRORS
    SCRIPT_ERRORS=$(awk '/^[[:space:]]*[a-z_]+=/{print FILENAME ":" NR ": " $0}' "${SCRIPT}" 2>/dev/null | grep -v "declare" | grep -v "local" | grep -v "case" | grep -v "esac" || true)
    
    if [[ -n "${SCRIPT_ERRORS}" ]]; then
      echo "ERROR: Found variable assignments with lowercase names in ${SCRIPT}:"
      echo "${SCRIPT_ERRORS}"
      TOTAL_ERRORS=$((TOTAL_ERRORS + $(echo "${SCRIPT_ERRORS}" | wc -l)))
    fi
  done
  
  [ "${TOTAL_ERRORS}" -eq 0 ]
}

# Test specific files that should follow the convention
@test "functionsProcess.sh should follow uppercase convention" {
  run awk '/^[[:space:]]*local[[:space:]]+[a-z_]+=/{print NR ": " $0}' bin/lib/functionsProcess.sh
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "processAPINotes.sh should follow uppercase convention" {
  run awk '/^[[:space:]]*local[[:space:]]+[a-z_]+=/{print NR ": " $0}' bin/process/processAPINotes.sh
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "processPlanetNotes.sh should follow uppercase convention" {
  run awk '/^[[:space:]]*local[[:space:]]+[a-z_]+=/{print NR ": " $0}' bin/process/processPlanetNotes.sh
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "wmsManager.sh should follow uppercase convention" {
  run awk '/^[[:space:]]*local[[:space:]]+[a-z_]+=/{print NR ": " $0}' bin/wms/wmsManager.sh
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# Test that no lowercase variable declarations exist
@test "no lowercase variable declarations should exist" {
  # Find all bash scripts in bin directory
  local BASH_SCRIPTS
  mapfile -t BASH_SCRIPTS < <(find bin/ -name "*.sh" -type f)
  
  local TOTAL_ERRORS=0
  
  for SCRIPT in "${BASH_SCRIPTS[@]}"; do
    # Check for any lowercase variable declarations
    local ERRORS=0
    if [[ -f "${SCRIPT}" ]]; then
      ERRORS=$(awk '/^[[:space:]]*[a-z_]+=/{print FILENAME ":" NR ": " $0}' "${SCRIPT}" 2>/dev/null | grep -v "declare" | grep -v "local" | grep -v "case" | grep -v "esac" | wc -l || echo "0")
    fi
    
    if [[ "${ERRORS}" -gt 0 ]]; then
      echo "ERROR: Found ${ERRORS} lowercase variable declarations in ${SCRIPT}"
      awk '/^[[:space:]]*[a-z_]+=/{print FILENAME ":" NR ": " $0}' "${SCRIPT}" 2>/dev/null | grep -v "declare" | grep -v "local" | grep -v "case" | grep -v "esac"
      TOTAL_ERRORS=$((TOTAL_ERRORS + ERRORS))
    fi
  done
  
  [ "${TOTAL_ERRORS}" -eq 0 ]
}

# Test that function parameters are handled correctly
@test "function parameters should be converted to uppercase in function body" {
  # Find all bash scripts in bin directory
  local BASH_SCRIPTS
  mapfile -t BASH_SCRIPTS < <(find bin/ -name "*.sh" -type f)
  
  for SCRIPT in "${BASH_SCRIPTS[@]}"; do
    # Check for function parameter assignments that should be uppercase
    run awk '
      /^function[[:space:]]+__[a-zA-Z_]+[[:space:]]*\(\)[[:space:]]*\{/ {
        in_function = 1
        next
      }
      in_function && /^[[:space:]]*local[[:space:]]+[a-z_]+=.*\$[0-9]/ {
        print FILENAME ":" NR ": " $0
      }
      in_function && /^[[:space:]]*\}/ {
        in_function = 0
      }
    ' "${SCRIPT}"
    
    if [[ -n "${output}" ]]; then
      echo "ERROR: Found function parameter assignments that should be uppercase in ${SCRIPT}:"
      echo "${output}"
      return 1
    fi
  done
} 