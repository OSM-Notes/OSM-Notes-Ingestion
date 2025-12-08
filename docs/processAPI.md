# Complete Description of processAPINotes.sh

> **Note:** For a general system overview, see [Documentation.md](./Documentation.md).
> For project motivation and background, see [Rationale.md](./Rationale.md).

## General Purpose

The `processAPINotes.sh` script is the incremental synchronization component of the
OpenStreetMap notes processing system. Its main function is to download the most
recent notes from the OSM API and synchronize them with the local database that
maintains the complete history.

## Main Features

- **Incremental Processing**: Only downloads and processes new or modified notes
- **Intelligent Synchronization**: Automatically determines when to perform complete synchronization from Planet
- **Parallel Processing**: Uses partitioning to efficiently process large volumes
- **Planet Integration**: Integrates with `processPlanetNotes.sh` when necessary

## Design Context

### Why This Design?

The API processing design was created to handle incremental updates efficiently while maintaining data consistency with the complete Planet dataset. The key design decisions include:

**Separation of Concerns**:

- `processAPINotes.sh` and `processPlanetNotes.sh` are kept as independent scripts, even though they perform similar operations
- This separation allows each script to be optimized for its specific use case (incremental vs. bulk processing)
- Over time, shared library scripts were created to avoid code duplication while maintaining script independence

**Intelligent Synchronization Threshold**:

- When API returns >= 10,000 notes, the system automatically triggers Planet synchronization
- This prevents processing large API datasets inefficiently
- Leverages the proven Planet processing pipeline for better reliability

**Parallel Processing with Partitions**:

- Uses database partitions equal to `MAX_THREADS` (CPU cores - 2)
- Each thread processes its own partition, avoiding lock contention
- Divides work into more parts than threads for better load balancing (see [Rationale.md](./Rationale.md) for details)

### Design Patterns Used

- **Singleton Pattern**: Ensures only one instance of `processAPINotes.sh` runs at a time, critical for cron jobs running every 15 minutes
- **Retry Pattern**: Implements exponential backoff for API calls and network operations
- **Circuit Breaker Pattern**: Prevents cascading failures when API is unavailable
- **Resource Management Pattern**: Uses `trap` handlers for cleanup of temporary files and resources

### Alternatives Considered

- **Single Script Approach**: Considered combining API and Planet processing into one script, but rejected to maintain separation of concerns and allow independent optimization
- **Different Partitioning Strategy**: Evaluated fixed partitions vs. dynamic partitions based on data volume; chose dynamic for better resource utilization
- **Synchronous Processing**: Considered sequential processing but chose parallel for performance with large datasets

### Trade-offs

- **Complexity vs. Performance**: Parallel processing adds complexity but significantly improves performance for large datasets
- **Validation Speed**: Optional validations can be skipped (`SKIP_XML_VALIDATION`, `SKIP_CSV_VALIDATION`) for faster processing in production
- **Error Recovery**: Comprehensive error handling adds overhead but ensures system reliability and easier debugging

## Input Arguments

The script **does NOT accept arguments** for normal execution. It only accepts:

```bash
./processAPINotes.sh --help
# or
./processAPINotes.sh -h
```

**Why doesn't it accept arguments?**

- It is designed to run automatically (cron job)
- The decision logic is internal based on database state
- Configuration is done through environment variables

## Usage Examples

All examples below are verified against the actual codebase implementation.

### Basic Execution

```bash
# Standard execution (production mode)
cd /path/to/OSM-Notes-Ingestion
./bin/process/processAPINotes.sh
```

The script automatically:

- Creates a temporary directory at `/tmp/processAPINotes_XXXXXX`
- Downloads notes from OSM API
- Processes and synchronizes with the database
- Cleans up temporary files (if `CLEAN=true`)

### Environment Variable Configuration

#### Debug Mode

```bash
# Enable detailed logging
export LOG_LEVEL=DEBUG
./bin/process/processAPINotes.sh

# Enable trace-level logging (most verbose)
export LOG_LEVEL=TRACE
./bin/process/processAPINotes.sh
```

#### Validation Control

```bash
# Default behavior: Both XML and CSV validations are skipped by default (FASTER)
# SKIP_XML_VALIDATION=true by default
# SKIP_CSV_VALIDATION=true by default
# No need to export these for default behavior
./bin/process/processAPINotes.sh

# Enable strict validation (slower but more thorough)
export SKIP_XML_VALIDATION=false
export SKIP_CSV_VALIDATION=false
./bin/process/processAPINotes.sh
```

#### File Cleanup Control

```bash
# Keep temporary files for debugging
export CLEAN=false
export LOG_LEVEL=DEBUG
./bin/process/processAPINotes.sh

# Files will be preserved in /tmp/processAPINotes_XXXXXX/
# Useful for inspecting CSV files, logs, and intermediate data
```

#### Email Alerts

```bash
# Configure email alerts for failures
export ADMIN_EMAIL="admin@example.com"
export SEND_ALERT_EMAIL=true
export LOG_LEVEL=WARN
./bin/process/processAPINotes.sh

# Disable email alerts
export SEND_ALERT_EMAIL=false
./bin/process/processAPINotes.sh
```

#### Bash Debug Mode

```bash
# Enable bash debug mode (shows all commands executed)
export BASH_DEBUG=true
export LOG_LEVEL=TRACE
./bin/process/processAPINotes.sh
```

### Monitoring Execution

#### View Logs in Real-Time

```bash
# Find the latest log directory
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)

# Follow log output
tail -f "$LATEST_DIR/processAPINotes.log"

# Or use the one-liner from script header
tail -40f $(ls -1rtd /tmp/processAPINotes_* | tail -1)/processAPINotes.log
```

#### Check Execution Status

```bash
# Check if script is running
ps aux | grep processAPINotes.sh

# Check lock file (contains PID and start time)
cat /tmp/processAPINotes.lock

# Check for failed execution marker
ls -la /tmp/processAPINotes_failed_execution
```

### Error Recovery

#### Recovering from Failed Execution

When a critical error occurs, the script creates a failed execution marker:

```bash
# 1. Check if previous execution failed
if [ -f /tmp/processAPINotes_failed_execution ]; then
    echo "Previous execution failed. Check email for details."
    cat /tmp/processAPINotes_failed_execution
fi

# 2. Review the latest log for error details
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
grep -i error "$LATEST_DIR/processAPINotes.log" | tail -20

# 3. Fix the underlying issue (database, network, etc.)

# 4. Remove the failed execution marker
rm /tmp/processAPINotes_failed_execution

# 5. Wait for next cron execution (recommended)
# The script is designed to run automatically via crontab.
# After removing the marker, wait for the next scheduled execution
# (typically every 15 minutes for processAPINotes.sh).
# Manual execution should only be used for testing/debugging.
```

#### Common Error Scenarios

**Historical data validation failure:**

```bash
# Error: Base tables missing or incomplete
# Solution: Run processPlanetNotes.sh first
./bin/process/processPlanetNotes.sh --base
```

**XML validation failure:**

```bash
# Error: Invalid XML structure from API
# Solution: Check API status
# Note: SKIP_XML_VALIDATION=true is already the default, so validation is skipped by default
# If you enabled validation (SKIP_XML_VALIDATION=false), you can revert to default:
unset SKIP_XML_VALIDATION
./bin/process/processAPINotes.sh
```

**Database connection failure:**

```bash
# Error: Cannot connect to database
# Solution: Check database is running and credentials in etc/properties.sh
psql -d osm_notes -c "SELECT 1;"
```

**Network connectivity issues:**

```bash
# Error: Network connectivity check failed
# Error: API unreachable or download failed
# Diagnosis:
ping -c 3 api.openstreetmap.org
curl -I "https://api.openstreetmap.org/api/0.6/notes"

# Solution: Check internet connection, firewall, DNS
# The script implements retry logic with exponential backoff
# Wait for automatic retry or check network configuration
```

**No last update timestamp:**

```bash
# Error: No last update. Please load notes first.
# Diagnosis:
psql -d osm_notes -c "SELECT * FROM max_note_timestamp;"

# Solution: Run processPlanetNotes.sh --base first to initialize database
./bin/process/processPlanetNotes.sh --base
```

**Planet process conflict:**

```bash
# Error: processPlanetNotes.sh is currently running
# Diagnosis:
ps aux | grep processPlanetNotes.sh
cat /tmp/processPlanetNotes.lock

# Solution: Wait for Planet process to complete, or if stuck:
# 1. Verify process is actually running
# 2. If not, remove stale lock: rm /tmp/processPlanetNotes.lock
```

**Large data gap detected:**

```bash
# Warning: Large gap detected (X notes), consider manual intervention
# Diagnosis:
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
grep -i "gap" "$LATEST_DIR/processAPINotes.log"

# Solution: Review gap details in logs
# If legitimate (e.g., API was down), script will continue
# If suspicious, may need to run processPlanetNotes.sh for full sync
```

**Parallel processing failures:**

```bash
# Error: Parallel processing failed
# Diagnosis:
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
grep -i "parallel\|partition" "$LATEST_DIR/processAPINotes.log"

# Solution:
# 1. Check memory: free -h
# 2. Reduce MAX_THREADS if memory constrained
# 3. Script will fall back to sequential processing if memory is low
export MAX_THREADS=2
./bin/process/processAPINotes.sh
```

**CSV validation failures:**

```bash
# Error: CSV validation failed
# Diagnosis:
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
grep -i "csv.*validation\|enum" "$LATEST_DIR/processAPINotes.log"

# Solution:
# 1. Review validation errors in logs
# 2. Check if data format changed
# 3. Temporarily skip validation (not recommended):
export SKIP_CSV_VALIDATION=true
./bin/process/processAPINotes.sh
```

**Missing SQL files:**

```bash
# Error: SQL file validation failed
# Diagnosis:
ls -la sql/process/41_create_api_tables.sql
ls -la sql/process/42_create_partitions.sql

# Solution: Verify SQL files exist in sql/process/ directory
# Check repository is complete: git status
```

**Memory issues during processing:**

```bash
# Error: Low memory detected, using sequential processing
# Diagnosis:
free -h
dmesg | grep -i "killed\|oom"

# Solution:
# 1. Script automatically falls back to sequential processing
# 2. Free up system memory
# 3. Reduce MAX_THREADS if needed
export MAX_THREADS=1
./bin/process/processAPINotes.sh
```

**Lock file conflicts:**

```bash
# Error: Script is already running
# Diagnosis:
ps aux | grep processAPINotes.sh
cat /tmp/processAPINotes.lock

# Solution:
# 1. If process is running, wait for completion
# 2. If process is not running, remove stale lock:
rm /tmp/processAPINotes.lock
```

**Failed execution marker present:**

```bash
# Error: Previous execution failed
# Diagnosis:
cat /tmp/processAPINotes_failed_execution

# Solution:
# 1. Review error details in marker file
# 2. Check email alert (if configured)
# 3. Review logs from failed execution
# 4. Fix underlying issue
# 5. Remove marker: rm /tmp/processAPINotes_failed_execution
# 6. Wait for next cron execution (recommended)
```

### Error Handling and Recovery Sequence

The following diagram shows how errors are handled and recovered:

```text
┌─────────────────────────────────────────────────────────────────────────┐
│              Error Handling and Recovery Flow                           │
└─────────────────────────────────────────────────────────────────────────┘

Normal Execution
    │
    ├─▶ Error occurs (any step)
    │   │
    │   ├─▶ ERR trap triggered
    │   │   ├─▶ Capture error details (line, command, exit code)
    │   │   ├─▶ Log error to file
    │   │   └─▶ Check GENERATE_FAILED_FILE flag
    │   │       │
    │   │       ├─▶ If true:
    │   │       │   ├─▶ __create_failed_marker()
    │   │       │   │   ├─▶ Create /tmp/processAPINotes_failed_execution
    │   │       │   │   ├─▶ Write error details to file
    │   │       │   │   └─▶ Send email alert (if SEND_ALERT_EMAIL=true)
    │   │       │   │
    │   │       │   └─▶ Exit with error code
    │   │       │
    │   │       └─▶ If false:
    │   │           └─▶ Exit with error code (no marker)
    │   │
    │   └─▶ Cleanup handlers (trap EXIT)
    │       ├─▶ __cleanup_on_exit()
    │       ├─▶ Remove temporary files (if CLEAN=true)
    │       └─▶ Remove lock file
    │
    └─▶ Next execution attempt
        │
        ├─▶ Check failed execution marker
        │   ├─▶ If exists:
        │   │   ├─▶ Display error message
        │   │   ├─▶ Show marker file path
        │   │   └─▶ Exit (ERROR_PREVIOUS_EXECUTION_FAILED)
        │   │
        │   └─▶ If not exists:
        │       └─▶ Continue normal execution
        │
        └─▶ Recovery process
            ├─▶ Admin receives email alert
            ├─▶ Admin reviews error details
            ├─▶ Admin fixes underlying issue
            ├─▶ Admin removes marker file
            └─▶ Wait for next cron execution
```

### Component Interaction Diagram

The following diagram shows how different components interact during processing:

```text
┌─────────────────────────────────────────────────────────────────────────┐
│              Component Interaction During Processing                     │
└─────────────────────────────────────────────────────────────────────────┘

processAPINotes.sh
    │
    ├─▶ Calls: functionsProcess.sh
    │   ├─▶ __checkPrereqs()
    │   ├─▶ __checkBaseTables()
    │   └─▶ __createBaseStructure()
    │
    ├─▶ Calls: processAPIFunctions.sh
    │   ├─▶ __getNewNotesFromApi()
    │   ├─▶ __countXmlNotesAPI()
    │   └─▶ __processApiXmlPart()
    │
    ├─▶ Calls: parallelProcessingFunctions.sh
    │   ├─▶ __splitXmlForParallelAPI()
    │   └─▶ __processApiXmlPart() [parallel]
    │
    ├─▶ Calls: validationFunctions.sh
    │   ├─▶ __validateApiNotesXMLFileComplete()
    │   ├─▶ __validate_csv_structure()
    │   └─▶ __validate_csv_for_enum_compatibility()
    │
    ├─▶ Calls: errorHandlingFunctions.sh
    │   ├─▶ __create_failed_marker()
    │   └─▶ __retry_* functions
    │
    ├─▶ Calls: commonFunctions.sh
    │   ├─▶ __log_* functions
    │   └─▶ __start_logger()
    │
    ├─▶ Calls: processPlanetNotes.sh (if TOTAL_NOTES >= MAX_NOTES)
    │   └─▶ Full synchronization
    │
    ├─▶ Executes: AWK scripts
    │   ├─▶ awk/extract_notes.awk
    │   ├─▶ awk/extract_comments.awk
    │   └─▶ awk/extract_comment_texts.awk
    │
    └─▶ Executes: SQL scripts
        ├─▶ sql/process/41_create_api_tables.sql
        ├─▶ sql/process/42_create_partitions.sql
        ├─▶ sql/process/43_load_partitioned_api_notes.sql
        └─▶ sql/process/44_consolidate_partitions.sql
```

### Cron Job Setup

#### Standard Production Cron

```bash
# Add to crontab (crontab -e)
# Process API notes every 15 minutes
# Note: Script creates its own log in /tmp/processAPINotes_XXXXXX/processAPINotes.log
# No need to redirect output unless you want additional logging
*/15 * * * * cd /path/to/OSM-Notes-Ingestion && ./bin/process/processAPINotes.sh >/dev/null 2>&1

# Alternative: Redirect to a logs directory (create it first: mkdir -p ~/logs)
*/15 * * * * cd /path/to/OSM-Notes-Ingestion && ./bin/process/processAPINotes.sh >> ~/logs/osm-notes-api.log 2>&1
```

#### Cron with Environment Variables

```bash
# With specific configuration
# Using logs directory in home (no special permissions required)
*/15 * * * * cd /path/to/OSM-Notes-Ingestion && export LOG_LEVEL=WARN && export SEND_ALERT_EMAIL=true && export ADMIN_EMAIL="admin@example.com" && ./bin/process/processAPINotes.sh >> ~/logs/osm-notes-api.log 2>&1

# Or without redirection (script creates its own log)
*/15 * * * * cd /path/to/OSM-Notes-Ingestion && export LOG_LEVEL=WARN && export SEND_ALERT_EMAIL=true && export ADMIN_EMAIL="admin@example.com" && ./bin/process/processAPINotes.sh >/dev/null 2>&1
```

**Note:** Scripts automatically create detailed logs in `/tmp/SCRIPT_NAME_XXXXXX/SCRIPT_NAME.log`. The cron redirection is optional and mainly useful for capturing startup errors. Use `~/logs/` or `./logs/` instead of `/var/log/` to avoid requiring special permissions.

### Database Inspection

#### Check Last Update Time

```bash
# Query the last update timestamp
psql -d osm_notes -c "SELECT last_update FROM properties WHERE key = 'last_update_api';"
```

#### Check API Tables

```bash
# View notes in API tables (before sync)
psql -d osm_notes -c "SELECT COUNT(*) FROM notes_api;"
psql -d osm_notes -c "SELECT note_id, latitude, longitude, status FROM notes_api LIMIT 10;"
```

#### Check Processing Status

```bash
# Check if Planet sync was triggered
psql -d osm_notes -c "SELECT * FROM properties WHERE key LIKE '%planet%';"
```

### Testing and Development

#### Development Mode

```bash
# Use test database
export DBNAME=osm_notes_test

# Enable all logging and validation
export LOG_LEVEL=TRACE
export SKIP_XML_VALIDATION=false
export SKIP_CSV_VALIDATION=false

# Keep files for inspection
export CLEAN=false

# Run script
./bin/process/processAPINotes.sh
```

#### Production Mode

```bash
# Minimal logging (errors only)
export LOG_LEVEL=ERROR

# Skip validation for speed (both XML and CSV validations are skipped by default)
# SKIP_XML_VALIDATION=true is the default, no need to export
# SKIP_CSV_VALIDATION=true is the default, no need to export
# Both validations are skipped by default for faster processing

# Clean up files (default: true)
export CLEAN=true

# Enable alerts
export SEND_ALERT_EMAIL=true
export ADMIN_EMAIL="admin@production.com"

# Run script
./bin/process/processAPINotes.sh
```

### Related Documentation

- **[bin/ENTRY_POINTS.md](../bin/ENTRY_POINTS.md)**: Entry point documentation
- **[bin/ENVIRONMENT_VARIABLES.md](../bin/ENVIRONMENT_VARIABLES.md)**: Complete environment variable reference
- **[Documentation.md](./Documentation.md)**: System architecture and general usage examples

## Table Architecture

### API Tables (Temporary)

API tables temporarily store data downloaded from the API:

- **`notes_api`**: Notes downloaded from the API
  - `note_id`: Unique OSM note ID
  - `latitude/longitude`: Geographic coordinates
  - `created_at`: Creation date
  - `status`: Status (open/closed)
  - `closed_at`: Closing date (if applicable)
  - `id_country`: ID of the country where it is located
  - `part_id`: Partition ID for parallel processing

- **`note_comments_api`**: Comments downloaded from the API
  - `id`: Generated sequential ID
  - `note_id`: Reference to the note
  - `sequence_action`: Comment order
  - `event`: Action type (open, comment, close, etc.)
  - `created_at`: Comment date
  - `id_user`: OSM user ID
  - `username`: OSM username
  - `part_id`: Partition ID for parallel processing

- **`note_comments_text_api`**: Comment text downloaded from the API
  - `id`: Comment ID
  - `note_id`: Reference to the note
  - `sequence_action`: Comment order
  - `body`: Textual content of the comment
  - `part_id`: Partition ID for parallel processing

### Base Tables (Permanent)

Uses the same base tables as `processPlanetNotes.sh`:

- `notes`, `note_comments`, `note_comments_text`

## Processing Flow

### Detailed Sequence Diagram

The following diagram shows the complete execution flow of `processAPINotes.sh`:


```text
┌─────────────────────────────────────────────────────────────────────────┐
│              processAPINotes.sh - Complete Execution Flow                │
└─────────────────────────────────────────────────────────────────────────┘

Cron/Manual
    │
    ▼
┌─────────────────┐
│  main() starts  │
└────────┬────────┘
         │
         ├─▶ Check --help parameter
         │   └─▶ Exit if help requested
         │
         ├─▶ Check failed execution marker
         │   └─▶ Exit if previous execution failed
         │
         ├─▶ __checkPrereqs()
         │   ├─▶ Verify commands available
         │   ├─▶ Verify database connection
         │   └─▶ Verify SQL files exist
         │
         ├─▶ __trapOn()
         │   └─▶ Setup error handlers and cleanup
         │
         ├─▶ __setupLockFile()
         │   ├─▶ Check for existing lock
         │   ├─▶ Create lock file (Singleton pattern)
         │   └─▶ Exit if already running
         │
         ├─▶ __dropApiTables()
         │   └─▶ Remove temporary API tables
         │
         ├─▶ __checkNoProcessPlanet()
         │   └─▶ Verify processPlanetNotes.sh not running
         │
         ├─▶ __checkBaseTables()
         │   ├─▶ Check if base tables exist
         │   └─▶ Return RET_FUNC (0=OK, 1=Missing, 2=Error)
         │
         ├─▶ Decision: RET_FUNC value
         │   │
         │   ├─▶ RET_FUNC=1 (Tables missing)
         │   │   └─▶ __createBaseStructure()
         │   │       └─▶ Calls processPlanetNotes.sh --base
         │   │
         │   ├─▶ RET_FUNC=0 (Tables exist)
         │   │   └─▶ __validateHistoricalDataAndRecover()
         │   │       └─▶ Validates and recovers if needed
         │   │
         │   └─▶ RET_FUNC=2 (Error)
         │       └─▶ Create failed marker and exit
         │
         ├─▶ __createApiTables()
         │   └─▶ Create temporary API tables
         │
         ├─▶ __createPartitions()
         │   └─▶ Create partitions for parallel processing
         │
         ├─▶ __createPropertiesTable()
         │   └─▶ Create properties tracking table
         │
         ├─▶ __ensureGetCountryFunction()
         │   └─▶ Ensure get_country() function exists
         │
         ├─▶ __createProcedures()
         │   └─▶ Create database procedures
         │
         ├─▶ __getNewNotesFromApi()
         │   ├─▶ Get last update timestamp from DB
         │   ├─▶ Build OSM API URL
         │   ├─▶ Download XML from OSM API
         │   └─▶ Save to API_NOTES_FILE
         │
         ├─▶ __validateApiNotesFile()
         │   ├─▶ Check file exists
         │   └─▶ Check file not empty
         │
         ├─▶ __validateAndProcessApiXml()
         │   │
         │   ├─▶ __validateApiNotesXMLFileComplete() [if SKIP_XML_VALIDATION=false]
         │   │   └─▶ Validate XML structure
         │   │
         │   ├─▶ __countXmlNotesAPI()
         │   │   └─▶ Count notes in XML (sets TOTAL_NOTES)
         │   │
         │   ├─▶ __processXMLorPlanet()
         │   │   │
         │   │   ├─▶ Decision: TOTAL_NOTES >= MAX_NOTES?
         │   │   │   │
         │   │   │   ├─▶ YES: Call processPlanetNotes.sh (full sync)
         │   │   │   │
         │   │   │   └─▶ NO: Process locally
         │   │   │       │
         │   │   │       ├─▶ Decision: TOTAL_NOTES >= MIN_NOTES_FOR_PARALLEL?
         │   │   │       │   │
         │   │   │       │   ├─▶ YES: Parallel processing
         │   │   │       │   │   ├─▶ __checkMemoryForProcessing()
         │   │   │       │   │   ├─▶ __splitXmlForParallelAPI()
         │   │   │       │   │   └─▶ __processApiXmlPart() [parallel]
         │   │   │       │   │       ├─▶ AWK: XML → CSV
         │   │   │       │   │       ├─▶ Validate CSV structure
         │   │   │       │   │       └─▶ Load to DB partition
         │   │   │       │   │
         │   │   │       │   └─▶ NO: Sequential processing
         │   │   │       │       └─▶ __processApiXmlSequential()
         │   │   │       │           ├─▶ AWK: XML → CSV
         │   │   │       │           └─▶ Load to DB
         │   │   │
         │   │   └─▶ __consolidatePartitions()
         │   │       └─▶ Merge partition data
         │   │
         │   ├─▶ __insertNewNotesAndComments()
         │   │   └─▶ Insert notes and comments to base tables
         │   │
         │   ├─▶ __loadApiTextComments()
         │   │   └─▶ Load comment text to base tables
         │   │
         │   └─▶ __updateLastValue()
         │       └─▶ Update last_update timestamp
         │
         ├─▶ __check_and_log_gaps()
         │   └─▶ Check for data gaps and log
         │
         ├─▶ __cleanNotesFiles()
         │   └─▶ Clean temporary files (if CLEAN=true)
         │
         └─▶ Remove lock file
             └─▶ Exit successfully
```

### Simplified Flow Steps

#### 1. Prerequisites Verification

- Verifies that `processPlanetNotes.sh` is not running
- Checks existence of base tables
- Validates necessary SQL files

#### 2. API Table Management

- Removes existing API tables
- Creates new API tables with partitioning
- Creates properties table for tracking

#### 3. Data Download

- Gets last update timestamp from database
- Builds API URL with filtering parameters
- Downloads new/modified notes from OSM API
- Validates downloaded XML structure

#### 4. Processing Decision

**If downloaded notes >= MAX_NOTES (configurable)**:

- Executes complete synchronization from Planet
- Calls `processPlanetNotes.sh`

**If downloaded notes < MAX_NOTES**:

- Processes downloaded notes locally
- Uses parallel processing with partitioning

#### 5. Parallel Processing

- Divides XML file into parts
- Processes each part in parallel using AWK extraction
- Consolidates results from all partitions

### 6. Data Integration

- Inserts new notes and comments into base tables
- Processes in chunks if there is much data (>1000 notes)
- Updates last update timestamp
- Cleans temporary files

## Integration with Planet Processing

### When Complete Synchronization is Required

When the number of notes downloaded from the API exceeds the configured threshold (MAX_NOTES), the script triggers a complete synchronization from Planet:

1. **Stops API Processing**: Halts current API processing
2. **Calls Planet Script**: Executes `processPlanetNotes.sh --base`
3. **Resets API State**: Clears API processing state
4. **Resumes API Processing**: Continues with incremental updates

### Benefits of This Approach

- **Data Consistency**: Ensures complete data synchronization
- **Performance**: Avoids processing large API datasets
- **Reliability**: Uses proven Planet processing pipeline
- **Efficiency**: Leverages existing Planet infrastructure

## Configuration

### Environment Variables

The script uses several environment variables for configuration:

- **`MAX_NOTES`**: Threshold for triggering Planet synchronization
- **`API_TIMEOUT`**: Timeout for API requests
- **`PARALLEL_THREADS`**: Number of parallel processing threads
- **`CHUNK_SIZE`**: Size of data chunks for processing

### Database Configuration

- **`DBNAME`**: Database name for notes storage
- **`DB_USER`**: Database user for connections
- **`DB_PASSWORD`**: Database password for authentication
- **`DB_HOST`**: Database host address
- **`DB_PORT`**: Database port number

## Error Handling

### Common Error Scenarios

1. **API Unavailable**: Retries with exponential backoff
2. **Database Connection Issues**: Logs error and exits gracefully
3. **XML Parsing Errors**: Validates structure before processing
4. **Disk Space Issues**: Checks available space before processing

### Recovery Mechanisms

- **Automatic Retry**: Implements retry logic for transient failures
- **Graceful Degradation**: Continues processing with available data
- **Error Logging**: Comprehensive error logging for debugging
- **State Preservation**: Maintains processing state for recovery

### Signal and Trap Handling

The API processing uses refined trap management to ensure safe termination,
consistent cleanup, and clear error reporting when the process is interrupted
or an unexpected error occurs.

- Trapped signals: `INT`, `TERM`, `ERR`.
- On trap:
  - Flushes and closes log sections properly.
  - Marks partial runs to enable recovery on next execution.
  - Cleans temporary directories when safe (`CLEAN=true`), preserving artifacts
    for debugging otherwise.
  - Exits with a non-zero error code aligned with the error category.

Operational guarantees:
- No orphan temporary directories when `CLEAN=true`.
- No silent exits; traps always log the call stack and failure reason.
- Compatible with parallel execution; each worker logs its own context.

## Performance Considerations

### Optimization Strategies

- **Parallel Processing**: Uses multiple threads for data processing
- **Partitioning**: Divides large datasets into manageable chunks
- **Memory Management**: Efficient memory usage for large XML files
- **Database Optimization**: Uses optimized queries and indexes

### Monitoring Points

- **Processing Time**: Tracks time for each processing phase
- **Memory Usage**: Monitors memory consumption during processing
- **Database Performance**: Tracks database query performance
- **API Response Times**: Monitors API request response times

## Maintenance

### Regular Tasks

- **Log Rotation**: Manages log file sizes and rotation
- **Temporary File Cleanup**: Removes temporary files after processing
- **Database Maintenance**: Performs database optimization tasks
- **Configuration Updates**: Updates configuration as needed

### Troubleshooting

- **Log Analysis**: Reviews logs for error patterns
- **Performance Tuning**: Adjusts parameters based on performance data
- **Database Optimization**: Optimizes database queries and indexes
- **System Monitoring**: Monitors system resources and performance

## Related Documentation

- **System Overview**: See [Documentation.md](./Documentation.md) for general architecture
- **Planet Processing**: See [processPlanet.md](./processPlanet.md) for Planet data processing details
- **Project Background**: See [Rationale.md](./Rationale.md) for project motivation and goals
