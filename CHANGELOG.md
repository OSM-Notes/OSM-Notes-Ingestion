# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

#### Country Assignment Bug Fix (2026-01-19)

- **Fixed ambiguous return value in `get_country()` function**:
  - **Issue**: Function returned `-1` for both known international waters and unknown countries, causing notes in countries like Brazil, Venezuela, Chile, etc. to be incorrectly marked as international waters
  - **Root Cause**: Function initialized `m_id_country := -1` and returned `COALESCE(m_id_country, -1)`, meaning unknown countries were marked as international waters
  - **Fix**: 
    - Changed initialization to `m_id_country := -2` for unknown countries
    - Reserved `-1` ONLY for known international waters (from `international_waters` table)
    - Introduced `-2` for unknown/not found countries
    - Added `ST_Intersects` fallback for points on country boundaries
    - Normalized SRID to 4326 for all geometries
  - **Implementation**:
    - Updated `sql/functionsProcess_21_createFunctionToGetCountry.sql` to use `-2` for unknown countries
    - Updated all code references from `id_country = -1` to `id_country < 0` to handle both `-1` and `-2`
    - Enhanced function to use `ST_Intersects` as fallback when `ST_Contains` fails (handles points on edges)
  - **Impact**:
    - Notes in valid countries are now correctly assigned (no longer marked as international waters)
    - Clear distinction between international waters (`-1`) and unknown countries (`-2`)
    - Better handling of points on country boundaries
    - Improved geometry validation with explicit SRID normalization
  - **Files changed**:
    - `sql/functionsProcess_21_createFunctionToGetCountry.sql` (core function fix)
    - `bin/lib/noteProcessingFunctions.sh` (6 occurrences updated)
    - `sql/functionsProcess_32_loadsBackupNoteLocation.sql`
    - `sql/functionsProcess_35_assignCountryToNotesChunk.sql`
    - `sql/functionsProcess_37_assignCountryToNotesChunk.sql`
    - `docs/Country_Assignment_2D_Grid.md` (documentation update)
  - **New tests added**:
    - `tests/unit/sql/get_country_return_values.test.sql` (validates return value semantics)
    - `tests/unit/sql/get_country_partial_failures.test.sql` (detects partial failures)
    - `tests/unit/bash/get_country_return_values.test.bats` (BATS integration tests)
    - `tests/setup_test_countries_for_get_country.sh` (automatic test data setup)

---

## [2026-01-26] - Recent Updates and Improvements

### Added

- **CI/CD Testing Infrastructure**: Added local CI testing scripts and improved test workflows
- **Test Infrastructure**: Enhanced test setup with PostGIS extension support and improved test country configuration

### Changed

- **Documentation**: Comprehensive documentation updates including standardized links, metadata sections, and Mermaid diagrams
- **Code Quality**: Standardized code formatting, improved error handling, and enhanced logging
- **Processing Logic**: Enhanced boundary processing, API notes processing, and country update workflows

### Fixed

- **Error Handling**: Improved error handling and validation across multiple processing scripts
- **Country Assignment**: Enhanced country assignment logic and boundary validation

---
