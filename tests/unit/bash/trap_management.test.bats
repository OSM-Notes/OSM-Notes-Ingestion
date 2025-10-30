#!/usr/bin/env bats

# Author: Andres Gomez (AngocA)
# Version: 2025-10-30

# Static tests for trap management in processAPINotes.sh (no sourcing)

setup() {
 load "${BATS_TEST_DIRNAME}/../../test_helper.bash"
 export SCRIPT_BASE_DIRECTORY
 export TARGET_FILE="${SCRIPT_BASE_DIRECTORY}/bin/process/processAPINotes.sh"
}

@test "__trapOn function is defined in processAPINotes.sh" {
 run grep -q "function __trapOn" "${TARGET_FILE}"
 [ "$status" -eq 0 ]
}

@test "__trapOn sets ERR trap" {
 run grep -E -q "trap '[^']*' ERR" "${TARGET_FILE}"
 [ "$status" -eq 0 ]
}

@test "__trapOn sets SIGINT and SIGTERM traps" {
 run grep -q "SIGINT SIGTERM" "${TARGET_FILE}"
 [ "$status" -eq 0 ]
}
