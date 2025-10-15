# CI/CD Integration for OSM-Notes-Ingestion

## Overview

This document describes the comprehensive CI/CD (Continuous Integration/Continuous
Deployment) integration implemented for the OSM-Notes-Ingestion project.

## Architecture

### GitHub Actions Workflow

The project uses GitHub Actions for automated testing and quality assurance.
The workflow is defined in `.github/workflows/tests.yml` and includes:

#### Jobs

1. **Unit Tests** (`unit-tests`)
   - Runs BATS tests for shell scripts
   - Tests basic functionality and script availability
   - Uses PostgreSQL service container

2. **DWH Enhanced Tests** (`dwh-enhanced-tests`)
   - Runs DWH enhanced functionality tests
   - Tests new dimensions, functions, ETL improvements
   - Uses PostgreSQL service container with PostGIS
   - Includes SQL unit tests and integration tests

3. **Integration Tests** (`integration-tests`)
   - Runs end-to-end tests using Docker containers
   - Tests complete workflows and data processing
   - Uses Docker Compose for multi-container testing

4. **Performance Tests** (`performance-tests`)
   - Benchmarks processing performance
   - Tests with large datasets
   - Measures execution time and resource usage

5. **Security Tests** (`security-tests`)
   - Runs ShellCheck for shell script analysis
   - Identifies potential security vulnerabilities

6. **Advanced Tests** (`advanced-tests`)
   - Code coverage analysis with kcov
   - Quality metrics and static analysis
   - Comprehensive reporting

7. **Test Summary** (`test-summary`)
   - Consolidates results from all test jobs
   - Generates comprehensive reports
   - Posts results to pull requests

### Test Environments

#### Host Environment

- Runs on the local development machine
- Uses system-installed tools and dependencies
- Simulates production-like conditions

#### Docker Environment

- Isolated containerized testing
- Consistent environment across different platforms
- Includes all necessary tools and dependencies

## Test Categories

### 1. Unit Tests (BATS)

- **Location**: `tests/unit/bash/`
- **Purpose**: Test individual functions and scripts
- **Coverage**: Core functionality, error handling, prerequisites

**Test Files**:

- `functionsProcess.test.bats` - Tests common functions
- `processPlanetNotes.test.bats` - Tests Planet processing script
- `processAPINotes.test.bats` - Tests API processing script
- `wmsManager.test.bats` - Tests WMS management script

### 2. Integration Tests

- **Location**: `tests/integration/`
- **Purpose**: Test complete workflows and data processing
- **Coverage**: End-to-end scenarios, database operations

**Test Files**:

- `end_to_end.test.bats` - Complete workflow testing
- `wms_integration.test.bats` - WMS integration testing

### 3. Advanced Tests

- **Location**: `tests/advanced/`
- **Purpose**: Code coverage, security, quality analysis
- **Coverage**: Comprehensive metrics and reporting

**Categories**:

- **Coverage**: Code coverage analysis with kcov
- **Security**: Security scanning with ShellCheck
- **Quality**: Code quality metrics and static analysis
- **Performance**: Performance benchmarking and optimization

## CI/CD Scripts

### Main Test Runner

- **File**: `tests/run_ci_tests.sh`
- **Purpose**: Orchestrates all test execution
- **Features**:
  - Host and Docker environment support
  - Parallel test execution
  - Comprehensive reporting
  - Environment detection and configuration

### Usage Examples

```bash
# Run all tests (host and Docker)
./tests/run_ci_tests.sh --all

# Run only host tests
./tests/run_ci_tests.sh --host-only

# Run only Docker tests
./tests/run_ci_tests.sh --docker-only

# Run with verbose output
./tests/run_ci_tests.sh --all --verbose

# Run tests in parallel
./tests/run_ci_tests.sh --all --parallel
```

## Docker Configuration

### Test Environment

- **Base Image**: Ubuntu 22.04
- **Tools Included**:
  - PostgreSQL client
  - BATS testing framework
  - ShellCheck for static analysis
  - kcov for code coverage
  - Python tools (pytest)
  - Node.js tools (ajv-cli, osmtogeojson)

### Docker Compose Setup

- **File**: `tests/docker/docker-compose.yml`
- **Services**:
  - `postgres`: PostgreSQL database with PostGIS
  - `app`: Main application container
  - `mock_api`: Mock OSM API server
  - `wms_test`: WMS testing container
  - `wms_advanced_test`: Advanced WMS testing

## Quality Assurance

### Code Quality Tools

1. **ShellCheck**
   - Static analysis for shell scripts
   - Identifies potential issues and best practices
   - Integrated into CI/CD pipeline

2. **kcov**
   - Code coverage analysis for shell scripts
   - Generates HTML reports
   - Measures test coverage percentage

3. **ShellCheck**
   - Security analysis for shell scripts
   - Identifies shell script vulnerabilities
   - Generates security reports

### Code Formatting

The project uses consistent code formatting:

```bash
# Shell script formatting
shfmt -w -i 1 -sr -bn -ci

# Shell script linting
shellcheck -x -o all
```

## Environment Variables

### Test Configuration

```bash
TEST_DBNAME=osm_notes_test      # Test database name
TEST_DBUSER=testuser            # Test database user
TEST_DBPASSWORD=testpass        # Test database password
TEST_DBHOST=localhost           # Test database host
TEST_DBPORT=5432               # Test database port
LOG_LEVEL=INFO                 # Logging level
MAX_THREADS=2                  # Maximum parallel threads
```

### CI/CD Configuration

```bash
CI_MODE=true                   # CI environment flag
GITHUB_TOKEN                   # GitHub API token
```

## Reporting and Artifacts

### Test Results

- **Location**: `./ci_results/`
- **Format**: JSON, HTML, Markdown
- **Content**: Test summaries, coverage reports, security scans

### GitHub Actions Artifacts

- Unit test results
- Integration test results
- Performance benchmarks
- Security scan reports
- Code coverage reports

## Monitoring and Alerts

### Test Status

- Automatic status updates on pull requests
- Detailed failure reporting
- Performance regression detection

### Quality Gates

- Minimum code coverage requirements
- Security vulnerability thresholds
- Performance benchmarks

## Best Practices

### Development Workflow

1. Write tests for new functionality
2. Ensure all tests pass locally
3. Push changes to trigger CI/CD
4. Review test results and reports
5. Address any issues before merging

### Test Writing Guidelines

- Use descriptive test names
- Follow BATS testing conventions
- Include both positive and negative test cases
- Test error conditions and edge cases

### CI/CD Maintenance

- Regular updates to dependencies
- Monitoring test execution time
- Optimizing test parallelization
- Updating security scanning rules

## Troubleshooting

### Common Issues

1. **Docker Build Failures**
   - Check Docker daemon status
   - Verify available disk space
   - Review Dockerfile syntax

2. **Test Failures**
   - Check database connectivity
   - Verify test data availability
   - Review test environment setup

3. **Performance Issues**
   - Monitor resource usage
   - Optimize test parallelization
   - Review test data size

### Debugging Commands

```bash
# Check Docker containers
docker compose ps

# View container logs
docker compose logs app

# Run tests with debug output
./tests/run_ci_tests.sh --verbose

# Check test database
psql -h localhost -U testuser -d osm_notes_test
```

## Future Enhancements

### Planned Improvements

1. **Automated Deployment**
   - Staging environment deployment
   - Production deployment automation
   - Rollback mechanisms

2. **Enhanced Monitoring**
   - Real-time test execution monitoring
   - Performance trend analysis
   - Automated alerting

3. **Advanced Testing**
   - Load testing for database operations
   - Chaos engineering for resilience testing
   - Mutation testing for test quality

4. **Security Enhancements**
   - Container vulnerability scanning
   - Dependency vulnerability monitoring
   - Automated security patching

## Conclusion

The CI/CD integration provides comprehensive testing and quality assurance for the
OSM-Notes-Ingestion project. It ensures code quality, security, and reliability
through automated testing across multiple environments and scenarios.

The system is designed to be maintainable, scalable, and provides clear feedback
to developers about the state of their changes.
