# Bin Directory

## Overview

The `bin` directory contains all the executable scripts and processing components
of the OSM-Notes-Ingestion system. This is the core operational directory where
the main processing logic resides.

## Directory Structure

### `/bin/process/`

Contains the main data processing scripts:

- **`processPlanetNotes.sh`**: Processes OSM notes from Planet files
- **`processAPINotes.sh`**: Processes OSM notes from API endpoints
- **`updateCountries.sh`**: Updates country data and associations

### `/bin/monitor/`

Monitoring and verification scripts:

- **`processCheckPlanetNotes.sh`**: Verifies Planet notes processing
- **`notesCheckVerifier.sh`**: Validates note data integrity

### `/bin/lib/`

Function libraries used by other scripts (not executed directly):

- **`functionsProcess.sh`**: Common processing functions
- **`processAPIFunctions.sh`**: API-specific functions
- **`processPlanetFunctions.sh`**: Planet-specific functions
- **`parallelProcessingFunctions.sh`**: Parallel processing functions
- **`securityFunctions.sh`**: Security and sanitization functions

### `/bin/scripts/`

Utility scripts for data management and maintenance:

- **`generateNoteLocationBackup.sh`**: Generates a CSV backup of note locations
  (note_id, id_country) to speed up subsequent processing runs. The script exports
  all notes with country assignments from the database and creates a compressed
  ZIP file that can be used as a baseline for faster location processing.

### `/bin/cleanupAll.sh`

Database maintenance script for comprehensive cleanup operations:

- **Full cleanup**: Removes all components (WMS, base tables, temporary files)
- **Partition-only cleanup**: Removes only partition tables (use `-p` or `--partitions-only` flag)
- **Database**: Configured via `etc/properties.sh` (DBNAME variable, created from `etc/properties.sh.example`)

## Software Components

### Data Processing Pipeline

- **Planet Processing**: `bin/process/processPlanetNotes.sh` handles large OSM Planet files
- **API Processing**: `bin/process/processAPINotes.sh` processes real-time API data

> **Note:** ETL, Data Warehouse, and Analytics components have been moved to
> [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

### Monitoring & Maintenance

- **Verification**: `bin/monitor/` scripts ensure data quality
- **Backup Generation**:
  - `bin/scripts/generateNoteLocationBackup.sh` creates CSV backups of note location
    data for faster processing
  - `bin/scripts/exportCountriesBackup.sh` exports country boundaries to GeoJSON
  - `bin/scripts/exportMaritimesBackup.sh` exports maritime boundaries to GeoJSON
- **Cleanup**: `bin/cleanupAll.sh` maintains database performance and cleanup operations
  (uses database configured in `etc/properties.sh`)

## Configuration

### Environment Variables

For complete environment variable documentation, see:

- **`bin/ENVIRONMENT_VARIABLES.md`** - All environment variables and their usage

### Entry Points and Parameters

For allowed script entry points and their parameters, see:

- **`bin/ENTRY_POINTS.md`** - Scripts that can be called directly and their usage

## Usage

All scripts in this directory are designed to be run from the project root and
require proper database configuration and dependencies to be installed.

### Quick Start Examples

#### First-Time Setup

Complete initial setup from scratch:

```bash
# 1. Process all historical notes from Planet (takes 1-2 hours)
./bin/process/processPlanetNotes.sh --base

# 2. Load country and maritime boundaries
./bin/process/updateCountries.sh --base

# 3. Verify setup
psql -d osm_notes -c "SELECT COUNT(*) FROM notes;"
psql -d osm_notes -c "SELECT COUNT(*) FROM countries;"

# 4. Generate backups for faster future processing
./bin/scripts/generateNoteLocationBackup.sh
./bin/scripts/exportCountriesBackup.sh
./bin/scripts/exportMaritimesBackup.sh
```

#### Production Deployment

Set up automated processing:

```bash
# Add to crontab (crontab -e)
# Process API notes every 15 minutes
*/15 * * * * cd /path/to/OSM-Notes-Ingestion && ./bin/process/processAPINotes.sh >/dev/null 2>&1

# Daily Planet sync (optional, at 2 AM)
0 2 * * * cd /path/to/OSM-Notes-Ingestion && ./bin/process/processPlanetNotes.sh >/dev/null 2>&1

# Weekly boundary updates (Sundays at 3 AM)
0 3 * * 0 cd /path/to/OSM-Notes-Ingestion && ./bin/process/updateCountries.sh >/dev/null 2>&1
```

#### Development and Testing

Run with debug logging and file preservation:

```bash
# Enable debug logging
export LOG_LEVEL=DEBUG

# Keep temporary files for inspection
export CLEAN=false

# Run API processing
./bin/process/processAPINotes.sh

# Inspect generated files
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
ls -lh "$LATEST_DIR"
cat "$LATEST_DIR/processAPINotes.log"
```

#### Troubleshooting Mode

Run with maximum verbosity:

```bash
# Enable trace-level logging (most verbose)
export LOG_LEVEL=TRACE

# Enable bash debug mode (shows all commands)
export BASH_DEBUG=true

# Keep all files
export CLEAN=false

# Run script
./bin/process/processAPINotes.sh

# Check logs
tail -f $(ls -1rtd /tmp/processAPINotes_* | tail -1)/processAPINotes.log
```

### Main Processing Scripts

#### processAPINotes.sh

Processes recent notes from the OSM API (typically run every 15 minutes via cron).

**Basic Usage:**

```bash
# Standard execution (production mode)
./bin/process/processAPINotes.sh
```

**Expected Output:**

```
[INFO] Preparing environment.
[INFO] Process ID: 12345
[INFO] Processing: ''.
[WARN] Process started.
[INFO] Validating single execution.
[INFO] Dropping API tables...
[INFO] Creating API tables...
[INFO] Getting new notes from API...
[INFO] Processing 150 notes (threshold: 100)
[INFO] Memory check passed, using parallel processing
[INFO] Using GNU parallel for API processing (6 jobs)
[INFO] Consolidating partitions...
[INFO] Inserting new notes and comments...
[INFO] Updating last value...
[WARN] Process finished.
```

**With Debug Logging:**

```bash
export LOG_LEVEL=DEBUG
./bin/process/processAPINotes.sh
```

**Keep Temporary Files for Inspection:**

```bash
export CLEAN=false
export LOG_LEVEL=DEBUG
./bin/process/processAPINotes.sh

# Files will be in /tmp/processAPINotes_XXXXXX/
# - CSV files with extracted data
# - XML file from API
# - Log file with detailed execution trace
```

**Check Help:**

```bash
./bin/process/processAPINotes.sh --help
# or
./bin/process/processAPINotes.sh -h
```

**Exit Codes:**

- `0`: Success
- `1`: Help message displayed
- `238`: Previous execution failed (check `/tmp/processAPINotes_failed_execution`)
- `241`: Library or utility missing
- `242`: Invalid argument
- `245`: No last update timestamp (run `processPlanetNotes.sh --base` first)
- `246`: Planet process is currently running


#### processPlanetNotes.sh

Processes OSM notes from Planet dump files. Can run in two modes: base (from scratch) or sync (incremental).

**Base Mode (Initial Setup):**

```bash
# Complete setup from scratch (takes 1-2 hours)
./bin/process/processPlanetNotes.sh --base
```

**Expected Output (Base Mode):**

```
[INFO] Preparing environment.
[INFO] Process: From scratch.
[WARN] Starting process.
[INFO] Dropping base tables...
[INFO] Creating base tables...
[INFO] Downloading planet file...
[INFO] Extracting notes XML...
[INFO] Processing planet notes with parallel processing...
[INFO] Using 8 threads for parallel processing
[INFO] Processing partition 1/24...
[INFO] Processing partition 2/24...
...
[INFO] Consolidating partitions...
[INFO] Loading notes to base tables...
[INFO] Cleaning notes files...
[INFO] Analyzing and vacuuming database...
[WARN] Ending process.
```

**Sync Mode (Incremental Update):**

```bash
# Process only new notes from Planet
./bin/process/processPlanetNotes.sh
```

**Expected Output (Sync Mode):**

```
[INFO] Preparing environment.
[INFO] Process: Imports new notes from Planet.
[WARN] Starting process.
[INFO] Dropping sync tables...
[INFO] Creating sync tables...
[INFO] Downloading planet file...
[INFO] Processing new notes...
[INFO] Loading sync notes (only new)...
[INFO] Moving sync to main tables...
[INFO] Cleaning notes files...
[WARN] Ending process.
```

**With Custom Logging:**

```bash
export LOG_LEVEL=INFO
export CLEAN=false
./bin/process/processPlanetNotes.sh --base
```

**Check Help:**

```bash
./bin/process/processPlanetNotes.sh --help
```

**Note:** After running `--base`, you must also run `updateCountries.sh --base` to load geographic boundaries.

#### updateCountries.sh

Updates country and maritime boundaries from Overpass API.

**Update Mode (Default):**

```bash
# Update boundaries and re-assign countries for affected notes
./bin/process/updateCountries.sh
```

**Expected Output:**

```
[INFO] Preparing environment.
[INFO] Process: Update mode.
[INFO] Checking for boundary changes...
[INFO] Downloading updated countries from Overpass...
[INFO] Processing 195 countries...
[INFO] Downloading updated maritimes from Overpass...
[INFO] Processing 150 maritime boundaries...
[INFO] Re-assigning countries for affected notes...
[INFO] Updated 1,234 notes with new country assignments
[INFO] Cleaning temporary files...
```

**Base Mode (Initial Setup):**

```bash
# Load all boundaries from scratch
./bin/process/updateCountries.sh --base
```

**Expected Output (Base Mode):**

```
[INFO] Preparing environment.
[INFO] Process: Base mode.
[INFO] Dropping country tables...
[INFO] Creating country tables...
[INFO] Downloading countries from Overpass...
[INFO] Processing 195 countries...
[INFO] Downloading maritimes from Overpass...
[INFO] Processing 150 maritime boundaries...
[INFO] Assigning countries to all notes...
[INFO] Assigned countries to 2,345,678 notes
[INFO] Cleaning temporary files...
```

**With Rate Limiting:**

```bash
# Increase delay between Overpass API requests (default: 2 seconds)
export RATE_LIMIT=5
./bin/process/updateCountries.sh
```

**Check Help:**

```bash
./bin/process/updateCountries.sh --help
```

### Monitoring Scripts

#### notesCheckVerifier.sh

Validates data integrity by comparing Planet vs API data.

**Basic Usage:**

```bash
./bin/monitor/notesCheckVerifier.sh
```

**Expected Output:**

```
[INFO] Starting notes check verifier...
[INFO] Comparing Planet vs API data...
[INFO] Checking note counts...
[INFO] Planet notes: 2,345,678
[INFO] API notes: 2,345,678
[INFO] Checking for discrepancies...
[INFO] No discrepancies found.
[INFO] Verification completed successfully.
```

**With Detailed Logging:**

```bash
export LOG_LEVEL=DEBUG
./bin/monitor/notesCheckVerifier.sh
```

**Automated Daily Verification:**

```bash
# Add to crontab for daily verification at 3 AM
0 3 * * * cd /path/to/OSM-Notes-Ingestion && ./bin/monitor/notesCheckVerifier.sh >> /var/log/osm-notes-verification.log 2>&1
```

**Check Specific Time Range:**

```bash
# Verify notes from last 24 hours
export VERIFY_LAST_HOURS=24
./bin/monitor/notesCheckVerifier.sh
```

**Exit Codes:**

- `0`: Verification successful, no discrepancies
- `1`: Help message displayed
- `241`: Library or utility missing
- `255`: General error or discrepancies found

#### analyzeDatabasePerformance.sh

Analyzes database performance and provides optimization recommendations.

**Basic Usage:**

```bash
./bin/monitor/analyzeDatabasePerformance.sh
```

**With Database Parameter:**

```bash
./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes
```

**Expected Output:**

```
[INFO] Analyzing database performance...
[INFO] Database: osm_notes
[INFO] Connection count: 5
[INFO] Table sizes:
[INFO]   notes: 1.2 GB
[INFO]   countries: 45 MB
[INFO] Index usage analysis...
[INFO] Query performance analysis...
[INFO] Recommendations:
[INFO]   - Consider VACUUM ANALYZE on notes table
[INFO]   - Index 'idx_notes_country' is underutilized
```

**Generate Performance Report:**

```bash
# Save output to file for analysis
./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes > performance_report.txt 2>&1

# Review recommendations
grep -i "recommendation\|warning\|error" performance_report.txt
```

**Weekly Performance Monitoring:**

```bash
# Add to crontab for weekly analysis (Sundays at 4 AM)
0 4 * * 0 cd /path/to/OSM-Notes-Ingestion && ./bin/monitor/analyzeDatabasePerformance.sh >> /var/log/osm-notes-performance.log 2>&1
```

**Exit Codes:**

- `0`: Analysis completed successfully
- `1`: Help message displayed
- `241`: Library or utility missing
- `242`: Invalid argument
- `255`: General error

### Maintenance Scripts

#### cleanupAll.sh

Removes database components. Use with caution!

**Full Cleanup (Default):**

```bash
# Removes ALL components (WMS, base tables, partitions, etc.)
./bin/cleanupAll.sh
# or explicitly
./bin/cleanupAll.sh --all
```

**Expected Output:**

```
[INFO] Starting cleanupAll.sh script
[INFO] Database: osm_notes
[WARN] This will remove ALL database components
[INFO] Removing WMS components...
[INFO] Removing base tables...
[INFO] Removing partition tables...
[INFO] Removing temporary tables...
[INFO] Cleanup completed successfully.
```

**Partitions Only:**

```bash
# Removes only partition tables (safer option)
./bin/cleanupAll.sh -p
# or
./bin/cleanupAll.sh --partitions-only
```

**Expected Output:**

```
[INFO] Starting cleanupAll.sh script
[INFO] Database: osm_notes
[INFO] Removing partition tables only...
[INFO] Cleanup completed successfully.
```

**With Custom Database:**

```bash
# Cleanup specific database
DBNAME=osm_notes_test ./bin/cleanupAll.sh
```

**Warning:** This script permanently removes data. Always backup before running!

### WMS Scripts

#### wmsManager.sh

Manages WMS database components (tables, triggers, functions).

**Install WMS Components:**

```bash
./bin/wms/wmsManager.sh install
```

**Expected Output:**

```
[INFO] Installing WMS components...
[INFO] Creating WMS schema...
[INFO] Creating WMS tables...
[INFO] Creating triggers...
[INFO] Creating functions...
[INFO] WMS components installed successfully.
```

**Verify Installation:**

```bash
# Check if WMS schema exists
psql -d osm_notes -c "\dn wms"

# List WMS tables
psql -d osm_notes -c "\dt wms.*"

# Check triggers
psql -d osm_notes -c "SELECT trigger_name, event_object_table FROM information_schema.triggers WHERE trigger_schema = 'wms';"
```

**Remove WMS Components:**

```bash
# Remove all WMS components (use with caution)
./bin/wms/wmsManager.sh remove
```

**Expected Output (Remove):**

```
[INFO] Removing WMS components...
[INFO] Dropping WMS schema...
[INFO] WMS components removed successfully.
```

**Reinstall After Schema Changes:**

```bash
# Remove and reinstall to apply updates
./bin/wms/wmsManager.sh remove
./bin/wms/wmsManager.sh install
```

**Exit Codes:**

- `0`: Operation completed successfully
- `1`: Help message displayed
- `241`: Library or utility missing
- `242`: Invalid argument
- `255`: General error
[INFO] WMS components installed successfully.
```

**Check Status:**

```bash
./bin/wms/wmsManager.sh status
```

**Expected Output:**

```
[INFO] Checking WMS components status...
[INFO] WMS schema: exists
[INFO] WMS tables: 3 tables found
[INFO] Triggers: 2 triggers active
[INFO] Functions: 1 function found
[INFO] WMS components are installed and active.
```

**Remove WMS Components:**

```bash
./bin/wms/wmsManager.sh remove
```

**Get Help:**

```bash
./bin/wms/wmsManager.sh help
```

#### geoserverConfig.sh

Configures GeoServer for WMS service.

**Install GeoServer Configuration:**

```bash
./bin/wms/geoserverConfig.sh install
```

**Expected Output:**

```
[INFO] Configuring GeoServer...
[INFO] Creating workspace: osm_notes
[INFO] Creating datastore: osm_notes_db
[INFO] Creating layers...
[INFO] Configuring styles...
[INFO] GeoServer configuration completed successfully.
```

**Check Status:**

```bash
./bin/wms/geoserverConfig.sh status
```

**Expected Output (Status):**

```
[INFO] Checking GeoServer configuration...
[INFO] Workspace: osm_notes (exists)
[INFO] Datastore: osm_notes_db (exists)
[INFO] Layers: 3 configured
[INFO] GeoServer is properly configured.
```

**Remove Configuration:**

```bash
./bin/wms/geoserverConfig.sh remove
```

**Expected Output (Remove):**

```
[INFO] Removing GeoServer configuration...
[INFO] Removing layers...
[INFO] Removing datastore...
[INFO] Removing workspace...
[INFO] GeoServer configuration removed successfully.
```

**Reconfigure After Changes:**

```bash
# Remove and reinstall to apply updates
./bin/wms/geoserverConfig.sh remove
./bin/wms/geoserverConfig.sh install
```

**Exit Codes:**

- `0`: Operation completed successfully
- `1`: Help message displayed
- `241`: Library or utility missing
- `242`: Invalid argument
- `255`: General error

### Generating Backups

#### Note Location Backup

To create or update the note location backup used for faster processing:

```bash
# Generate backup of note locations (note_id, id_country)
./bin/scripts/generateNoteLocationBackup.sh
```

This script:

- Connects to the database and verifies it has notes with country assignments
- Exports all note locations to a CSV file
- Compresses the CSV into a ZIP file
- Stores the result in `data/noteLocation.csv.zip`

The backup file is automatically imported during the location processing phase
to avoid re-calculating countries for notes that already have assignments.

#### Boundaries Backup (Countries and Maritimes)

To create or update boundaries backups used to avoid Overpass downloads:

**Export Country Boundaries:**

```bash
./bin/scripts/exportCountriesBackup.sh
```

**Expected Output:**

```
[INFO] Exporting country boundaries...
[INFO] Querying database for countries...
[INFO] Found 195 countries
[INFO] Exporting to GeoJSON...
[INFO] Writing to data/countries.geojson...
[INFO] Export completed: 195 countries exported
[INFO] File size: 45.2 MB
```

**Export Maritime Boundaries:**

```bash
./bin/scripts/exportMaritimesBackup.sh
```

**Expected Output:**

```
[INFO] Exporting maritime boundaries...
[INFO] Querying database for maritimes...
[INFO] Found 150 maritime boundaries
[INFO] Exporting to GeoJSON...
[INFO] Writing to data/maritimes.geojson...
[INFO] Export completed: 150 maritimes exported
[INFO] File size: 12.8 MB
```

**With Custom Database:**

```bash
DBNAME=osm_notes_test ./bin/scripts/exportCountriesBackup.sh
```

**These scripts:**

- Export boundaries from the database to GeoJSON format
- Store results in `data/countries.geojson` and `data/maritimes.geojson`
- Are automatically used by `processPlanet base` and `updateCountries`
- Compare IDs before downloading to avoid unnecessary Overpass API calls

See [Boundaries_Backup.md](../docs/Boundaries_Backup.md) for complete
documentation on boundaries backup functionality.

### Common Use Cases

#### Initial System Setup

Complete setup from scratch:

```bash
# 1. Load all historical notes from Planet (takes 1-2 hours)
./bin/process/processPlanetNotes.sh --base

# 2. Load country and maritime boundaries
./bin/process/updateCountries.sh --base

# 3. Generate backups for faster future processing
./bin/scripts/generateNoteLocationBackup.sh
./bin/scripts/exportCountriesBackup.sh
./bin/scripts/exportMaritimesBackup.sh

# 4. Install WMS components (optional, for map visualization)
./bin/wms/wmsManager.sh install

# Expected output: Creating WMS schema, configuring triggers
# Result: WMS tables and functions ready for GeoServer
```

#### Daily Operations

Normal production workflow:

```bash
# API processing runs automatically via cron (every 15 minutes)
# Manual execution if needed:
./bin/process/processAPINotes.sh

# Check processing status
psql -d osm_notes -c "
  SELECT 
    COUNT(*) as total_notes,
    COUNT(*) FILTER (WHERE status = 'open') as open_notes,
    MAX(created_at) as latest_note
  FROM notes;
"

# View latest processing log
tail -f $(ls -1rtd /tmp/processAPINotes_* | tail -1)/processAPINotes.log
```

#### Periodic Maintenance

Weekly or monthly maintenance tasks:

```bash
# Update country boundaries (if boundaries changed in OSM)
./bin/process/updateCountries.sh

# Expected: Downloads only changed boundaries, re-assigns affected notes
# Time: 5-15 minutes

# Sync with latest Planet dump (optional, for complete data)
./bin/process/processPlanetNotes.sh

# Expected: Processes only new notes since last sync
# Time: 30-60 minutes depending on new data volume

# Regenerate backups after significant updates
./bin/scripts/generateNoteLocationBackup.sh
./bin/scripts/exportCountriesBackup.sh
./bin/scripts/exportMaritimesBackup.sh
```

#### Performance Optimization

Adjust processing for your system:

```bash
# Reduce parallel threads if low on memory
export MAX_THREADS=2
./bin/process/processPlanetNotes.sh --base

# Skip validations for faster processing (production only)
export SKIP_XML_VALIDATION=true
export SKIP_CSV_VALIDATION=true
./bin/process/processAPINotes.sh

# Increase Overpass rate limit delay if getting rate limited
export RATE_LIMIT=5
./bin/process/updateCountries.sh
```

#### Data Export and Backup

Export data for analysis or backup:

```bash
# Export all note locations (for faster reprocessing)
./bin/scripts/generateNoteLocationBackup.sh

# Export country boundaries to GeoJSON
./bin/scripts/exportCountriesBackup.sh

# Export maritime boundaries to GeoJSON
./bin/scripts/exportMaritimesBackup.sh

# Verify exports
ls -lh data/*.zip data/*.geojson
```

#### Error Recovery

Recover from failed executions:

```bash
# Check if previous execution failed
ls -la /tmp/processAPINotes_failed_execution

# Review error details
cat /tmp/processAPINotes_failed_execution

# Check logs
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
grep -i error "$LATEST_DIR/processAPINotes.log" | tail -20

# Fix the underlying issue, then remove marker
rm /tmp/processAPINotes_failed_execution

# Re-run (or wait for next cron execution)
./bin/process/processAPINotes.sh
```

#### Testing and Development

Run scripts in test mode:

```bash
# Use test database
export DBNAME=osm_notes_test

# Enable debug logging
export LOG_LEVEL=DEBUG

# Keep temporary files
export CLEAN=false

# Run with validation enabled
export SKIP_XML_VALIDATION=false
export SKIP_CSV_VALIDATION=false

# Execute script
./bin/process/processAPINotes.sh

# Inspect results
psql -d osm_notes_test -c "SELECT COUNT(*) FROM notes;"
ls -lh /tmp/processAPINotes_*/
```

### Environment Variables

Common environment variables for all scripts:

**Logging Control:**

```bash
# Set log level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
export LOG_LEVEL=DEBUG

# Keep temporary files (default: true, files are deleted)
export CLEAN=false
```

**Database Configuration:**

```bash
# Override database name (default: from etc/properties.sh)
export DBNAME=osm_notes_test
```

**Processing Control:**

```bash
# Skip XML validation (default: true, validation skipped)
export SKIP_XML_VALIDATION=false

# Skip CSV validation (default: false, validation performed)
export SKIP_CSV_VALIDATION=true

# Maximum threads for parallel processing (default: CPU cores - 2)
export MAX_THREADS=4
```

**Network Configuration:**

```bash
# Rate limit for Overpass API (seconds between requests, default: 2)
export RATE_LIMIT=5
```

**Alert Configuration:**

```bash
# Email for alerts (default: root@localhost)
export ADMIN_EMAIL="admin@example.com"

# Enable/disable email alerts (default: true)
export SEND_ALERT_EMAIL=true
```

For complete environment variable documentation, see [ENVIRONMENT_VARIABLES.md](./ENVIRONMENT_VARIABLES.md).

## Dependencies

### Required

- PostgreSQL with PostGIS extension
- GNU AWK (gawk)
- GNU Parallel
- Bash 4+ scripting environment
- bzip2, curl, sed, grep
- ogr2ogr (GDAL tools for geographic data)

### Optional

- xmllint (only for strict XML validation when `SKIP_XML_VALIDATION=false`)
