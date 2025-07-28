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

### `/sql/dwh/`

Data Warehouse scripts:

- **ETL processes**: `ETL_*.sql` scripts for data transformation
- **Data marts**: `datamartUsers/` and `datamartCountries/` subdirectories
- **Staging**: `Staging_*.sql` scripts for temporary data processing

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

## Software Components

### Database Schema

- **Base Tables**: Define the core structure for storing OSM notes
- **Partition Tables**: Optimize performance for large datasets
- **Indexes and Constraints**: Ensure data integrity and query performance

### Data Processing

- **ETL Scripts**: Transform raw data into structured warehouse format
- **Data Marts**: Create specialized views for analytics
- **Staging**: Handle temporary data during processing

### Functions and Procedures

- **Country Resolution**: Automatically associate notes with countries
- **Data Insertion**: Optimized procedures for bulk data loading
- **Validation**: Ensure data quality and consistency

## Usage
These scripts should be executed in the correct order as defined by the processing
pipeline. Most scripts are automatically called by the bash processing scripts
in the `bin/` directory.

## Dependencies

- PostgreSQL 11+ with PostGIS extension
- Proper database permissions
- Required extensions (btree_gist, etc.) 

