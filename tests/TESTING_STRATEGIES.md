# Testing Strategies - OSM-Notes-Ingestion

**Purpose:** Document testing strategies, approaches, and best practices used in
the OSM-Notes-Ingestion project.

---

## Table of Contents

- [Overview](#overview)
- [Testing Philosophy](#testing-philosophy)
- [Test Types and Strategies](#test-types-and-strategies)
- [Test Organization Strategy](#test-organization-strategy)
- [Mocking Strategy](#mocking-strategy)
- [Test Data Strategy](#test-data-strategy)
- [Performance Testing Strategy](#performance-testing-strategy)
- [Security Testing Strategy](#security-testing-strategy)
- [Integration Testing Strategy](#integration-testing-strategy)
- [Regression Testing Strategy](#regression-testing-strategy)
- [Test Maintenance Strategy](#test-maintenance-strategy)

---

## Overview

This document describes the testing strategies and approaches used throughout the
OSM-Notes-Ingestion project. It provides guidance on how tests are structured,
organized, and maintained to ensure code quality and reliability.

### Key Principles

1. **Comprehensive Coverage**: Tests cover critical functionality, edge cases,
   and error scenarios
2. **Isolation**: Tests are independent and can run in any order
3. **Determinism**: Tests produce consistent results
4. **Maintainability**: Tests are well-documented and easy to understand
5. **Performance**: Tests run efficiently without unnecessary overhead

---

## Testing Philosophy

### Test-Driven Development (TDD)

While not strictly TDD, the project follows these principles:

- **Write tests for bugs**: Every bug fix includes a regression test
- **Test before refactoring**: Ensure tests pass before major refactoring
- **Test edge cases**: Focus on boundary conditions and error scenarios
- **Test integration points**: Verify components work together correctly

### Test Levels

The project uses a multi-level testing approach:

1. **Unit Tests**: Test individual functions and components in isolation
2. **Integration Tests**: Test how components work together
3. **End-to-End Tests**: Test complete workflows from start to finish
4. **Performance Tests**: Measure and track system performance
5. **Security Tests**: Validate security functions and prevent vulnerabilities
6. **Regression Tests**: Prevent historical bugs from reoccurring

---

## Test Types and Strategies

### Unit Tests

**Strategy**: Test individual functions and components in isolation with mocked
dependencies.

**Approach**:
- Use BATS framework for Bash script testing
- Mock external dependencies (databases, network calls, file system)
- Test both success and failure paths
- Focus on function behavior, not implementation details

**Example**:
```bash
@test "Function should handle valid input correctly" {
  # Arrange: Set up test data
  local input="valid_input"
  
  # Act: Execute function
  run function_under_test "${input}"
  
  # Assert: Verify results
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "expected_output" ]]
}
```

### Integration Tests

**Strategy**: Test how multiple components work together without mocking internal
dependencies.

**Approach**:
- Test complete workflows (download → process → store)
- Use real database connections (test database)
- Mock only external services (OSM API, Overpass API)
- Verify data flow between components

**Example**:
```bash
@test "Complete workflow: download -> validate -> process -> store" {
  # Download notes from API
  run download_notes_from_api
  
  # Validate downloaded data
  run validate_xml_file "${DOWNLOADED_FILE}"
  
  # Process and store
  run process_and_store_notes
  
  # Verify data in database
  run verify_notes_in_database
}
```

### End-to-End Tests

**Strategy**: Test complete user workflows from start to finish.

**Approach**:
- Test complete scenarios (e.g., initial setup, daily sync, error recovery)
- Use test database with realistic data
- Verify end-to-end data integrity
- Test error scenarios and recovery

**Example**:
```bash
@test "E2E: Complete API processing workflow" {
  # Setup: Initialize empty database
  setup_empty_database
  
  # Execute: Run complete processing workflow
  run processAPINotes.sh
  
  # Verify: Check all expected outcomes
  verify_notes_loaded
  verify_countries_assigned
  verify_timestamps_updated
}
```

---

## Test Organization Strategy

### Directory Structure

Tests are organized by type and component:

```
tests/
├── unit/              # Unit tests
│   ├── bash/         # Bash function tests
│   └── sql/          # SQL function tests
├── integration/      # Integration tests
├── regression/       # Regression test suite
├── fixtures/         # Test data and fixtures
└── mock_commands/    # Mock implementations
```

### Naming Conventions

**Test Files**: `[component]_[category].test.bats`

- `component`: Component being tested (e.g., `processAPINotes`, `boundary_processing`)
- `category`: Test category (e.g., `integration`, `validation`, `error_handling`)

**Test Functions**: Descriptive names that explain what is being tested

- Format: `"should [expected behavior] when [condition]"`
- Example: `"should retry download when network error occurs"`

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

---

## Mocking Strategy

### When to Mock

Mock external dependencies that are:
- **Unreliable**: Network services, external APIs
- **Slow**: Database operations, file I/O (in unit tests)
- **Side effects**: File system modifications, system commands
- **Unavailable**: Services not available in test environment

### Mock Implementation

**Location**: `tests/mock_commands/`

**Strategy**:
- Create mock scripts that mimic real command behavior
- Use fixtures for deterministic responses
- Support both success and failure scenarios
- Maintain same interface as real commands

**Example**:
```bash
# Mock curl command
#!/bin/bash
# Mock curl for testing
# Resolves URLs to fixture files

if [[ "$1" == "https://api.openstreetmap.org/api/0.6/notes/3394115.json" ]]; then
  cat "${MOCK_FIXTURES_DIR}/3394115.json"
  exit 0
fi

# Default: return error
exit 1
```

### Mock Usage

**In Tests**:
```bash
setup() {
  # Add mock commands to PATH
  export PATH="${TEST_BASE_DIR}/tests/mock_commands:${PATH}"
}
```

---

## Test Data Strategy

### Fixtures

**Purpose**: Provide deterministic test data for consistent test results.

**Location**: `tests/fixtures/`

**Types**:
1. **Command Fixtures** (`command/extra/`): JSON, XML files for API responses
2. **Special Cases** (`special_cases/`): Edge case XML scenarios
3. **XML Test Data** (`xml/`): Sample XML files for processing tests
4. **SQL Sample Data** (`sample_data.sql`): Database test data

**Usage**:
```bash
@test "Process should handle special case XML" {
  local fixture="${TEST_BASE_DIR}/tests/fixtures/special_cases/single_note.xml"
  run process_xml_file "${fixture}"
  [[ "${status}" -eq 0 ]]
}
```

### Inline Test Data

**When to Use**:
- Simple, test-specific data
- Data that needs to be modified per test
- One-time use data

**Example**:
```bash
@test "Function should process valid JSON" {
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

---

## Performance Testing Strategy

### Benchmark Tests

**Purpose**: Track performance metrics and detect regressions.

**Approach**:
- Measure execution time for critical operations
- Track memory usage
- Compare performance across versions
- Store results in JSON format for analysis

**Metrics Collected**:
- XML processing performance
- Database operation time
- File I/O throughput
- Memory usage
- Parallel processing efficiency

**Example**:
```bash
@test "BENCHMARK: XML validation performance" {
  local start_time=$(date +%s.%N)
  
  # Execute operation
  validate_xml_file "${LARGE_XML_FILE}"
  
  local end_time=$(date +%s.%N)
  local duration=$(echo "${end_time} - ${start_time}" | bc -l)
  
  # Store benchmark result
  store_benchmark_result "xml_validation" "${duration}"
}
```

### Performance Targets

- **Unit Tests**: < 1 second per test
- **Integration Tests**: < 30 seconds per test
- **E2E Tests**: < 5 minutes per test
- **Full Test Suite**: < 30 minutes total

---

## Security Testing Strategy

### Input Sanitization Tests

**Purpose**: Verify that all user inputs are properly sanitized.

**Approach**:
- Test SQL injection prevention
- Test command injection prevention
- Test path traversal prevention
- Test XSS prevention (if applicable)

**Coverage**:
- All sanitization functions
- All input validation functions
- All database query functions

### Security Test Categories

1. **SQL Injection Tests**: Verify SQL injection attacks are prevented
2. **Input Sanitization Tests**: Verify input sanitization functions work correctly
3. **Edge Case Security Tests**: Test security edge cases
4. **Integration Security Tests**: Test security in integration scenarios

---

## Integration Testing Strategy

### Component Integration

**Strategy**: Test how components work together.

**Approach**:
- Test API → Processing → Database flow
- Test Planet → Processing → Database flow
- Test Boundary → Processing → Database flow
- Verify data integrity throughout the pipeline

### External Service Integration

**Strategy**: Test integration with external services using mocks.

**Approach**:
- Mock OSM API responses
- Mock Overpass API responses
- Mock Planet file downloads
- Test error handling and retry logic

---

## Regression Testing Strategy

### Bug Documentation

**Strategy**: Document every bug with a regression test.

**Approach**:
1. Document the bug in test comments
2. Write test that verifies the fix
3. Ensure test passes with current code
4. Update regression suite README

**Format**:
```bash
# =============================================================================
# Bug #N: Brief Description
# =============================================================================
# Bug: Detailed description of what was wrong
# Fix: How it was fixed
# Commit: commit_hash
# Date: YYYY-MM-DD
# Reference: docs/SomeDocument.md

@test "REGRESSION: Brief description of what should not happen" {
  # Test that verifies the bug is fixed
}
```

### Regression Test Maintenance

- **Add tests for new bugs**: Every bug fix includes a regression test
- **Keep tests updated**: Update tests when behavior changes intentionally
- **Remove obsolete tests**: Remove tests for bugs that are no longer relevant

---

## Test Maintenance Strategy

### Code Duplication

**Strategy**: Consolidate common test code into helper functions.

**Approach**:
- Create helper files for common test patterns
- Use helper functions for setup/teardown
- Share fixtures across tests
- Consolidate mock implementations

**Helper Files**:
- `tests/regression/regression_helpers.bash`
- `tests/integration/boundary_processing_helpers.bash`
- `tests/unit/bash/daemon_test_helpers.bash`

### Test Refactoring

**Strategy**: Keep tests maintainable and readable.

**Approach**:
- Split long tests (>200 lines) into smaller tests
- Extract common patterns into helper functions
- Use descriptive test names
- Add comments explaining complex test logic

### Test Documentation

**Strategy**: Document tests for maintainability.

**Approach**:
- Add header comments to test files
- Add inline comments explaining test logic
- Document test fixtures and their purpose
- Update documentation when tests change

---

## Best Practices

### Test Writing

1. **Arrange-Act-Assert**: Follow AAA pattern for test structure
2. **One Assertion Per Test**: Focus each test on one behavior
3. **Descriptive Names**: Use clear, descriptive test names
4. **Comments**: Add comments explaining why, not what
5. **Isolation**: Tests should be independent and runnable in any order

### Test Maintenance

1. **Keep Tests Updated**: Update tests when code changes
2. **Remove Obsolete Tests**: Remove tests that are no longer relevant
3. **Refactor Regularly**: Refactor tests to improve maintainability
4. **Document Changes**: Document test changes in commit messages

### Test Execution

1. **Run Tests Locally**: Run tests before committing
2. **Run Tests in CI**: Ensure all tests pass in CI environment
3. **Monitor Test Performance**: Track test execution time
4. **Fix Failing Tests**: Fix failing tests immediately

---

## Related Documentation

- [Contributing Tests Guide](./CONTRIBUTING_TESTS.md)
- [Fixtures Documentation](./fixtures/README.md)
- [Testing Guide](../docs/Testing_Guide.md)
- [Test Suites Reference](../docs/Testing_Suites_Reference.md)

