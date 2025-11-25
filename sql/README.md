# SQL Directory

## Overview

The `sql` directory contains all database-related scripts, including table
creation, data loading, and maintenance operations. This directory is essential
for setting up and maintaining the PostgreSQL database that stores OSM notes data.

## Directory Structure

### `/sql/process/`

Scripts for processing and loading data:

- **Base table creation**: `processPlanetNotes_21_createBaseTables_*.sql`
- **Partition management**: `processPlanetNotes_25_createPartitions.sql`
- **Data loading**: `processPlanetNotes_31_*.sql` and `processPlanetNotes_41_*.sql`
- **API processing**: `processAPINotes_*.sql` scripts

> **Note:** DWH (Data Warehouse), ETL, and Analytics SQL scripts have been moved to
> [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

### `/sql/functionsProcess/`

Database functions and procedures:

- **Country functions**: `functionsProcess_21_createFunctionToGetCountry.sql`
- **Note procedures**: `functionsProcess_22_createProcedure_insertNote.sql`
- **Comment procedures**: `functionsProcess_23_createProcedure_insertNoteComment.sql`

### `/sql/monitor/`

Monitoring and verification scripts:

- **Check tables**: `processCheckPlanetNotes_*.sql`
- **Verification reports**: `notesCheckVerifier-report.sql`

### `/sql/wms/`

Web Map Service related scripts:

- **Database preparation**: `prepareDatabase.sql`
- **Cleanup**: `removeFromDatabase.sql`

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
> [OSM-Notes-Analytics](https://github.com/OSMLatam/OSM-Notes-Analytics).

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
