# Complete Description of processAPINotes.sh

> **Note:** For a general system overview, see [Documentation.md](./Documentation.md).
> For project motivation and background, see [Rationale.md](./Rationale.md).
> 
> **⚠️ Recommended:** For production use, consider using `processAPINotesDaemon.sh` instead (see [Daemon Mode](#daemon-mode-processapinotesdaemonsh) section). The daemon provides lower latency (30-60 seconds vs 15 minutes) and better efficiency.

## General Purpose

The `processAPINotes.sh` script is the incremental synchronization component of the
OpenStreetMap notes processing system. Its main function is to download the most
recent notes from the OSM API and synchronize them with the local database that
maintains the complete history.

> **Note:** This script can be run manually or via cron, but for production environments, the daemon mode (`processAPINotesDaemon.sh`) is recommended for better performance and lower latency.

## Main Features

- **Incremental Processing**: Only downloads and processes new or modified notes
- **Intelligent Synchronization**: Automatically determines when to perform complete synchronization from Planet
- **Sequential Processing**: Efficient sequential processing optimized for incremental updates
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


### Design Patterns Used

- **Singleton Pattern**: Ensures only one instance of `processAPINotes.sh` runs at a time (also used by the daemon)
- **Retry Pattern**: Implements exponential backoff for API calls and network operations
- **Circuit Breaker Pattern**: Prevents cascading failures when API is unavailable
- **Resource Management Pattern**: Uses `trap` handlers for cleanup of temporary files and resources

### Alternatives Considered

- **Single Script Approach**: Considered combining API and Planet processing into one script, but rejected to maintain separation of concerns and allow independent optimization
- **Partitioning Strategy**: Evaluated partitioning for API processing but chose sequential processing for simpler architecture and better suitability for incremental updates

### Trade-offs

- **Simplicity vs. Performance**: Sequential processing provides good performance for incremental updates while maintaining simplicity
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

- It is designed to run automatically (can be used with cron, but daemon mode is recommended)
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

**Automatic Recovery for Network Errors:**

The script now automatically recovers from temporary network errors:

- **Network errors** (connectivity issues, API timeouts): Do NOT create a failed execution marker
- **Auto-retry**: On next execution, the script verifies connectivity and continues automatically if restored
- **No manual intervention needed** for temporary network issues

**Manual Recovery for Data/Logic Errors:**

When a critical non-network error occurs (data corruption, logic errors), the script creates a failed execution marker:

```bash
# 1. Check if previous execution failed
if [ -f /tmp/processAPINotes_failed_execution ]; then
    echo "Previous execution failed. Check email for details."
    cat /tmp/processAPINotes_failed_execution
fi

# 2. Review the latest log for error details
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
grep -i error "$LATEST_DIR/processAPINotes.log" | tail -20

# 3. Fix the underlying issue (database, data corruption, etc.)

# 4. Remove the failed execution marker
rm /tmp/processAPINotes_failed_execution

# 5. Wait for next execution
# If using daemon mode: it will retry automatically
# If using cron: wait for next scheduled execution
# Manual execution should only be used for testing/debugging.
```

**Note:** Network errors are handled automatically and do not require manual intervention. Only data corruption or logic errors require manual recovery.

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
# (created from etc/properties.sh.example)
psql -d notes -c "SELECT 1;"
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
psql -d notes -c "SELECT * FROM max_note_timestamp;"

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
# 6. Wait for next execution (if using cron) or let daemon retry automatically
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
            └─▶ Wait for next execution (cron) or automatic retry (daemon)
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
    │   └─▶ __processApiXmlSequential()
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
        ├─▶ sql/process/processAPINotes_21_createApiTables.sql
        ├─▶ sql/process/processAPINotes_31_loadApiNotes.sql
        ├─▶ sql/process/processAPINotes_32_insertNewNotesAndComments.sql
        └─▶ sql/process/processAPINotes_33_loadNewTextComments.sql
```

### Automated Execution

> **⚠️ Recommended:** For production use, use the daemon mode (`processAPINotesDaemon.sh`) instead. See the [Daemon Mode](#daemon-mode-processapinotesdaemonsh) section for installation and configuration. The daemon provides 30-60 second latency vs 15 minutes with cron.

#### Using Cron (Legacy/Alternative)

If you need to use cron instead of the daemon (e.g., systemd not available):

```bash
# Add to crontab (crontab -e)
# Process API notes every 15 minutes
*/15 * * * * cd /path/to/OSM-Notes-Ingestion && ./bin/process/processAPINotes.sh >/dev/null 2>&1
```

**Note:** Scripts automatically create detailed logs in `/tmp/processAPINotes_XXXXXX/processAPINotes.log`. The cron redirection is optional and mainly useful for capturing startup errors.

### Database Inspection

#### Check Last Update Time

```bash
# Query the last update timestamp
psql -d notes -c "SELECT last_update FROM properties WHERE key = 'last_update_api';"
```

#### Check API Tables

```bash
# View notes in API tables (before sync)
psql -d notes -c "SELECT COUNT(*) FROM notes_api;"
psql -d notes -c "SELECT note_id, latitude, longitude, status FROM notes_api LIMIT 10;"
```

#### Check Processing Status

```bash
# Check if Planet sync was triggered
psql -d notes -c "SELECT * FROM properties WHERE key LIKE '%planet%';"
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

#### Code Example: Creating and Using API Tables

The following example shows how API tables are created and used during processing:

```bash
# Source the API processing functions
source bin/lib/processAPIFunctions.sh

# Create API tables (called automatically by processAPINotes.sh)
__createApiTables

# Verify tables were created
psql -d "${DBNAME}" -c "SELECT 
  schemaname,
  tablename,
  tableowner
FROM pg_tables
WHERE tablename LIKE 'notes_api%'
ORDER BY tablename;"

# Example: Load data into API tables (sequential processing)
__processApiXmlSequential "${XML_FILE}"
```

**SQL Example: API Table Structure**

```sql
-- Example API table structure
-- Created by: sql/process/processAPINotes_21_createApiTables.sql

CREATE TABLE IF NOT EXISTS notes_api (
  note_id INTEGER NOT NULL,
  latitude DECIMAL NOT NULL,
  longitude DECIMAL NOT NULL,
  created_at TIMESTAMP NOT NULL,
  closed_at TIMESTAMP,
  status note_status_enum,
  id_country INTEGER
);

-- Data is loaded directly into API tables using COPY command
-- No partitions are needed for sequential processing
```

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

Manual/Daemon
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
         │   │   │       │   │
         │   │   │       │   └─▶ Sequential processing
         │   │   │       │       └─▶ __processApiXmlSequential()
         │   │   │       │           ├─▶ AWK: XML → CSV
         │   │   │       │           ├─▶ Validate CSV structure
         │   │   │       │           └─▶ Load to DB
         │   │   │
         │   ├─▶ __insertNewNotesAndComments()
         │   │   ├─▶ Insert notes and comments to base tables
         │   │   ├─▶ Validate data integrity (integrity check)
         │   │   └─▶ Update last_update timestamp (same connection)
         │   │       Note: Timestamp update runs in same connection to preserve
         │   │       integrity_check_passed variable between transactions
         │   │
         │   ├─▶ __loadApiTextComments()
         │   │   └─▶ Load comment text to base tables
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
- Creates new API tables (no partitioning)
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
- Uses sequential processing

#### 5. Sequential Processing

- Processes XML file sequentially using AWK extraction
- Loads data directly into API tables
- Validates CSV structure before loading

### 6. Data Integration

- Inserts new notes and comments into base tables
- Processes in chunks if there is much data (>1000 notes)
- Validates data integrity (checks for notes without comments)
- Updates last update timestamp (executed in same connection as insertion to preserve integrity check result)
- Cleans temporary files

#### Code Example: Data Integration Process

The following example shows how API data is integrated into base tables:

```bash
# Source the API processing functions
source bin/lib/processAPIFunctions.sh

# Insert new notes and comments from API tables to base tables
# This uses stored procedures for efficient bulk insertion
# Note: This function also updates the timestamp automatically in the same
# database connection to ensure integrity check results persist
__insertNewNotesAndComments

# Verify the integration
psql -d "${DBNAME}" -c "
  SELECT 
    COUNT(*) as total_notes,
    COUNT(*) FILTER (WHERE status = 'open') as open_notes,
    COUNT(*) FILTER (WHERE status = 'closed') as closed_notes
  FROM notes;
"
```

**SQL Procedure Example:**

The `__insertNewNotesAndComments()` function uses stored procedures for efficient insertion:

```sql
-- Example stored procedure used by __insertNewNotesAndComments()
-- Located in: sql/process/processAPINotes_32_insertNewNotesAndComments.sql

-- Insert new notes (simplified version)
INSERT INTO notes (
  note_id, latitude, longitude, created_at, closed_at, status
)
SELECT 
  note_id, latitude, longitude, created_at, closed_at, status
FROM notes_api
WHERE note_id NOT IN (SELECT note_id FROM notes)
ON CONFLICT (note_id) DO UPDATE SET
  status = EXCLUDED.status,
  closed_at = EXCLUDED.closed_at;

-- Insert new comments
INSERT INTO note_comments (
  note_id, sequence_action, event, created_at, id_user, username
)
SELECT 
  note_id, sequence_action, event, created_at, id_user, username
FROM note_comments_api
ON CONFLICT (note_id, sequence_action) DO NOTHING;
```

## Detailed Sequence Diagrams

### API Processing Sequence Diagram

The following diagram shows the detailed sequence of interactions between components during API processing:

```text
┌─────────────────────────────────────────────────────────────────────────┐
│          Detailed Sequence: processAPINotes.sh Component Interactions     │
└─────────────────────────────────────────────────────────────────────────┘

User/Daemon        processAPINotesDaemon.sh    OSM API      PostgreSQL    AWK Scripts
    │                      │               │              │              │
    │───execute───────────▶│               │              │              │
    │                      │               │              │              │
    │                      │───check failed marker───────▶│              │
    │                      │◀───marker exists?────────────│              │
    │                      │               │              │              │
    │                      │───__checkPrereqs()───────────▶│              │
    │                      │◀───prereqs OK────────────────│              │
    │                      │               │              │              │
    │                      │───__setupLockFile()──────────▶│              │
    │                      │◀───lock created───────────────│              │
    │                      │               │              │              │
    │                      │───__checkBaseTables()─────────▶│              │
    │                      │◀───RET_FUNC (0/1/2)───────────│              │
    │                      │               │              │              │
    │                      │───__createApiTables()─────────▶│              │
    │                      │               │              │              │
    │                      │───CREATE TABLE notes_api──────▶│              │
    │                      │◀───table created──────────────│              │
    │                      │               │              │              │
    │                      │───__createPartitions()────────▶│              │
    │                      │               │              │              │
    │                      │───CREATE partition tables──────▶│              │
    │                      │◀───partitions created──────────│              │
    │                      │               │              │              │
    │                      │───__getNewNotesFromApi()───────▶│              │
    │                      │               │              │              │
    │                      │               │───GET /api/0.6/notes───────▶│
    │                      │               │◀───XML response─────────────│
    │                      │◀───XML file────────────────────│              │
    │                      │               │              │              │
    │                      │───__countXmlNotesAPI()─────────▶│              │
    │                      │               │              │              │
    │                      │               │              │              │
    │                      │───grep + wc───────────────────▶│              │
    │                      │◀───TOTAL_NOTES──────────────────│              │
    │                      │               │              │              │
    │                      │───Decision: TOTAL_NOTES >= MAX? │              │
    │                      │               │              │              │
    │                      │   [If YES: Call processPlanetNotes.sh]       │
    │                      │               │              │              │
    │                      │───__processApiXmlSequential()──▶│              │
    │                      │               │              │              │
    │                      │               │              │              │
    │                      │───process XML file──────────────▶│              │
    │                      │               │              │              │
    │                      │               │              │              │
    │                      │               │              │───extract_notes.awk──▶│
    │                      │               │              │◀───CSV output─────────│
    │                      │◀───CSV file─────────────────────│              │
    │                      │               │              │              │
    │                      │───__loadApiNotes()──────────────▶│              │
    │                      │               │              │              │
    │                      │───COPY CSV to partition_0───────▶│              │
    │                      │◀───data loaded───────────────────│              │
    │                      │               │              │              │
    │                      │───load CSV into notes_api───────▶│              │
    │                      │◀───data loaded───────────────────│              │
    │                      │               │              │              │
    │                      │───__insertNewNotesAndComments()──▶│              │
    │                      │               │              │              │
    │                      │───INSERT INTO notes─────────────▶│              │
    │                      │◀───notes inserted────────────────│              │
    │                      │               │              │              │
    │                      │───Integrity check───────────────▶│              │
    │                      │◀───check passed─────────────────│              │
    │                      │               │              │              │
    │                      │───UPDATE max_note_timestamp─────▶│              │
    │                      │◀───updated (same connection)────│              │
    │                      │               │              │              │
    │                      │───__dropApiTables()─────────────▶│              │
    │                      │               │              │              │
    │                      │───DROP TABLE notes_api──────────▶│              │
    │                      │◀───tables dropped────────────────│              │
    │                      │               │              │              │
    │◀───success───────────│               │              │              │
```

### Parallel Processing Sequence Diagram

The following diagram shows how parallel processing coordinates multiple threads:

```text
┌─────────────────────────────────────────────────────────────────────────┐
│          Parallel Processing: Multi-Thread Coordination                  │
└─────────────────────────────────────────────────────────────────────────┘

Main Script      GNU Parallel    Thread 1    Thread 2    Thread N    PostgreSQL
    │                 │             │            │           │            │
    │───split XML────▶│             │            │           │            │
    │                 │             │            │           │            │
    │                 │───part_0───▶│            │           │            │
    │                 │───part_1───────▶│         │           │            │
    │                 │───part_N───────────────▶│            │            │
    │                 │             │            │           │            │
    │                 │───process part_0───────▶│            │            │
    │                 │             │            │           │            │
    │                 │             │───AWK extract─────────▶│            │
    │                 │             │◀───CSV──────────────────│            │
    │                 │             │            │           │            │
    │                 │             │───load partition_0─────▶│            │
    │                 │             │◀───loaded────────────────│            │
    │                 │             │            │           │            │
    │                 │             │───process part_1───────▶│            │
    │                 │             │            │           │            │
    │                 │             │            │───AWK extract─────────▶│
    │                 │             │            │◀───CSV──────────────────│
    │                 │             │            │           │            │
    │                 │             │            │───load partition_1─────▶│
    │                 │             │            │◀───loaded────────────────│
    │                 │             │            │           │            │
    │                 │             │            │           │            │
    │                 │───[All threads complete]─────────────│            │
    │                 │             │            │           │            │
    │───consolidate──▶│             │            │           │            │
    │                 │             │            │           │            │
    │                 │───consolidate all partitions─────────▶│            │
    │                 │             │            │           │            │
    │                 │             │            │           │◀───INSERT───│
    │                 │             │            │           │───consolidated─▶│
    │◀───complete──────│             │            │           │            │
```

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

This section covers common issues specific to API processing. For a comprehensive troubleshooting guide, see [Troubleshooting_Guide.md](./Troubleshooting_Guide.md).

#### Common API Processing Issues

**1. API Rate Limiting or Timeout**

**Symptoms:**
- Error: "API unreachable or download failed"
- Timeout errors during API calls
- Script fails during download phase

**Diagnosis:**
```bash
# Test API connectivity
curl -I "https://api.openstreetmap.org/api/0.6/notes"

# Check network connectivity
ping -c 3 api.openstreetmap.org

# Review download logs
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
grep -i "api\|download\|timeout" "$LATEST_DIR/processAPINotes.log" | tail -20
```

**Solutions:**
- **Automatic Recovery**: Network errors are handled automatically - no manual intervention needed
- The script will automatically retry on the next execution when connectivity is restored
- Check internet connectivity: `ping -c 3 api.openstreetmap.org`
- Verify OSM API is operational: https://www.openstreetmap.org/api/status
- The script implements automatic retry with exponential backoff (5 attempts)
- **Note**: Network errors do NOT create a failed execution marker, allowing automatic recovery

**2. Base Tables Missing**

**Symptoms:**
- Error: "Base tables missing or incomplete"
- Script exits with error code 238
- Failed execution marker created

**Diagnosis:**
```bash
# Check if base tables exist
psql -d "${DBNAME:-notes}" -c "
  SELECT table_name 
  FROM information_schema.tables 
  WHERE table_schema = 'public' 
    AND table_name IN ('notes', 'note_comments', 'countries');
"

# Check failed execution marker
cat /tmp/processAPINotes_failed_execution
```

**Solutions:**
- Run initial Planet processing to create base tables:
  ```bash
  ./bin/process/processPlanetNotes.sh --base
  ```
- This will download and process historical data (takes 1-2 hours)
- After completion, API processing will work normally

**3. Large Data Gap Detected**

**Symptoms:**
- Warning: "Large gap detected (X notes), consider manual intervention"
- Script continues but logs warning
- May indicate API was down for extended period

**Diagnosis:**
```bash
# Review gap details in logs
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
grep -i "gap\|missing" "$LATEST_DIR/processAPINotes.log"

# Check last update timestamp
psql -d "${DBNAME:-notes}" -c "
  SELECT * FROM properties WHERE key = 'last_update_api';
"
```

**Solutions:**
- If gap is legitimate (API was down), script will continue normally
- If gap is suspicious, consider running Planet sync:
  ```bash
  ./bin/process/processPlanetNotes.sh
  ```
- Review gap size: gaps < 10,000 notes are usually acceptable

**4. Parallel Processing Failures**

**Symptoms:**
- Error: "Parallel processing failed"
- Low memory warnings
- Script falls back to sequential processing

**Diagnosis:**
```bash
# Check memory usage
free -h

# Check system logs for OOM kills
dmesg | grep -i "killed\|oom"

# Review processing logs
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
grep -i "parallel\|memory\|partition" "$LATEST_DIR/processAPINotes.log"
```

**Solutions:**
- Reduce MAX_THREADS if memory constrained:
  ```bash
  export MAX_THREADS=2
  ./bin/process/processAPINotes.sh
  ```
- Script automatically falls back to sequential processing if memory is low
- Add swap space if needed: `sudo swapon --show`

**5. CSV Validation Failures**

**Symptoms:**
- Error: "CSV validation failed"
- Enum compatibility errors
- Script exits during validation phase

**Diagnosis:**
```bash
# Review validation errors
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
grep -i "csv.*validation\|enum" "$LATEST_DIR/processAPINotes.log"

# Check CSV files (if CLEAN=false)
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
head -5 "$LATEST_DIR"/*.csv
```

**Solutions:**
- Review validation errors in logs to identify specific issues
- Check if OSM data format changed (rare)
- Temporarily skip validation for debugging (not recommended for production):
  ```bash
  export SKIP_CSV_VALIDATION=true
  ./bin/process/processAPINotes.sh
  ```

**6. Planet Sync Triggered**

**Symptoms:**
- Message: "Starting full synchronization from Planet"
- Script calls processPlanetNotes.sh
- Processing takes much longer than usual

**Diagnosis:**
```bash
# Check why Planet sync was triggered
LATEST_DIR=$(ls -1rtd /tmp/processAPINotes_* | tail -1)
grep -i "total_notes\|max_notes\|planet" "$LATEST_DIR/processAPINotes.log"

# Check MAX_NOTES threshold
grep -i "MAX_NOTES" etc/properties.sh
```

**Solutions:**
- This is normal behavior when API returns >= 10,000 notes
- Planet sync ensures complete data consistency
- Wait for Planet processing to complete (may take 1-2 hours)
- After completion, API processing resumes normally

#### Quick Diagnostic Commands

```bash
# Check script execution status
ps aux | grep processAPINotes.sh

# View latest log in real-time
tail -f $(ls -1rtd /tmp/processAPINotes_* | tail -1)/processAPINotes.log

# Check for failed execution
ls -la /tmp/processAPINotes_failed_execution

# Verify database connection
psql -d "${DBNAME:-notes}" -c "SELECT COUNT(*) FROM notes;"

# Check last update time
psql -d "${DBNAME:-notes}" -c "
  SELECT * FROM properties WHERE key = 'last_update_api';
"
```

#### Getting More Help

- **Comprehensive Guide**: See [Troubleshooting_Guide.md](./Troubleshooting_Guide.md) for detailed troubleshooting across all components
- **Error Codes**: See [Troubleshooting_Guide.md#error-code-reference](./Troubleshooting_Guide.md#error-code-reference) for complete error code reference
- **Logs**: All logs are stored in `/tmp/processAPINotes_XXXXXX/processAPINotes.log`
- **System Documentation**: See [Documentation.md](./Documentation.md) for system architecture overview

## Daemon Mode: processAPINotesDaemon.sh (Recommended)

> **Status:** **Recommended for production** - Provides lower latency and better efficiency than cron-based execution

### Overview

`processAPINotesDaemon.sh` is the **recommended production solution**, replacing cron-based execution of `processAPINotes.sh`. It provides the same functionality with significant improvements:

- **Lower Latency**: 30-60 seconds between checks (vs 15 minutes with cron)
- **Better Efficiency**: One-time setup instead of recreating structures each execution
- **Adaptive Sleep**: Adjusts wait time based on processing duration
- **Continuous Operation**: Runs indefinitely, automatically recovering from errors

### Comparison: Cron Script vs Daemon

| Aspect | processAPINotes.sh (Cron) | processAPINotesDaemon.sh (Daemon) ⭐ |
|--------|---------------------------|--------------------------------------|
| **Status** | Legacy/Alternative | **Recommended for production** |
| **Execution** | Periodic (every 15 min) | Continuous (loop) |
| **Latency** | 15 minutes | 30-60 seconds |
| **Setup Overhead** | Every execution (1.8-4.5s) | Once at startup |
| **Table Management** | DROP + CREATE each time | TRUNCATE (reuses structure) |
| **Error Recovery** | Wait for next cron | Immediate retry |
| **Use Case** | Legacy systems, testing | **Production, real-time systems, messaging** |

**⚠️ Important:** Do NOT run both scripts simultaneously. They use the same database tables and will conflict.

**Recommendation:** Use the daemon for all production deployments. The cron approach is only recommended for legacy systems or when systemd is not available.

### Installation

#### Using systemd (Recommended)

1. **Copy service file:**
   ```bash
   sudo cp examples/systemd/osm-notes-api-daemon.service /etc/systemd/system/
   ```

2. **Edit service file** (REQUIRED - adjust paths and user):
   ```bash
   sudo nano /etc/systemd/system/osm-notes-api-daemon.service
   ```

   **Important:** Update these lines:
   - `User=notes` → Your production user (may be different from login user)
   - `Group=notes` → **OPTIONAL** - Comment out or remove if you get `status=216/GROUP` error. systemd will use the user's primary group automatically.
   - `WorkingDirectory=/home/notes/OSM-Notes-Ingestion` → Actual project path
   - `ExecStart=/home/notes/OSM-Notes-Ingestion/bin/process/processAPINotesDaemon.sh` → Actual script path
   - `Documentation=file:///home/notes/OSM-Notes-Ingestion/docs/Process_API.md` → Actual docs path

   **Note:** If you login as `angoca` but the process should run as `notes`, set `User=notes`. The `Group=` line is optional - if you get `status=216/GROUP` error, remove the `Group=` line and systemd will use the user's primary group automatically.

   **Troubleshooting:** 
   
   **Error 217/USER (user not found):**
   - Verify user exists: `getent passwd notes`
   - Update `User=` in service file to an existing user
   
   **Error 216/GROUP (group not found):**
   - Remove the `Group=` line from the service file (systemd will use user's primary group automatically)
   - Or find primary group: `id -gn notes` and use that name
   
   **Error 127 (command not found):**
   - Make script executable: `sudo chmod +x /home/notes/OSM-Notes-Ingestion/bin/process/processAPINotesDaemon.sh`
   - Use explicit bash in ExecStart: `ExecStart=/bin/bash /path/to/processAPINotesDaemon.sh` (instead of relying on shebang)
   - Verify script runs manually: `sudo -u notes /home/notes/OSM-Notes-Ingestion/bin/process/processAPINotesDaemon.sh --help`
   - Check PATH is set in service file (should include `/usr/bin:/bin`)

3. **Enable and start:**
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable osm-notes-api-daemon
   sudo systemctl start osm-notes-api-daemon
   ```

4. **Verify status:**
   ```bash
   sudo systemctl status osm-notes-api-daemon
   sudo journalctl -u osm-notes-api-daemon -f
   ```

### Configuration

#### Environment Variables

```bash
# Sleep interval between API checks (default: 60 seconds)
export DAEMON_SLEEP_INTERVAL=60

# Logging level
export LOG_LEVEL=INFO

# Clean temporary files after processing
export CLEAN=true
```

#### Adaptive Sleep Logic

The daemon implements intelligent sleep calculation:

- **No new notes**: Sleeps full interval (60s default)
- **Processing < interval**: Sleeps remaining time (60s - processing_time)
- **Processing ≥ interval**: Continues immediately (no sleep)

**Examples:**
- Processed in 25s → Sleeps 35s (maintains 60s interval)
- Processed in 80s → Sleeps 0s (continues immediately)
- No notes → Sleeps 60s

### Migration from Cron Script

#### Step 1: Stop Cron Job

```bash
# Edit crontab
crontab -e

# Comment or remove the line:
# */15 * * * * /path/to/OSM-Notes-Ingestion/bin/process/processAPINotes.sh >/dev/null 2>&1
```

**Verify cron is stopped:**
```bash
crontab -l | grep processAPINotes
# Should return nothing or show commented line
```

#### Step 2: Install systemd Service

```bash
# 1. Copy service file
sudo cp examples/systemd/osm-notes-api-daemon.service /etc/systemd/system/

# 2. Edit service file (REQUIRED - adjust paths and user)
sudo nano /etc/systemd/system/osm-notes-api-daemon.service
```

**Edit these lines in the service file:**
- `User=osmuser` → Change to your user
- `Group=osmuser` → Change to your group  
- `WorkingDirectory=/path/to/OSM-Notes-Ingestion` → Change to actual path
- `ExecStart=/path/to/OSM-Notes-Ingestion/bin/process/processAPINotesDaemon.sh` → Change to actual path
- `Documentation=file:///path/to/OSM-Notes-Ingestion/docs/Process_API.md` → Change to actual path

**Optional:** Adjust environment variables:
- `LOG_LEVEL=INFO` (or DEBUG, WARN, ERROR)
- `DAEMON_SLEEP_INTERVAL=60` (seconds between checks)
- `CLEAN=true` (clean temporary files)

#### Step 3: Enable and Start Daemon

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable daemon (start on boot)
sudo systemctl enable osm-notes-api-daemon

# Start daemon
sudo systemctl start osm-notes-api-daemon
```

#### Step 4: Verify Installation

```bash
# Check service status
sudo systemctl status osm-notes-api-daemon
# Should show: "Active: active (running)"

# View logs in real-time
sudo journalctl -u osm-notes-api-daemon -f

# View last 50 lines
sudo journalctl -u osm-notes-api-daemon -n 50
```

#### Step 5: Verify Data Processing

```bash
# Check that notes are being processed
psql -d "${DBNAME}" -c "
  SELECT COUNT(*), MAX(created_at) 
  FROM notes 
  WHERE created_at > NOW() - INTERVAL '1 hour';
"

# Check last processed timestamp
psql -d "${DBNAME}" -c "
  SELECT timestamp, NOW() - timestamp AS age 
  FROM max_note_timestamp;
"
```

#### Migration Checklist

- [ ] Cron job removed/commented
- [ ] Service file copied and paths updated
- [ ] User/group set correctly in service file
- [ ] Daemon enabled and started
- [ ] Service status shows "active (running)"
- [ ] Logs show successful initialization
- [ ] Data is being processed (check database)
- [ ] No errors in logs

#### Common Issues

**Service Fails to Start:**
```bash
# Check service status
sudo systemctl status osm-notes-api-daemon

# Check logs for errors
sudo journalctl -u osm-notes-api-daemon -n 100

# Common causes:
# - Wrong path in ExecStart
# - Wrong user/group
# - Database not accessible
# - Missing properties.sh
```

**Daemon Exits Immediately:**
```bash
# Check if lock file exists (another instance running)
ls -la /tmp/processAPINotesDaemon.lock

# Check logs
sudo journalctl -u osm-notes-api-daemon -n 50

# Verify database connection
psql -d "${DBNAME}" -c "SELECT 1;"
```

**No Data Processing:**
```bash
# Check if daemon is checking API
sudo journalctl -u osm-notes-api-daemon | grep -i "check\|api\|notes"

# Verify API is accessible
wget -q -O /tmp/test.xml "https://api.openstreetmap.org/api/0.6/notes/search.xml?limit=1"

# Check last timestamp
psql -d "${DBNAME}" -c "SELECT * FROM max_note_timestamp;"
```

#### Rollback (If Needed)

If you need to go back to cron:

```bash
# Stop and disable daemon
sudo systemctl stop osm-notes-api-daemon
sudo systemctl disable osm-notes-api-daemon

# Remove service file
sudo rm /etc/systemd/system/osm-notes-api-daemon.service
sudo systemctl daemon-reload

# Restore cron
crontab -e
# Add: */15 * * * * /path/to/OSM-Notes-Ingestion/bin/process/processAPINotes.sh >/dev/null 2>&1
```

### Testing

Run daemon-specific tests:

```bash
# Run all daemon tests
./tests/run_processAPINotesDaemon_tests.sh

# Or run specific test suites
bats tests/unit/bash/processAPINotesDaemon_sleep_logic.test.bats
bats tests/unit/bash/processAPINotesDaemon_integration.test.bats
```

### Logging

#### With systemd (Recommended)

When running with systemd, logs are integrated with `journalctl`:

```bash
# View logs in real-time
sudo journalctl -u osm-notes-api-daemon -f

# View last 100 lines
sudo journalctl -u osm-notes-api-daemon -n 100

# View logs since today
sudo journalctl -u osm-notes-api-daemon --since today

# Filter by log level
sudo journalctl -u osm-notes-api-daemon -p err
```

**Log location:** Systemd journal (not files)

#### Manual Execution

When running manually (not recommended for production), logs are written to:

```
/tmp/processAPINotesDaemon_XXXXXX/processAPINotesDaemon.log
```

Where `XXXXXX` is a random suffix. The directory persists for the daemon's lifetime.

**View logs:**
```bash
# Find latest log directory
LATEST_DIR=$(ls -1rtd /tmp/processAPINotesDaemon_* | tail -1)

# View logs
tail -f "${LATEST_DIR}/processAPINotesDaemon.log"

# Or use the one-liner from script header
tail -40f $(ls -1rtd /tmp/processAPINotesDaemon_* | tail -1)/processAPINotesDaemon.log
```

**Log rotation:** Logs accumulate in the same file while daemon runs. For long-running daemons, consider log rotation or use systemd.

### Troubleshooting

#### Daemon Not Starting

```bash
# Check service status
sudo systemctl status osm-notes-api-daemon

# Check logs
sudo journalctl -u osm-notes-api-daemon -n 100

# Verify lock file
ls -la /tmp/processAPINotesDaemon.lock
```

#### Daemon Stops Unexpectedly

The daemon exits after 5 consecutive errors. Check logs:

```bash
sudo journalctl -u osm-notes-api-daemon | grep -i error
```

#### Graceful Shutdown

```bash
# Stop daemon gracefully
sudo systemctl stop osm-notes-api-daemon

# Or send shutdown signal
touch /tmp/processAPINotesDaemon_shutdown
```

### Files Reference

**Essential Files:**
- `bin/process/processAPINotesDaemon.sh` - Main daemon script
- `examples/systemd/osm-notes-api-daemon.service` - systemd service file

**Dependencies** (already in repository):
- Same as `processAPINotes.sh`: `etc/properties.sh`, `lib/osm-common/`, SQL scripts, etc.

### Technical Details

- **Singleton Pattern**: Uses `flock` for atomic lock file management
- **Signal Handling**: SIGTERM/SIGINT (graceful shutdown), SIGHUP (reload config), SIGUSR1 (status)
- **Error Recovery**: Automatic retries with consecutive error limit (5)
- **Year Change**: Handles correctly (partitions are by `part_id`, not date)
- **Resource Management**: Automatic cleanup via `trap` handlers

## Related Documentation

- **System Overview**: See [Documentation.md](./Documentation.md) for general architecture
- **Planet Processing**: See [Process_Planet.md](./Process_Planet.md) for Planet data processing details
- **Project Background**: See [Rationale.md](./Rationale.md) for project motivation and goals

