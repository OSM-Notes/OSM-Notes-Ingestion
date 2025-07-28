#!/bin/bash
# WMS Properties Configuration
# Configuration file for WMS and GeoServer components
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-27

# =============================================================================
# WMS Database Configuration
# =============================================================================

# Database connection for WMS components
WMS_DBNAME="${WMS_DBNAME:-osm_notes}"
WMS_DBUSER="${WMS_DBUSER:-postgres}"
WMS_DBPASSWORD="${WMS_DBPASSWORD:-}"
WMS_DBHOST="${WMS_DBHOST:-localhost}"
WMS_DBPORT="${WMS_DBPORT:-5432}"

# WMS Schema configuration
WMS_SCHEMA="${WMS_SCHEMA:-wms}"
WMS_TABLE="${WMS_TABLE:-notes_wms}"

# =============================================================================
# GeoServer Configuration
# =============================================================================

# GeoServer installation and access
GEOSERVER_HOME="${GEOSERVER_HOME:-/opt/geoserver}"
GEOSERVER_DATA_DIR="${GEOSERVER_DATA_DIR:-${GEOSERVER_HOME}/data_dir}"
GEOSERVER_URL="${GEOSERVER_URL:-http://localhost:8080/geoserver}"

# GeoServer credentials
GEOSERVER_USER="${GEOSERVER_USER:-admin}"
GEOSERVER_PASSWORD="${GEOSERVER_PASSWORD:-geoserver}"

# GeoServer workspace and namespace
GEOSERVER_WORKSPACE="${GEOSERVER_WORKSPACE:-osm_notes}"
GEOSERVER_NAMESPACE="${GEOSERVER_NAMESPACE:-http://osm-notes-profile}"
GEOSERVER_STORE="${GEOSERVER_STORE:-notes_wms}"
GEOSERVER_LAYER="${GEOSERVER_LAYER:-notes_wms_layer}"

# =============================================================================
# WMS Service Configuration
# =============================================================================

# WMS service parameters
WMS_SERVICE_TITLE="${WMS_SERVICE_TITLE:-OSM Notes WMS Service}"
WMS_SERVICE_DESCRIPTION="${WMS_SERVICE_DESCRIPTION:-OpenStreetMap Notes for WMS service}"
WMS_SERVICE_KEYWORDS="${WMS_SERVICE_KEYWORDS:-osm,notes,openstreetmap}"

# WMS layer configuration
WMS_LAYER_TITLE="${WMS_LAYER_TITLE:-OSM Notes WMS Layer}"
WMS_LAYER_DESCRIPTION="${WMS_LAYER_DESCRIPTION:-OpenStreetMap Notes for WMS service}"
WMS_LAYER_SRS="${WMS_LAYER_SRS:-EPSG:4326}"

# WMS Layer-specific configurations (from README)
WMS_LAYER_OPEN_NAME="${WMS_LAYER_OPEN_NAME:-Open OSM Notes layer}"
WMS_LAYER_OPEN_DESCRIPTION="${WMS_LAYER_OPEN_DESCRIPTION:-This layer shows the location of the currently open notes. The color intensity shows the age of the creation time.}"
WMS_LAYER_OPEN_SQL="${WMS_LAYER_OPEN_SQL:-SELECT /* Notes-WMS */ year_created_at, year_closed_at, geometry FROM wms.notes_wms WHERE year_closed_at IS NULL ORDER BY year_created_at DESC}"

WMS_LAYER_CLOSED_NAME="${WMS_LAYER_CLOSED_NAME:-Closed OSM Notes layer}"
WMS_LAYER_CLOSED_DESCRIPTION="${WMS_LAYER_CLOSED_DESCRIPTION:-This layer shows the location of the closed notes. The color intensity shows the age of the creation time.}"
WMS_LAYER_CLOSED_SQL="${WMS_LAYER_CLOSED_SQL:-SELECT /* Notes-WMS */ year_created_at, year_closed_at, geometry FROM wms.notes_wms WHERE year_closed_at IS NOT NULL ORDER BY year_created_at DESC}"

# WMS bounding box (worldwide by default)
WMS_BBOX_MINX="${WMS_BBOX_MINX:--180}"
WMS_BBOX_MAXX="${WMS_BBOX_MAXX:-180}"
WMS_BBOX_MINY="${WMS_BBOX_MINY:--90}"
WMS_BBOX_MAXY="${WMS_BBOX_MAXY:-90}"

# WMS Organization Information (from README)
WMS_ORGANIZATION="${WMS_ORGANIZATION:-OSM LatAm}"
WMS_ORGANIZATION_URL="${WMS_ORGANIZATION_URL:-https://osmlatam.org}"
WMS_ORGANIZATION_WELCOME="${WMS_ORGANIZATION_WELCOME:-Set of layers provided by OpenStreetMap LatAm.}"

# WMS Contact Information (from README)
WMS_CONTACT_PERSON="${WMS_CONTACT_PERSON:-Andres Gomez Casanova - AngocA}"
WMS_CONTACT_POSITION="${WMS_CONTACT_POSITION:-Volunteer}"
WMS_CONTACT_EMAIL="${WMS_CONTACT_EMAIL:-angoca@osm.lat}"
WMS_CONTACT_CITY="${WMS_CONTACT_CITY:-Bogota}"
WMS_CONTACT_STATE="${WMS_CONTACT_STATE:-D.C.}"
WMS_CONTACT_COUNTRY="${WMS_CONTACT_COUNTRY:-Colombia}"

# WMS Attribution (from README)
WMS_ATTRIBUTION_TEXT="${WMS_ATTRIBUTION_TEXT:-OpenStreetMap contributors}"
WMS_ATTRIBUTION_LINK="${WMS_ATTRIBUTION_LINK:-https://www.openstreetmap.org/copyright}"

# =============================================================================
# Style Configuration
# =============================================================================

# SLD style configuration (from README)
WMS_STYLE_OPEN_NAME="${WMS_STYLE_OPEN_NAME:-OpenNotes}"
WMS_STYLE_OPEN_FILE="${WMS_STYLE_OPEN_FILE:-${PROJECT_ROOT}/sld/OpenNotes.sld}"
WMS_STYLE_CLOSED_NAME="${WMS_STYLE_CLOSED_NAME:-ClosedNotes}"
WMS_STYLE_CLOSED_FILE="${WMS_STYLE_CLOSED_FILE:-${PROJECT_ROOT}/sld/ClosedNotes.sld}"
WMS_STYLE_COUNTRIES_NAME="${WMS_STYLE_COUNTRIES_NAME:-CountriesAndMaritimes}"
WMS_STYLE_COUNTRIES_FILE="${WMS_STYLE_COUNTRIES_FILE:-${PROJECT_ROOT}/sld/CountriesAndMaritimes.sld}"

# Style fallback options
WMS_STYLE_FALLBACK="${WMS_STYLE_FALLBACK:-true}"
WMS_STYLE_DEFAULT="${WMS_STYLE_DEFAULT:-point}"

# Legacy style name (for backward compatibility)
WMS_STYLE_NAME="${WMS_STYLE_NAME:-osm_notes_style}"
WMS_STYLE_FILE="${WMS_STYLE_FILE:-${WMS_STYLE_OPEN_FILE}}"

# =============================================================================
# Performance Configuration
# =============================================================================

# Database connection pool
WMS_DB_POOL_SIZE="${WMS_DB_POOL_SIZE:-10}"
WMS_DB_POOL_TIMEOUT="${WMS_DB_POOL_TIMEOUT:-30}"

# WMS cache configuration
WMS_CACHE_ENABLED="${WMS_CACHE_ENABLED:-true}"
WMS_CACHE_TTL="${WMS_CACHE_TTL:-3600}"
WMS_CACHE_MAX_SIZE="${WMS_CACHE_MAX_SIZE:-100}"

# Tile cache configuration (from README)
WMS_TILE_CACHE_ENABLED="${WMS_TILE_CACHE_ENABLED:-true}"
WMS_TILE_CACHE_EXPIRE="${WMS_TILE_CACHE_EXPIRE:-3600}"
WMS_TILE_CACHE_DISK_QUOTA="${WMS_TILE_CACHE_DISK_QUOTA:-5GB}"
WMS_TILE_CACHE_BASE_DIR="${WMS_TILE_CACHE_BASE_DIR:-/opt/geoserver/data_dir/gwc}"
WMS_TILE_CACHE_PUBLISHED_ZOOM_LEVELS="${WMS_TILE_CACHE_PUBLISHED_ZOOM_LEVELS:-0-8}"

# BlobStore configuration (from README)
WMS_BLOBSTORE_ENABLED="${WMS_BLOBSTORE_ENABLED:-true}"
WMS_BLOBSTORE_IDENTIFIER="${WMS_BLOBSTORE_IDENTIFIER:-OSM Notes}"
WMS_BLOBSTORE_TYPE="${WMS_BLOBSTORE_TYPE:-File BlobStore}"
WMS_BLOBSTORE_BASE_DIR="${WMS_BLOBSTORE_BASE_DIR:-/opt/geoserver/data_dir/blobs}"

# =============================================================================
# Security Configuration
# =============================================================================

# Authentication settings
WMS_AUTH_ENABLED="${WMS_AUTH_ENABLED:-false}"
WMS_AUTH_USER="${WMS_AUTH_USER:-}"
WMS_AUTH_PASSWORD="${WMS_AUTH_PASSWORD:-}"

# CORS configuration
WMS_CORS_ENABLED="${WMS_CORS_ENABLED:-true}"
WMS_CORS_ALLOW_ORIGIN="${WMS_CORS_ALLOW_ORIGIN:-*}"

# =============================================================================
# Logging Configuration
# =============================================================================

# WMS logging
WMS_LOG_LEVEL="${WMS_LOG_LEVEL:-INFO}"
WMS_LOG_FILE="${WMS_LOG_FILE:-${PROJECT_ROOT}/logs/wms.log}"
WMS_LOG_MAX_SIZE="${WMS_LOG_MAX_SIZE:-10MB}"
WMS_LOG_MAX_FILES="${WMS_LOG_MAX_FILES:-5}"

# =============================================================================
# Validation Configuration
# =============================================================================

# Data validation settings
WMS_VALIDATE_GEOMETRY="${WMS_VALIDATE_GEOMETRY:-true}"
WMS_VALIDATE_COORDINATES="${WMS_VALIDATE_COORDINATES:-true}"
WMS_MAX_COORDINATES="${WMS_MAX_COORDINATES:-1000}"

# =============================================================================
# Integration Configuration
# =============================================================================

# JOSM/Vespucci integration
WMS_JOSM_ENABLED="${WMS_JOSM_ENABLED:-true}"
WMS_VESPUCCI_ENABLED="${WMS_VESPUCCI_ENABLED:-true}"

# External tools integration
WMS_GDAL_ENABLED="${WMS_GDAL_ENABLED:-false}"
WMS_POSTGIS_ENABLED="${WMS_POSTGIS_ENABLED:-true}"

# =============================================================================
# Development/Testing Configuration
# =============================================================================

# Development mode
WMS_DEV_MODE="${WMS_DEV_MODE:-false}"
WMS_DEBUG_ENABLED="${WMS_DEBUG_ENABLED:-false}"

# Testing configuration
WMS_TEST_DBNAME="${WMS_TEST_DBNAME:-osm_notes_test}"
WMS_TEST_DBUSER="${WMS_TEST_DBUSER:-testuser}"
WMS_TEST_DBPASSWORD="${WMS_TEST_DBPASSWORD:-testpass}"

# =============================================================================
# Backup Configuration
# =============================================================================

# Backup settings
WMS_BACKUP_ENABLED="${WMS_BACKUP_ENABLED:-true}"
WMS_BACKUP_DIR="${WMS_BACKUP_DIR:-${PROJECT_ROOT}/backups/wms}"
WMS_BACKUP_RETENTION="${WMS_BACKUP_RETENTION:-7}"

# =============================================================================
# Monitoring Configuration
# =============================================================================

# Health check settings
WMS_HEALTH_CHECK_ENABLED="${WMS_HEALTH_CHECK_ENABLED:-true}"
WMS_HEALTH_CHECK_INTERVAL="${WMS_HEALTH_CHECK_INTERVAL:-300}"
WMS_HEALTH_CHECK_TIMEOUT="${WMS_HEALTH_CHECK_TIMEOUT:-30}"

# Metrics collection
WMS_METRICS_ENABLED="${WMS_METRICS_ENABLED:-false}"
WMS_METRICS_PORT="${WMS_METRICS_PORT:-9090}"

# =============================================================================
# Utility Functions
# =============================================================================

# Function to validate WMS properties
__validate_wms_properties() {
 local errors=0

 # Validate database connection
 if [[ -z "${WMS_DBNAME}" ]]; then
  echo "ERROR: WMS_DBNAME is not set" >&2
  ((errors++))
 fi

 if [[ -z "${WMS_DBUSER}" ]]; then
  echo "ERROR: WMS_DBUSER is not set" >&2
  ((errors++))
 fi

 # Validate GeoServer configuration
 if [[ -z "${GEOSERVER_URL}" ]]; then
  echo "ERROR: GEOSERVER_URL is not set" >&2
  ((errors++))
 fi

 if [[ -z "${GEOSERVER_USER}" ]]; then
  echo "ERROR: GEOSERVER_USER is not set" >&2
  ((errors++))
 fi

 if [[ -z "${GEOSERVER_PASSWORD}" ]]; then
  echo "ERROR: GEOSERVER_PASSWORD is not set" >&2
  ((errors++))
 fi

 # Validate workspace configuration
 if [[ -z "${GEOSERVER_WORKSPACE}" ]]; then
  echo "ERROR: GEOSERVER_WORKSPACE is not set" >&2
  ((errors++))
 fi

 if [[ -z "${GEOSERVER_STORE}" ]]; then
  echo "ERROR: GEOSERVER_STORE is not set" >&2
  ((errors++))
 fi

 if [[ -z "${GEOSERVER_LAYER}" ]]; then
  echo "ERROR: GEOSERVER_LAYER is not set" >&2
  ((errors++))
 fi

 # Validate numeric values
 if ! [[ "${WMS_DBPORT}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: WMS_DBPORT must be a number" >&2
  ((errors++))
 fi

 if ! [[ "${WMS_BBOX_MINX}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  echo "ERROR: WMS_BBOX_MINX must be a number" >&2
  ((errors++))
 fi

 if ! [[ "${WMS_BBOX_MAXX}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  echo "ERROR: WMS_BBOX_MAXX must be a number" >&2
  ((errors++))
 fi

 if ! [[ "${WMS_BBOX_MINY}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  echo "ERROR: WMS_BBOX_MINY must be a number" >&2
  ((errors++))
 fi

 if ! [[ "${WMS_BBOX_MAXY}" =~ ^-?[0-9]+\.?[0-9]*$ ]]; then
  echo "ERROR: WMS_BBOX_MAXY must be a number" >&2
  ((errors++))
 fi

 return $errors
}

# Function to export WMS properties for scripts
__export_wms_properties() {
 export WMS_DBNAME WMS_DBUSER WMS_DBPASSWORD WMS_DBHOST WMS_DBPORT
 export WMS_SCHEMA WMS_TABLE
 export GEOSERVER_HOME GEOSERVER_DATA_DIR GEOSERVER_URL
 export GEOSERVER_USER GEOSERVER_PASSWORD
 export GEOSERVER_WORKSPACE GEOSERVER_NAMESPACE GEOSERVER_STORE GEOSERVER_LAYER
 export WMS_SERVICE_TITLE WMS_SERVICE_DESCRIPTION WMS_SERVICE_KEYWORDS
 export WMS_LAYER_TITLE WMS_LAYER_DESCRIPTION WMS_LAYER_SRS
 export WMS_BBOX_MINX WMS_BBOX_MAXX WMS_BBOX_MINY WMS_BBOX_MAXY
 export WMS_STYLE_NAME WMS_STYLE_FILE WMS_STYLE_FALLBACK WMS_STYLE_DEFAULT
 export WMS_STYLE_OPEN_NAME WMS_STYLE_OPEN_FILE WMS_STYLE_CLOSED_NAME WMS_STYLE_CLOSED_FILE
 export WMS_STYLE_COUNTRIES_NAME WMS_STYLE_COUNTRIES_FILE
 export WMS_DB_POOL_SIZE WMS_DB_POOL_TIMEOUT
 export WMS_CACHE_ENABLED WMS_CACHE_TTL WMS_CACHE_MAX_SIZE
 export WMS_TILE_CACHE_ENABLED WMS_TILE_CACHE_EXPIRE WMS_TILE_CACHE_DISK_QUOTA
 export WMS_TILE_CACHE_BASE_DIR WMS_TILE_CACHE_PUBLISHED_ZOOM_LEVELS
 export WMS_BLOBSTORE_ENABLED WMS_BLOBSTORE_IDENTIFIER WMS_BLOBSTORE_TYPE WMS_BLOBSTORE_BASE_DIR
 export WMS_AUTH_ENABLED WMS_AUTH_USER WMS_AUTH_PASSWORD
 export WMS_CORS_ENABLED WMS_CORS_ALLOW_ORIGIN
 export WMS_LOG_LEVEL WMS_LOG_FILE WMS_LOG_MAX_SIZE WMS_LOG_MAX_FILES
 export WMS_VALIDATE_GEOMETRY WMS_VALIDATE_COORDINATES WMS_MAX_COORDINATES
 export WMS_JOSM_ENABLED WMS_VESPUCCI_ENABLED
 export WMS_GDAL_ENABLED WMS_POSTGIS_ENABLED
 export WMS_DEV_MODE WMS_DEBUG_ENABLED
 export WMS_TEST_DBNAME WMS_TEST_DBUSER WMS_TEST_DBPASSWORD
 export WMS_BACKUP_ENABLED WMS_BACKUP_DIR WMS_BACKUP_RETENTION
 export WMS_HEALTH_CHECK_ENABLED WMS_HEALTH_CHECK_INTERVAL WMS_HEALTH_CHECK_TIMEOUT
 export WMS_METRICS_ENABLED WMS_METRICS_PORT
 export WMS_ORGANIZATION WMS_ORGANIZATION_URL WMS_ORGANIZATION_WELCOME
 export WMS_CONTACT_PERSON WMS_CONTACT_POSITION WMS_CONTACT_EMAIL
 export WMS_CONTACT_CITY WMS_CONTACT_STATE WMS_CONTACT_COUNTRY
 export WMS_ATTRIBUTION_TEXT WMS_ATTRIBUTION_LINK
 export WMS_LAYER_OPEN_NAME WMS_LAYER_OPEN_DESCRIPTION WMS_LAYER_OPEN_SQL
 export WMS_LAYER_CLOSED_NAME WMS_LAYER_CLOSED_DESCRIPTION WMS_LAYER_CLOSED_SQL
}

# Function to show WMS configuration
__show_wms_config() {
 echo "=== WMS Configuration ==="
 echo "Database: ${WMS_DBHOST}:${WMS_DBPORT}/${WMS_DBNAME} (${WMS_DBUSER})"
 echo "Schema: ${WMS_SCHEMA}.${WMS_TABLE}"
 echo "GeoServer: ${GEOSERVER_URL} (${GEOSERVER_USER})"
 echo "Workspace: ${GEOSERVER_WORKSPACE}"
 echo "Store: ${GEOSERVER_STORE}"
 echo "Layer: ${GEOSERVER_LAYER}"
 echo "Styles: ${WMS_STYLE_OPEN_NAME}, ${WMS_STYLE_CLOSED_NAME}, ${WMS_STYLE_COUNTRIES_NAME}"
 echo "BBox: ${WMS_BBOX_MINX},${WMS_BBOX_MINY} to ${WMS_BBOX_MAXX},${WMS_BBOX_MAXY}"
 echo "Organization: ${WMS_ORGANIZATION} (${WMS_ORGANIZATION_URL})"
 echo "Contact: ${WMS_CONTACT_PERSON} (${WMS_CONTACT_EMAIL})"
 echo "Attribution: ${WMS_ATTRIBUTION_TEXT}"
 echo "Tile Cache: ${WMS_TILE_CACHE_ENABLED} (${WMS_TILE_CACHE_DISK_QUOTA})"
 echo "BlobStore: ${WMS_BLOBSTORE_ENABLED} (${WMS_BLOBSTORE_IDENTIFIER})"
 echo "Log Level: ${WMS_LOG_LEVEL}"
 echo "Dev Mode: ${WMS_DEV_MODE}"
 echo "========================="
}

# Auto-export properties when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 # Script is being executed directly
 __show_wms_config
else
 # Script is being sourced
 __export_wms_properties
fi 