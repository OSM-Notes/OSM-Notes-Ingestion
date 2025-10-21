# GitHub Actions Workflows

## Overview

This directory contains the CI/CD pipeline for OSM-Notes-Ingestion.

## Workflows

### `ci.yml` - Consolidated CI/CD Pipeline

**Main workflow** that handles all continuous integration and testing.

#### Triggers

- **Push**: Runs on pushes to `main` and `develop` branches
- **Pull Request**: Runs on PRs targeting `main` and `develop`
- **Schedule**: Runs daily at 2:00 AM UTC (full test suite)
- **Manual**: Can be triggered manually via workflow_dispatch

#### Pipeline Stages

1. **Quick Checks** (always runs - ~2-3 min)
   - Shellcheck static analysis
   - Code formatting validation (shfmt)
   - Common code issues detection

2. **Unit Tests** (always runs - ~5-7 min)
   - BATS unit tests for all bash scripts
   - PostgreSQL-based tests
   - Validates all core functionality

3. **Integration Tests - Quick** (runs on PRs - ~5-8 min)
   - Critical integration tests only
   - Fast feedback for pull requests
   - Tests: processAPINotes, cleanupAll, processPlanetNotes

4. **Integration Tests - Full** (runs on main/develop/schedule - ~10-15 min)
   - Complete integration test suite
   - All test categories: process-api, process-planet, cleanup, wms
   - End-to-end workflow validation

5. **Security Scan** (always runs - ~2-3 min)
   - Security vulnerability checks
   - Hardcoded credentials detection
   - File permissions validation

6. **Performance Tests** (schedule/manual only - ~5-10 min)
   - Performance benchmarks
   - Resource usage analysis
   - Only runs on scheduled builds or manual trigger

#### Execution Matrix

| Event | Quick Checks | Unit Tests | Integration Quick | Integration Full | Security | Performance |
|-------|--------------|------------|-------------------|------------------|----------|-------------|
| PR | ✅ | ✅ | ✅ | ❌ | ✅ | ❌ |
| Push to main | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| Push to develop | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ |
| Schedule (daily) | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |
| Manual (full) | ✅ | ✅ | ❌ | ✅ | ✅ | ✅ |

#### Benefits of Consolidation

**Before (3 separate workflows):**
- Total jobs per push: 12 (6 + 5 + 1)
- Estimated time: ~35-45 minutes
- Redundant test execution (3x integration, 2x shellcheck, 2x unit)

**After (1 consolidated workflow):**
- Total jobs per PR: 5 (quick-checks, unit-tests, integration-quick, security-scan, summary)
- Total jobs per push to main/develop: 6 (adds integration-full)
- Estimated time for PR: ~15-20 minutes
- Estimated time for main/develop: ~25-30 minutes
- No redundancy

**Time savings:**
- PRs: ~50% faster
- Main/develop pushes: ~30% faster
- Scheduled runs: Full coverage with performance tests

#### Manual Execution

To run the full test suite manually:

1. Go to Actions tab in GitHub
2. Select "CI/CD Pipeline"
3. Click "Run workflow"
4. Select branch
5. Set "Run full test suite" to `true`
6. Click "Run workflow"

## Artifacts

All workflows generate artifacts that are retained for 7 days:

- `unit-test-results`: Unit test logs and results
- `integration-test-results-quick`: Quick integration test results
- `integration-test-results-full`: Full integration test results
- `performance-test-results`: Performance benchmarks

## Maintenance

### Adding New Tests

1. Add BATS test files to `tests/unit/bash/` or `tests/integration/`
2. Update test runner scripts if needed
3. Tests will automatically be picked up by the CI pipeline

### Modifying Pipeline

Edit `.github/workflows/ci.yml` to:
- Add new stages
- Modify conditional execution
- Update dependencies
- Change trigger conditions

### Debugging Failed Builds

1. Check the specific job that failed
2. Download artifacts for detailed logs
3. Run tests locally: `./tests/run_integration_tests.sh`
4. Check test output in `tests/results/`

## Migration Notes

This consolidated workflow replaced three previous workflows:
- `tests.yml` - Comprehensive test suite (deprecated 2025-10-21)
- `quality-tests.yml` - Quality and integration tests (deprecated 2025-10-21)
- `integration-tests.yml` - Scheduled integration tests (deprecated 2025-10-21)

All functionality from these workflows has been merged into `ci.yml` with:
- Eliminated redundancy
- Faster execution
- Better conditional logic
- Single file to maintain
