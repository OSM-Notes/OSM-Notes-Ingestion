#!/bin/bash

# Installation script for OSM-Notes-Ingestion directories
# Creates standard Linux directories for logs and temporary files
#
# Author: Andres Gomez (AngocA)
# Version: 2025-12-18
VERSION="2025-12-18"

set -euo pipefail

# Default user and group (can be overridden)
OSM_USER="${OSM_USER:-notes}"
OSM_GROUP="${OSM_GROUP:-maptimebogota}"

# Directories to create
LOG_DIR="/var/log/osm-notes-ingestion"
TMP_DIR="/var/tmp/osm-notes-ingestion"
LOCK_DIR="/var/run/osm-notes-ingestion"

# Subdirectories
LOG_SUBDIRS=("daemon" "processing" "monitoring")
TMP_SUBDIRS=("planet" "overpass" "api")

echo "=== OSM-Notes-Ingestion Directory Installation ==="
echo ""

# Check if running as root
if [[ "${EUID}" -ne 0 ]]; then
 echo "ERROR: This script must be run as root (use sudo)"
 echo ""
 echo "Usage:"
 echo "  sudo $0"
 echo ""
 exit 1
fi

# Check if user exists
if ! id "${OSM_USER}" > /dev/null 2>&1; then
 echo "ERROR: User '${OSM_USER}' does not exist"
 echo "Please create the user first or set OSM_USER environment variable"
 exit 1
fi

# Get primary group if not set
if [[ -z "${OSM_GROUP}" ]]; then
 OSM_GROUP=$(id -gn "${OSM_USER}")
fi

echo "Configuration:"
echo "  User: ${OSM_USER}"
echo "  Group: ${OSM_GROUP}"
echo "  Log directory: ${LOG_DIR}"
echo "  Temp directory: ${TMP_DIR}"
echo "  Lock directory: ${LOCK_DIR}"
echo ""

# Create log directory structure
echo "Creating log directories..."
mkdir -p "${LOG_DIR}"
for SUBDIR in "${LOG_SUBDIRS[@]}"; do
 mkdir -p "${LOG_DIR}/${SUBDIR}"
 echo "  Created: ${LOG_DIR}/${SUBDIR}"
done

# Create temp directory structure
echo ""
echo "Creating temporary directories..."
mkdir -p "${TMP_DIR}"
for SUBDIR in "${TMP_SUBDIRS[@]}"; do
 mkdir -p "${TMP_DIR}/${SUBDIR}"
 echo "  Created: ${TMP_DIR}/${SUBDIR}"
done

# Create lock directory
echo ""
echo "Creating lock directory..."
mkdir -p "${LOCK_DIR}"
echo "  Created: ${LOCK_DIR}"

# Set ownership
echo ""
echo "Setting ownership..."
chown -R "${OSM_USER}:${OSM_GROUP}" "${LOG_DIR}" "${TMP_DIR}" "${LOCK_DIR}"
echo "  Ownership set to ${OSM_USER}:${OSM_GROUP}"

# Set permissions
echo ""
echo "Setting permissions..."
# Logs: readable by group, writable by owner
chmod -R 755 "${LOG_DIR}"
find "${LOG_DIR}" -type f -exec chmod 644 {} \;
# Temp: writable by owner and group
chmod -R 775 "${TMP_DIR}"
# Locks: writable by owner and group
chmod -R 775 "${LOCK_DIR}"
echo "  Permissions configured"

# Create logrotate configuration
echo ""
echo "Creating logrotate configuration..."
cat > /etc/logrotate.d/osm-notes-ingestion << 'EOF'
/var/log/osm-notes-ingestion/**/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0644 notes maptimebogota
    sharedscripts
    postrotate
        # Reload daemon if running (non-blocking)
        systemctl reload osm-notes-api-daemon > /dev/null 2>&1 || true
    endscript
}
EOF
echo "  Created: /etc/logrotate.d/osm-notes-ingestion"

# Summary
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Directories created:"
echo "  ${LOG_DIR}"
echo "  ${TMP_DIR}"
echo "  ${LOCK_DIR}"
echo ""
echo "Logrotate configuration:"
echo "  /etc/logrotate.d/osm-notes-ingestion"
echo ""
echo "Next steps:"
echo "  1. Verify ownership: ls -la ${LOG_DIR}"
echo "  2. Test write access: sudo -u ${OSM_USER} touch ${LOG_DIR}/test.log && rm ${LOG_DIR}/test.log"
echo "  3. Logs will be automatically rotated daily (30 days retention)"
echo ""
