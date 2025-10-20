# OSM Notes Ingestion - System Documentation

**Version:** 2025-10-14

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

### 1. Geographic Data Collection

**Source:** Overpass API queries for country and maritime boundaries

**Process:**

1. Download boundary relations with specific tags
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

### 5. WMS Service Delivery

**Source:** WMS schema in database

**Process:**

1. Synchronize WMS tables with main tables via triggers
2. Apply spatial and temporal indexes
3. GeoServer renders with configured styles

**Output:** Map tiles and feature information via WMS protocol

---

## Database Schema

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

- **`bin/functionsProcess.sh`**: Shared processing functions
  - Database operations
  - Validation functions
  - Common utilities

- **`bin/parallelProcessingFunctions.sh`**: Parallel processing utilities
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

- **`bin/wms/wmsConfigExample.sh`**: Configuration examples and validation
  - Example configurations
  - Validation tools
  - Testing utilities

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
- **[Test_Execution_Sequence.md](./Test_Execution_Sequence.md)**: Sequential
  test execution
- **[Testing_Suites_Reference.md](./Testing_Suites_Reference.md)**: Test
  suites reference
- **[Testing_Workflows_Overview.md](./Testing_Workflows_Overview.md)**: Testing
  workflows

### WMS Documentation

- **[WMS_Guide.md](./WMS_Guide.md)**: WMS overview
- **[WMS_Technical.md](./WMS_Technical.md)**: WMS technical details
- **[WMS_User_Guide.md](./WMS_User_Guide.md)**: WMS user guide
- **[WMS_Administration.md](./WMS_Administration.md)**: WMS administration
- **[WMS_API_Reference.md](./WMS_API_Reference.md)**: WMS API reference
- **[WMS_Development.md](./WMS_Development.md)**: WMS development guide
- **[WMS_Deployment.md](./WMS_Deployment.md)**: WMS deployment guide
- **[WMS_Testing.md](./WMS_Testing.md)**: WMS testing guide

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

---

**Last Updated:** 2025-10-14  
**Maintainer:** Andres Gomez (AngocA)
