---
title: "Testing Workflows Overview - OSM-Notes-Ingestion"
description: "This document explains the GitHub Actions workflows used in the OSM-Notes-Ingestion project to"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "testing"
audience:
  - "developers"
project: "OSM-Notes-Ingestion"
status: "active"
---


# Testing Workflows Overview - OSM-Notes-Ingestion

## Summary

This document explains the GitHub Actions workflows used in the OSM-Notes-Ingestion project to
automate testing and ensure code quality.

## Why are there three workflows?

When you make a push or pull request, you see three different "workflow runs" because the project
has several independent workflows configured in `.github/workflows/`. Each one is designed to run a
specific type of test.

**Advantages of this configuration:**

- ✅ **Parallelization:** Tests run simultaneously, getting results faster
- ✅ **Specialization:** Each workflow focuses on a specific aspect (quality, integration,
  functionality)
- ✅ **Independence:** If one type of test fails, it doesn't stop the others
- ✅ **Clarity:** You can see the status of each category separately

## Main Workflows

### 1. Tests (tests.yml)

**Purpose:** Runs the main battery of unit and integration tests for the project's Bash and SQL
scripts.

**What it validates:**

- Bash functions and scripts work correctly in isolation (unit tests)
- Different system components interact correctly with each other (integration tests)
- Main data processing flows, XML validation, error handling, and parallelism work as expected
- Includes tests with real data, mock tests, and hybrid tests

**When it runs:** On each push or pull request to the main branch (`main`), or when manually
requested.

**Main test files:**

- `tests/run_all_tests.sh`
- `tests/run_integration_tests.sh`
- `tests/run_enhanced_tests.sh`
- `tests/run_real_data_tests.sh`

---

**Note:** All testing workflows have been consolidated into `ci.yml`. The previous separate workflows (`quality-tests.yml`, `integration-tests.yml`, `tests.yml`) were deprecated and merged on 2025-10-21.

---

## Testing Scripts Summary Table

| Script / Workflow             | Location | Main Purpose                                        |
| ----------------------------- | -------- | --------------------------------------------------- |
| `run_all_tests.sh`            | tests/   | Runs all main tests (unit, integration, mock, etc.) |
| `run_integration_tests.sh`    | tests/   | Runs complete integration tests                     |
| `run_quality_tests.sh`        | tests/   | Validates code quality, format, and conventions     |
| `run_mock_tests.sh`           | tests/   | Runs tests using mocks and simulated environments   |
| `run_enhanced_tests.sh`       | tests/   | Advanced testability and robustness tests           |
| `run_real_data_tests.sh`      | tests/   | Tests with real data and special cases              |
| `run_parallel_tests.sh`       | tests/   | Validates parallel processing and concurrency       |
| `run_error_handling_tests.sh` | tests/   | Error handling and edge case validation tests       |

> **Note:** DWH/ETL tests are maintained in
> [OSM-Notes-Analytics](https://github.com/OSM-Notes/OSM-Notes-Analytics). | `run_ci_tests.sh` |
> tests/docker/ | CI/CD tests in Docker environment | | `run_integration_tests.sh` | tests/docker/ |
> Integration tests in Docker environment | | `ci.yml` | .github/workflows/ | Unified GitHub Actions
> workflow for all tests (quality, integration, unit, etc.) |

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

The workflow is defined in the `.github/workflows/` folder:

- `.github/workflows/ci.yml` - Unified CI/CD workflow (includes all tests: quality, integration, unit, etc.)

**Note:** Previous separate workflows (`tests.yml`, `quality-tests.yml`, `integration-tests.yml`) were deprecated and merged into `ci.yml` on 2025-10-21.

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

This configuration allows quick problem detection and maintains the quality of the
OSM-Notes-Ingestion project.
