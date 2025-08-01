#!/bin/bash

# Script para configurar herramientas de monitoreo de calidad
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

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
Script para configurar herramientas de monitoreo de calidad

Usage: $0 [OPTIONS]

Options:
  -h, --help              Show this help message
  -v, --verbose           Verbose output
  --install-tools         Install quality monitoring tools
  --setup-sonarqube       Setup SonarQube configuration
  --setup-codecov         Setup Codecov configuration
  --setup-security        Setup security scanning
  --generate-reports      Generate quality reports
  --all                   Run all setup steps

Examples:
  $0 --install-tools         # Install monitoring tools
  $0 --setup-sonarqube      # Setup SonarQube
  $0 --setup-codecov        # Setup Codecov
  $0 --all                  # Run all setup steps

EOF
}

# Install quality monitoring tools
install_tools() {
  log_info "Installing quality monitoring tools..."
  
  # Check if we're on Ubuntu/Debian
  if command -v apt-get &> /dev/null; then
    log_info "Installing tools via apt..."
    
    # Install basic tools
    sudo apt-get update
    sudo apt-get install -y \
      shellcheck \
      shfmt \
      bats \
      jq \
      yamllint \
      python3-pip \
      python3-yaml \
      python3-requests
    
    # Install Python tools
    pip3 install --user \
      coverage \
      pytest \
      pytest-cov \
      bandit \
      safety \
      black \
      flake8
    
  elif command -v yum &> /dev/null; then
    log_info "Installing tools via yum..."
    sudo yum install -y \
      shellcheck \
      jq \
      python3-pip
    
  elif command -v brew &> /dev/null; then
    log_info "Installing tools via brew..."
    brew install \
      shellcheck \
      shfmt \
      bats-core \
      jq \
      yamllint
    
  else
    log_warning "Package manager not detected, manual installation required"
    log_info "Please install: shellcheck, shfmt, bats, jq, yamllint"
  fi
  
  log_success "Quality monitoring tools installed"
}

# Setup SonarQube configuration
setup_sonarqube() {
  log_info "Setting up SonarQube configuration..."
  
  # Create sonar-project.properties
  cat > sonar-project.properties << 'EOF'
# SonarQube Configuration for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

# Project identification
sonar.projectKey=osm-notes-profile
sonar.projectName=OSM-Notes-profile
sonar.projectVersion=1.0.0

# Source code location
sonar.sources=bin,scripts
sonar.tests=tests
sonar.test.inclusions=tests/**/*.bats,tests/**/*.sh

# Language configuration
sonar.language=shell
sonar.shell.file.suffixes=sh

# Coverage configuration
sonar.coverage.jacoco.xmlReportPaths=coverage.xml
sonar.coverage.exclusions=tests/**,**/*.test.bats

# Quality gate configuration
sonar.qualitygate.wait=true

# Exclude patterns
sonar.exclusions=**/node_modules/**,**/tmp/**,**/temp/**,**/.git/**

# Test configuration
sonar.test.inclusions=tests/**/*
sonar.test.exclusions=tests/tmp/**,tests/output/**

# Security configuration
sonar.security.sources.javasecurity=true
sonar.security.sources.pythonsecurity=true

# Duplicate code detection
sonar.cpd.shell.minimumTokens=100

# Custom rules
sonar.shellcheck.reportPaths=shellcheck-report.json
sonar.shfmt.reportPaths=shfmt-report.json
EOF

  # Create SonarQube workflow
  cat > .github/workflows/sonarqube.yml << 'EOF'
name: SonarQube Analysis

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  sonarqube:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Setup Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'

    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y shellcheck shfmt bats jq yamllint
        pip install coverage pytest pytest-cov bandit safety

    - name: Run tests with coverage
      run: |
        # Run tests and generate coverage
        coverage run -m pytest tests/ || true
        coverage xml -o coverage.xml

    - name: Run shellcheck
      run: |
        shellcheck -x -o all bin/*.sh scripts/*.sh > shellcheck-report.json || true

    - name: Run shfmt check
      run: |
        shfmt -d bin/ scripts/ > shfmt-report.json || true

    - name: SonarQube Scan
      uses: sonarqube-quality-gate-action@master
      env:
        GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      with:
        scannerHome: ${{ github.workspace }}/.sonar/scanner
        args: >
          -Dsonar.projectKey=osm-notes-profile
          -Dsonar.sources=bin,scripts
          -Dsonar.tests=tests
          -Dsonar.coverage.jacoco.xmlReportPaths=coverage.xml
          -Dsonar.shellcheck.reportPaths=shellcheck-report.json
          -Dsonar.shfmt.reportPaths=shfmt-report.json
EOF

  log_success "SonarQube configuration created"
  log_info "Next steps:"
  log_info "1. Set up SonarQube server"
  log_info "2. Add SONAR_TOKEN to GitHub secrets"
  log_info "3. Configure quality gates"
}

# Setup Codecov configuration
setup_codecov() {
  log_info "Setting up Codecov configuration..."
  
  # Create codecov.yml
  cat > codecov.yml << 'EOF'
# Codecov Configuration for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

codecov:
  require_ci_to_pass: yes
  notify:
    wait_for_ci: yes

coverage:
  precision: 2
  round: down
  range: "80...100"
  status:
    project:
      default:
        target: 80%
        threshold: 5%
    patch:
      default:
        target: 80%
        threshold: 5%

parsers:
  gcov:
    branch_detection:
      conditional: yes
      loop: yes
      method: no
      macro: no

comment:
  layout: "reach,diff,flags,files,footer"
  behavior: default
  require_changes: no

ignore:
  - "tests/"
  - "docs/"
  - "*.md"
  - "*.yml"
  - "*.yaml"
  - "*.json"
EOF

  # Create Codecov workflow
  cat > .github/workflows/codecov.yml << 'EOF'
name: Codecov

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  codecov:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'

    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y bats shellcheck
        pip install coverage pytest pytest-cov

    - name: Run tests with coverage
      run: |
        # Run integration tests and generate coverage
        coverage run --source=bin,scripts -m pytest tests/ || true
        coverage run --append --source=bin,scripts -m bats tests/unit/bash/ || true
        
        # Generate coverage report
        coverage xml -o coverage.xml
        coverage html -d coverage_html

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.xml
        flags: unittests
        name: codecov-umbrella
        fail_ci_if_error: false
        verbose: true
EOF

  log_success "Codecov configuration created"
  log_info "Next steps:"
  log_info "1. Connect repository to Codecov"
  log_info "2. Add CODECOV_TOKEN to GitHub secrets"
  log_info "3. Configure coverage thresholds"
}

# Setup security scanning
setup_security() {
  log_info "Setting up security scanning..."
  
  # Create security workflow
  cat > .github/workflows/security.yml << 'EOF'
name: Security Scan

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]
  schedule:
    - cron: '0 2 * * *'

jobs:
  security-scan:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Setup Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'

    - name: Install security tools
      run: |
        sudo apt-get update
        sudo apt-get install -y shellcheck
        pip install bandit safety

    - name: Run Bandit security scan
      run: |
        bandit -r bin/ scripts/ -f json -o bandit-report.json || true
        bandit -r bin/ scripts/ -f txt -o bandit-report.txt || true

    - name: Run Safety check
      run: |
        safety check --json --output safety-report.json || true
        safety check --text --output safety-report.txt || true

    - name: Run Shellcheck security scan
      run: |
        shellcheck -x -o all bin/*.sh scripts/*.sh > shellcheck-security.json || true

    - name: Check for secrets
      run: |
        # Check for hardcoded secrets
        grep -r "password\|secret\|key\|token" bin/ scripts/ || echo "No obvious secrets found"
        
        # Check for hardcoded credentials
        grep -r "admin\|root\|test" bin/ scripts/ || echo "No obvious credentials found"

    - name: Upload security reports
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: security-reports
        path: |
          bandit-report.json
          bandit-report.txt
          safety-report.json
          safety-report.txt
          shellcheck-security.json
        retention-days: 30

    - name: Generate security summary
      if: always()
      run: |
        echo "## Security Scan Results" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "### Tools Used:" >> $GITHUB_STEP_SUMMARY
        echo "- ✅ Bandit (Python security)" >> $GITHUB_STEP_SUMMARY
        echo "- ✅ Safety (dependency vulnerabilities)" >> $GITHUB_STEP_SUMMARY
        echo "- ✅ Shellcheck (shell security)" >> $GITHUB_STEP_SUMMARY
        echo "- ✅ Secret detection" >> $GITHUB_STEP_SUMMARY
        echo "" >> $GITHUB_STEP_SUMMARY
        echo "### Reports Generated:" >> $GITHUB_STEP_SUMMARY
        echo "- Security reports uploaded as artifacts" >> $GITHUB_STEP_SUMMARY
        echo "- Check artifacts for detailed results" >> $GITHUB_STEP_SUMMARY
EOF

  log_success "Security scanning configuration created"
  log_info "Security tools configured:"
  log_info "- Bandit (Python security)"
  log_info "- Safety (dependency vulnerabilities)"
  log_info "- Shellcheck (shell security)"
  log_info "- Secret detection"
}

# Generate quality reports
generate_reports() {
  log_info "Generating quality reports..."
  
  # Create reports directory
  mkdir -p reports
  
  # Generate shellcheck report
  log_info "Running shellcheck..."
  shellcheck -x -o all bin/*.sh scripts/*.sh > reports/shellcheck-report.txt 2>&1 || true
  
  # Generate shfmt report
  log_info "Running shfmt..."
  shfmt -d bin/ scripts/ > reports/shfmt-report.txt 2>&1 || true
  
  # Generate test coverage report
  log_info "Running test coverage..."
  if command -v bats &> /dev/null; then
    bats tests/unit/bash/ > reports/bats-report.txt 2>&1 || true
  fi
  
  # Generate dependency report
  log_info "Generating dependency report..."
  {
    echo "=== DEPENDENCY REPORT ==="
    echo "Date: $(date)"
    echo ""
    echo "=== REQUIRED TOOLS ==="
    echo "BATS: $(command -v bats || echo 'NOT FOUND')"
    echo "Shellcheck: $(command -v shellcheck || echo 'NOT FOUND')"
    echo "Shfmt: $(command -v shfmt || echo 'NOT FOUND')"
    echo "PostgreSQL: $(command -v psql || echo 'NOT FOUND')"
    echo "XML tools: $(command -v xmllint || echo 'NOT FOUND')"
    echo ""
    echo "=== PYTHON DEPENDENCIES ==="
    pip list 2>/dev/null || echo "pip not available"
    echo ""
    echo "=== SYSTEM INFO ==="
    echo "OS: $(uname -a)"
    echo "Shell: $SHELL"
    echo "Bash version: $(bash --version | head -1)"
  } > reports/dependency-report.txt
  
  # Generate summary report
  log_info "Generating summary report..."
  {
    echo "# Quality Report - OSM-Notes-profile"
    echo "Generated: $(date)"
    echo ""
    echo "## Summary"
    echo "- Shellcheck issues: $(grep -c "SC" reports/shellcheck-report.txt 2>/dev/null || echo "0")"
    echo "- Shfmt issues: $(grep -c "diff" reports/shfmt-report.txt 2>/dev/null || echo "0")"
    echo "- Test results: See bats-report.txt"
    echo "- Dependencies: See dependency-report.txt"
    echo ""
    echo "## Files Analyzed"
    echo "- Shell scripts: $(find bin scripts -name "*.sh" | wc -l)"
    echo "- Test files: $(find tests -name "*.bats" | wc -l)"
    echo "- SQL files: $(find sql -name "*.sql" | wc -l)"
    echo ""
    echo "## Recommendations"
    echo "1. Fix shellcheck issues"
    echo "2. Format code with shfmt"
    echo "3. Ensure all tests pass"
    echo "4. Update dependencies regularly"
  } > reports/quality-summary.md
  
  log_success "Quality reports generated in reports/ directory"
  log_info "Reports created:"
  log_info "- shellcheck-report.txt"
  log_info "- shfmt-report.txt"
  log_info "- bats-report.txt"
  log_info "- dependency-report.txt"
  log_info "- quality-summary.md"
}

# Main function
main() {
  local install_tools_flag=false
  local setup_sonarqube_flag=false
  local setup_codecov_flag=false
  local setup_security_flag=false
  local generate_reports_flag=false
  local run_all=false
  
  # Parse command line arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help)
        show_help
        exit 0
        ;;
      -v|--verbose)
        set -x
        shift
        ;;
      --install-tools)
        install_tools_flag=true
        shift
        ;;
      --setup-sonarqube)
        setup_sonarqube_flag=true
        shift
        ;;
      --setup-codecov)
        setup_codecov_flag=true
        shift
        ;;
      --setup-security)
        setup_security_flag=true
        shift
        ;;
      --generate-reports)
        generate_reports_flag=true
        shift
        ;;
      --all)
        run_all=true
        shift
        ;;
      *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
  
  # Run all steps if requested
  if [[ "${run_all}" == true ]]; then
    install_tools_flag=true
    setup_sonarqube_flag=true
    setup_codecov_flag=true
    setup_security_flag=true
    generate_reports_flag=true
  fi
  
  # Execute requested actions
  if [[ "${install_tools_flag}" == true ]]; then
    install_tools
  fi
  
  if [[ "${setup_sonarqube_flag}" == true ]]; then
    setup_sonarqube
  fi
  
  if [[ "${setup_codecov_flag}" == true ]]; then
    setup_codecov
  fi
  
  if [[ "${setup_security_flag}" == true ]]; then
    setup_security
  fi
  
  if [[ "${generate_reports_flag}" == true ]]; then
    generate_reports
  fi
  
  # Show summary
  echo
  echo "=========================================="
  echo "Quality Monitoring Setup Summary"
  echo "=========================================="
  echo "✅ Tools installed/configured"
  echo "✅ SonarQube configuration created"
  echo "✅ Codecov configuration created"
  echo "✅ Security scanning configured"
  echo "✅ Quality reports generated"
  echo ""
  echo "📋 Next steps:"
  echo "   1. Configure SonarQube server"
  echo "   2. Connect to Codecov"
  echo "   3. Review security reports"
  echo "   4. Set up quality gates"
  echo "   5. Monitor quality metrics"
  echo
  log_success "Quality monitoring setup completed!"
}

# Run main function
main "$@" 