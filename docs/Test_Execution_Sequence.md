# Sequential Test Execution Guide

**Version:** 2025-10-14  
**Author:** Andres Gomez (AngocA)

## Introduction

This guide allows you to execute tests **in parts**, organized by priority,
complexity, and functional category. Ideal for:

- Quick verification during development
- Debugging specific components
- Controlled execution with limited resources
- Early error identification

---

## Organization by Levels

### 📊 Level Summary

| Level | Suites | Approx. Tests | Time | Description |
|-------|--------|---------------|------|-------------|
| **Level 1 - Basic** | 15 | ~150 | 5-10 min | Fundamental and fast tests |
| **Level 2 - Validation** | 20 | ~250 | 10-15 min | Data and format validation |
| **Level 3 - Processing** | 18 | ~220 | 15-25 min | API and Planet processing logic |
| **Level 4 - Parallel** | 18 | ~220 | 10-15 min | Parallel processing optimization |
| **Level 5 - Cleanup** | 25 | ~350 | 12-18 min | Cleanup and error handling |
| **Level 6 - Monitoring** | 18 | ~220 | 8-12 min | Monitoring and WMS |
| **Level 7 - Advanced** | 18 | ~220 | 10-15 min | Advanced tests and edge cases |
| **Level 8 - Integration** | 8 | ~68 | 10-20 min | End-to-End Integration |
| **TOTAL** | **~140** | **~1,698** | **81-135 min** | |

---

## Level 1 - Basic Tests (5-10 minutes)

### Objective

Verify basic functionality, logging, and code structure.

### Included Suites

```bash
# 1.1 - Enhanced logging (18 tests, ~2 min)
bats tests/unit/bash/bash_logger_enhanced.test.bats

# 1.2 - Database variables (15 tests, ~1 min)
bats tests/unit/bash/database_variables.test.bats

# 1.3 - Format and lint (static tests, ~2 min)
bats tests/unit/bash/format_and_lint.test.bats

# 1.4 - Naming conventions - functions (static tests, ~1 min)
bats tests/unit/bash/function_naming_convention.test.bats

# 1.5 - Naming conventions - variables (static tests, ~1 min)
bats tests/unit/bash/variable_naming_convention.test.bats

# 1.6 - Script help validation (static tests, ~1 min)
bats tests/unit/bash/script_help_validation.test.bats

# 1.7 - Duplicate variable detection (static tests, ~1 min)
bats tests/unit/bash/variable_duplication.test.bats
bats tests/unit/bash/variable_duplication_detection.test.bats

# 1.8 - Function consolidation (static tests, ~1 min)
bats tests/unit/bash/function_consolidation.test.bats
```

### Consolidated Level 1 Command

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Execute all basic tests
bats tests/unit/bash/bash_logger_enhanced.test.bats \
     tests/unit/bash/database_variables.test.bats \
     tests/unit/bash/format_and_lint.test.bats \
     tests/unit/bash/function_naming_convention.test.bats \
     tests/unit/bash/variable_naming_convention.test.bats \
     tests/unit/bash/script_help_validation.test.bats \
     tests/unit/bash/variable_duplication.test.bats \
     tests/unit/bash/variable_duplication_detection.test.bats \
     tests/unit/bash/function_consolidation.test.bats
```

**Expected result:** ✅ ~50-60 tests passing in 5-10 minutes

---

## Level 2 - Validation Tests (10-15 minutes)

### Objective

Validate data input, coordinates, dates, and formats.

### Included Suites

```bash
# 2.1 - Centralized validation (10 tests, ~1 min)
bats tests/unit/bash/centralized_validation.test.bats

# 2.2 - Coordinate validation (11 tests, ~2 min)
bats tests/unit/bash/coordinate_validation_enhanced.test.bats

# 2.3 - Date validation (15 tests, ~2 min)
bats tests/unit/bash/date_validation.test.bats

# 2.4 - UTC date validation (tests, ~1 min)
bats tests/unit/bash/date_validation_utc.test.bats

# 2.5 - Date validation - integration (8 tests, ~1 min)
bats tests/unit/bash/date_validation_integration.test.bats

# 2.6 - Boundary validation (7 tests, ~1 min)
bats tests/unit/bash/boundary_validation.test.bats

# 2.7 - Checksum validation (9 tests, ~1 min)
bats tests/unit/bash/checksum_validation.test.bats

# 2.8 - Input validation (tests, ~1 min)
bats tests/unit/bash/input_validation.test.bats

# 2.9 - Extended validation (tests, ~2 min)
bats tests/unit/bash/extended_validation.test.bats

# 2.10 - Edge case validation (tests, ~1 min)
bats tests/unit/bash/edge_cases_validation.test.bats

# 2.11 - SQL validation (tests, ~2 min)
bats tests/unit/bash/sql_validation_integration.test.bats

# 2.12 - SQL constraints validation (tests, ~2 min)
bats tests/unit/bash/sql_constraints_validation.test.bats
```

### Consolidated Level 2 Command

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Execute all validation tests
bats tests/unit/bash/centralized_validation.test.bats \
     tests/unit/bash/coordinate_validation_enhanced.test.bats \
     tests/unit/bash/date_validation.test.bats \
     tests/unit/bash/date_validation_utc.test.bats \
     tests/unit/bash/date_validation_integration.test.bats \
     tests/unit/bash/boundary_validation.test.bats \
     tests/unit/bash/checksum_validation.test.bats \
     tests/unit/bash/input_validation.test.bats \
     tests/unit/bash/extended_validation.test.bats \
     tests/unit/bash/edge_cases_validation.test.bats \
     tests/unit/bash/sql_validation_integration.test.bats \
     tests/unit/bash/sql_constraints_validation.test.bats
```

**Expected result:** ✅ ~100-120 tests passing in 10-15 minutes

---

## Level 3 - XML Processing Tests (5-8 minutes)

### Objective

Validate XML processing and AWK extraction.

### Included Suites

```bash
# 3.1 - CSV enum validation (9 tests, ~1 min)
bats tests/unit/bash/csv_enum_validation.test.bats

# 3.2 - XML validation simple (tests, ~2 min)
bats tests/unit/bash/xml_validation_simple.test.bats

# 3.3 - XML validation enhanced (tests, ~2 min)
bats tests/unit/bash/xml_validation_enhanced.test.bats

# 3.4 - XML validation functions (tests, ~2 min)
bats tests/unit/bash/xml_validation_functions.test.bats

# 3.5 - XML validation large files (tests, ~3 min)
bats tests/unit/bash/xml_validation_large_files.test.bats

# 3.6 - XML processing enhanced (tests, ~2 min)
bats tests/unit/bash/xml_processing_enhanced.test.bats

# 3.7 - XML corruption recovery (tests, ~2 min)
bats tests/unit/bash/xml_corruption_recovery.test.bats

# 3.8 - Resource limits (tests, ~2 min)
bats tests/unit/bash/resource_limits.test.bats
```

### Consolidated Level 3 Command

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Execute all XML processing tests
bats tests/unit/bash/csv_enum_validation.test.bats \
     tests/unit/bash/xml_validation_simple.test.bats \
     tests/unit/bash/xml_validation_enhanced.test.bats \
     tests/unit/bash/xml_validation_functions.test.bats \
     tests/unit/bash/xml_validation_large_files.test.bats \
     tests/unit/bash/xml_processing_enhanced.test.bats \
     tests/unit/bash/xml_corruption_recovery.test.bats \
     tests/unit/bash/resource_limits.test.bats
```

**Expected result:** ✅ ~60-80 tests passing in 5-8 minutes

---

## Level 4 - Processing Tests (15-25 minutes)

### Objective

Validate API and Planet data processing.

### Included Suites

```bash
# 4.1 - ProcessAPI basic (tests, ~2 min)
bats tests/unit/bash/processAPINotes.test.bats

# 4.2 - ProcessAPI integration (tests, ~3 min)
bats tests/unit/bash/processAPINotes_integration.test.bats

# 4.3 - ProcessAPI error handling improved (tests, ~2 min)
bats tests/unit/bash/processAPINotes_error_handling_improved.test.bats

# 4.4 - ProcessAPI parallel error (tests, ~2 min)
bats tests/unit/bash/processAPINotes_parallel_error.test.bats

# 4.5 - ProcessAPI historical validation (tests, ~2 min)
bats tests/unit/bash/historical_data_validation.test.bats

# 4.6 - ProcessAPI historical integration (tests, ~2 min)
bats tests/unit/bash/processAPI_historical_integration.test.bats

# 4.7 - API download verification (6 tests, ~2 min)
bats tests/unit/bash/api_download_verification.test.bats

# 4.8 - ProcessPlanet basic (tests, ~2 min)
bats tests/unit/bash/processPlanetNotes.test.bats

# 4.9 - ProcessPlanet integration (tests, ~3 min)
bats tests/unit/bash/processPlanetNotes_integration.test.bats

# 4.10 - ProcessPlanet integration fixed (tests, ~3 min)
bats tests/unit/bash/processPlanetNotes_integration_fixed.test.bats

# 4.11 - Mock planet functions (tests, ~2 min)
bats tests/unit/bash/mock_planet_functions.test.bats
```

### Consolidated Level 4 Command

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Execute all processing tests
bats tests/unit/bash/processAPINotes.test.bats \
     tests/unit/bash/processAPINotes_integration.test.bats \
     tests/unit/bash/processAPINotes_error_handling_improved.test.bats \
     tests/unit/bash/processAPINotes_parallel_error.test.bats \
     tests/unit/bash/historical_data_validation.test.bats \
     tests/unit/bash/processAPI_historical_integration.test.bats \
     tests/unit/bash/api_download_verification.test.bats \
     tests/unit/bash/processPlanetNotes.test.bats \
     tests/unit/bash/processPlanetNotes_integration.test.bats \
     tests/unit/bash/processPlanetNotes_integration_fixed.test.bats \
     tests/unit/bash/mock_planet_functions.test.bats
```

**Expected result:** ✅ ~120-150 tests passing in 15-25 minutes

---

## Level 5 - Parallel Processing Tests (10-15 minutes)

### Objective

Validate optimization and parallel processing.

### Included Suites

```bash
# 5.1 - Complete parallel processing suite (21 tests, ~5 min)
bats tests/parallel_processing_test_suite.bats

# 5.2 - Robust parallel processing (tests, ~2 min)
bats tests/unit/bash/parallel_processing_robust.test.bats

# 5.3 - Parallel processing optimization (tests, ~2 min)
bats tests/unit/bash/parallel_processing_optimization.test.bats

# 5.4 - Parallel processing validation (tests, ~2 min)
bats tests/unit/bash/parallel_processing_validation.test.bats

# 5.5 - Parallel threshold (tests, ~1 min)
bats tests/unit/bash/parallel_threshold.test.bats

# 5.6 - Parallel delay test (tests, ~2 min)
bats tests/unit/bash/parallel_delay_test.test.bats

# 5.7 - Parallel delay test simple (tests, ~1 min)
bats tests/unit/bash/parallel_delay_test_simple.bats

# 5.8 - Parallel failed file (tests, ~1 min)
bats tests/unit/bash/parallel_failed_file.test.bats

# 5.9 - Binary division performance (14 tests, ~2 min)
bats tests/unit/bash/binary_division_performance.test.bats
```

### Consolidated Level 5 Command

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Execute all parallel processing tests
bats tests/parallel_processing_test_suite.bats \
     tests/unit/bash/parallel_processing_robust.test.bats \
     tests/unit/bash/parallel_processing_optimization.test.bats \
     tests/unit/bash/parallel_processing_validation.test.bats \
     tests/unit/bash/parallel_threshold.test.bats \
     tests/unit/bash/parallel_delay_test.bats \
     tests/unit/bash/parallel_delay_test_simple.bats \
     tests/unit/bash/parallel_failed_file.test.bats \
     tests/unit/bash/binary_division_performance.test.bats
```

**Expected result:** ✅ ~80-100 tests passing in 10-15 minutes

---

## Level 6 - Cleanup and Error Handling Tests (12-18 minutes)

### Objective

Validate resource cleanup and error handling.

### Included Suites

```bash
# 6.1 - CleanupAll integration (16 tests, ~3 min)
bats tests/unit/bash/cleanupAll_integration.test.bats

# 6.2 - CleanupAll basic (10 tests, ~2 min)
bats tests/unit/bash/cleanupAll.test.bats

# 6.3 - Clean flag handling (6 tests, ~1 min)
bats tests/unit/bash/clean_flag_handling.test.bats

# 6.4 - Clean flag simple (5 tests, ~1 min)
bats tests/unit/bash/clean_flag_simple.test.bats

# 6.5 - Clean flag exit trap (5 tests, ~1 min)
bats tests/unit/bash/clean_flag_exit_trap.test.bats

# 6.6 - Cleanup behavior (5 tests, ~1 min)
bats tests/unit/bash/cleanup_behavior.test.bats

# 6.7 - Cleanup behavior simple (3 tests, ~1 min)
bats tests/unit/bash/cleanup_behavior_simple.test.bats

# 6.8 - Cleanup order (7 tests, ~1 min)
bats tests/unit/bash/cleanup_order.test.bats

# 6.9 - Cleanup dependency fix (4 tests, ~1 min)
bats tests/unit/bash/cleanup_dependency_fix.test.bats

# 6.10 - Error handling (tests, ~2 min)
bats tests/unit/bash/error_handling.test.bats

# 6.11 - Error handling enhanced (tests, ~2 min)
bats tests/unit/bash/error_handling_enhanced.test.bats

# 6.12 - Error handling consolidated (tests, ~2 min)
bats tests/unit/bash/error_handling_consolidated.test.bats
```

### Consolidated Level 6 Command

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Execute all cleanup and error handling tests
bats tests/unit/bash/cleanupAll_integration.test.bats \
     tests/unit/bash/cleanupAll.test.bats \
     tests/unit/bash/clean_flag_handling.test.bats \
     tests/unit/bash/clean_flag_simple.test.bats \
     tests/unit/bash/clean_flag_exit_trap.test.bats \
     tests/unit/bash/cleanup_behavior.test.bats \
     tests/unit/bash/cleanup_behavior_simple.test.bats \
     tests/unit/bash/cleanup_order.test.bats \
     tests/unit/bash/cleanup_dependency_fix.test.bats \
     tests/unit/bash/error_handling.test.bats \
     tests/unit/bash/error_handling_enhanced.test.bats \
     tests/unit/bash/error_handling_consolidated.test.bats
```

**Expected result:** ✅ ~100-120 tests passing in 12-18 minutes

---

## Level 7 - Monitoring and WMS Tests (8-12 minutes)

### Objective

Validate monitoring, WMS, and other components.

### Included Suites

```bash
# 7.1 - Monitoring (tests, ~2 min)
bats tests/unit/bash/monitoring.test.bats

# 7.2 - Notes check verifier integration (tests, ~2 min)
bats tests/unit/bash/notesCheckVerifier_integration.test.bats

# 7.3 - Process check planet notes integration (tests, ~2 min)
bats tests/unit/bash/processCheckPlanetNotes_integration.test.bats

# 7.4 - WMS Manager (tests, ~2 min)
bats tests/unit/bash/wmsManager.test.bats

# 7.5 - WMS Manager integration (tests, ~2 min)
bats tests/unit/bash/wmsManager_integration.test.bats

# 7.6 - WMS config example integration (tests, ~1 min)
bats tests/unit/bash/wmsConfigExample_integration.test.bats

# 7.7 - GeoServer config integration (tests, ~1 min)
bats tests/unit/bash/geoserverConfig_integration.test.bats

# 7.8 - Update countries integration (tests, ~1 min)
bats tests/unit/bash/updateCountries_integration.test.bats
```

### Consolidated Level 7 Command

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Execute all monitoring and WMS tests
bats tests/unit/bash/monitoring.test.bats \
     tests/unit/bash/notesCheckVerifier_integration.test.bats \
     tests/unit/bash/processCheckPlanetNotes_integration.test.bats \
     tests/unit/bash/wmsManager.test.bats \
     tests/unit/bash/wmsManager_integration.test.bats \
     tests/unit/bash/wmsConfigExample_integration.test.bats \
     tests/unit/bash/geoserverConfig_integration.test.bats \
     tests/unit/bash/updateCountries_integration.test.bats
```

**Expected result:** ✅ ~50-70 tests passing in 8-12 minutes

---

## Level 8 - Advanced and Edge Case Tests (10-15 minutes)

### Objective

Validate edge cases, performance, and advanced functionality.

### Included Suites

```bash
# 8.1 - Performance edge cases (tests, ~3 min)
bats tests/unit/bash/performance_edge_cases.test.bats

# 8.2 - Performance edge cases simple (tests, ~2 min)
bats tests/unit/bash/performance_edge_cases_simple.test.bats

# 8.3 - Performance edge cases quick (tests, ~2 min)
bats tests/unit/bash/performance_edge_cases_quick.test.bats

# 8.4 - Edge cases integration (tests, ~2 min)
bats tests/unit/bash/edge_cases_integration.test.bats

# 8.5 - Real data integration (tests, ~2 min)
bats tests/unit/bash/real_data_integration.test.bats

# 8.6 - Hybrid integration (tests, ~2 min)
bats tests/unit/bash/hybrid_integration.test.bats

# 8.7 - Script execution integration (tests, ~2 min)
bats tests/unit/bash/script_execution_integration.test.bats

# 8.8 - Profile integration (tests, ~1 min)
bats tests/unit/bash/profile_integration.test.bats

# 8.9 - Functions process (tests, ~2 min)
bats tests/unit/bash/functionsProcess.test.bats

# 8.10 - Functions process enhanced (tests, ~2 min)
bats tests/unit/bash/functionsProcess_enhanced.test.bats

# 8.11 - Prerequisites enhanced (tests, ~2 min)
bats tests/unit/bash/prerequisites_enhanced.test.bats

# 8.12 - Logging improvements (tests, ~2 min)
bats tests/unit/bash/logging_improvements.test.bats

# 8.13 - Logging pattern validation (tests, ~2 min)
bats tests/unit/bash/logging_pattern_validation.test.bats
```

### Consolidated Level 8 Command

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Execute all advanced tests
bats tests/unit/bash/performance_edge_cases.test.bats \
     tests/unit/bash/performance_edge_cases_simple.test.bats \
     tests/unit/bash/performance_edge_cases_quick.test.bats \
     tests/unit/bash/edge_cases_integration.test.bats \
     tests/unit/bash/real_data_integration.test.bats \
     tests/unit/bash/hybrid_integration.test.bats \
     tests/unit/bash/script_execution_integration.test.bats \
     tests/unit/bash/profile_integration.test.bats \
     tests/unit/bash/functionsProcess.test.bats \
     tests/unit/bash/functionsProcess_enhanced.test.bats \
     tests/unit/bash/prerequisites_enhanced.test.bats \
     tests/unit/bash/logging_improvements.test.bats \
     tests/unit/bash/logging_pattern_validation.test.bats
```

**Expected result:** ✅ ~100-130 tests passing in 10-15 minutes

---

## Level 9 - End-to-End Integration Tests (10-20 minutes)

### Objective

Validate complete ingestion and processing flows.

### Included Suites

```bash
# 9.1 - Boundary processing error integration (16 tests, ~4 min)
bats tests/integration/boundary_processing_error_integration.test.bats

# 9.2 - WMS integration (10 tests, ~3 min)
bats tests/integration/wms_integration.test.bats

# 9.3 - Logging pattern validation integration (9 tests, ~2 min)
bats tests/integration/logging_pattern_validation_integration.test.bats

# 9.4 - Mock planet processing (8 tests, ~2 min)
bats tests/integration/mock_planet_processing.test.bats

# 9.5 - ProcessAPI parallel error integration (7 tests, ~2 min)
bats tests/integration/processAPINotes_parallel_error_integration.test.bats

# 9.6 - End to end (6 tests, ~3 min)
bats tests/integration/end_to_end.test.bats

# 9.7 - ProcessAPI historical e2e (5 tests, ~2 min)
bats tests/integration/processAPI_historical_e2e.test.bats
```

### Consolidated Level 9 Command

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Execute all integration tests
bats tests/integration/boundary_processing_error_integration.test.bats \
     tests/integration/wms_integration.test.bats \
     tests/integration/logging_pattern_validation_integration.test.bats \
     tests/integration/mock_planet_processing.test.bats \
     tests/integration/processAPINotes_parallel_error_integration.test.bats \
     tests/integration/end_to_end.test.bats \
     tests/integration/processAPI_historical_e2e.test.bats
```

**Expected result:** ✅ ~68 tests passing in 10-20 minutes

---

## Quick Sequence (Quick Check - 15-20 minutes)

For quick verification before commit:

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Quick suite - critical tests
bats tests/unit/bash/bash_logger_enhanced.test.bats \
     tests/unit/bash/format_and_lint.test.bats \
     tests/unit/bash/centralized_validation.test.bats \
     tests/unit/bash/coordinate_validation_enhanced.test.bats \
     tests/unit/bash/date_validation.test.bats \
     tests/unit/bash/csv_enum_validation.test.bats \
     tests/unit/bash/processAPINotes.test.bats \
     tests/unit/bash/processPlanetNotes.test.bats \
     tests/parallel_processing_test_suite.bats \
     tests/unit/bash/error_handling_consolidated.test.bats
```

**Expected result:** ✅ ~150-180 critical tests in 15-20 minutes

---

## Complete Sequence (Full Test Suite)

### Option 1: Execute level by level

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Level 1 - Basic
bats tests/unit/bash/bash_logger_enhanced.test.bats \
     tests/unit/bash/database_variables.test.bats \
     tests/unit/bash/format_and_lint.test.bats

# Level 2 - Validation
bats tests/unit/bash/centralized_validation.test.bats \
     tests/unit/bash/coordinate_validation_enhanced.test.bats \
     tests/unit/bash/date_validation.test.bats

# ... continue with each level ...
```

### Option 2: Automated script

```bash
cd /home/angoca/github/OSM-Notes-Ingestion

# Create and execute complete sequence script
cat > run_tests_sequential.sh << 'EOF'
#!/bin/bash

set -euo pipefail

echo "=== Level 1: Basic Tests ==="
bats tests/unit/bash/bash_logger_enhanced.test.bats \
     tests/unit/bash/database_variables.test.bats \
     tests/unit/bash/format_and_lint.test.bats

echo "=== Level 2: Validation Tests ==="
bats tests/unit/bash/centralized_validation.test.bats \
     tests/unit/bash/coordinate_validation_enhanced.test.bats

# ... add more levels as needed ...

echo "=== ✅ Complete sequence finished ==="
EOF

chmod +x run_tests_sequential.sh
./run_tests_sequential.sh
```

---

## Execution Scripts by Category

### By Functionality

```bash
# Complete ProcessAPI
bats tests/unit/bash/processAPINotes*.bats \
     tests/unit/bash/api_download_verification.test.bats \
     tests/unit/bash/historical_data_validation.test.bats

# Complete ProcessPlanet
bats tests/unit/bash/processPlanetNotes*.bats \
     tests/unit/bash/mock_planet_functions.test.bats

# Complete XML processing
bats tests/unit/bash/xml*.bats

# Complete Parallel Processing
bats tests/parallel_processing_test_suite.bats \
     tests/unit/bash/parallel*.bats

# Complete Cleanup
bats tests/unit/bash/cleanup*.bats tests/unit/bash/clean*.bats

# Complete WMS
bats tests/unit/bash/wms*.bats tests/integration/wms_integration.test.bats
```

---

## Progress Monitoring

### Script with progress indicators

```bash
#!/bin/bash

TOTAL_LEVELS=9
CURRENT_LEVEL=0

run_level() {
  local level=$1
  local description=$2
  CURRENT_LEVEL=$level
  
  echo ""
  echo "╔════════════════════════════════════════╗"
  echo "║  Level $level/$TOTAL_LEVELS: $description"
  echo "╚════════════════════════════════════════╝"
  echo ""
}

# Level 1
run_level 1 "Basic Tests"
bats tests/unit/bash/bash_logger_enhanced.test.bats

# Level 2
run_level 2 "Validation Tests"
bats tests/unit/bash/centralized_validation.test.bats

# ... continue ...

echo ""
echo "╔════════════════════════════════════════╗"
echo "║  ✅ All levels completed!"
echo "╚════════════════════════════════════════╝"
```

---

## Usage Recommendations

### During Active Development

1. **Quick commit:** Level 1 + Level 2 (~15 min)
2. **Before push:** Levels 1-5 (~45 min)
3. **Before merge:** Levels 1-9 (~90 min)
4. **Release:** All levels (~120 min)

### For Debugging

1. Execute specific level for affected functionality
2. Execute specific suite for the component
3. Execute individual test: `bats file.bats -f "test name"`

### For CI/CD

1. GitHub Actions executes all automatically
2. For local CI testing: `./tests/run_all_tests.sh --mode docker`

---

## Troubleshooting

### Test fails in a level

```bash
# Re-execute only that level with verbose
bats -t tests/unit/bash/failing_file.test.bats

# View details of a specific test
bats tests/unit/bash/file.bats -f "exact test name"
```

### PostgreSQL not available

```bash
# Verify PostgreSQL is running
sudo systemctl status postgresql

# Start PostgreSQL
sudo systemctl start postgresql

# Verify connection
psql -U notes -d notes -c "SELECT 1;"
```

### Tests too slow

```bash
# Execute only quick check
bats tests/unit/bash/format_and_lint.test.bats

# Use mock mode for tests without DB
./tests/run_all_tests.sh --mode mock --type unit
```

---

## Key Commands Summary

```bash
# Quick verification (15-20 min)
./tests/run_tests_sequential.sh quick

# Specific level (example: Level 3 - XML Processing)
bats tests/unit/bash/xml*.bats

# Specific suite
bats tests/unit/bash/processAPINotes.test.bats

# Individual test
bats tests/unit/bash/processAPINotes.test.bats -f "specific_test_name"

# All unit tests
bats tests/unit/bash/*.bats

# All integration tests
bats tests/integration/*.bats

# Everything (not recommended locally, use CI)
./tests/run_all_tests.sh --mode host --type all
```

---

**Last updated:** 2025-10-14  
**Maintainer:** Andres Gomez (AngocA)
