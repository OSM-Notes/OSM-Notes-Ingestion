#!/bin/bash

# Script para ejecutar GitHub Actions localmente usando act
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Show help
show_help() {
  cat << EOF
Script para ejecutar GitHub Actions localmente usando act

Usage: $0 [OPTIONS] [JOB_NAME]

Options:
  -h, --help              Show this help message
  -v, --verbose           Verbose output
  -l, --list              List available jobs
  -a, --all               Run all jobs
  -j, --job JOB_NAME      Run specific job
  -e, --event EVENT       Event to simulate (push, pull_request, workflow_dispatch)
  -w, --workflow FILE     Workflow file to use (default: ci.yml)

Available jobs:
  - quick-checks          Code Quality & Linting (fast)
  - unit-tests            Unit Tests (requires PostgreSQL)
  - security-scan         Security Scan
  - integration-tests-quick  Quick Integration Tests (requires PostgreSQL)
  - integration-tests-full   Full Integration Tests (requires PostgreSQL)
  - performance-tests     Performance Tests (requires PostgreSQL)
  - test-summary          Test Summary

Examples:
  $0 --list                    # List all available jobs
  $0 --job quick-checks        # Run quick checks only
  $0 --job unit-tests          # Run unit tests
  $0 --all                     # Run all jobs
  $0 --event pull_request      # Simulate pull request event

Requirements:
  - act (https://github.com/nektos/act)
  - Docker
  - PATH should include ~/.local/bin (where act is installed)

EOF
}

# Check prerequisites
check_prerequisites() {
  log_info "Checking prerequisites..."

  # Check if we're in a git repository
  if [[ ! -d ".git" ]]; then
    log_error "This is not a git repository"
    exit 1
  fi

  # Check if act is available
  if ! command -v act &> /dev/null; then
    if [[ -f "${HOME}/.local/bin/act" ]]; then
      export PATH="${HOME}/.local/bin:${PATH}"
      log_info "Using act from ~/.local/bin"
    else
      log_error "act not found. Please install it:"
      log_info "  curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash"
      log_info "  Or download from: https://github.com/nektos/act/releases"
      exit 1
    fi
  fi

  # Check if Docker is available
  if ! command -v docker &> /dev/null; then
    log_error "Docker not found. Please install Docker"
    exit 1
  fi

  # Check if Docker is running
  if ! docker info &> /dev/null; then
    log_error "Docker is not running. Please start Docker"
    exit 1
  fi

  log_success "Prerequisites check completed"
}

# List available jobs
list_jobs() {
  log_info "Listing available jobs..."
  export PATH="${HOME}/.local/bin:${PATH}"
  act --list
}

# Run specific job
run_job() {
  local job_name="${1}"
  local event="${2:-push}"
  local workflow_file="${3:-ci.yml}"

  log_info "Running job: ${job_name} with event: ${event}"
  export PATH="${HOME}/.local/bin:${PATH}"

  local act_cmd="act -j ${job_name} --container-architecture linux/amd64"
  act_cmd="${act_cmd} -P ubuntu-latest=catthehacker/ubuntu:act-latest"

  if [[ "${event}" != "push" ]]; then
    act_cmd="${act_cmd} --eventpath /tmp/act_event.json"
    # Create event JSON
    cat > /tmp/act_event.json << EOF
{
  "event_name": "${event}",
  "ref": "refs/heads/main",
  "workflow": "${workflow_file}"
}
EOF
  fi

  if [[ "${VERBOSE}" == true ]]; then
    act_cmd="${act_cmd} --verbose"
  fi

  log_info "Executing: ${act_cmd}"
  eval "${act_cmd}"
}

# Run all jobs
run_all_jobs() {
  local event="${1:-push}"
  local workflow_file="${2:-ci.yml}"

  log_info "Running all jobs with event: ${event}"
  export PATH="${HOME}/.local/bin:${PATH}"

  local act_cmd="act --container-architecture linux/amd64"
  act_cmd="${act_cmd} -P ubuntu-latest=catthehacker/ubuntu:act-latest"

  if [[ "${event}" != "push" ]]; then
    act_cmd="${act_cmd} --eventpath /tmp/act_event.json"
    # Create event JSON
    cat > /tmp/act_event.json << EOF
{
  "event_name": "${event}",
  "ref": "refs/heads/main",
  "workflow": "${workflow_file}"
}
EOF
  fi

  if [[ "${VERBOSE}" == true ]]; then
    act_cmd="${act_cmd} --verbose"
  fi

  log_info "Executing: ${act_cmd}"
  eval "${act_cmd}"
}

# Main function
main() {
  local list_jobs_flag=false
  local run_all_flag=false
  local job_name=""
  local event="push"
  local workflow_file="ci.yml"
  local verbose=false

  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h | --help)
        show_help
        exit 0
        ;;
      -v | --verbose)
        verbose=true
        set -x
        shift
        ;;
      -l | --list)
        list_jobs_flag=true
        shift
        ;;
      -a | --all)
        run_all_flag=true
        shift
        ;;
      -j | --job)
        job_name="${2}"
        shift 2
        ;;
      -e | --event)
        event="${2}"
        shift 2
        ;;
      -w | --workflow)
        workflow_file="${2}"
        shift 2
        ;;
      *)
        # Assume it's a job name if no flag
        if [[ -z "${job_name}" ]]; then
          job_name="${1}"
        else
          log_error "Unknown option: $1"
          show_help
          exit 1
        fi
        shift
        ;;
    esac
  done

  readonly VERBOSE="${verbose}"

  # Check prerequisites
  check_prerequisites

  # Execute requested action
  if [[ "${list_jobs_flag}" == true ]]; then
    list_jobs
    exit 0
  fi

  if [[ "${run_all_flag}" == true ]]; then
    run_all_jobs "${event}" "${workflow_file}"
    exit 0
  fi

  if [[ -n "${job_name}" ]]; then
    run_job "${job_name}" "${event}" "${workflow_file}"
    exit 0
  fi

  # Default: show help
  log_warning "No action specified"
  show_help
  exit 1
}

# Run main function
main "$@"

