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

### 1. Prerequisites Verification

- Verifies that `processPlanetNotes.sh` is not running
- Checks existence of base tables
- Validates necessary SQL and XSLT files

### 2. API Table Management

- Removes existing API tables
- Creates new API tables with partitioning
- Creates properties table for tracking

### 3. Data Download

- Gets last update timestamp from database
- Builds API URL with filtering parameters
- Downloads new/modified notes from OSM API
- Validates downloaded XML structure

### 4. Processing Decision

**If downloaded notes >= MAX_NOTES (configurable)**:

- Executes complete synchronization from Planet
- Calls `processPlanetNotes.sh`

**If downloaded notes < MAX_NOTES**:

- Processes downloaded notes locally
- Uses parallel processing with partitioning

### 5. Parallel Processing

- Divides XML file into parts
- Processes each part in parallel using XSLT
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
