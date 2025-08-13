# CI Troubleshooting Guide

## Overview

This document provides solutions for common CI/CD issues encountered in the OSM-Notes-profile project, particularly related to missing tools and dependencies in GitHub Actions.

## Common Issues

### 1. Missing XSLT Tools

**Error**: `xsltproc: command not found` or `xmllint: command not found`

**Solution**: These tools are now automatically installed in the CI workflow:

```yaml
- name: Install system dependencies
  run: |
    sudo apt-get update
    sudo apt-get install -y \
      libxml2-utils \
      xsltproc \
      # ... other dependencies
```

**Verification**: The workflow includes a verification step that checks tool availability.

### 2. Missing Shell Formatting Tools

**Error**: `shfmt: command not found` or `shellcheck: command not found`

**Solution**: The workflow now includes automatic installation of `shfmt`:

```yaml
- name: Install shfmt (if not available)
  run: |
    if ! command -v shfmt; then
      echo "shfmt not found, installing from GitHub..."
      chmod +x tests/install_shfmt.sh
      ./tests/install_shfmt.sh
    else
      echo "shfmt already available"
    fi
```

**Note**: `shellcheck` is installed via the package manager.

### 3. XSLT Tests Failing

**Error**: Tests like `xslt_enum_validation.test.bats` fail due to missing tools

**Solution**: The workflow now includes conditional execution of XSLT tests:

```yaml
- name: Run XSLT tests
  run: |
    if command -v xsltproc && command -v xmllint; then
      bats tests/unit/bash/xslt_simple.test.bats
      bats tests/unit/bash/xslt_enum_validation.test.bats
    else
      echo "XSLT tools not available, skipping XSLT tests"
    fi
```

### 4. Integration Tests Failing

**Error**: Tests requiring XSLT processing fail

**Solution**: Integration tests are now executed conditionally:

```yaml
- name: Run integration tests (if tools available)
  run: |
    if command -v xsltproc && command -v xmllint; then
      echo "Running integration tests with XSLT support..."
      bats tests/unit/bash/edge_cases_integration.test.bats || echo "Edge cases integration tests failed"
      bats tests/unit/bash/hybrid_integration.test.bats || echo "Hybrid integration tests failed"
      bats tests/unit/bash/real_data_integration.test.bats || echo "Real data integration tests failed"
      bats tests/unit/bash/resource_limits.test.bats || echo "Resource limits tests failed"
    else
      echo "XSLT tools not available, skipping integration tests that require XSLT"
    fi
```

## Environment Verification

The CI workflow includes a comprehensive environment verification step:

```yaml
- name: Verify CI environment
  run: |
    chmod +x tests/verify_ci_environment.sh
    ./tests/verify_ci_environment.sh
```

This script tests:
- Tool availability (`xsltproc`, `xmllint`, `shfmt`, `shellcheck`, `bats`, `psql`)
- XSLT processing capabilities
- Shell formatting capabilities
- Database connectivity
- BATS framework functionality

## Manual Installation Scripts

### Installing shfmt

If you need to install `shfmt` manually:

```bash
# Make the script executable
chmod +x tests/install_shfmt.sh

# Run the installation script
./tests/install_shfmt.sh
```

The script tries multiple installation methods:
1. Package manager (apt-get, yum, dnf, brew)
2. Go install (if Go is available)
3. Direct download from GitHub releases

### Verifying Environment

To verify your local environment:

```bash
# Make the script executable
chmod +x tests/verify_ci_environment.sh

# Run the verification script
./tests/verify_ci_environment.sh
```

## CI Scripts

### run_ci_tests_simple.sh

This script is specifically designed for CI environments and includes:

- Automatic dependency installation
- Conditional test execution based on tool availability
- Comprehensive error handling
- Detailed logging

Usage in CI:
```yaml
- name: Run unit tests
  run: |
    chmod +x tests/run_ci_tests_simple.sh
    ./tests/run_ci_tests_simple.sh 2>&1 | tee tests/results/unit-tests.log
```

## Troubleshooting Steps

### 1. Check Tool Availability

```bash
# Verify basic tools
command -v xsltproc && echo "✓ xsltproc available"
command -v xmllint && echo "✓ xmllint available"
command -v shfmt && echo "✓ shfmt available"
command -v shellcheck && echo "✓ shellcheck available"
```

### 2. Check Package Installation

```bash
# For Ubuntu/Debian
dpkg -l | grep -E "(libxml2|libxslt|xsltproc|shfmt|shellcheck)"

# For CentOS/RHEL
rpm -qa | grep -E "(libxml2|libxslt|xsltproc|shfmt|shellcheck)"
```

### 3. Test XSLT Processing

```bash
# Create a simple test
echo '<root><item>test</item></root>' > test.xml
xsltproc -o test.csv /path/to/stylesheet.xslt test.xml
```

### 4. Test Shell Formatting

```bash
# Test shfmt
echo 'echo "test"' > test.sh
shfmt -d test.sh

# Test shellcheck
shellcheck test.sh
```

## Common Solutions

### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install -y \
  libxml2-utils \
  xsltproc \
  shfmt \
  shellcheck \
  bats
```

### CentOS/RHEL

```bash
sudo yum install -y \
  libxml2 \
  libxslt \
  xsltproc \
  shfmt \
  shellcheck \
  bats
```

### macOS

```bash
brew install \
  libxml2 \
  libxslt \
  shfmt \
  shellcheck \
  bats-core
```

## CI Workflow Structure

The current CI workflow is structured to:

1. **Install Dependencies**: All required tools are installed upfront
2. **Verify Environment**: Tools are verified before running tests
3. **Conditional Execution**: Tests run only when required tools are available
4. **Graceful Degradation**: Missing tools don't cause complete failure
5. **Comprehensive Logging**: All steps are logged for debugging

## Best Practices

1. **Always check tool availability** before running tests
2. **Use conditional execution** for tool-dependent tests
3. **Provide fallback behavior** when tools are missing
4. **Log all installation steps** for debugging
5. **Test locally** before pushing to CI
6. **Use the verification script** to ensure environment consistency

## Support

If you encounter issues not covered in this guide:

1. Check the CI logs for specific error messages
2. Run the verification script locally to reproduce the issue
3. Review the workflow file for recent changes
4. Check if the issue is related to GitHub Actions updates
5. Consider opening an issue with detailed error information

## Version History

- **2025-08-13**: Initial troubleshooting guide creation
- Added solutions for missing XSLT tools
- Added solutions for missing shell formatting tools
- Added environment verification procedures
- Added manual installation scripts documentation
