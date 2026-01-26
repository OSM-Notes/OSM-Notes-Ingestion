---
title: "Installation and Dependencies Guide"
description: "Complete guide to install dependencies and set up OSM-Notes-Ingestion for development"
version: "1.0.0"
last_updated: "2026-01-26"
author: "AngocA"
tags:
  - "installation"
  - "dependencies"
  - "setup"
audience:
  - "developers"
  - "system-admins"
project: "OSM-Notes-Ingestion"
status: "active"
---

# Installation and Dependencies Guide

Complete guide to install all dependencies and set up OSM-Notes-Ingestion for development and production.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [System Dependencies](#system-dependencies)
3. [Database Setup](#database-setup)
4. [Project Installation](#project-installation)
5. [Configuration](#configuration)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

---

## System Requirements

### Operating System

- **Linux** (Ubuntu 20.04+ / Debian 11+ recommended)
- **Bash** 4.0 or higher
- **Git** for cloning repositories

### Hardware Requirements

- **CPU**: 2+ cores recommended
- **RAM**: 4GB minimum, 8GB+ recommended
- **Disk**: 50GB+ free space (for Planet files and database)
- **Network**: Stable internet connection for downloading Planet files and API access

---

## System Dependencies

### Required Software

Install all required dependencies on Ubuntu/Debian:

```bash
# Update package list
sudo apt-get update

# PostgreSQL with PostGIS extension
sudo apt-get install -y postgresql postgresql-contrib postgis postgresql-14-postgis-3

# Standard UNIX utilities
sudo apt-get install -y grep awk sed curl jq bc

# Parallel processing
sudo apt-get install -y parallel

# Download tool for parallel downloads
sudo apt-get install -y aria2

# XML validation (optional, only if SKIP_XML_VALIDATION=false)
sudo apt-get install -y libxml2-utils

# Geographic tools (GDAL)
sudo add-apt-repository ppa:ubuntugis/ppa -y
sudo apt-get update
sudo apt-get install -y gdal-bin

# Node.js and npm (for geographic tools)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Node.js tools globally
sudo npm install -g osmtogeojson
sudo npm install -g ajv-cli

# Email notifications (for monitoring alerts)
sudo apt-get install -y mutt

# Git (if not already installed)
sudo apt-get install -y git
```

### Verify Installation

```bash
# Check PostgreSQL version
psql --version  # Should be 12+

# Check PostGIS
psql -d postgres -c "SELECT PostGIS_version();"

# Check Bash version
bash --version  # Should be 4.0+

# Check other tools
parallel --version
jq --version
curl --version
node --version  # Should be 18+
npm --version
gdalinfo --version
```

---

## Database Setup

### 1. Create PostgreSQL User and Database

```bash
# Switch to postgres user
sudo su - postgres

# Create user and database
psql << EOF
CREATE USER notes WITH PASSWORD 'your_secure_password_here';
ALTER USER notes CREATEDB;
CREATE DATABASE notes WITH OWNER notes;
\q
EOF

exit
```

### 2. Enable PostGIS Extension

```bash
psql -d notes -U notes << EOF
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS btree_gist;
\q
EOF
```

### 3. Verify Database Setup

```bash
psql -d notes -U notes -c "SELECT PostGIS_version();"
psql -d notes -U notes -c "\dx"  # List installed extensions
```

---

## Project Installation

### 1. Clone Repository with Submodules

```bash
# Clone with submodules (recommended)
git clone --recurse-submodules https://github.com/OSM-Notes/OSM-Notes-Ingestion.git
cd OSM-Notes-Ingestion

# Or if already cloned, initialize submodules
git submodule update --init --recursive
```

### 2. Verify Submodule Installation

```bash
# Check submodule status
git submodule status

# Verify common functions exist
ls -la lib/osm-common/commonFunctions.sh
ls -la lib/osm-common/validationFunctions.sh
ls -la lib/osm-common/errorHandlingFunctions.sh
ls -la lib/osm-common/bash_logger.sh
```

### 3. Install System Directories (Optional - for Production)

For production installations, create system directories:

```bash
sudo bin/scripts/install_directories.sh
```

This creates:
- `/var/log/osm-notes-ingestion/` - Log files
- `/var/tmp/osm-notes-ingestion/` - Temporary files
- `/var/run/osm-notes-ingestion/` - Lock files

**Note**: For development, the system will use `/tmp` directories automatically.

---

## Configuration

### 1. Environment Variables

Create a configuration file or set environment variables:

```bash
# Copy example configuration
cp etc/properties.sh.example etc/properties.sh

# Edit configuration
nano etc/properties.sh
```

### 2. Required Configuration Variables

Set these variables in `etc/properties.sh` or as environment variables:

```bash
# Database connection
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_NAME="notes"
export DB_USER="notes"
export DB_PASSWORD="your_secure_password_here"

# Logging
export LOG_LEVEL="INFO"  # TRACE, DEBUG, INFO, WARN, ERROR, FATAL

# Processing options
export SKIP_XML_VALIDATION="false"  # Set to "true" to skip XML validation
```

### 3. Source Configuration

```bash
# Source the configuration file
source etc/properties.sh

# Or export variables directly
export DB_NAME="notes"
export DB_USER="notes"
# ... etc
```

---

## Verification

### 1. Verify Prerequisites

Run the prerequisites check:

```bash
# Check all prerequisites
./bin/lib/prerequisitesFunctions.sh

# Or run a test script that checks prerequisites
./tests/run_all_tests.sh --check-prereqs
```

### 2. Test Database Connection

```bash
# Test connection
psql -h localhost -U notes -d notes -c "SELECT version();"

# Test PostGIS
psql -h localhost -U notes -d notes -c "SELECT PostGIS_version();"
```

### 3. Run Tests

```bash
# Run all tests
./tests/run_all_tests.sh

# Run specific test suites
./tests/unit/bash/run_unit_tests.sh
```

### 4. Verify Entry Points

```bash
# Check available entry points
cat bin/Entry_Points.md

# Verify scripts are executable
ls -la bin/process/*.sh
```

---

## Internal Dependencies

### Project Dependencies

**None** - This is the base project and has no dependencies on other OSM-Notes repositories.

However, other projects depend on this one:
- **OSM-Notes-Analytics** requires this project (reads from base tables)
- **OSM-Notes-WMS** requires this project (uses same database)
- **OSM-Notes-Monitoring** monitors this project

### Git Submodule

This project uses **OSM-Notes-Common** as a Git submodule:
- Location: `lib/osm-common/`
- Contains: Shared Bash functions
- **Required**: Yes (must be initialized)

---

## Troubleshooting

### Submodule Issues

If you see errors like `/lib/osm-common/commonFunctions.sh: No such file or directory`:

```bash
# Initialize submodules
git submodule update --init --recursive

# Verify submodule exists
ls -la lib/osm-common/commonFunctions.sh

# If still having issues, re-initialize
git submodule deinit -f lib/osm-common
git submodule update --init --recursive
```

### Database Connection Issues

```bash
# Check PostgreSQL is running
sudo systemctl status postgresql

# Check user permissions
psql -U postgres -c "\du notes"

# Test connection
psql -h localhost -U notes -d notes
```

### Missing Dependencies

```bash
# Check if all tools are installed
which psql parallel jq curl node npm gdalinfo

# Install missing tools (see System Dependencies section above)
```

### Permission Issues

```bash
# Ensure scripts are executable
chmod +x bin/process/*.sh
chmod +x bin/monitor/*.sh
chmod +x bin/scripts/*.sh

# Check directory permissions
ls -la /var/log/osm-notes-ingestion/  # If using installed mode
ls -la /tmp/osm-notes-ingestion/      # If using fallback mode
```

---

## Next Steps

After installation:

1. **Read Entry Points**: `bin/Entry_Points.md` - Which scripts to use
2. **Review Environment Variables**: `bin/Environment_Variables.md` - Configuration options
3. **Run Tests**: `./tests/run_all_tests.sh` - Verify installation
4. **Read Documentation**: `docs/README.md` - Complete documentation index

---

## Related Documentation

- [Entry Points](bin/Entry_Points.md) - Which scripts can be called directly
- [Environment Variables](bin/Environment_Variables.md) - Complete configuration reference
- [Local Setup Guide](Local_Setup.md) - Development environment setup
- [PostgreSQL Setup](Postgresql_Setup.md) - Database configuration details
- [Testing Guide](Testing_Guide.md) - How to run tests
