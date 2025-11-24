# Development Tools

This directory contains development and maintenance tools that are **NOT** part of the production system execution.

## Directory Structure

### `ci-cd/`

CI/CD setup and configuration scripts:

- **`activate_github_actions.sh`**: Configures GitHub Actions workflows
- **`setup_quality_monitoring.sh`**: Sets up quality monitoring tools (SonarQube, Codecov, security scanning)
- **`setup_complete_ci_cd.sh`**: Master script for complete CI/CD setup
- **`run_github_actions_local.sh`**: Runs GitHub Actions workflows locally using `act`

See [ci-cd/README.md](ci-cd/README.md) for detailed documentation.

## Purpose

These tools are **development-only** and should **NOT** be executed in production environments. They are used for:

- Setting up development environments
- Configuring CI/CD pipelines
- Running tests locally
- Generating configuration files

## Production vs Development

**Production scripts** (executed in normal system operation):
- Located in `bin/` directory
- Use only standard bash/awk/sed tools
- No external dependencies like Python

**Development tools** (this directory):
- Used only during development and CI/CD
- May require additional tools (Python, act, etc.)
- Generate configuration files, not executed in production

