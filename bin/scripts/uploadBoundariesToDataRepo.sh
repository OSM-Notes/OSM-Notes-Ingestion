#!/bin/bash

# Uploads boundary backup files (countries.geojson.gz and maritimes.geojson.gz)
# to the OSM-Notes-Data repository on GitHub.
#
# This script:
# 1. Compresses the GeoJSON files if not already compressed
# 2. Clones or updates the OSM-Notes-Data repository
# 3. Copies the backup files to the repository
# 4. Commits and pushes the changes
#
# Usage:
#   ./bin/scripts/uploadBoundariesToDataRepo.sh
#   BOUNDARIES_DATA_REPO=/path/to/OSM-Notes-Data ./bin/scripts/uploadBoundariesToDataRepo.sh
#
# Environment variables:
#   BOUNDARIES_DATA_REPO - Path to OSM-Notes-Data repository (default: ../OSM-Notes-Data)
#   BOUNDARIES_DATA_REPO_URL - GitHub repository URL (default: git@github.com:OSMLatam/OSM-Notes-Data.git)
#   DBNAME - Database name for export (default: notes)
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-05
VERSION="2025-12-05"

# Base directory for the project
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." \
 &> /dev/null && pwd)"
declare -r SCRIPT_BASE_DIRECTORY

# Logger levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL
declare LOG_LEVEL="${LOG_LEVEL:-INFO}"

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Configuration
declare DBNAME="${DBNAME:-notes}"
declare BOUNDARIES_DATA_REPO="${BOUNDARIES_DATA_REPO:-${SCRIPT_BASE_DIRECTORY}/../OSM-Notes-Data}"
declare BOUNDARIES_DATA_REPO_URL="${BOUNDARIES_DATA_REPO_URL:-git@github.com:OSMLatam/OSM-Notes-Data.git}"

# Output files
declare -r COUNTRIES_GEOJSON="${SCRIPT_BASE_DIRECTORY}/data/countries.geojson"
declare -r MARITIMES_GEOJSON="${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson"
declare -r COUNTRIES_GZ="${SCRIPT_BASE_DIRECTORY}/data/countries.geojson.gz"
declare -r MARITIMES_GZ="${SCRIPT_BASE_DIRECTORY}/data/maritimes.geojson.gz"

###############################################################################
# Main function
###############################################################################
main() {
 # Enable bash debug mode if BASH_DEBUG environment variable is set
 if [[ "${BASH_DEBUG:-}" == "true" ]] || [[ "${BASH_DEBUG:-}" == "1" ]]; then
  set -xv
 fi

 __log_start
 __logi "Uploading boundary backups to OSM-Notes-Data repository..."

 # Step 1: Export backups if they don't exist
 __logi "Step 1: Checking if backup files exist..."
 if [[ ! -f "${COUNTRIES_GEOJSON}" ]] || [[ ! -f "${MARITIMES_GEOJSON}" ]]; then
  __logi "Backup files not found, exporting from database..."
  if [[ ! -f "${COUNTRIES_GEOJSON}" ]]; then
   if ! "${SCRIPT_BASE_DIRECTORY}/bin/scripts/exportCountriesBackup.sh"; then
    __loge "Failed to export countries backup"
    exit 1
   fi
  fi
  if [[ ! -f "${MARITIMES_GEOJSON}" ]]; then
   if ! "${SCRIPT_BASE_DIRECTORY}/bin/scripts/exportMaritimesBackup.sh"; then
    __loge "Failed to export maritimes backup"
    exit 1
   fi
  fi
 fi

 # Step 2: Compress files if not already compressed
 __logi "Step 2: Compressing GeoJSON files..."
 if [[ ! -f "${COUNTRIES_GZ}" ]] || [[ "${COUNTRIES_GEOJSON}" -nt "${COUNTRIES_GZ}" ]]; then
  __logi "Compressing countries.geojson..."
  gzip -k -f "${COUNTRIES_GEOJSON}"
 fi
 if [[ ! -f "${MARITIMES_GZ}" ]] || [[ "${MARITIMES_GEOJSON}" -nt "${MARITIMES_GZ}" ]]; then
  __logi "Compressing maritimes.geojson..."
  gzip -k -f "${MARITIMES_GEOJSON}"
 fi

 # Step 3: Clone or update the data repository
 __logi "Step 3: Preparing OSM-Notes-Data repository..."
 if [[ ! -d "${BOUNDARIES_DATA_REPO}" ]]; then
  __logi "Cloning OSM-Notes-Data repository to ${BOUNDARIES_DATA_REPO}..."
  if ! git clone "${BOUNDARIES_DATA_REPO_URL}" "${BOUNDARIES_DATA_REPO}"; then
   __loge "Failed to clone OSM-Notes-Data repository"
   exit 1
  fi
 else
  __logi "Updating OSM-Notes-Data repository..."
  cd "${BOUNDARIES_DATA_REPO}" || exit 1
  if ! git pull; then
   __logw "Failed to pull latest changes, continuing anyway..."
  fi
 fi

 # Step 4: Create data directory if it doesn't exist
 __logi "Step 4: Preparing data directory in repository..."
 mkdir -p "${BOUNDARIES_DATA_REPO}/data"

 # Step 5: Copy files to repository
 __logi "Step 5: Copying backup files to repository..."
 if ! cp "${COUNTRIES_GZ}" "${BOUNDARIES_DATA_REPO}/data/"; then
  __loge "Failed to copy countries.geojson.gz"
  exit 1
 fi
 if ! cp "${MARITIMES_GZ}" "${BOUNDARIES_DATA_REPO}/data/"; then
  __loge "Failed to copy maritimes.geojson.gz"
  exit 1
 fi

 # Step 6: Commit and push
 __logi "Step 6: Committing and pushing changes..."
 cd "${BOUNDARIES_DATA_REPO}" || exit 1

 # Check if there are changes
 if git diff --quiet --exit-code data/countries.geojson.gz data/maritimes.geojson.gz 2> /dev/null; then
  __logi "No changes to commit (files are up to date)"
  __log_finish
  return 0
 fi

 # Get file sizes for commit message
 local COUNTRIES_SIZE
 COUNTRIES_SIZE=$(du -h "${BOUNDARIES_DATA_REPO}/data/countries.geojson.gz" | cut -f1)
 local MARITIMES_SIZE
 MARITIMES_SIZE=$(du -h "${BOUNDARIES_DATA_REPO}/data/maritimes.geojson.gz" | cut -f1)

 # Get feature counts
 local COUNTRIES_COUNT=0
 local MARITIMES_COUNT=0
 if command -v jq > /dev/null 2>&1; then
  if [[ -f "${COUNTRIES_GEOJSON}" ]]; then
   COUNTRIES_COUNT=$(jq '.features | length' "${COUNTRIES_GEOJSON}" 2> /dev/null || echo "0")
  fi
  if [[ -f "${MARITIMES_GEOJSON}" ]]; then
   MARITIMES_COUNT=$(jq '.features | length' "${MARITIMES_GEOJSON}" 2> /dev/null || echo "0")
  fi
 fi

 # Add files
 git add data/countries.geojson.gz data/maritimes.geojson.gz

 # Commit
 local COMMIT_MSG="Update boundary backups: countries (${COUNTRIES_COUNT} features, ${COUNTRIES_SIZE}) and maritimes (${MARITIMES_COUNT} features, ${MARITIMES_SIZE})"
 if ! git commit -m "${COMMIT_MSG}"; then
  __loge "Failed to commit changes"
  exit 1
 fi

 # Push
 __logi "Pushing changes to GitHub..."
 if ! git push; then
  __loge "Failed to push changes to GitHub"
  __loge "You may need to push manually: cd ${BOUNDARIES_DATA_REPO} && git push"
  exit 1
 fi

 __logi "Successfully uploaded boundary backups to OSM-Notes-Data repository"
 __logi "Repository: ${BOUNDARIES_DATA_REPO}"
 __logi "Files:"
 __logi "  - data/countries.geojson.gz (${COUNTRIES_SIZE}, ${COUNTRIES_COUNT} features)"
 __logi "  - data/maritimes.geojson.gz (${MARITIMES_SIZE}, ${MARITIMES_COUNT} features)"

 __log_finish
}

# Execute main
main "$@"

