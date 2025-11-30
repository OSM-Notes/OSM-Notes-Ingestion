#!/usr/bin/env bash

# Cleanup script for ignored files
# This script removes files that are in .gitignore and safe to delete
#
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

set -o errexit
set -o nounset
set -o pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Function to print colored messages
__print_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

__print_warning() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

__print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to calculate directory size
__get_size() {
  if command -v du >/dev/null 2>&1; then
    du -sh "$1" 2>/dev/null | cut -f1
  else
    echo "N/A"
  fi
}

# Function to calculate file size
__get_file_size() {
  if [ -f "$1" ]; then
    if command -v stat >/dev/null 2>&1; then
      stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null || echo "N/A"
    else
      echo "N/A"
    fi
  else
    echo "0"
  fi
}

# Main cleanup function
main() {
  __print_info "Starting cleanup of ignored files..."
  __print_info "All files being removed are in .gitignore and safe to delete"
  echo ""

  local total_deleted=0
  local total_size=0

  # Log files
  __print_info "Cleaning log files..."
  local log_files=(
    "*.log"
    "postgresql-*.log"
    "updateCountries.log"
    "output*.log"
    "tests/docker/last_test_results.log"
    "tests/format_lint_test_output.log"
  )

  for pattern in "${log_files[@]}"; do
    if ls $pattern 1>/dev/null 2>&1; then
      for file in $pattern; do
        if [ -f "$file" ]; then
          local size=$(__get_file_size "$file")
          rm -f "$file"
          __print_info "  Deleted: $file"
          ((total_deleted++)) || true
        fi
      done
    fi
  done

  # Output directory
  __print_info "Cleaning output directory..."
  if [ -d "output" ]; then
    local size=$(__get_size "output")
    rm -rf output/
    __print_info "  Deleted directory: output/ ($size)"
    ((total_deleted++)) || true
  fi

  # Uncompressed GeoJSON files
  __print_info "Cleaning uncompressed GeoJSON files..."
  local geojson_files=(
    "data/countries.geojson"
    "data/maritimes.geojson"
  )

  for file in "${geojson_files[@]}"; do
    if [ -f "$file" ]; then
      local size=$(__get_file_size "$file")
      rm -f "$file"
      __print_info "  Deleted: $file"
      ((total_deleted++)) || true
    fi
  done

  # Planet files
  __print_info "Cleaning planet files..."
  if ls planet-notes*.bz2 1>/dev/null 2>&1; then
    for file in planet-notes*.bz2; do
      if [ -f "$file" ]; then
        rm -f "$file"
        __print_info "  Deleted: $file"
        ((total_deleted++)) || true
      fi
    done
  fi

  # Temporary directories
  __print_info "Cleaning temporary directories..."
  local temp_dirs=(
    "test_output_failures"
    "tests/tmp"
  )

  for dir in "${temp_dirs[@]}"; do
    if [ -d "$dir" ]; then
      local size=$(__get_size "$dir")
      rm -rf "$dir"
      __print_info "  Deleted directory: $dir/ ($size)"
      ((total_deleted++)) || true
    fi
  done

  echo ""
  __print_info "Cleanup completed!"
  __print_info "Total items deleted: $total_deleted"
  __print_warning "Note: etc/properties.sh_local was NOT deleted (contains local config)"
  __print_info "If you want to delete it manually, run: rm -f etc/properties.sh_local"
}

# Run main function
main "$@"


