# Testing Workflows Overview - OSM-Notes-profile

## Summary

This document explains the GitHub Actions workflows used in the OSM-Notes-profile project to automate testing and ensure code quality.

## Why are there three workflows?

When you make a push or pull request, you see three different "workflow runs" because the project has several independent workflows configured in `.github/workflows/`. Each one is designed to run a specific type of test.

**Advantages of this configuration:**

- ✅ **Parallelization:** Tests run simultaneously, getting results faster
- ✅ **Specialization:** Each workflow focuses on a specific aspect (quality, integration, functionality)
- ✅ **Independence:** If one type of test fails, it doesn't stop the others
- ✅ **Clarity:** You can see the status of each category separately

## Main Workflows

### 1. Tests (tests.yml)

**Purpose:** Runs the main battery of unit and integration tests for the project's Bash and SQL scripts.

**What it validates:**

- Bash functions and scripts work correctly in isolation (unit tests)
- Different system components interact correctly with each other (integration tests)
- Main data processing flows, XML validation, error handling, and parallelism work as expected
- Includes tests with real data, mock tests, and hybrid tests

**When it runs:** On each push or pull request to the main branch (`main`), or when manually requested.

**Main test files:**

- `tests/run_all_tests.sh`
- `tests/run_integration_tests.sh`
- `tests/run_enhanced_tests.sh`
- `tests/run_real_data_tests.sh`

---

### 2. Quality Tests (quality-tests.yml)

**Purpose:** Focuses on ensuring source code quality and compliance with best practices.

**What it validates:**

- Bash and SQL scripts comply with defined format and style standards (shellcheck, shfmt, markdownlint)
- No duplicate variables, syntax errors, or permission issues in scripts
- Documentation and configuration files are present and properly formatted
- Validation of naming conventions and code structure

**When it runs:** On each push or pull request to the main branch (`main`), or when manually requested.

**Main test files:**

- `tests/run_quality_tests.sh`
- `tests/run_quality_tests_simple.sh`
- `tests/scripts/check_variable_duplicates.sh`

---

### 3. Integration Tests (integration-tests.yml)

**Purpose:** Validates the integration of different system modules, especially in environments that simulate real infrastructure (using Docker).

**What it validates:**

- Scripts can interact correctly with PostgreSQL databases and simulated external services (mock API)
- ETL flows, note processing, and WMS administration work end-to-end
- Integration with external tools (Docker, PostGIS, etc.) is successful
- Network connectivity and configuration tests

**When it runs:** On each push or pull request to the main branch (`main`), or when manually requested.

**Main test files:**

- `tests/docker/run_ci_tests.sh`
- `tests/docker/run_integration_tests.sh`
- `tests/run_integration_tests.sh`
- `tests/run_mock_integration_tests.sh`

---

## Testing Scripts Summary Table

| Script / Workflow                      | Location                                 | Main Purpose                                                                 |
|----------------------------------------|-------------------------------------------|-------------------------------------------------------------------------------|
| `run_all_tests.sh`                     | tests/                                    | Runs all main tests (unit, integration, mock, etc.)                           |
| `run_integration_tests.sh`             | tests/                                    | Runs complete integration tests                                                |
| `run_quality_tests.sh`                 | tests/                                    | Validates code quality, format, and conventions                               |
| `run_mock_tests.sh`                    | tests/                                    | Runs tests using mocks and simulated environments                             |
| `run_enhanced_tests.sh`                | tests/                                    | Advanced testability and robustness tests                                     |
| `run_real_data_tests.sh`               | tests/                                    | Tests with real data and special cases                                        |
| `run_parallel_tests.sh`                | tests/                                    | Validates parallel processing and concurrency                                 |
| `run_xml_xslt_tests.sh`                | tests/                                    | XML/XSLT validation and transformation tests                                  |
| `run_error_handling_tests.sh`          | tests/                                    | Error handling and edge case validation tests                                 |
| `run_dwh_tests.sh`                     | tests/                                    | DWH enhanced testing (new dimensions, functions, ETL)                         |
| `run_ci_tests.sh`                      | tests/docker/                             | CI/CD tests in Docker environment                                             |
| `run_integration_tests.sh`             | tests/docker/                             | Integration tests in Docker environment                                       |
| `quality-tests.yml`                    | .github/workflows/                        | GitHub Actions workflow for quality tests                                     |
| `integration-tests.yml`                | .github/workflows/                        | GitHub Actions workflow for integration tests                                 |
| `tests.yml`                            | .github/workflows/                        | GitHub Actions workflow for main unit and integration tests                   |

## How to Interpret Results

### Workflow States

- 🟢 **Green (Success):** All tests passed correctly
- 🔴 **Red (Failure):** At least one test failed
- 🟡 **Yellow (Pending/Queued):** The workflow is waiting to run
- ⚪ **Gray (Skipped):** The workflow didn't run (e.g., doesn't apply to the branch)

### What to do when a workflow fails

1. **Review the logs:** Click on the failed workflow to see detailed logs
2. **Identify the problem:** The logs will show exactly which test failed and why
3. **Reproduce locally:** Run the tests locally to debug
4. **Fix the problem:** Fix the code and make a new commit

### Useful commands for debugging

```bash
# Run tests locally
./tests/run_all_tests.sh

# Run specific tests
./tests/run_quality_tests.sh
./tests/run_integration_tests.sh

# Run tests with verbose
./tests/run_integration_tests.sh --verbose

# View detailed logs
tail -f tests/tmp/*.log
```

## Workflow Configuration

The workflows are defined in the `.github/workflows/` folder:

- `.github/workflows/tests.yml` - Main tests
- `.github/workflows/quality-tests.yml` - Quality tests
- `.github/workflows/integration-tests.yml` - Integration tests

Each YAML file contains:

- **Triggers:** When the workflow runs (push, pull_request, etc.)
- **Jobs:** Specific tasks to execute
- **Steps:** Detailed steps within each job
- **Environments:** Execution environments (Ubuntu, Docker, etc.)

## Best Practices

### For Developers

- ✅ Run tests locally before pushing
- ✅ Review GitHub Actions logs after each push
- ✅ Fix problems quickly to keep the pipeline green
- ✅ Use specific tests for debugging

### For Maintenance

- ✅ Keep tests updated when code changes
- ✅ Add new tests for new functionality
- ✅ Optimize test execution time
- ✅ Document workflow changes

## Conclusion

The three workflows work together to ensure code quality:

- **Tests:** Validates functionality and integration
- **Quality Tests:** Validates clean and well-structured code
- **Integration Tests:** Validates operation in real environments

This configuration allows quick problem detection and maintains the quality of the OSM-Notes-profile project.

---

*Last updated: 2025-08-04*
