# Local Setup - OSM-Notes-Ingestion

**Purpose:** Guide for configuring the system locally (development/testing).

**Date:** 2025-12-18

---

## Option 1: Fallback Mode (Recommended for Development)

**You don't need to do anything.** The system automatically detects that it's not installed and uses fallback mode.

### What does fallback mode do?

- **Logs**: `/tmp/osm-notes-ingestion/logs/{daemon,processing,monitoring}/`
- **Temporary files**: `/tmp/`
- **Lock files**: `/tmp/osm-notes-ingestion/locks/`

### Advantages

- ✅ No root permissions required
- ✅ No additional configuration needed
- ✅ Works immediately
- ✅ Ideal for development and testing

### Usage

```bash
# Simply run scripts normally
./bin/process/processAPINotes.sh

# Logs will be automatically created in:
# /tmp/osm-notes-ingestion/logs/processing/processAPINotes.log
```

### Verify fallback mode

```bash
# Run any script and verify logs
./bin/process/processAPINotes.sh

# Verify that directories were created in /tmp
ls -la /tmp/osm-notes-ingestion/
```

---

## Option 2: Installed Mode (Local Production)

If you want to simulate a production environment locally, you can install the directories.

### Requirements

- Root permissions (sudo)
- User `notes` (or configure `OSM_USER`)

### Installation

```bash
# Option A: Use default user (notes)
sudo bin/scripts/install_directories.sh

# Option B: Specify user and group
sudo OSM_USER=your_user OSM_GROUP=your_group bin/scripts/install_directories.sh
```

### What does the script create?

- **Logs**: `/var/log/osm-notes-ingestion/{daemon,processing,monitoring}/`
- **Temporary files**: `/var/tmp/osm-notes-ingestion/`
- **Lock files**: `/var/run/osm-notes-ingestion/`
- **Logrotate**: Automatic configuration in `/etc/logrotate.d/osm-notes-ingestion`

### Verify installation

```bash
# Verify created directories
ls -la /var/log/osm-notes-ingestion/
ls -la /var/tmp/osm-notes-ingestion/
ls -la /var/run/osm-notes-ingestion/

# Verify permissions
sudo -u notes touch /var/log/osm-notes-ingestion/processing/test.log
sudo -u notes rm /var/log/osm-notes-ingestion/processing/test.log
```

### Uninstallation

```bash
# Remove directories
sudo rm -rf /var/log/osm-notes-ingestion
sudo rm -rf /var/tmp/osm-notes-ingestion
sudo rm -rf /var/run/osm-notes-ingestion

# Remove logrotate
sudo rm -f /etc/logrotate.d/osm-notes-ingestion
```

---

## Force Fallback Mode (Even if Installed)

If you have directories installed but want to use fallback mode for testing:

```bash
# Force fallback mode
export FORCE_FALLBACK_MODE=true
./bin/process/processAPINotes.sh
```

---

## Customize Paths (Advanced)

You can customize paths using environment variables:

```bash
# Customize log paths
export LOG_DIR="/home/user/osm-logs"
export TMP_DIR="/home/user/osm-tmp"
export LOCK_DIR="/home/user/osm-locks"

# Run script
./bin/process/processAPINotes.sh
```

**Note:** If you use custom paths, make sure they exist and are writable.

---

## Mode Comparison

| Feature | Fallback Mode | Installed Mode |
|---------|--------------|----------------|
| **Log location** | `/tmp/osm-notes-ingestion/logs/` | `/var/log/osm-notes-ingestion/` |
| **Temp location** | `/tmp/` | `/var/tmp/osm-notes-ingestion/` |
| **Lock location** | `/tmp/osm-notes-ingestion/locks/` | `/var/run/osm-notes-ingestion/` |
| **Requires root** | ❌ No | ✅ Yes |
| **Persistence** | ❌ Deleted on reboot | ✅ Persistent |
| **Logrotate** | ❌ No | ✅ Yes (automatic) |
| **Ideal for** | Development, Testing | Production |

---

## Recommendation

**For local development:** Use fallback mode (do nothing, works automatically).

**For production:** Run `install_directories.sh` with sudo.

---

## Troubleshooting

### Error: "Permission denied" in installed mode

```bash
# Verify permissions
ls -la /var/log/osm-notes-ingestion/
ls -la /var/tmp/osm-notes-ingestion/
ls -la /var/run/osm-notes-ingestion/

# Fix permissions (if necessary)
sudo chown -R notes:maptimebogota /var/log/osm-notes-ingestion
sudo chown -R notes:maptimebogota /var/tmp/osm-notes-ingestion
sudo chown -R notes:maptimebogota /var/run/osm-notes-ingestion
```

### Verify which mode is being used

```bash
# Run script with LOG_LEVEL=DEBUG
export LOG_LEVEL=DEBUG
./bin/process/processAPINotes.sh 2>&1 | grep -i "Mode:"

# You should see:
# "Mode: INSTALLED (production)" or
# "Mode: FALLBACK (testing/development)"
```

---

**End of document**
