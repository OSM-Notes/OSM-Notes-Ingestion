# Installation Guide

**Purpose:** Guide for installing OSM-Notes-Ingestion directories and configuration

## Overview

OSM-Notes-Ingestion supports two modes of operation:

1. **Installed Mode** (Production): Uses standard Linux directories (`/var/log`, `/var/tmp`)
2. **Fallback Mode** (Testing/Development): Uses `/tmp` directories (no installation required)

The system automatically detects which mode to use based on directory existence and permissions.

## Installation Steps

### 1. Create Directories

Run the installation script as root:

```bash
sudo bin/scripts/install_directories.sh
```

This script:
- Creates `/var/log/osm-notes-ingestion/` with subdirectories (daemon, processing, monitoring)
- Creates `/var/tmp/osm-notes-ingestion/` with subdirectories (planet, overpass, api)
- Creates `/var/run/osm-notes-ingestion/` for lock files
- Sets proper ownership and permissions
- Configures logrotate for automatic log rotation

### 2. Verify Installation

```bash
# Check directories
ls -la /var/log/osm-notes-ingestion/
ls -la /var/tmp/osm-notes-ingestion/
ls -la /var/run/osm-notes-ingestion/

# Test write access (replace 'notes' with your user)
sudo -u notes touch /var/log/osm-notes-ingestion/test.log
sudo -u notes rm /var/log/osm-notes-ingestion/test.log
```

### 3. Configure Logrotate (Optional)

The installation script creates `/etc/logrotate.d/osm-notes-ingestion` with:
- Daily rotation
- 30 days retention
- Automatic compression
- Uses `copytruncate` to avoid interrupting the daemon during rotation

**Note:** If you have an existing installation with the old configuration (that reloads the daemon), you can update it by running:
```bash
sudo bin/scripts/update_logrotate_config.sh
```

To customize, edit `/etc/logrotate.d/osm-notes-ingestion`.

## Running Without Installation

If you don't want to install (e.g., for testing), the system automatically falls back to `/tmp`:

```bash
# No installation needed - just run scripts
./bin/process/processAPINotes.sh
```

The system will:
- Use `/tmp/osm-notes-ingestion/logs/` for logs
- Use `/tmp/` for temporary files
- Use `/tmp/osm-notes-ingestion/locks/` for lock files

**Note:** Files in `/tmp` are deleted on system reboot.

## Manual Override

You can override directory locations using environment variables:

```bash
export LOG_DIR=/custom/logs
export TMP_DIR=/custom/tmp
export LOCK_DIR=/custom/locks
./bin/process/processAPINotes.sh
```

Or force fallback mode:

```bash
export FORCE_FALLBACK_MODE=true
./bin/process/processAPINotes.sh
```

## Directory Structure

### Installed Mode

```
/var/log/osm-notes-ingestion/
├── daemon/
│   ├── processAPINotesDaemon.log
│   └── processAPINotesDaemon_gaps.log
├── processing/
│   ├── processAPINotes.log
│   ├── processPlanetNotes.log
│   └── updateCountries.log
└── monitoring/
    └── notesCheckVerifier.log

/var/tmp/osm-notes-ingestion/
├── planet/              # Large planet files (cleaned after processing)
├── overpass/            # Overpass JSON files
└── api/                 # API XML/CSV files

/var/run/osm-notes-ingestion/
└── *.lock               # Lock files
```

### Fallback Mode

```
/tmp/osm-notes-ingestion/
├── logs/
│   ├── daemon/
│   ├── processing/
│   └── monitoring/
└── locks/

/tmp/
└── processAPINotes_XXXXXX/  # Temporary execution directories
```

## Uninstallation

To remove installed directories:

```bash
sudo rm -rf /var/log/osm-notes-ingestion
sudo rm -rf /var/tmp/osm-notes-ingestion
sudo rm -rf /var/run/osm-notes-ingestion
sudo rm /etc/logrotate.d/osm-notes-ingestion
```

## Troubleshooting

### Permission Denied

If you get permission errors:

```bash
# Check ownership
ls -la /var/log/osm-notes-ingestion/

# Fix ownership (replace 'notes' with your user)
sudo chown -R notes:maptimebogota /var/log/osm-notes-ingestion
sudo chown -R notes:maptimebogota /var/tmp/osm-notes-ingestion
sudo chown -R notes:maptimebogota /var/run/osm-notes-ingestion
```

### Logs Not Rotating

Check logrotate configuration:

```bash
# Test logrotate configuration
sudo logrotate -d /etc/logrotate.d/osm-notes-ingestion

# Force rotation (for testing)
sudo logrotate -f /etc/logrotate.d/osm-notes-ingestion
```

### Disk Space Issues

Monitor disk usage:

```bash
# Check log directory size
du -sh /var/log/osm-notes-ingestion/

# Check temp directory size
du -sh /var/tmp/osm-notes-ingestion/

# Clean old logs manually (if needed)
find /var/log/osm-notes-ingestion/ -name "*.log.*" -mtime +30 -delete
```

