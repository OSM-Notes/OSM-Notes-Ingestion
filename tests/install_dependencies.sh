#!/bin/bash

# Install dependencies for OSM-Notes-profile tests
# Author: Andres Gomez (AngocA)
# Version: 2025-07-28

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

# Function to check if command exists
command_exists() {
 command -v "$1" >/dev/null 2>&1
}

# Function to install package manager dependencies
install_system_deps() {
 log_info "Installing system dependencies..."
 
 # Detect package manager
 if command_exists apt-get; then
  # Ubuntu/Debian
  log_info "Using apt-get package manager"
  
  # Try without sudo first
  if apt-get update &> /dev/null; then
   log_info "Installing packages without sudo..."
   apt-get install -y postgresql-client bats pgtap libxml2-dev libxslt1-dev xsltproc
  else
   log_warning "apt-get requires sudo, trying with sudo..."
   sudo apt-get update
   sudo apt-get install -y postgresql-client bats pgtap libxml2-dev libxslt1-dev xsltproc
  fi
 elif command_exists yum; then
  # CentOS/RHEL
  log_info "Using yum package manager"
  sudo yum install -y postgresql bats libxml2-devel libxslt-devel xsltproc
 elif command_exists dnf; then
  # Fedora
  log_info "Using dnf package manager"
  sudo dnf install -y postgresql bats libxml2-devel libxslt-devel xsltproc
 else
  log_error "Unsupported package manager"
  log_info "Please install the following packages manually:"
  log_info "  - postgresql-client"
  log_info "  - bats"
  log_info "  - pgtap (or equivalent)"
  log_info "  - libxml2-dev"
  log_info "  - libxslt1-dev"
  log_info "  - xsltproc"
  exit 1
 fi
}

# Function to install Python dependencies
install_python_deps() {
 log_info "Installing Python dependencies..."
 
 if command_exists pip3; then
  pip3 install requests pytest pytest-mock
 elif command_exists pip; then
  pip install requests pytest pytest-mock
 else
  log_warning "pip not found, skipping Python dependencies"
 fi
}

# Function to setup Docker without sudo
setup_docker() {
 log_info "Setting up Docker access..."
 
 if command_exists docker; then
  # Check if user is in docker group
  if groups | grep -q docker; then
   log_success "User is already in docker group"
  else
   log_warning "User is not in docker group"
   log_info "To run Docker without sudo, add your user to the docker group:"
   log_info "  sudo usermod -aG docker $USER"
   log_info "  Then log out and log back in"
  fi
 else
  log_warning "Docker not found"
  log_info "To install Docker, visit: https://docs.docker.com/get-docker/"
 fi
}

# Function to setup PostgreSQL access
setup_postgresql() {
 log_info "Setting up PostgreSQL access..."
 
 if command_exists psql; then
  log_success "PostgreSQL client is available"
 else
  log_error "PostgreSQL client not found"
  log_info "Please install postgresql-client package"
  exit 1
 fi
 
 # Test PostgreSQL connection
 if psql -d postgres -c "SELECT 1;" >/dev/null 2>&1; then
  log_success "PostgreSQL connection successful"
 else
  log_warning "PostgreSQL connection failed"
  log_info "Please ensure PostgreSQL is running and accessible"
  log_info "You may need to configure pg_hba.conf for local connections"
 fi
}

# Main execution
main() {
 log_info "Installing dependencies for OSM-Notes-profile tests..."
 
 install_system_deps
 install_python_deps
 setup_docker
 setup_postgresql
 
 log_success "Dependency installation completed"
 log_info "You can now run tests without sudo in most cases"
}

# Run main function
main "$@"