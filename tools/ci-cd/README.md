# CI/CD Tools

This directory contains development and CI/CD setup scripts. These scripts are **NOT** part of the production system execution - they are only used for development, testing, and CI/CD pipeline configuration.

## Scripts

### `activate_github_actions.sh`

Configures and activates GitHub Actions workflows for the project.

**Usage:**
```bash
./tools/ci-cd/activate_github_actions.sh --all
```

### `setup_quality_monitoring.sh`

Sets up quality monitoring tools including SonarQube, Codecov, and security scanning.

**Usage:**
```bash
./tools/ci-cd/setup_quality_monitoring.sh --all
```

### `setup_complete_ci_cd.sh`

Master script that sets up the complete CI/CD pipeline including GitHub Actions and quality monitoring.

**Usage:**
```bash
./tools/ci-cd/setup_complete_ci_cd.sh --all
```

### `run_github_actions_local.sh`

Runs GitHub Actions workflows locally using `act` tool for testing before pushing.

**Usage:**
```bash
./tools/ci-cd/run_github_actions_local.sh --all
```

## Purpose

These scripts are **development tools only** and should **NOT** be executed in production environments. They are used to:

- Configure CI/CD pipelines
- Set up development tools
- Generate configuration files for GitHub Actions
- Test workflows locally

## Dependencies

These scripts may require:
- Python 3 (for some development tools)
- `act` (for local GitHub Actions execution)
- Various development tools (shellcheck, shfmt, bats, etc.)

These dependencies are **NOT** required for production system execution.

