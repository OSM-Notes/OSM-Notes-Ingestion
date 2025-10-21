# Test Matrix - OSM Notes Ingestion

**Version:** 2025-10-14  
**Author:** Andres Gomez (AngocA)

## Summary Table - Execution Types

| Execution Type | Requirements | Scripts | Description |
|----------------|--------------|---------|-------------|
| **Local (Host)** | Local PostgreSQL, BATS, XML tools | `run_all_tests.sh --mode host` | Direct execution on host system |
| **Docker** | Docker, Docker Compose | `run_all_tests.sh --mode docker` | Execution in isolated containers |
| **GitHub Actions** | GitHub repository, configured workflows | `.github/workflows/*.yml` | Automatic CI/CD execution |
| **Mock** | BATS, mock commands | `run_all_tests.sh --mode mock` | Execution without external dependencies |

---

## Main Matrix - Test Suites by Execution Type

### Coverage Summary

| Test Suite | Files | Tests | Local | Docker | GitHub | Mock | Estimated Time |
|------------|-------|-------|-------|--------|--------|------|----------------|
| **Unit Tests (Bash)** | 86 | ~946 | ✅ | ✅ | ✅ | ✅ | 15-30 min |
| **Unit Tests (SQL)** | 6 | ~120 | ✅ | ✅ | ✅ | ❌ | 5-10 min |
| **Integration Tests** | 8 | 68 | ✅ | ✅ | ✅ | ⚠️ | 10-20 min |
| **Parallel Processing** | 1 | 21 | ✅ | ✅ | ✅ | ✅ | 5-10 min |
| **Advanced - Coverage** | - | - | ✅ | ✅ | ✅ | ❌ | 10-15 min |
| **Advanced - Security** | - | - | ✅ | ✅ | ✅ | ✅ | 3-5 min |
| **Advanced - Quality** | - | - | ✅ | ✅ | ✅ | ✅ | 5-10 min |
| **Advanced - Performance** | - | - | ✅ | ✅ | ✅ | ⚠️ | 5-10 min |
| **Docker Integration** | 15+ | varies | ❌ | ✅ | ✅ | ❌ | 10-20 min |
| **WMS Tests** | 3 | ~20 | ✅ | ✅ | ✅ | ⚠️ | 5-8 min |
| **TOTAL** | **123+** | **~1,255+** | - | - | - | - | **81-158 min** |

**Legend:**

- ✅ Fully supported
- ⚠️ Partially supported (requires additional configuration)
- ❌ Not supported in this environment

**Note:** DWH Enhanced tests were moved to OSM-Notes-Analytics repository

---

## Unit Test Suite Details (Bash)

### Unit Test Categories

| Category | Files | Approx. Tests | Description |
|----------|-------|---------------|-------------|
| **ProcessAPI** | 7 | ~85 | Incremental API processing |
| **ProcessPlanet** | 6 | ~75 | Complete Planet dump processing |
| **Parallel Processing** | 6 | ~68 | Parallel processing and optimization |
| **XML Processing** | 9 | ~95 | XML validation and AWK extraction |
| **Validation** | 12 | ~140 | Data validation (coordinates, dates, etc.) |
| **Error Handling** | 8 | ~82 | Error handling and recovery |
| **Cleanup** | 7 | ~60 | Cleanup and maintenance |
| **WMS** | 3 | ~28 | Web Map Service integration |
| **Monitoring** | 5 | ~48 | Monitoring and verification |
| **Database** | 4 | ~50 | Database variables and functions |
| **Integration** | 10 | ~115 | Script integration tests |
| **Quality & Format** | 9 | ~100 | Code quality and formatting |
| **TOTAL** | **86** | **~946** | |

### Top 20 Unit Test Suites (by test count)

| # | File | Tests | Category | Priority |
|---|------|-------|----------|----------|
| 1 | `bash_logger_enhanced.test.bats` | 18 | Logging | High |
| 2 | `cleanupAll_integration.test.bats` | 16 | Cleanup | High |
| 3 | `date_validation.test.bats` | 15 | Validation | High |
| 4 | `database_variables.test.bats` | 15 | Database | Medium |
| 5 | `binary_division_performance.test.bats` | 14 | Performance | Medium |
| 6 | `coordinate_validation_enhanced.test.bats` | 11 | Validation | High |
| 7 | `centralized_validation.test.bats` | 10 | Validation | High |
| 8 | `cleanupAll.test.bats` | 10 | Cleanup | High |
| 9 | `checksum_validation.test.bats` | 9 | Validation | Medium |
| 10 | `csv_enum_validation.test.bats` | 9 | CSV/AWK | High |
| 11 | `date_validation_integration.test.bats` | 8 | Validation | High |
| 12 | `boundary_validation.test.bats` | 7 | Validation | Medium |
| 13 | `cleanup_order.test.bats` | 7 | Cleanup | Medium |
| 14 | `api_download_verification.test.bats` | 6 | ProcessAPI | High |
| 15 | `clean_flag_handling.test.bats` | 6 | Cleanup | Medium |
| 16 | `clean_flag_exit_trap.test.bats` | 5 | Cleanup | Medium |
| 17 | `clean_flag_simple.test.bats` | 5 | Cleanup | Medium |
| 18 | `cleanup_behavior.test.bats` | 5 | Cleanup | Medium |
| 19 | `cleanup_dependency_fix.test.bats` | 4 | Cleanup | Medium |
| 20 | `cleanup_behavior_simple.test.bats` | 3 | Cleanup | Medium |

---

## Integration Test Suite Details

| # | File | Tests | Description | Components |
|---|------|-------|-------------|------------|
| 1 | `boundary_processing_error_integration.test.bats` | 16 | Boundary processing with errors | ProcessPlanet, Boundaries |
| 2 | `wms_integration.test.bats` | 10 | WMS integration | WMS, GeoServer |
| 3 | `logging_pattern_validation_integration.test.bats` | 9 | Logging pattern validation | Logging, Validation |
| 4 | `mock_planet_processing.test.bats` | 8 | Planet processing with mocks | ProcessPlanet, Mock |
| 5 | `processAPINotes_parallel_error_integration.test.bats` | 7 | ProcessAPI with parallel errors | ProcessAPI, Parallel |
| 6 | `end_to_end.test.bats` | 6 | Complete ingestion flow | Full workflow |
| 7 | `processAPI_historical_e2e.test.bats` | 5 | ProcessAPI with historical data | ProcessAPI, Historical |
| **TOTAL** | **8** | **68** | | |

---

## Execution Matrix - Commands by Type

### Local Execution (Host)

```bash
# All tests
./tests/run_all_tests.sh --mode host --type all

# Unit tests only
./tests/run_all_tests.sh --mode host --type unit

# Integration tests only
./tests/run_all_tests.sh --mode host --type integration

# Quality tests only
./tests/run_all_tests.sh --mode host --type quality
```

**Requirements:**

- PostgreSQL installed and running
- User `postgres` or `notes` with permissions
- BATS installed
- xmllint (optional, for XML validation)
- shellcheck, shfmt

**Estimated time:** 84-163 minutes for all tests

---

### Docker Execution

```bash
# All tests
./tests/run_all_tests.sh --mode docker --type all

# Unit tests only
./tests/run_all_tests.sh --mode docker --type unit

# Integration tests only
./tests/run_all_tests.sh --mode docker --type integration
```

**Requirements:**

- Docker installed
- Docker Compose installed
- User in `docker` group (or use sudo)

**Estimated time:** 90-180 minutes for all tests (includes container setup time)

---

### Mock Execution (Without Database)

```bash
# All tests
./tests/run_all_tests.sh --mode mock --type all

# Unit tests only
./tests/run_all_tests.sh --mode mock --type unit

# Integration tests only (limited)
./tests/run_all_tests.sh --mode mock --type integration
```

**Requirements:**

- BATS installed
- Mock commands in `tests/mock_commands/`

**Estimated time:** 30-60 minutes (not all tests are compatible)

---

### CI/CD Execution (GitHub Actions)

```bash
# Push to main/develop triggers automatically
git push origin main

# Or manually from GitHub UI:
# Actions → Tests → Run workflow
```

**Available workflows:**

- `tests.yml` - Complete test suite
- `integration-tests.yml` - Integration tests
- `quality-tests.yml` - Quality tests

**Estimated time:** 77-116 minutes (complete workflow)

---

## Feature Compatibility Matrix

| Feature | Local | Docker | GitHub | Mock |
|---------|-------|--------|--------|------|
| **Database tests** | ✅ | ✅ | ✅ | ❌ |
| **AWK extraction** | ✅ | ✅ | ✅ | ✅ |
| **Parallel processing** | ✅ | ✅ | ✅ | ✅ |
| **WMS integration** | ✅ | ✅ | ✅ | ⚠️ |
| **Coverage reports** | ✅ | ✅ | ✅ | ❌ |
| **Security scans** | ✅ | ✅ | ✅ | ✅ |
| **Performance tests** | ✅ | ✅ | ⚠️ | ⚠️ |
| **Large file tests** | ✅ | ✅ | ❌ | ❌ |
| **End-to-end tests** | ✅ | ✅ | ✅ | ⚠️ |

---

## Usage Recommendations

### For Local Development

```bash
# Quick check before commit
./tests/run_tests_sequential.sh quick

# Complete verification
./tests/run_tests_sequential.sh full
```

### For Continuous Integration

```bash
# On GitHub Actions (automatic)
# Runs tests.yml on each push/PR

# For local CI debugging
./tests/run_all_tests.sh --mode docker --type all
```

### For Specific Feature Testing

```bash
# Testing ProcessAPI
bats tests/unit/bash/processAPINotes*.bats

# Testing ProcessPlanet
bats tests/unit/bash/processPlanetNotes*.bats

# Testing Parallel Processing
bats tests/parallel_processing_test_suite.bats
```

---

## Coverage Metrics

### Coverage by Component

| Component | Tests | Estimated Coverage |
|-----------|-------|--------------------|
| **ProcessAPI** | ~85 | 85-90% |
| **ProcessPlanet** | ~75 | 80-85% |
| **AWK Extraction** | ~20 | 85-90% |
| **Parallel Processing** | ~68 | 85-90% |
| **Validation** | ~140 | 80-85% |
| **Cleanup** | ~60 | 75-80% |
| **WMS** | ~28 | 70-75% |
| **Error Handling** | ~82 | 80-85% |
| **Database** | ~50 | 75-80% |

### Global Coverage

- **Total Tests:** ~1,290+
- **Estimated Code Coverage:** 80-85%
- **Function Coverage:** 85-90%
- **Error Case Coverage:** 75-80%

---

## Troubleshooting

### Common Issues by Execution Type

#### Local

```bash
# PostgreSQL not accessible
sudo systemctl start postgresql

# User without permissions
sudo -u postgres createuser -s $USER

# BATS not found
sudo apt-get install bats
```

#### Docker

```bash
# Docker not available
sudo apt-get install docker.io docker-compose

# Insufficient permissions
sudo usermod -aG docker $USER
# (logout/login required)

# Containers don't start
cd tests/docker
docker compose down -v
docker compose up -d --build
```

#### Mock

```bash
# Mock commands not executable
chmod +x tests/mock_commands/*

# Missing environment variables
source tests/properties.sh
```

#### GitHub Actions

```bash
# Workflow doesn't run
# - Verify Actions permissions in Settings
# - Verify YAML syntax
# - Check logs in Actions tab
```

---

## Additional Resources

### Documentation

- [Testing Guide](Testing_Guide.md) - Complete testing guide
- [Testing Workflows Overview](Testing_Workflows_Overview.md) - Workflow descriptions
- [Testing Suites Reference](Testing_Suites_Reference.md) - Suite reference
- [CI Troubleshooting](CI_Troubleshooting.md) - CI/CD troubleshooting

### Utility Scripts

- `tests/setup_ci_environment.sh` - CI environment setup
- `tests/verify_ci_environment.sh` - Environment verification
- `tests/install_shfmt.sh` - shfmt installation
- `tests/setup_mock_environment.sh` - Mock environment setup

---

## Conclusions

### Executive Summary

- **Total Suites:** 128+ test files
- **Total Tests:** ~1,290+ individual tests
- **Execution Types:** 4 (Local, Docker, GitHub, Mock)
- **Categories:** 12+ test categories
- **Total Time:** 84-163 minutes (local), 77-116 minutes (CI)
- **Coverage:** 80-85% of code

### Next Steps

1. Execute complete matrix locally before each release
2. Monitor execution times in CI/CD
3. Expand performance test coverage
4. Add more large file tests in Docker
5. Improve Mock mode compatibility

---

**Last update:** 2025-10-14  
**Maintainer:** Andres Gomez (AngocA)
