# Regression Test Suite

**Purpose:** Prevent regression of historical bugs and issues

**Author:** Andres Gomez (AngocA)  
**Version:** 2025-12-08

## Overview

This directory contains regression tests that document and prevent historical bugs
from reoccurring. Each test is based on a real bug that was fixed in the codebase.

## Test Structure

### `regression_suite.test.bats`

Comprehensive regression test suite covering 10 historical bugs:

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
bats tests/regression/regression_suite.test.bats

# Run with verbose output
bats -v tests/regression/regression_suite.test.bats
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

