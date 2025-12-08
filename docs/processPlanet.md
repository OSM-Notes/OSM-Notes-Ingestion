# Complete Description of processPlanetNotes.sh

> **Note:** For a general system overview, see [Documentation.md](./Documentation.md).
> For project motivation and background, see [Rationale.md](./Rationale.md).

## General Purpose

The `processPlanetNotes.sh` script is the central component of the OpenStreetMap notes processing system. Its main function is to download, process, and load into a PostgreSQL database all notes from the OSM planet, either from scratch or only new notes.

## Design Context

### Why This Design?

The Planet processing design was created to handle very large XML files (2.2GB+) efficiently while maintaining data integrity. The key design decisions include:

**AWK-Based XML Processing**:
- XML files from Planet are simple in structure and repeat elements many times
- AWK processes XML as text files without full XML parsing, which is much faster
- This approach was chosen after evaluating Saxon (Java, memory issues), xmlproc (memory leaks), and xmlstarlet (uses xmlproc)
- **Trade-off**: Risk if OSM changes XML format, but API 0.6 has been stable for ~12 years

**Split-Process-Consolidate Approach**:
- Large XML files are split into parts first, then processed in parallel with AWK
- This prevents OOM (Out of Memory) kills with large text fields
- Each part is processed independently, then results are consolidated
- Better than trying to process the entire file at once

**Sync Tables Pattern**:
- Temporary sync tables allow parallel processing without affecting base tables
- Enables validation before committing to main tables
- Provides rollback capability in case of errors
- Allows deduplication before final insertion

**Parallel Processing Strategy**:
- Divides work into more parts than threads for better load balancing
- Prevents scenarios where one thread finishes quickly while another processes heavy workload
- Example: Old notes from backup have correct positions (fast), new notes need calculation (slow)
- By dividing into more parts, threads can balance workload from a common queue

### Design Patterns Used

* **Singleton Pattern**: Ensures only one instance of `processPlanetNotes.sh` runs at a time
* **FIFO Queue Pattern**: Used for downloading boundaries via Overpass API to prevent race conditions
* **Semaphore Pattern**: Limits concurrent downloads to Overpass API, preventing rate limiting and temporary bans
* **Retry Pattern**: Implements exponential backoff for download failures and network operations
* **Resource Management Pattern**: Uses `trap` handlers for cleanup of temporary files and resources

### Alternatives Considered

* **XSLT Processing**: Initially used Saxon and xsltproc, but both had memory limitations with large files
* **Full XML Parsing**: Considered using XML parsers, but AWK text processing proved much faster and more memory-efficient
* **Sequential Processing**: Considered processing files sequentially, but parallel processing significantly reduces total time
* **Fixed Partitions**: Evaluated fixed number of partitions, but dynamic partitioning based on data volume provides better resource utilization

### Trade-offs

* **Processing Speed vs. Memory**: AWK processing is faster but requires careful file splitting to avoid memory issues
* **Validation vs. Performance**: Optional XML/CSV validations can be skipped for faster processing
* **Parallel Complexity**: Parallel processing adds complexity but provides significant performance gains
* **Sync Tables Overhead**: Temporary tables add overhead but provide safety and validation capabilities

## Input Arguments

The script accepts two types of arguments:

### 1. No argument (incremental processing)

```bash
./processPlanetNotes.sh
```

- **Purpose**: Processes only new notes from the planet file
- **Behavior**:
  - Downloads the most recent planet file
  - Compares with existing notes in the database
  - Inserts only notes that don't exist
  - Updates comments and comment texts

### 2. `--base` argument (complete processing)

```bash
./processPlanetNotes.sh --base
```

- **Purpose**: Processes all notes from scratch
- **Behavior**:
  - Removes all existing tables
  - Downloads and processes country and maritime boundaries
  - Downloads the complete planet file
  - Processes all notes from the planet
  - Creates the complete database structure

## Table Architecture

### Base Tables (Permanent)

Base tables store the complete history of all notes:

- **`notes`**: Stores all notes from the planet
  - `note_id`: Unique OSM note ID
  - `latitude/longitude`: Geographic coordinates
  - `created_at`: Creation date
  - `status`: Status (open/closed)
  - `closed_at`: Closing date (if applicable)
  - `id_country`: ID of the country where it is located

- **`note_comments`**: Comments associated with notes
  - `id`: Generated sequential ID
  - `note_id`: Reference to the note
  - `sequence_action`: Comment order
  - `event`: Action type (open, comment, close, etc.)
  - `created_at`: Comment date
  - `id_user`: OSM user ID

- **`note_comments_text`**: Comment text
  - `id`: Comment ID
  - `note_id`: Reference to the note
  - `sequence_action`: Comment order
  - `body`: Textual content of the comment

### Sync Tables (Temporary)

Sync tables are temporary and used for incremental processing:

- **`notes_sync`**: Temporary version of `notes`
- **`note_comments_sync`**: Temporary version of `note_comments`
- **`note_comments_text_sync`**: Temporary version of `note_comments_text`

**Why do sync tables exist?**

1. **Parallel Processing**: Allow processing large volumes of data in parallel
2. **Validation**: Allow verifying integrity before moving to main tables
3. **Rollback**: In case of error, it's easier to revert changes in temporary tables
4. **Deduplication**: Allow removing duplicates before final insertion

## Processing Flow

### 1. Environment Preparation

- Prerequisites verification (PostgreSQL, tools)
- Creation of temporary directories
- Logging configuration

### 2. Table Management

**For `--base`**:

- Removes all existing tables
- Creates base tables from scratch

**For incremental processing**:

- Removes sync tables
- Verifies existence of base tables
- Creates sync tables for new processing

### 3. Geographic Data Processing

- Downloads country and maritime boundaries via Overpass
  - Uses FIFO queue system to prevent race conditions
  - Implements smart waiting based on Overpass API status
  - Respects rate limits (configurable via `RATE_LIMIT`)
  - Ensures thread-safe concurrent downloads
- Processes boundary relations with specific tags
- Converts to PostgreSQL geometry objects
- Organizes areas for spatial queries

### 4. Planet File Download

- Downloads the most recent planet file
- Validates file integrity and size
- Extracts notes XML from the planet file

### 5. XML Processing

- Validates XML structure against XSD schema (optional, if SKIP_XML_VALIDATION=false)
- Transforms XML to CSV using AWK extraction
- Processes in parallel using partitioning
- Consolidates results from all partitions

### 6. Data Loading

- Loads processed data into sync tables
- Validates data integrity and constraints
- Moves data from sync to base tables
- Removes duplicates and ensures consistency

### 7. Country Association

- Associates each note with its corresponding country
- Uses spatial queries to determine note location
- Updates country information in notes table

### 8. Cleanup and Optimization

- Removes temporary files and sync tables
- Optimizes database indexes
- Updates statistics for query optimization
- Logs processing results and statistics

## Parallel Processing

### Partitioning Strategy

- Divides large XML files into manageable parts
- Processes each partition in parallel
- Uses multiple threads for concurrent processing
- Consolidates results from all partitions

### Performance Optimization

- **Memory Management**: Efficient handling of large XML files
- **Database Optimization**: Optimized queries and indexes
- **Disk I/O**: Minimizes disk operations through buffering
- **Network**: Efficient download and processing of planet files

## Error Handling

### Common Error Scenarios

1. **Download Failures**: Retries with exponential backoff
2. **XML Parsing Errors**: Validates structure before processing
3. **Database Connection Issues**: Graceful handling of connection problems
4. **Disk Space Issues**: Checks available space before processing

### Recovery Mechanisms

- **Automatic Retry**: Implements retry logic for transient failures
- **State Preservation**: Maintains processing state for recovery
- **Error Logging**: Comprehensive error logging for debugging
- **Graceful Degradation**: Continues processing with available data

## Configuration

### Environment Variables

- **`LOG_LEVEL`**: Logging level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL)
- **`CLEAN`**: Whether to remove temporary files (true/false)
- **`MAX_THREADS`**: Number of threads for parallel processing
- **`PLANET_URL`**: URL for planet file download

### Database Configuration

- **`DBNAME`**: Database name for notes storage
- **`DB_USER`**: Database user for connections
- **`DB_PASSWORD`**: Database password for authentication
- **`DB_HOST`**: Database host address
- **`DB_PORT`**: Database port number

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
- **Network Performance**: Monitors download speeds and reliability

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

## Integration with Other Components

### API Processing Integration

- Provides base data for incremental API processing
- Ensures data consistency between Planet and API sources
- Coordinates processing to avoid conflicts

### Analytics Integration

> **Note:** ETL processes, data warehouse, and data marts are maintained in
> [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

- Provides raw data for analytics processing
- Ensures data quality and integrity for downstream systems
- Supports data export for analytics workflows

## Related Documentation

- **System Overview**: See [Documentation.md](./Documentation.md) for general architecture
- **API Processing**: See [processAPI.md](./processAPI.md) for API data processing details
- **Project Background**: See [Rationale.md](./Rationale.md) for project motivation and goals
