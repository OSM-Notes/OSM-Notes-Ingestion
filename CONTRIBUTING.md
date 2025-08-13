# Contributing to OSM-Notes-profile

Thank you for your interest in contributing to the OSM-Notes-profile project!
This document provides comprehensive guidelines for contributing to this
OpenStreetMap notes analysis system.

## Table of Contents

- [Code Standards](#code-standards)
- [Development Workflow](#development-workflow)
- [Testing Requirements](#testing-requirements)
- [File Organization](#file-organization)
- [Naming Conventions](#naming-conventions)
- [Documentation](#documentation)
- [Quality Assurance](#quality-assurance)
- [Pull Request Process](#pull-request-process)

## Code Standards

### Bash Script Standards

All bash scripts must follow these standards:

#### Required Header Structure

```bash
#!/bin/bash

# Brief description of the script functionality
#
# This script [describe what it does]
# * [key feature 1]
# * [key feature 2]
# * [key feature 3]
#
# These are some examples to call this script:
# * [example 1]
# * [example 2]
#
# This is the list of error codes:
# [list all error codes with descriptions]
#
# For contributing, please execute these commands before submitting:
# * shellcheck -x -o all [SCRIPT_NAME].sh
# * shfmt -w -i 1 -sr -bn [SCRIPT_NAME].sh
#
# Author: Andres Gomez (AngocA)
# Version: [YYYY-MM-DD]
VERSION="[YYYY-MM-DD]"
```

#### Required Script Settings

```bash
#set -xv
# Fails when a variable is not initialized.
set -u
# Fails with a non-zero return code.
set -e
# Fails if the commands of a pipe return non-zero.
set -o pipefail
# Fails if an internal function fails.
set -E
```

#### Variable Declaration Standards

- **Global variables**: Use `declare -r` for readonly variables
- **Local variables**: Use `local` declaration
- **Integer variables**: Use `declare -i`
- **Arrays**: Use `declare -a`
- **All variables must be braced**: `${VAR}` instead of `$VAR`

#### Function Naming Convention

- **All functions must start with double underscore**: `__function_name`
- **Use descriptive names**: `__download_planet_notes`, `__validate_xml_file`
- **Include function documentation**:

```bash
# Downloads the planet notes file from OSM servers.
# Parameters: None
# Returns: 0 on success, non-zero on failure
function __download_planet_notes {
  # Function implementation
}
```

#### Error Handling

- **Define error codes at the top**:

```bash
# Error codes.
# 1: Help message.
declare -r ERROR_HELP_MESSAGE=1
# 241: Library or utility missing.
declare -r ERROR_MISSING_LIBRARY=241
# 242: Invalid argument for script invocation.
declare -r ERROR_INVALID_ARGUMENT=242
```

### SQL Standards

#### File Naming Convention

- **Process files**: `processAPINotes_21_createApiTables.sql`
- **ETL files**: `ETL_11_checkDWHTables.sql`
- **Function files**: `functionsProcess_21_createFunctionToGetCountry.sql`
- **Drop files**: `processAPINotes_12_dropApiTables.sql`

#### SQL Code Standards

- **Keywords in UPPERCASE**: `SELECT`, `INSERT`, `UPDATE`, `DELETE`
- **Identifiers in lowercase**: `table_name`, `column_name`
- **Use proper indentation**: 2 spaces
- **Include comments for complex queries**
- **Use parameterized queries when possible**

## Development Workflow

### 1. Environment Setup

Before contributing, ensure you have the required tools:

```bash
# Install development tools
sudo apt-get install shellcheck shfmt bats

# Install database tools
sudo apt-get install postgresql postgis

# Install XML processing tools
sudo apt-get install libxml2-utils xsltproc xmlstarlet

# Install geographic tools
sudo apt-get install gdal-bin ogr2ogr
```

### 2. Project Structure Understanding

Familiarize yourself with the project structure:

- **`bin/`**: Executable scripts and processing components
- **`sql/`**: Database scripts and schema definitions
- **`tests/`**: Comprehensive testing infrastructure
- **`docs/`**: System documentation
- **`etc/`**: Configuration files
- **`xslt/`**: XML transformations
- **`xsd/`**: XML schema definitions
- **`overpass/`**: Geographic data queries
- **`sld/`**: Map styling definitions

### 3. Development Process

1. **Create a feature branch**:

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Follow the established patterns**:
   - Use existing function names and patterns
   - Follow the error code numbering system
   - Maintain the logging structure
   - Use the established variable naming

3. **Test your changes**:

   ```bash
   # Run basic tests
   ./tests/run_tests_simple.sh
   
   # Run enhanced tests
   ./tests/run_enhanced_tests.sh
   
   # Run advanced tests
   ./tests/advanced/run_advanced_tests.sh
   ```

## Testing Requirements

### Overview

All contributions must include comprehensive testing. The project uses **78 BATS testing suites** covering all system components, including the new DWH enhanced features.

### Test Categories

#### Unit Tests (72 suites)

- **Bash Scripts**: 68 BATS test suites for shell scripts
- **SQL Functions**: 4 SQL test suites (including DWH enhanced)

#### Integration Tests (8 suites)

- **End-to-End Workflows**: Complete system integration testing
- **DWH Enhanced**: ETL and datamart enhanced functionality testing

#### Validation Tests

- **Data Validation**: XML/CSV processing, ETL workflows
- **Error Handling**: Edge cases, error conditions
- **Performance**: Parallel processing, optimization

#### Quality Tests

- **Code Quality**: Linting, formatting, conventions
- **Security**: Vulnerability scanning, best practices

### DWH Enhanced Testing Requirements

When contributing to DWH features, you must include tests for:

#### New Dimensions

- **`dimension_timezones`**: Timezone support testing
- **`dimension_seasons`**: Seasonal analysis testing
- **`dimension_continents`**: Continental grouping testing
- **`dimension_application_versions`**: Application version testing
- **`fact_hashtags`**: Bridge table testing

#### Enhanced Dimensions

- **`dimension_time_of_week`**: Renamed dimension with enhanced attributes
- **`dimension_users`**: SCD2 implementation testing
- **`dimension_countries`**: ISO codes testing
- **`dimension_days`**: Enhanced date attributes testing
- **`dimension_applications`**: Enhanced attributes testing

#### New Functions

- **`get_timezone_id_by_lonlat()`**: Timezone calculation testing
- **`get_season_id()`**: Season calculation testing
- **`get_application_version_id()`**: Application version management testing
- **`get_local_date_id()`**: Local date calculation testing
- **`get_local_hour_of_week_id()`**: Local hour calculation testing

#### Enhanced ETL

- **Staging Procedures**: New columns, SCD2, bridge tables
- **Datamart Compatibility**: Integration with new dimensions
- **Documentation**: Consistency with implementation

### Running Tests

#### Complete Test Suite

```bash
# Run all tests (recommended)
./tests/run_all_tests.sh

# Run DWH enhanced tests only
./tests/run_dwh_tests.sh

# Run specific test categories
./tests/run_tests.sh --type dwh
```

#### Individual Test Categories

```bash
# Unit tests
bats tests/unit/bash/*.bats
bats tests/unit/sql/*.sql

# Integration tests
bats tests/integration/*.bats

# DWH enhanced tests
./tests/run_dwh_tests.sh --skip-integration  # SQL only
./tests/run_dwh_tests.sh --skip-sql          # Integration only
```

#### Test Validation

```bash
# Validate test structure
./tests/run_dwh_tests.sh --dry-run

# Check test coverage
./tests/run_tests.sh --type all
```

### Test Documentation

All new tests must be documented in:

- [Testing Suites Reference](./docs/Testing_Suites_Reference.md)
- [Testing Guide](./docs/Testing_Guide.md)
- [DWH Testing Documentation](./tests/README.md#dwh-enhanced-testing-features)

### CI/CD Integration

Tests are automatically run in GitHub Actions:

- **Unit Tests**: Basic functionality and code quality
- **DWH Enhanced Tests**: New dimensions, functions, ETL improvements
- **Integration Tests**: End-to-end workflow validation
- **Performance Tests**: System performance validation
- **Security Tests**: Vulnerability scanning
- **Advanced Tests**: Coverage, quality, advanced functionality

### Test Quality Standards

#### Code Coverage

- **Minimum 85%** code coverage for new features
- **100% coverage** for critical functions
- **Integration testing** for all workflows

#### Test Quality

- **Descriptive test names** that explain the scenario
- **Comprehensive assertions** that validate all aspects
- **Error case testing** for edge cases and failures
- **Performance testing** for time-sensitive operations

#### Documentation

- **Test descriptions** that explain the purpose
- **Setup instructions** for test environment
- **Expected results** clearly documented
- **Troubleshooting guides** for common issues

## File Organization

### Directory Structure Standards

```text
project/
├── bin/                    # Executable scripts
│   ├── process/           # Data processing scripts
│   ├── dwh/              # Data warehouse scripts
│   ├── monitor/          # Monitoring scripts
│   ├── functionsProcess.sh # Shared functions
│   ├── parallelProcessingFunctions.sh # Consolidated parallel processing functions
│   └── consolidatedValidationFunctions.sh # Consolidated validation functions
├── sql/                   # Database scripts
│   ├── process/          # Processing SQL scripts
│   ├── dwh/             # Data warehouse SQL
│   ├── monitor/         # Monitoring SQL
│   └── functionsProcess/ # Function definitions
├── tests/                # Testing infrastructure
│   ├── unit/            # Unit tests
│   ├── integration/     # Integration tests
│   ├── advanced/        # Advanced testing
│   └── fixtures/        # Test data
├── docs/                 # Documentation
├── etc/                  # Configuration
├── xslt/                 # XML transformations
├── xsd/                  # XML schemas
├── overpass/             # Geographic queries
└── sld/                  # Map styling
```

### File Naming Conventions

#### Script Files

- **Main scripts**: `processAPINotes.sh`, `processPlanetNotes.sh`
- **Utility scripts**: `updateCountries.sh`, `cleanupAll.sh`
- **Test scripts**: `test_[component].sh`

#### SQL Files

- **Creation scripts**: `[component]_21_create[Object].sql`
- **Drop scripts**: `[component]_11_drop[Object].sql`
- **Data scripts**: `[component]_31_load[Data].sql`

#### Test Files

- **Unit tests**: `[component].test.bats`
- **Integration tests**: `[feature]_integration.test.bats`
- **SQL tests**: `[component].test.sql`

## Naming Conventions

### Variables

- **Global variables**: `UPPERCASE_WITH_UNDERSCORES`
- **Local variables**: `lowercase_with_underscores`
- **Constants**: `UPPERCASE_WITH_UNDERSCORES`
- **Environment variables**: `UPPERCASE_WITH_UNDERSCORES`

### Functions

- **All functions**: `__function_name_with_underscores`
- **Private functions**: `__private_function_name`
- **Public functions**: `__public_function_name`

### Database Objects

- **Tables**: `lowercase_with_underscores`
- **Columns**: `lowercase_with_underscores`
- **Functions**: `function_name_with_underscores`
- **Procedures**: `procedure_name_with_underscores`

## Consolidated Functions

### Function Consolidation Strategy

The project uses a consolidation strategy to eliminate code duplication and improve maintainability:

#### 1. Parallel Processing Functions (`bin/parallelProcessingFunctions.sh`)

- **Purpose**: Centralizes all XML parallel processing functions
- **Functions**: `__processXmlPartsParallel`, `__splitXmlForParallelSafe`, `__processApiXmlPart`, `__processPlanetXmlPart`
- **Usage**: All scripts that need parallel processing should source this file
- **Fallback**: Legacy scripts maintain compatibility through wrapper functions

#### 2. Validation Functions (`bin/consolidatedValidationFunctions.sh`)

- **Purpose**: Centralizes all validation functions for XML, CSV, coordinates, and databases
- **Functions**: `__validate_xml_with_enhanced_error_handling`, `__validate_csv_structure`, `__validate_coordinates`
- **Usage**: All validation operations should use these consolidated functions
- **Fallback**: Legacy scripts maintain compatibility through wrapper functions

#### 3. Implementation Guidelines

- **New Functions**: Add to appropriate consolidated file rather than duplicating across scripts
- **Legacy Support**: Always provide fallback mechanisms for backward compatibility
- **Testing**: Include tests for both consolidated functions and legacy compatibility

## Documentation

### Required Documentation

1. **Script Headers**: Every script must have a comprehensive header
2. **Function Documentation**: All functions must be documented
3. **README Files**: Each directory should have a README.md
4. **API Documentation**: Document any new APIs or interfaces
5. **Configuration Documentation**: Document configuration options
6. **Consolidated Functions**: Document any new consolidated function files

### Documentation Standards

#### Script Documentation

```bash
# Brief description of what the script does
#
# Detailed explanation of functionality
# * Key feature 1
# * Key feature 2
# * Key feature 3
#
# Usage examples:
# * Example 1
# * Example 2
#
# Error codes:
# 1: Help message
# 241: Library missing
# 242: Invalid argument
#
# Author: [Your Name]
# Version: [YYYY-MM-DD]
```

#### Function Documentation

```bash
# Brief description of what the function does
# Parameters: [list of parameters]
# Returns: [return value description]
# Side effects: [any side effects]
function __function_name {
  # Implementation
}
```

## Quality Assurance

### Pre-Submission Checklist

Before submitting your contribution, ensure:

- [ ] **Code formatting**: Run `shfmt -w -i 1 -sr -bn` on all bash scripts
- [ ] **Linting**: Run `shellcheck -x -o all` on all bash scripts
- [ ] **Tests**: All tests pass (`./tests/run_tests.sh`)
- [ ] **Documentation**: All new code is documented
- [ ] **Error handling**: Proper error codes and handling
- [ ] **Logging**: Appropriate logging levels and messages
- [ ] **Performance**: No performance regressions
- [ ] **Security**: No security vulnerabilities

### Code Quality Tools

#### Required Tools

```bash
# Format bash scripts
shfmt -w -i 1 -sr -bn script.sh

# Lint bash scripts
shellcheck -x -o all script.sh

# Run tests
./tests/run_tests.sh

# Run advanced tests
./tests/advanced/run_advanced_tests.sh
```

#### Quality Standards

- **ShellCheck**: No warnings or errors
- **shfmt**: Consistent formatting
- **Test Coverage**: Minimum 80% coverage
- **Performance**: No significant performance degradation
- **Security**: No security vulnerabilities

## Pull Request Process

### 1. Preparation

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature`
3. **Make your changes following the standards above**
4. **Test thoroughly**: Run all test suites
5. **Update documentation**: Add/update relevant documentation

### 2. Submission

1. **Commit your changes**:

   ```bash
   git add .
   git commit -m "feat: add new feature description"
   ```

2. **Push to your fork**:

   ```bash
   git push origin feature/your-feature
   ```

3. **Create a Pull Request** with:
   - **Clear title**: Describe the feature/fix
   - **Detailed description**: Explain what and why
   - **Test results**: Include test output
   - **Screenshots**: If applicable

### 3. Review Process

1. **Automated checks** must pass
2. **Code review** by maintainers
3. **Test verification** by maintainers
4. **Documentation review** for completeness
5. **Final approval** and merge

### 4. Commit Message Standards

Use conventional commit messages:

```text
type(scope): description

[optional body]

[optional footer]
```

**Types**:

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `chore`: Maintenance tasks

**Examples**:

```text
feat(process): add parallel processing for large datasets
fix(sql): correct country boundary import for Austria
docs(readme): update installation instructions
test(api): add integration tests for new endpoints
```

## Getting Help

### Resources

- **Project README**: Main project documentation
- **Directory READMEs**: Specific component documentation
- **Test Examples**: See existing tests for patterns
- **Code Examples**: Study existing scripts for patterns

### Contact

- **Issues**: Use GitHub Issues for bugs and feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Pull Requests**: For code contributions

### Development Environment

For local development, consider using Docker:

```bash
# Run tests in Docker
./tests/docker/run_integration_tests.sh

# Debug in Docker
./tests/docker/debug_postgres.sh
```

### Local Configuration

To avoid accidentally committing local configuration changes:

```bash
# Tell Git to ignore changes to properties files (local development only)
git update-index --assume-unchanged etc/properties.sh
git update-index --assume-unchanged etc/etl.properties
git update-index --assume-unchanged etc/wms.properties.sh

# Verify that the files are now ignored
git ls-files -v | grep '^[[:lower:]]'

# To re-enable tracking (if needed)
git update-index --no-assume-unchanged etc/properties.sh
git update-index --no-assume-unchanged etc/etl.properties
git update-index --no-assume-unchanged etc/wms.properties.sh
```

This allows you to customize database settings, user names, ETL configurations, or WMS settings without affecting the repository.

## Version Control

### Branch Strategy

- **main**: Production-ready code
- **develop**: Integration branch
- **feature/***: New features
- **bugfix/***: Bug fixes
- **hotfix/***: Critical fixes

### Release Process

1. **Feature complete**: All features implemented and tested
2. **Documentation complete**: All documentation updated
3. **Tests passing**: All test suites pass
4. **Code review**: All changes reviewed
5. **Release**: Tag and release

---

**Thank you for contributing to OSM-Notes-profile!**

Your contributions help make OpenStreetMap notes analysis more accessible and
powerful for the community.
