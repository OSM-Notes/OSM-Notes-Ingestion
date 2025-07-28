# XSLT Transformations Directory

## Overview
The `xslt` directory contains XSLT (Extensible Stylesheet Language 
Transformations) files that convert OSM notes XML data into structured formats 
for database loading and analysis. These transformations are essential for 
processing the raw XML data from OSM API and Planet files.

## Directory Structure

### `/xslt/`
XSLT transformation files:
- **`notes-API-csv.xslt`**: Converts API XML to CSV format
- **`notes-Planet-csv.xslt`**: Converts Planet XML to CSV format
- **`note_comments-API-csv.xslt`**: Converts API comments to CSV
- **`note_comments-Planet-csv.xslt`**: Converts Planet comments to CSV
- **`note_comments_text-API-csv.xslt`**: Converts API comment text to CSV
- **`note_comments_text-Planet-csv.xslt`**: Converts Planet comment text to CSV

## Software Components

### Data Transformation
- **XML to CSV**: Converts complex XML structures to flat CSV files
- **Data Extraction**: Extracts specific fields from OSM notes XML
- **Format Standardization**: Ensures consistent data format across sources
- **Data Cleaning**: Removes invalid characters and normalizes data

### Processing Pipeline
- **API Processing**: Transforms real-time API XML responses
- **Planet Processing**: Transforms large Planet file XML data
- **Comment Processing**: Handles note comments and text content
- **Bulk Processing**: Optimized for large-scale data transformation

### Output Formats
- **CSV Files**: Structured data for database loading
- **Field Mapping**: Consistent field names across different sources
- **Data Types**: Proper handling of dates, numbers, and text
- **Encoding**: UTF-8 encoding for international character support

## Usage
These XSLT files are used by the processing scripts (`bin/process/`) to transform 
raw XML data into structured formats that can be loaded into the PostgreSQL 
database. The transformations ensure data consistency and proper formatting.

## Dependencies
- XSLT processor (xsltproc, saxon, etc.)
- XML input files from OSM API or Planet
- Proper XML schema validation
- UTF-8 encoding support 
