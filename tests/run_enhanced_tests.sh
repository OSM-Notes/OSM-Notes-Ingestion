#!/bin/bash
# shellcheck disable=SC2310

# Enhanced Testability Test Runner
# Executes comprehensive tests for improved code testability and robustness
# Author: Andres Gomez (AngocA)
# Version: 2025-01-15

set -euo pipefail

# Colors for output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Script directory and base paths
# shellcheck disable=SC2155,SC2250
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC2155,SC2250
TEST_BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Test files to be executed
readonly ENHANCED_TESTS=(
  "tests/unit/bash/functionsProcess_enhanced.test.bats"
  "tests/unit/bash/prerequisites_enhanced.test.bats"
  "tests/unit/bash/xml_processing_enhanced.test.bats"
)

# Default options for test execution
VERBOSE=false
PARALLEL=false
FAIL_FAST=false
COVERAGE=false
MOCK_ONLY=false

# =============================================================================
# Helper functions
# =============================================================================

print_header() {
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}  Enhanced Testability Test Runner${NC}"
  echo -e "${BLUE}========================================${NC}"
  echo
}

print_success() {
  echo -e "${GREEN}✅ $*${NC}"
}

print_error() {
  echo -e "${RED}❌ $*${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $*${NC}"
}

print_info() {
  echo -e "${BLUE}ℹ️  $*${NC}"
}

show_help() {
  cat << EOF
Enhanced Testability Test Runner

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -p, --parallel      Run tests in parallel
    -f, --fail-fast     Stop on first failure
    -c, --coverage      Run with coverage analysis
    -m, --mock-only     Run only mock tests
    -a, --all           Run all enhanced tests (default)

Examples:
    $0                    # Run all enhanced tests
    $0 --verbose         # Run with verbose output
    $0 --parallel        # Run tests in parallel
    $0 --coverage        # Run with coverage analysis
    $0 --mock-only       # Run only mock tests

Test Files:
    - functionsProcess_enhanced.test.bats
    - prerequisites_enhanced.test.bats
    - xml_processing_enhanced.test.bats
EOF
}

check_prerequisites() {
  print_info "Checking prerequisites..."

  # Check if BATS testing framework is available
  if ! command -v bats &> /dev/null; then
    print_error "BATS is not installed. Please install it first."
    exit 1
  fi

  # Check if all test files exist
  for test_file in "${ENHANCED_TESTS[@]}"; do
    if [[ ! -f "${TEST_BASE_DIR}/${test_file}" ]]; then
      print_error "Test file not found: ${test_file}"
      exit 1
    fi
  done

  # Create test directories
  mkdir -p "${TEST_BASE_DIR}/tests/tmp"
  mkdir -p "${TEST_BASE_DIR}/tests/tmp/mock_tools"

  print_success "Prerequisites check passed"
}

run_single_test() {
  local test_file="$1"
  local test_name
  test_name=$(basename "${test_file}" .bats)

  print_info "Running ${test_name}..."

  local bats_args=()

  if [[ "${VERBOSE}" == true ]]; then
    bats_args+=("--verbose")
  fi

  if [[ "${FAIL_FAST}" == true ]]; then
    bats_args+=("--fail-fast")
  fi

  if [[ "${PARALLEL}" == true ]]; then
    bats_args+=("--jobs" "4")
  fi

  # Run the test
  if bats "${bats_args[@]}" "${TEST_BASE_DIR}/${test_file}"; then
    print_success "${test_name} passed"
    return 0
  else
    print_error "${test_name} failed"
    return 1
  fi
}

run_coverage_analysis() {
  print_info "Running coverage analysis..."

  # Check if kcov is available
  if ! command -v kcov &> /dev/null; then
    print_warning "kcov not available, skipping coverage analysis"
    return 0
  fi

  # Create coverage directory
  local coverage_dir="${TEST_BASE_DIR}/tests/coverage_enhanced"
  mkdir -p "${coverage_dir}"

  # Run tests with coverage
  for test_file in "${ENHANCED_TESTS[@]}"; do
    local test_name
    test_name=$(basename "${test_file}" .bats)
    local test_coverage_dir="${coverage_dir}/${test_name}"

    print_info "Running coverage for ${test_name}..."

    kcov --include-path="${TEST_BASE_DIR}/bin" \
      --exclude-path="${TEST_BASE_DIR}/tests" \
      --output-dir="${test_coverage_dir}" \
      bats "${TEST_BASE_DIR}/${test_file}"
  done

  print_success "Coverage analysis completed"
  print_info "Coverage reports available in: ${coverage_dir}"
}

run_mock_tests() {
  print_info "Running mock tests only..."

  # Create mock environment
  setup_mock_environment

  # Run tests that use mocks
  for test_file in "${ENHANCED_TESTS[@]}"; do
    local test_name
    test_name=$(basename "${test_file}" .bats)

    # Filter tests that contain "mock" in their names
    if bats --list "${TEST_BASE_DIR}/${test_file}" | grep -q "mock"; then
      print_info "Running mock tests from ${test_name}..."
      run_single_test "${test_file}"
    fi
  done

  # Clean up mock environment
  cleanup_mock_environment
}

setup_mock_environment() {
  print_info "Setting up mock environment..."

  local mock_dir="${TEST_BASE_DIR}/tests/tmp/mock_tools"
  mkdir -p "${mock_dir}"

  # Create mock tools
  create_mock_tools "${mock_dir}"

  # Add mock directory to PATH
  export PATH="${mock_dir}:${PATH}"
}

cleanup_mock_environment() {
  print_info "Cleaning up mock environment..."

  local mock_dir="${TEST_BASE_DIR}/tests/tmp/mock_tools"
  rm -rf "${mock_dir}"
}

create_mock_tools() {
  local mock_dir="$1"

  # Mock xmlstarlet
  cat > "${mock_dir}/xmlstarlet" << 'EOF'
#!/bin/bash
if [[ "$1" == "sel" ]] && [[ "$2" == "-t" ]] && [[ "$3" == "-v" ]]; then
    if [[ "$4" == "count(/osm/note)" ]]; then
        echo "2"
    elif [[ "$4" == "count(/osm-notes/note)" ]]; then
        echo "1"
    else
        echo "0"
    fi
else
    echo "Invalid arguments" >&2
    exit 1
fi
EOF
  chmod +x "${mock_dir}/xmlstarlet"

  # Mock xsltproc
  cat > "${mock_dir}/xsltproc" << 'EOF'
#!/bin/bash
if [[ "$1" == "-o" ]]; then
    # Create output file
    echo "id,lon,lat,date_created,status" > "$2"
    echo "123456,-3.7038,40.4168,2025-01-15 10:30:00 UTC,closed" >> "$2"
    echo "0"
else
    echo "0"
fi
EOF
  chmod +x "${mock_dir}/xsltproc"

  # Mock psql
  cat > "${mock_dir}/psql" << 'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "psql (PostgreSQL) 15.1"
elif [[ "$1" == "-d" ]] && [[ "$2" == "test_db" ]]; then
    if [[ "$3" == "-c" ]] && [[ "$4" == "SELECT PostGIS_version();" ]]; then
        echo "3.3.2"
    elif [[ "$3" == "-c" ]] && [[ "$4" == "SELECT COUNT(1) FROM pg_extension WHERE extname = 'btree_gist';" ]]; then
        echo "1"
    else
        echo "1"
    fi
else
    echo "1"
fi
EOF
  chmod +x "${mock_dir}/psql"

  # Mock wget
  cat > "${mock_dir}/wget" << 'EOF'
#!/bin/bash
if [[ "$1" == "--version" ]]; then
    echo "GNU Wget 1.21.3"
elif [[ "$1" == "--timeout=10" ]]; then
    echo "HTTP/1.1 200 OK"
else
    echo "HTTP/1.1 200 OK"
fi
EOF
  chmod +x "${mock_dir}/wget"
}

# =============================================================================
# Main execution
# =============================================================================

main() {
  print_header

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
    -h | --help)
      show_help
      exit 0
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    -p | --parallel)
      PARALLEL=true
      shift
      ;;
    -f | --fail-fast)
      FAIL_FAST=true
      shift
      ;;
    -c | --coverage)
      COVERAGE=true
      shift
      ;;
    -m | --mock-only)
      MOCK_ONLY=true
      shift
      ;;
    -a | --all)
      # Default behavior
      shift
      ;;
    *)
      print_error "Unknown option: $1"
      show_help
      exit 1
      ;;
    esac
  done

  # Check prerequisites
  check_prerequisites

  # Change to test base directory
  cd "${TEST_BASE_DIR}"

  # Run tests based on options
  if [[ "${MOCK_ONLY}" == true ]]; then
    run_mock_tests
  elif [[ "${COVERAGE}" == true ]]; then
    run_coverage_analysis
  else
    # Run all enhanced tests
    print_info "Running all enhanced tests..."

    local failed_tests=0

    for test_file in "${ENHANCED_TESTS[@]}"; do
      if ! run_single_test "${test_file}"; then
        ((failed_tests++))
      fi
    done

    # Summary
    echo
    print_header
    if [[ ${failed_tests} -eq 0 ]]; then
      print_success "All enhanced tests passed!"
    else
      print_error "${failed_tests} test suite(s) failed"
      exit 1
    fi
  fi
}

# Run main function
main "$@"
