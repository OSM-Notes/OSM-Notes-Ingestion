#!/usr/bin/env bats

# Unit tests for functionsProcess.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

@test "functions should be loaded" {
  # Check if key functions are available
  run declare -f __checkPrereqsCommands
  [ "$status" -eq 0 ]
  
  run declare -f __countXmlNotesAPI
  [ "$status" -eq 0 ]
  
  run declare -f __countXmlNotesPlanet
  [ "$status" -eq 0 ]
}

@test "environment variables should be set" {
  # Check if required environment variables are set
  [ -n "$TEST_BASE_DIR" ]
  [ -n "$TEST_DBNAME" ]
  [ -n "$LOG_LEVEL" ]
  [ -n "$MAX_THREADS" ]
}

@test "__checkPrereqsCommands should be available" {
  # Just check that the function exists and can be called
  run declare -f __checkPrereqsCommands
  [ "$status" -eq 0 ]
  [[ "$output" == *"__checkPrereqsCommands"* ]]
}

@test "__countXmlNotesAPI should be available" {
  # Just check that the function exists
  run declare -f __countXmlNotesAPI
  [ "$status" -eq 0 ]
  [[ "$output" == *"__countXmlNotesAPI"* ]]
}

@test "__countXmlNotesPlanet should be available" {
  # Just check that the function exists
  run declare -f __countXmlNotesPlanet
  [ "$status" -eq 0 ]
  [[ "$output" == *"__countXmlNotesPlanet"* ]]
}

@test "__splitXmlForParallelAPI should be available" {
  # Just check that the function exists
  run declare -f __splitXmlForParallelAPI
  [ "$status" -eq 0 ]
  [[ "$output" == *"__splitXmlForParallelAPI"* ]]
}

@test "__splitXmlForParallelPlanet should be available" {
  # Just check that the function exists
  run declare -f __splitXmlForParallelPlanet
  [ "$status" -eq 0 ]
  [[ "$output" == *"__splitXmlForParallelPlanet"* ]]
}

@test "__createFunctionToGetCountry should be available" {
  # Just check that the function exists
  run declare -f __createFunctionToGetCountry
  [ "$status" -eq 0 ]
  [[ "$output" == *"__createFunctionToGetCountry"* ]]
}

@test "__createProcedures should be available" {
  # Just check that the function exists
  run declare -f __createProcedures
  [ "$status" -eq 0 ]
  [[ "$output" == *"__createProcedures"* ]]
}

@test "__organizeAreas should be available" {
  # Just check that the function exists
  run declare -f __organizeAreas
  [ "$status" -eq 0 ]
  [[ "$output" == *"__organizeAreas"* ]]
}

@test "__getLocationNotes should be available" {
  # Just check that the function exists
  run declare -f __getLocationNotes
  [ "$status" -eq 0 ]
  [[ "$output" == *"__getLocationNotes"* ]]
}

@test "test database should be created" {
  # Test database creation
  run create_test_database
  [ "$status" -eq 0 ]
  
  # Clean up
  run drop_test_database
  [ "$status" -eq 0 ]
}

@test "helper functions should be available" {
  # Check if helper functions are available
  run declare -f create_test_database
  [ "$status" -eq 0 ]
  
  run declare -f drop_test_database
  [ "$status" -eq 0 ]
  
  run declare -f table_exists
  [ "$status" -eq 0 ]
  
  run declare -f count_rows
  [ "$status" -eq 0 ]
} 