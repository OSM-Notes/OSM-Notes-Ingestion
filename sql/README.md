# SQL Directory

## Overview

The `sql` directory contains all database-related scripts, including table
creation, data loading, and maintenance operations. This directory is essential
for setting up and maintaining the PostgreSQL database that stores OSM notes data.

## Directory Structure

### `/sql/process/`

Scripts for processing and loading data, organized by processing type:

#### Planet Notes Processing (`processPlanetNotes_*.sql`)

**Base Table Creation** (Sequence: 21-23):

- **`processPlanetNotes_21_createBaseTables_enum.sql`**: Creates ENUM types
  - Defines: `note_status_enum`, `note_action_enum`
  - Usage: Called first during base table creation

- **`processPlanetNotes_22_createBaseTables_tables.sql`**: Creates main tables
  - Creates: `notes`, `note_comments`, `note_comments_text` tables
  - Includes: Primary keys, indexes, constraints
  - Usage: Called after enum creation

- **`processPlanetNotes_23_createBaseTables_constraints.sql`**: Adds constraints
  - Adds: Foreign keys, check constraints, unique constraints
  - Usage: Called after table creation

**Table Management** (Sequence: 11-13):

- **`processPlanetNotes_11_dropSyncTables.sql`**: Drops sync tables
  - Purpose: Cleanup before base mode
  - Usage: Called at start of `--base` mode

- **`processPlanetNotes_11_dropAllPartitions.sql`**: Drops all partition tables
  - Purpose: Cleanup partitions before recreation
  - Usage: Called during partition management

- **`processPlanetNotes_13_dropBaseTables.sql`**: Drops base tables
  - Purpose: Full cleanup for base mode
  - Usage: Called at start of `--base` mode

**Sync Tables** (Sequence: 24):
- **`processPlanetNotes_24_createSyncTables.sql`**: Creates sync tables
  - Creates: `notes_sync`, `note_comments_sync`, `note_comments_text_sync`
  - Purpose: Intermediate tables for Planet data before consolidation
  - Usage: Called during Planet processing

**Partition Management** (Sequence: 25):

- **`processPlanetNotes_25_createPartitions.sql`**: Creates partition tables
  - Purpose: Creates partition tables for parallel processing
  - Creates: `notes_sync_part_0` through `notes_sync_part_N` (N = MAX_THREADS)
  - Usage: Called before parallel CSV loading

**Country Tables** (Sequence: 25-28):

- **`processPlanetNotes_25_createCountryTables.sql`**: Creates country tables
  - Creates: `countries`, `maritimes` tables
  - Usage: Called during initial setup

- **`processPlanetNotes_26_optimizeCountryIndexes.sql`**: Optimizes country indexes
  - Purpose: Creates spatial indexes for efficient country queries
  - Usage: Called after country table creation

- **`processPlanetNotes_27_createInternationalWatersTable.sql`**: Creates international waters table
  - Purpose: Handles notes in international waters
  - Usage: Called during setup

- **`processPlanetNotes_28_addInternationalWatersExamples.sql`**: Adds examples
  - Purpose: Populates international waters examples
  - Usage: Called after table creation

**Data Loading** (Sequence: 41-45):

- **`processPlanetNotes_41_loadPartitionedSyncNotes.sql`**: Loads partitioned notes
  - Purpose: Bulk loads CSV data into partition tables using COPY
  - Usage: Called for each partition during parallel processing
  - Performance: Critical for Planet processing speed

- **`processPlanetNotes_42_consolidatePartitions.sql`**: Consolidates partitions
  - Purpose: Merges partition tables into sync tables
  - Usage: Called after all partitions are loaded
  - Performance: Massive INSERT operation

- **`processPlanetNotes_43_commentsSequence.sql`**: Creates comment sequences
  - Purpose: Sets up sequences for comment IDs
  - Usage: Called before comment loading

- **`processPlanetNotes_43_moveSyncToMain.sql`**: Moves sync to main tables
  - Purpose: Consolidates sync tables into main tables
  - Usage: Called after sync tables are populated

- **`processPlanetNotes_43_removeDuplicates.sql`**: Removes duplicates
  - Purpose: Cleans up duplicate notes/comments
  - Usage: Called after consolidation

- **`processPlanetNotes_44_loadTextComments.sql`**: Loads text comments
  - Purpose: Loads note comment text data
  - Usage: Called after comments are loaded

- **`processPlanetNotes_45_objectsTextComments.sql`**: Processes text comment objects
  - Purpose: Final processing of text comments
  - Usage: Called after text comments are loaded

#### API Notes Processing (`processAPINotes_*.sql`)

**Table Management** (Sequence: 12):

- **`processAPINotes_12_dropApiTables.sql`**: Drops API tables
  - Purpose: Cleanup before recreation
  - Usage: Called at start of processing if needed

**Table Creation** (Sequence: 21-23):

- **`processAPINotes_21_createApiTables.sql`**: Creates API tables
  - Creates: `notes_api`, `note_comments_api`, `note_comments_text_api`
  - Purpose: Intermediate tables for API data before insertion
  - Usage: Called at start of API processing

- **`processAPINotes_22_createPartitions.sql`**: Creates API partition tables
  - Purpose: Creates partition tables for parallel API processing
  - Creates: `notes_api_part_0` through `notes_api_part_N`
  - Usage: Called before parallel CSV loading

- **`processAPINotes_23_createPropertiesTables.sql`**: Creates properties table
  - Creates: `properties` table for storing last processed sequence
  - Purpose: Tracks last API sequence number for incremental sync
  - Usage: Called during initial setup

**Data Loading** (Sequence: 31-35):

- **`processAPINotes_31_loadApiNotes.sql`**: Loads API notes into partitions
  - Purpose: Bulk loads CSV data into API partition tables
  - Usage: Called for each partition during parallel processing

- **`processAPINotes_32_insertNewNotesAndComments.sql`**: Inserts new notes/comments
  - Purpose: Inserts new notes and comments from API tables to main tables
  - Uses: Stored procedures `insert_note()` and `insert_note_comment()`
  - Strategy: Cursor-based batch processing for efficiency
  - Usage: Called after API tables are loaded

- **`processAPINotes_33_loadNewTextComments.sql`**: Loads new text comments
  - Purpose: Loads text comments from API to main tables
  - Usage: Called after comments are inserted

- **`processAPINotes_34_updateLastValues.sql`**: Updates last processed sequence
  - Purpose: Stores last processed API sequence number
  - Usage: Called at end of API processing

- **`processAPINotes_35_consolidatePartitions.sql`**: Consolidates API partitions
  - Purpose: Merges API partition tables into main API tables
  - Usage: Called after all partitions are loaded

> **Note:** DWH (Data Warehouse), ETL, and Analytics SQL scripts have been moved to
> [OSM-Notes-Analytics](https://github.com/OSM-Notes/OSM-Notes-Analytics).

### SQL Functions and Procedures (Root Level)

Database functions and procedures (located directly in `sql/`):

#### Country Resolution Functions

- **`functionsProcess_21_createFunctionToGetCountry.sql`**: Main function for country assignment
  - **Purpose**: Determines which country a note belongs to based on coordinates
  - **Function**: `get_country(lon, lat, note_id) RETURNS INTEGER`
  - **Strategy**: Uses 2D grid partitioning (24 zones) to minimize expensive ST_Contains calls
  - **Optimization**: Checks current country first (95% hit rate when updating boundaries)
  - **Usage**: Called by note insertion procedures and country assignment scripts
  - **Related**: `sql/functionsProcess_31_organizeAreas_2DGrid.sql` (grid setup)

- **`functionsProcess_21_createFunctionToGetCountry_stub.sql`**: Stub version for testing
  - **Purpose**: Simplified version for unit testing without full spatial logic

#### Note Processing Procedures

- **`functionsProcess_22_createProcedure_insertNote.sql`**: Insert note procedure
  - **Purpose**: Inserts a new note into the database with country assignment
  - **Procedure**: `insert_note(note_id, latitude, longitude, created_at, process_id)`
  - **Features**:
    - Validates process lock (prevents concurrent execution)
    - Automatically assigns country using `get_country()`
    - Inserts note as "opened" (status updated when closing comment is processed)
  - **Usage**: Called by `processAPINotes.sh` for incremental API synchronization

- **`functionsProcess_23_createProcedure_insertNoteComment.sql`**: Insert comment procedure
  - **Purpose**: Inserts a note comment and updates note status if closing
  - **Procedure**: `insert_note_comment(note_id, comment_id, created_at, action, user_id, user_name, text, process_id)`
  - **Features**:
    - Updates note status to "closed" if action is "closed"
    - Handles text comments separately
  - **Usage**: Called by `processAPINotes.sh` for comment synchronization

#### Country Assignment Functions

- **`functionsProcess_31_organizeAreas.sql`**: Organize areas for country assignment
  - **Purpose**: Sets up spatial organization for efficient country lookup
  - **Usage**: Called during initial setup

- **`functionsProcess_31_organizeAreas_2DGrid.sql`**: 2D grid partitioning setup
  - **Purpose**: Creates 24-zone grid system for optimized country assignment
  - **Strategy**: Divides world into zones based on longitude/latitude ranges
  - **Usage**: Called by `get_country()` function for efficient spatial queries

- **`functionsProcess_32_loadsBackupNoteLocation.sql`**: Load note location backup
  - **Purpose**: Loads note_id/id_country pairs from backup CSV for faster processing
  - **Usage**: Called by `noteProcessingFunctions.sh` to speed up country assignment
  - **Performance**: Avoids spatial queries for notes that already have country assignments

- **`functionsProcess_33_verifyNoteIntegrity.sql`**: Verify note location integrity
  - **Purpose**: Validates that note coordinates match assigned country
  - **Usage**: Called after country assignment to ensure data integrity
  - **Performance**: Critical operation that can take hours for large datasets

- **`functionsProcess_34_reassignAffectedNotes.sql`**: Reassign notes after boundary changes
  - **Purpose**: Reassigns countries for notes affected by boundary updates
  - **Usage**: Called by `updateCountries.sh` after boundary changes

- **`functionsProcess_35_assignCountryToNotesChunk.sql`**: Assign country to notes chunk
  - **Purpose**: Assigns countries to a chunk of notes (legacy version)
  - **Usage**: Used in older processing workflows

- **`functionsProcess_36_reassignAffectedNotes.sql`**: Reassign affected notes (optimized)
  - **Purpose**: Optimized version for reassigning notes after boundary changes
  - **Strategy**: Uses bounding box queries before full geometry checks
  - **Usage**: Called by `updateCountries.sh` for efficient reassignment

- **`functionsProcess_36_reassignAffectedNotes_batch.sql`**: Reassign affected notes (batch, optimized)
  - **Purpose**: Batch processing version with optimization to only update notes where country changed
  - **Strategy**: 
    - Uses bounding box queries to find potentially affected notes
    - Calls `get_country()` which checks current country first (95% hit rate)
    - **OPTIMIZATION**: Only performs UPDATE when country actually changed (reduces unnecessary writes)
  - **Performance**: Significantly faster than updating all notes, especially when most notes remain in same country
  - **Usage**: Called repeatedly by `updateCountries.sh` until all affected notes are processed

- **`functionsProcess_37_assignCountryToNotesChunk.sql`**: Assign country to notes chunk (optimized)
  - **Purpose**: Optimized version for assigning countries to note chunks
  - **Usage**: Called during Planet processing for bulk country assignment

#### Validation Functions

- **`functionsProcess_11_checkBaseTables.sql`**: Check base tables exist
  - **Purpose**: Validates that required base tables exist
  - **Usage**: Called during setup and validation

- **`functionsProcess_11_checkHistoricalData.sql`**: Check historical data
  - **Purpose**: Validates historical data integrity
  - **Usage**: Called during Planet processing validation

### `/sql/monitor/`

Monitoring and verification scripts:

- **`processCheckPlanetNotes_*.sql`**: Check tables and data integrity
  - **Purpose**: Validates Planet processing results
  - **Usage**: Called by `notesCheckVerifier.sh` for data quality checks
  - **Checks**:
    - Table existence and structure
    - Data counts and consistency
    - Country assignment completeness

- **`notesCheckVerifier-report.sql`**: Generate verification reports
  - **Purpose**: Creates detailed reports comparing Planet vs API data
  - **Usage**: Called by `notesCheckVerifier.sh` for discrepancy analysis
  - **Output**: Detailed comparison reports

**Usage Example**:

```bash
# Run verification check
psql -d osm_notes -f sql/monitor/processCheckPlanetNotes_*.sql

# Generate verification report
psql -d osm_notes -f sql/monitor/notesCheckVerifier-report.sql > report.txt
```

### `/sql/analysis/`

Performance analysis and validation scripts:

- **Integrity verification performance**: `analyze_integrity_verification_performance.sql`
  - Validates current integrity verification query performance
  - Checks index usage and query plan efficiency
  - Tests performance against thresholds (scalability)
  - Provides EXPLAIN ANALYZE and timing analysis
  - Usage: `psql -d "${DBNAME}" -f sql/analysis/analyze_integrity_verification_performance.sql`

## Software Components

### Database Schema

- **Base Tables**: Define the core structure for storing OSM notes
- **Partition Tables**: Optimize performance for large datasets
- **Indexes and Constraints**: Ensure data integrity and query performance

### Data Processing

- **Note Processing**: Scripts for loading and processing OSM notes data
- **API Integration**: Scripts for incremental API data synchronization

> **Note:** For ETL scripts, data marts, and staging procedures, see
> [OSM-Notes-Analytics](https://github.com/OSM-Notes/OSM-Notes-Analytics).

### Functions and Procedures

- **Country Resolution**: Automatically associate notes with countries
- **Data Insertion**: Optimized procedures for bulk data loading
- **Validation**: Ensure data quality and consistency

## Usage

These scripts should be executed in the correct order as defined by the processing
pipeline. Most scripts are automatically called by the bash processing scripts
in the `bin/` directory.

### Performance Analysis Scripts

The `sql/analysis/` directory contains scripts for validating and analyzing
performance optimizations:

#### `analyze_integrity_verification_performance.sql`

This script compares the performance of optimized vs original integrity verification
queries to validate that optimizations are working correctly.

**Usage:**

```bash
# Execute analysis on your database
psql -d "${DBNAME}" -f sql/analysis/analyze_integrity_verification_performance.sql

# Save results to file
psql -d "${DBNAME}" -f sql/analysis/analyze_integrity_verification_performance.sql > analysis_results.txt
```

**What it does:**

1. **TEST 1**: Analyzes current query plan (validates index usage and efficiency)
2. **TEST 2**: Performance benchmarks (validates execution time meets thresholds)
3. **TEST 3**: Index usage verification (ensures indexes are being used)
4. **TEST 4**: Index statistics (shows index sizes and usage metrics)
5. **TEST 5**: Scalability test (validates performance with larger datasets)

**Expected results:**
- Execution time: < 1ms for 5000 notes, < 10ms for 100000 notes
- Index `notes_country_note_id` should be used (Index Scan, not Seq Scan)
- Query plan should be efficient (minimal buffers, fast execution)

**When to use:**

- After implementing performance optimizations
- To validate that indexes are being used correctly
- To compare query performance before/after changes
- To troubleshoot performance issues

## Dependencies


- PostgreSQL 11+ with PostGIS extension
- Proper database permissions
- Required extensions (btree_gist, etc.)
