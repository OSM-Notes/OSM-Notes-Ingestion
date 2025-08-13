#!/bin/bash

# Install shfmt for OSM-Notes-profile tests
# Author: Andres Gomez (AngocA)
# Version: 2025-08-13

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

# Function to check if shfmt is already installed
check_shfmt() {
 if command -v shfmt &> /dev/null; then
  local version
  version=$(shfmt --version 2> /dev/null || echo "unknown")
  log_success "shfmt is already installed (version: ${version})"
  return 0
 fi
 return 1
}

# Function to install shfmt from package manager
install_from_package_manager() {
 log_info "Attempting to install shfmt from package manager..."

 if command -v apt-get &> /dev/null; then
  log_info "Using apt-get package manager"
  sudo apt-get update
  sudo apt-get install -y shfmt
 elif command -v yum &> /dev/null; then
  log_info "Using yum package manager"
  sudo yum install -y shfmt
 elif command -v dnf &> /dev/null; then
  log_info "Using dnf package manager"
  sudo dnf install -y shfmt
 elif command -v brew &> /dev/null; then
  log_info "Using Homebrew package manager"
  brew install shfmt
 else
  log_warning "Unsupported package manager"
  return 1
 fi

 # Check if installation was successful
 if check_shfmt; then
  return 0
 else
  log_warning "Package manager installation failed"
  return 1
 fi
}

# Function to install shfmt from GitHub releases
install_from_github() {
 log_info "Installing shfmt from GitHub releases..."

 # Detect architecture
 local arch
 case "$(uname -m)" in
 x86_64) arch="amd64" ;;
 aarch64) arch="arm64" ;;
 armv7l) arch="arm" ;;
 *) arch="amd64" ;;
 esac

 log_info "Detected architecture: ${arch}"

 # Create temporary directory
 local temp_dir
 temp_dir=$(mktemp -d)
 cd "${temp_dir}"

 # Download latest release
 local version="v3.6.0" # Latest stable version as of 2025-08-13
 local download_url="https://github.com/mvdan/sh/releases/download/${version}/shfmt_${version}_linux_${arch}"

 log_info "Downloading shfmt ${version} for ${arch}..."
 if curl -L -o shfmt "${download_url}"; then
  log_success "Download completed"
 else
  log_error "Download failed"
  cd - > /dev/null
  rm -rf "${temp_dir}"
  return 1
 fi

 # Make executable and install
 chmod +x shfmt
 sudo mv shfmt /usr/local/bin/

 # Cleanup
 cd - > /dev/null
 rm -rf "${temp_dir}"

 # Verify installation
 if check_shfmt; then
  log_success "shfmt installed successfully from GitHub"
  return 0
 else
  log_error "Installation verification failed"
  return 1
 fi
}

# Function to install shfmt using go install
install_from_go() {
 log_info "Attempting to install shfmt using Go..."

 if ! command -v go &> /dev/null; then
  log_warning "Go is not installed, cannot use go install"
  return 1
 fi

 log_info "Installing shfmt using: go install mvdan.cc/sh/v3/cmd/shfmt@latest"
 if go install mvdan.cc/sh/v3/cmd/shfmt@latest; then
  # Add Go bin to PATH if not already there
  if [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
   echo 'export PATH="$HOME/go/bin:$PATH"' >> ~/.bashrc
   export PATH="$HOME/go/bin:$PATH"
  fi

  if check_shfmt; then
   log_success "shfmt installed successfully using Go"
   return 0
  else
   log_warning "Go installation completed but shfmt not found in PATH"
   return 1
  fi
 else
  log_warning "Go installation failed"
  return 1
 fi
}

# Main execution
main() {
 log_info "Installing shfmt for OSM-Notes-profile tests..."

 # Check if already installed
 if check_shfmt; then
  exit 0
 fi

 # Try package manager first
 if install_from_package_manager; then
  exit 0
 fi

 # Try Go install if available
 if install_from_go; then
  exit 0
 fi

 # Fallback to GitHub installation
 if install_from_github; then
  exit 0
 fi

 # All installation methods failed
 log_error "Failed to install shfmt using all available methods"
 log_info "Please install shfmt manually:"
 log_info "  - Visit: https://github.com/mvdan/sh/releases"
 log_info "  - Download the appropriate version for your system"
 log_info "  - Make it executable and add to PATH"
 exit 1
}

# Run main function
main "$@"
