---
title: "Troubleshooting Guide"
description: "This comprehensive troubleshooting guide consolidates common problems and solutions for the"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "troubleshooting"
  - "guide"
audience:
  - "users"
  - "developers"
project: "OSM-Notes-Ingestion"
status: "active"
---


# Troubleshooting Guide

**Version:** 2025-12-08

This comprehensive troubleshooting guide consolidates common problems and solutions for the
OSM-Notes-Ingestion system. Problems are organized by category for easy navigation.

## Table of Contents

- [Quick Diagnostic Commands](#quick-diagnostic-commands)
- [Database Issues](#database-issues)
- [API Processing Issues](#api-processing-issues)
- [Planet Processing Issues](#planet-processing-issues)
- [Network and Connectivity](#network-and-connectivity)
- [Performance Issues](#performance-issues)
- [Error Code Reference](#error-code-reference)
- [Recovery Procedures](#recovery-procedures)
- [Getting Help](#getting-help)

---

## Quick Diagnostic Commands

Use these commands to quickly assess system health:

```bash
# Check if scripts are running
ps aux | grep -E "processAPI|processPlanet|updateCountries"

# Check lock files
ls -la /tmp/*.lock

# Check failed execution markers
ls -la /tmp/*_failed_execution

# Find latest logs
# Find latest logs (works in both installed and fallback modes)
LATEST_API=$(find /var/log/osm-notes-ingestion/processing /tmp/osm-notes-ingestion/logs/processing \
  -name "processAPINotes.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
  sort -n | tail -1 | awk '{print $2}')
LATEST_PLANET=$(find /var/log/osm-notes-ingestion/processing /tmp/osm-notes-ingestion/logs/processing \
  -name "processPlanetNotes.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
  sort -n | tail -1 | awk '{print $2}')
echo "API log: $LATEST_API"
echo "Planet log: $LATEST_PLANET"

# Check database connection
psql -d "${DBNAME:-notes}" -c "SELECT version();"

# Check disk space
df -h

# Check memory
free -h
```

---

## Database Issues

### Problem: Cannot Connect to Database

**Symptoms:**

- Error: "could not connect to server"
- Scripts fail immediately
- Database operations timeout

**Diagnosis:**

```bash
# Check PostgreSQL service status
sudo systemctl status postgresql

# Test connection
psql -d "${DBNAME:-notes}" -c "SELECT 1;"

# Check credentials in properties file
# Note: etc/properties.sh should be created from etc/properties.sh.example
if [[ -f etc/properties.sh ]]; then
  cat etc/properties.sh | grep -E "DBNAME|DB_USER|DB_PASSWORD|DB_HOST|DB_PORT"
else
  echo "ERROR: etc/properties.sh not found. Create it from etc/properties.sh.example"
fi

# Verify database exists
psql -l | grep "${DBNAME:-notes}"

# Check firewall (if remote database)
sudo iptables -L | grep postgresql
```

**Solutions:**

1. **Start PostgreSQL service:**

   ```bash
   sudo systemctl start postgresql
   sudo systemctl enable postgresql  # Enable auto-start
   ```

2. **Verify database credentials:**
   - Create `etc/properties.sh` from `etc/properties.sh.example` if it doesn't exist
   - Check `etc/properties.sh` for correct values
   - Test connection manually: `psql -h HOST -U USER -d DBNAME`

3. **Create database if missing:**

   ```bash
   createdb "${DBNAME:-notes}"
   psql -d "${DBNAME:-notes}" -c "CREATE EXTENSION IF NOT EXISTS postgis;"
   ```

4. **Check firewall rules** (if using remote database):
   ```bash
   # Allow PostgreSQL port (default 5432)
   sudo ufw allow 5432/tcp
   ```

### Problem: Database Out of Space

**Symptoms:**

- Error: "No space left on device"
- Database operations fail
- Disk usage at 100%

**Diagnosis:**

```bash
# Check disk space
df -h

# Check database size
psql -d "${DBNAME:-notes}" -c "SELECT pg_size_pretty(pg_database_size('${DBNAME:-notes}'));"

# Check table sizes
psql -d "${DBNAME:-notes}" -c "
SELECT
  schemaname,
  tablename,
  pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
"

# Check temporary files
du -sh /tmp/process*_* 2>/dev/null
```

**Solutions:**

1. **Free up disk space:**

   ```bash
   # Remove old log directories
   find /tmp -name "process*_*" -type d -mtime +7 -exec rm -rf {} \;

   # Remove old temporary files
   rm -rf /tmp/process*_*/tmp_* 2>/dev/null
   ```

2. **Vacuum database:**

   ```bash
   psql -d "${DBNAME:-notes}" -c "VACUUM FULL;"
   psql -d "${DBNAME:-notes}" -c "VACUUM ANALYZE;"
   ```

3. **Archive old data** (if applicable):
   - Export old notes to archive
   - Remove archived data from active tables

4. **Increase disk space** or use different partition for database

### Problem: Slow Database Queries

**Symptoms:**

- Queries take very long to execute
- Scripts timeout
- High CPU usage on database server

**Diagnosis:**

```bash
# Analyze query performance
psql -d "${DBNAME:-notes}" -c "EXPLAIN ANALYZE SELECT COUNT(*) FROM notes;"

# Check for missing indexes
psql -d "${DBNAME:-notes}" -c "
SELECT
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
"

# Check table statistics
psql -d "${DBNAME:-notes}" -c "
SELECT
  schemaname,
  tablename,
  n_live_tup,
  n_dead_tup,
  last_vacuum,
  last_autovacuum,
  last_analyze,
  last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
"
```

**Solutions:**

1. **Update statistics:**

   ```bash
   psql -d "${DBNAME:-notes}" -c "ANALYZE;"
   ```

2. **Rebuild indexes:**

   ```bash
   psql -d "${DBNAME:-notes}" -c "REINDEX DATABASE ${DBNAME:-notes};"
   ```

3. **Vacuum dead rows:**

   ```bash
   psql -d "${DBNAME:-notes}" -c "VACUUM FULL notes;"
   ```

4. **Check for missing indexes** (review query plans and add indexes as needed)

5. **Optimize PostgreSQL configuration:**
   - Increase `shared_buffers`
   - Adjust `work_mem` for complex queries
   - Tune `maintenance_work_mem` for VACUUM operations

### Problem: PostGIS Extension Missing or Errors

**Symptoms:**

- Error: "function does not exist"
- Spatial queries fail
- Country assignment fails
- Error: "extension postgis does not exist"

**Diagnosis:**

```bash
# Check PostGIS extension
psql -d "${DBNAME:-notes}" -c "SELECT PostGIS_version();"

# Check if extension is enabled
psql -d "${DBNAME:-notes}" -c "\dx" | grep postgis

# Test spatial functions
psql -d "${DBNAME:-notes}" -c "SELECT ST_Contains(ST_MakePoint(0,0), ST_MakePoint(0,0));"
```

**Solutions:**

1. **Install PostGIS extension:**

   ```bash
   # Install PostGIS package (Ubuntu/Debian)
   sudo apt-get install postgis postgresql-XX-postgis-3

   # Enable extension in database
   psql -d "${DBNAME:-notes}" -c "CREATE EXTENSION IF NOT EXISTS postgis;"
   ```

2. **Verify PostGIS version** (3.0+ recommended):

   ```bash
   psql -d "${DBNAME:-notes}" -c "SELECT PostGIS_version();"
   ```

3. **Re-run geographic data processing:**
   ```bash
   ./bin/process/updateCountries.sh
   ```

---

## API Processing Issues

### Problem: API Processing Fails Repeatedly

**Symptoms:**

- Script exits with error code
- Failed execution marker created
- No new notes processed

**Diagnosis:**

```bash
# Check latest error logs
# Find latest log (works in both modes)
LATEST_LOG=$(find /var/log/osm-notes-ingestion/processing /tmp/osm-notes-ingestion/logs/processing \
  -name "processAPINotes.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
  sort -n | tail -1 | awk '{print $2}')
if [[ -n "${LATEST_LOG}" ]] && [[ -f "${LATEST_LOG}" ]]; then
  grep -i "error\|failed\|fatal" "${LATEST_LOG}" | tail -20
fi

# Check failed execution marker (works in both modes)
FAILED_FILE=$(find /var/run/osm-notes-ingestion /tmp/osm-notes-ingestion/locks \
  -name "processAPINotes_failed_execution" 2>/dev/null | head -1)
if [[ -n "${FAILED_FILE}" ]] && [[ -f "${FAILED_FILE}" ]]; then
  cat "${FAILED_FILE}"
fi

# Check database connection
psql -d "${DBNAME:-notes}" -c "SELECT 1;" 2>&1

# Check base tables exist
psql -d "${DBNAME:-notes}" -c "SELECT COUNT(*) FROM notes;" 2>&1
```

**Solutions:**

1. **Network connectivity issues:**

   ```bash
   # Test OSM API connectivity
   curl -I "https://api.openstreetmap.org/api/0.6/notes"

   # Check DNS resolution
   nslookup api.openstreetmap.org
   ```

2. **Database connection problems:**
   - See [Database Issues](#database-issues) section above

3. **Missing base tables:**

   ```bash
   # Run Planet processing to create base tables
   ./bin/process/processPlanetNotes.sh --base
   ```

4. **Review specific error in logs** and follow corresponding solution

### Problem: Large Gaps in Note Sequence

**Symptoms:**

- Missing note IDs in sequence
- Logs show gap warnings
- Suspicious data gaps

**Diagnosis:**

```bash
# Check for gaps in note sequence
psql -d "${DBNAME:-notes}" -c "
SELECT
  note_id,
  LAG(note_id) OVER (ORDER BY note_id) as prev_id,
  note_id - LAG(note_id) OVER (ORDER BY note_id) as gap
FROM notes
ORDER BY note_id DESC
LIMIT 20;
"

# Check last processed sequence
psql -d "${DBNAME:-notes}" -c "
SELECT value FROM properties WHERE key = 'last_update';
"
```

**Solutions:**

1. **If gaps are legitimate** (API was down):
   - Script will continue processing automatically
   - No action needed

2. **If gaps are suspicious:**
   - Review gap details in logs
   - Consider full Planet sync:
     ```bash
     ./bin/process/processPlanetNotes.sh --base
     ```

3. **Check API status:**
   ```bash
   curl -I "https://api.openstreetmap.org/api/0.6/notes"
   ```

### Problem: Process Planet Conflict

**Symptoms:**

- Error: "Planet process is currently running"
- Error code: 246
- Cannot start API processing

**Diagnosis:**

```bash
# Check if processPlanetNotes.sh is actually running
ps aux | grep processPlanetNotes.sh | grep -v grep

# Check lock file
# Find and display lock file (works in both modes)
LOCK_FILE=$(find /var/run/osm-notes-ingestion /tmp/osm-notes-ingestion/locks \
  -name "processPlanetNotes.lock" 2>/dev/null | head -1)
if [[ -n "${LOCK_FILE}" ]]; then
  cat "${LOCK_FILE}"
fi
```

**Solutions:**

1. **If processPlanetNotes.sh is running:**
   - Wait for it to complete

   # Monitor progress (works in both modes)

   LATEST_LOG=$(find /var/log/osm-notes-ingestion/processing /tmp/osm-notes-ingestion/logs/processing \
     -name "processPlanetNotes.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
     sort -n | tail -1 | awk '{print $2}')
   if [[ -n "${LATEST_LOG}"
   ]] && [[-f "${LATEST_LOG}"]]; then tail -f "${LATEST_LOG}" fi

2. **If lock file is stale** (process not running):

   ```bash
   # Verify process is not running
   ps aux | grep processPlanetNotes.sh | grep -v grep

   # If not running, remove stale lock
   # Remove lock file (works in both modes)
   LOCK_FILE=$(find /var/run/osm-notes-ingestion /tmp/osm-notes-ingestion/locks \
     -name "processPlanetNotes.lock" 2>/dev/null | head -1)
   if [[ -n "${LOCK_FILE}" ]]; then
     rm "${LOCK_FILE}"
   fi
   ```

### Problem: CSV Validation Failures

**Symptoms:**

- Error: "CSV validation failed"
- Processing stops at CSV stage
- Invalid data format errors

**Diagnosis:**

```bash
# Check CSV validation errors in logs
# Find latest log (works in both modes)
LATEST_LOG=$(find /var/log/osm-notes-ingestion/processing /tmp/osm-notes-ingestion/logs/processing \
  -name "processAPINotes.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
  sort -n | tail -1 | awk '{print $2}')
if [[ -n "${LATEST_LOG}" ]] && [[ -f "${LATEST_LOG}" ]]; then
  grep -i "csv.*valid\|validation.*fail" "${LATEST_LOG}"
fi

# Inspect CSV files (if CLEAN=false)
# Find CSV files in temporary directories (works in both modes)
find /var/tmp/osm-notes-ingestion /tmp -type d -name "processAPINotes_*" 2>/dev/null | \
  head -1 | xargs -I {} find {} -name "*.csv" -type f | head -1 | xargs head -20
```

**Solutions:**

1. **Skip CSV validation** (for testing only):

   ```bash
   export SKIP_CSV_VALIDATION=true
   ./bin/process/processAPINotes.sh
   ```

2. **Review CSV structure** and fix data issues

3. **Check AWK extraction script** for parsing problems

---

## Planet Processing Issues

### Problem: Planet Download Fails

**Symptoms:**

- Download timeout or connection reset
- Incomplete Planet file
- Checksum mismatch

**Diagnosis:**

```bash
# Check disk space (Planet files are 2GB+)
df -h

# Test Planet server connectivity
curl -I "https://planet.openstreetmap.org/planet/notes/"

# Check for partial downloads
find /tmp -name "*.xml" -o -name "*.xml.bz2" | head -5

# Check network connectivity
ping -c 3 planet.openstreetmap.org
```

**Solutions:**

1. **Insufficient disk space:**
   - Free up space (see [Database Out of Space](#problem-database-out-of-space))
   - Use different partition for downloads

2. **Network connectivity issues:**
   - Check internet connection
   - Try alternative Planet mirror if available
   - Retry download

3. **Server temporarily unavailable:**
   - Wait and retry later
   - Check Planet server status

4. **Resume interrupted download:**
   ```bash
   # curl can resume with -C flag
   curl -C - -o planet-notes-latest.osn.bz2 "https://planet.openstreetmap.org/planet/notes/planet-notes-latest.osn.bz2"
   ```

### Problem: Out of Memory (OOM) During Processing

**Symptoms:**

- Process killed by system
- Error: "Killed" in logs
- System becomes unresponsive

**Diagnosis:**

```bash
# Check memory usage
free -h

# Check for OOM kills
dmesg | grep -i "killed\|oom"

# Check system logs
journalctl -k | grep -i "oom\|killed" | tail -20
```

**Solutions:**

1. **Reduce MAX_THREADS:**

   ```bash
   export MAX_THREADS=2  # Default is CPU cores - 2
   ./bin/process/processPlanetNotes.sh --base
   ```

2. **Add swap space:**

   ```bash
   # Check current swap
   swapon --show

   # Add swap file (example: 4GB)
   sudo fallocate -l 4G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   ```

3. **Process during off-peak hours** when system has more available memory

4. **Close other applications** to free memory

### Problem: Disk Space Exhaustion

**Symptoms:**

- Error: "No space left on device"
- Extraction fails
- Database operations fail

**Diagnosis:**

```bash
# Check disk space
df -h

# Find large temporary files
# Check disk usage (works in both modes)
du -sh /var/tmp/osm-notes-ingestion/processPlanetNotes_* /tmp/processPlanetNotes_* 2>/dev/null | sort -h

# Check database size
psql -d "${DBNAME:-notes}" -c "SELECT pg_size_pretty(pg_database_size('${DBNAME:-notes}'));"
```

**Solutions:**

1. **Free up disk space:**

   ```bash
   # Remove old log directories
   find /tmp -name "processPlanetNotes_*" -type d -mtime +7 -exec rm -rf {} \;

   # Remove old temporary files
   # Remove temporary subdirectories (works in both modes)
   find /var/tmp/osm-notes-ingestion /tmp -type d -name "processPlanetNotes_*" 2>/dev/null | \
     xargs -I {} find {} -type d -name "tmp_*" -exec rm -rf {} + 2>/dev/null
   ```

2. **Enable automatic cleanup:**

   ```bash
   export CLEAN=true  # This is the default
   ./bin/process/processPlanetNotes.sh
   ```

3. **Increase disk space** or use different partition

### Problem: Lock File Issues

**Symptoms:**

- Error: "Script is already running"
- Cannot start new execution
- Stale lock file

**Diagnosis:**

```bash
# Check if process is actually running
ps aux | grep processPlanetNotes.sh | grep -v grep

# Check lock file
# Find and display lock file (works in both modes)
LOCK_FILE=$(find /var/run/osm-notes-ingestion /tmp/osm-notes-ingestion/locks \
  -name "processPlanetNotes.lock" 2>/dev/null | head -1)
if [[ -n "${LOCK_FILE}" ]]; then
  cat "${LOCK_FILE}"
fi

# Verify PID in lock file
# Find and check lock file (works in both modes)
LOCK_FILE=$(find /var/run/osm-notes-ingestion /tmp/osm-notes-ingestion/locks \
  -name "processPlanetNotes.lock" 2>/dev/null | head -1)
if [[ -n "${LOCK_FILE}" ]] && [[ -f "${LOCK_FILE}" ]]; then
  LOCK_PID=$(cat "${LOCK_FILE}" | cut -d: -f1)
  ps -p "$LOCK_PID" 2>/dev/null
fi
```

**Solutions:**

1. **If process is not running** (stale lock):

   ```bash
   # Verify process is not running
   ps aux | grep processPlanetNotes.sh | grep -v grep

   # If not running, remove stale lock
   # Remove lock file (works in both modes)
   LOCK_FILE=$(find /var/run/osm-notes-ingestion /tmp/osm-notes-ingestion/locks \
     -name "processPlanetNotes.lock" 2>/dev/null | head -1)
   if [[ -n "${LOCK_FILE}" ]]; then
     rm "${LOCK_FILE}"
   fi
   ```

2. **If process is running:**
   - Wait for completion

   # Monitor progress (works in both modes)

   LATEST_LOG=$(find /var/log/osm-notes-ingestion/processing /tmp/osm-notes-ingestion/logs/processing \
     -name "processPlanetNotes.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
     sort -n | tail -1 | awk '{print $2}')
   if [[ -n "${LATEST_LOG}"
   ]] && [[-f "${LATEST_LOG}"]]; then tail -f "${LATEST_LOG}" fi

3. **Check for zombie processes:**
   ```bash
   ps aux | grep defunct
   ```

### Problem: XML Validation Failures

**Symptoms:**

- Error: "XML validation failed"
- Processing stops at validation stage
- Invalid XML structure errors

**Diagnosis:**

```bash
# Check XML validation errors in logs
LATEST_DIR=$(ls -1rtd /tmp/processPlanetNotes_* 2>/dev/null | tail -1)
grep -i "xml.*valid\|validation.*fail" "$LATEST_DIR/processPlanetNotes.log"

# Validate XML manually (if file exists)
# Find planet file in temporary directories (works in both modes)
PLANET_FILE=$(find /var/tmp/osm-notes-ingestion /tmp -type d -name "processPlanetNotes_*" 2>/dev/null | \
  head -1 | xargs -I {} find {} -name "planet-notes-latest.osn" -type f | head -1)
if [[ -n "${PLANET_FILE}" ]] && [[ -f "${PLANET_FILE}" ]]; then
  xmllint --noout --schema xsd/OSM-notes-planet-schema.xsd "${PLANET_FILE}" 2>&1 | head -20
fi
fi
```

**Solutions:**

1. **Skip XML validation** (for testing only):

   ```bash
   export SKIP_XML_VALIDATION=true
   ./bin/process/processPlanetNotes.sh --base
   ```

2. **Re-download Planet file** (may be corrupted)

3. **Check XML schema** matches Planet file format

---

For **WMS (Web Map Service) troubleshooting**, see the
[OSM-Notes-WMS](https://github.com/OSM-Notes/OSM-Notes-WMS) repository.

## Network and Connectivity

### Problem: Overpass API Rate Limiting

**Symptoms:**

- Boundary downloads fail
- Error: "Rate limit exceeded"
- HTTP 429 errors
- Temporary bans from Overpass API

**Diagnosis:**

```bash
# Check Overpass API status
curl -s "https://overpass-api.de/api/status" | jq

# Review download logs
# Find latest updateCountries log (works in both modes)
LATEST_LOG=$(find /var/log/osm-notes-ingestion/processing /tmp/osm-notes-ingestion/logs/processing \
  -name "updateCountries.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
  sort -n | tail -1 | awk '{print $2}')
if [[ -n "${LATEST_LOG}" ]] && [[ -f "${LATEST_LOG}" ]]; then
  grep -i "overpass\|rate\|limit\|429" "${LATEST_LOG}" | tail -20
fi

# Check rate limit settings
grep -i "RATE_LIMIT\|OVERPASS" etc/properties.sh
```

**Solutions:**

1. **Increase delay between requests:**

   ```bash
   export RATE_LIMIT=5  # seconds between requests (default: 2)
   ./bin/process/updateCountries.sh
   ```

2. **Reduce concurrent downloads:**
   - Semaphore pattern handles this automatically
   - System uses FIFO queue to prevent rate limiting

3. **Wait for rate limit to reset:**
   - Usually resets after 1 hour
   - Check Overpass API status page

4. **Use alternative Overpass instance** if available:
   - Configure different endpoint in properties

5. **Smart waiting:**
   - System automatically waits when rate limited
   - Check logs for "waiting" messages

### Problem: OSM API Connectivity Issues

**Symptoms:**

- Cannot download notes from API
- Connection timeout
- DNS resolution failures

**Diagnosis:**

```bash
# Test OSM API connectivity
curl -I "https://api.openstreetmap.org/api/0.6/notes"

# Check DNS resolution
nslookup api.openstreetmap.org

# Test with timeout
curl --connect-timeout 10 "https://api.openstreetmap.org/api/0.6/notes"
```

**Solutions:**

1. **Check internet connection:**

   ```bash
   ping -c 3 8.8.8.8
   ping -c 3 api.openstreetmap.org
   ```

2. **Check firewall rules:**

   ```bash
   sudo iptables -L | grep -E "OUTPUT|443|80"
   ```

3. **Increase timeout:**

   ```bash
   export API_TIMEOUT=60  # seconds
   ./bin/process/processAPINotes.sh
   ```

4. **Check proxy settings** (if behind proxy):
   - Configure `http_proxy` and `https_proxy` environment variables

---

## Performance Issues

### Problem: Slow Processing

**Symptoms:**

- Scripts take very long to complete
- High CPU usage
- Processing times exceed expected duration

**Diagnosis:**

```bash
# Check processing times in logs
grep "Processing time\|Total time" /tmp/process*_*/process*.log | tail -10

# Check CPU usage
top -bn1 | grep -E "processAPI|processPlanet|updateCountries"

# Check database performance
psql -d "${DBNAME:-notes}" -c "EXPLAIN ANALYZE SELECT COUNT(*) FROM notes;"

# Check parallel processing configuration
echo "MAX_THREADS: ${MAX_THREADS:-$(nproc)}"
```

**Solutions:**

1. **Optimize database:**

   ```bash
   psql -d "${DBNAME:-notes}" -c "ANALYZE;"
   psql -d "${DBNAME:-notes}" -c "VACUUM FULL;"
   ```

2. **Adjust parallel processing:**

   ```bash
   # Increase threads if CPU available
   export MAX_THREADS=8  # Default is CPU cores - 2

   # Decrease if memory constrained
   export MAX_THREADS=2
   ```

3. **Check for missing indexes:**
   - Review query plans
   - Add indexes for frequently queried columns

4. **Use faster storage** (SSD) for database

5. **Process during off-peak hours** when system has more resources

### Problem: High Memory Usage

**Symptoms:**

- System becomes slow
- Swap usage increases
- Risk of OOM kills

**Diagnosis:**

```bash
# Check memory usage
free -h

# Check process memory
ps aux | grep -E "processAPI|processPlanet" | awk '{print $2, $6/1024 " MB"}'

# Check swap usage
swapon --show
```

**Solutions:**

1. **Reduce MAX_THREADS:**

   ```bash
   export MAX_THREADS=2
   ```

2. **Add swap space** (see [Out of Memory](#problem-out-of-memory-oom-during-processing))

3. **Close other applications** to free memory

4. **Process smaller batches** by adjusting chunk sizes

---

## Error Code Reference

### Standard Error Codes

All scripts use standardized error codes defined in `lib/osm-common/commonFunctions.sh`:

| Code  | Meaning                             | Solution                                          |
| ----- | ----------------------------------- | ------------------------------------------------- |
| `1`   | Help message displayed              | Normal exit, no action needed                     |
| `238` | Previous execution failed           | Check failed marker, fix issue, remove marker     |
| `239` | Error creating report               | Check report directory permissions                |
| `241` | Library or utility missing          | Install missing dependencies                      |
| `242` | Invalid argument                    | Check script parameters                           |
| `243` | Logger utility is missing           | Verify `lib/osm-common/` submodule is initialized |
| `244` | Error downloading boundary ID list  | Check Overpass API connectivity                   |
| `245` | No last update timestamp            | Run `processPlanetNotes.sh --base` first          |
| `246` | Planet process is currently running | Wait for Planet processing to complete            |
| `247` | Error downloading notes             | Check OSM API connectivity                        |
| `248` | Error executing Planet dump         | Check Planet processing logs                      |
| `249` | Error downloading boundary          | Check Overpass API connectivity                   |
| `250` | Error GeoJSON conversion            | Check GDAL/ogr2ogr installation                   |
| `251` | Internet issue                      | Check network connectivity                        |
| `252` | Data validation error               | Check input data format                           |
| `255` | General error                       | Review logs for specific issue                    |

### Script-Specific Error Codes

#### processAPINotes.sh

| Code  | Meaning                             | Solution                                          |
| ----- | ----------------------------------- | ------------------------------------------------- |
| `1`   | Help message displayed              | Normal exit, no action needed                     |
| `238` | Previous execution failed           | Check failed marker, fix issue, remove marker     |
| `241` | Library or utility missing          | Install missing dependencies                      |
| `242` | Invalid argument                    | Check script parameters                           |
| `243` | Logger utility is missing           | Verify `lib/osm-common/` submodule is initialized |
| `245` | No last update timestamp            | Run `processPlanetNotes.sh --base` first          |
| `246` | Planet process is currently running | Wait for Planet processing to complete            |
| `248` | Error executing Planet dump         | Check Planet processing logs                      |

#### processPlanetNotes.sh

| Code  | Meaning                             | Solution                                          |
| ----- | ----------------------------------- | ------------------------------------------------- |
| `1`   | Help message displayed              | Normal exit, no action needed                     |
| `238` | Previous execution failed           | Check failed marker, fix issue, remove marker     |
| `241` | Library or utility missing          | Install missing dependencies                      |
| `242` | Invalid argument                    | Check script parameters                           |
| `243` | Logger utility is missing           | Verify `lib/osm-common/` submodule is initialized |
| `244` | Error downloading boundary ID list  | Check Overpass API connectivity                   |
| `245` | No last update timestamp            | Run `processPlanetNotes.sh --base` first          |
| `246` | Planet process is currently running | Wait for Planet processing to complete            |
| `247` | Error downloading notes             | Check Planet download connectivity                |
| `248` | Error executing Planet dump         | Check Planet processing logs                      |
| `249` | Error downloading boundary          | Check Overpass API connectivity                   |
| `250` | Error GeoJSON conversion            | Check GDAL/ogr2ogr installation                   |
| `251` | Internet issue                      | Check network connectivity                        |
| `252` | Data validation error               | Check input data format                           |
| `255` | General error                       | Review logs for specific issue                    |

#### updateCountries.sh

| Code  | Meaning                    | Solution                           |
| ----- | -------------------------- | ---------------------------------- |
| `1`   | Help message displayed     | Normal exit                        |
| `238` | Previous execution failed  | Check failed marker                |
| `241` | Library or utility missing | Install missing dependencies       |
| `242` | Invalid argument           | Check script parameters            |
| `243` | Logger utility is missing  | Verify `lib/osm-common/` submodule |
| `249` | Error downloading boundary | Check Overpass API connectivity    |
| `250` | Error GeoJSON conversion   | Check GDAL/ogr2ogr installation    |
| `255` | General error              | Review logs                        |

#### notesCheckVerifier.sh

| Code  | Meaning                    | Solution                           |
| ----- | -------------------------- | ---------------------------------- |
| `1`   | Help message displayed     | Normal exit                        |
| `238` | Previous execution failed  | Check failed marker                |
| `239` | Error creating report      | Check report directory permissions |
| `241` | Library or utility missing | Install missing dependencies       |
| `242` | Invalid argument           | Check script parameters            |
| `243` | Logger utility is missing  | Verify `lib/osm-common/` submodule |
| `255` | General error              | Review logs                        |

#### processCheckPlanetNotes.sh

| Code  | Meaning                    | Solution                           |
| ----- | -------------------------- | ---------------------------------- |
| `1`   | Help message displayed     | Normal exit                        |
| `238` | Previous execution failed  | Check failed marker                |
| `241` | Library or utility missing | Install missing dependencies       |
| `242` | Invalid argument           | Check script parameters            |
| `243` | Logger utility is missing  | Verify `lib/osm-common/` submodule |
| `247` | Error downloading notes    | Check Planet download connectivity |
| `255` | General error              | Review logs                        |

#### Script Error Codes

| Code  | Meaning                    | Solution                                                |
| ----- | -------------------------- | ------------------------------------------------------- |
| `1`   | Help message displayed     | Normal exit                                             |
| `241` | Library or utility missing | Install missing dependencies (PostGIS, SQL files)       |
| `242` | Invalid argument           | Check script parameters                                 |
| `255` | General error              | Review logs (database connection, PostGIS installation) |

|------|---------|----------| | `1` | Help message displayed | Normal exit | | `241` | Library or
utility missing | Install missing dependencies (curl, jq, etc.) | | `242` | Invalid argument | Check
script parameters | | `255` | General error | Review logs (GeoServer connection, authentication) |

#### cleanupAll.sh

| Code  | Meaning                    | Solution                     |
| ----- | -------------------------- | ---------------------------- |
| `1`   | Help message displayed     | Normal exit                  |
| `241` | Library or utility missing | Install missing dependencies |
| `242` | Invalid argument           | Check script parameters      |
| `255` | General error              | Review logs                  |

#### analyzeDatabasePerformance.sh

| Code  | Meaning                    | Solution                                                    |
| ----- | -------------------------- | ----------------------------------------------------------- |
| `1`   | Help message displayed     | Normal exit                                                 |
| `241` | Library or utility missing | Install missing dependencies (SQL analysis scripts)         |
| `242` | Invalid argument           | Check script parameters                                     |
| `255` | General error              | Review logs (database connection, analysis script failures) |

#### Scripts in bin/scripts/

All utility scripts (`exportCountriesBackup.sh`, `exportMaritimesBackup.sh`,
`generateNoteLocationBackup.sh`) use:

| Code  | Meaning                    | Solution                                           |
| ----- | -------------------------- | -------------------------------------------------- |
| `1`   | Help message displayed     | Normal exit                                        |
| `249` | Error downloading boundary | Check Overpass API connectivity                    |
| `255` | General error              | Review logs (database connection, file operations) |

### Recovery for Each Error Code

1. **Check failed execution marker:**

   ```bash
   # Find and display failed execution markers (works in both modes)
   FAILED_API=$(find /var/run/osm-notes-ingestion /tmp/osm-notes-ingestion/locks \
     -name "processAPINotes_failed_execution" 2>/dev/null | head -1)
   FAILED_PLANET=$(find /var/run/osm-notes-ingestion /tmp/osm-notes-ingestion/locks \
     -name "processPlanetNotes_failed_execution" 2>/dev/null | head -1)
   if [[ -n "${FAILED_API}" ]] && [[ -f "${FAILED_API}" ]]; then
     cat "${FAILED_API}"
   fi
   if [[ -n "${FAILED_PLANET}" ]] && [[ -f "${FAILED_PLANET}" ]]; then
     cat "${FAILED_PLANET}"
   fi
   ```

2. **Review logs for specific error:**

   ```bash
   # Find latest log (works in both modes)
   LATEST_LOG=$(find /var/log/osm-notes-ingestion/processing /tmp/osm-notes-ingestion/logs/processing \
     -name "processAPINotes.log" -type f -printf '%T@ %p\n' 2>/dev/null | \
     sort -n | tail -1 | awk '{print $2}')
   if [[ -n "${LATEST_LOG}" ]] && [[ -f "${LATEST_LOG}" ]]; then
     tail -100 "${LATEST_LOG}"
   fi
   ```

3. **Fix underlying issue** (see specific problem sections above)

4. **Remove failed marker:**

   ```bash
   rm /tmp/processAPINotes_failed_execution
   rm /tmp/processPlanetNotes_failed_execution
   ```

5. **Wait for next scheduled execution** (recommended) or run manually for testing

---

## Recovery Procedures

### After Failed Execution

1. **Check failed execution marker:**

   ```bash
   if [ -f /tmp/processAPINotes_failed_execution ]; then
     cat /tmp/processAPINotes_failed_execution
   fi
   ```

2. **Review logs:**

   ```bash
   LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* 2>/dev/null | tail -1)
   if [ -n "$LATEST_DIR" ]; then
     tail -100 "$LATEST_DIR/processAPINotes.log"
   fi
   ```

3. **Fix underlying issue** (see specific problem sections above)

4. **Remove failed marker:**

   ```bash
   rm /tmp/processAPINotes_failed_execution
   ```

5. **Wait for next scheduled execution** (recommended for production):
   - Scripts are designed for automated execution via cron
   - Manual execution is only for testing/debugging

### Partial Processing Recovery

If processing was interrupted:

1. **Check what was completed:**

   ```bash
   psql -d "${DBNAME:-notes}" -c "SELECT COUNT(*) FROM notes;"
   psql -d "${DBNAME:-notes}" -c "SELECT MAX(created_at) FROM notes;"
   ```

2. **For `--base` mode:**
   - Re-run from scratch (will drop and recreate tables)
   - All data will be reloaded

3. **For sync mode:**
   - Re-run normally (will only process new notes)
   - Script handles partial processing automatically

### Database Recovery

If database corruption is suspected:

1. **Backup current state:**

   ```bash
   pg_dump "${DBNAME:-notes}" > backup_before_recovery_$(date +%Y%m%d).sql
   ```

2. **Restore from Planet:**

   ```bash
   ./bin/process/processPlanetNotes.sh --base
   ```

3. **Reload boundaries:**

   ```bash
   ./bin/process/updateCountries.sh --base
   ```

4. **Regenerate backups:**

   ```bash
   ./bin/scripts/generateNoteLocationBackup.sh
   ./bin/scripts/exportCountriesBackup.sh
   ./bin/scripts/exportMaritimesBackup.sh
   ```

5. **Verify recovery:**
   ```bash
   psql -d "${DBNAME:-notes}" -c "SELECT COUNT(*) FROM notes;"
   psql -d "${DBNAME:-notes}" -c "SELECT MAX(created_at) FROM notes;"
   ```

---

## Getting Help

### Review Documentation

- **[Documentation.md](./Documentation.md)**: Complete system documentation
- **[Process_API.md](./Process_API.md)**: API processing details and troubleshooting
- **[Process_Planet.md](./Process_Planet.md)**: Planet processing details and troubleshooting For
  **WMS (Web Map Service) documentation**, see the
  [OSM-Notes-WMS](https://github.com/OSM-Notes/OSM-Notes-WMS) repository.

### Check Logs

```bash
# Find all log directories
ls -1rtd /tmp/process*_* 2>/dev/null

# Review latest errors
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* 2>/dev/null | tail -1)
if [ -n "$LATEST_DIR" ]; then
  grep -i "error\|failed\|fatal" "$LATEST_DIR/processAPINotes.log" | tail -50
fi
```

### Common Recovery Steps

1. Check failed execution marker (if exists)
2. Review latest logs for error details
3. Verify prerequisites (database, network, disk space)
4. Fix underlying issue (see specific problem sections)
5. Remove failed marker (if exists)
6. Wait for next scheduled execution (recommended) or run manually for testing

### Diagnostic Scripts

Use these scripts for automated diagnostics:

```bash
# Database performance analysis
./bin/monitor/analyzeDatabasePerformance.sh

# Data integrity verification
./bin/monitor/notesCheckVerifier.sh
```

### Community Support

- **GitHub Issues**: Report bugs and request features
- **Documentation**: Review comprehensive guides
- **Logs**: Always include relevant log excerpts when asking for help

---

## Related Documentation

### Core Documentation

- **[Documentation.md](./Documentation.md)**: Complete system documentation and architecture
- **[Component_Dependencies.md](./Component_Dependencies.md)**: Component dependencies and
  relationships
- **[Rationale.md](./Rationale.md)**: Project motivation and design decisions

### Processing Documentation

- **[Process_API.md](./Process_API.md)**: API processing details, troubleshooting, and error codes
- **[Process_Planet.md](./Process_Planet.md)**: Planet processing details, troubleshooting, and
  error codes

### Spatial Processing Documentation

- **[Country_Assignment_2D_Grid.md](./Country_Assignment_2D_Grid.md)**: Country assignment algorithm
  and spatial processing
- **[Capital_Validation_Explanation.md](./Capital_Validation_Explanation.md)**: Capital validation
  mechanism
- **[ST_DWithin_Explanation.md](./ST_Dwithin_Explanation.md)**: PostGIS spatial functions
  explanation

### Service Documentation

For **WMS (Web Map Service) documentation**, see the
[OSM-Notes-WMS](https://github.com/OSM-Notes/OSM-Notes-WMS) repository.

### Script Reference

- **[bin/README.md](../bin/README.md)**: Script usage examples and common use cases
- **[bin/ENTRY_POINTS.md](../bin/ENTRY_POINTS.md)**: Script entry points and parameters
- **[bin/ENVIRONMENT_VARIABLES.md](../bin/ENVIRONMENT_VARIABLES.md)**: Environment variable
  documentation

### Testing Documentation

- **[Testing_Guide.md](./Testing_Guide.md)**: Testing procedures and troubleshooting
- **[CI_Troubleshooting.md](./CI_Troubleshooting.md)**: CI/CD troubleshooting guide
