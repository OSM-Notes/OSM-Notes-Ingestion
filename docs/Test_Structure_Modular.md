# Test Structure - Modular Organization

## Overview

The OSM-Notes-Ingestion test suite uses a **modular structure** to improve maintainability,
readability, and test execution efficiency. Tests are organized in smaller, focused modules grouped
by functionality.

## Structure Summary

### Statistics

- **Total Test Files**: 132 BATS test suites
- **Modular Files**: 64 focused modules
- **Average Module Size**: ~150-250 lines per module
- **Module Size Range**: Typically 100-400 lines

### Organization Criteria

Modules are organized by:

- **Functionality**: Related tests grouped together
- **Size**: Modules typically kept under 400 lines
- **Purpose**: Clear separation of concerns (common, validation, integration, etc.)

### Benefits

1. **Maintainability**: Smaller files are easier to understand and modify
2. **Organization**: Tests grouped by functionality (common, validation, integration, etc.)
3. **Performance**: Can run specific modules instead of entire large files
4. **Readability**: Clear naming convention makes it easy to find relevant tests
5. **Collaboration**: Multiple developers can work on different modules simultaneously

## Naming Convention

### Format

```
[component]_[category].test.bats
```

### Categories

- **`common`** - Common/shared functionality tests
- **`basic`** - Basic functionality tests
- **`validation`** - Data validation tests
- **`integration`** - Integration scenario tests
- **`error_handling`** - Error handling and edge cases
- **`performance`** - Performance and optimization tests
- **`advanced`** - Advanced scenario tests
- **`sanitize`** - Security sanitization tests
- **`injection`** - Security injection prevention tests
- **`network`** - Network-related tests
- **`database`** - Database-related tests
- **`filesystem`** - Filesystem-related tests
- **`logging`** - Logging functionality tests
- **`utils`** - Utility function tests
- **`impl`** - Implementation-specific tests

### Examples

- `note_processing_common.test.bats` - Common note processing functionality
- `security_functions_sanitize.test.bats` - SQL sanitization functions
- `prerequisites_database.test.bats` - Database prerequisites validation
- `edge_cases_files.test.bats` - File-related edge cases

## Test Modules by Component

### 1. Note Processing (6 modules)

**Modules**:

- `note_processing_common.test.bats` (5 tests) - Common functionality
- `note_processing_network.test.bats` (6 tests) - Network operations
- `note_processing_download_queue.test.bats` (11 tests) - Download queue
- `note_processing_retry.test.bats` (11 tests) - Retry logic
- `note_processing_validation.test.bats` (3 tests) - Data validation
- `note_processing_location.test.bats` (5 tests) - Location processing

### 2. Security Functions (4 modules)

**Modules**:

- `security_functions_sanitize.test.bats` (32 tests) - SQL sanitization
- `security_functions_injection.test.bats` (6 tests) - Injection prevention
- `security_functions_edge_cases.test.bats` (6 tests) - Edge cases
- `security_functions_integration.test.bats` (3 tests) - Integration

### 3. Prerequisites (9 modules)

**Modules**:

- `prerequisites_commands.test.bats` (10 tests) - Command checks
- `prerequisites_database.test.bats` (3 tests) - Database connectivity
- `prerequisites_filesystem.test.bats` (4 tests) - Filesystem checks
- `prerequisites_network.test.bats` (2 tests) - Network connectivity
- `prerequisites_performance.test.bats` (1 test) - Performance tests
- `prerequisites_mock.test.bats` (1 test) - Mock environment
- `prerequisites_error_handling.test.bats` (2 tests) - Error handling
- `prerequisites_integration.test.bats` (2 tests) - Integration

### 4. Boundary Processing (4 modules)

**Modules**:

- `boundary_processing_common.test.bats` (1 test) - Common functionality
- `boundary_processing_logging.test.bats` (14 tests) - Logging
- `boundary_processing_utils.test.bats` (10 tests) - Utility functions
- `boundary_processing_impl.test.bats` (3 tests) - Implementation

### 5. Overpass Functions (5 modules)

**Modules**:

- `overpass_functions_common.test.bats` (3 tests) - Common functions
- `overpass_functions_overpass.test.bats` (10 tests) - Overpass API
- `overpass_functions_json.test.bats` (4 tests) - JSON processing
- `overpass_functions_geojson.test.bats` (11 tests) - GeoJSON
- `overpass_functions_edge_integration.test.bats` (9 tests) - Edge cases

### 6. CSV Validation (5 modules)

**Modules**:

- `csv_comma_awk_basic.test.bats` (2 tests) - Basic comma handling
- `csv_comma_awk_multiline.test.bats` (1 test) - Multiline text
- `csv_comma_awk_quotes.test.bats` (4 tests) - Quote handling
- `csv_comma_awk_complex.test.bats` (2 tests) - Complex scenarios
- `csv_comma_validation.test.bats` (6 tests) - CSV validation

### 7. Extended Validation (4 modules)

**Modules**:

- `extended_validation_json.test.bats` (18 tests) - JSON validation
- `extended_validation_database.test.bats` (7 tests) - Database validation
- `extended_validation_coordinates.test.bats` (10 tests) - Coordinates
- `extended_validation_numeric_string.test.bats` (6 tests) - Numeric/string

### 8. XML Processing (3 modules)

**Modules**:

- `functionsProcess_xml_counting_api.test.bats` (9 tests) - API counting
- `functionsProcess_xml_counting_planet.test.bats` (3 tests) - Planet counting
- `functionsProcess_database_integration.test.bats` (1 test) - Integration

### 9. Monitoring (3 modules)

**Modules**:

- `monitoring_detection.test.bats` (6 tests) - Issue detection
- `monitoring_infrastructure.test.bats` (2 tests) - Infrastructure
- `monitoring_historical.test.bats` (4 tests) - Historical data

### 10. ProcessAPI Historical (3 modules)

**Modules**:

- `processAPI_historical_scenarios.test.bats` (3 tests) - Scenarios
- `processAPI_historical_sql.test.bats` (3 tests) - SQL validation
- `processAPI_historical_integration.test.bats` (4 tests) - Integration

### 11. Binary Division (3 modules)

**Modules**:

- `binary_division_basic.test.bats` (3 tests) - Basic functionality
- `binary_division_performance.test.bats` (8 tests) - Performance
- `binary_division_error_handling.test.bats` (3 tests) - Error handling

### 12. JSON Validation (4 modules)

**Modules**:

- `json_validation_basic.test.bats` (2 tests) - Basic validation
- `json_validation_errors.test.bats` (10 tests) - Error scenarios
- `json_validation_advanced.test.bats` (7 tests) - Advanced tests
- `json_validation_integration.test.bats` (1 test) - Integration

### 13. Edge Cases (4 modules)

**Modules**:

- `edge_cases_files.test.bats` (2 tests) - File handling
- `edge_cases_database.test.bats` (4 tests) - Database scenarios
- `edge_cases_infrastructure.test.bats` (5 tests) - Infrastructure
- `edge_cases_validation.test.bats` (3 tests) - Validation

### 14. Utility Scripts (3 modules)

**Modules**:

- `export_countries_backup.test.bats` (5 tests) - Country export
- `export_maritimes_backup.test.bats` (5 tests) - Maritime export
- `generate_note_location_backup.test.bats` (6 tests) - Location backup

### 15. AWK CSV Validation (3 modules)

**Modules**:

- `awk_csv_column_count.test.bats` (6 tests) - Column count
- `awk_csv_sql_order.test.bats` (4 tests) - SQL order
- `awk_csv_consistency.test.bats` (1 test) - Consistency

## Test Runners

Test runners include all modular files:

- `run_tests_simple.sh` - Simple test runner
- `run_tests_sequential.sh` - Sequential test execution
- `run_tests.sh` - Master test runner

## Running Modular Tests

### Run All Tests for a Component

```bash
# Run all note processing tests
bats tests/unit/bash/note_processing_*.test.bats

# Run all security function tests
bats tests/unit/bash/security_functions_*.test.bats

# Run all prerequisite tests
bats tests/unit/bash/prerequisites_*.test.bats
```

### Run Specific Module

```bash
# Run specific module
bats tests/unit/bash/note_processing_common.test.bats

# Run with specific test
bats tests/unit/bash/security_functions_sanitize.test.bats -f "test_sanitize_sql_string"
```

### Run by Category

```bash
# Run all validation tests
find tests/unit/bash -name "*_validation.test.bats" -exec bats {} \;

# Run all integration tests
find tests/unit/bash -name "*_integration.test.bats" -exec bats {} \;

# Run all error handling tests
find tests/unit/bash -name "*_error*.test.bats" -exec bats {} \;
```

## Maintenance Guidelines

### Adding New Tests

1. **Check existing modules** - Add to existing module if functionality matches
2. **Create new module** - If new functionality, create `[component]_[category].test.bats`
3. **Update test runners** - Add new file to appropriate test runner
4. **Update documentation** - Document new module in this file

### Module Organization Guidelines

1. **Size threshold**: Keep modules under 400 lines when possible
2. **Logical grouping**: Group tests by functionality, not just size
3. **Naming consistency**: Follow naming convention
4. **Update runners**: Include new modules in test runners
5. **Documentation**: Update this documentation when adding modules

### Best Practices

1. **Module size**: Aim for 150-300 lines per module
2. **Test count**: 3-15 tests per module (flexible based on complexity)
3. **Cohesion**: Keep related tests together
4. **Independence**: Each module should be independently runnable
5. **Documentation**: Include clear module descriptions

## Related Documentation

- [Testing Guide](./Testing_Guide.md) - General testing guidelines
- [Testing Suites Reference](./Testing_Suites_Reference.md) - Complete test suite reference
- [Test Execution Guide](./Test_Execution_Guide.md) - Test execution procedures
- [tests/README.md](../tests/README.md) - Test directory overview
- [tests/unit/bash/README.md](../tests/unit/bash/README.md) - Bash unit tests overview
