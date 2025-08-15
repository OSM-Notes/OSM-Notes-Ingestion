# CI/CD Troubleshooting Guide

## Overview

This document provides solutions for common issues encountered when running GitHub Actions workflows for the OSM-Notes-profile project.

## Common Issues and Solutions

### 1. PostgreSQL Connection Issues

#### Problem
```
ERROR: connection to server at localhost (127.0.0.1), port 5432 failed: FATAL: password authentication failed for user "testuser"
```

#### Solution
The issue is typically caused by authentication method conflicts. The workflow has been updated to use `POSTGRES_HOST_AUTH_METHOD: trust` for CI environments.

**Check these points:**
- Ensure `POSTGRES_HOST_AUTH_METHOD: trust` is set in the service configuration
- Verify that `PGPASSWORD` environment variable is correctly set
- Check that the PostgreSQL service is healthy before running tests

**Updated workflow configuration:**
```yaml
services:
  postgres:
    image: postgres:16
    env:
      POSTGRES_DB: osm_notes_test
      POSTGRES_USER: testuser
      POSTGRES_PASSWORD: testpass
      POSTGRES_HOST_AUTH_METHOD: trust  # This is crucial
```

### 2. PostGIS Installation Failures

#### Problem
```
ERROR: could not open extension control file "postgis.control"
```

#### Solution
The workflow now uses the official PostGIS Docker image instead of trying to install PostGIS extensions manually.

**Updated configuration:**
```yaml
services:
  postgres:
    image: postgis/postgis:16-3.4  # Official PostGIS image
```

### 3. Environment Variable Conflicts

#### Problem
Tests fail because environment variables are not properly set or conflict with each other.

#### Solution
Use the centralized environment setup script:

```bash
# In your workflow step
- name: Set up test environment
  run: |
    chmod +x tests/setup_ci_environment.sh
    source tests/setup_ci_environment.sh
```

This script:
- Sets all necessary database variables
- Configures PostgreSQL client environment
- Sets application-specific variables
- Provides backward compatibility

### 4. Tool Availability Issues

#### Problem
Required tools like `xsltproc`, `xmllint`, `shfmt`, or `shellcheck` are not available.

#### Solution
The workflow now includes comprehensive tool installation and verification:

```yaml
- name: Install system dependencies
  run: |
    sudo apt-get update
    sudo apt-get install -y \
      postgresql-client \
      bats \
      pgtap \
      libxml2-dev \
      libxslt1-dev \
      libxml2-utils \
      xsltproc \
      shellcheck \
      curl

- name: Verify tools availability
  run: |
    echo "Verifying required tools are available..."
    command -v xsltproc && echo "✓ xsltproc available"
    command -v xmllint && echo "✓ xmllint available"
    command -v shfmt && echo "✓ shfmt available"
    command -v shellcheck && echo "✓ shellcheck available"
    command -v bats && echo "✓ bats available"
    command -v psql && echo "✓ psql available"
```

### 5. Docker Compose Issues in Integration Tests

#### Problem
Integration tests fail because Docker containers are not properly configured or services are not healthy.

#### Solution
The Docker Compose configuration has been updated with:
- Proper health checks
- Restart policies
- Correct port mappings
- Better service dependencies

**Key improvements:**
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U testuser -d osm_notes_test"]
  interval: 5s
  timeout: 10s
  retries: 20
  start_period: 30s
restart: unless-stopped
```

### 6. Test Execution Failures

#### Problem
Tests fail due to missing test data or incorrect test setup.

#### Solution
Ensure proper test environment setup:

1. **Create necessary directories:**
```bash
mkdir -p tests/results
mkdir -p tests/output
mkdir -p tests/docker/logs
```

2. **Wait for services to be ready:**
```bash
until pg_isready -h localhost -p 5432 -U testuser; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 2
done
```

3. **Test database connection:**
```bash
export PGPASSWORD=testpass
psql -h localhost -U testuser -d osm_notes_test -c "SELECT version();" || exit 1
```

## Debugging Steps

### 1. Check Workflow Logs
- Review the complete workflow execution logs
- Look for specific error messages
- Check the timing of failures

### 2. Verify Service Health
```bash
# Check PostgreSQL service
docker ps | grep postgres
docker logs <postgres_container_id>

# Check service health
pg_isready -h localhost -p 5432 -U testuser
```

### 3. Test Environment Variables
```bash
# Check if environment variables are set
env | grep -E "(TEST_|DB|PG)"
```

### 4. Verify Tool Installation
```bash
# Check tool availability
which xsltproc xmllint shfmt shellcheck bats psql
```

## Prevention Strategies

### 1. Use Health Checks
Always include health checks for database services:
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U testuser -d osm_notes_test"]
  interval: 5s
  timeout: 10s
  retries: 20
```

### 2. Implement Proper Waiting
Wait for services to be ready before running tests:
```bash
until pg_isready -h localhost -p 5432 -U testuser; do
  sleep 2
done
```

### 3. Centralize Configuration
Use centralized scripts for environment setup:
- `tests/setup_ci_environment.sh` - Environment configuration
- `tests/verify_ci_environment.sh` - Tool verification

### 4. Test Database Connections
Always test database connectivity before running tests:
```bash
psql -h localhost -U testuser -d osm_notes_test -c "SELECT version();" || exit 1
```

## Getting Help

If you continue to experience issues:

1. **Check the logs:** Review the complete workflow execution logs
2. **Verify configuration:** Ensure all configuration files are up to date
3. **Test locally:** Try running the tests in a local Docker environment
4. **Create an issue:** Report the problem with detailed error messages and logs

## Related Documentation

- [Testing Guide](Testing_Guide.md)
- [CI/CD Integration](CI_CD_Integration.md)
- [Docker Setup](tests/docker/README.md)
- [Workflow Configuration](.github/workflows/README.md)
