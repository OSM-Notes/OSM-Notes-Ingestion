# OSM Notes Ingestion - System Documentation

## Overview

This document provides comprehensive technical documentation for the
OSM-Notes-Ingestion system, including system architecture, data flow, and
implementation details.

> **Note:** For project motivation and background, see [Rationale.md](./Rationale.md).

## Purpose

This repository focuses exclusively on **data ingestion** from OpenStreetMap:

- **Data Collection**: Extracting notes data from OSM API and Planet dumps
- **Data Processing**: Transforming and validating note data
- **Data Storage**: Loading processed data into PostgreSQL/PostGIS
- **WMS Service**: Providing geographic visualization of notes

> **Note:** Analytics, ETL, and Data Warehouse components are maintained in a
> separate repository: [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics)

---

## System Architecture

### Architecture Diagram

```text
┌─────────────────────────────────────────────────────────────────────┐
│                        OSM-Notes-Ingestion System                    │
└─────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
┌───────────────┐          ┌───────────────┐          ┌───────────────┐
│  OSM Notes    │          │  OSM Planet   │          │   Overpass    │
│     API       │          │     Dumps     │          │     API       │
│  (Real-time)  │          │  (Historical) │          │ (Boundaries)  │
└───────┬───────┘          └───────┬───────┘          └───────┬───────┘
        │                          │                          │
        │                          │                          │
        └──────────┬───────────────┴──────────┬───────────────┘
                   │                          │
                   ▼                          ▼
        ┌────────────────────┐    ┌────────────────────┐
        │  Data Collection   │    │  Boundary Download │
        │      Layer         │    │   (FIFO Queue)    │
        └──────────┬─────────┘    └──────────┬─────────┘
                   │                         │
                   └────────────┬────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │  Data Processing      │
                    │      Layer           │
                    │  ┌─────────────────┐ │
                    │  │ XML → CSV (AWK) │ │
                    │  │  Validation     │ │
                    │  │  Parallel Proc  │ │
                    │  └─────────────────┘ │
                    └───────────┬───────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   Data Storage        │
                    │      Layer            │
                    │  ┌─────────────────┐ │
                    │  │  PostgreSQL     │ │
                    │  │  + PostGIS      │ │
                    │  │  - notes        │ │
                    │  │  - comments    │ │
                    │  │  - countries    │ │
                    │  └─────────────────┘ │
                    └───────────┬───────────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
                ▼                               ▼
    ┌───────────────────┐          ┌───────────────────┐
    │   WMS Layer       │          │  Analytics (DWH)  │
    │  (GeoServer)      │          │  (External Repo)  │
    │  - Map Tiles      │          │  - Star Schema    │
    │  - Styles         │          │  - Data Marts     │
    └───────────────────┘          └───────────────────┘
```

### Core Components

The OSM-Notes-Ingestion system consists of the following components:

#### 1. Data Collection Layer

- **API Integration**: Real-time data from OSM Notes API
  - Incremental updates every 15 minutes
  - Limited to last 10,000 closed notes and all open notes
  - Automatic detection of new, modified, and reopened notes

- **Planet Processing**: Historical data from OSM Planet dumps
  - Complete note history since 2013
  - Daily planet dumps processing
  - Full database initialization and updates

- **Geographic Boundaries**: Country and maritime boundaries via Overpass
  - Country polygons for spatial analysis
  - Maritime boundaries
  - Automatic updates

#### 2. Data Processing Layer

- **XML Transformation**: AWK-based extraction from XML to CSV
  - Optimized AWK scripts for API and Planet formats
  - Fast and memory-efficient processing
  - No external XML dependencies
  - Parallel processing support

- **Data Validation**: Comprehensive validation functions
  - XML structure validation (optional)
  - Date and coordinate validation
  - Data integrity checks
  - Schema validation (optional)

- **Parallel Processing**: Partitioned data processing for large volumes
  - Automatic file splitting
  - Parallel AWK extraction
  - Resource management and optimization

#### 3. Data Storage Layer

- **PostgreSQL Database**: Primary data storage
  - Core tables for notes and comments
  - Spatial indexes for geographic queries
  - Temporal indexes for time-based queries

- **PostGIS Extension**: Spatial data handling
  - Geographic coordinates storage
  - Spatial queries and analysis
  - Country assignment for notes

#### 4. WMS (Web Map Service) Layer

- **Geographic Visualization**: Map-based note display
- **Real-time Updates**: Synchronized with main database
- **Style Management**: Different styles for open/closed notes
- **Client Integration**: JOSM, Vespucci, and web applications

---

## Data Flow

### Data Flow Diagram

```text
┌─────────────────────────────────────────────────────────────────────┐
│                         Data Flow Overview                           │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────┐
│ Overpass API │
│ (Boundaries) │
└──────┬───────┘
       │
       │ Download (FIFO Queue)
       │
       ▼
┌──────────────┐     ┌──────────────┐
│   Countries  │────▶│   PostGIS    │
│   Table      │     │  Geometry    │
└──────────────┘     └──────────────┘

┌──────────────┐
│ OSM Planet  │
│   Dumps     │
└──────┬───────┘
       │
       │ Download
       │
       ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  XML File    │────▶│  AWK Extract │────▶│  CSV Files   │
│  (2.2GB+)    │     │  (Parallel)  │     │  (Partitioned)│
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │
                                                  │ Load
                                                  ▼
                                         ┌──────────────┐
                                         │ Sync Tables  │
                                         │ (Temporary)  │
                                         └──────┬───────┘
                                                │
                                                │ Merge
                                                ▼
                                         ┌──────────────┐
                                         │  Base Tables │
                                         │  (notes,     │
                                         │   comments)  │
                                         └──────┬───────┘
                                                │
                                                │ Country
                                                │ Assignment
                                                ▼
                                         ┌──────────────┐
                                         │  Notes with  │
                                         │  Countries   │
                                         └──────┬───────┘
                                                │
                    ┌──────────────────────────┴──────────────────────────┐
                    │                                                       │
                    ▼                                                       ▼
         ┌──────────────────┐                                  ┌──────────────────┐
         │   WMS Tables     │                                  │  Analytics DWH   │
         │  (via Triggers)  │                                  │  (External Repo) │
         └──────────┬───────┘                                  └───────────────────┘
                    │
                    ▼
         ┌──────────────────┐
         │    GeoServer     │
         │   (WMS Service)  │
         └──────────┬───────┘
                    │
                    ▼
         ┌──────────────────┐
         │  Map Clients     │
         │ (JOSM, Vespucci)  │
         └──────────────────┘

┌──────────────┐
│  OSM Notes   │
│     API      │
└──────┬───────┘
       │
       │ Every 15 min
       │
       ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  XML (API)   │────▶│  AWK Extract │────▶│  API Tables  │
│  (<10K notes)│     │  (Parallel)  │     │ (Temporary)  │
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │
                                                  │ Update
                                                  ▼
                                         ┌──────────────┐
                                         │  Base Tables │
                                         │  (Incremental│
                                         │   Updates)   │
                                         └──────────────┘
```

### 1. Geographic Data Collection

**Source:** Overpass API queries for country and maritime boundaries

**Process:**

1. Download boundary relations with specific tags
   - FIFO queue system ensures orderly downloads
   - Smart waiting respects Overpass API rate limits
   - Prevents race conditions in parallel processing
   - Thread-safe ticket-based queue management
2. Transform to PostGIS geometry objects
3. Store in `countries` table

**Output:** PostgreSQL geometry objects for spatial queries

### 2. Historical Data Processing (Planet)

**Source:** OSM Planet daily dumps (notes since 2013)

**Process:**

1. Download Planet notes dump
2. Transform XML to CSV using AWK extraction
3. Validate data structure and content (optional)
4. Load into temporary sync tables
5. Merge with main tables

**Output:** Base database with complete note history

**Frequency:** Daily or on-demand

### 3. Incremental Data Synchronization (API)

**Source:** OSM Notes API (recent changes)

**Process:**

1. Query API for updates (last 10,000 closed + all open)
2. Transform XML to CSV
3. Validate and detect changes
4. Load into temporary API tables
5. Update main tables with new/modified notes

**Output:** Updated database with latest changes

**Frequency:** Every 15 minutes (configurable)

### 4. Country Assignment

**Process:**

1. For each new/modified note
2. Perform spatial query against country boundaries
3. Assign country based on geographic location
4. Update note record with country information

**Output:** Notes with assigned countries

### Processing Sequence Diagram

```text
┌─────────────────────────────────────────────────────────────────────┐
│                    Processing Sequence Overview                      │
└─────────────────────────────────────────────────────────────────────┘

API Processing Flow (Every 15 minutes):
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Cron    │───▶│processAPI│───▶│  OSM API │───▶│   AWK    │───▶│PostgreSQL│
│  Scheduler│    │  Script  │    │  (XML)   │    │ Extract  │    │  (API    │
└──────────┘    └────┬─────┘    └──────────┘    └────┬─────┘    │  Tables) │
                     │                               │           └────┬──────┘
                     │                               │                │
                     │                               │                │
                     │                               ▼                │
                     │                      ┌──────────────┐          │
                     │                      │   Parallel   │          │
                     │                      │  Processing  │          │
                     │                      │  (Partitions)│          │
                     │                      └──────────────┘          │
                     │                                                │
                     │                                                ▼
                     │                                      ┌──────────────┐
                     │                                      │  Base Tables │
                     └──────────────────────────────────────▶│  (Updated)  │
                                                             └──────────────┘

Planet Processing Flow (Daily/On-demand):
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Manual  │───▶│processPlan│───▶│  Planet  │───▶│   AWK    │───▶│PostgreSQL│
│  Trigger │    │  etNotes  │    │  Dump    │    │ Extract  │    │  (Sync   │
└──────────┘    └────┬─────┘    └──────────┘    └────┬─────┘    │  Tables) │
                     │                               │           └────┬──────┘
                     │                               │                │
                     │                               ▼                │
                     │                      ┌──────────────┐          │
                     │                      │   Split XML  │          │
                     │                      │   (Parallel)  │          │
                     │                      └──────┬───────┘          │
                     │                               │                 │
                     │                               ▼                 │
                     │                      ┌──────────────┐          │
                     │                      │   Process    │          │
                     │                      │   Parts      │          │
                     │                      │  (Parallel)  │          │
                     │                      └──────┬───────┘          │
                     │                               │                 │
                     │                               ▼                 │
                     │                      ┌──────────────┐          │
                     │                      │  Consolidate │          │
                     │                      │  Partitions  │          │
                     │                      └──────┬───────┘          │
                     │                               │                 │
                     │                               ▼                 │
                     │                                      ┌──────────────┐
                     └──────────────────────────────────────▶│  Base Tables │
                                                             │  (Merged)   │
                                                             └──────────────┘

Country Assignment Flow:
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Notes   │───▶│  Spatial │───▶│ PostGIS  │───▶│  Notes   │
│  (New)   │    │  Query   │    │  (ST_    │    │ (Updated │
│          │    │          │    │ Contains)│    │  w/      │
└──────────┘    └────┬─────┘    └────┬─────┘    │ Country) │
                     │                │         └──────────┘
                     │                │
                     ▼                ▼
              ┌──────────────┐  ┌──────────────┐
              │  Countries   │  │  Parallel    │
              │   Table     │  │  Processing  │
              │  (PostGIS)  │  │  (Chunks)    │
              └──────────────┘  └──────────────┘
```

### 5. WMS Service Delivery

**Source:** WMS schema in database

**Process:**

1. Synchronize WMS tables with main tables via triggers
2. Apply spatial and temporal indexes
3. GeoServer renders with configured styles

**Output:** Map tiles and feature information via WMS protocol

---

## Usage Examples

This section provides real, verified code examples based on the actual implementation. All examples reflect the current codebase behavior.

### Basic Script Execution

#### Processing API Notes (Incremental Sync)

The `processAPINotes.sh` script does not accept command-line arguments (except `--help`). Configuration is done via environment variables:

```bash
# Basic execution (production mode)
./bin/process/processAPINotes.sh

# With debug logging
export LOG_LEVEL=DEBUG
./bin/process/processAPINotes.sh

# Enable XML validation (default is to skip for speed)
export SKIP_XML_VALIDATION=false
export SKIP_CSV_VALIDATION=false
./bin/process/processAPINotes.sh

# Keep temporary files for debugging
export CLEAN=false
export LOG_LEVEL=DEBUG
./bin/process/processAPINotes.sh

# Enable bash debug mode (shows all commands)
export BASH_DEBUG=true
export LOG_LEVEL=TRACE
./bin/process/processAPINotes.sh
```

**Note:** The script creates a temporary directory at `/tmp/processAPINotes_XXXXXX` where `XXXXXX` is a random string. Logs are written to `${TMP_DIR}/processAPINotes.log`.

**Following progress:**

```bash
# Find the latest log file
tail -40f $(ls -1rtd /tmp/processAPINotes_* | tail -1)/processAPINotes.log
```

#### Processing Planet Notes (Historical Data)

The `processPlanetNotes.sh` script accepts a `--base` parameter for full initialization:

```bash
# Sync mode (incremental update from Planet)
./bin/process/processPlanetNotes.sh

# Base mode (full initialization, drops and recreates tables)
./bin/process/processPlanetNotes.sh --base

# With validation enabled
export SKIP_XML_VALIDATION=false
export LOG_LEVEL=INFO
./bin/process/processPlanetNotes.sh --base

# Debug mode with file preservation
export LOG_LEVEL=DEBUG
export CLEAN=false
./bin/process/processPlanetNotes.sh --base
```

#### Updating Country Boundaries

The `updateCountries.sh` script updates geographic boundaries:

```bash
# Update mode (normal operation)
./bin/process/updateCountries.sh

# Base mode (recreate country tables)
./bin/process/updateCountries.sh --base

# With debug logging
export LOG_LEVEL=DEBUG
./bin/process/updateCountries.sh
```

### Environment Variables

All scripts support common environment variables. See [bin/ENVIRONMENT_VARIABLES.md](../bin/ENVIRONMENT_VARIABLES.md) for complete documentation.

#### Common Variables

```bash
# Logging level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
export LOG_LEVEL=DEBUG

# Cleanup temporary files (true/false, default: true)
export CLEAN=true

# Skip XML validation (true/false, default: true - skips validation)
export SKIP_XML_VALIDATION=false  # Set to false to enable validation

# Skip CSV validation (true/false, default: true - skips validation)
export SKIP_CSV_VALIDATION=false  # Set to false to enable validation

# Database name override
export DBNAME=osm_notes_test

# Bash debug mode (shows all commands)
export BASH_DEBUG=true
```

#### processAPINotes.sh Specific Variables

```bash
# Email alerts configuration
export ADMIN_EMAIL="admin@example.com"
export SEND_ALERT_EMAIL=true

# Complete example with all options
export LOG_LEVEL=DEBUG
export CLEAN=false
export SKIP_XML_VALIDATION=false
export ADMIN_EMAIL="admin@example.com"
export SEND_ALERT_EMAIL=true
./bin/process/processAPINotes.sh
```

### Error Handling and Recovery

#### Failed Execution Marker

When critical errors occur, the script creates a failed execution marker file:

```bash
# Check if previous execution failed
ls -la /tmp/processAPINotes_failed_execution

# Recover from failed execution
# 1. Check email for alert details
# 2. Fix the underlying issue (database, network, etc.)
# 3. Remove the marker file
rm /tmp/processAPINotes_failed_execution

# 4. Wait for next cron execution (recommended)
# The script is designed to run automatically via crontab.
# After removing the marker, wait for the next scheduled execution
# (e.g., every 15 minutes for processAPINotes.sh)

# Note: Manual execution is only for testing/debugging.
# In production, let the cron job handle the next execution.
```

#### Lock File Management

Scripts use lock files to prevent concurrent execution:

```bash
# Check if script is running
ls -la /tmp/processAPINotes.lock

# View lock file contents (shows PID and start time)
cat /tmp/processAPINotes.lock

# Remove stale lock (only if process is not running!)
# First verify: ps aux | grep processAPINotes.sh
rm /tmp/processAPINotes.lock
```

### Monitoring and Logging

#### Viewing Logs

```bash
# Find latest log directory
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
echo "Log directory: $LATEST_DIR"

# View log file
tail -f "$LATEST_DIR/processAPINotes.log"

# Search for errors
grep -i error "$LATEST_DIR/processAPINotes.log"

# Search for warnings
grep -i warn "$LATEST_DIR/processAPINotes.log"
```

#### Database Monitoring

```bash
# Check PostgreSQL application name (shows which script is using DB)
psql -d osm_notes -c "SELECT application_name, state, query_start FROM pg_stat_activity WHERE application_name LIKE 'process%';"

# Monitor active connections
psql -d osm_notes -c "SELECT count(*) FROM pg_stat_activity WHERE datname = 'osm_notes';"
```

### Cron Job Configuration

Example crontab entries for automated execution:

```bash
# Process API notes every 15 minutes
*/15 * * * * cd /path/to/OSM-Notes-Ingestion && ./bin/process/processAPINotes.sh >> /var/log/osm-notes-api.log 2>&1

# Update countries daily at 2 AM
0 2 * * * cd /path/to/OSM-Notes-Ingestion && ./bin/process/updateCountries.sh >> /var/log/osm-notes-countries.log 2>&1

# Verify data integrity daily at 3 AM
0 3 * * * cd /path/to/OSM-Notes-Ingestion && ./bin/monitor/notesCheckVerifier.sh >> /var/log/osm-notes-verify.log 2>&1
```

### Testing and Development

#### Development Mode

```bash
# Use test database
export DBNAME=osm_notes_test

# Enable all logging
export LOG_LEVEL=TRACE

# Keep files for inspection
export CLEAN=false

# Enable strict validation
export SKIP_XML_VALIDATION=false
export SKIP_CSV_VALIDATION=false

# Run script
./bin/process/processAPINotes.sh
```

#### Production Mode

```bash
# Use production database (default)
# DBNAME comes from etc/properties.sh

# Minimal logging
export LOG_LEVEL=ERROR

# Clean up files (default: true)
export CLEAN=true

# Skip validation for speed (defaults already skip both XML and CSV validation)
# SKIP_XML_VALIDATION=true is the default, no need to export
# SKIP_CSV_VALIDATION=true is the default, no need to export
# Both validations are skipped by default for faster processing

# Enable alerts
export SEND_ALERT_EMAIL=true
export ADMIN_EMAIL="admin@production.com"

# Run script
./bin/process/processAPINotes.sh
```

### Help and Documentation

All scripts support `--help` or `-h`:

```bash
# Get help for any script
./bin/process/processAPINotes.sh --help
./bin/process/processPlanetNotes.sh --help
./bin/process/updateCountries.sh --help
```

### Related Documentation

For more detailed examples and use cases, see:

- **[bin/ENTRY_POINTS.md](../bin/ENTRY_POINTS.md)**: Allowed entry points and usage
- **[bin/ENVIRONMENT_VARIABLES.md](../bin/ENVIRONMENT_VARIABLES.md)**: Complete environment variable reference
- **[processAPI.md](./processAPI.md)**: Detailed API processing documentation
- **[processPlanet.md](./processPlanet.md)**: Detailed Planet processing documentation

---

## Database Schema

### Database Schema Diagram

```text
┌─────────────────────────────────────────────────────────────────────┐
│                      Database Schema Overview                        │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                         Core Tables (Permanent)                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐         ┌──────────────┐         ┌─────────────┐│
│  │    notes     │────────▶│note_comments │────────▶│note_comments││
│  │              │ 1:N     │              │ 1:1     │    _text    ││
│  │ - note_id    │         │ - note_id    │         │ - note_id   ││
│  │ - lat/lon    │         │ - sequence   │         │ - sequence  ││
│  │ - status     │         │ - event      │         │ - body      ││
│  │ - country_id │         │ - user_id    │         └─────────────┘│
│  └──────┬───────┘         └──────────────┘                         │
│         │                                                           │
│         │ Spatial Query                                             │
│         │                                                           │
│         ▼                                                           │
│  ┌──────────────┐                                                   │
│  │   countries  │                                                   │
│  │              │                                                   │
│  │ - country_id │                                                   │
│  │ - geom       │                                                   │
│  │ (PostGIS)    │                                                   │
│  └──────────────┘                                                   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                    Processing Tables (Temporary)                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  API Processing:              Planet Processing:                    │
│  ┌──────────────┐              ┌──────────────┐                    │
│  │ notes_api    │              │ notes_sync   │                    │
│  │ (partitioned)│              │ (partitioned) │                    │
│  └──────────────┘              └──────────────┘                    │
│  ┌──────────────┐              ┌──────────────┐                    │
│  │comments_api  │              │comments_sync │                    │
│  └──────────────┘              └──────────────┘                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                         WMS Tables (wms schema)                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐                                                  │
│  │ notes_wms    │  ← Synchronized via triggers from notes          │
│  │              │                                                   │
│  │ - Simplified │                                                   │
│  │ - Optimized  │                                                   │
│  │ - Indexed    │                                                   │
│  └──────────────┘                                                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Core Tables

- **`notes`**: All OSM notes with geographic and temporal data
  - Columns: note_id, latitude, longitude, created_at, closed_at, status
  - Indexes: spatial (lat/lon), temporal (dates), status
  - Approximately 4.3M notes (as of 2024)

- **`note_comments`**: Comment metadata and user information
  - Columns: note_id, sequence_action, action, action_date, user_id, username
  - Indexes: note_id, user_id, action_date
  - One record per comment/action

- **`note_comments_text`**: Actual comment content
  - Columns: note_id, sequence_action, text
  - Linked to note_comments via foreign key
  - Separated for performance (text can be large)

- **`countries`**: Geographic boundaries for spatial analysis
  - PostGIS geometry objects
  - Country names and ISO codes
  - Used for spatial queries and note assignment

### Processing Tables (Temporary)

- **API Tables**: Temporary storage for API data
  - `notes_api`, `note_comments_api`, `note_comments_text_api`
  - Cleared after each sync

- **Sync Tables**: Temporary storage for Planet processing
  - `notes_sync`, `note_comments_sync`, `note_comments_text_sync`
  - Used for bulk loading and validation

### WMS Tables

- **`wms.notes_wms`**: Optimized note data for map visualization
  - Simplified geometry and attributes
  - Automatic synchronization via triggers
  - Spatial and temporal indexes for performance

### Monitoring Tables

- **Check Tables**: Used for monitoring and verification
  - Compare API vs Planet data
  - Detect discrepancies
  - Validate data integrity

---

## Technical Implementation

### Processing Scripts

#### Core Processing

- **`bin/process/processAPINotes.sh`**: Incremental synchronization from OSM API
  - Configurable update frequency
  - Automatic error handling and retry
  - Logging and monitoring

- **`bin/process/processPlanetNotes.sh`**: Historical data processing from Planet dumps
  - Large file handling
  - Parallel processing
  - Checksum validation

- **`bin/process/updateCountries.sh`**: Geographic boundary updates
  - Overpass API integration
  - Boundary validation
  - Country table updates

#### Support Functions

- **`bin/lib/functionsProcess.sh`**: Shared processing functions
  - Database operations
  - Validation functions
  - Common utilities

- **`bin/lib/parallelProcessingFunctions.sh`**: Parallel processing utilities
  - File splitting
  - Parallel execution
  - Resource management

#### Monitoring

- **`bin/monitor/notesCheckVerifier.sh`**: Verification and monitoring
  - Data consistency checks
  - Discrepancy detection
  - Alert generation

- **`bin/monitor/processCheckPlanetNotes.sh`**: Planet data verification
  - Compare API vs Planet
  - Validate note counts
  - Generate reports

#### Cleanup

- **`bin/cleanupAll.sh`**: Cleanup and maintenance
  - Remove temporary tables
  - Clear processing data
  - Database cleanup

### WMS Scripts

- **`bin/wms/wmsManager.sh`**: WMS database component management
  - Create/drop WMS schema
  - Configure triggers and functions
  - Manage indexes

- **`bin/wms/geoserverConfig.sh`**: GeoServer configuration automation
  - Layer configuration
  - Style management
  - Service setup

### Data Transformation

- **AWK Extraction Scripts** (`awk/`):
  - `extract_notes.awk`: Extract notes from XML to CSV
  - `extract_comments.awk`: Extract comment metadata to CSV
  - `extract_comment_texts.awk`: Extract comment text with HTML entity handling
  - Fast, memory-efficient, no external dependencies

- **Validation** (optional):
  - XML schema validation (`xsd/`) - only if SKIP_XML_VALIDATION=false
  - Data integrity checks
  - Coordinate validation
  - Date format validation

### Performance Optimization

- **Parallel Processing**:
  - File splitting for large XML files
  - Concurrent AWK extraction (10x faster than XSLT)
  - Parallel database loading

- **Indexing**:
  - Spatial indexes (PostGIS)
  - Temporal indexes (dates)
  - Composite indexes for common queries

- **Caching**:
  - WMS tables for fast map rendering
  - Materialized views (when needed)

---

## Integration Points

### External APIs

- **OSM Notes API** (`https://api.openstreetmap.org/api/0.6/notes`)
  - Real-time note data
  - RESTful API
  - XML format

- **Overpass API** (`https://overpass-api.de/api/interpreter`)
  - Geographic boundary data
  - Custom queries via Overpass QL
  - OSM data extraction

- **Planet Dumps** (`https://planet.openstreetmap.org/planet/notes/`)
  - Historical data archives
  - Daily updates
  - Complete note history

### WMS Service

- **GeoServer**: WMS service provider
  - Version 2.20+ recommended
  - PostGIS data store
  - SLD styles

- **PostGIS**: Spatial data storage and processing
  - Version 3.0+ recommended
  - Spatial indexes
  - Geographic queries

- **OGC Standards**: WMS 1.3.0 compliance
  - GetCapabilities
  - GetMap
  - GetFeatureInfo

### Data Formats

- **Input**: XML (from OSM API and Planet dumps)
- **Intermediate**: CSV (for database loading)
- **Storage**: PostgreSQL with PostGIS
- **Output**: WMS tiles, GeoJSON

---

## Monitoring and Maintenance

### System Health

- **Database Monitoring**:
  - Connection pool status
  - Query performance
  - Index usage

- **Processing Monitoring**:
  - Script execution status
  - Error logs
  - Processing times

- **Data Quality**:
  - Validation checks
  - Integrity constraints
  - Discrepancy detection

### Maintenance Tasks

- **Regular Synchronization**: 15-minute API updates
- **Daily Planet Processing**: Historical data updates (optional)
- **Weekly Boundary Updates**: Geographic data refresh
- **Monthly Cleanup**: Remove old temporary data

---

## Usage Guidelines

### For System Administrators

- Monitor system health and performance
- Manage database maintenance and backups
- Configure processing schedules and timeouts
- Set up cron jobs for automatic processing

### For Developers

- Understand data flow and transformation processes
- Modify processing scripts and validation procedures
- Extend ingestion capabilities
- Add new data sources or formats

### For End Users

- Use WMS layers in mapping applications (JOSM, Vespucci)
- Visualize note patterns geographically
- Explore user and country profiles interactively via [OSM-Notes-Viewer](https://github.com/OSMLatam/OSM-Notes-Viewer)
- Query database for custom analysis
- Export data in various formats

---

## Dependencies

### Software Requirements

#### Required

- **PostgreSQL** (13+): Database server
- **PostGIS** (3.0+): Spatial extension
- **Bash** (4.0+): Scripting environment
- **GNU AWK (gawk)**: AWK extraction scripts
- **GNU Parallel**: Parallel processing
- **curl/wget**: Data download
- **ogr2ogr** (GDAL): Geographic data import
- **GeoServer** (2.20+): WMS service provider (optional)
- **Java** (11+): Runtime for GeoServer (optional)

#### Optional

- **xmllint**: XML validation (only if SKIP_XML_VALIDATION=false)

### Data Dependencies

- **OSM Notes API**: Real-time note data
- **Planet Dumps**: Historical data archives
- **Overpass API**: Geographic boundaries

---

## Related Documentation

### Core Documentation

- **[README.md](../README.md)**: Project overview and quick start
- **[Rationale.md](./Rationale.md)**: Project motivation and goals
- **[CONTRIBUTING.md](../CONTRIBUTING.md)**: Contribution guidelines

### Processing Documentation

- **[processAPI.md](./processAPI.md)**: API processing details
- **[processPlanet.md](./processPlanet.md)**: Planet processing details
- **[Input_Validation.md](./Input_Validation.md)**: Validation procedures
- **[XML_Validation_Improvements.md](./XML_Validation_Improvements.md)**: XML
  validation enhancements (optional)

### Testing Documentation

- **[Testing_Guide.md](./Testing_Guide.md)**: Testing guidelines
- **[Test_Matrix.md](./Test_Matrix.md)**: Test coverage matrix
- **[Test_Execution_Guide.md](./Test_Execution_Guide.md)**: Test execution guide and sequence
- **[Testing_Suites_Reference.md](./Testing_Suites_Reference.md)**: Test
  suites reference
- **[Testing_Workflows_Overview.md](./Testing_Workflows_Overview.md)**: Testing
  workflows

### WMS Documentation

- **[WMS_Guide.md](./WMS_Guide.md)**: Complete WMS guide for administrators and developers
- **[WMS_User_Guide.md](./WMS_User_Guide.md)**: WMS user guide for mappers

### CI/CD Documentation

- **[CI_CD_Integration.md](./CI_CD_Integration.md)**: CI/CD setup
- **[CI_Troubleshooting.md](./CI_Troubleshooting.md)**: CI/CD troubleshooting

### Other Technical Guides

- **[Cleanup_Integration.md](./Cleanup_Integration.md)**: Cleanup procedures
- **[Logging_Pattern_Validation.md](./Logging_Pattern_Validation.md)**: Logging
  standards

---

## External Resources

### Analytics and Data Warehouse

For analytics, ETL, and data warehouse functionality, see:

- **[OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics)**
  - Star schema design
  - ETL processes
  - Data marts (users, countries)
  - Profile generation
  - Advanced analytics

### Web Visualization

For interactive web visualization and exploration of user and country profiles:

- **[OSM-Notes-Viewer](https://github.com/OSMLatam/OSM-Notes-Viewer)**
  - Interactive web interface
  - User and country profile visualization
  - Statistics and analytics exploration
  - Hashtag tracking and analysis
  - Geographic distribution visualization
