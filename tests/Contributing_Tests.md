# Contributing Tests to OSM-Notes-Ingestion

This guide provides comprehensive instructions for contributing tests to the OSM-Notes-Ingestion
project.

## Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Writing Tests](#writing-tests)
- [Test Documentation](#test-documentation)
- [Using Fixtures](#using-fixtures)
- [Mocking External Dependencies](#mocking-external-dependencies)
- [Test Naming Conventions](#test-naming-conventions)
- [Code Quality Standards](#code-quality-standards)
- [Running Tests](#running-tests)
- [Submitting Tests](#submitting-tests)

## Overview

### Test Framework

The project uses **BATS (Bash Automated Testing System)** for all shell script testing. BATS
provides a simple, powerful framework for testing Bash scripts and functions.

### Test Categories

1. **Unit Tests**: Test individual functions and components in isolation
2. **Integration Tests**: Test how components work together
3. **Regression Tests**: Prevent historical bugs from reoccurring
4. **Performance Tests**: Benchmark system performance
5. **Security Tests**: Validate security functions and prevent vulnerabilities

### Test Organization

Tests are organized by component and functionality:

```
tests/
├── unit/bash/          # Unit tests for Bash functions
├── integration/        # Integration tests
├── regression/         # Regression test suite
├── fixtures/           # Test data and fixtures
└── mock_commands/      # Mock implementations for external commands
```

## Test Structure

### Basic Test File Structure

```bash
#!/usr/bin/env bats

# Component Name - Category Tests
# Brief description of what this test file covers
# Author: Your Name
# Version: YYYY-MM-DD

load "${BATS_TEST_DIRNAME}/../../test_helper"

setup() {
  # Initialize test environment
  # Create temporary directories
  # Set up environment variables
  # Load required functions
  # Create mock dependencies
}

teardown() {
  # Clean up test files
  # Remove temporary directories
  # Reset environment variables
}

# =============================================================================
# Section: Function or Feature Name
# =============================================================================

@test "Descriptive test name that explains what is being tested" {
  # Arrange: Set up test data and conditions
  local test_var="value"

  # Act: Execute the function or code being tested
  run function_under_test "${test_var}"

  # Assert: Verify the results
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == *"expected"* ]]
}
```

### Test Sections

Organize tests into logical sections using comment headers:

```bash
# =============================================================================
# Section: Function Name or Feature
# =============================================================================

@test "Test description" {
  # Test implementation
}
```

## Writing Tests

### Test Structure: Arrange-Act-Assert

Follow the **Arrange-Act-Assert** pattern:

1. **Arrange**: Set up test data, mocks, and preconditions
2. **Act**: Execute the code being tested
3. **Assert**: Verify the results

```bash
@test "Function should handle valid input correctly" {
  # Arrange: Set up test data
  local input_file="${TEST_DIR}/test_input.txt"
  echo "test data" > "${input_file}"

  # Act: Execute function
  run process_file "${input_file}"

  # Assert: Verify results
  [[ "${status}" -eq 0 ]]
  [[ -f "${TEST_DIR}/test_output.txt" ]]
}
```

### Inline Comments

Add inline comments to explain:

- **Why** a test exists (what scenario it covers)
- **What** edge cases are being tested
- **How** complex mocks work
- **What** expected behavior should be

```bash
@test "Function should handle empty input gracefully" {
  # Test edge case: empty input file
  # Expected: function should return error code 1
  # and log appropriate error message

  local empty_file="${TEST_DIR}/empty.txt"
  touch "${empty_file}"

  run process_file "${empty_file}"

  # Verify error handling
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"empty file"* ]]
}
```

### Test Naming

Use descriptive test names that explain:

- **What** is being tested
- **When** or **under what conditions**
- **What** the expected outcome is

**Good examples**:

```bash
@test "process_file should return error when file does not exist"
@test "validate_coordinates should reject invalid latitude values"
@test "download_boundary should retry on network failure"
```

**Bad examples**:

```bash
@test "test1"
@test "process_file test"
@test "validation"
```

### Test Isolation

Each test should be **independent** and **isolated**:

- Tests should not depend on other tests
- Tests should not share state
- Tests should clean up after themselves
- Use `setup()` and `teardown()` for common initialization/cleanup

```bash
setup() {
  # Each test gets a fresh temporary directory
  TEST_DIR=$(mktemp -d)
  export TEST_DIR
}

teardown() {
  # Clean up after each test
  rm -rf "${TEST_DIR}"
}
```

## Test Documentation

### File Header

Every test file should have a header with:

- Component name and category
- Brief description
- Author name
- Version date (YYYY-MM-DD)

```bash
#!/usr/bin/env bats

# Boundary Processing - Download and Import Tests
# Tests for download and import functions (downloadBoundary, importBoundary, etc.)
# Author: Andres Gomez (AngocA)
# Version: 2025-12-31
```

### Section Headers

Use section headers to organize related tests:

```bash
# =============================================================================
# Tests for __downloadBoundary_json_geojson_only
# =============================================================================
```

### Inline Comments

Add comments for:

- Complex logic or calculations
- Mock implementations
- Edge cases
- Expected behavior

```bash
@test "Function should handle network timeout" {
  # Mock curl to simulate network timeout
  # This tests the retry logic when network operations fail
  curl() {
    sleep 2
    return 124  # Timeout exit code
  }
  export -f curl

  # Function should retry 3 times before failing
  run download_with_retry "http://example.com"

  # Verify retry behavior
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"retry"* ]]
}
```

## Using Fixtures

### Fixture Locations

- **XML/JSON Data**: `tests/fixtures/command/extra/`
- **Special Cases**: `tests/fixtures/special_cases/`
- **SQL Data**: `tests/fixtures/sample_data.sql`
- **Planet Dumps**: `tests/fixtures/planet-notes-latest.osn.xml`

### Loading Fixtures

```bash
@test "Process should handle special case XML" {
  # Load fixture from special_cases directory
  local fixture_file="${TEST_BASE_DIR}/tests/fixtures/special_cases/single_note.xml"

  run process_xml_file "${fixture_file}"

  [[ "${status}" -eq 0 ]]
}
```

### Creating Test Data

For simple test data, create it inline:

```bash
@test "Function should process valid JSON" {
  # Create minimal test JSON
  local json_file="${TEST_DIR}/test.json"
  cat > "${json_file}" << 'EOF'
{
  "type": "Feature",
  "properties": {"name": "Test"}
}
EOF

  run process_json "${json_file}"
  [[ "${status}" -eq 0 ]]
}
```

For complex or reusable test data, add it to `tests/fixtures/`.

## Mocking External Dependencies

### Mocking Strategy

The project follows a **consistent mocking strategy** to ensure tests are:

- **Fast**: Avoid slow network calls and external dependencies
- **Reliable**: Tests don't depend on external service availability
- **Maintainable**: Use common helpers instead of inline mocks
- **Isolated**: Each test is independent and doesn't affect others

### When to Use Mocks

#### Always Mock Services Requiring Internet

Mock external services that require internet connectivity:

- **OSM Notes API** (`api.openstreetmap.org`)
- **Overpass API** (`overpass-api.de`)
- **OSM Planet Server** (`planet.openstreetmap.org`)

**Reason**: These services may be unavailable, slow, or rate-limited during testing.

#### Use Real Services When Local

Use real services when they are local and reliable:

- **PostgreSQL** (local database `osm_notes_ingestion_test`)
- **System tools** (`xmllint`, `bzip2`, `jq`, `osmtogeojson`, `ogr2ogr`)

**Reason**: Local services are fast, reliable, and provide better test coverage.

### Use Common Helpers Instead of Inline Mocks

**❌ Avoid**: Creating inline mocks in each test file

```bash
# BAD: Inline mock duplicated across files
psql() {
  local ARGS=("$@")
  # ... complex parsing logic ...
  echo "result"
  return 0
}
export -f psql
```

**✅ Prefer**: Using common helpers from `test_helpers_common.bash`

```bash
# GOOD: Use common helper
load "${BATS_TEST_DIRNAME}/../../test_helpers_common"

setup() {
  # Use common helper for psql mocking
  __setup_mock_psql_for_query "SELECT.*FROM notes" "5" 0
}
```

### Available Mocking Helpers

#### PostgreSQL Mocking (`test_helpers_common.bash`)

```bash
# Mock psql for query results
__setup_mock_psql_for_query "QUERY_PATTERN" "RESULT" [EXIT_CODE]

# Mock psql for boolean results
__setup_mock_psql_boolean "QUERY_PATTERN" "t|f"

# Mock psql for count results
__setup_mock_psql_count "QUERY_PATTERN" "COUNT"

# Mock psql with tracking and pattern matching
__setup_mock_psql_with_tracking "TRACK_FILE" "MATCH_FILE" "PATTERN1:RESULT1" ...
```

**Example**:

```bash
@test "Function should query database correctly" {
  # Mock psql to return count of 5
  __setup_mock_psql_count "SELECT COUNT" "5"

  run function_that_queries_db

  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "5" ]]
}
```

#### GeoJSON Processing Mocking

```bash
# Mock osmtogeojson for OSM→GeoJSON conversion
__setup_mock_osmtogeojson "INPUT_PATTERN" "OUTPUT_FILE"

# Mock ogr2ogr for GeoJSON→PostgreSQL import
__setup_mock_ogr2ogr "true|false" [ERROR_MESSAGE]
```

**Example**:

```bash
@test "Function should convert JSON to GeoJSON" {
  __setup_mock_osmtogeojson ".*\.json" "/tmp/output.geojson"

  run convert_to_geojson "input.json"

  [[ "${status}" -eq 0 ]]
  [[ -f "/tmp/output.geojson" ]]
}
```

#### API Mocking

```bash
# Mock curl for API calls
__setup_mock_curl_for_api "URL_PATTERN" "RESPONSE" [STATUS_CODE]

# Mock curl for Overpass API
__setup_mock_curl_overpass "QUERY_PATTERN" "RESPONSE" [STATUS_CODE]
```

**Example**:

```bash
@test "Function should download from API" {
  __setup_mock_curl_for_api "api.openstreetmap.org" '<?xml version="1.0"?><osm></osm>' 0

  run download_from_api

  [[ "${status}" -eq 0 ]]
}
```

### Service Availability Helpers

Use `service_availability_helpers.bash` to check service availability before running tests:

```bash
load "${BATS_TEST_DIRNAME}/service_availability_helpers"

@test "Function should work with Overpass API" {
  # Skip if Overpass API is not available
  __skip_if_overpass_api_unavailable "Overpass API not available"

  # Test implementation
  run function_that_uses_overpass

  [[ "${status}" -eq 0 ]]
}
```

**Available Skip Helpers**:

- `__skip_if_osm_api_unavailable [MESSAGE]`
- `__skip_if_overpass_api_unavailable [MESSAGE]`
- `__skip_if_planet_server_unavailable [MESSAGE]`
- `__skip_if_postgresql_unavailable [DBNAME] [MESSAGE]`
- `__skip_if_network_unavailable [MESSAGE]`
- `__skip_if_external_services_not_required [MESSAGE]`

### Hybrid Tests

**Hybrid tests** (`run_*_hybrid.sh`) are the recommended approach for integration tests:

- ✅ **Mock internet services**: OSM API, Overpass API, Planet Server
- ✅ **Use real local services**: PostgreSQL database, system tools
- ✅ **Better coverage**: Tests real database interactions
- ✅ **Faster execution**: No network delays

**Example**: `tests/run_processAPINotes_hybrid.sh`

### Database Connectivity

For tests requiring database access, use the database connectivity helper:

```bash
load "${BATS_TEST_DIRNAME}/../../test_helpers_common"

@test "Function should insert into database" {
  # Skip if database is not available
  __skip_if_no_database "${DBNAME}" "Database ${DBNAME} not available"

  # Test implementation
  run function_that_inserts_data

  [[ "${status}" -eq 0 ]]
}
```

**Note**: The default test database is `osm_notes_ingestion_test`. Set `TEST_DBNAME` environment
variable to use a different database.

### Mocking Internal Functions

Mock internal functions when testing components in isolation:

```bash
setup() {
  # Mock helper function
  __validate_json_with_element() {
    local file="${1}"
    [[ -f "${file}" ]] && [[ -s "${file}" ]]
  }
  export -f __validate_json_with_element
}
```

### Mocking with Shellcheck

When mocking functions, you may need to disable shellcheck warnings:

```bash
# shellcheck disable=SC2317
create_mock_json() {
  # Function is called indirectly by other mocks
  # shellcheck cannot detect this usage
  local id="${1}"
  # ... implementation
}
```

### Best Practices

1. **Always use common helpers** instead of creating inline mocks
2. **Check service availability** before running tests that require external services
3. **Use hybrid tests** for integration testing (mock internet, use real DB)
4. **Document complex mocks** with inline comments explaining behavior
5. **Keep mocks simple** - they should simulate behavior, not replicate full implementation
6. **Test both success and failure** scenarios with mocks

### Additional Resources

- `tests/test_helpers_common.bash` - Common mocking helpers
- `tests/integration/service_availability_helpers.bash` - Service availability checks
- `tests/TESTING_STRATEGIES.md` - Comprehensive testing strategies
- `docs/External_Services_Mocking_Analysis.md` - Detailed mocking analysis

## Test Naming Conventions

### File Naming

- Format: `[component]_[category].test.bats`
- Examples:
  - `boundary_processing_download_import.test.bats`
  - `security_functions_sanitize.test.bats`
  - `note_processing_network.test.bats`

### Test Naming

- Use descriptive names
- Start with what is being tested
- Include expected behavior
- Use present tense

**Pattern**: `[Component/Function] should [expected behavior] [when condition]`

Examples:

- `__downloadBoundary should return success when JSON is valid`
- `process_file should handle empty input gracefully`
- `validate_coordinates should reject values outside valid range`

## Code Quality Standards

### Formatting

- Use `shfmt -w -i 1 -sr -bn` to format scripts
- Maximum 80 characters per line
- Use 1 space for indentation
- No trailing whitespace

### Linting

- Run `shellcheck -x -o all` on all test files
- Fix all warnings and errors
- Use `# shellcheck disable=SC####` only when necessary with explanation

### Best Practices

1. **Use local variables** for test-specific data
2. **Clean up resources** in `teardown()`
3. **Use descriptive variable names**
4. **Avoid hardcoded values** (use variables or constants)
5. **Test both success and failure cases**
6. **Test edge cases** (empty input, null values, boundary conditions)

## Running Tests

### Run All Tests

```bash
./tests/run_tests_sequential.sh
```

### Run Specific Test File

```bash
bats tests/unit/bash/your_test_file.test.bats
```

### Run Tests with Verbose Output

```bash
bats --verbose tests/unit/bash/your_test_file.test.bats
```

### Run Tests in CI Mode

```bash
./tests/run_tests_simple.sh
```

## Submitting Tests

### Pre-Submission Checklist

- [ ] All tests pass locally
- [ ] Code is formatted with `shfmt`
- [ ] Code passes `shellcheck` with no errors
- [ ] Tests follow naming conventions
- [ ] Tests have appropriate inline comments
- [ ] Tests use fixtures appropriately
- [ ] Tests are properly isolated
- [ ] Documentation is updated (if needed)

### Commit Message

Use conventional commit format:

```
test(component): add tests for feature X

- Add unit tests for function Y
- Add integration tests for workflow Z
- Update test documentation
```

### Pull Request

When submitting a PR with tests:

1. **Describe what is being tested**
2. **Explain why these tests are needed**
3. **Include test output** showing all tests pass
4. **Reference related issues** if applicable
5. **Update documentation** if adding new test categories or fixtures

## Additional Resources

- [BATS Documentation](https://github.com/bats-core/bats-core)
- [Testing Strategies](./Testing_Strategies.md) - Comprehensive testing strategies and approaches
- [Project Testing Guide](../docs/Testing_Guide.md)
- [Test Suites Reference](../docs/Testing_Suites_Reference.md)
- [Fixtures Documentation](./fixtures/README.md)
- [External Services Mocking Analysis](../docs/External_Services_Mocking_Analysis.md) - Detailed
  analysis of mocking strategy
- [Service Availability Helpers](./integration/service_availability_helpers.bash) - Helpers for
  checking service availability

## Getting Help

- Check existing tests for examples
- Review `tests/unit/bash/README.md` for test organization
- Ask questions in GitHub Discussions
- Review test documentation in `docs/Testing_Guide.md`
