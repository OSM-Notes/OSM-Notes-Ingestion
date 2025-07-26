# OSM Notes Profile - System Documentation

## Overview

This document provides comprehensive technical documentation for the OSM-Notes-profile system, including system architecture, data flow, and implementation details.

> **Note:** For project motivation and background, see [Rationale.md](./Rationale.md).

## System Architecture

### Core Components

The OSM-Notes-profile system consists of several key components:

1. **Data Collection Layer**
   - API Integration: Real-time data from OSM API
   - Planet Processing: Historical data from OSM Planet dumps
   - Geographic Boundaries: Country and maritime boundaries via Overpass

2. **Data Processing Layer**
   - ETL Processes: Data transformation and loading
   - Parallel Processing: Partitioned data processing for large volumes
   - Data Validation: XML structure validation and data integrity checks

3. **Data Storage Layer**
   - PostgreSQL Database: Primary data storage
   - PostGIS Extension: Spatial data handling
   - Data Warehouse: Star schema for analytics
   - Data Marts: Pre-calculated analytics for users and countries

4. **Analytics Layer**
   - User Profiles: Individual contributor analytics
   - Country Profiles: Geographic community analytics
   - Hashtag Analysis: Campaign and initiative tracking
   - Application Usage: Tool adoption metrics

## Data Flow

### 1. Geographic Data Collection
- **Source**: Overpass API queries for country and maritime boundaries
- **Process**: Download boundary relations with specific tags
- **Output**: PostgreSQL geometry objects for spatial queries

### 2. Historical Data Processing
- **Source**: OSM Planet daily dumps (notes since 2013)
- **Process**: XML parsing and transformation to CSV
- **Output**: Base database with complete note history

### 3. Incremental Data Synchronization
- **Source**: OSM API (recent changes, limited to 10,000 notes)
- **Process**: Real-time synchronization every 15 minutes
- **Output**: Updated database with latest changes

### 4. Data Warehouse Population
- **Source**: Processed note data
- **Process**: ETL transformation to star schema
- **Output**: Analytics-ready data structures

### 5. Profile Generation
- **Source**: Data warehouse
- **Process**: Pre-calculated aggregations
- **Output**: User and country profiles

## Database Schema

### Core Tables
- **`notes`**: All OSM notes with geographic and temporal data
- **`note_comments`**: Comment metadata and user information
- **`note_comments_text`**: Actual comment content
- **`countries`**: Geographic boundaries for spatial analysis

### Processing Tables
- **API Tables**: Temporary storage for API data (`notes_api`, `note_comments_api`, `note_comments_text_api`)
- **Sync Tables**: Temporary storage for Planet processing (`notes_sync`, `note_comments_sync`, `note_comments_text_sync`)

### Analytics Tables
- **Fact Tables**: Time-series data for analytics
- **Dimension Tables**: Reference data for analysis
- **Data Marts**: Pre-calculated user and country metrics

## Technical Implementation

### Processing Scripts
- **`processAPINotes.sh`**: Incremental synchronization from OSM API
- **`processPlanetNotes.sh`**: Historical data processing from Planet dumps
- **`updateCountries.sh`**: Geographic boundary updates

### Data Transformation
- **XSLT Templates**: XML to CSV transformation
- **Parallel Processing**: Partitioned data processing
- **Data Validation**: Schema validation and integrity checks

### Performance Optimization
- **Partitioning**: Large table partitioning for parallel processing
- **Indexing**: Optimized database indexes for spatial and temporal queries
- **Caching**: Pre-calculated analytics in data marts

## Integration Points

### External APIs
- **OSM API**: Real-time note data
- **Overpass API**: Geographic boundary data
- **Planet Dumps**: Historical data archives

### Data Formats
- **XML**: Input format from OSM APIs and Planet dumps
- **CSV**: Intermediate format for data processing
- **PostgreSQL**: Final storage format with spatial extensions

## Monitoring and Maintenance

### System Health
- **Database Monitoring**: Connection and performance metrics
- **Processing Monitoring**: ETL job status and completion
- **Data Quality**: Validation and integrity checks

### Maintenance Tasks
- **Regular Synchronization**: 15-minute API updates
- **Daily Planet Processing**: Historical data updates
- **Weekly Boundary Updates**: Geographic data refresh
- **Monthly Analytics**: Data mart population

## Usage Guidelines

### For System Administrators
- Monitor system health and performance
- Manage database maintenance and backups
- Configure processing schedules and timeouts

### For Developers
- Understand data flow and transformation processes
- Modify processing scripts and ETL procedures
- Extend analytics and reporting capabilities

### For Data Analysts
- Query data warehouse for custom analytics
- Create new data marts for specific use cases
- Generate reports and visualizations

### For End Users
- Access user and country profiles
- View note activity and contribution metrics
- Analyze hashtag and campaign performance

## Dependencies

### Software Requirements
- **PostgreSQL**: Database server with PostGIS extension
- **Bash**: Scripting environment for processing
- **XSLT**: XML transformation tools
- **Overpass**: Geographic data API

### Data Dependencies
- **OSM API**: Real-time note data
- **Planet Dumps**: Historical data archives
- **Geographic Boundaries**: Country and maritime data

## Related Documentation

- **System Architecture**: This document provides the high-level overview
- **Processing Details**: See [processAPI.md](./processAPI.md) and [processPlanet.md](./processPlanet.md) for specific implementation details
- **Project Motivation**: See [Rationale.md](./Rationale.md) for background and goals