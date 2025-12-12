#!/bin/bash

# Generate EEZ centroids CSV from World_EEZ shapefile
# Extracts centroid coordinates and metadata for each EEZ feature
# This CSV is used by __checkMissingMaritimes() to verify OSM coverage
#
# Source shapefile:
#   World EEZ v12 (2023-10-25) from MarineRegions.org
#   Download: https://www.marineregions.org/downloads.php
#   File: World_EEZ_v12_20231025.zip
#   License: CC-BY 4.0 (Creative Commons Attribution 4.0 International)
#
# License of generated CSV:
#   This CSV is a derivative work and is licensed under CC-BY 4.0,
#   the same license as the original shapefile.
#   See data/eez_analysis/LICENSE for full license details.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-11

set -euo pipefail
set -E

# Script configuration
SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." &> /dev/null && pwd)"
export SCRIPT_BASE_DIRECTORY

# Load common functions
# shellcheck disable=SC1091
source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"

# Input shapefile
EEZ_SHAPEFILE="${EEZ_SHAPEFILE:-/home/notes/World_EEZ_v12_20231025.zip}"
EEZ_TEMP_DIR="${EEZ_TEMP_DIR:-/tmp/world_eez_centroids}"
EEZ_SHAPEFILE_LAYER="${EEZ_SHAPEFILE_LAYER:-eez_v12}"

# Output file
OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_BASE_DIRECTORY}/data/eez_analysis}"
OUTPUT_CSV="${OUTPUT_DIR}/eez_centroids.csv"

# Temporary directory for this script (if not already set by common functions)
if [[ -z "${TMP_DIR:-}" ]]; then
 TMP_DIR="/tmp/generateEEZCentroids_$$"
 mkdir -p "${TMP_DIR}"
fi

# Global variable for shapefile path
SHP_PATH=""

###############################################################################
# Helper functions
###############################################################################

# Cleanup function
__cleanup() {
 local EXIT_CODE=${1:-0}
 __logd "Cleaning up temporary files..."
 if [[ "${EXIT_CODE}" -ne 0 ]] && [[ -n "${CLEANUP_ON_ERROR:-}" ]]; then
  rm -rf "${EEZ_TEMP_DIR}" 2> /dev/null || true
 fi
 return "${EXIT_CODE}"
}

# Trap errors
trap '__cleanup $?' ERR
trap '__cleanup 0' EXIT

###############################################################################
# Main functions
###############################################################################

# Extract centroids from shapefile
__extract_centroids() {
 __logi "Extracting EEZ centroids from shapefile..."

 # Create output directory
 mkdir -p "${OUTPUT_DIR}"

 # Check if shapefile exists
 if [[ ! -f "${EEZ_SHAPEFILE}" ]]; then
  __loge "ERROR: Shapefile not found: ${EEZ_SHAPEFILE}"
  __loge "Please set EEZ_SHAPEFILE environment variable or place shapefile at default location"
  exit 1
 fi

 # Extract shapefile if needed
 if [[ ! -d "${EEZ_TEMP_DIR}" ]] || [[ ! -f "${EEZ_TEMP_DIR}/World_EEZ_v12_20231025/${EEZ_SHAPEFILE_LAYER}.shp" ]]; then
  __logi "Extracting shapefile from ZIP..."
  rm -rf "${EEZ_TEMP_DIR}"
  mkdir -p "${EEZ_TEMP_DIR}"
  unzip -q "${EEZ_SHAPEFILE}" -d "${EEZ_TEMP_DIR}" || {
   __loge "ERROR: Failed to extract shapefile"
   exit 1
  }
 fi

 SHP_PATH="${EEZ_TEMP_DIR}/World_EEZ_v12_20231025/${EEZ_SHAPEFILE_LAYER}.shp"

 # Import to temporary database table to calculate centroids using PostGIS
 __logi "Importing to database to calculate centroids..."
 local DBNAME="${DBNAME:-notes}"
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -v ON_ERROR_STOP=1 -c "DROP TABLE IF EXISTS temp_eez_centroids_calc CASCADE;" > /dev/null 2>&1 || true

 # Import shapefile to temporary table
 # Use -nlt PROMOTE_TO_MULTI to handle both Polygon and MultiPolygon
 local OGR_LOG="${TMP_DIR}/ogr2ogr_centroids.log"
 if ! ogr2ogr -f PostgreSQL "PG:dbname=${DBNAME}" "${SHP_PATH}" \
  -nln temp_eez_centroids_calc \
  -nlt PROMOTE_TO_MULTI \
  -t_srs EPSG:4326 \
  -lco GEOMETRY_NAME=geom \
  -overwrite > "${OGR_LOG}" 2>&1; then
  __loge "ERROR: Failed to import shapefile to database"
  if [[ -f "${OGR_LOG}" ]]; then
   __loge "ogr2ogr error log:"
   tail -20 "${OGR_LOG}" | while IFS= read -r line; do
    __loge "  ${line}"
   done
  fi
  exit 1
 fi

 # Extract features with centroids using PostGIS
 __logi "Calculating centroids using PostGIS..."
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -Atq -c "
  SELECT
   COALESCE(mrgid::text, ''),
   COALESCE('\"' || REPLACE(geoname, '\"', '\"\"') || '\"', ''),
   COALESCE('\"' || REPLACE(territory1, '\"', '\"\"') || '\"', ''),
   COALESCE('\"' || REPLACE(sovereign1, '\"', '\"\"') || '\"', ''),
   ROUND(ST_Y(ST_Centroid(geom))::numeric, 6),
   ROUND(ST_X(ST_Centroid(geom))::numeric, 6)
  FROM temp_eez_centroids_calc
  WHERE geom IS NOT NULL
  ORDER BY mrgid;
 " > "${OUTPUT_CSV}.tmp" 2> /dev/null || {
  __loge "ERROR: Failed to calculate centroids"
  PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -c "DROP TABLE IF EXISTS temp_eez_centroids_calc CASCADE;" > /dev/null 2>&1 || true
  exit 1
 }

 # Add header and format as CSV
 # Note: This CSV is a derivative work of World EEZ v12 shapefile
 # Licensed under CC-BY 4.0 (see data/eez_analysis/LICENSE)
 {
  echo "eez_id,name,territory,sovereign,centroid_lat,centroid_lon"
  cat "${OUTPUT_CSV}.tmp"
 } > "${OUTPUT_CSV}"

 # Create LICENSE file in output directory
 {
  echo "Creative Commons Attribution 4.0 International License (CC-BY 4.0)"
  echo "===================================================================="
  echo ""
  echo "This file (eez_centroids.csv) is a derivative work of the World EEZ v12"
  echo "shapefile from MarineRegions.org."
  echo ""
  echo "Source Data:"
  echo "------------"
  echo "- Original dataset: World EEZ v12 (2023-10-25)"
  echo "- Source: MarineRegions.org"
  echo "- Download: https://www.marineregions.org/downloads.php"
  echo "- Original license: CC-BY 4.0 (Creative Commons Attribution 4.0 International)"
  echo ""
  echo "Derivative Work:"
  echo "----------------"
  echo "- File: eez_centroids.csv"
  echo "- Description: Extracted centroids (coordinates and metadata) from World EEZ v12 shapefile"
  echo "- Generated by: bin/scripts/generateEEZCentroids.sh"
  echo "- Generation date: $(date +%Y-%m-%d)"
  echo ""
  echo "License:"
  echo "--------"
  echo "This derivative work is licensed under the same terms as the original:"
  echo "Creative Commons Attribution 4.0 International License (CC-BY 4.0)"
  echo ""
  echo "You are free to:"
  echo "- Share: copy and redistribute the material in any medium or format"
  echo "- Adapt: remix, transform, and build upon the material for any purpose,"
  echo "  even commercially"
  echo ""
  echo "Under the following terms:"
  echo "- Attribution: You must give appropriate credit, provide a link to the license,"
  echo "  and indicate if changes were made. You may do so in any reasonable manner,"
  echo "  but not in any way that suggests the licensor endorses you or your use."
  echo ""
  echo "Full license text: https://creativecommons.org/licenses/by/4.0/"
  echo ""
  echo "Attribution:"
  echo "------------"
  echo "This work is based on data from MarineRegions.org (https://www.marineregions.org/),"
  echo "specifically the World EEZ v12 dataset, which is licensed under CC-BY 4.0."
  echo ""
  echo "When using this CSV file, please attribute:"
  echo "- Original data: MarineRegions.org"
  echo "- Original dataset: World EEZ v12 (2023-10-25)"
  echo "- Derivative work: eez_centroids.csv (generated by OSM-Notes-Ingestion project)"
  echo ""
  echo "Note:"
  echo "-----"
  echo "This CSV file is used as a reference to identify missing maritime boundaries"
  echo "in OpenStreetMap. The actual data in the database comes exclusively from"
  echo "OpenStreetMap (OSM), not from this shapefile."
 } > "${OUTPUT_DIR}/LICENSE"

 # Cleanup temporary table
 PGAPPNAME="${PGAPPNAME}" psql -d "${DBNAME}" -c "DROP TABLE IF EXISTS temp_eez_centroids_calc CASCADE;" > /dev/null 2>&1 || true
 rm -f "${OUTPUT_CSV}.tmp" 2> /dev/null || true

 local TOTAL_FEATURES
 TOTAL_FEATURES=$(tail -n +2 "${OUTPUT_CSV}" | wc -l | tr -d ' ' || echo "0")
 __logi "Extracted ${TOTAL_FEATURES} EEZ centroids to ${OUTPUT_CSV}"

 # Show sample of first few centroids
 __logd "Sample centroids (first 5):"
 head -6 "${OUTPUT_CSV}" | while IFS=',' read -r line; do
  __logd "  ${line}"
 done
}

###############################################################################
# Main
###############################################################################

main() {
 __log_start
 __logi "Starting EEZ centroids extraction from shapefile..."

 __extract_centroids

 __logi "Centroids extraction completed successfully."
 __logi "Output file: ${OUTPUT_CSV}"
 __logi ""
 __logi "This file will be used by __checkMissingMaritimes() to verify OSM coverage."
 __log_finish
}

main "$@"
