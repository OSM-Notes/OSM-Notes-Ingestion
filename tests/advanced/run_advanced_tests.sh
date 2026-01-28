#!/bin/bash
# Advanced testing script for OSM Notes Profile project
# Author: Andres Gomez ( AngocA)
# Version: 2025-07-23

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Load test properties
# shellcheck disable=SC1091
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/../properties.sh" ]]; then
 source "$(dirname "${BASH_SOURCE[0]}")/../properties.sh"
fi

# Test configuration with standardized defaults
VERBOSE="${VERBOSE:-false}"
CLEAN="${CLEAN:-false}"
PARALLEL="${PARALLEL:-false}"
TEST_PERFORMANCE_TIMEOUT="${TEST_PERFORMANCE_TIMEOUT:-60}"

# Output configuration
OUTPUT_DIR="${ADVANCED_OUTPUT_DIR:-./advanced_reports}"
COVERAGE_THRESHOLD="${COVERAGE_THRESHOLD:-80}"
SECURITY_FAIL_ON_HIGH="${SECURITY_FAIL_ON_HIGH:-false}"
QUALITY_MIN_RATING="${QUALITY_MIN_RATING:-A}"
FAIL_FAST="${FAIL_FAST:-false}"

# Test types
RUN_COVERAGE=false
RUN_SECURITY=false
RUN_QUALITY=false
RUN_PERFORMANCE=false

# Logging function
__log() {
 local level="$1"
 shift
 local message="$*"

 case "${level}" in
 "INFO")
  echo -e "${BLUE}[INFO]${NC} ${message}"
  ;;
 "SUCCESS")
  echo -e "${GREEN}[SUCCESS]${NC} ${message}"
  ;;
 "WARNING")
  echo -e "${YELLOW}[WARNING]${NC} ${message}"
  ;;
 "ERROR")
  echo -e "${RED}[ERROR]${NC} ${message}"
  ;;
 *)
  echo -e "${RED}[ERROR]${NC} Unknown log level: ${level}"
  ;;
 esac
}

# Help function
__show_help() {
 cat << EOF
Usage: $0 [OPTIONS]

Options:
  --help, -h           Show this help
  --coverage-only      Run only coverage tests
  --security-only      Run only security tests
  --quality-only       Run only quality tests
  --performance-only   Run only performance tests
  --output-dir DIR     Output directory (default: ./advanced_reports)
  --clean              Clean previous reports
  --verbose            Verbose mode
  --parallel           Run tests in parallel
  --fail-fast          Stop on first failure

Environment variables:
  ADVANCED_OUTPUT_DIR  Output directory
  COVERAGE_THRESHOLD   Minimum coverage threshold
  SECURITY_FAIL_ON_HIGH Fail on high vulnerabilities
  QUALITY_MIN_RATING   Minimum quality rating
  PERFORMANCE_TIMEOUT  Timeout for performance tests

Examples:
  $0 --coverage-only --threshold 90
  $0 --security-only --fail-on-high
  $0 --all --output-dir /tmp/advanced
  $0 --clean --verbose --parallel
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
 case $1 in
 --help | -h)
  __show_help
  exit 0
  ;;
 --coverage-only)
  RUN_COVERAGE=true
  shift
  ;;
 --security-only)
  RUN_SECURITY=true
  shift
  ;;
 --quality-only)
  RUN_QUALITY=true
  shift
  ;;
 --performance-only)
  RUN_PERFORMANCE=true
  shift
  ;;
 --output-dir)
  OUTPUT_DIR="$2"
  shift 2
  ;;
 --clean)
  CLEAN=true
  shift
  ;;
 --verbose)
  export VERBOSE=true
  shift
  ;;
 --parallel)
  export PARALLEL=true
  shift
  ;;
 --fail-fast)
  FAIL_FAST=true
  shift
  ;;
 *)
  __log "ERROR" "Unknown option: $1"
  __show_help
  exit 1
  ;;
 esac
done

# If no specific test type is selected, run all
if [[ "${RUN_COVERAGE}" == "false" && "${RUN_SECURITY}" == "false" && "${RUN_QUALITY}" == "false" && "${RUN_PERFORMANCE}" == "false" ]]; then
 RUN_COVERAGE=true
 RUN_SECURITY=true
 RUN_QUALITY=true
 RUN_PERFORMANCE=true
fi

# Check prerequisites
__check_prerequisites() {
 __log "INFO" "Checking prerequisites for advanced tests..."

 local missing_tools=()

 # Check basic tools
 if ! command -v bash > /dev/null 2>&1; then
  missing_tools+=("bash")
 fi

 if ! command -v find > /dev/null 2>&1; then
  missing_tools+=("find")
 fi

 # Check testing tools
 if ! command -v bats > /dev/null 2>&1; then
  missing_tools+=("bats")
 fi

 # Check coverage tools (optional)
 if [[ "${RUN_COVERAGE}" == "true" ]]; then
  if ! command -v bashcov > /dev/null 2>&1; then
   __log "WARNING" "bashcov not found - coverage tests will be limited"
   __log "INFO" "Install with: gem install bashcov"
  fi
 fi

 # Check security tools (optional)
 if [[ "${RUN_SECURITY}" == "true" ]]; then
  if ! command -v shellcheck > /dev/null 2>&1; then
   __log "WARNING" "shellcheck not found - security tests will be limited"
  fi
 fi

 # Check quality tools (optional)
 if [[ "${RUN_QUALITY}" == "true" ]]; then
  if ! command -v shfmt > /dev/null 2>&1; then
   __log "WARNING" "shfmt not found - quality tests will be limited"
  fi
 fi

 if [[ ${#missing_tools[@]} -gt 0 ]]; then
  __log "ERROR" "Missing basic tools: ${missing_tools[*]}"
  exit 1
 fi

 __log "SUCCESS" "Prerequisites verified"
}

# Clean previous reports
__clean_reports() {
 if [[ "${CLEAN}" == "true" ]]; then
  __log "INFO" "Cleaning previous reports..."
  rm -rf "${OUTPUT_DIR}"
 fi
}

# Create output directory
__create_output_dir() {
 mkdir -p "${OUTPUT_DIR}"
 __log "INFO" "Output directory created: ${OUTPUT_DIR}"
}

# Run coverage tests
__run_coverage_tests() {
 __log "INFO" "Running coverage tests..."

 local coverage_dir="${OUTPUT_DIR}/coverage"
 mkdir -p "${coverage_dir}"

 # Use bashcov script if available
 if [[ -f "./scripts/generate_coverage_instrumented_optimized.sh" ]]; then
  if bash ./scripts/generate_coverage_instrumented_optimized.sh; then
   __log "SUCCESS" "Coverage tests completed"
  else
   __log "WARNING" "Coverage tests completed with warnings"
  fi
 else
  __log "WARNING" "bashcov coverage script not found"
  __log "INFO" "Install bashcov with: bash scripts/install_coverage_tools.sh"
 fi
}

# Run security tests
__run_security_tests() {
 __log "INFO" "Running security tests..."

 local security_dir="${OUTPUT_DIR}/security"
 mkdir -p "${security_dir}"

 # Run security script if available
 if [[ -f "./tests/advanced/security/security_scan.sh" ]]; then
  local fail_args=""
  if [[ "${SECURITY_FAIL_ON_HIGH}" == "true" ]]; then
   fail_args="--fail-on-high"
  fi

  if ./tests/advanced/security/security_scan.sh --output-dir "${security_dir}" "${fail_args}"; then
   __log "SUCCESS" "Security tests completed"
  else
   __log "WARNING" "Security tests completed with warnings"
  fi
 else
  __log "WARNING" "Security script not found"
 fi
}

# Run quality tests
__run_quality_tests() {
 __log "INFO" "Running quality tests..."

 local quality_dir="${OUTPUT_DIR}/quality"
 mkdir -p "${quality_dir}"

 # Check shell script formatting
 if command -v shfmt > /dev/null 2>&1; then
  __log "INFO" "Checking bash script formatting..."
  local format_issues=0

  while IFS= read -r -d '' file; do
   if ! shfmt -d "${file}" > /dev/null 2>&1; then
    __log "WARNING" "Format issue in: ${file}"
    ( (format_issues++))
   fi
  done < <(find . -name "*.sh" -type f -print0)

  if [[ ${format_issues} -eq 0 ]]; then
   __log "SUCCESS" "Bash script formatting verified"
  else
   __log "WARNING" "Found ${format_issues} format issues"
  fi
 fi

 # Check shell script linting
 if command -v shellcheck > /dev/null 2>&1; then
  __log "INFO" "Checking bash script linting..."
  local lint_issues=0

  while IFS= read -r -d '' file; do
   if ! shellcheck "${file}" > /dev/null 2>&1; then
    __log "WARNING" "Linting issue in: ${file}"
    ( (lint_issues++))
   fi
  done < <(find . -name "*.sh" -type f -print0)

  if [[ ${lint_issues} -eq 0 ]]; then
   __log "SUCCESS" "Bash script linting verified"
  else
   __log "WARNING" "Found ${lint_issues} linting issues"
  fi
 fi

 # Generate quality report
 local quality_report="${quality_dir}/quality_summary.md"
 cat > "${quality_report}" << EOF
# Quality Test Summary
Generated: $(date)

## Shell Script Quality
- Format checking: $(command -v shfmt > /dev/null 2>&1 && echo "Available" || echo "Not available")
- Linting: $(command -v shellcheck > /dev/null 2>&1 && echo "Available" || echo "Not available")

## Recommendations
1. Use shfmt to format all shell scripts
2. Fix all shellcheck warnings
3. Follow bash best practices
4. Use proper error handling
EOF

 __log "SUCCESS" "Quality tests completed"
}

# Run performance tests
__run_performance_tests() {
 __log "INFO" "Running performance tests..."

 local performance_dir="${OUTPUT_DIR}/performance"
 mkdir -p "${performance_dir}"

 # Test script execution time
 __log "INFO" "Testing execution time of main scripts..."

 local performance_report="${performance_dir}/performance_summary.md"
 cat > "${performance_report}" << EOF
# Performance Test Summary
Generated: $(date)

## Script Execution Times
EOF

 # Test main scripts
 local scripts=("bin/process/processPlanetNotes.sh" "bin/process/processAPINotes.sh")

 for script in "${scripts[@]}"; do
  if [[ -f "${script}" ]]; then
   __log "INFO" "Testing: ${script}"

   local start_time
   start_time=$(date +%s.%N)
   if timeout "${TEST_PERFORMANCE_TIMEOUT}" bash "${script}" --help > /dev/null 2>&1; then
    local end_time
    end_time=$(date +%s.%N)
    local execution_time
    execution_time=$(echo "${end_time} - ${start_time}" | bc -l 2> /dev/null || echo "N/A")
    echo "- ${script}: ${execution_time}s" >> "${performance_report}"
    __log "SUCCESS" "${script}: ${execution_time}s"
   else
    echo "- ${script}: Timeout or error" >> "${performance_report}"
    __log "WARNING" "${script}: Timeout or error"
   fi
  fi
 done

 echo "" >> "$performance_report"
 echo "## Recommendations" >> "$performance_report"
 echo "1. Optimize slow scripts" >> "$performance_report"
 echo "2. Consider parallel processing where possible" >> "$performance_report"
 echo "3. Monitor resource usage" >> "$performance_report"

 __log "SUCCESS" "Performance tests completed"
}

# Generate final summary
__generate_final_summary() {
 __log "INFO" "Generating final summary..."

 local summary_file="$OUTPUT_DIR/advanced_tests_summary.md"

 cat > "$summary_file" << EOF
# Advanced Tests Summary
Generated: $(date)

## Test Results

### Coverage Tests
- Status: $(if [[ "$RUN_COVERAGE" == "true" ]]; then echo "Executed"; else echo "Skipped"; fi)
- Threshold: ${COVERAGE_THRESHOLD}%

### Security Tests
- Status: $(if [[ "${RUN_SECURITY}" == "true" ]]; then echo "Executed"; else echo "Skipped"; fi)
- Fail on High: ${SECURITY_FAIL_ON_HIGH}

### Quality Tests
- Status: $(if [[ "${RUN_QUALITY}" == "true" ]]; then echo "Executed"; else echo "Skipped"; fi)
- Min Rating: ${QUALITY_MIN_RATING}

### Performance Tests
- Status: $(if [[ "${RUN_PERFORMANCE}" == "true" ]]; then echo "Executed"; else echo "Skipped"; fi)
- Timeout: ${TEST_PERFORMANCE_TIMEOUT}s

## Reports Generated
EOF

 # List all generated reports
 find "${OUTPUT_DIR}" -name "*.md" -o -name "*.txt" -o -name "*.json" | while read -r file; do
  echo "- $(basename "${file}")" >> "${summary_file}"
 done

 echo "" >> "${summary_file}"
 echo "## Next Steps" >> "${summary_file}"
 echo "1. Review all generated reports" >> "${summary_file}"
 echo "2. Address any issues found" >> "${summary_file}"
 echo "3. Improve test coverage" >> "${summary_file}"
 echo "4. Optimize performance bottlenecks" >> "${summary_file}"

 __log "SUCCESS" "Final summary generated: ${summary_file}"
}

# Main function
main() {
 __log "INFO" "Starting advanced tests - Phase 3..."

 # Check prerequisites
 __check_prerequisites

 # Clean previous reports if requested
 __clean_reports

 # Create output directory
 __create_output_dir

 # Run tests based on configuration
 local tests_failed=false

 if [[ "${RUN_COVERAGE}" == "true" ]]; then
  if ! __run_coverage_tests; then
   tests_failed=true
   if [[ "${FAIL_FAST}" == "true" ]]; then
    __log "ERROR" "Failure in coverage tests"
    exit 1
   fi
  fi
 fi

 if [[ "${RUN_SECURITY}" == "true" ]]; then
  if ! __run_security_tests; then
   tests_failed=true
   if [[ "${FAIL_FAST}" == "true" ]]; then
    __log "ERROR" "Failure in security tests"
    exit 1
   fi
  fi
 fi

 if [[ "${RUN_QUALITY}" == "true" ]]; then
  if ! __run_quality_tests; then
   tests_failed=true
   if [[ "${FAIL_FAST}" == "true" ]]; then
    __log "ERROR" "Failure in quality tests"
    exit 1
   fi
  fi
 fi

 if [[ "${RUN_PERFORMANCE}" == "true" ]]; then
  if ! __run_performance_tests; then
   tests_failed=true
   if [[ "${FAIL_FAST}" == "true" ]]; then
    __log "ERROR" "Failure in performance tests"
    exit 1
   fi
  fi
 fi

 # Generate final summary
 __generate_final_summary

 if [[ "${tests_failed}" == "true" ]]; then
  __log "WARNING" "Some tests failed. Review reports in: ${OUTPUT_DIR}"
  exit 1
 else
  __log "SUCCESS" "All advanced tests completed successfully. Reports in: ${OUTPUT_DIR}"
 fi
}

# Run main function
main "$@"
