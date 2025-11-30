#!/usr/bin/env bash

# =============================================================================
# Cleanup Script for Ignored Files
# =============================================================================
#
# PURPOSE:
#   This script safely removes files and directories that are listed in
#   .gitignore and are safe to delete. It helps maintain a clean repository
#   workspace by removing temporary files, logs, generated data, and other
#   artifacts that accumulate during development and testing.
#
# WHY USE THIS SCRIPT:
#   1. **Save AI Tokens**: When using AI coding assistants (like Cursor), they
#      analyze all files in your workspace. Removing unnecessary files reduces
#      the context size, saving tokens and improving AI response quality.
#   2. **Clean Workspace**: Keeps your repository clean and organized, making
#      it easier to navigate and understand the codebase.
#   3. **Free Disk Space**: Removes large temporary files, logs, and generated
#      data files that can accumulate over time.
#   4. **Safe Operation**: Only removes files that are explicitly listed in
#      .gitignore, ensuring you never delete important source code or
#      configuration files.
#
# WHAT IT REMOVES:
#   - Log files (*.log, postgresql-*.log, updateCountries.log, etc.)
#   - Output directory (output/)
#   - Uncompressed GeoJSON files (data/countries.geojson, data/maritimes.geojson)
#   - Planet download files (planet-notes*.bz2)
#   - Temporary test directories (test_output_failures/, tests/tmp/)
#
# WHAT IT DOES NOT REMOVE:
#   - Source code files
#   - Configuration files (except etc/properties.sh_local if you manually delete it)
#   - Test fixtures and expected test data
#   - Any file NOT listed in .gitignore
#
# USAGE:
#   # Run from project root directory
#   ./tools/cleanup_ignored_files.sh
#
#   # The script will show what it's deleting and provide a summary
#
# WHEN TO RUN:
#   - **Regularly**: Run this script periodically (weekly or after major
#     development sessions) to keep your workspace clean
#   - **Before AI Sessions**: Run before starting a new AI coding session to
#     reduce context size and save tokens
#   - **After Testing**: Run after running test suites to clean up test outputs
#   - **Before Commits**: Run before making commits to ensure you're not
#     accidentally including temporary files
#
# SAFETY:
#   - This script is SAFE to run at any time
#   - It only removes files that are in .gitignore
#   - It will NOT delete source code, configuration, or important files
#   - All operations are logged so you can see what was deleted
#
# EXAMPLES:
#   # Clean up after a development session
#   ./tools/cleanup_ignored_files.sh
#
#   # Clean up before starting work with AI assistant
#   ./tools/cleanup_ignored_files.sh
#
#   # Clean up after running tests
#   ./tests/run_all_tests.sh
#   ./tools/cleanup_ignored_files.sh
#
# REQUIREMENTS:
#   - Bash 4.0 or higher
#   - Standard Unix utilities (rm, ls, du, stat)
#   - Run from project root directory
#
# AUTHOR:
#   Andres Gomez (AngocA)
#
# VERSION:
#   2025-11-30
#
# =============================================================================

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

  # ========================================================================
  # Clean log files
  # ========================================================================
  # Removes all log files that accumulate during development and testing.
  # These files can be large and are regenerated when needed.
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
          local size
          size=$(__get_file_size "$file")
          rm -f "$file"
          __print_info "  Deleted: $file"
          ((total_deleted++)) || true
        fi
      done
    fi
  done

  # ========================================================================
  # Clean output directory
  # ========================================================================
  # Removes the output/ directory which contains generated files from
  # processing operations. This directory can grow large over time.
  __print_info "Cleaning output directory..."
  if [ -d "output" ]; then
    local size
    size=$(__get_size "output")
    rm -rf output/
    __print_info "  Deleted directory: output/ ($size)"
    ((total_deleted++)) || true
  fi

  # ========================================================================
  # Clean uncompressed GeoJSON files
  # ========================================================================
  # Removes uncompressed GeoJSON backup files. Only compressed .geojson.gz
  # files are tracked in the repository. Uncompressed versions are generated
  # when needed and can be large.
  __print_info "Cleaning uncompressed GeoJSON files..."
  local geojson_files=(
    "data/countries.geojson"
    "data/maritimes.geojson"
  )

  for file in "${geojson_files[@]}"; do
    if [ -f "$file" ]; then
      local size
      size=$(__get_file_size "$file")
      rm -f "$file"
      __print_info "  Deleted: $file"
      ((total_deleted++)) || true
    fi
  done

  # ========================================================================
  # Clean planet download files
  # ========================================================================
  # Removes downloaded planet note files (*.bz2). These are large files
  # downloaded from OpenStreetMap and are regenerated when needed for
  # processing. They can be several GB in size.
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

  # ========================================================================
  # Clean temporary test directories
  # ========================================================================
  # Removes temporary directories created during test execution. These
  # directories contain test artifacts and can be safely removed as they
  # are regenerated when tests run.
  __print_info "Cleaning temporary directories..."
  local temp_dirs=(
    "test_output_failures"
    "tests/tmp"
  )

  for dir in "${temp_dirs[@]}"; do
    if [ -d "$dir" ]; then
      local size
      size=$(__get_size "$dir")
      rm -rf "$dir"
      __print_info "  Deleted directory: $dir/ ($size)"
      ((total_deleted++)) || true
    fi
  done

  # ========================================================================
  # Summary
  # ========================================================================
  echo ""
  __print_info "Cleanup completed!"
  __print_info "Total items deleted: $total_deleted"
  __print_warning "Note: etc/properties.sh_local was NOT deleted (contains local config)"
  __print_info "If you want to delete it manually, run: rm -f etc/properties.sh_local"
  echo ""
  __print_info "💡 TIP: Run this script regularly to keep your workspace clean"
  __print_info "   and reduce AI token usage when working with coding assistants."
}

# Run main function
main "$@"


