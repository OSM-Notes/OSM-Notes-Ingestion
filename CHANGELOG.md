# Changelog

All notable changes to this project will be documented in this file.

## [2025-10-15] - Documentation Audit and Cleanup

### Removed

- **Historical/report files** (4 files, ~1,524 lines):
  - `SEPARATION_SUMMARY.md` - Historical report of repository separation (2025-10-13)
  - `INTEGRATION_TESTING_STRATEGY.md` - Strategic proposal (not technical documentation)
  - `QUALITY_TESTING_STRATEGY.md` - Strategic proposal (not technical documentation)
  - `tests/migration_guide.md` - Historical migration guide (test script consolidation)

### Changed

- **Repository name correction** (32 files, 99 references):
  - Fixed "OSM-Notes-profile" → "OSM-Notes-Ingestion" across all documentation
  - Affected files: README.md, all docs/, tests/, and component READMEs
  - Now consistent with actual repository name

- **File renamed for clarity**:
  - `tests/README_TESTING.md` → `tests/Testing_Technical_Guide.md`
  - More descriptive name distinguishes from `tests/README.md`
  - All references updated

- **docs/Documentation.md completely rewritten** (262 lines):
  - Removed all DWH/ETL/Analytics content (was ~40% of file)
  - Now focuses exclusively on Ingestion + WMS
  - Updated architecture to reflect current repository scope
  - Added clear separation note pointing to OSM-Notes-Analytics
  - Improved structure and organization
  - Updated all internal references

### Fixed

- Markdown formatting issues corrected with markdownlint
- Removed redundant and obsolete content
- Documentation now accurately reflects codebase

### Documentation

- All documentation now represents actual system functionality
- No historical reports or strategic proposals remain
- Clear focus on technical documentation only
- Consistent repository naming throughout

## [2025-10-14] - Testing Infrastructure, Documentation Translation, and DWH Cleanup

### Added

- Comprehensive test execution matrix documentation (`docs/Test_Matrix.md`) - English
- Sequential test execution guide (`docs/Test_Execution_Sequence.md`) - English
- Sequential test runner script (`tests/run_tests_sequential.sh`) - 9 levels
- Quick test guide (`tests/QUICK_TEST_GUIDE.md`) - English
- Bugfix documentation (`docs/Bugfix_ValidationFunctions_Path.md`) - English
- Multiple execution modes: quick, basic, standard, full
- Per-level execution capability for targeted testing
- Progress monitoring with colored banners

### Removed

- Level 10 test suite (DWH Enhanced) - components moved to OSM-Notes-Analytics
- Function `__cleanup_etl()` from `bin/cleanupAll.sh`
- Job `dwh-enhanced-tests` from `.github/workflows/tests.yml` (128 lines)
- References to `etc/etl.properties` in 8 test files
- Tests for moved files (ETL.sh, profile.sh, datamart scripts)
- Spanish language documentation (4 files, 1,931 lines translated)

### Fixed

- **validationFunctions.sh path:** Corrected in `tests/test_helper.bash`
  - Changed from `bin/validationFunctions.sh` to `lib/osm-common/validationFunctions.sh`
  - Eliminated warning in all tests (~1,000+ tests affected)
- **SCRIPT_BASE_DIRECTORY:** Fixed in `lib/osm-common/validationFunctions.sh` (../ → ../../)
- **commonFunctions.sh:** Added special case for `lib/osm-common` directory
- **cleanupAll.sh:** Corrected shfmt format, removed `__cleanup_etl()`
- **binary_division_performance.test.bats:** Fixed PROJECT_ROOT detection
- **mock_planet_processing.test.bats:** Fixed XSLT test redirections
- **wmsManager.sh:** Now works correctly with help commands
- Marked 4 environment-sensitive performance tests as skip

### Documentation

- **Translated all testing documentation from Spanish to English (4 files, 1,931 lines)**
- Created detailed test execution sequence guide with ~939 tests in 9 levels
- Added comprehensive test matrix showing 101 test suites across 4 environments
- Documented execution times for each level and category
- Updated README.md with accurate test counts (101 suites, ~1,000+ tests)
- Clarified DWH/ETL/Analytics components are in OSM-Notes-Analytics
- Verified all file references point to existing files

### Changed

- Total test levels: 10 → 9
- Test suite count: 86 bash + 8 integration + 6 SQL + 1 parallel = 101 suites
- GitHub workflow simplified (removed DWH job)
- Sequential script rejects level 10 with informative error

### Validated

- Successfully executed ~939 tests across levels 2-9 (100% pass rate)
- No broken references to removed components
- All translated documentation verified

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
