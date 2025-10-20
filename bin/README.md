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

### `/bin/dwh/`

Data Warehouse components:

- **`ETL.sh`**: Main ETL (Extract, Transform, Load) process
- **`profile.sh`**: Generates data profiles and statistics
- **`datamartUsers/`**: User-related data mart processing
- **`datamartCountries/`**: Country-related data mart processing

### `/bin/monitor/`

Monitoring and verification scripts:

- **`processCheckPlanetNotes.sh`**: Verifies Planet notes processing
- **`notesCheckVerifier.sh`**: Validates note data integrity

### `/bin/cleanupAll.sh`

Database maintenance script for comprehensive cleanup operations:

- **Full cleanup**: Removes all components (ETL, WMS, base tables, temporary files)
- **Partition-only cleanup**: Removes only partition tables (use `-p` or `--partitions-only` flag)

## Software Components

### Data Processing Pipeline

- **Planet Processing**: `bin/process/processPlanetNotes.sh` handles large OSM Planet files
- **API Processing**: `bin/process/processAPINotes.sh` processes real-time API data
- **ETL Pipeline**: `bin/dwh/ETL.sh` orchestrates the complete data transformation

### Data Warehouse

- **Data Marts**: `bin/dwh/datamartUsers/` and `bin/dwh/datamartCountries/`
  create specialized data views
- **Profiling**: `bin/dwh/profile.sh` generates analytics and reports

### Monitoring & Maintenance

- **Verification**: `bin/monitor/` scripts ensure data quality
- **Cleanup**: `bin/cleanupAll.sh` maintains database performance and cleanup operations

## Usage

All scripts in this directory are designed to be run from the project root and
require proper database configuration and dependencies to be installed.

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
