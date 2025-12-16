#!/usr/bin/env bats

# Common tests for utility scripts in bin/scripts/
# Tests basic functionality, existence, and structure
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

load "$(dirname "$BATS_TEST_FILENAME")/../../test_helper.bash"

# =============================================================================
# Tests for exportCountriesBackup.sh
# =============================================================================

@test "exportCountriesBackup.sh should exist" {
 [ -f "${TEST_BASE_DIR}/bin/scripts/exportCountriesBackup.sh" ]
}

@test "exportCountriesBackup.sh should be executable" {
 [ -x "${TEST_BASE_DIR}/bin/scripts/exportCountriesBackup.sh" ]
}

@test "exportCountriesBackup.sh should handle invalid arguments gracefully" {
 # Test that script handles invalid arguments without crashing
 run bash "${TEST_BASE_DIR}/bin/scripts/exportCountriesBackup.sh" --invalid-arg 2>&1 || true
 # Script should either exit with error or show help, but not crash
 [ "$status" -ne 0 ] || [ -n "$output" ]
}

@test "exportCountriesBackup.sh should use DBNAME environment variable" {
 # Check that script references DBNAME
 run grep -q "DBNAME" "${TEST_BASE_DIR}/bin/scripts/exportCountriesBackup.sh"
 [ "$status" -eq 0 ]
}

@test "exportCountriesBackup.sh should output to data/countries.geojson" {
 # Check that script references output file
 run grep -q "countries.geojson" "${TEST_BASE_DIR}/bin/scripts/exportCountriesBackup.sh"
 [ "$status" -eq 0 ]
}

# =============================================================================
# Tests for exportMaritimesBackup.sh
# =============================================================================

@test "exportMaritimesBackup.sh should exist" {
 [ -f "${TEST_BASE_DIR}/bin/scripts/exportMaritimesBackup.sh" ]
}

@test "exportMaritimesBackup.sh should be executable" {
 [ -x "${TEST_BASE_DIR}/bin/scripts/exportMaritimesBackup.sh" ]
}

@test "exportMaritimesBackup.sh should handle invalid arguments gracefully" {
 # Test that script handles invalid arguments without crashing
 run bash "${TEST_BASE_DIR}/bin/scripts/exportMaritimesBackup.sh" --invalid-arg 2>&1 || true
 # Script should either exit with error or show help, but not crash
 [ "$status" -ne 0 ] || [ -n "$output" ]
}

@test "exportMaritimesBackup.sh should use DBNAME environment variable" {
 # Check that script references DBNAME
 run grep -q "DBNAME" "${TEST_BASE_DIR}/bin/scripts/exportMaritimesBackup.sh"
 [ "$status" -eq 0 ]
}

@test "exportMaritimesBackup.sh should output to data/maritimes.geojson" {
 # Check that script references output file
 run grep -q "maritimes.geojson" "${TEST_BASE_DIR}/bin/scripts/exportMaritimesBackup.sh"
 [ "$status" -eq 0 ]
}

# =============================================================================
# Tests for generateNoteLocationBackup.sh
# =============================================================================

@test "generateNoteLocationBackup.sh should exist" {
 [ -f "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" ]
}

@test "generateNoteLocationBackup.sh should be executable" {
 [ -x "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" ]
}

@test "generateNoteLocationBackup.sh should handle invalid arguments gracefully" {
 # Test that script handles invalid arguments without crashing
 run bash "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh" --invalid-arg 2>&1 || true
 # Script should either exit with error or show help, but not crash
 [ "$status" -ne 0 ] || [ -n "$output" ]
}

@test "generateNoteLocationBackup.sh should use DBNAME environment variable" {
 # Check that script references DBNAME
 run grep -q "DBNAME" "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh"
 [ "$status" -eq 0 ]
}

@test "generateNoteLocationBackup.sh should output to data/noteLocation.csv.zip" {
 # Check that script references output file
 run grep -q "noteLocation.csv" "${TEST_BASE_DIR}/bin/scripts/generateNoteLocationBackup.sh"
 [ "$status" -eq 0 ]
}

# =============================================================================
# Tests for generateEEZCentroids.sh
# =============================================================================

@test "generateEEZCentroids.sh should exist" {
 [ -f "${TEST_BASE_DIR}/bin/scripts/generateEEZCentroids.sh" ]
}

@test "generateEEZCentroids.sh should be executable" {
 [ -x "${TEST_BASE_DIR}/bin/scripts/generateEEZCentroids.sh" ]
}

@test "generateEEZCentroids.sh should reference EEZ_SHAPEFILE" {
 # Check that script references shapefile variable
 run grep -q "EEZ_SHAPEFILE" "${TEST_BASE_DIR}/bin/scripts/generateEEZCentroids.sh"
 [ "$status" -eq 0 ]
}

@test "generateEEZCentroids.sh should output to data/eez_analysis/eez_centroids.csv" {
 # Check that script references output file
 run grep -q "eez_centroids.csv" "${TEST_BASE_DIR}/bin/scripts/generateEEZCentroids.sh"
 [ "$status" -eq 0 ]
}

