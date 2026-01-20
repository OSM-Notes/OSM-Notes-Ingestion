# JSON Data Directory

## Purpose

The `json` directory contains JSON schema definitions and sample data files used for:

- **Data Validation**: Validating JSON data structures from Overpass API responses
- **Testing**: Providing test data and examples for development
- **Documentation**: Self-documenting schema definitions for OSM data structures
- **Integration**: Supporting web applications and API integrations

## Overview

The `json` directory contains JSON (JavaScript Object Notation) files that provide structured data
for the OSM-Notes-Ingestion system. These files include schema definitions, sample data, and
configuration files in JSON format.

## Directory Structure

### `/json/`

JSON files and data:

- **`geojsonschema.json`**: GeoJSON schema definition for geographic data
- **`map.geojson`**: Sample GeoJSON data for mapping applications
- **`osm-jsonschema.json`**: JSON schema for OSM data structures

## Software Components

### Schema Definitions

- **GeoJSON Schema**: Defines structure for geographic data in JSON format
- **OSM JSON Schema**: Defines structure for OpenStreetMap data
- **Data Validation**: Schema files for validating JSON data
- **Documentation**: Self-documenting schema definitions

### Geographic Data

- **GeoJSON Files**: Geographic data in JSON format
- **Map Data**: Sample mapping data for testing and development
- **Spatial Information**: Coordinate data and geographic features
- **Web Integration**: JSON data for web applications and APIs

### Data Exchange

- **API Responses**: JSON format for API data exchange
- **Configuration**: JSON-based configuration files
- **Metadata**: Structured metadata in JSON format
- **Interoperability**: Standard JSON format for data sharing

## Usage

These JSON files support:

- Web application development and testing
- API data exchange and validation
- Geographic data processing and visualization
- Configuration management and metadata storage

## Examples

### Validating JSON Data

Validate Overpass API response against the OSM JSON schema:

```bash
# Using ajv-cli (if installed)
ajv validate -s osm-jsonschema.json -d overpass_response.json

# Using Python
python3 -c "
import json
import jsonschema
with open('osm-jsonschema.json') as schema_file:
    schema = json.load(schema_file)
with open('overpass_response.json') as data_file:
    data = json.load(data_file)
jsonschema.validate(instance=data, schema=schema)
print('Valid JSON')
"
```

### Example JSON Structure (Overpass Response)

```json
{
  "version": 0.6,
  "generator": "Overpass API",
  "osm3s": {
    "timestamp_osm_base": "2025-12-07T00:00:00Z",
    "copyright": "The data included in this document is from www.openstreetmap.org"
  },
  "elements": [
    {
      "type": "relation",
      "id": 12345,
      "tags": {
        "type": "boundary",
        "boundary": "administrative",
        "admin_level": "2"
      }
    }
  ]
}
```

### Using GeoJSON for Mapping

The `map.geojson` file provides sample geographic data in GeoJSON format:

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [-74.006, 40.7128]
      },
      "properties": {
        "name": "Sample Location"
      }
    }
  ]
}
```

## Dependencies

- JSON processing libraries
- Geographic data handling tools
- Web development frameworks
- JSON schema validation tools (e.g., `ajv-cli`, `jsonschema` Python library)
