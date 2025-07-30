#!/usr/bin/env bats
# Temporal Gap Detection Tests
# Tests for the temporal gap detection function in functionsProcess.sh
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-29

setup() {
  # Load test helper functions
  load "${BATS_TEST_DIRNAME}/../../test_helper.bash"
  
  # Load the functions to test
  load "${BATS_TEST_DIRNAME}/../../../bin/functionsProcess.sh"
}

@test "temporal gap detection should work with acceptable gap" {
  local current_time=$(date +%s)
  local api_time=$((current_time - 600))  # 10 minutes ago
  
  run __detect_temporal_gap "${api_time}" "${current_time}" 30
  [ "$status" -eq 0 ]
  [[ "$output" == *"acceptable"* ]]
}

@test "temporal gap detection should fail with large gap" {
  local current_time=$(date +%s)
  local api_time=$((current_time - 3600))  # 60 minutes ago
  
  run __detect_temporal_gap "${api_time}" "${current_time}" 30
  [ "$status" -eq 1 ]
  [[ "$output" == *"Large temporal gap"* ]]
}

@test "temporal gap detection should work with string timestamps" {
  local api_time="2025-07-26 08:00:00"
  local planet_time="2025-07-26 08:15:00"
  
  run __detect_temporal_gap "${api_time}" "${planet_time}" 30
  [ "$status" -eq 0 ]
  [[ "$output" == *"acceptable"* ]]
}

@test "temporal gap detection should fail with large string gap" {
  local api_time="2025-07-26 08:00:00"
  local planet_time="2025-07-26 09:00:00"
  
  run __detect_temporal_gap "${api_time}" "${planet_time}" 30
  [ "$status" -eq 1 ]
  [[ "$output" == *"Large temporal gap"* ]]
}

@test "temporal gap detection should use default values" {
  run __detect_temporal_gap
  [ "$status" -eq 0 ]
  [[ "$output" == *"acceptable"* ]]
}