# Testing Guide

## Overview

This document provides comprehensive guidance for testing the OSM-Notes-profile project. The testing framework includes unit tests, integration tests, and performance tests to ensure code quality and reliability.

## Test Structure

### Unit Tests (`tests/unit/`)

Unit tests are organized by language and functionality:

- **Bash tests** (`tests/unit/bash/`): Test bash scripts and functions
- **SQL tests** (`tests/unit/sql/`): Test database functions and procedures

### Integration Tests (`tests/integration/`)

Integration tests verify that different components work together correctly.

### Performance Tests (`tests/advanced/performance/`)

Performance tests measure system performance under various conditions.

## XML Validation Testing

### Enhanced XML Validation Functions

The project now uses enhanced XML validation functions that handle large files more efficiently:

#### `__validate_xml_with_enhanced_error_handling`

This is the main validation function that automatically chooses the appropriate validation strategy based on file size:

- **Small files** (< 500MB): Standard validation with schema
- **Large files** (500MB - 1GB): Basic validation without schema
- **Very large files** (> 1GB): Structure-only validation

#### `__validate_xml_basic`

Performs basic XML structure validation without schema validation:
- Checks for root element `<osm-notes>`
- Verifies note elements exist
- Counts total notes
- Validates tag matching

#### `__validate_xml_structure_only`

Performs lightweight structure validation for very large files:
- Same as basic validation but optimized for very large files
- No schema validation to avoid memory issues

### Testing XML Validation

#### Unit Tests

1. **`xml_validation_enhanced.test.bats`**: Tests the enhanced validation functions
2. **`xml_validation_functions.test.bats`**: Tests individual validation functions
3. **`xml_validation_large_files.test.bats`**: Tests large file handling

#### Integration Tests

1. **`processPlanetNotes_integration.test.bats`**: Tests Planet notes validation
2. **`processAPINotes_integration.test.bats`**: Tests API notes validation

#### Key Test Scenarios

- **Small files**: Standard validation with schema
- **Large files**: Basic validation without schema
- **Very large files**: Structure-only validation
- **Invalid XML**: Error handling and reporting
- **Missing files**: Proper error messages
- **Memory constraints**: Graceful degradation

### Running XML Validation Tests

```bash
# Run all XML validation tests
./tests/run_xml_xslt_tests.sh

# Run specific XML validation tests
bats tests/unit/bash/xml_validation_enhanced.test.bats
bats tests/unit/bash/xml_validation_functions.test.bats
bats tests/unit/bash/xml_validation_large_files.test.bats

# Run integration tests
bats tests/unit/bash/processPlanetNotes_integration.test.bats
bats tests/unit/bash/processAPINotes_integration.test.bats
```

## Test Categories

### 1. Unit Tests

Unit tests focus on individual functions and components:

```bash
# Run all unit tests
./tests/run_tests.sh

# Run specific unit test categories
./tests/run_tests_simple.sh
./tests/run_mock_tests.sh
```

### 2. Integration Tests

Integration tests verify component interactions:

```bash
# Run integration tests
./tests/run_integration_tests.sh

# Run specific integration tests
bats tests/integration/end_to_end.test.bats
bats tests/integration/processAPI_historical_e2e.test.bats
```

### 3. Performance Tests

Performance tests measure system performance:

```bash
# Run performance tests
./tests/advanced/performance/run_performance_tests.sh
```

## Test Environment Setup

### Prerequisites

1. **BATS**: Install BATS testing framework
2. **PostgreSQL**: Set up test database
3. **Dependencies**: Install required tools and libraries

### Environment Configuration

1. **Test Database**: Configure test database connection
2. **Mock Commands**: Set up mock commands for testing
3. **Test Data**: Prepare test data and fixtures

## Running Tests

### Quick Start

```bash
# Run all tests
./tests/run_all_tests.sh

# Run specific test categories
./tests/run_tests_simple.sh
./tests/run_integration_tests.sh
./tests/run_quality_tests.sh
```

### Test Execution Options

- **Verbose mode**: `bats --verbose`
- **Parallel execution**: `bats --jobs 4`
- **Specific tests**: `bats --filter "test_name"`
- **Output format**: `bats --formatter tap`

## Test Data Management

### Fixtures

Test fixtures are stored in `tests/fixtures/`:

- **XML files**: Sample XML data for testing
- **SQL scripts**: Database setup and teardown scripts
- **Configuration**: Test configuration files

### Mock Data

Mock data is generated for testing:

- **Large files**: Generated XML files for performance testing
- **Edge cases**: Special XML structures for validation testing
- **Error scenarios**: Malformed data for error handling tests

## Continuous Integration

### GitHub Actions

Tests are automatically run in GitHub Actions:

- **Unit tests**: Run on every push
- **Integration tests**: Run on pull requests
- **Performance tests**: Run on schedule

### Local CI

Run CI tests locally:

```bash
# Run CI tests
./tests/run_ci_tests.sh

# Run quality checks
./tests/run_quality_tests.sh
```

## Troubleshooting

### Common Issues

1. **Test failures**: Check test environment setup
2. **Database issues**: Verify PostgreSQL connection
3. **Memory issues**: Adjust test configuration
4. **Timeout issues**: Increase timeout values

### Debugging

1. **Verbose output**: Use `--verbose` flag
2. **Log files**: Check test log files
3. **Environment**: Verify environment variables
4. **Dependencies**: Check required tools

## Best Practices

### Test Writing

1. **Descriptive names**: Use clear test names
2. **Isolation**: Tests should be independent
3. **Cleanup**: Always clean up test data
4. **Documentation**: Document complex test scenarios

### Test Maintenance

1. **Regular updates**: Keep tests up to date
2. **Refactoring**: Update tests when code changes
3. **Performance**: Monitor test execution time
4. **Coverage**: Maintain good test coverage

## Contributing

### Adding New Tests

1. **Follow conventions**: Use existing test patterns
2. **Documentation**: Update this guide
3. **Review**: Submit for code review
4. **Integration**: Ensure tests pass in CI

### Test Standards

1. **Code quality**: Follow project coding standards
2. **Performance**: Tests should run efficiently
3. **Reliability**: Tests should be stable
4. **Maintainability**: Tests should be easy to maintain
