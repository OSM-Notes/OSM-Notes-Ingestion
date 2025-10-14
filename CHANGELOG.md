# Changelog

All notable changes to this project will be documented in this file.

## [2025-10-14] - Testing Infrastructure Improvements

### Added

- Comprehensive test execution matrix documentation (`docs/Test_Matrix.md`)
- Sequential test execution guide (`docs/Test_Execution_Sequence.md`)
- Sequential test runner script (`tests/run_tests_sequential.sh`)
- Quick test guide (`tests/QUICK_TEST_GUIDE.md`)
- 10 test execution levels organized by priority and complexity
- Multiple execution modes: quick, basic, standard, full
- Per-level execution capability for targeted testing

### Fixed

- Corrected path to `validationFunctions.sh` in `tests/test_helper.bash`
- Warning message "validationFunctions.sh not found" no longer appears in all tests
- Path changed from `bin/validationFunctions.sh` to `lib/osm-common/validationFunctions.sh`
- Improved error message to indicate correct location

### Documentation

- Created detailed test execution sequence guide with ~1,290+ tests organized in 10 levels
- Added test matrix showing all 128+ test suites across 4 execution environments
- Documented execution times for each level and test category
- Added troubleshooting section for common test execution issues

## [2025-08-07] - XML Validation Enhancement

### Added

- Enhanced XML validation functions for handling large files efficiently
- `__validate_xml_with_enhanced_error_handling`: Main validation function with automatic strategy selection
- `__validate_xml_basic`: Basic XML structure validation without schema
- `__validate_xml_structure_only`: Lightweight structure validation for very large files
- Automatic file size detection and validation strategy selection
- Memory-efficient validation for files > 1GB

### Changed

- Simplified XML validation logic by removing duplicate functions
- Replaced direct `xmllint` calls with enhanced validation functions
- Updated validation strategy based on file size:
  - Small files (< 500MB): Standard validation with schema
  - Large files (500MB - 1GB): Basic validation without schema
  - Very large files (> 1GB): Structure-only validation
- Removed `__validate_xml_in_batches` and `__validate_xml_structure_alternative` functions
- Updated all tests to use new validation functions

### Fixed

- Memory issues with large XML files (> 2GB)
- Out of memory errors during XML validation
- Duplicate validation logic in processPlanet and processAPI flows
- Inconsistent validation behavior across different file sizes

### Removed

- `__validatePlanetNotesXMLFile` (duplicate function)
- `__validateApiNotesXMLFile` (duplicate function)
- `__validate_xml_in_batches` (replaced with enhanced functions)
- `__validate_xml_structure_alternative` (replaced with enhanced functions)

### Testing

- Updated all XML validation tests to use new functions
- Added comprehensive tests for different file sizes
- Updated integration tests for processPlanet and processAPI
- Added performance tests for large file handling
- Updated documentation for XML validation testing

## [Previous versions...]
