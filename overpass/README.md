# Overpass API Queries Directory

## Overview
The `overpass` directory contains Overpass API query files used to extract
geographic and administrative data from OpenStreetMap. These queries support the
OSM-Notes-profile system by providing country boundaries, maritime areas, and
other geographic reference data.

## Directory Structure

### `/overpass/`
Overpass API query files:
- **`countries.op`**: Query to extract country boundaries and administrative data
- **`maritimes.op`**: Query to extract maritime areas and water bodies

## Software Components

### Geographic Data Extraction
- **Country Boundaries**: Administrative boundaries for country identification
- **Maritime Areas**: Water bodies and maritime zones
- **Administrative Data**: Country codes, names, and hierarchical relationships
- **Geographic Features**: Natural and man-made geographic features

### Data Processing Support
- **Country Resolution**: Associates OSM notes with countries based on coordinates
- **Geographic Analysis**: Supports spatial analysis and reporting
- **Data Enrichment**: Adds geographic context to OSM notes
- **Boundary Validation**: Validates note locations against administrative boundaries

### Integration with OSM Notes
- **Location Services**: Provides geographic context for note locations
- **Country Assignment**: Automatically assigns notes to countries
- **Regional Analysis**: Supports regional and country-level reporting
- **Spatial Queries**: Enables location-based note filtering and analysis

## Usage
These Overpass queries are used by the processing scripts to:
- Extract country boundaries for note location analysis
- Provide geographic context for OSM notes
- Support country-based reporting and analytics
- Enable spatial analysis of note distribution

## Dependencies
- Overpass API access
- Geographic data processing tools
- Spatial analysis libraries
- Coordinate system handling (WGS84)

