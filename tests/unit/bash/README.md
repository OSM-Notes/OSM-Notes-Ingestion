# Bash Unit Tests

This directory contains BATS (Bash Automated Testing System) unit tests for shell script components.

## Test File Organization

### Modular Structure

The test suite is organized in a **modular structure** with tests grouped by functionality for improved maintainability and organization.

**Total Test Files**: 132 BATS test suites

### Naming Convention

Test files follow a consistent naming pattern:

- **Format**: `[component]_[category].test.bats`
- **Categories**:
  - `common` - Common/shared functionality
  - `validation` - Data validation tests
  - `integration` - Integration scenarios
  - `error_handling` - Error handling and edge cases
  - `performance` - Performance and optimization
  - `basic` - Basic functionality
  - `advanced` - Advanced scenarios
  - `sanitize` - Security sanitization
  - `injection` - Security injection tests

### Test Modules by Component

#### Note Processing (6 modules)
- `note_processing_common.test.bats` - Common note processing functionality
- `note_processing_network.test.bats` - Network-related tests
- `note_processing_download_queue.test.bats` - Download queue management
- `note_processing_retry.test.bats` - Retry logic and error recovery
- `note_processing_validation.test.bats` - Data validation
- `note_processing_location.test.bats` - Location processing

#### Security Functions (4 modules)
- `security_functions_sanitize.test.bats` - SQL sanitization (32 tests)
- `security_functions_injection.test.bats` - SQL injection prevention (6 tests)
- `security_functions_edge_cases.test.bats` - Edge cases (6 tests)
- `security_functions_integration.test.bats` - Integration scenarios (3 tests)

#### Prerequisites (9 modules)
- `prerequisites_commands.test.bats` - Command availability checks
- `prerequisites_database.test.bats` - Database connectivity
- `prerequisites_filesystem.test.bats` - Filesystem permissions
- `prerequisites_network.test.bats` - Network connectivity
- `prerequisites_performance.test.bats` - Performance tests
- `prerequisites_mock.test.bats` - Mock environment tests
- `prerequisites_error_handling.test.bats` - Error handling
- `prerequisites_integration.test.bats` - Integration scenarios

#### Boundary Processing (5 modules)
- `boundary_processing_common.test.bats` - Common functionality
- `boundary_processing_logging.test.bats` - Logging tests (14 tests)
- `boundary_processing_utils.test.bats` - Utility functions (10 tests)
- `boundary_processing_impl.test.bats` - Implementation tests (3 tests)
- `boundary_processing_download_import.test.bats` - Download and import functions (24 tests)

#### Overpass Functions (5 modules)
- `overpass_functions_common.test.bats` - Common functions (3 tests)
- `overpass_functions_overpass.test.bats` - Overpass API tests (10 tests)
- `overpass_functions_json.test.bats` - JSON processing (4 tests)
- `overpass_functions_geojson.test.bats` - GeoJSON tests (11 tests)
- `overpass_functions_edge_integration.test.bats` - Edge cases (9 tests)

#### CSV Validation (5 modules)
- `csv_comma_awk_basic.test.bats` - Basic comma handling (2 tests)
- `csv_comma_awk_multiline.test.bats` - Multiline text (1 test)
- `csv_comma_awk_quotes.test.bats` - Quote handling (4 tests)
- `csv_comma_awk_complex.test.bats` - Complex scenarios (2 tests)
- `csv_comma_validation.test.bats` - CSV validation

#### Extended Validation (4 modules)
- `extended_validation_json.test.bats` - JSON validation (18 tests)
- `extended_validation_database.test.bats` - Database validation (7 tests)
- `extended_validation_coordinates.test.bats` - Coordinate validation (10 tests)
- `extended_validation_numeric_string.test.bats` - Numeric/string validation (6 tests)

#### XML Processing (3 modules)
- `functionsProcess_xml_counting_api.test.bats` - API XML counting (9 tests)
- `functionsProcess_xml_counting_planet.test.bats` - Planet XML counting (3 tests)
- `functionsProcess_database_integration.test.bats` - Database integration (1 test)

#### Monitoring (3 modules)
- `monitoring_detection.test.bats` - Issue detection (6 tests)
- `monitoring_infrastructure.test.bats` - Infrastructure tests (2 tests)
- `monitoring_historical.test.bats` - Historical data (4 tests)

#### ProcessAPI Historical (3 modules)
- `processAPI_historical_scenarios.test.bats` - Test scenarios (3 tests)
- `processAPI_historical_sql.test.bats` - SQL validation (3 tests)
- `processAPI_historical_integration.test.bats` - Integration tests (4 tests)

#### Binary Division (3 modules)
- `binary_division_basic.test.bats` - Basic functionality (3 tests)
- `binary_division_performance.test.bats` - Performance tests (8 tests)
- `binary_division_error_handling.test.bats` - Error handling (3 tests)

#### JSON Validation (4 modules)
- `json_validation_basic.test.bats` - Basic validation (2 tests)
- `json_validation_errors.test.bats` - Error scenarios (10 tests)
- `json_validation_advanced.test.bats` - Advanced tests (7 tests)
- `json_validation_integration.test.bats` - Integration (1 test)

#### Edge Cases (4 modules)
- `edge_cases_files.test.bats` - File handling (2 tests)
- `edge_cases_database.test.bats` - Database scenarios (4 tests)
- `edge_cases_infrastructure.test.bats` - Infrastructure tests (5 tests)
- `edge_cases_validation.test.bats` - Validation tests (3 tests)

#### Utility Scripts (3 modules)
- `export_countries_backup.test.bats` - Country backup export (5 tests)
- `export_maritimes_backup.test.bats` - Maritime backup export (5 tests)
- `generate_note_location_backup.test.bats` - Note location backup (6 tests)

#### AWK CSV Validation (3 modules)
- `awk_csv_column_count.test.bats` - Column count validation (6 tests)
- `awk_csv_sql_order.test.bats` - SQL order validation (4 tests)
- `awk_csv_consistency.test.bats` - Consistency checks (1 test)

### Core Testing Files

- **`resource_limits.test.bats`**: Tests for XML processing resource limitations and monitoring
- **`historical_data_validation.test.bats`**: Tests for historical data validation in processAPI
- **`xml_processing_enhanced.test.bats`**: Enhanced XML processing and validation tests
- **`processPlanetNotes.test.bats`**: Tests for Planet Notes processing functionality
- **`processAPINotes.test.bats`**: Tests for API Notes processing functionality

### Historical Data Validation Testing

The `historical_data_validation.test.bats` file specifically tests the critical data integrity features:

#### Functions Tested

1. **`__checkHistoricalData()`**
   - Validates sufficient historical data exists (minimum 30 days)
   - Checks both `notes` and `note_comments` tables
   - Handles database connection failures gracefully
   - Provides clear error messages

#### Test Categories

- **Function Existence**: Verifies all historical validation functions are available
- **Empty Table Handling**: Tests behavior when base tables exist but are empty
- **Insufficient History**: Tests when data exists but lacks sufficient historical depth
- **Successful Validation**: Tests normal operation with adequate historical data
- **Error Scenarios**: Tests database connectivity issues and edge cases
- **SQL Script Validation**: Tests the actual SQL validation logic
- **ProcessAPI Integration**: Tests integration with the main processAPI script

### ProcessAPI Integration Testing

The `processAPI_historical_integration.test.bats` provides comprehensive scenario testing:

#### Scenarios Tested

1. **Normal Operation**: Base tables exist with sufficient historical data
2. **Critical Failure**: Base tables exist but historical data is missing or insufficient
3. **Fresh Installation**: Base tables don't exist (triggers planet sync)
4. **Database Issues**: Connection failures and error handling
5. **Script Integration**: Real processAPI script validation

### Resource Limitation Testing

The `resource_limits.test.bats` file specifically tests the new resource management features:

#### Functions Tested

1. **`__monitor_xmllint_resources()`**
   - Background resource monitoring
   - CPU and memory usage tracking
   - Process lifecycle management

2. **`__run_xmllint_with_limits()`**
   - CPU limitation (25% of one core)
   - Memory limitation (2GB)
   - Timeout management (300 seconds)
   - Resource logging

3. **`__validate_xml_structure_only()`**
   - XML structure validation with resource limits
   - Large file handling
   - Error reporting

#### Test Categories

- **Function Existence**: Verifies functions are properly loaded
- **Valid XML Processing**: Tests normal operation with resource limits
- **Invalid XML Handling**: Tests error conditions and malformed XML
- **Resource Monitoring**: Tests background monitoring functionality
- **CPU Limit Detection**: Tests behavior when `cpulimit` is unavailable
- **Memory Management**: Tests memory restriction enforcement

## Running the Tests

### All Resource Limit Tests

```bash
cd tests/unit/bash
bats resource_limits.test.bats
```

### Specific Test

```bash
cd tests/unit/bash
bats resource_limits.test.bats -f "test_run_xmllint_with_limits_with_valid_xml"
```

### All XML Processing Tests

```bash
cd tests/unit/bash
bats xml_processing_enhanced.test.bats
```

### Historical Data Validation Tests

```bash
cd tests/unit/bash
bats historical_data_validation.test.bats
```

### ProcessAPI Integration Tests

```bash
cd tests/unit/bash
bats processAPI_historical_integration.test.bats
```

### All Historical Validation Tests

```bash
cd tests/unit/bash
bats historical_data_validation.test.bats processAPI_historical_integration.test.bats
```

### All Bash Unit Tests

```bash
cd tests/unit/bash
bats *.test.bats
```

## Expected Output

### Successful Resource Limits Test Run

```text
✓ test_monitor_xmllint_resources_function_exists
✓ test_monitor_xmllint_resources_with_short_process  
✓ test_run_xmllint_with_limits_function_exists
✓ test_run_xmllint_with_limits_with_valid_xml
✓ test_run_xmllint_with_limits_with_invalid_xml
✓ test_cpulimit_availability_warning
✓ test_validate_xml_structure_only_function_exists

7 tests, 0 failures
```

## Dependencies

- **BATS**: Bash Automated Testing System
- **xmllint**: XML validation tool (part of libxml2-utils)
- **cpulimit**: CPU usage limiting tool (optional)
- **Standard Unix tools**: ps, grep, sed, sort, tail

## Resource Monitoring Output

When tests run, they generate resource monitoring logs showing:

```text
2025-08-07 19:12:07 - Starting resource monitoring for PID 12345
2025-08-07 19:12:07 - PID: 12345, CPU: 15.2%, Memory: 1.5%, RSS: 245760KB
2025-08-07 19:12:12 - PID: 12345, CPU: 22.1%, Memory: 2.1%, RSS: 335872KB
2025-08-07 19:12:17 - Process 12345 finished or terminated
```

## Troubleshooting

### Common Issues

1. **Function not found errors**
   - Ensure the test helper properly loads the functions
   - Check that `TEST_BASE_DIR` is correctly set

2. **xmllint not available**
   - Install libxml2-utils: `sudo apt-get install libxml2-utils`

3. **cpulimit warnings**
   - Install cpulimit: `sudo apt-get install cpulimit`
   - Or accept that CPU limits won't be enforced (tests still pass)

4. **Permission errors**
   - Ensure `/tmp` is writable
   - Check that test files can be created and deleted

### Debug Mode

Run tests with verbose output:

```bash
bats resource_limits.test.bats --verbose-run
```

## Test Environment

Tests are designed to work in both:

- **Host environment**: Direct execution on the host system
- **Docker environment**: Containerized testing
- **CI/CD environment**: Automated testing pipelines

The tests automatically detect the environment and adapt accordingly.
