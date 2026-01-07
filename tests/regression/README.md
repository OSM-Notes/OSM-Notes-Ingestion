# Regression Test Suite

**Purpose:** Prevent regression of historical bugs and issues

**Author:** Andres Gomez (AngocA)  
**Version:** 2025-12-15

## Overview

This directory contains regression tests that document and prevent historical bugs
from reoccurring. Each test is based on a real bug that was fixed in the codebase.

## Test Structure

### Regression Test Suites

The regression tests are organized into multiple test files:

- **`regression_suite_original_bugs.test.bats`** - Original bugs (2025-12-07 to 2025-12-12)
- **`regression_suite_daemon_bugs.test.bats`** - Daemon bugs (2025-12-15)
- **`regression_suite_processing_bugs.test.bats`** - Processing bugs (2025-12-14)
- **`regression_suite_api_bugs.test.bats`** - Critical API bugs (2025-12-13)

Comprehensive regression test suite covering 25 historical bugs:

**Original Bugs (2025-12-07 to 2025-12-12):**
1. **Failed Boundaries Extraction** - False positives from timestamps
2. **Capital Validation** - Incorrect coordinates handling
3. **Empty Import Table** - GeoJSON without Polygon features
4. **SRID Handling** - Inconsistent SRID usage
5. **verifyNoteIntegrity** - Inefficient spatial index usage
6. **Output Redirection** - Incorrect redirection in processAPINotes.sh
7. **Checksum Validation** - Incorrect library references
8. **SQL Insertion for Null Island** - Invalid SQL syntax
9. **Boundary Processing** - Missing geometry field detection
10. **Taiwan Special Handling** - Problematic tags removal
11. **API URL Missing Date Filter** - Incorrect API endpoint without date filtering
12. **Timestamp Format with Literal HH24** - Malformed timestamps in SQL queries

**Daemon Bugs (2025-12-15):**
13. **Syntax Error in Daemon Gap Detection** - NOTE_COUNT with newlines causing arithmetic errors
14. **Daemon Initialization with Empty Database** - Daemon failed to start with empty DB
15. **API Table Creation Errors with Empty Database** - Enum errors when creating API tables before base tables
16. **OSM API Version Detection Fix** - Daemon failed to detect API version

**Processing Bugs (2025-12-14):**
17. **API Tables Not Being Cleaned** - Data accumulation between daemon cycles
18. **pgrep False Positives** - Incorrect process detection in daemon startup check
19. **rmdir Failure on Non-Empty Directories** - Cleanup failures in processPlanetNotes.sh
20. **local Keyword Usage in Trap Handlers** - "local: can only be used in a function" error
21. **VACUUM ANALYZE Timeout** - Timeout too short for large tables (7GB+)
22. **Integrity Check Handling for Databases Without Comments** - False positives when no comments exist

**Critical API Bugs (2025-12-13):**
23. **API Timeout Insufficient for Large Downloads** - 30s timeout insufficient for 10,000 notes
24. **Missing Processing Functions in Daemon** - Functions not loaded when daemon sourced
25. **app.integrity_check_passed Variable Not Persisting** - Variable didn't persist between psql connections

## New Unit Tests

**`tests/unit/bash/processAPIFunctions_api_url.test.bats`** - Comprehensive unit tests for API URL construction and timestamp format validation:

- Tests API URL endpoint correctness (`/notes/search.xml` vs `/notes?limit=`)
- Tests URL parameter inclusion (`limit`, `closed`, `sort`, `from`)
- Tests timestamp format validation (ISO 8601, no literal "HH24")
- Tests timestamp URL-safety
- Tests database timestamp retrieval
- Tests error handling for empty timestamps
- Tests MAX_NOTES variable usage

## Bug Documentation

Each test includes:
- **Bug Description**: What the bug was
- **Fix Applied**: How it was fixed
- **Commit Reference**: Related commit hash
- **Date**: When the bug was fixed
- **Reference**: Link to documentation or analysis

## Running Regression Tests

```bash
# Run all regression tests
bats tests/regression/regression_suite_original_bugs.test.bats
bats tests/regression/regression_suite_daemon_bugs.test.bats
bats tests/regression/regression_suite_processing_bugs.test.bats
bats tests/regression/regression_suite_api_bugs.test.bats

# Run with verbose output
bats -v tests/regression/regression_suite_original_bugs.test.bats
bats -v tests/regression/regression_suite_daemon_bugs.test.bats
bats -v tests/regression/regression_suite_processing_bugs.test.bats
bats -v tests/regression/regression_suite_api_bugs.test.bats
```

## Adding New Regression Tests

When fixing a bug, add a regression test to prevent it from reoccurring:

1. **Document the bug** in the test comment:
   ```bash
   # =============================================================================
   # Bug #N: Brief Description
   # =============================================================================
   # Bug: Detailed description of what was wrong
   # Fix: How it was fixed
   # Commit: commit_hash
   # Date: YYYY-MM-DD
   # Reference: docs/SomeDocument.md
   ```

2. **Write the test** to verify the fix:
   ```bash
   @test "REGRESSION: Brief description of what should not happen" {
     # Test that verifies the bug is fixed
   }
   ```

3. **Ensure the test passes** with the current code

4. **Update this README** with the new bug entry

## Bug Sources

Bugs are identified from:
- Git commit messages with "fix", "bug", "error"
- Documentation files (e.g., `docs/Failed_Boundaries_Analysis.md`)
- Code comments with TODO/FIXME/BUG markers
- Historical analysis documents

## Notes

- Tests use `skip` when dependencies are missing (e.g., SQL files that may have
  been refactored)
- Tests focus on behavior, not implementation details
- Tests should remain stable even if code is refactored

