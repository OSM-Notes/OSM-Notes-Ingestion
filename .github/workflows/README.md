# GitHub Actions Workflows - OSM-Notes-Ingestion

## Summary

This folder contains the GitHub Actions workflows that automate testing and validation for the OSM-Notes-Ingestion project.

## Workflow Structure

### tests.yml

**Purpose:** Main testing workflow

- Runs unit and integration tests
- Validates Bash and SQL script functionality
- Includes tests with real data and mock
- Runs on push and pull requests to `main`

### quality-tests.yml

**Purpose:** Code quality workflow

- Validates code format and style
- Runs shellcheck, shfmt, markdownlint
- Verifies naming conventions
- Runs on push and pull requests to `main`

### integration-tests.yml

**Purpose:** Integration testing workflow

- Validates database integration
- Tests ETL and WMS flows
- Runs tests in Docker environment
- Runs on push and pull requests to `main`

## Configuration

Each workflow is configured for:

- **Triggers:** `push` and `pull_request` to `main` branch
- **Environment:** Ubuntu 22.04
- **Timeout:** 30 minutes per job
- **Concurrency:** Limited to avoid conflicts

## Workflow States

- 🟢 **Success:** All tests passed
- 🔴 **Failure:** At least one test failed
- 🟡 **Pending:** Queued for execution
- ⚪ **Skipped:** Doesn't apply to the event

## Troubleshooting

### Workflow fails

1. Review logs in the Actions tab
2. Identify the job and step that failed
3. Reproduce the problem locally
4. Fix and make a new commit

### Workflow doesn't run

1. Verify the YAML file is valid
2. Confirm the trigger is configured correctly
3. Check repository permissions

## Equivalent Local Commands

```bash
# Run main tests
./tests/run_all_tests.sh

# Run quality tests
./tests/run_quality_tests.sh

# Run integration tests
./tests/run_integration_tests.sh

# Run Docker tests
./tests/docker/run_ci_tests.sh
```

## Related Documentation

- [Testing Guide](../docs/Testing_Guide.md)
- [Testing Workflows Overview](../docs/Testing_Workflows_Overview.md)
- [CI/CD Integration](../docs/CI_CD_Integration.md)

---

*Last updated: 2025-08-04*
