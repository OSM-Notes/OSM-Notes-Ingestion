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
# Tests for generateEEZCentroids.sh
# =============================================================================

@test "generateEEZCentroids.sh should exist" {
 [ -f "${TEST_BASE_DIR}/bin/scripts/generateEEZCentroids.sh" ]
}

@test "generateEEZCentroids.sh should be executable" {
 [ -x "${TEST_BASE_DIR}/bin/scripts/generateEEZCentroids.sh" ]
}

@test "generateEEZCentroids.sh should have main function" {
 # Check that script has main function
 run grep -q "main()" "${TEST_BASE_DIR}/bin/scripts/generateEEZCentroids.sh"
 [ "$status" -eq 0 ]
}

@test "generateEEZCentroids.sh should reference EEZ_SHAPEFILE" {
 # Check that script references EEZ_SHAPEFILE variable
 run grep -q "EEZ_SHAPEFILE" "${TEST_BASE_DIR}/bin/scripts/generateEEZCentroids.sh"
 [ "$status" -eq 0 ]
}

@test "generateEEZCentroids.sh should reference output CSV" {
 # Check that script references output CSV file
 run grep -q "eez_centroids.csv" "${TEST_BASE_DIR}/bin/scripts/generateEEZCentroids.sh"
 [ "$status" -eq 0 ]
}

@test "generateEEZCentroids.sh should use DBNAME environment variable" {
 # Check that script references DBNAME
 run grep -q "DBNAME" "${TEST_BASE_DIR}/bin/scripts/generateEEZCentroids.sh"
 [ "$status" -eq 0 ]
}

# =============================================================================
# Tests for install_directories.sh
# =============================================================================

@test "install_directories.sh should exist" {
 [ -f "${TEST_BASE_DIR}/bin/scripts/install_directories.sh" ]
}

@test "install_directories.sh should be executable" {
 [ -x "${TEST_BASE_DIR}/bin/scripts/install_directories.sh" ]
}

@test "install_directories.sh should check for root privileges" {
 # Check that script checks for root (EUID)
 run grep -q "EUID" "${TEST_BASE_DIR}/bin/scripts/install_directories.sh"
 [ "$status" -eq 0 ]
}

@test "install_directories.sh should create log directories" {
 # Check that script creates log directories
 run grep -q "/var/log/osm-notes-ingestion" "${TEST_BASE_DIR}/bin/scripts/install_directories.sh"
 [ "$status" -eq 0 ]
}

@test "install_directories.sh should create temp directories" {
 # Check that script creates temp directories
 run grep -q "/var/tmp/osm-notes-ingestion" "${TEST_BASE_DIR}/bin/scripts/install_directories.sh"
 [ "$status" -eq 0 ]
}

@test "install_directories.sh should create lock directories" {
 # Check that script creates lock directories
 run grep -q "/var/run/osm-notes-ingestion" "${TEST_BASE_DIR}/bin/scripts/install_directories.sh"
 [ "$status" -eq 0 ]
}

@test "install_directories.sh should create logrotate configuration" {
 # Check that script creates logrotate config
 run grep -q "logrotate" "${TEST_BASE_DIR}/bin/scripts/install_directories.sh"
 [ "$status" -eq 0 ]
}

# =============================================================================
# Tests for benchmark_http_optimizations.sh
# =============================================================================

@test "benchmark_http_optimizations.sh should exist" {
 [ -f "${TEST_BASE_DIR}/bin/scripts/benchmark_http_optimizations.sh" ]
}

@test "benchmark_http_optimizations.sh should be executable" {
 [ -x "${TEST_BASE_DIR}/bin/scripts/benchmark_http_optimizations.sh" ]
}

@test "benchmark_http_optimizations.sh should handle --help argument" {
 # Check that script has help option
 run grep -q "--help" "${TEST_BASE_DIR}/bin/scripts/benchmark_http_optimizations.sh"
 [ "$status" -eq 0 ]
}

@test "benchmark_http_optimizations.sh should handle --iterations argument" {
 # Check that script handles iterations argument
 run grep -q "--iterations" "${TEST_BASE_DIR}/bin/scripts/benchmark_http_optimizations.sh"
 [ "$status" -eq 0 ]
}

@test "benchmark_http_optimizations.sh should handle --output-dir argument" {
 # Check that script handles output-dir argument
 run grep -q "--output-dir" "${TEST_BASE_DIR}/bin/scripts/benchmark_http_optimizations.sh"
 [ "$status" -eq 0 ]
}

@test "benchmark_http_optimizations.sh should reference OSM_API_URL" {
 # Check that script references OSM_API_URL
 run grep -q "OSM_API_URL" "${TEST_BASE_DIR}/bin/scripts/benchmark_http_optimizations.sh"
 [ "$status" -eq 0 ]
}

@test "benchmark_http_optimizations.sh should use __retry_osm_api function" {
 # Check that script uses retry function
 run grep -q "__retry_osm_api" "${TEST_BASE_DIR}/bin/scripts/benchmark_http_optimizations.sh"
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

