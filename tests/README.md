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