# Tests Directory

## Overview

The `tests` directory contains comprehensive testing infrastructure for the
OSM-Notes-Ingestion system. It includes unit tests, integration tests,
performance tests, and quality assurance tools to ensure the reliability and
correctness of the entire system.

## Quick Start (No sudo required)

To run tests without sudo privileges:

1. **Install dependencies**:

   ```bash
   ./tests/install_dependencies.sh
   ```

2. **Setup test database**:

   ```bash
   ./tests/setup_test_db.sh
   ```

3. **Run tests**:

   ```bash
   ./tests/run_tests_simple.sh
   ```

## CI/CD Environment

For GitHub Actions and other CI environments:

1. **Verify CI environment**:

   ```bash
   ./tests/verify_ci_environment.sh
   ```

2. **Install missing tools** (if needed):

   ```bash
   ./tests/install_shfmt.sh
   ```

3. **Run CI-optimized tests**:

   ```bash
   ./tests/run_ci_tests_simple.sh
   ```

**Note**: The CI workflow automatically handles dependency installation and environment verification.

## Troubleshooting

### Common CI Issues

If you encounter issues in GitHub Actions or other CI environments:

1. **Missing tools**: Check the [CI Troubleshooting Guide](../docs/CI_Troubleshooting.md)
2. **Environment verification**: Run `./tests/verify_ci_environment.sh`
3. **Manual tool installation**: Use `./tests/install_shfmt.sh` for missing formatters

### Local Environment Issues

For local testing problems:

1. **Dependencies**: Ensure all required packages are installed
2. **Database**: Verify PostgreSQL is running and accessible
3. **Permissions**: Check file permissions and database access rights

## Docker Setup (Alternative)

If you prefer to use Docker and have sudo access:

1. **Setup Docker environment**:

   ```bash
   cd tests/docker
   docker compose up -d
   ```

2. **Run tests in Docker**:

   ```bash
   ./tests/docker/run_integration_tests.sh
   ```

## Directory Structure

### `/tests/unit/`

Unit tests for individual components:

- **`bash/`**: BATS (Bash Automated Testing System) tests for shell scripts
  - **`resource_limits.test.bats`**: Tests for XML processing resource limitations and monitoring
  - **`historical_data_validation.test.bats`**: Tests for historical data validation in processAPI
  - **`processAPI_historical_integration.test.bats`**: Integration tests for processAPI historical validation
  - **`xslt_enum_format.test.bats`**: Tests for XSLT enum format validation and PostgreSQL compatibility
  - **`xml_processing_enhanced.test.bats`**: Enhanced XML processing tests
  - **Other `.test.bats` files**: Component-specific unit tests
- **`sql/`**: Database function and table tests
  - **`dwh_dimensions_enhanced.test.sql`**: Unit tests for enhanced DWH dimensions
  - **`dwh_functions_enhanced.test.sql`**: Unit tests for enhanced DWH functions
  - **`tables_final_fixed.test.sql`**: Database table structure tests
  - **`functions_final_corrected.test.sql`**: Database function tests

### `/tests/integration/`

End-to-end integration tests:

- **`end_to_end.test.bats`**: Complete workflow testing from data ingestion to output
- **`processAPI_historical_e2e.test.bats`**: End-to-end tests for processAPI historical validation with real database scenarios

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

### CI and Environment Scripts

CI-specific and environment management scripts:

- **`run_ci_tests_simple.sh`**: CI-optimized test runner with automatic dependency installation
- **`install_shfmt.sh`**: Automatic installation script for shfmt shell formatter
- **`verify_ci_environment.sh`**: Comprehensive environment verification for CI/CD
- **`install_dependencies.sh`**: General dependency installation script

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
- **Resource Limit Tests**: XML processing resource monitoring and limits validation
- **Historical Data Validation Tests**: ProcessAPI prerequisite validation for historical data integrity
- **XSLT Enum Format Tests**: PostgreSQL enum compatibility validation for CSV output

### Test Data

- **Sample Data**: Representative datasets for testing
- **Edge Cases**: Special scenarios and error conditions
- **Mock Data**: Simulated data for isolated testing

## Usage

Tests can be run individually or as part of the complete test suite:

- `./tests/run_tests_simple.sh`: Basic test suite (no sudo required)
- `./tests/run_enhanced_tests.sh`: Enhanced test suite
- `./tests/run_tests.sh`: Complete test suite
- `./tests/advanced/run_advanced_tests.sh`: Advanced quality tests

### Running Specific Test Categories

- **Resource Limit Tests**: `cd tests/unit/bash && bats resource_limits.test.bats`
- **Historical Data Validation Tests**: `cd tests/unit/bash && bats historical_data_validation.test.bats`
- **ProcessAPI Integration Tests**: `cd tests/unit/bash && bats processAPI_historical_integration.test.bats`
- **XSLT Enum Format Tests**: `cd tests/unit/bash && bats xslt_enum_format.test.bats`
- **XML Processing Tests**: `cd tests/unit/bash && bats xml_processing_enhanced.test.bats`
- **Individual Test**: `cd tests/unit/bash && bats resource_limits.test.bats -f "test_name"`

## Troubleshooting

### Common Issues

1. **PostgreSQL access denied**:
   - Ensure PostgreSQL is running: `sudo systemctl start postgresql`
   - Configure local access in `pg_hba.conf`
   - Or use Docker: `cd tests/docker && docker compose up -d`

2. **Docker requires sudo**:
   - Add user to docker group: `sudo usermod -aG docker $USER`
   - Log out and log back in
   - Or use the non-Docker tests: `./tests/run_tests_simple.sh`

3. **Missing dependencies**:
   - Run: `./tests/install_dependencies.sh`
   - Or install manually: `sudo apt-get install postgresql-client bats`

## Dependencies

- BATS testing framework
- Docker and docker-compose (optional)
- PostgreSQL test database
- Various testing tools (shellcheck, shfmt, etc.)

## Test Configuration and Standardized Values

### Overview

This document describes the standardized configuration values used across all test
environments in the OSM-Notes-Ingestion project. **Test properties are completely
separate from production properties** to maintain clear boundaries between
environments.

### Test Properties vs Production Properties

#### Test Properties (`tests/properties.sh`)

- **Purpose**: Configuration for all test environments
- **Scope**: Unit tests, integration tests, CI/CD tests
- **Values**: Conservative, safe defaults for testing
- **Independence**: Completely separate from production

#### Production Properties (`etc/properties.sh`)

- **Purpose**: Configuration for production environments
- **Scope**: Live data processing, production deployments
- **Values**: Optimized for performance and reliability
- **Independence**: No test-specific values

### Test Properties Configuration

#### Database Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `TEST_DBNAME` | `osm_notes_test` | Test database name |
| `TEST_DBUSER` | `testuser` (Docker) / `postgres` (Host) | Test-specific database user |
| `TEST_DBPASSWORD` | `testpass` (Docker) / `` (Host) | Database password |
| `TEST_DBHOST` | `postgres` (Docker) / `localhost` (Host) | Database host |
| `TEST_DBPORT` | `5432` | Database port |

#### Timeout Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `TEST_TIMEOUT` | `300` (5 minutes) | General test timeout |
| `PERFORMANCE_TIMEOUT` | `60` (1 minute) | Performance test timeout |
| `MOCK_API_TIMEOUT` | `30` (30 seconds) | Mock API timeout |
| `CI_TIMEOUT` | `600` (10 minutes) | CI/CD timeout |
| `DOCKER_TIMEOUT` | `300` (5 minutes) | Docker operations timeout |
| `VALIDATION_TIMEOUT` | `60` (1 minute) | Validation test timeout |

#### Retry Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `TEST_RETRIES` | `3` | Standard retry count |
| `MAX_RETRIES` | `30` | Maximum retries for service startup |
| `RETRY_INTERVAL` | `2` | Seconds between retries |
| `CI_MAX_RETRIES` | `20` | CI environment retries |
| `DOCKER_MAX_RETRIES` | `10` | Docker-specific retries |
| `VALIDATION_RETRIES` | `3` | Validation retries |

#### Threading Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `MAX_THREADS` | `2` | Conservative threading for tests |
| `CI_MAX_THREADS` | `2` | Conservative threading for CI |
| `PARALLEL_THREADS` | `2` | Conservative parallel processing |
| `PARALLEL_ENABLED` | `false` | Enable parallel processing |

#### Memory Configuration

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `MEMORY_LIMIT_MB` | `100` | Memory limit for tests |

### Environment-Specific Configuration

#### Docker Environment

- Uses `testuser`/`testpass` credentials
- Connects to `postgres` host
- Conservative threading (2 threads)
- Extended timeouts for container startup

#### Host Environment

- Uses `postgres` user with no password
- Connects to `localhost`
- Conservative threading (2 threads)
- Standard timeouts

#### CI/CD Environment

- Extended timeouts (10 minutes)
- More retries (20 attempts)
- Conservative threading (2 threads)
- Enhanced logging and error reporting

### Usage

#### Loading Test Properties

All test scripts automatically load the test properties:

```bash
# Load test properties
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/properties.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/properties.sh"
fi
```

#### Overriding Test Values

You can override any test value by setting environment variables:

```bash
# Override timeout for specific test
export TEST_TIMEOUT=600
bash tests/run_tests_simple.sh

# Override threading for performance test
export MAX_THREADS=4
bash tests/run_enhanced_tests.sh --parallel
```

#### Production vs Test Values

The system uses different default values for production and test environments:

| Configuration | Production | Test |
|---------------|------------|------|
| `MAX_THREADS` | `4-16` (based on cores) | `2` |
| `MEMORY_LIMIT_MB` | `512` | `100` |
| `TEST_TIMEOUT` | `600` | `300` |
| `MAX_RETRIES` | `30` | `30` |

### Benefits of Separation

1. **Clear Boundaries**: Test and production configurations are completely separate
2. **Safety**: Test values cannot accidentally affect production
3. **Maintainability**: Each environment has its own configuration file
4. **Reliability**: Predictable behavior in each environment
5. **Flexibility**: Easy to customize each environment independently
