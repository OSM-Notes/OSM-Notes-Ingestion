# XML Schema Definitions Directory

## Overview

The `xsd` directory contains XML Schema Definition (XSD) files that define the structure and
validation rules for OSM notes XML data. These schemas ensure data integrity and provide
documentation for the expected XML formats from different OSM data sources.

## Directory Structure

### `/xsd/`

XML Schema Definition files:

- **`OSM-notes-API-schema.xsd`**: Schema for OSM API XML responses
- **`OSM-notes-planet-schema.xsd`**: Schema for Planet file XML data

## Software Components

### Data Validation

- **Schema Validation**: Ensures XML data conforms to expected structure
- **Type Checking**: Validates data types and formats
- **Constraint Enforcement**: Enforces business rules and data relationships
- **Error Detection**: Identifies malformed or invalid XML data

### Documentation

- **Data Structure**: Documents the expected XML structure
- **Field Definitions**: Describes each field and its purpose
- **Data Types**: Specifies data types and constraints
- **Relationships**: Defines relationships between XML elements

### Processing Support

- **Input Validation**: Validates incoming XML data before processing
- **Error Handling**: Provides clear error messages for invalid data
- **Development Support**: Helps developers understand data structure
- **Testing**: Supports automated testing of XML data

## Usage

These XSD files are used for:

- Validating incoming XML data from OSM API and Planet files
- Documenting the expected data structure for developers
- Supporting automated testing and quality assurance
- Ensuring data integrity throughout the processing pipeline

**Note**: XML validation is optional and can be skipped by setting `SKIP_XML_VALIDATION=true` for
faster processing. See [Rationale.md](../docs/Rationale.md) for design decisions.

## Validation Examples

### Validating OSM API XML Response

Validate XML from OSM Notes API against the API schema:

```bash
# Using xmllint (if SKIP_XML_VALIDATION=false)
xmllint --noout --schema OSM-notes-API-schema.xsd api_response.xml

# Example output on success:
# api_response.xml validates
```

### Validating Planet XML File

Validate Planet dump XML against the Planet schema:

```bash
# Using xmllint
xmllint --noout --schema OSM-notes-planet-schema.xsd planet-notes-latest.osn.xml

# For very large files (>1000 MB), validation may be skipped or use structure-only validation
# See docs/XML_Validation_Improvements.md for details
```

### Example XML Structure (OSM API)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<osm version="0.6" generator="OpenStreetMap server"
     copyright="OpenStreetMap and contributors"
     attribution="http://www.openstreetmap.org/copyright"
     license="http://opendatacommons.org/licenses/odbl/1-0/">
  <note id="12345" lat="40.7128" lon="-74.0060">
    <comment action="opened" timestamp="2025-12-07T10:00:00Z"
             uid="123" user="testuser">
      Sample note comment
    </comment>
  </note>
</osm>
```

### Validation in Processing Scripts

The processing scripts automatically validate XML when `SKIP_XML_VALIDATION=false`:

```bash
# Enable validation (default behavior)
export SKIP_XML_VALIDATION=false
./bin/process/processAPINotes.sh

# Skip validation for faster processing
export SKIP_XML_VALIDATION=true
./bin/process/processAPINotes.sh
```

### Common Validation Errors

- **Missing required attributes**: `version`, `generator`, `copyright` must be present
- **Invalid coordinate ranges**: `lat` must be -90 to 90, `lon` must be -180 to 180
- **Malformed XML structure**: Missing closing tags or invalid nesting
- **Schema version mismatch**: API version must be >= 0.6

## Dependencies

- XML Schema processor (`xmllint` from libxml2-utils)
- XML validation tools
- Proper XML namespace handling
- UTF-8 encoding support
