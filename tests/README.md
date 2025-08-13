# Tests Directory

## Overview

The `tests` directory contains comprehensive testing infrastructure for the
OSM-Notes-profile system. It includes unit tests, integration tests,
performance tests, and quality assurance tools to ensure the reliability and
correctness of the entire system.

## Quick Start (No sudo required)

To run tests without sudo privileges:

1. **Install dependencies**:

   ```bash
   ./tests/install_dependencies.sh
   ```

2. **Setup test database**:

   ```bash
   ./tests/setup_test_db.sh
   ```

3. **Run tests**:

   ```bash
   ./tests/run_tests_simple.sh
   ```

## CI/CD Environment

For GitHub Actions and other CI environments:

1. **Verify CI environment**:

   ```bash
   ./tests/verify_ci_environment.sh
   ```

2. **Install missing tools** (if needed):

   ```bash
   ./tests/install_shfmt.sh
   ```

3. **Run CI-optimized tests**:

   ```bash
   ./tests/run_ci_tests_simple.sh
   ```

**Note**: The CI workflow automatically handles dependency installation and environment verification.

## Troubleshooting

### Common CI Issues

If you encounter issues in GitHub Actions or other CI environments:

1. **Missing tools**: Check the [CI Troubleshooting Guide](../docs/CI_Troubleshooting.md)
2. **Environment verification**: Run `./tests/verify_ci_environment.sh`
3. **Manual tool installation**: Use `./tests/install_shfmt.sh` for missing formatters

### Local Environment Issues

For local testing problems:

1. **Dependencies**: Ensure all required packages are installed
2. **Database**: Verify PostgreSQL is running and accessible
3. **Permissions**: Check file permissions and database access rights

## Docker Setup (Alternative)

If you prefer to use Docker and have sudo access:

1. **Setup Docker environment**:

   ```bash
   cd tests/docker
   docker compose up -d
   ```

2. **Run tests in Docker**:

   ```bash
   ./tests/docker/run_integration_tests.sh
   ```

## Directory Structure

### `/tests/unit/`

Unit tests for individual components:

- **`bash/`**: BATS (Bash Automated Testing System) tests for shell scripts
  - **`resource_limits.test.bats`**: Tests for XML processing resource limitations and monitoring
  - **`historical_data_validation.test.bats`**: Tests for historical data validation in processAPI
  - **`processAPI_historical_integration.test.bats`**: Integration tests for processAPI historical validation
  - **`xslt_enum_format.test.bats`**: Tests for XSLT enum format validation and PostgreSQL compatibility
  - **`xml_processing_enhanced.test.bats`**: Enhanced XML processing tests
  - **Other `.test.bats` files**: Component-specific unit tests
- **`sql/`**: Database function and table tests
  - **`dwh_dimensions_enhanced.test.sql`**: Unit tests for enhanced DWH dimensions
  - **`dwh_functions_enhanced.test.sql`**: Unit tests for enhanced DWH functions
  - **`tables_final_fixed.test.sql`**: Database table structure tests
  - **`functions_final_corrected.test.sql`**: Database function tests

### `/tests/integration/`

End-to-end integration tests:

- **`end_to_end.test.bats`**: Complete workflow testing from data ingestion to output
- **`processAPI_historical_e2e.test.bats`**: End-to-end tests for processAPI historical validation with real database scenarios
- **`ETL_enhanced_integration.test.bats`**: Integration tests for enhanced ETL functionality
- **`datamart_enhanced_integration.test.bats`**: Integration tests for enhanced datamart functionality

### `/tests/docker/`

Containerized testing environment:

- **`docker-compose.yml`**: Docker environment setup
- **`run_integration_tests.sh`**: Integration tests in Docker
- **`test_*.sh`**: Individual component tests

### `/tests/advanced/`

Advanced testing and quality tools:

- **`coverage/`**: Code coverage analysis
- **`security/`**: Security scanning tools
- **`performance/`**: Performance testing
- **`quality/`**: Code quality checks

### `/tests/scripts/`

Test automation scripts:

- **`test_special_cases.sh`**: Tests for edge cases and special scenarios
- **`run_advanced_tests.sh`**: Advanced test orchestration

### CI and Environment Scripts

CI-specific and environment management scripts:

- **`run_ci_tests_simple.sh`**: CI-optimized test runner with automatic dependency installation
- **`install_shfmt.sh`**: Automatic installation script for shfmt shell formatter
- **`verify_ci_environment.sh`**: Comprehensive environment verification for CI/CD
- **`install_dependencies.sh`**: General dependency installation script

### `/tests/fixtures/`

Test data and sample files:

- **`sample_data.sql`**: Database test data
- **`special_cases/`**: Edge case test scenarios

## Software Components

### Testing Framework

- **BATS**: Bash Automated Testing System for shell script testing
- **Docker**: Containerized testing environment
- **Coverage Tools**: Code coverage analysis
- **Quality Tools**: Linting and formatting checks

### Test Categories

- **Unit Tests**: Individual function and component testing
- **Integration Tests**: End-to-end workflow testing
- **Performance Tests**: System performance validation
- **Security Tests**: Vulnerability scanning
- **Quality Tests**: Code quality and style validation
- **Resource Limit Tests**: XML processing resource monitoring and limits validation
- **Historical Data Validation Tests**: ProcessAPI prerequisite validation for historical data integrity
- **XSLT Enum Format Tests**: PostgreSQL enum compatibility validation for CSV output
- **DWH Enhanced Tests**: Data warehouse enhanced functionality testing

### Test Data

- **Sample Data**: Representative datasets for testing
- **Edge Cases**: Special scenarios and error conditions
- **Mock Data**: Simulated data for isolated testing

## Usage

Tests can be run individually or as part of the complete test suite:

- `./tests/run_tests_simple.sh`: Basic test suite (no sudo required)
- `./tests/run_enhanced_tests.sh`: Enhanced test suite
- `./tests/run_tests.sh`: Complete test suite
- `./tests/run_dwh_tests.sh`: DWH enhanced tests only
- `./tests/advanced/run_advanced_tests.sh`: Advanced quality tests

### Running Specific Test Categories

- **Resource Limit Tests**: `cd tests/unit/bash && bats resource_limits.test.bats`
- **Historical Data Validation Tests**: `cd tests/unit/bash && bats historical_data_validation.test.bats`
- **ProcessAPI Integration Tests**: `cd tests/unit/bash && bats processAPI_historical_integration.test.bats`
- **XSLT Enum Format Tests**: `cd tests/unit/bash && bats xslt_enum_format.test.bats`
- **XML Processing Tests**: `cd tests/unit/bash && bats xml_processing_enhanced.test.bats`
- **DWH Enhanced Tests**: `./tests/run_dwh_tests.sh`
- **Individual Test**: `cd tests/unit/bash && bats resource_limits.test.bats -f "test_name"`

## DWH Enhanced Testing Features

### Overview

The DWH (Data Warehouse) enhanced testing suite validates all the improvements made to the star schema, including new dimensions, enhanced functions, and improved ETL processes.

### New Dimensions Testing

#### Enhanced Dimensions

- **`dimension_timezones`**: Timezone support for local time calculations
- **`dimension_seasons`**: Seasonal analysis based on date and latitude
- **`dimension_continents`**: Continental grouping for geographical analysis
- **`dimension_application_versions`**: Application version tracking
- **`fact_hashtags`**: Bridge table for many-to-many hashtag relationships

#### Improved Dimensions

- **`dimension_time_of_week`**: Renamed from `dimension_hours_of_week` with enhanced attributes
- **`dimension_users`**: SCD2 implementation for username changes
- **`dimension_countries`**: ISO codes (alpha2, alpha3) support
- **`dimension_days`**: Enhanced date attributes (ISO week, quarter, names)
- **`dimension_applications`**: Enhanced attributes (pattern_type, vendor, category)

### Enhanced Functions Testing

#### New Functions

- **`get_timezone_id_by_lonlat(lon, lat)`**: Timezone calculation from coordinates
- **`get_season_id(ts, lat)`**: Season calculation from date and latitude
- **`get_application_version_id(app_id, version)`**: Application version management
- **`get_local_date_id(ts, tz_id)`**: Local date calculation
- **`get_local_hour_of_week_id(ts, tz_id)`**: Local hour calculation

#### Improved Functions

- **`get_date_id(date)`**: Enhanced with ISO week, quarter, names
- **`get_time_of_week_id(timestamp)`**: Enhanced with hour_of_week, period_of_day

### ETL Enhanced Testing

#### Staging Procedures

- **New columns**: `action_timezone_id`, `local_action_dimension_id_date`, `action_dimension_id_season`
- **SCD2 support**: User dimension with `valid_from`, `valid_to`, `is_current`
- **Bridge table**: `fact_hashtags` for hashtag relationships
- **Application versions**: Parsing and storing application versions

#### Datamart Compatibility

- **Updated references**: All datamarts updated for `dimension_time_of_week`
- **SCD2 integration**: Datamarts handle current vs historical user records
- **New dimensions**: Datamarts can reference new dimensions (continents, seasons, timezones)

### Running DWH Tests

#### Complete DWH Test Suite

```bash
# Run all DWH enhanced tests
./tests/run_dwh_tests.sh

# Run with specific database
./tests/run_dwh_tests.sh --db-name testdb --db-user testuser

# Dry run (show what would be executed)
./tests/run_dwh_tests.sh --dry-run
```

#### Individual Test Categories

```bash
# SQL unit tests only
./tests/run_dwh_tests.sh --skip-integration

# Integration tests only
./tests/run_dwh_tests.sh --skip-sql

# Specific SQL test
psql -d notes -f tests/unit/sql/dwh_dimensions_enhanced.test.sql

# Specific integration test
bats tests/integration/ETL_enhanced_integration.test.bats
```

#### From Main Test Runner

```bash
# Run DWH tests from main runner
./tests/run_tests.sh --type dwh

# Run all tests including DWH
./tests/run_tests.sh --type all
```

### DWH Test Coverage

#### Unit Tests (`tests/unit/sql/`)

**`dwh_dimensions_enhanced.test.sql`**:

- ✅ New dimension tables existence
- ✅ Renamed dimension validation
- ✅ New columns in existing dimensions
- ✅ SCD2 columns in users dimension
- ✅ Bridge table structure
- ✅ Dimension population validation

**`dwh_functions_enhanced.test.sql`**:

- ✅ New function existence and functionality
- ✅ Enhanced function attributes
- ✅ SCD2 user dimension functionality
- ✅ Bridge table functionality
- ✅ Dimension population validation

#### Integration Tests (`tests/integration/`)

**`ETL_enhanced_integration.test.bats`**:

- ✅ Enhanced dimensions validation
- ✅ SCD2 implementation validation
- ✅ New functions validation
- ✅ Staging procedures validation
- ✅ Datamart compatibility
- ✅ Enhanced functions integration
- ✅ Bridge table implementation
- ✅ Documentation consistency

**`datamart_enhanced_integration.test.bats`**:

- ✅ DatamartUsers enhanced functionality
- ✅ DatamartCountries enhanced functionality
- ✅ Script validation
- ✅ Enhanced dimensions integration
- ✅ SCD2 integration
- ✅ Bridge table integration
- ✅ Application version integration
- ✅ Season integration
- ✅ Script execution
- ✅ Enhanced columns validation
- ✅ Documentation consistency

### Example DWH Test Output

```bash
$ ./tests/run_dwh_tests.sh
[INFO] Starting DWH enhanced tests...
[INFO] Checking prerequisites...
[SUCCESS] Prerequisites check completed
[INFO] Running DWH SQL unit tests...
[INFO] Testing enhanced dimensions...
[SUCCESS] Enhanced dimensions tests passed
[INFO] Testing enhanced functions...
[SUCCESS] Enhanced functions tests passed
[INFO] Running DWH integration tests...
[INFO] Testing ETL enhanced integration...
✓ ETL enhanced dimensions validation
✓ ETL SCD2 implementation validation
✓ ETL new functions validation
✓ ETL staging procedures validation
✓ ETL datamart compatibility
[INFO] Testing datamart enhanced integration...
✓ DatamartUsers enhanced functionality
✓ DatamartCountries enhanced functionality
✓ Datamart script validation
✓ Datamart enhanced dimensions integration
[INFO] Test summary:
[INFO]   Total tests: 4
[INFO]   Passed: 4
[INFO]   Failed: 0
[SUCCESS] All DWH enhanced tests passed!
```

### DWH Test Prerequisites

#### Database Requirements

- PostgreSQL database with DWH schema
- Enhanced dimensions and functions installed
- Sample data for testing

#### Environment Variables

```bash
# Database configuration
export DBNAME=notes
export DBUSER=notes

# Test configuration
export SKIP_SQL=false
export SKIP_INTEGRATION=false
```

#### Installation Steps

1. **Install DWH schema**:

   ```bash
   psql -d notes -f sql/dwh/ETL_22_createDWHTables.sql
   psql -d notes -f sql/dwh/ETL_24_addFunctions.sql
   psql -d notes -f sql/dwh/ETL_25_populateDimensionTables.sql
   ```

2. **Verify installation**:

   ```bash
   ./tests/run_dwh_tests.sh --dry-run
   ```

3. **Run tests**:

   ```bash
   ./tests/run_dwh_tests.sh
   ```

## Resource Limitation Features

### XML Processing Resource Limits

The system now includes advanced resource management for XML processing to prevent system overload:

- **CPU Limitation**: Restricts xmllint to 25% of one CPU core using `cpulimit`
- **Memory Limitation**: Restricts memory usage to 2GB using `ulimit -v`
- **Process Monitoring**: Real-time monitoring of CPU and memory usage
- **Timeout Protection**: Extended timeout (300s) for large files with early termination if needed
- **Resource Logging**: Detailed logs of resource usage stored in `${TMP_DIR}/xmllint_resources.log`

### Testing the Resource Limits

The `resource_limits.test.bats` file contains comprehensive tests for:

1. **Function Existence**: Verifies all resource limit functions are available
2. **Valid XML Processing**: Tests processing with resource limits on valid XML files
3. **Invalid XML Handling**: Tests error handling with malformed XML files
4. **Resource Monitoring**: Tests the background resource monitoring functionality
5. **CPU Limit Detection**: Tests behavior when `cpulimit` is not available
6. **Memory Limit Enforcement**: Tests memory restriction functionality

### Example Test Output

```bash
$ cd tests/unit/bash && bats resource_limits.test.bats
✓ test_monitor_xmllint_resources_function_exists
✓ test_monitor_xmllint_resources_with_short_process  
✓ test_run_xmllint_with_limits_function_exists
✓ test_run_xmllint_with_limits_with_valid_xml
✓ test_run_xmllint_with_limits_with_invalid_xml
✓ test_cpulimit_availability_warning
✓ test_validate_xml_structure_only_function_exists
```

## Historical Data Validation Features

### ProcessAPI Data Integrity Protection

The system now includes critical validation to ensure ProcessAPI doesn't run without proper historical context:

- **Historical Data Requirement**: ProcessAPI now requires at least 30 days of historical data
- **Automatic Detection**: Validates both `notes` and `note_comments` tables for sufficient historical coverage
- **Graceful Failure**: Provides clear error messages and actionable guidance when historical data is missing
- **Database Integrity**: Ensures ProcessAPI only processes incremental updates with proper historical context

### Testing the Historical Data Validation

The `historical_data_validation.test.bats` file contains comprehensive tests for:

1. **Function Existence**: Verifies `__checkHistoricalData` function is available
2. **Empty Table Validation**: Tests behavior when tables exist but are empty
3. **Insufficient Data Validation**: Tests when data exists but lacks sufficient history (< 30 days)
4. **Successful Validation**: Tests when sufficient historical data exists
5. **Database Connection Issues**: Tests graceful handling of database connectivity problems
6. **SQL Script Validation**: Tests the actual SQL validation logic
7. **Integration Testing**: Tests ProcessAPI script integration

### Integration Test Examples

The `processAPI_historical_integration.test.bats` provides scenario-based tests:

```bash
# Test normal operation with historical data
✓ processAPI_should_continue_when_base_tables_and_historical_data_exist

# Test critical failure without historical data  
✓ processAPI_should_exit_when_historical_data_missing

# Test automatic planet sync when base tables missing
✓ processAPI_should_run_planet_sync_when_base_tables_missing
```

### End-to-End Database Tests

The `processAPI_historical_e2e.test.bats` provides real database scenario testing:

- **Empty Database Scenario**: Tests validation with empty base tables
- **Recent Data Only**: Tests insufficient historical data (< 30 days)
- **Sufficient Historical Data**: Tests successful validation with adequate history
- **Actual SQL Script Testing**: Tests the real SQL validation scripts

### Example Error Messages

When historical validation fails, ProcessAPI now shows:

```
CRITICAL: Historical data validation failed!
ProcessAPI cannot continue without historical data from Planet.
The system needs historical context to properly process incremental updates.

Required action: Run processPlanetNotes.sh first to load historical data:
  /path/to/processPlanetNotes.sh

This will load the complete historical dataset from OpenStreetMap Planet dump.
```

## XSLT Enum Format Validation Features

### PostgreSQL Enum Compatibility Fix

A critical bug was identified and fixed in the XSLT transformations that generate CSV files for database import:

**Original Problem:**

```text
ERROR: la sintaxis de entrada no es válida para el enum note_event_enum: «"opened"»
CONTEXTO: COPY note_comments_api, línea 1, columna event: «"opened"»
```

**Root Cause:** XSLT files were generating enum values with double quotes (`"opened"`) when PostgreSQL expects unquoted values (`opened`).

### Fixed XSLT Files

1. **`xslt/note_comments-API-csv.xslt`** (Version 2025-08-07)
   - Fixed enum value generation: `,opened,` instead of `,"opened",`
   - Corrected XML element access: `action` instead of `@action`
   - Updated note ID extraction: `id` instead of `@id`

2. **`xslt/note_comments-Planet-csv.xslt`** (Version 2025-08-07)
   - Applied same enum format fix for consistency
   - Maintains proper CSV structure for PostgreSQL COPY

### CSV Format Specification

**Correct Format for PostgreSQL:**

```csv
note_id,sequence,enum_value,"timestamp",user_id,"username"
123,1,opened,"2025-08-07T19:31:31Z",1001,"testuser"
123,2,commented,"2025-08-07T19:32:15Z",1002,"anotheruser"
123,3,closed,"2025-08-07T19:33:00Z",1003,"closer"
```

**Field Types:**

- `note_id`: INTEGER (no quotes)
- `sequence`: INTEGER (no quotes)
- `enum_value`: ENUM (no quotes) - **CRITICAL: This was the bug**
- `timestamp`: TEXT (with quotes)
- `user_id`: INTEGER (no quotes)
- `username`: TEXT (with quotes)

### Testing the Enum Format

The `xslt_enum_format.test.bats` file provides comprehensive validation:

#### Test Categories

1. **Basic Enum Validation**: Ensures enum values don't have quotes
2. **Multiple Enum Values**: Tests all enum values (`opened`, `commented`, `closed`, `reopened`)
3. **PostgreSQL Compatibility**: Validates exact CSV format expected by database
4. **Regression Testing**: Reproduces and validates fix for original error
5. **Comprehensive Format Testing**: Validates complete CSV structure

#### Example Test Output

```bash
# Test Results
✓ api_xslt_generates_enum_values_without_quotes
✓ api_xslt_handles_different_enum_values_correctly
✓ planet_xslt_generates_enum_values_without_quotes
✓ planet_xslt_handles_different_enum_values_correctly
✓ api_csv_format_is_compatible_with_postgresql_enum
✓ planet_csv_format_is_compatible_with_postgresql_enum
✓ verify_fix_for_reported_enum_error
✓ csv_format_is_ready_for_postgresql_copy_command

8 tests, 0 failures
```

### Impact of the Fix

- ✅ **Eliminates PostgreSQL import errors** for note comments
- ✅ **Ensures data consistency** between API and Planet processing
- ✅ **Maintains CSV compatibility** with database COPY commands
- ✅ **Prevents future enum-related errors** through comprehensive testing
- ✅ **Preserves all other CSV field formatting** (timestamps, usernames remain quoted)

## Troubleshooting

### Common Issues

1. **PostgreSQL access denied**:
   - Ensure PostgreSQL is running: `sudo systemctl start postgresql`
   - Configure local access in `pg_hba.conf`
   - Or use Docker: `cd tests/docker && docker compose up -d`

2. **Docker requires sudo**:
   - Add user to docker group: `sudo usermod -aG docker $USER`
   - Log out and log back in
   - Or use the non-Docker tests: `./tests/run_tests_simple.sh`

3. **Missing dependencies**:
   - Run: `./tests/install_dependencies.sh`
   - Or install manually: `sudo apt-get install postgresql-client bats`

4. **DWH tests failing**:
   - Ensure DWH schema is installed: `psql -d notes -f sql/dwh/ETL_22_createDWHTables.sql`
   - Check database connection: `psql -d notes -c "SELECT 1;"`
   - Verify enhanced functions: `psql -d notes -c "SELECT proname FROM pg_proc WHERE proname LIKE 'get_%';"`

## Dependencies

- BATS testing framework
- Docker and docker-compose (optional)
- PostgreSQL test database
- Various testing tools (shellcheck, shfmt, etc.)

## Test Configuration and Standardized Values

### Overview

This document describes the standardized configuration values used across all test
environments in the OSM-Notes-profile project. **Test properties are completely
separate from production properties** to maintain clear boundaries between
environments.

### Test Properties vs Production Properties

#### Test Properties (`tests/properties.sh`)

- **Purpose**: Configuration for all test environments
- **Scope**: Unit tests, integration tests, CI/CD tests
- **Values**: Conservative, safe defaults for testing
- **Independence**: Completely separate from production

#### Production Properties (`etc/properties.sh`)

- **Purpose**: Configuration for production environments
- **Scope**: Live data processing, production deployments
- **Values**: Optimized for performance and reliability
- **Independence**: No test-specific values

### Test Properties Configuration

#### Database Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `TEST_DBNAME` | `osm_notes_test` | Test database name |
| `TEST_DBUSER` | `testuser` (Docker) / `postgres` (Host) | Test-specific database user |
| `TEST_DBPASSWORD` | `testpass` (Docker) / `` (Host) | Database password |
| `TEST_DBHOST` | `postgres` (Docker) / `localhost` (Host) | Database host |
| `TEST_DBPORT` | `5432` | Database port |

#### Timeout Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `TEST_TIMEOUT` | `300` (5 minutes) | General test timeout |
| `PERFORMANCE_TIMEOUT` | `60` (1 minute) | Performance test timeout |
| `MOCK_API_TIMEOUT` | `30` (30 seconds) | Mock API timeout |
| `CI_TIMEOUT` | `600` (10 minutes) | CI/CD timeout |
| `DOCKER_TIMEOUT` | `300` (5 minutes) | Docker operations timeout |
| `VALIDATION_TIMEOUT` | `60` (1 minute) | Validation test timeout |

#### Retry Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `TEST_RETRIES` | `3` | Standard retry count |
| `MAX_RETRIES` | `30` | Maximum retries for service startup |
| `RETRY_INTERVAL` | `2` | Seconds between retries |
| `CI_MAX_RETRIES` | `20` | CI environment retries |
| `DOCKER_MAX_RETRIES` | `10` | Docker-specific retries |
| `VALIDATION_RETRIES` | `3` | Validation retries |

#### Threading Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `MAX_THREADS` | `2` | Conservative threading for tests |
| `CI_MAX_THREADS` | `2` | Conservative threading for CI |
| `PARALLEL_THREADS` | `2` | Conservative parallel processing |
| `PARALLEL_ENABLED` | `false` | Enable parallel processing |

#### Memory Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `MEMORY_LIMIT_MB` | `100` | Memory limit for tests |

### Environment-Specific Configuration

#### Docker Environment

- Uses `testuser`/`testpass` credentials
- Connects to `postgres` host
- Conservative threading (2 threads)
- Extended timeouts for container startup

#### Host Environment

- Uses `postgres` user with no password
- Connects to `localhost`
- Conservative threading (2 threads)
- Standard timeouts

#### CI/CD Environment

- Extended timeouts (10 minutes)
- More retries (20 attempts)
- Conservative threading (2 threads)
- Enhanced logging and error reporting

### Usage

#### Loading Test Properties

All test scripts automatically load the test properties:

```bash
# Load test properties
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/properties.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/properties.sh"
fi
```

#### Overriding Test Values

You can override any test value by setting environment variables:

```bash
# Override timeout for specific test
export TEST_TIMEOUT=600
bash tests/run_tests_simple.sh

# Override threading for performance test
export MAX_THREADS=4
bash tests/run_enhanced_tests.sh --parallel
```

#### Production vs Test Values

The system uses different default values for production and test environments:

| Configuration | Production | Test |
|---------------|------------|------|
| `MAX_THREADS` | `4-16` (based on cores) | `2` |
| `MEMORY_LIMIT_MB` | `512` | `100` |
| `TEST_TIMEOUT` | `600` | `300` |
| `MAX_RETRIES` | `30` | `30` |

### Benefits of Separation

1. **Clear Boundaries**: Test and production configurations are completely separate
2. **Safety**: Test values cannot accidentally affect production
3. **Maintainability**: Each environment has its own configuration file
4. **Reliability**: Predictable behavior in each environment
5. **Flexibility**: Easy to customize each environment independently

