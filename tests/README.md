# Tests Directory

## Overview
The `tests` directory contains comprehensive testing infrastructure for the OSM-Notes-profile system. It includes unit tests, integration tests, performance tests, and quality assurance tools to ensure the reliability and correctness of the entire system.

## Directory Structure

### `/tests/unit/`
Unit tests for individual components:
- **`bash/`**: BATS (Bash Automated Testing System) tests for shell scripts
- **`sql/`**: Database function and table tests

### `/tests/integration/`
End-to-end integration tests:
- **`end_to_end.test.bats`**: Complete workflow testing from data ingestion to output

### `/tests/docker/`
Containerized testing environment:
- **`docker-compose.yml`**: Docker environment setup
- **`run_integration_tests.sh`**: Integration tests in Docker
- **`test_*.sh`**: Individual component tests

### `/tests/advanced/`
Advanced testing and quality tools:
- **`coverage/`**: Code coverage analysis
- **`security/`**: Security scanning tools
- **`performance/`**: Performance testing
- **`quality/`**: Code quality checks

### `/tests/scripts/`
Test automation scripts:
- **`test_special_cases.sh`**: Tests for edge cases and special scenarios
- **`run_advanced_tests.sh`**: Advanced test orchestration

### `/tests/fixtures/`
Test data and sample files:
- **`sample_data.sql`**: Database test data
- **`special_cases/`**: Edge case test scenarios

## Software Components

### Testing Framework
- **BATS**: Bash Automated Testing System for shell script testing
- **Docker**: Containerized testing environment
- **Coverage Tools**: Code coverage analysis
- **Quality Tools**: Linting and formatting checks

### Test Categories
- **Unit Tests**: Individual function and component testing
- **Integration Tests**: End-to-end workflow testing
- **Performance Tests**: System performance validation
- **Security Tests**: Vulnerability scanning
- **Quality Tests**: Code quality and style validation

### Test Data
- **Sample Data**: Representative datasets for testing
- **Edge Cases**: Special scenarios and error conditions
- **Mock Data**: Simulated data for isolated testing

## Usage
Tests can be run individually or as part of the complete test suite:
- `./tests/run_tests_simple.sh`: Basic test suite
- `./tests/run_enhanced_tests.sh`: Enhanced test suite
- `./tests/run_tests.sh`: Complete test suite
- `./tests/advanced/run_advanced_tests.sh`: Advanced quality tests

## Dependencies
- BATS testing framework
- Docker and docker-compose
- PostgreSQL test database
- Various testing tools (shellcheck, shfmt, etc.) 

# Test Configuration and Standardized Values

## Overview

This document describes the standardized configuration values used across all test environments in the OSM-Notes-profile project. **Test properties are completely separate from production properties** to maintain clear boundaries between environments.

## Test Properties vs Production Properties

### Test Properties (`tests/properties.sh`)
- **Purpose**: Configuration for all test environments
- **Scope**: Unit tests, integration tests, CI/CD tests
- **Values**: Conservative, safe defaults for testing
- **Independence**: Completely separate from production

### Production Properties (`etc/properties.sh`)
- **Purpose**: Configuration for production environments
- **Scope**: Live data processing, production deployments
- **Values**: Optimized for performance and reliability
- **Independence**: No test-specific values

## Test Properties Configuration

### Database Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `TEST_DBNAME` | `osm_notes_test` | Test database name |
| `TEST_DBUSER` | `testuser` (Docker) / `postgres` (Host) | Database user |
| `TEST_DBPASSWORD` | `testpass` (Docker) / `` (Host) | Database password |
| `TEST_DBHOST` | `postgres` (Docker) / `localhost` (Host) | Database host |
| `TEST_DBPORT` | `5432` | Database port |

### Timeout Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `TEST_TIMEOUT` | `300` (5 minutes) | General test timeout |
| `PERFORMANCE_TIMEOUT` | `60` (1 minute) | Performance test timeout |
| `MOCK_API_TIMEOUT` | `30` (30 seconds) | Mock API timeout |
| `CI_TIMEOUT` | `600` (10 minutes) | CI/CD timeout |
| `DOCKER_TIMEOUT` | `300` (5 minutes) | Docker operations timeout |
| `VALIDATION_TIMEOUT` | `60` (1 minute) | Validation test timeout |

### Retry Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `TEST_RETRIES` | `3` | Standard retry count |
| `MAX_RETRIES` | `30` | Maximum retries for service startup |
| `RETRY_INTERVAL` | `2` | Seconds between retries |
| `CI_MAX_RETRIES` | `20` | CI environment retries |
| `DOCKER_MAX_RETRIES` | `10` | Docker-specific retries |
| `VALIDATION_RETRIES` | `3` | Validation retries |

### Threading Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `MAX_THREADS` | `2` | Conservative threading for tests |
| `CI_MAX_THREADS` | `2` | Conservative threading for CI |
| `PARALLEL_THREADS` | `2` | Conservative parallel processing |
| `PARALLEL_ENABLED` | `false` | Enable parallel processing |

### Memory Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `MEMORY_LIMIT_MB` | `100` | Memory limit for tests |

## Environment-Specific Configuration

### Docker Environment
- Uses `testuser`/`testpass` credentials
- Connects to `postgres` host
- Conservative threading (2 threads)
- Extended timeouts for container startup

### Host Environment
- Uses `postgres` user with no password
- Connects to `localhost`
- Conservative threading (2 threads)
- Standard timeouts

### CI/CD Environment
- Extended timeouts (10 minutes)
- More retries (20 attempts)
- Conservative threading (2 threads)
- Enhanced logging and error reporting

## Usage

### Loading Test Properties

All test scripts automatically load the test properties:

```bash
# Load test properties
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/properties.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/properties.sh"
fi
```

### Overriding Test Values

You can override any test value by setting environment variables:

```bash
# Override timeout for specific test
export TEST_TIMEOUT=600
bash tests/run_tests_simple.sh

# Override threading for performance test
export MAX_THREADS=4
bash tests/run_enhanced_tests.sh --parallel
```

### Production vs Test Values

The system uses different default values for production and test environments:

| Configuration | Production | Test |
|---------------|------------|------|
| `MAX_THREADS` | `4-16` (based on cores) | `2` |
| `MEMORY_LIMIT_MB` | `512` | `100` |
| `TEST_TIMEOUT` | `600` | `300` |
| `MAX_RETRIES` | `30` | `30` |

## Benefits of Separation

1. **Clear Boundaries**: Test and production configurations are completely separate
2. **Safety**: Test values cannot accidentally affect production
3. **Maintainability**: Each environment has its own configuration file
4. **Reliability**: Predictable behavior in each environment
5. **Flexibility**: Easy to customize each environment independently

## Version History

- **2025-07-26**: Separated test properties from production properties
- Removed test-specific values from production configuration
- Created independent test property file
- Updated all test scripts to use test properties only
- Improved documentation and usage examples 