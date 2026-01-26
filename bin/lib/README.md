# Bin Lib Directory

## Overview

The `bin/lib/` directory contains reusable function libraries used by processing scripts throughout
the OSM-Notes-Ingestion system. These libraries provide modular, well-organized functions for common
operations, following the project's naming conventions (functions start with double underscore `__`
and are lowercase).

## Directory Structure

### Core Libraries

- **`functionsProcess.sh`**: Main entry point that loads all function modules
- **`processAPIFunctions.sh`**: Functions specific to OSM API processing
- **`processPlanetFunctions.sh`**: Functions specific to Planet dump processing
- **`noteProcessingFunctions.sh`**: Functions for note location and country assignment
- **`boundaryProcessingFunctions.sh`**: Functions for geographic boundary processing
- **`overpassFunctions.sh`**: Functions for Overpass API interactions
- **`parallelProcessingFunctions.sh`**: Functions for parallel processing coordination
- **`securityFunctions.sh`**: Security and SQL sanitization functions

## Function Libraries

### `functionsProcess.sh`

**Purpose**: Main entry point that loads all function modules and provides common utilities.

**Key Functions**:

- **`__retry_file_operation()`**: Retry file operations with exponential backoff and smart waiting
  for Overpass API
  - Parameters: `operation_command`, `max_retries`, `base_delay`, `cleanup_command`, `smart_wait`,
    `explicit_endpoint`
  - Returns: `0` on success, `1` on failure
  - Usage: Used for downloading files with retry logic and Overpass rate limit handling

- **`__check_overpass_status()`**: Check Overpass API endpoint status and availability
  - Parameters: `endpoint_url`
  - Returns: `0` if available, `1` if unavailable
  - Usage: Validates Overpass endpoints before making requests

- **`__resolve_note_location_backup()`**: Resolve and download note location backup file
  - Returns: `0` on success, `1` on failure
  - Usage: Downloads backup CSV from GitHub if not found locally, used for faster country assignment

- **`__validation()`**: Validate XML and CSV files
  - Parameters: `file_path`, `validation_type` (xml/csv)
  - Returns: `0` on success, `1` on failure
  - Usage: Validates data files before processing

**Dependencies**: Loads `lib/osm-common/commonFunctions.sh`, `validationFunctions.sh`,
`errorHandlingFunctions.sh`, and project-specific libraries.

**Usage Example**:

```bash
# Source the main functions library
source bin/lib/functionsProcess.sh

# Use retry function for file download
__retry_file_operation \
  "curl -s -o ${OUTPUT_FILE} ${URL}" \
  7 \
  20 \
  "rm -f ${OUTPUT_FILE}" \
  true \
  "${OVERPASS_ENDPOINT}"
```

### `processAPIFunctions.sh`

**Purpose**: Functions specific to processing OSM API data (incremental synchronization).

**Key Functions**:

- **`__getNewNotesFromApi()`**: Download new notes from OSM API
  - Parameters: `last_value` (sequence number), `max_notes` (default: 10000)
  - Returns: Downloads XML file to `${API_NOTES_FILE}`
  - Usage: Called by `processAPINotes.sh` to fetch incremental updates

- **`__createApiTables()`**: Create API-specific database tables
  - Usage: Creates `notes_api`, `note_comments_api`, `note_comments_text_api` tables
  - Related SQL: `sql/process/processAPINotes_21_createApiTables.sql`

- **`__createPartitions()`**: Create partition tables for parallel processing
  - Parameters: `num_partitions` (based on `MAX_THREADS`)
  - Usage: Creates partition tables for parallel CSV loading

- **`__loadApiNotes()`**: Load API notes from CSV into partition tables
  - Parameters: `csv_file`, `partition_number`
  - Usage: Bulk loads CSV data into partition tables using PostgreSQL COPY

- **`__insertNewNotesAndComments()`**: Insert new notes and comments from API tables to main tables
  - Usage: Uses stored procedures and cursors for efficient insertion
  - Related SQL: `sql/process/processAPINotes_32_insertNewNotesAndComments.sql`

- **`__consolidatePartitions()`**: Consolidate partition data into main API tables
  - Usage: Merges partition tables into `notes_api`, `note_comments_api`
  - Related SQL: `sql/process/processAPINotes_35_consolidatePartitions.sql`

- **`__updateLastValue()`**: Update last processed sequence number
  - Parameters: `last_value`
  - Usage: Stores last processed API sequence for next incremental sync

**Usage Example**:

```bash
source bin/lib/processAPIFunctions.sh

# Download new notes
__getNewNotesFromApi 12345 10000

# Create tables and partitions
__createApiTables
__createPartitions 4

# Load and process
__loadApiNotes "${CSV_FILE}" 1
__insertNewNotesAndComments
__consolidatePartitions
```

### `processPlanetFunctions.sh`

**Purpose**: Functions specific to processing OSM Planet dump files (historical data).

**Key Functions**:

- **`__downloadPlanetFile()`**: Download Planet dump file
  - Parameters: `planet_url`, `output_file`
  - Usage: Downloads large Planet XML files with checksum validation

- **`__createBaseTables()`**: Create base database tables
  - Usage: Creates main `notes`, `note_comments`, `note_comments_text` tables
  - Related SQL: `sql/process/processPlanetNotes_21_createBaseTables_*.sql`

- **`__createPartitions()`**: Create partition tables for parallel processing
  - Parameters: `num_partitions`
  - Usage: Creates sync partition tables for parallel loading

- **`__loadPartitionedSyncNotes()`**: Load Planet notes into partition tables
  - Parameters: `csv_file`, `partition_number`
  - Usage: Bulk loads CSV data into sync partition tables

- **`__consolidatePartitions()`**: Consolidate partition data into sync tables
  - Usage: Merges partition tables into `notes_sync`, `note_comments_sync`
  - Related SQL: `sql/process/processPlanetNotes_42_consolidatePartitions.sql`

**Usage Example**:

```bash
source bin/lib/processPlanetFunctions.sh

# Download Planet file
__downloadPlanetFile "${PLANET_URL}" "${PLANET_FILE}"

# Create base tables
__createBaseTables

# Process in parallel
__createPartitions 8
__loadPartitionedSyncNotes "${CSV_FILE}" 1
__consolidatePartitions
```

### `noteProcessingFunctions.sh`

**Purpose**: Functions for note location processing and country assignment.

**Key Functions**:

- **`__getLocationNotes_impl()`**: Assign countries to notes using location data
  - Usage: Main function for country assignment, uses backup CSV for speed
  - Supports hybrid/test mode for faster testing
  - Related SQL: `sql/functionsProcess_32_loadsBackupNoteLocation.sql`,
    `sql/functionsProcess_37_assignCountryToNotesChunk.sql`

- **`__verifyNoteIntegrity()`**: Verify note location integrity
  - Usage: Validates that note coordinates match assigned country
  - Related SQL: `sql/functionsProcess_33_verifyNoteIntegrity.sql`

- **`__reassignAffectedNotes()`**: Reassign countries for notes affected by boundary changes
  - Usage: Called after country boundary updates
  - Related SQL: `sql/functionsProcess_36_reassignAffectedNotes.sql`

**Usage Example**:

```bash
source bin/lib/noteProcessingFunctions.sh

# Assign countries to notes
__getLocationNotes_impl

# Verify integrity
__verifyNoteIntegrity

# Reassign after boundary update
__reassignAffectedNotes
```

### `boundaryProcessingFunctions.sh`

**Purpose**: Functions for processing geographic boundaries (countries, maritimes).

**Key Functions**:

- **`__processCountries_impl()`**: Process country boundaries from Overpass API
  - Parameters: `overpass_query`, `output_file`
  - Usage: Downloads, validates, and imports country boundaries
  - Related SQL: `sql/process/updateCountries_*.sql`

- **`__processMaritimes_impl()`**: Process maritime boundaries (EEZ, Contiguous Zones)
  - Parameters: `overpass_query`, `output_file`
  - Usage: Downloads and imports maritime boundaries

- **`__validate_capital_location()`**: Validate capital city location within country boundary
  - Parameters: `country_id`, `capital_lat`, `capital_lon`
  - Usage: Ensures capital coordinates are within country geometry (prevents data
    cross-contamination)
  - Related Documentation: See
    [docs/Capital_Validation_Explanation.md](../../docs/Capital_Validation_Explanation.md) for
    detailed explanation

- **`__compareIdsWithBackup()`**: Compare boundary IDs with backup files
  - Usage: Determines which boundaries need updating vs. using backup

**Usage Example**:

```bash
source bin/lib/boundaryProcessingFunctions.sh

# Process countries
__processCountries_impl "${QUERY_FILE}" "${OUTPUT_FILE}"

# Process maritimes
__processMaritimes_impl "${QUERY_FILE}" "${OUTPUT_FILE}"

# Validate capital
__validate_capital_location 1 4.6097 -74.0817
```

### `overpassFunctions.sh`

**Purpose**: Functions for interacting with Overpass API (rate limiting, query execution).

**Key Functions**:

- **`__execute_overpass_query()`**: Execute Overpass query with rate limiting
  - Parameters: `query_file`, `output_file`, `endpoint`
  - Usage: Executes Overpass queries with FIFO queue and semaphore pattern

- **`__get_overpass_endpoint()`**: Get available Overpass endpoint
  - Returns: Endpoint URL
  - Usage: Selects best available endpoint for query execution

- **`__wait_for_overpass_slot()`**: Wait for available slot in Overpass queue
  - Usage: Implements FIFO queue system for rate limiting

**Usage Example**:

```bash
source bin/lib/overpassFunctions.sh

# Execute query with rate limiting
__execute_overpass_query "${QUERY_FILE}" "${OUTPUT_FILE}" "${ENDPOINT}"
```

### `parallelProcessingFunctions.sh`

**Purpose**: Functions for coordinating parallel processing operations, resource management, and XML
file splitting.

**Key Functions**:

- **`__check_system_resources()`**: Check available system resources (CPU, memory, disk)
  - **Parameters**: None
  - **Returns**: `0` if resources are sufficient, `1` if insufficient
  - **Usage**: Validates system can handle parallel processing before starting
  - **Checks**:
    - Available CPU cores
    - Available memory (RAM)
    - Available disk space
    - System load average
  - **Example**:
    ```bash
    if ! __check_system_resources; then
        echo "Insufficient resources for parallel processing"
        exit 1
    fi
    ```

- **`__adjust_workers_for_resources()`**: Adjust number of workers based on available resources
  - **Parameters**:
    - `requested_workers`: Desired number of workers
  - **Returns**: Adjusted worker count (may be less than requested)
  - **Usage**: Dynamically adjusts parallelism based on system capacity
  - **Logic**:
    - Checks available CPU cores
    - Checks available memory
    - Reduces workers if resources are limited
    - Default: CPU cores - 2 (leaves 2 cores for system)
  - **Example**:
    ```bash
    REQUESTED=16
    ACTUAL=$(__adjust_workers_for_resources ${REQUESTED})
    echo "Using ${ACTUAL} workers (requested ${REQUESTED})"
    ```

- **`__processXmlPartsParallel()`**: Process XML file parts in parallel using GNU Parallel
  - **Parameters**:
    - `xml_file`: Path to XML file to process
    - `num_parts`: Number of parts to split into
    - `processing_function`: Function name to call for each part
  - **Returns**: `0` on success, `1` on failure
  - **Usage**: Splits XML file and processes parts concurrently
  - **Performance**: Significantly faster than sequential processing for large files
  - **Example**:
    ```bash
    __processXmlPartsParallel \
        "${PLANET_XML}" \
        8 \
        "__processPlanetXmlPart"
    ```

- **`__splitXmlForParallelSafe()`**: Split XML file safely for parallel processing
  - **Parameters**:
    - `xml_file`: Path to XML file
    - `num_parts`: Number of parts to create
    - `output_dir`: Directory to write parts
  - **Returns**: `0` on success, `1` on failure
  - **Usage**: Splits XML at note boundaries to avoid corruption
  - **Safety**: Ensures each part is valid XML (doesn't split mid-element)
  - **Example**:
    ```bash
    mkdir -p /tmp/xml_parts
    __splitXmlForParallelSafe \
        "${XML_FILE}" \
        8 \
        "/tmp/xml_parts"
    ```

- **`__divide_xml_file()`**: Divide XML file into parts using binary division
  - **Parameters**:
    - `xml_file`: Path to XML file
    - `num_parts`: Number of parts to create
    - `output_dir`: Directory to write parts
  - **Returns**: `0` on success, `1` on failure
  - **Usage**: Binary division algorithm for efficient XML splitting
  - **Algorithm**: Uses binary search to find split points at note boundaries
  - **Performance**: Faster than linear scanning for large files
  - **Example**:
    ```bash
    __divide_xml_file \
        "${LARGE_XML_FILE}" \
        24 \
        "/tmp/parts"
    ```

- **`__wait_for_resources()`**: Wait for system resources to become available
  - **Parameters**:
    - `required_memory_mb`: Required memory in MB
    - `timeout_seconds`: Maximum time to wait
  - **Returns**: `0` if resources available, `1` if timeout
  - **Usage**: Waits for system resources before starting processing

- **`__configure_system_limits()`**: Configure system limits for parallel processing
  - **Parameters**:
    - `max_workers`: Maximum number of workers
  - **Returns**: `0` on success, `1` on failure
  - **Usage**: Sets ulimit and other system limits for optimal performance

**Usage Example**:

```bash
source bin/lib/parallelProcessingFunctions.sh

# Check if system has enough resources
if ! __check_system_resources; then
    echo "Error: Insufficient system resources"
    exit 1
fi

# Adjust workers based on available resources
REQUESTED_WORKERS=16
ACTUAL_WORKERS=$(__adjust_workers_for_resources ${REQUESTED_WORKERS})
echo "Using ${ACTUAL_WORKERS} workers"

# Configure system limits
__configure_system_limits ${ACTUAL_WORKERS}

# Split XML file safely
XML_PARTS_DIR="/tmp/xml_parts_$$"
mkdir -p "${XML_PARTS_DIR}"
__splitXmlForParallelSafe \
    "${PLANET_XML}" \
    ${ACTUAL_WORKERS} \
    "${XML_PARTS_DIR}"

# Process parts in parallel
__processXmlPartsParallel \
    "${PLANET_XML}" \
    ${ACTUAL_WORKERS} \
    "__processPlanetXmlPart"
```

**Performance Considerations**:

- **Optimal Workers**: CPU cores - 2 (leaves cores for system)
- **Memory**: Each worker needs ~500MB-2GB depending on data size
- **Disk I/O**: Parallel processing increases disk I/O; ensure fast storage
- **Network**: For API processing, consider rate limits

### `securityFunctions.sh`

**Purpose**: Security functions for SQL sanitization and input validation.

**Key Functions**:

- **`__sanitize_sql_identifier()`**: Sanitize SQL identifiers to prevent injection
  - Parameters: `identifier`
  - Returns: Sanitized identifier
  - Usage: Validates table/column names before use in SQL queries

- **`__validate_sql_identifier()`**: Validate SQL identifier format
  - Parameters: `identifier`
  - Returns: `0` if valid, `1` if invalid
  - Usage: Ensures identifiers match PostgreSQL naming rules

**Usage Example**:

```bash
source bin/lib/securityFunctions.sh

# Sanitize table name
TABLE_NAME=$(__sanitize_sql_identifier "${USER_INPUT}")

# Validate before use
if __validate_sql_identifier "${TABLE_NAME}"; then
  psql -d "${DBNAME}" -c "SELECT * FROM ${TABLE_NAME};"
fi
```

## Function Naming Conventions

All functions follow these conventions:

- **Prefix**: Double underscore `__` (e.g., `__getNewNotesFromApi`)
- **Case**: Lowercase with underscores (e.g., `__process_xml_part`)
- **Naming Pattern**: `__<action><object><qualifier>()`
  - Examples: `__getNewNotesFromApi()`, `__loadPartitionedSyncNotes()`, `__createApiTables()`

## Usage in Scripts

Functions are loaded by sourcing `functionsProcess.sh`:

```bash
#!/bin/bash

# Load all function libraries
source bin/lib/functionsProcess.sh

# Functions are now available
__getNewNotesFromApi 12345 10000
__createApiTables
```

## Dependencies

### External Libraries (Git Submodule)

Functions depend on `lib/osm-common/` (Git submodule):

- **`commonFunctions.sh`**: Core utilities (logging, error codes, prerequisites)
- **`validationFunctions.sh`**: Data validation functions
- **`errorHandlingFunctions.sh`**: Error handling and recovery patterns
- **`bash_logger.sh`**: Logging library (log4j-style)

### System Dependencies

- **PostgreSQL/PostGIS**: Database operations
- **GNU Parallel**: Parallel processing
- **AWK**: XML/CSV processing
- **curl**: File downloads and API calls
- **ogr2ogr (GDAL)**: GeoJSON processing

## Testing

Functions are tested via:

- **Unit Tests**: `tests/unit/bash/*.test.bats`
- **Integration Tests**: `tests/integration/*.test.bats`
- **Mock Scripts**: `tests/mocks/` for external dependencies

## Related Documentation

- **[bin/README.md](../README.md)**: Overview of bin directory structure
- **[docs/Documentation.md](../../docs/Documentation.md)**: Complete system documentation
- **[docs/Process_API.md](../../docs/Process_API.md)**: API processing details
- **[docs/Process_Planet.md](../../docs/Process_Planet.md)**: Planet processing details
- **[docs/Capital_Validation_Explanation.md](../../docs/Capital_Validation_Explanation.md)**:
  Capital validation to prevent data cross-contamination
- **[docs/Country_Assignment_2D_Grid.md](../../docs/Country_Assignment_2D_Grid.md)**: Country
  assignment strategy
- **[docs/ST_DWithin_Explanation.md](../../docs/ST_Dwithin_Explanation.md)**: PostGIS spatial
  functions
- **[bin/ENVIRONMENT_VARIABLES.md](../Environment_Variables.md)**: Environment variable reference

## Version

This documentation was last updated: 2025-12-08
