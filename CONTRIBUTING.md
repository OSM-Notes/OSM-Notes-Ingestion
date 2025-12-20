# Contributing to OSM-Notes-Ingestion

Thank you for your interest in contributing to the OSM-Notes-Ingestion project!
This document provides comprehensive guidelines for contributing to this
OpenStreetMap notes analysis system.

## Table of Contents

- [Project Context](#project-context)
- [System Architecture Overview](#system-architecture-overview)
- [Types of Contributions](#types-of-contributions)
- [Code Standards](#code-standards)
- [Development Workflow](#development-workflow)
- [Testing Requirements](#testing-requirements)
- [File Organization](#file-organization)
- [Naming Conventions](#naming-conventions)
- [Documentation](#documentation)
- [Quality Assurance](#quality-assurance)
- [Pull Request Process](#pull-request-process)

## Project Context

### What is OSM-Notes-Ingestion?

OSM-Notes-Ingestion is a data ingestion system for OpenStreetMap notes. It:

- **Downloads** notes from OSM API (real-time) and Planet dumps (historical)
- **Processes** XML data using AWK for fast, memory-efficient extraction
- **Stores** processed data in PostgreSQL/PostGIS database
- **Monitors** data quality and synchronization

> **Note:** Analytics, ETL, and Data Warehouse components are maintained separately in [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

### Key Design Principles

1. **Separation of Concerns**: API and Planet processing are separate scripts, optimized for their specific use cases
2. **Performance**: AWK-based processing for speed, parallel processing for large datasets
3. **Reliability**: Comprehensive error handling, retry logic, and monitoring
4. **Maintainability**: Modular design, shared libraries, comprehensive testing

### Essential Documentation

Before contributing, familiarize yourself with:

#### Core Documentation

- **[README.md](../README.md)**: Project overview and quick start
- **[docs/Documentation.md](../docs/Documentation.md)**: Complete system architecture and technical details
- **[docs/Rationale.md](../docs/Rationale.md)**: Project motivation and design decisions
- **[docs/Component_Dependencies.md](../docs/Component_Dependencies.md)**: Component dependencies and interactions
- **[docs/Troubleshooting_Guide.md](../docs/Troubleshooting_Guide.md)**: Centralized troubleshooting guide with error codes

#### Processing Documentation

- **[docs/Process_API.md](../docs/Process_API.md)**: API processing implementation details, sequence diagrams, and troubleshooting
- **[docs/Process_Planet.md](../docs/Process_Planet.md)**: Planet processing implementation details, sequence diagrams, and troubleshooting
- **[docs/Country_Assignment_2D_Grid.md](../docs/Country_Assignment_2D_Grid.md)**: Country assignment algorithm and spatial processing
- **[docs/Capital_Validation_Explanation.md](../docs/Capital_Validation_Explanation.md)**: Capital location validation mechanism
- **[docs/ST_DWithin_Explanation.md](../docs/ST_DWithin_Explanation.md)**: Spatial distance queries explanation

#### Script Reference

- **[bin/README.md](../bin/README.md)**: Script usage examples, common use cases, and reference
- **[bin/ENTRY_POINTS.md](../bin/ENTRY_POINTS.md)**: Which scripts can be called directly
- **[bin/ENVIRONMENT_VARIABLES.md](../bin/ENVIRONMENT_VARIABLES.md)**: Environment variable documentation

#### Testing Documentation

- **[tests/README.md](../tests/README.md)**: Testing infrastructure overview
- **[tests/CONTRIBUTING_TESTS.md](../tests/CONTRIBUTING_TESTS.md)**: Guide for
  contributing tests (test structure, inline comments, fixtures, mocking)
- **[tests/fixtures/README.md](../tests/fixtures/README.md)**: Test fixtures
  and sample data documentation
- **[docs/Testing_Guide.md](../docs/Testing_Guide.md)**: Comprehensive testing guide
- **[docs/Testing_Suites_Reference.md](../docs/Testing_Suites_Reference.md)**: Complete test suite reference

## System Architecture Overview

### High-Level Architecture

```text
┌─────────────────────────────────────────────────────────────────────┐
│                    OSM-Notes-Ingestion System                        │
└─────────────────────────────────────────────────────────────────────┘

Data Sources:
    ├─▶ OSM Notes API (real-time, every 15 minutes)
    ├─▶ OSM Planet Dumps (historical, daily)
    └─▶ Overpass API (geographic boundaries)

Processing Layer:
    ├─▶ processAPINotes.sh (incremental updates)
    ├─▶ processPlanetNotes.sh (bulk processing)
    └─▶ updateCountries.sh (boundary updates)

Storage Layer:
    └─▶ PostgreSQL/PostGIS Database
        ├─▶ Base tables (notes, comments, countries)
        └─▶ Temporary tables (sync, API partitions)

Output:
    └─▶ Analytics (external repository)

For **WMS (Web Map Service)**, see the
[OSM-Notes-WMS](https://github.com/OSMLatam/OSM-Notes-WMS) repository.
```

### Core Components

#### 1. Processing Scripts (`bin/process/`)

- **`processAPINotes.sh`**: Processes incremental updates from OSM API
  - Runs every 15 minutes (cron)
  - Handles up to 10,000 notes per run
  - Automatically triggers Planet sync if threshold exceeded
  - See [docs/Process_API.md](../docs/Process_API.md) for details

- **`processPlanetNotes.sh`**: Processes historical data from Planet dumps
  - Base mode: Complete setup from scratch
  - Sync mode: Incremental updates
  - See [docs/Process_Planet.md](../docs/Process_Planet.md) for details

- **`updateCountries.sh`**: Updates country and maritime boundaries
  - Downloads from Overpass API
  - Re-assigns countries for affected notes
  - See [bin/README.md](../bin/README.md) for usage

#### 2. Function Libraries (`bin/lib/` and `lib/osm-common/`)

- **`bin/lib/`**: Project-specific functions
  - `processAPIFunctions.sh`: API processing functions
  - `processPlanetFunctions.sh`: Planet processing functions
  - `parallelProcessingFunctions.sh`: Parallel processing coordination
  - `boundaryProcessingFunctions.sh`: Geographic boundary processing

- **`lib/osm-common/`**: Shared functions (Git submodule)
  - `commonFunctions.sh`: Core utilities
  - `validationFunctions.sh`: Data validation
  - `errorHandlingFunctions.sh`: Error handling and recovery
  - `bash_logger.sh`: Logging library

#### 3. Database Layer (`sql/`)

- **`sql/process/`**: Processing SQL scripts
- **`sql/monitor/`**: Monitoring queries

#### 4. Data Transformation (`awk/`)

- AWK scripts for XML to CSV conversion
- Optimized for large files and parallel processing

### Data Flow

1. **API Processing Flow**:
   ```
   OSM API → XML Download → AWK Extraction → CSV → Database (API tables) → Base tables
   ```

2. **Planet Processing Flow**:
   ```
   Planet Dump → Extract XML → Split → Parallel AWK → CSV → Database (Sync tables) → Base tables
   ```

For **WMS (Web Map Service) flow**, see the
[OSM-Notes-WMS](https://github.com/OSMLatam/OSM-Notes-WMS) repository.

For detailed flow diagrams, see [docs/Documentation.md](../docs/Documentation.md#processing-sequence-diagram).

## Types of Contributions

### Bug Fixes

**When to contribute**: Fixing errors, incorrect behavior, or edge cases.

**Process**:

1. **Identify the issue**:
   - Reproduce the bug consistently
   - Check existing issues on GitHub (avoid duplicates)
   - Review error logs and check failed execution markers (`/tmp/*_failed_execution`)
   - Check error codes: See [docs/Troubleshooting_Guide.md](../docs/Troubleshooting_Guide.md#error-code-reference)

2. **Understand the context**:
   - **System Overview**: Review [docs/Documentation.md](../docs/Documentation.md) for architecture
   - **Component Dependencies**: Check [docs/Component_Dependencies.md](../docs/Component_Dependencies.md) to understand interactions
   - **Processing Details**: 
     - [docs/Process_API.md](../docs/Process_API.md) for API processing bugs
     - [docs/Process_Planet.md](../docs/Process_Planet.md) for Planet processing bugs
   - **Troubleshooting**: Review [docs/Troubleshooting_Guide.md](../docs/Troubleshooting_Guide.md) for common issues and solutions
   - **Spatial Processing**: If related to country assignment, see [docs/Country_Assignment_2D_Grid.md](../docs/Country_Assignment_2D_Grid.md)
   - **Error Codes**: Verify error codes match standards in `lib/osm-common/commonFunctions.sh`

3. **Locate the problematic code**:
   - Check script entry points: [bin/ENTRY_POINTS.md](../bin/ENTRY_POINTS.md)
   - Review function libraries: `bin/lib/` and `lib/osm-common/`
   - Check SQL scripts if database-related: `sql/process/`
   - Review AWK scripts if XML processing: `awk/`

4. **Create a fix**:
   - Follow code standards (see [Code Standards](#code-standards))
   - Use standardized error codes from `lib/osm-common/commonFunctions.sh`
   - Add tests for the bug (prevent regression)
   - Update documentation if behavior changes
   - Update [docs/Troubleshooting_Guide.md](../docs/Troubleshooting_Guide.md) if it's a new error scenario

5. **Test thoroughly**:
   - Run all tests: `./tests/run_all_tests.sh`
   - Run specific test category: `./tests/run_tests.sh --type unit`
   - Test the specific scenario that was broken
   - Verify no regressions: `./tests/run_tests.sh --type all`
   - Check code quality: `./tests/run_quality_tests.sh`

**Example commit message**:
```text
fix(processAPI): correct country assignment for notes on boundaries

Fixes issue where notes exactly on country boundaries were not assigned
to any country. Now uses ST_Contains with proper boundary handling.

Fixes #123
```

### New Features

**When to contribute**: Adding new functionality or capabilities.

**Process**:

1. **Propose the feature**:
   - Open a GitHub issue to discuss (use "Feature Request" template)
   - Explain the use case and benefits
   - Review architecture to understand integration points:
     - [docs/Documentation.md](../docs/Documentation.md) for system architecture
     - [docs/Component_Dependencies.md](../docs/Component_Dependencies.md) for component interactions
     - [docs/Rationale.md](../docs/Rationale.md) for design principles

2. **Design the solution**:
   - **Architecture Review**:
     - [docs/Documentation.md](../docs/Documentation.md) for system architecture and data flows
     - [docs/Component_Dependencies.md](../docs/Component_Dependencies.md) to understand dependencies
   - **Pattern Review**:
     - [bin/README.md](../bin/README.md) for script patterns and examples
     - Existing scripts in `bin/process/`, `bin/monitor/` for patterns
   - **Database Design**:
     - Review existing schema: `sql/process/`
     - Consider spatial queries: [docs/ST_DWithin_Explanation.md](../docs/ST_DWithin_Explanation.md)
     - Plan migrations if schema changes needed
   - **Integration Points**:
     - Check if it affects API processing: [docs/Process_API.md](../docs/Process_API.md)
     - Check if it affects Planet processing: [docs/Process_Planet.md](../docs/Process_Planet.md)
     - For WMS integration, see the [OSM-Notes-WMS](https://github.com/OSMLatam/OSM-Notes-WMS) repository
   - **Error Handling**:
     - Use standardized error codes from `lib/osm-common/commonFunctions.sh`
     - Document new error codes in [docs/Troubleshooting_Guide.md](../docs/Troubleshooting_Guide.md)

3. **Implement the feature**:
   - Follow code standards and patterns (see [Code Standards](#code-standards))
   - Use consolidated functions when possible: `bin/parallelProcessingFunctions.sh`, `bin/consolidatedValidationFunctions.sh`
   - Create comprehensive tests (see [Testing Requirements](#testing-requirements))
   - Update all relevant documentation

4. **Documentation updates**:
   - **Architecture**: Update [docs/Documentation.md](../docs/Documentation.md) if architecture changes
   - **Component Dependencies**: Update [docs/Component_Dependencies.md](../docs/Component_Dependencies.md) if dependencies change
   - **Script Usage**: Update [bin/README.md](../bin/README.md) with examples and use cases
   - **Entry Points**: Update [bin/ENTRY_POINTS.md](../bin/ENTRY_POINTS.md) if adding new scripts
   - **Troubleshooting**: Add new error scenarios to [docs/Troubleshooting_Guide.md](../docs/Troubleshooting_Guide.md)
   - **Processing Docs**: Update [docs/Process_API.md](../docs/Process_API.md) or [docs/Process_Planet.md](../docs/Process_Planet.md) if relevant
   - **Environment Variables**: Update [bin/ENVIRONMENT_VARIABLES.md](../bin/ENVIRONMENT_VARIABLES.md) if adding new variables

**Example commit message**:
```text
feat(monitor): add database performance analysis script

Adds analyzeDatabasePerformance.sh to monitor query performance,
index usage, and provide optimization recommendations.

- Analyzes slow queries
- Reports index utilization
- Suggests optimization strategies

Closes #456
```

### Refactoring

**When to contribute**: Improving code structure without changing functionality.

**Process**:

1. **Identify refactoring opportunity**:
   - Code duplication (consolidate into shared functions)
   - Performance improvements (parallel processing, optimization)
   - Better error handling (standardize error codes)
   - Improved maintainability (better organization, documentation)

2. **Review existing patterns**:
   - **Component Interactions**: Check [docs/Documentation.md](../docs/Documentation.md) and [docs/Component_Dependencies.md](../docs/Component_Dependencies.md)
   - **Consolidated Functions**: Review [CONTRIBUTING.md#consolidated-functions](#consolidated-functions)
     - `bin/parallelProcessingFunctions.sh`: Parallel processing functions
     - `bin/consolidatedValidationFunctions.sh`: Validation functions
   - **Shared Libraries**: Understand `lib/osm-common/` structure
   - **Error Codes**: Ensure consistency with `lib/osm-common/commonFunctions.sh`
   - **Script Patterns**: Review existing scripts for established patterns

3. **Plan the refactoring**:
   - **Functionality Preservation**: Ensure no functionality changes
   - **Backward Compatibility**: Maintain compatibility with existing scripts
   - **Test Impact**: Consider impact on existing tests
   - **Documentation**: Plan documentation updates
   - **Error Handling**: Maintain or improve error handling

4. **Execute carefully**:
   - Make incremental changes (one function/script at a time)
   - Run tests after each change: `./tests/run_tests.sh --type unit`
   - Verify behavior is unchanged: `./tests/run_all_tests.sh`
   - Update documentation if patterns change
   - Update [docs/Component_Dependencies.md](../docs/Component_Dependencies.md) if dependencies change

**Example commit message**:
```text
refactor(parallel): consolidate XML splitting functions

Consolidates XML splitting logic from multiple scripts into
parallelProcessingFunctions.sh to eliminate duplication and improve
maintainability.

- Moves __splitXmlForParallelAPI to shared library
- Updates all scripts to use consolidated function
- Maintains backward compatibility
```

### Documentation Improvements

**When to contribute**: Improving clarity, adding examples, fixing errors.

**Process**:

1. **Identify documentation gaps**:
   - Missing examples
   - Unclear explanations
   - Outdated information
   - Broken links

2. **Review existing documentation**:
   - [docs/README.md](../docs/README.md) for documentation structure
   - Check related documents for consistency

3. **Make improvements**:
   - Add examples and use cases
   - Clarify complex concepts
   - Fix errors and update outdated info
   - Add cross-references

**Example commit message**:
```text
docs(processAPI): add troubleshooting examples for common errors

Adds detailed troubleshooting examples for:
- Network connectivity issues
- Database connection failures
- Memory problems during processing

Improves developer experience when debugging issues.
```

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
- **Function files**: `functionsProcess_21_createFunctionToGetCountry.sql`
- **Drop files**: `processAPINotes_12_dropApiTables.sql`

> **Note:** ETL files are maintained in [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

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

# Install XML validation tools (optional, only if SKIP_XML_VALIDATION=false)
sudo apt-get install libxml2-utils

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
- **`awk/`**: AWK extraction scripts (XML to CSV conversion)
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

All contributions must include comprehensive testing. The project uses **BATS testing suites** covering all system components.

> **Note:** DWH/ETL tests are maintained in [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

### Test Categories

#### Unit Tests (72 suites)

- **Bash Scripts**: 68 BATS test suites for shell scripts
- **SQL Functions**: SQL test suites

> **Note:** DWH/ETL tests are maintained in [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

#### Integration Tests (8 suites)

- **End-to-End Workflows**: Complete system integration testing

#### Validation Tests

- **Data Validation**: XML/CSV processing and validation
- **Error Handling**: Edge cases, error conditions
- **Performance**: Parallel processing, optimization

#### Quality Tests

- **Code Quality**: Linting, formatting, conventions
- **Security**: Vulnerability scanning, best practices

> **Note:** DWH/ETL testing requirements are maintained in [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

### Running Tests

#### Complete Test Suite

```bash
# Run all tests (recommended)
./tests/run_all_tests.sh

# Run specific test categories
./tests/run_tests.sh --type unit
./tests/run_tests.sh --type integration
```

#### Individual Test Categories

```bash
# Unit tests
bats tests/unit/bash/*.bats
bats tests/unit/sql/*.sql

# Integration tests
bats tests/integration/*.bats

> **Note:** DWH/ETL tests are maintained in [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).
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

> **Note:** DWH/ETL testing documentation is maintained in [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

### CI/CD Integration

Tests are automatically run in GitHub Actions:

- **Unit Tests**: Basic functionality and code quality
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
├── awk/                  # AWK extraction scripts
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

### Documentation Strategy

**Principle:** Detailed documentation in Markdown (docs/) + Concise comments in code with cross-references.

- **Markdown (docs/)**: Large concepts, architecture, complete workflows, design decisions, extensive guides
- **Code Comments**: Pointed references to documentation, implementation-specific explanations, parameters, returns, minimal examples

**Rule of Thumb:** If it requires more than 2-3 lines to explain, it goes in Markdown with a reference from the code.

### Required Documentation

1. **Script Headers**: Every script must have a comprehensive header following the standard format
2. **Function Documentation**: All functions must be documented following the standard format
3. **README Files**: Each directory should have a README.md
4. **API Documentation**: Document any new APIs or interfaces
5. **Configuration Documentation**: Document configuration options
6. **Consolidated Functions**: Document any new consolidated function files

### Documentation Standards

#### Script Header Standard (Bash)

**Principle:** Concise header with references to detailed documentation in Markdown.

**Standard Format:**

```bash
#!/bin/bash

# <Descriptive title>
# <Brief purpose description - 1-2 lines maximum>
#
# For detailed documentation, see:
#   - docs/<main_document>.md (architecture, complete workflows)
#   - docs/<specific_document>.md (if applicable)
#   - bin/README.md (usage examples, parameters)
#
# Quick Reference:
#   Usage: ./<script_name>.sh [options]
#   Examples: export LOG_LEVEL=DEBUG ; ./<script_name>.sh
#
# Error Codes: See docs/Troubleshooting_Guide.md for complete list
#   1) Help message displayed
#   238) Previous execution failed
#   <other codes> (see docs/Troubleshooting_Guide.md for details)
#
# Dependencies: <brief list>
#
# For contributing: shellcheck -x -o all <script> && shfmt -w -i 1 -sr -bn <script>
#
# Author: Andres Gomez (AngocA)
# Version: YYYY-MM-DD
VERSION="YYYY-MM-DD"
```

**Real Example:**

```bash
#!/bin/bash

# Process API Notes - Incremental synchronization from OSM Notes API
# Downloads, processes, and synchronizes new/updated notes from OSM API
#
# For detailed documentation, see:
#   - docs/Process_API.md (complete workflow, architecture, troubleshooting)
#   - docs/Documentation.md (system overview, data flow)
#   - bin/README.md (usage examples, parameters)
#
# Quick Reference:
#   Usage: ./processAPINotes.sh [--help]
#   Examples: export LOG_LEVEL=DEBUG ; ./processAPINotes.sh
#
# Error Codes: See docs/Troubleshooting_Guide.md for complete list
#   1) Help message displayed
#   238) Previous execution failed
#   241) Library or utility missing
#
# Dependencies: PostgreSQL, AWK, curl, lib/osm-common/
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-08
VERSION="2025-12-08"
```

#### Function Header Standard (Bash)

**Principle:** Concise header with parameters, returns, and reference to detailed documentation.

**Standard Format:**

```bash
# <Descriptive title>
# <Brief description - 1 line>
#
# Parameters:
#   $1: <name> - <brief description> [required/optional]
#   $2: <name> - <brief description> [required/optional]
#
# Returns:
#   0: Success
#   1: Error - <brief description>
#
# Side Effects: <brief list if applicable>
#
# Examples:
#   __function_name "param1" "param2"
#
# Related: docs/<document>.md (detailed explanation, strategy, examples)
# Related Functions: __related_function()
function __function_name() {
  # Implementation
}
```

**Real Example:**

```bash
# Check system resources before launching new processes
# Validates memory usage and system load to prevent system overload
#
# Parameters:
#   $1: Mode (optional, "minimal" for reduced requirements) [optional]
#
# Returns:
#   0: Resources available
#   1: Resources not available (high memory or load)
#
# Examples:
#   if __check_system_resources; then
#     echo "System ready"
#   fi
#
# Related: docs/Documentation.md#parallel-processing (resource management)
function __check_system_resources() {
  # Implementation
}
```

#### Function/Procedure Header Standard (SQL)

**Principle:** Concise header with reference to detailed documentation in Markdown.

**Standard Format:**

```sql
-- <Descriptive title>
-- <Brief description - 1-2 lines>
--
-- Parameters:
--   param1 <type>: <brief description> [required/optional]
--   param2 <type>: <brief description> [required/optional]
--
-- Returns:
--   <type>: <brief description>
--   NULL: <when returns NULL>
--
-- Exceptions: <brief list>
--
-- Strategy: See docs/<document>.md for complete algorithm
--   - <summary of main steps>
--
-- Performance: See docs/<document>.md#performance
--   - <key metrics>
--
-- Examples:
--   SELECT get_country(-74.006, 40.7128, 12345);
--
-- Related: docs/<document>.md (detailed explanation, examples, troubleshooting)
-- Related Functions: <other_function>()
CREATE OR REPLACE FUNCTION function_name(...)
```

**Real Example:**

```sql
-- Get country assignment for a note using 2D grid optimization
-- Determines which country a note belongs to based on coordinates
--
-- Parameters:
--   lon DECIMAL: Note longitude [required]
--   lat DECIMAL: Note latitude [required]
--   id_note INTEGER: Note ID for optimization [required]
--
-- Returns:
--   INTEGER: Country ID, or -1 for international waters
--   NULL: Never (always returns INTEGER)
--
-- Exceptions: None (uses RETURN, not RAISE)
--
-- Strategy: See docs/Country_Assignment_2D_Grid.md for complete algorithm
--   1. Check current country first (95% hit rate when updating boundaries)
--   2. Use 2D grid (24 zones) to select relevant countries
--   3. Search terrestrial countries before maritime zones
--
-- Performance: See docs/Country_Assignment_2D_Grid.md#performance
--   - Average: <1ms per note
--   - Optimized for boundary updates (checks current country first)
--
-- Examples:
--   SELECT get_country(-74.006, 40.7128, 12345);
--
-- Related: docs/Country_Assignment_2D_Grid.md (complete strategy, examples)
-- Related Functions: insert_note() (calls this function)
CREATE OR REPLACE FUNCTION get_country(...)
```

#### Inline Comments Standard

**Principle:** If it requires more than 2-3 lines, move it to Markdown with a reference.

**Guidelines:**

1. **Pointed and concise comments:**
   - Explain "what" and "why" in 1-2 lines maximum
   - Reference documentation for extensive explanations
   - Code should be self-explanatory

2. **Comments for specific implementation:**
   - Non-obvious optimizations (with reference to docs if complex)
   - Workarounds for known bugs
   - Edge cases specific to the code

3. **References to documentation:**
   - For complex algorithms: "See docs/X.md for algorithm details"
   - For strategies: "See docs/X.md#strategy for complete strategy"
   - For troubleshooting: "See docs/Troubleshooting_Guide.md#issue"

**Format:**

```bash
# OPTIMIZATION: <brief explanation> (see docs/X.md for details)
# FIXME: <known issue> (see docs/X.md#known-issues)
# TODO: <future improvement> (see ToDo/X.md)
# NOTE: <important note> (see docs/X.md for context)
# WARNING: <brief warning> (see docs/X.md#warnings for details)
```

**Real Example:**

```sql
-- OPTIMIZATION: Check current country first (95% hit rate when updating boundaries)
-- See docs/Country_Assignment_2D_Grid.md#optimization for strategy details
IF m_current_country IS NOT NULL AND m_current_country > 0 THEN
  ...
END IF;

-- Determine geographic zone using 2D grid (lon AND lat)
-- See docs/Country_Assignment_2D_Grid.md#zones for complete zone definitions
IF (-5 < lat AND lat < 4.53 AND 4 > lon AND lon > -4) THEN
  m_area := 'Null Island';
  ...
END IF;
```

### Important Notes

- **Functions do NOT include Author/Version**: Only main scripts (executable files) include author and version
- **Keep headers concise**: Detailed explanations belong in Markdown documentation
- **Always reference documentation**: For complex concepts, algorithms, or strategies
- **Update documentation when code changes**: Keep code comments and Markdown docs in sync

### How to Document Changes

When making changes, update documentation as follows:

#### Script Changes

1. **Update Script Header**:
   - Update version date to current date (YYYY-MM-DD)
   - Add new examples if functionality changes
   - Update error codes list if adding new errors
   - Update function descriptions if behavior changes

2. **Update bin/README.md**:
   - Add usage examples for new scripts
   - Update examples if behavior changes
   - Add new error codes to exit codes section
   - Update "Common Use Cases" if applicable

3. **Update bin/ENTRY_POINTS.md**:
   - Add entry point if creating new executable script
   - Document parameters and options

#### Architecture Changes

1. **Update docs/Documentation.md**:
   - Update architecture diagrams if components change
   - Add new sequence diagrams for new processes
   - Update data flow descriptions

2. **Update docs/Component_Dependencies.md**:
   - Add new dependencies if components interact differently
   - Update dependency diagrams

#### Error Handling Changes

1. **Update docs/Troubleshooting_Guide.md**:
   - Add new error scenarios with diagnosis and solutions
   - Update error code reference table
   - Add new error codes to script-specific sections

2. **Update lib/osm-common/commonFunctions.sh**:
   - Add new error code constants if needed
   - Document error code meanings

#### Processing Changes

1. **Update docs/Process_API.md** or **docs/Process_Planet.md**:
   - Update sequence diagrams if flow changes
   - Add new troubleshooting cases
   - Update code examples if API changes

2. **Update docs/Country_Assignment_2D_Grid.md**:
   - Document changes to country assignment algorithm
   - Update spatial processing explanations

#### Environment Variable Changes

1. **Update bin/ENVIRONMENT_VARIABLES.md**:
   - Document new environment variables
   - Update descriptions if behavior changes
   - Add examples of usage

#### Testing Changes

1. **Update tests/README.md**:
   - Document new test suites
   - Update test execution instructions

2. **Update docs/Testing_Guide.md**:
   - Add new test scenarios
   - Update test execution examples

#### Documentation Checklist

Before submitting, verify:

- [ ] Script headers updated with current date
- [ ] bin/README.md updated with examples (if script changes)
- [ ] docs/Troubleshooting_Guide.md updated (if error handling changes)
- [ ] docs/Documentation.md updated (if architecture changes)
- [ ] docs/Component_Dependencies.md updated (if dependencies change)
- [ ] Relevant processing docs updated (Process_API.md or Process_Planet.md)
- [ ] Cross-references verified and updated
- [ ] All links in documentation work correctly

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

1. **Commit your changes** (use conventional commits):

   ```bash
   # Format: <type>(<scope>): <subject>
   git add .
   git commit -m "feat(processAPI): add new feature description"
   
   # Common types:
   # feat: New feature
   # fix: Bug fix
   # docs: Documentation changes
   # refactor: Code refactoring
   # test: Adding tests
   # chore: Maintenance tasks
   ```

2. **Push to your fork**:

   ```bash
   git push origin feature/your-feature
   ```

3. **Create a Pull Request** with:
   - **Clear title**: Use conventional commit format: `type(scope): description`
   - **Detailed description**: 
     - Explain what and why
     - Reference related issues: `Fixes #123` or `Closes #456`
     - List changes made
     - Document any breaking changes
   - **Test results**: Include test output showing all tests pass
   - **Documentation**: List documentation files updated
   - **Screenshots**: If applicable (for UI or visualization changes)
   - **Checklist**: Mark completed items from pre-submission checklist

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

# Verify that the files are now ignored
git ls-files -v | grep '^[[:lower:]]'

# To re-enable tracking (if needed)
git update-index --no-assume-unchanged etc/properties.sh
```

This allows you to customize database settings or user names without affecting the repository.

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

**Thank you for contributing to OSM-Notes-Ingestion!**

Your contributions help make OpenStreetMap notes analysis more accessible and
powerful for the community.
