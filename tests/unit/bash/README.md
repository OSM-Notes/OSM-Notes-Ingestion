# Bash Unit Tests

This directory contains BATS (Bash Automated Testing System) unit tests for shell script components.

## Test Files Overview

### Core Testing Files

- **`resource_limits.test.bats`**: Tests for XML processing resource limitations and monitoring
- **`historical_data_validation.test.bats`**: Tests for historical data validation in processAPI
- **`processAPI_historical_integration.test.bats`**: Integration tests for processAPI historical validation
- **`xslt_enum_format.test.bats`**: Tests for XSLT enum format validation and PostgreSQL compatibility
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

### XSLT Enum Format Testing

The `xslt_enum_format.test.bats` file tests the critical PostgreSQL enum compatibility fix:

#### Bug Fixed

**Original Error:**

```text
ERROR: la sintaxis de entrada no es válida para el enum note_event_enum: «"opened"»
```

**Root Cause:** XSLT was generating CSV with quoted enum values (`"opened"`) instead of unquoted (`opened`).

#### Tests Categories

1. **Enum Quote Validation**: Ensures no quotes around enum values (`opened`, `commented`, `closed`, `reopened`)
2. **XML Structure Compliance**: Tests correct XML element access (`action` vs `@action`)
3. **CSV Format Validation**: Verifies PostgreSQL COPY command compatibility
4. **Regression Testing**: Reproduces and validates fix for the original error
5. **Comprehensive Format Testing**: All enum values and CSV structure validation

#### Test Functions

- `api_xslt_generates_enum_values_without_quotes`: Basic enum format validation
- `api_xslt_handles_different_enum_values_correctly`: All enum values testing  
- `planet_xslt_generates_enum_values_without_quotes`: Planet XSLT validation
- `planet_xslt_handles_different_enum_values_correctly`: Planet enum values
- `api_csv_format_is_compatible_with_postgresql_enum`: Database compatibility
- `planet_csv_format_is_compatible_with_postgresql_enum`: Planet compatibility
- `verify_fix_for_reported_enum_error`: Regression test for original bug
- `csv_format_is_ready_for_postgresql_copy_command`: Complete format validation

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

### XSLT Enum Format Tests

```bash
cd tests/unit/bash
bats xslt_enum_format.test.bats
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
