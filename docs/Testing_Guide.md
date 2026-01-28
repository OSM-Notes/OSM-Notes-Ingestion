---
title: "Testing Guide - OSM-Notes-Ingestion"
description: "This guide provides comprehensive information about the implemented integration tests, use cases,"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "testing"
  - "guide"
audience:
  - "developers"
project: "OSM-Notes-Ingestion"
status: "active"
---


# Testing Guide - OSM-Notes-Ingestion

> **Note:** For system architecture overview, see [Documentation.md](./Documentation.md).  
> For project motivation and background, see [Rationale.md](./Rationale.md).  
> For test execution procedures, see [Test_Execution_Guide.md](./Test_Execution_Guide.md).

## Summary

This guide provides comprehensive information about the implemented integration tests, use cases,
and troubleshooting for the OSM-Notes-Ingestion project.

## GitHub Actions Workflows

The project uses three main GitHub Actions workflows that run automatically on each push or pull
request:

### 1. Tests (tests.yml)

**Purpose:** Runs the main battery of unit and integration tests. **What it validates:**

- Bash functions and scripts work correctly in isolation
- System components interact correctly with each other
- Main data processing flows, XML validation, error handling, and parallelism work as expected
- Includes tests with real data, mock tests, and hybrid tests

### 2. Quality Tests (quality-tests.yml)

**Purpose:** Ensures source code quality and compliance with best practices. **What it validates:**

- Bash and SQL scripts comply with defined format and style standards
- No duplicate variables, syntax errors, or permission issues in scripts
- Documentation and configuration files are present and properly formatted

### 3. Integration Tests (integration-tests.yml)

**Purpose:** Validates system module integration, especially in environments that simulate real
infrastructure. **What it validates:**

- Scripts can interact correctly with PostgreSQL databases and external services
- Note processing works end-to-end
- Integration with external tools (Docker, PostGIS, etc.) is successful

## Testing Scripts Summary Table

| Script / Workflow                 | Location           | Main Purpose                                                 |
| --------------------------------- | ------------------ | ------------------------------------------------------------ |
| `run_all_tests.sh`                | tests/             | Runs all main tests (unit, integration, mock, etc.)          |
| `run_integration_tests.sh`        | tests/             | Runs complete integration tests                              |
| `run_quality_tests.sh`            | tests/             | Validates code quality, format, and conventions              |
| `run_logging_validation_tests.sh` | tests/             | Validates logging pattern compliance across all bash scripts |
| `run_mock_tests.sh`               | tests/             | Runs tests using mocks and simulated environments            |
| `run_enhanced_tests.sh`           | tests/             | Advanced testability and robustness tests                    |
| `run_real_data_tests.sh`          | tests/             | Tests with real data and special cases                       |
| `run_parallel_tests.sh`           | tests/             | Validates parallel processing and concurrency                |
| `run_error_handling_tests.sh`     | tests/             | Error handling and edge case validation tests                |
| `run_ci_tests.sh`                 | tests/docker/      | CI/CD tests in Docker environment                            |
| `run_integration_tests.sh`        | tests/docker/      | Integration tests in Docker environment                      |
| `quality-tests.yml`               | .github/workflows/ | GitHub Actions workflow for quality tests                    |
| `integration-tests.yml`           | .github/workflows/ | GitHub Actions workflow for integration tests                |
| `tests.yml`                       | .github/workflows/ | GitHub Actions workflow for main unit and integration tests  |

## Types of Tests

### 1. Integration Tests

Integration tests actually run the scripts to detect real problems like:

- `log_info: orden no encontrada`
- `Notes are not yet on the database`
- `FAIL! (1) - __validation error`

### 2. Consolidated Functions Testing

The project includes specialized tests for consolidated functions that eliminate code duplication:

- **Parallel Processing Functions**: Tests for `bin/lib/parallelProcessingFunctions.sh` ensure XML
  processing functions work correctly across different formats (API vs Planet)
- **Validation Functions**: Tests for `lib/osm-common/consolidatedValidationFunctions.sh` validate XML, CSV,
  coordinate, and database validation functions
- **Legacy Compatibility**: Tests ensure that existing scripts continue to work while using the new
  consolidated implementations
- **Fallback Mechanisms**: Tests verify that scripts gracefully handle missing consolidated function
  files

#### Covered Scripts

**Processing Scripts:**

- `processAPINotes.sh` - API note processing
- `processPlanetNotes.sh` - Planet note processing
- `updateCountries.sh` - Country updates

**Cleanup Scripts:**

- `cleanupAll.sh` - Full cleanup
- `cleanupAll.sh` - Comprehensive cleanup (full or partition-only)

For **WMS (Web Map Service) scripts**, see the
[OSM-Notes-WMS](https://github.com/OSM-Notes/OSM-Notes-WMS) repository.

**Monitor Scripts:**

- `processCheckPlanetNotes.sh` - Note verification
- `notesCheckVerifier.sh` - Note verifier

### 3. Logging Pattern Validation Tests

Logging pattern validation tests ensure that all bash functions follow the established logging
conventions:

- **`__log_start`**: Every function must start with this call
- **`__log_finish`**: Every function must end with this call and have it before each `return`
  statement
- **Consistent logging**: All functions use the same logging pattern for traceability

**Available Tests:**

- **Unit Tests**: `tests/unit/bash/logging_pattern_validation.test.bats` - Tests individual logging
  patterns
- **Integration Tests**: `tests/integration/logging_pattern_validation_integration.test.bats` -
  Tests validation scripts
- **Validation Scripts**:
  - `tests/scripts/validate_logging_patterns.sh` - Comprehensive validation
  - `tests/scripts/validate_logging_patterns_simple.sh` - Simple validation
- **Test Runner**: `tests/run_logging_validation_tests.sh` - Dedicated logging validation test
  runner

**Run Logging Validation:**

```bash
# Run all logging pattern tests
./tests/run_logging_validation_tests.sh

# Run only validation scripts
./tests/run_logging_validation_tests.sh --validate-only

# Run only BATS tests
./tests/run_logging_validation_tests.sh --bats-only

# Run specific test types
./tests/run_logging_validation_tests.sh --mode unit
./tests/run_logging_validation_tests.sh --mode integration
```

### 4. Edge Cases Tests

Edge cases tests cover boundary situations:

- Very large XML files
- Malformed XML files
- Empty database
- Corrupted database
- Network connectivity issues
- Insufficient disk space
- Permission issues
- Concurrent access
- Memory restrictions
- Invalid configuration
- Missing dependencies
- Timeout scenarios
- Data corruption
- Extreme values

## Use Cases

### Use Case 1: Local Development

**Objective:** Verify that changes work correctly before committing.

**Steps:**

1. Run integration tests locally:

   ```bash
   ./tests/run_integration_tests.sh --all
   ```

2. Run specific tests:

   ```bash
   ./tests/run_integration_tests.sh --process-api
   ./tests/run_integration_tests.sh --process-planet
   ```

3. Run edge case tests:

   ```bash
   bats tests/unit/bash/edge_cases_integration.test.bats
   ```

**Expected Result:** All tests pass without errors.

### Use Case 2: CI/CD Pipeline

**Objective:** Automatically verify code quality on each commit.

**Steps:**

1. The GitHub Actions workflow runs automatically
2. All integration tests run
3. Quality and security tests run
4. Automatic reports are generated

**Expected Result:** Successful pipeline with all tests passing.

### Use Case 3: Debugging Problems

**Objective:** Identify and resolve specific problems.

**Steps:**

1. Run specific tests that fail:

   ```bash
   bats tests/unit/bash/processAPINotes_integration.test.bats
   ```

2. Review detailed logs:

   ```bash
   ./tests/run_integration_tests.sh --process-api --verbose
   ```

3. Run edge case tests to identify problems:

   ```bash
   bats tests/unit/bash/edge_cases_integration.test.bats
   ```

**Expected Result:** Identification of the specific problem.

### Use Case 4: Configuration Validation

**Objective:** Verify that the system configuration is correct.

**Steps:**

1. Verify database connectivity:

   ```bash
   psql -h localhost -p 5432 -U postgres -d osm_notes_ingestion_test -c "SELECT 1;"
   ```

2. Verify required tools:

   ```bash
   command -v bats && echo "BATS OK"
   command -v psql && echo "PostgreSQL OK"
   command -v xmllint && echo "XML tools OK"
   ```

3. Run configuration tests:

   ```bash
   ./tests/run_integration_tests.sh --all
   ```

**Expected Result:** All verifications pass.

## Overpass Fallback and Continue-on-Error Testing

**Objective:** Validate that boundary downloads use fallback endpoints and the process continues on
invalid JSON.

**Steps:**

1. Configure endpoints and behavior:

   ```bash
   export OVERPASS_ENDPOINTS="https://overpass-api.de/api/interpreter,https://overpass.kumi.systems/api/interpreter"
   export OVERPASS_RETRIES_PER_ENDPOINT=3
   export OVERPASS_BACKOFF_SECONDS=5
   export CONTINUE_ON_OVERPASS_ERROR=true
   ```

2. Run countries update:

   ```bash
   DBNAME=osm-notes ./bin/process/updateCountries.sh
   ```

3. Inspect results:

   ```bash
   # Failed boundaries list (when continue-on-error is enabled)
   # Find files in temporary directories (works in both modes)
   find /var/tmp/osm-notes-ingestion /tmp -type d -name "updateCountries_*" 2>/dev/null | \
     head -1 | xargs -I {} find {} -name "failed_boundaries.txt" -o -name "updateCountries.log*" 2>/dev/null | \
     xargs ls -l 2>/dev/null || true
   ```

**Expected Result:**

- If primary Overpass is degraded, the script retries and then falls back to a secondary endpoint.
- Invalid JSON responses do not stop the whole process when `CONTINUE_ON_OVERPASS_ERROR=true`;
  failing boundary IDs are recorded in `failed_boundaries.txt`.

## Troubleshooting

### Problem 1: "log_info: orden no encontrada"

**Symptoms:**

- Logging errors when running scripts
- Logging functions not available

**Causes:**

- Logger not initialized correctly
- Logging functions not defined
- Script sourcing issues

**Solutions:**

1. Verify that `bash_logger.sh` is available:

   ```bash
   ls -la lib/bash_logger.sh
   ```

2. Verify logger initialization:

   ```bash
   source bin/commonFunctions.sh
   __start_logger
   ```

3. Verify logging functions:

   ```bash
   declare -f __log_info
   declare -f __log_error
   ```

### Problem 2: "Notes are not yet on the database"

**Symptoms:**

- SQL script execution errors
- Tables not found

**Causes:**

- Empty database
- Tables not created
- SQL scripts with errors

**Solutions:**

1. Verify that tables exist:

   ```bash
   psql -d osm_notes_ingestion_test -c "SELECT COUNT(*) FROM information_schema.tables;"
   ```

2. Create tables if they don't exist:

   ```bash
   psql -d osm_notes_ingestion_test -f sql/process/processPlanetNotes_22_createBaseTables_tables.sql
   ```

3. Verify SQL scripts:

   ```bash
   psql -d osm_notes_ingestion_test -f sql/process/processAPINotes_23_createPropertiesTables.sql
   ```

### Problem 3: "FAIL! (1) - \_\_validation error"

**Symptoms:**

- Validation function errors
- Infinite loops in traps

**Causes:**

- Validation functions not defined
- Error traps issues
- Recursion in functions

**Solutions:**

1. Verify validation functions:

   ```bash
   declare -f __validation
   ```

2. Verify traps:

   ```bash
   trap -p
   ```

3. Review recursive functions:

   ```bash
   grep -r "function __" bin/
   ```

### Problem 4: Scripts cannot be loaded (code 127)

**Symptoms:**

- Script sourcing errors
- Commands not found

**Causes:**

- Missing dependencies
- Permission issues
- Malformed scripts

**Solutions:**

1. Verify dependencies:

   ```bash
   command -v psql
   command -v xmllint
   command -v bats
   ```

2. Verify permissions:

   ```bash
   ls -la bin/*.sh
   chmod +x bin/*.sh
   ```

3. Verify syntax:

   ```bash
   bash -n bin/process/processAPINotes.sh
   ```

### Problem 5: Integration tests fail

**Symptoms:**

- Integration tests do not pass
- Errors in CI/CD

**Causes:**

- Incorrect configuration
- Missing dependencies
- Network issues

**Solutions:**

1. Verify test configuration:

   ```bash
   cat tests/properties.sh
   ```

2. Run tests with verbose:

   ```bash
   ./tests/run_integration_tests.sh --all --verbose
   ```

3. Verify connectivity:

   ```bash
   pg_isready -h localhost -p 5432
   ```

## Useful Commands

### Run All Tests

```bash
./tests/run_integration_tests.sh --all
```

### Run Specific Tests

```bash
./tests/run_integration_tests.sh --process-api
./tests/run_integration_tests.sh --process-planet
./tests/run_integration_tests.sh --cleanup
# WMS tests are in the OSM-Notes-WMS repository
# ETL/DWH tests are in the OSM-Notes-Analytics repository
```

### Run Individual Tests

```bash
bats tests/unit/bash/processAPINotes_integration.test.bats
bats tests/unit/bash/edge_cases_integration.test.bats
```

### Verify Configuration

```bash
# Verify database
psql -d osm_notes_ingestion_test -c "SELECT version();"

# Verify tools
command -v bats && echo "BATS OK"
command -v psql && echo "PostgreSQL OK"

# Verify files
ls -la bin/*.sh
ls -la sql/process/*.sql
```

### Debugging

```bash
# Run with verbose
./tests/run_integration_tests.sh --all --verbose

# Run with debug
LOG_LEVEL=DEBUG ./tests/run_integration_tests.sh --all

# Review detailed logs
tail -f tests/tmp/*.log
```

## Best Practices

### 1. Development

- Run tests before each commit
- Use specific tests for debugging
- Keep tests updated

### 2. CI/CD

- Integrate tests into automated pipeline
- Generate coverage reports
- Notify failures immediately

### 3. Monitoring

- Run tests regularly
- Review error logs
- Keep documentation updated

### 4. Maintenance

- Update tests when code changes
- Add new edge cases
- Optimize execution time

## Conclusion

Integration tests are essential to detect real problems before they reach production. This guide
provides the tools and knowledge needed to:

- ✅ **Run tests effectively**
- ✅ **Debug problems quickly**
- ✅ **Maintain code quality**
- ✅ **Integrate with CI/CD**

**Recommendation:** Use this guide as a reference to maintain the quality and reliability of the
OSM-Notes-Ingestion project.

## Related Documentation

- **[Test_Execution_Guide.md](./Test_Execution_Guide.md)**: Step-by-step test execution procedures
- **[Test_Matrix.md](./Test_Matrix.md)**: Complete test coverage matrix
- **[Testing_Suites_Reference.md](./Testing_Suites_Reference.md)**: Detailed reference for all test
  suites
- **[Testing_Workflows_Overview.md](./Testing_Workflows_Overview.md)**: GitHub Actions workflows
  explanation
- **[CI_CD_Integration.md](./CI_CD_Integration.md)**: CI/CD setup and configuration
- **[CI_Troubleshooting.md](./CI_Troubleshooting.md)**: CI/CD troubleshooting guide
- **[Documentation.md](./Documentation.md)**: System architecture and overview
- **[Process_API.md](./Process_API.md)**: API processing implementation (for testing API components)
- **[Process_Planet.md](./Process_Planet.md)**: Planet processing implementation (for testing Planet
  components)
