#!/bin/bash

# Script to run GitHub Actions CI tests locally
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
 echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
 echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
 echo -e "${RED}[ERROR]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

# Check if running in CI environment
if [[ -n "${CI:-}" ]]; then
 log_info "Running in CI environment"
else
 log_info "Running locally - simulating CI environment"
fi

# Check if act is available and user wants to use it
USE_ACT="${USE_ACT:-auto}"

if [[ "${USE_ACT}" == "auto" ]] || [[ "${USE_ACT}" == "true" ]]; then
 # Check if act is installed
 if command -v act >/dev/null 2>&1; then
  # Check if act is available
  export PATH="${HOME}/.local/bin:${PATH}"
  if command -v act &> /dev/null || [[ -f "${HOME}/.local/bin/act" ]]; then
   log_info "Using act to run GitHub Actions workflows..."
   log_info "To run tests manually instead, set USE_ACT=false"
   
   # Parse arguments for act
   ACT_JOB_NAME=""
   ACT_EVENT="push"
   ACT_ARGS=()
   
   # Check for job name in arguments
   while [[ $# -gt 0 ]]; do
    case "${1}" in
     --job | -j)
      ACT_JOB_NAME="${2:-}"
      shift 2
      ;;
     --event | -e)
      ACT_EVENT="${2:-}"
      shift 2
      ;;
     --all | -a)
      ACT_JOB_NAME="all"
      shift
      ;;
     *)
      if [[ -z "${ACT_JOB_NAME}" ]]; then
       ACT_JOB_NAME="${1}"
      else
       ACT_ARGS+=("${1}")
      fi
      shift
      ;;
    esac
   done
   
   # Run with act directly
   log_info "Running act with job: ${ACT_JOB_NAME:-quick-checks}"
   log_info "Event: ${ACT_EVENT}"
   
   # Create event JSON file
   cat > /tmp/act_event.json << 'EOF'
{
  "push": {
    "ref": "refs/heads/main"
  }
}
EOF
   
   # Build act command as array
   ACT_CMD_ARRAY=(
     act
     -W .github/workflows/ci.yml
     --eventpath /tmp/act_event.json
   )
   
   if [[ -n "${ACT_JOB_NAME}" ]] && [[ "${ACT_JOB_NAME}" != "all" ]]; then
    ACT_CMD_ARRAY+=(--job "${ACT_JOB_NAME}")
   else
    # Warning: Running all jobs may cause port conflicts with PostgreSQL
    # Multiple Unit Tests jobs will try to use port 5432 simultaneously
    log_warning "Running all jobs - this may cause PostgreSQL port conflicts"
    log_warning "Multiple Unit Tests jobs will try to use port 5432 simultaneously"
    log_info "To avoid conflicts, run specific jobs: --job quick-checks"
    log_info "Or use USE_ACT=false to run tests without act simulation"
   fi
   
   # Add any additional arguments
   if [[ ${#ACT_ARGS[@]} -gt 0 ]]; then
    ACT_CMD_ARRAY+=("${ACT_ARGS[@]}")
   fi
   
   log_info "Executing: ${ACT_CMD_ARRAY[*]}"
   "${ACT_CMD_ARRAY[@]}"
   
   exit $?
  else
   log_warning "act not found, falling back to manual test execution"
   log_info "To install act: https://github.com/nektos/act"
  fi
 else
  log_warning "GitHub Actions runner script not found, using manual execution"
 fi
fi

if [[ "${USE_ACT}" == "false" ]]; then
 log_info "Using manual test execution (USE_ACT=false)"
fi

# ============================================================================
# STAGE 1: Quick Quality Checks
# ============================================================================
log_info "=== STAGE 1: Quick Quality Checks ==="

# Check if shellcheck is available
if ! command -v shellcheck > /dev/null 2>&1; then
 log_warning "shellcheck not found, installing..."
 if command -v apt-get > /dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y shellcheck
 else
  log_error "shellcheck not available and cannot install automatically"
  exit 1
 fi
fi

# Check if shfmt is available
if ! command -v shfmt > /dev/null 2>&1; then
 log_warning "shfmt not found, installing..."
 if [[ -f "${SCRIPT_DIR}/install_shfmt.sh" ]]; then
  chmod +x "${SCRIPT_DIR}/install_shfmt.sh"
  "${SCRIPT_DIR}/install_shfmt.sh"
 else
  log_error "shfmt installer not found"
  exit 1
 fi
fi

# Run shellcheck
log_info "Running shellcheck on bash scripts..."
if find bin -name "*.sh" -type f -exec shellcheck -x -o all {} \; 2>&1 | tee /tmp/shellcheck.log; then
 log_success "shellcheck passed"
else
 log_error "shellcheck found issues"
 cat /tmp/shellcheck.log
 exit 1
fi

# Check code formatting with shfmt
log_info "Checking bash code formatting..."
if find bin -name "*.sh" -type f -exec shfmt -d -i 1 -sr -bn {} \; 2>&1 | tee /tmp/shfmt.log; then
 log_success "Code formatting check passed"
else
 if grep -q "diff" /tmp/shfmt.log; then
  log_error "Code formatting issues found"
  cat /tmp/shfmt.log
  exit 1
 else
  log_success "Code formatting check passed"
 fi
fi

# Check for trailing whitespace
log_info "Checking for trailing whitespace..."
if find bin -name "*.sh" -type f -exec grep -l " $" {} \; 2> /dev/null | tee /tmp/trailing_ws.log; then
 log_error "Trailing whitespace found"
 cat /tmp/trailing_ws.log
 exit 1
else
 log_success "No trailing whitespace found"
fi

# Verify proper shebang
log_info "Verifying proper shebang..."
if ! find bin -name "*.sh" -type f -exec head -1 {} \; | grep -q "#!/bin/bash"; then
 log_error "Some scripts don't have proper shebang"
 exit 1
else
 log_success "All scripts have proper shebang"
fi

# ============================================================================
# STAGE 2: Unit Tests
# ============================================================================
log_info "=== STAGE 2: Unit Tests ==="

# Setup Node.js
log_info "Setting up Node.js..."
if ! command -v node > /dev/null 2>&1; then
 log_warning "Node.js not found"
 if command -v nvm > /dev/null 2>&1; then
  log_info "Using nvm to install Node.js..."
  source ~/.nvm/nvm.sh || true
  nvm install 20 || nvm use 20 || true
 else
  log_warning "nvm not found, trying to install Node.js via package manager..."
  if command -v apt-get > /dev/null 2>&1; then
   curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
   sudo apt-get install -y nodejs
  else
   log_error "Cannot install Node.js automatically"
   exit 1
  fi
 fi
fi

log_info "Node.js version: $(node --version 2> /dev/null || echo 'not available')"

# Install dependencies
log_info "Installing system dependencies..."
if command -v apt-get > /dev/null 2>&1; then
 sudo apt-get update
 sudo apt-get install -y \
  bats \
  postgresql-client \
  libxml2-utils \
  awk \
  curl || log_warning "Some packages may not be installed"
else
 log_warning "apt-get not available, assuming dependencies are installed"
fi

# Install Node.js tools
log_info "Installing Node.js tools (ajv-cli)..."
if command -v npm > /dev/null 2>&1; then
 npm install -g ajv-cli || log_warning "Failed to install ajv-cli globally, trying locally..."
 if ! command -v ajv > /dev/null 2>&1; then
  log_warning "ajv-cli not in PATH, checking local installation..."
  if [[ -d node_modules/.bin ]] && [[ -f node_modules/.bin/ajv ]]; then
   export PATH="${PROJECT_ROOT}/node_modules/.bin:${PATH}"
  fi
 fi
else
 log_warning "npm not available"
fi

# Install shfmt if not already installed
if ! command -v shfmt > /dev/null 2>&1; then
 log_info "Installing shfmt..."
 if [[ -f "${SCRIPT_DIR}/install_shfmt.sh" ]]; then
  chmod +x "${SCRIPT_DIR}/install_shfmt.sh"
  "${SCRIPT_DIR}/install_shfmt.sh"
 fi
fi

# Setup test environment
log_info "Setting up test environment..."
mkdir -p tests/tmp
mkdir -p tests/results
chmod +x tests/run_integration_tests.sh 2> /dev/null || true

# Verify tools availability
log_info "Verifying required tools..."
command -v awk > /dev/null 2>&1 && log_success "✓ awk available" || log_warning "✗ awk not available"
command -v xmllint > /dev/null 2>&1 && log_success "✓ xmllint available" || log_warning "✗ xmllint not available"
command -v shfmt > /dev/null 2>&1 && log_success "✓ shfmt available" || log_warning "✗ shfmt not available"
command -v shellcheck > /dev/null 2>&1 && log_success "✓ shellcheck available" || log_warning "✗ shellcheck not available"
command -v bats > /dev/null 2>&1 && log_success "✓ bats available" || log_warning "✗ bats not available"
command -v psql > /dev/null 2>&1 && log_success "✓ psql available" || log_warning "✗ psql not available"
command -v ajv > /dev/null 2>&1 && log_success "✓ ajv available" || log_warning "✗ ajv not available"

# Check PostgreSQL availability
log_info "Checking PostgreSQL availability..."
if command -v psql > /dev/null 2>&1; then
 # Try to connect to PostgreSQL
 if psql -h localhost -p 5432 -U postgres -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
  log_success "PostgreSQL is accessible"
 elif psql -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
  log_success "PostgreSQL is accessible (local connection)"
 else
  log_warning "PostgreSQL may not be accessible - some tests may be skipped"
  log_info "To start PostgreSQL: sudo systemctl start postgresql"
 fi
else
 log_warning "psql not available - database tests will be skipped"
fi

# Wait for PostgreSQL if available
if command -v pg_isready > /dev/null 2>&1; then
 log_info "Waiting for PostgreSQL..."
 if pg_isready -h localhost -p 5432 -U postgres > /dev/null 2>&1; then
  log_success "PostgreSQL is ready"
 elif pg_isready > /dev/null 2>&1; then
  log_success "PostgreSQL is ready (local)"
 else
  log_warning "PostgreSQL is not ready - some tests may fail"
 fi
fi

# Run unit tests
log_info "Running unit tests..."
export TEST_DBNAME="${TEST_DBNAME:-osm_notes_test}"
export TEST_DBUSER="${TEST_DBUSER:-postgres}"
export TEST_DBPASSWORD="${TEST_DBPASSWORD:-postgres}"
export TEST_DBHOST="${TEST_DBHOST:-localhost}"
export TEST_DBPORT="${TEST_DBPORT:-5432}"
export DBNAME="${DBNAME:-osm_notes_test}"
export DB_USER="${DB_USER:-postgres}"
export DBPASSWORD="${DBPASSWORD:-postgres}"
export DBHOST="${DBHOST:-localhost}"
export DBPORT="${DBPORT:-5432}"
export LOG_LEVEL="${LOG_LEVEL:-INFO}"
export MAX_THREADS="${MAX_THREADS:-2}"

if bats tests/unit/bash/ 2>&1 | tee tests/results/unit-tests.log; then
 log_success "Unit tests passed"
else
 log_error "Unit tests failed"
 log_info "Check tests/results/unit-tests.log for details"
 exit 1
fi

log_success "=== All CI tests completed successfully! ==="
