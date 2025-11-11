#!/bin/bash

# Overpass Helper Functions for OSM-Notes-profile
# Author: Andres Gomez (AngocA)
# Version: 2025-11-11

VERSION="2025-11-11"

# shellcheck disable=SC2317,SC2155,SC2034

# Ensure common logging functions are available
if ! declare -f __logi > /dev/null 2>&1; then
 if [[ -f "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_BASE_DIRECTORY}/lib/osm-common/commonFunctions.sh"
 fi
fi

# Provide defaults for retry/backoff if not already set
: "${OVERPASS_RETRIES_PER_ENDPOINT:=7}"
: "${OVERPASS_BACKOFF_SECONDS:=20}"

# Log Overpass attempt details
function __log_overpass_attempt() {
 local BOUNDARY_ID="${1}"
 local ATTEMPT="${2}"
 local MAX_ATTEMPTS="${3}"
 __logi "Downloading boundary ${BOUNDARY_ID} from Overpass API (attempt ${ATTEMPT}/${MAX_ATTEMPTS})..."
}

# Log successful Overpass download
function __log_overpass_success() {
 local BOUNDARY_ID="${1}"
 local ATTEMPT="${2}"
 __logi "Successfully downloaded boundary ${BOUNDARY_ID} from Overpass API (attempt ${ATTEMPT})"
}

# Log Overpass error after retries
function __log_overpass_failure() {
 local BOUNDARY_ID="${1}"
 local ATTEMPT="${2}"
 local MAX_ATTEMPTS="${3}"
 local ELAPSED="${4}"
 __loge "Failed to retrieve boundary ${BOUNDARY_ID} from Overpass after retries (attempt ${ATTEMPT}/${MAX_ATTEMPTS}, elapsed: ${ELAPSED}s)"
}

# Provide default JSON validation logging
function __log_json_validation_start() {
 local BOUNDARY_ID="${1}"
 __logi "Validating JSON structure for boundary ${BOUNDARY_ID}..."
}

function __log_json_validation_success() {
 local BOUNDARY_ID="${1}"
 __logi "JSON validation passed for boundary ${BOUNDARY_ID}"
}

function __log_geojson_conversion_attempt() {
 local BOUNDARY_ID="${1}"
 local ATTEMPT="${2}"
 local MAX_ATTEMPTS="${3}"
 __logd "Attempting GeoJSON conversion for boundary ${BOUNDARY_ID} (attempt ${ATTEMPT}/${MAX_ATTEMPTS})..."
}

function __log_geojson_conversion_success() {
 local BOUNDARY_ID="${1}"
 local ATTEMPT="${2}"
 __logd "GeoJSON conversion completed for boundary ${BOUNDARY_ID} (attempt ${ATTEMPT})"
}

function __log_geojson_validation() {
 local BOUNDARY_ID="${1}"
 __logd "Validating GeoJSON structure for boundary ${BOUNDARY_ID}..."
}

function __log_geojson_validation_success() {
 local BOUNDARY_ID="${1}"
 __logd "GeoJSON validation passed for boundary ${BOUNDARY_ID}"
}

function __log_geojson_conversion_failure() {
 local BOUNDARY_ID="${1}"
 local ATTEMPT="${2}"
 local MAX_ATTEMPTS="${3}"
 local ELAPSED="${4}"
 __loge "Failed to convert boundary ${BOUNDARY_ID} to GeoJSON after retries (attempt ${ATTEMPT}/${MAX_ATTEMPTS}, elapsed: ${ELAPSED}s)"
}
