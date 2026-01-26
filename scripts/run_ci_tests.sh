#!/usr/bin/env bash
#
# Run CI Tests Locally
# Simulates the GitHub Actions workflow to test changes locally
# This script delegates to tests/run_all_tests.sh --ci when available
# Author: Andres Gomez (AngocA)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

print_message() {
    local color="${1}"
    shift
    echo -e "${color}$*${NC}"
}

print_message "${YELLOW}" "=== Running CI Tests Locally (OSM-Notes-Ingestion) ==="
echo

cd "${PROJECT_ROOT}"

# Test coverage evaluation function
evaluate_test_coverage() {
    local scripts_dir="${1:-bin}"
    local tests_dir="${2:-tests}"

    print_message "${BLUE}" "Evaluating test coverage..."

    # Count test files for a script
    count_test_files() {
        local script_path="${1}"
        local script_name
        script_name=$(basename "${script_path}" .sh)

        local test_count=0

        # Check unit tests
        if [[ -d "${PROJECT_ROOT}/${tests_dir}/unit/bash" ]]; then
            if find "${PROJECT_ROOT}/${tests_dir}/unit/bash" -name "*${script_name}*.bats" -o -name "*${script_name}*.sh" 2>/dev/null | grep -q .; then
                test_count=$(find "${PROJECT_ROOT}/${tests_dir}/unit/bash" \( -name "*${script_name}*.bats" -o -name "*${script_name}*.sh" \) -type f 2>/dev/null | wc -l | tr -d ' ')
            fi
        fi

        # Check integration tests
        if [[ -d "${PROJECT_ROOT}/${tests_dir}/integration" ]]; then
            if find "${PROJECT_ROOT}/${tests_dir}/integration" -name "*${script_name}*.bats" -o -name "*${script_name}*.sh" 2>/dev/null | grep -q .; then
                test_count=$((test_count + $(find "${PROJECT_ROOT}/${tests_dir}/integration" \( -name "*${script_name}*.bats" -o -name "*${script_name}*.sh" \) -type f 2>/dev/null | wc -l | tr -d ' ')))
            fi
        fi

        echo "${test_count}"
    }

    # Calculate coverage percentage
    calculate_coverage() {
        local script_path="${1}"
        local test_count
        test_count=$(count_test_files "${script_path}")

        if [[ ${test_count} -gt 0 ]]; then
            # Heuristic: 1 test = 40%, 2 tests = 60%, 3+ tests = 80%
            local coverage=0
            if [[ ${test_count} -ge 3 ]]; then
                coverage=80
            elif [[ ${test_count} -eq 2 ]]; then
                coverage=60
            elif [[ ${test_count} -eq 1 ]]; then
                coverage=40
            fi
            echo "${coverage}"
        else
            echo "0"
        fi
    }

    # Find all scripts
    local scripts=()
    if [[ -d "${PROJECT_ROOT}/${scripts_dir}" ]]; then
        while IFS= read -r -d '' script; do
            scripts+=("${script}")
        done < <(find "${PROJECT_ROOT}/${scripts_dir}" -name "*.sh" -type f -print0 2>/dev/null | sort -z)
    fi

    if [[ ${#scripts[@]} -eq 0 ]]; then
        print_message "${YELLOW}" "⚠ No scripts found in ${scripts_dir}/, skipping coverage evaluation"
        return 0
    fi

    local total_scripts=${#scripts[@]}
    local scripts_with_tests=0
    local scripts_above_threshold=0
    local total_coverage=0
    local coverage_count=0

    for script in "${scripts[@]}"; do
        local script_name
        script_name=$(basename "${script}")
        local test_count
        test_count=$(count_test_files "${script}")
        local coverage
        coverage=$(calculate_coverage "${script}")

        if [[ ${test_count} -gt 0 ]]; then
            scripts_with_tests=$((scripts_with_tests + 1))
            if [[ "${coverage}" =~ ^[0-9]+$ ]] && [[ ${coverage} -gt 0 ]]; then
                total_coverage=$((total_coverage + coverage))
                coverage_count=$((coverage_count + 1))

                if [[ ${coverage} -ge 80 ]]; then
                    scripts_above_threshold=$((scripts_above_threshold + 1))
                fi
            fi
        fi
    done

    # Calculate overall coverage
    local overall_coverage=0
    if [[ ${coverage_count} -gt 0 ]]; then
        overall_coverage=$((total_coverage / coverage_count))
    fi

    echo
    echo "Coverage Summary:"
    echo "  Total scripts: ${total_scripts}"
    echo "  Scripts with tests: ${scripts_with_tests}"
    echo "  Scripts above 80% coverage: ${scripts_above_threshold}"
    echo "  Average coverage: ${overall_coverage}%"
    echo

    if [[ ${overall_coverage} -ge 80 ]]; then
        print_message "${GREEN}" "✓ Coverage target met (${overall_coverage}% >= 80%)"
    elif [[ ${overall_coverage} -ge 50 ]]; then
        print_message "${YELLOW}" "⚠ Coverage below target (${overall_coverage}% < 80%), improvement needed"
    else
        print_message "${YELLOW}" "⚠ Coverage significantly below target (${overall_coverage}% < 50%)"
    fi

    echo
    print_message "${BLUE}" "Note: This is an estimated coverage based on test file presence."
    print_message "${BLUE}" "For accurate coverage, use code instrumentation tools like bashcov."
}

# Run coverage evaluation before delegating (non-blocking)
if [[ -d "${PROJECT_ROOT}/bin" ]]; then
    echo
    print_message "${YELLOW}" "=== Test Coverage Evaluation ==="
    echo
    evaluate_test_coverage "bin" "tests" || true
    echo
fi

# Check if run_all_tests.sh exists and has --ci option
if [[ -f "tests/run_all_tests.sh" ]]; then
    print_message "${BLUE}" "Using existing run_all_tests.sh --ci..."
    print_message "${BLUE}" "This delegates to tests/run_ci_tests_local.sh which simulates GitHub Actions"
    exec ./tests/run_all_tests.sh --ci "$@"
fi

# Fallback: If run_all_tests.sh doesn't exist, provide helpful message
print_message "${RED}" "Error: tests/run_all_tests.sh not found"
print_message "${YELLOW}" "This project should have a tests/run_all_tests.sh script with --ci option"
exit 1
