# Testing Suites Reference - OSM-Notes-profile

## Overview

This document provides a comprehensive reference of all BATS testing suites in the OSM-Notes-profile project. The project contains **78 total testing suites** organized into different categories for comprehensive coverage of all system components, including the new DWH enhanced features.

## 📊 Testing Suites Statistics

- **Total BATS Suites**: 78
- **Integration Suites**: 8
- **Unit Bash Suites**: 68
- **Unit SQL Suites**: 4 (including DWH enhanced)
- **Consolidated Test Runners**: 10 (including DWH enhanced)

## 🚀 Consolidated Test Runners (10 scripts)

The project has been simplified from 36 redundant test runners to 10 consolidated scripts:

### Primary Test Runners

#### 1. `run_tests.sh` - Master Test Runner

- **Purpose**: Consolidated master test runner with multiple modes
- **Modes**: host, mock, docker, ci
- **Test Types**: all, unit, integration, quality, dwh
- **Usage**: `./run_tests.sh --mode host --type all`

#### 2. `run_tests_simple.sh` - Simple Test Runner

- **Purpose**: Simplified test runner for host system
- **Features**: No Docker required, basic validation
- **Usage**: `./run_tests_simple.sh`

#### 3. `run_quality_tests.sh` - Quality Tests Runner

- **Purpose**: Consolidated quality testing with multiple modes
- **Modes**: basic, enhanced, all
- **Features**: Format, naming, validation tests
- **Usage**: `./run_quality_tests.sh --mode enhanced`

#### 4. `run_logging_validation_tests.sh` - Logging Pattern Validation Tests

- **Purpose**: Dedicated logging pattern compliance validation
- **Modes**: unit, integration, all
- **Features**: Logging pattern validation, script validation, BATS tests
- **Usage**: `./tests/run_logging_validation_tests.sh --mode all`

#### 4. `run_dwh_tests.sh` - DWH Enhanced Tests Runner

- **Purpose**: Dedicated DWH enhanced testing
- **Features**: New dimensions, functions, ETL improvements
- **Test Types**: SQL unit tests, integration tests
- **Usage**: `./run_dwh_tests.sh`

### Specialized Test Runners

#### 5. `run_all_tests.sh` - Legacy All Tests Runner

- **Purpose**: Legacy runner for backward compatibility
- **Features**: Runs all test suites including DWH enhanced
- **Usage**: `./run_all_tests.sh`

#### 6. `run_integration_tests.sh` - Integration Tests

- **Purpose**: Focused integration testing
- **Features**: End-to-end workflows, DWH enhanced integration
- **Usage**: `./run_integration_tests.sh`

#### 7. `run_mock_tests.sh` - Mock Environment Tests

- **Purpose**: Tests without real database
- **Features**: Mock commands and environment
- **Usage**: `./run_mock_tests.sh`

#### 8. `run_error_handling_tests.sh` - Error Handling Tests

- **Purpose**: Focused error handling validation
- **Features**: Edge cases and error scenarios
- **Usage**: `./run_error_handling_tests.sh`

#### 9. `run_xml_xslt_tests.sh` - XML/XSLT Tests

- **Purpose**: XML processing and XSLT transformation tests
- **Features**: Data transformation validation
- **Usage**: `./run_xml_xslt_tests.sh`

#### 10. `run_manual_tests.sh` - Manual Tests

- **Purpose**: Manual testing scenarios
- **Features**: Interactive testing
- **Usage**: `./run_manual_tests.sh`

## 🔗 Integration Test Suites (9 suites)

Integration tests validate complete workflows and system interactions:

### 1. boundary_processing_error_integration.test.bats

- **Purpose**: Tests error handling in boundary processing workflows
- **Coverage**: Geographic boundary processing, error scenarios, Taiwan boundary fixes
- **Key Tests**:
  - QUERY_FILE variable validation
  - Invalid boundary ID detection
  - Error message patterns
  - Complete error handling chain

### 2. end_to_end.test.bats

- **Purpose**: Complete workflow testing from data ingestion to output
- **Coverage**: Full system integration, data processing pipelines
- **Key Tests**:
  - API notes processing workflow
  - Planet notes processing workflow
  - Large XML file handling

### 3. ETL_enhanced_integration.test.bats

- **Purpose**: DWH enhanced ETL functionality testing
- **Coverage**: New dimensions, functions, SCD2, bridge tables
- **Key Tests**:
  - Enhanced dimensions validation
  - SCD2 implementation validation
  - New functions validation
  - Staging procedures validation
  - Datamart compatibility
  - Bridge table implementation
  - Documentation consistency

### 4. datamart_enhanced_integration.test.bats

- **Purpose**: Datamart enhanced functionality testing
- **Coverage**: Datamart compatibility with new dimensions
- **Key Tests**:
  - DatamartUsers enhanced functionality
  - DatamartCountries enhanced functionality
  - Enhanced dimensions integration
  - SCD2 integration
  - Bridge table integration
  - Application version integration
  - Season integration
  - Script execution validation
  - Enhanced columns validation
  - Documentation consistency

## ⚡ Unit Test Suites - Bash (68 suites)

### 📋 Validation and Verification (15 suites)

#### Data Validation

- **api_download_verification.test.bats** - API download verification and validation
- **boundary_validation.test.bats** - Geographic boundary validation
- **centralized_validation.test.bats** - Centralized validation functions
- **checksum_validation.test.bats** - File checksum validation
- **input_validation.test.bats** - Input data validation

#### Date and Time Validation

- **date_validation.test.bats** - Date format validation
- **date_validation_integration.test.bats** - Date validation integration
- **date_validation_utc.test.bats** - UTC date validation

#### SQL and Database Validation

- **sql_constraints_validation.test.bats** - SQL constraint validation
- **sql_validation_integration.test.bats** - SQL validation integration

#### XML Validation

- **xml_validation_enhanced.test.bats** - Enhanced XML validation
- **xml_validation_functions.test.bats** - XML validation functions
- **xml_validation_large_files.test.bats** - Large file XML validation
- **xml_validation_simple.test.bats** - Simple XML validation

#### Extended Validation

- **extended_validation.test.bats** - Extended validation scenarios

### 🔄 Processing and Transformation (5 suites)

- **csv_enum_validation.test.bats** - CSV enum validation
- **xml_processing_enhanced.test.bats** - Enhanced XML processing
- **xslt_csv_format.test.bats** - XSLT CSV format validation
- **xslt_enum_validation.test.bats** - XSLT enum validation
- **xslt_simple.test.bats** - Simple XSLT transformations

### 🗄️ Database and ETL (6 suites)

- **database_variables.test.bats** - Database variable management
- **datamartCountries_integration.test.bats** - Countries datamart integration
- **datamartUsers_integration.test.bats** - Users datamart integration
- **ETL_enhanced.test.bats** - Enhanced ETL functionality
- **ETL_integration.test.bats** - ETL integration testing
- **profile_integration.test.bats** - Data profiling integration

### 🔧 Functions and Scripts (8 suites)

- **bash_logger_enhanced.test.bats** - Enhanced bash logging
- **cleanupAll.test.bats** - Complete cleanup functionality
- **cleanupAll_integration.test.bats** - Cleanup integration testing
- **cleanup_behavior.test.bats** - Cleanup behavior validation
- **cleanup_behavior_simple.test.bats** - Simple cleanup behavior
- **functionsProcess.test.bats** - Process functions testing
- **functionsProcess_enhanced.test.bats** - Enhanced process functions
- **function_naming_convention.test.bats** - Function naming conventions

### 🚀 Parallel Processing and Performance (6 suites)

- **parallel_failed_file.test.bats** - Parallel processing failure handling
- **parallel_processing_validation.test.bats** - Parallel processing validation
- **parallel_threshold.test.bats** - Parallel processing thresholds
- **performance_edge_cases.test.bats** - Performance edge cases
- **performance_edge_cases_quick.test.bats** - Quick performance tests
- **performance_edge_cases_simple.test.bats** - Simple performance tests

### 🎯 Note Processing (7 suites)

- **processAPINotes.test.bats** - API notes processing
- **processAPINotes_error_handling_improved.test.bats** - Improved error handling
- **processAPINotes_integration.test.bats** - API processing integration
- **processAPINotes_parallel_error.test.bats** - Parallel error handling
- **processCheckPlanetNotes_integration.test.bats** - Planet notes verification
- **processPlanetNotes.test.bats** - Planet notes processing
- **processPlanetNotes_integration.test.bats** - Planet processing integration

### 🔍 Monitoring and Verification (2 suites)

- **monitoring.test.bats** - System monitoring functionality
- **notesCheckVerifier_integration.test.bats** - Notes verification integration

### 🛠️ Tools and Utilities (11 suites)

- **edge_cases_integration.test.bats** - Edge cases integration
- **error_handling.test.bats** - Error handling functionality
- **error_handling_enhanced.test.bats** - Enhanced error handling
- **error_handling.test.bats** - Consolidated error handling tests
- **format_and_lint.test.bats** - Code formatting and linting
- **hybrid_integration.test.bats** - Hybrid environment integration
- **logging_improvements.test.bats** - Logging improvements
- **prerequisites_enhanced.test.bats** - Enhanced prerequisites checking
- **real_data_integration.test.bats** - Real data integration
- **script_execution_integration.test.bats** - Script execution integration
- **script_help_validation.test.bats** - Script help validation

### 🌐 WMS and Web Services (3 suites)

- **wmsConfigExample_integration.test.bats** - WMS configuration examples
- **wmsManager.test.bats** - WMS manager functionality
- **wmsManager_integration.test.bats** - WMS manager integration

### 📝 Logging Pattern Validation (1 suite)

- **logging_pattern_validation_integration.test.bats** - Logging pattern validation integration

### 📊 Variables and Configuration (4 suites)

- **updateCountries_integration.test.bats** - Country updates integration
- **variable_duplication.test.bats** - Variable duplication detection
- **variable_duplication_detection.test.bats** - Variable duplication detection
- **variable_naming_convention.test.bats** - Variable naming conventions

## 🗄️ Unit Test Suites - SQL (2 suites)

- **functions.test.sql** - Database functions testing
- **tables.test.sql** - Database tables testing

## 🎯 Test Coverage Analysis

### Functional Coverage

1. **Data Processing** (25 suites)
   - XML/CSV processing and validation
   - ETL workflows and data transformation
   - Parallel processing and performance

2. **System Integration** (15 suites)
   - Database operations and connectivity
   - API integration and external services
   - WMS and web services

3. **Quality Assurance** (20 suites)
   - Code quality and conventions
   - Error handling and edge cases
   - Validation and verification

4. **Infrastructure** (14 suites)
   - Monitoring and verification
   - Configuration management
   - Tools and utilities

### Technical Coverage

- **Bash Scripts**: 100% coverage of all main scripts
- **SQL Functions**: Complete function testing
- **XML Processing**: Comprehensive validation
- **Error Handling**: All error scenarios covered
- **Performance**: Edge cases and optimization
- **Integration**: End-to-end workflows

## 🚀 Usage Guidelines

### Running Tests with Consolidated Runners

```bash
# Master test runner with different modes
./tests/run_tests.sh --mode host --type all                    # Host system
./tests/run_tests.sh --mode mock --type unit                   # Mock environment
./tests/run_tests.sh --mode docker --type integration          # Docker environment
./tests/run_tests.sh --mode ci --type all                      # CI/CD environment

# Quality tests with different modes
./tests/run_quality_tests.sh --mode basic                      # Basic quality checks
./tests/run_quality_tests.sh --mode enhanced                   # Enhanced quality checks
./tests/run_quality_tests.sh --format-only                     # Only formatting tests
./tests/run_quality_tests.sh --naming-only                     # Only naming tests

# Specialized test runners
./tests/run_tests_simple.sh                                    # Simple tests (no Docker)
./tests/run_integration_tests.sh                               # Integration tests
./tests/run_mock_tests.sh                                      # Mock environment tests
./tests/run_error_handling_tests.sh                            # Error handling tests
./tests/run_xml_xslt_tests.sh                                  # XML/XSLT tests
```

### Running Specific Test Categories

```bash
# Run all validation tests
find tests/unit/bash -name "*validation*.bats" -exec bats {} \;

# Run all integration tests
bats tests/integration/

# Run all performance tests
find tests/unit/bash -name "*performance*.bats" -exec bats {} \;

# Run all error handling tests
find tests/unit/bash -name "*error*.bats" -exec bats {} \;
```

### Test Environment Setup

```bash
# Setup test database
./tests/setup_test_db.sh

# Install dependencies
./tests/install_dependencies.sh

# Run simple tests (no sudo required)
./tests/run_tests_simple.sh
```

## 📈 Quality Metrics

### Test Statistics

- **Total Test Cases**: 840+ individual tests
- **Coverage Areas**: 15 functional categories
- **Integration Points**: 6 major workflows
- **Error Scenarios**: 50+ edge cases
- **Performance Tests**: 20+ scenarios
- **Consolidated Runners**: 9 (reduced from 36)

### Success Criteria

- All tests must pass before merging
- Code coverage > 90% for critical components
- Integration tests must complete successfully
- Performance tests must meet thresholds
- Quality tests must pass all checks

## 🔄 Maintenance

### Adding New Tests

1. Follow naming conventions: `[component].test.bats`
2. Include comprehensive test cases
3. Add to appropriate category
4. Update this documentation
5. Ensure CI/CD integration

### Updating Tests

1. Maintain backward compatibility
2. Update documentation
3. Verify CI/CD pipeline
4. Test in multiple environments

## 📚 Related Documentation

- [Testing Guide](./Testing_Guide.md) - General testing guidelines
- [Testing Workflows Overview](./Testing_Workflows_Overview.md) - CI/CD workflows
- [CI/CD Integration](./CI_CD_Integration.md) - Continuous integration
- [Input Validation](./Input_Validation.md) - Validation strategies

---

*Last updated: 2025-01-27*
*Total suites documented: 74*
*Consolidated runners: 9 (reduced from 36)*
