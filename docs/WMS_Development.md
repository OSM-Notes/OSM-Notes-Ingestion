# WMS Development Guide

## Overview

This guide provides comprehensive information for developers working with the
WMS (Web Map Service) component of the OSM-Notes-Ingestion project. It covers
architecture, database design, GeoServer integration, and extension development.

### Target Audience

- **Backend Developers**: Working with database and server-side logic
- **Frontend Developers**: Building web applications that consume WMS
- **DevOps Engineers**: Automating deployment and configuration
- **GIS Developers**: Extending spatial functionality
- **System Integrators**: Connecting WMS with other systems

### Prerequisites

Before developing with the WMS system, ensure you have:

- **PostgreSQL with PostGIS**: Database with spatial extensions
- **GeoServer**: WMS service provider
- **Java Development Kit**: For GeoServer development
- **Bash scripting**: For automation and deployment
- **Git**: Version control for collaborative development

## Architecture Overview

### System Architecture

The WMS system follows a layered architecture pattern:

```text
┌─────────────────────────────────────────────────────────────┐
│                    Client Layer                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   JOSM      │  │  Vespucci   │  │  Web Apps   │          │
│  │             │  │             │  │             │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Service Layer                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   WMS       │  │   REST API  │  │  Security   │          │
│  │  Protocol   │  │             │  │             │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  GeoServer Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  Workspace  │  │  Datastore  │  │    Layer    │          │
│  │ Management  │  │ Management  │  │ Management  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Style     │  │   Cache     │  │  Security   │          │
│  │ Management  │  │ Management  │  │             │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Database Layer                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   WMS       │  │   Triggers  │  │  Functions  │          │
│  │  Schema     │  │             │  │             │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Indexes   │  │  Statistics │  │  Monitoring │          │
│  │             │  │             │  │             │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Data Ingestion**: Notes data flows from main tables to WMS schema
2. **Spatial Processing**: Coordinates are converted to PostGIS geometries
3. **Temporal Processing**: Years are extracted for styling and filtering
4. **Service Delivery**: GeoServer serves WMS layers with styles
5. **Client Consumption**: Applications consume WMS via standard protocol

## Database Design

### WMS Schema Design

#### Core Table Structure

```sql
-- WMS Schema
CREATE SCHEMA IF NOT EXISTS wms;
COMMENT ON SCHEMA wms IS 'Objects to publish the WMS layer';

-- Main WMS table
CREATE TABLE wms.notes_wms (
    note_id INTEGER PRIMARY KEY,
    year_created_at INTEGER,
    year_closed_at INTEGER,
    geometry GEOMETRY(POINT, 4326)
);

COMMENT ON TABLE wms.notes_wms IS
  'Locations of the notes and its opening and closing year';
COMMENT ON COLUMN wms.notes_wms.note_id IS 'OSM note id';
COMMENT ON COLUMN wms.notes_wms.year_created_at IS 'Year when the note was created';
COMMENT ON COLUMN wms.notes_wms.year_closed_at IS 'Year when the note was closed';
COMMENT ON COLUMN wms.notes_wms.geometry IS 'Location of the note';
```

#### Design Principles

1. **Separation of Concerns**: WMS data is separate from main application data
2. **Performance Optimization**: Denormalized structure for fast queries
3. **Spatial Efficiency**: PostGIS geometries for spatial operations
4. **Temporal Support**: Year-based temporal data for styling
5. **Scalability**: Indexed for large datasets

#### Index Strategy

```sql
-- Spatial index for geometry queries
CREATE INDEX notes_wms_geometry_gist ON wms.notes_wms USING GIST (geometry);

-- Temporal indexes for filtering
CREATE INDEX notes_wms_created_year ON wms.notes_wms (year_created_at);
CREATE INDEX notes_wms_closed_year ON wms.notes_wms (year_closed_at);

-- Composite index for common queries
CREATE INDEX notes_wms_temporal_spatial ON wms.notes_wms (year_created_at,
  year_closed_at) 
WHERE geometry IS NOT NULL;

-- Partial index for open notes (most common query)
CREATE INDEX notes_wms_open_notes ON wms.notes_wms (year_created_at) 
WHERE year_closed_at IS NULL;
```

### Trigger System

#### Insert Trigger

```sql
CREATE OR REPLACE FUNCTION wms.insert_new_notes()
RETURNS TRIGGER AS $$
BEGIN
    -- Only insert if coordinates are valid
    IF NEW.lon IS NOT NULL AND NEW.lat IS NOT NULL THEN
        INSERT INTO wms.notes_wms
        VALUES (
            NEW.note_id,
            EXTRACT(YEAR FROM NEW.created_at),
            EXTRACT(YEAR FROM NEW.closed_at),
            ST_SetSRID(ST_MakePoint(NEW.lon, NEW.lat), 4326)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER insert_new_notes
    AFTER INSERT ON notes
    FOR EACH ROW
    EXECUTE FUNCTION wms.insert_new_notes();
```

#### Update Trigger

```sql
CREATE OR REPLACE FUNCTION wms.update_notes()
RETURNS TRIGGER AS $$
BEGIN
    -- Update existing WMS record
    UPDATE wms.notes_wms
    SET 
        year_created_at = EXTRACT(YEAR FROM NEW.created_at),
        year_closed_at = EXTRACT(YEAR FROM NEW.closed_at),
        geometry = ST_SetSRID(ST_MakePoint(NEW.lon, NEW.lat), 4326)
    WHERE note_id = NEW.note_id;
    
    -- Insert if doesn't exist and has coordinates
    IF NOT FOUND AND NEW.lon IS NOT NULL AND NEW.lat IS NOT NULL THEN
        INSERT INTO wms.notes_wms
        VALUES (
            NEW.note_id,
            EXTRACT(YEAR FROM NEW.created_at),
            EXTRACT(YEAR FROM NEW.closed_at),
            ST_SetSRID(ST_MakePoint(NEW.lon, NEW.lat), 4326)
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_notes
    AFTER UPDATE ON notes
    FOR EACH ROW
    EXECUTE FUNCTION wms.update_notes();
```

#### Delete Trigger

```sql
CREATE OR REPLACE FUNCTION wms.delete_notes()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM wms.notes_wms WHERE note_id = OLD.note_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_notes
    AFTER DELETE ON notes
    FOR EACH ROW
    EXECUTE FUNCTION wms.delete_notes();
```

### Utility Functions

#### Data Validation

```sql
CREATE OR REPLACE FUNCTION wms.validate_coordinates(lon double precision,
  lat double precision)
RETURNS boolean AS $$
BEGIN
    RETURN lon BETWEEN -180 AND 180 AND lat BETWEEN -90 AND 90;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION wms.validate_year(year_val integer)
RETURNS boolean AS $$
BEGIN
    RETURN year_val BETWEEN 2013 AND EXTRACT(YEAR FROM CURRENT_DATE) + 1;
END;
$$ LANGUAGE plpgsql;
```

#### Data Statistics

```sql
CREATE OR REPLACE FUNCTION wms.get_notes_statistics()
RETURNS TABLE (
    total_notes bigint,
    open_notes bigint,
    closed_notes bigint,
    recent_notes bigint,
    oldest_year integer,
    newest_year integer
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_notes,
        COUNT(*) FILTER (WHERE year_closed_at IS NULL) as open_notes,
        COUNT(*) FILTER (WHERE year_closed_at IS NOT NULL) as closed_notes,
        COUNT(*) FILTER (WHERE year_created_at >= 
         EXTRACT(YEAR FROM CURRENT_DATE) - 1) as recent_notes,
        MIN(year_created_at) as oldest_year,
        MAX(year_created_at) as newest_year
    FROM wms.notes_wms;
END;
$$ LANGUAGE plpgsql;
```

#### Spatial Queries

```sql
CREATE OR REPLACE FUNCTION wms.get_notes_in_bbox(
    min_lon double precision,
    min_lat double precision,
    max_lon double precision,
    max_lat double precision
)
RETURNS TABLE (
    note_id integer,
    year_created_at integer,
    year_closed_at integer,
    lon double precision,
    lat double precision
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        nw.note_id,
        nw.year_created_at,
        nw.year_closed_at,
        ST_X(nw.geometry) as lon,
        ST_Y(nw.geometry) as lat
    FROM wms.notes_wms nw
    WHERE ST_Within(
        nw.geometry, 
        ST_MakeEnvelope(min_lon, min_lat, max_lon, max_lat, 4326)
    );
END;
$$ LANGUAGE plpgsql;
```

## GeoServer Integration

### REST API Development

#### Workspace Management

```bash
#!/bin/bash
# Create workspace via REST API

GEOSERVER_URL="http://localhost:8080/geoserver"
GEOSERVER_USER="admin"
GEOSERVER_PASSWORD="geoserver"

# Create workspace
curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -XPOST -H "Content-type: application/json" \
  -d '{"workspace":{"name":"osm_notes"}}' \
  "${GEOSERVER_URL}/rest/workspaces"

# Create namespace
curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -XPOST -H "Content-type: application/json" \
  -d '{"namespace":{"prefix":"osm_notes","uri":"http://osm-notes-profile"}}' \
  "${GEOSERVER_URL}/rest/namespaces"
```

#### Datastore Management

```bash
#!/bin/bash
# Create PostGIS datastore

DATABASE_HOST="localhost"
DATABASE_PORT="5432"
DATABASE_NAME="osm_notes"
DATABASE_USER="postgres"
DATABASE_PASSWORD="password"

# Create datastore
curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -XPOST -H "Content-type: application/json" \
  -d "{
    \"dataStore\": {
      \"name\": \"notes_wms\",
      \"type\": \"PostGIS\",
      \"enabled\": true,
      \"connectionParameters\": {
        \"entry\": [
          {\"@key\": \"host\", \"$\": \"${DATABASE_HOST}\"},
          {\"@key\": \"port\", \"$\": \"${DATABASE_PORT}\"},
          {\"@key\": \"database\", \"$\": \"${DATABASE_NAME}\"},
          {\"@key\": \"schema\", \"$\": \"wms\"},
          {\"@key\": \"user\", \"$\": \"${DATABASE_USER}\"},
          {\"@key\": \"passwd\", \"$\": \"${DATABASE_PASSWORD}\"},
          {\"@key\": \"dbtype\", \"$\": \"postgis\"},
          {\"@key\": \"validate connections\", \"$\": \"true\"}
        ]
      }
    }
  }" \
  "${GEOSERVER_URL}/rest/workspaces/osm_notes/datastores"
```

#### Layer Management

```bash
#!/bin/bash
# Create feature type (layer)

# Create feature type
curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -XPOST -H "Content-type: application/json" \
  -d "{
    \"featureType\": {
      \"name\": \"notes_wms_layer\",
      \"nativeName\": \"notes_wms\",
      \"title\": \"OSM Notes WMS Layer\",
      \"description\": \"OpenStreetMap Notes for WMS service\",
      \"enabled\": true,
      \"srs\": \"EPSG:4326\",
      \"nativeBoundingBox\": {
        \"minx\": -180,
        \"maxx\": 180,
        \"miny\": -90,
        \"maxy\": 90,
        \"crs\": \"EPSG:4326\"
      },
      \"latLon\": {
        \"minx\": -180,
        \"maxx\": 180,
        \"miny\": -90,
        \"maxy\": 90,
        \"crs\": \"EPSG:4326\"
      }
    }
  }" \
  "${GEOSERVER_URL}/rest/workspaces/osm_notes/datastores/notes_wms/featuretypes"
```

### Style Management

#### SLD Style Development

```xml
<?xml version="1.0" encoding="UTF-8"?>
<StyledLayerDescriptor version="1.0.0" 
  xmlns="http://www.opengis.net/sld" 
  xmlns:ogc="http://www.opengis.net/ogc"
  xmlns:xlink="http://www.w3.org/1999/xlink" 
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://www.opengis.net/sld http://schemas.opengis.net/sld/1.0.0/StyledLayerDescriptor.xsd">
  <NamedLayer>
    <Name>OpenNotes</Name>
    <UserStyle>
      <Title>Open Notes Style</Title>
      <FeatureTypeStyle>
        <Rule>
          <Name>Open Notes</Name>
          <ogc:Filter>
            <ogc:PropertyIsNull>
              <ogc:PropertyName>year_closed_at</ogc:PropertyName>
            </ogc:PropertyIsNull>
          </ogc:Filter>
          <PointSymbolizer>
            <Graphic>
              <Mark>
                <WellKnownName>circle</WellKnownName>
                <Fill>
                  <CssParameter name="fill">
                    <ogc:Function name="Interpolate">
                      <ogc:PropertyName>year_created_at</ogc:PropertyName>
                      <ogc:Literal>2013</ogc:Literal>
                      <ogc:Literal>#FF0000</ogc:Literal>
                      <ogc:Literal>2024</ogc:Literal>
                      <ogc:Literal>#FF6666</ogc:Literal>
                    </ogc:Function>
                  </CssParameter>
                </Fill>
                <Stroke>
                  <CssParameter name="stroke">#000000</CssParameter>
                  <CssParameter name="stroke-width">1</CssParameter>
                </Stroke>
              </Mark>
              <Size>
                <ogc:Function name="Interpolate">
                  <ogc:PropertyName>year_created_at</ogc:PropertyName>
                  <ogc:Literal>2013</ogc:Literal>
                  <ogc:Literal>8</ogc:Literal>
                  <ogc:Literal>2024</ogc:Literal>
                  <ogc:Literal>4</ogc:Literal>
                </ogc:Function>
              </Size>
            </Graphic>
          </PointSymbolizer>
        </Rule>
      </FeatureTypeStyle>
    </UserStyle>
  </NamedLayer>
</StyledLayerDescriptor>
```

#### Style Upload

```bash
#!/bin/bash
# Upload SLD style to GeoServer

STYLE_NAME="OpenNotes"
SLD_FILE="sld/OpenNotes.sld"

# Upload style
curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -XPOST -H "Content-type: application/vnd.ogc.sld+xml" \
  -d @${SLD_FILE} \
  "${GEOSERVER_URL}/rest/styles"

# Assign style to layer
curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  -XPUT -H "Content-type: application/json" \
  -d "{
    \"layer\": {
      \"defaultStyle\": {
        \"name\": \"${STYLE_NAME}\"
      }
    }
  }" \
  "${GEOSERVER_URL}/rest/layers/osm_notes:notes_wms_layer"
```

## Extension Development

### Custom Functions

#### PostgreSQL Functions

```sql
-- Custom function for note density calculation
CREATE OR REPLACE FUNCTION wms.calculate_note_density(
    bbox geometry,
    radius_meters integer DEFAULT 1000
)
RETURNS TABLE (
    center_lon double precision,
    center_lat double precision,
    note_count bigint,
    open_count bigint,
    closed_count bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ST_X(ST_Centroid(cluster)) as center_lon,
        ST_Y(ST_Centroid(cluster)) as center_lat,
        COUNT(*) as note_count,
        COUNT(*) FILTER (WHERE year_closed_at IS NULL) as open_count,
        COUNT(*) FILTER (WHERE year_closed_at IS NOT NULL) as closed_count
    FROM (
        SELECT ST_ClusterWithin(geometry, radius_meters) as cluster
        FROM wms.notes_wms
        WHERE ST_Within(geometry, bbox)
    ) clusters
    GROUP BY cluster;
END;
$$ LANGUAGE plpgsql;
```

#### GeoServer Extensions

```java
// Custom GeoServer extension for note statistics
package org.geoserver.wms.notes;

import org.geoserver.wms.WMS;
import org.geoserver.wms.WMSRequest;
import org.geoserver.wms.WMSResponse;
import org.geoserver.wms.WMSResponse.ResponseType;

public class NotesStatisticsResponse implements WMSResponse {
    
    private final WMS wms;
    
    public NotesStatisticsResponse(WMS wms) {
        this.wms = wms;
    }
    
    @Override
    public ResponseType getResponseType() {
        return ResponseType.JSON;
    }
    
    @Override
    public void write(WMSRequest request, java.io.OutputStream out) throws
      Exception {
        // Implementation for note statistics
        String stats = generateStatistics(request);
        out.write(stats.getBytes());
    }
    
    private String generateStatistics(WMSRequest request) {
        // Database query for statistics
        return "{\"total_notes\": 1000, \"open_notes\": 500}";
    }
}
```

### Custom Styles

#### Dynamic Styling

```xml
<!-- Dynamic style based on note age -->
<Rule>
  <Name>Recent Notes</Name>
  <ogc:Filter>
    <ogc:And>
      <ogc:PropertyIsNull>
        <ogc:PropertyName>year_closed_at</ogc:PropertyName>
      </ogc:PropertyIsNull>
      <ogc:PropertyIsGreaterThanOrEqualTo>
        <ogc:PropertyName>year_created_at</ogc:PropertyName>
        <ogc:Literal>2024</ogc:Literal>
      </ogc:PropertyIsGreaterThanOrEqualTo>
    </ogc:And>
  </ogc:Filter>
  <PointSymbolizer>
    <Graphic>
      <Mark>
        <WellKnownName>star</WellKnownName>
        <Fill>
          <CssParameter name="fill">#FF0000</CssParameter>
        </Fill>
      </Mark>
      <Size>12</Size>
    </Graphic>
  </PointSymbolizer>
</Rule>
```

### Custom Endpoints

#### REST API Extensions

```java
// Custom REST endpoint for note queries
@RestController
@RequestMapping("/rest/notes")
public class NotesController {
    
    @Autowired
    private NotesService notesService;
    
    @GetMapping("/statistics")
    public ResponseEntity<Map<String, Object>> getStatistics() {
        Map<String, Object> stats = notesService.getStatistics();
        return ResponseEntity.ok(stats);
    }
    
    @GetMapping("/search")
    public ResponseEntity<List<Note>> searchNotes(
            @RequestParam Double minLon,
            @RequestParam Double minLat,
            @RequestParam Double maxLon,
            @RequestParam Double maxLat) {
        
        List<Note> notes = notesService.searchByBBox(minLon, minLat, maxLon, maxLat);
        return ResponseEntity.ok(notes);
    }
}
```

## Performance Optimization

### Database Optimization

#### Query Optimization

```sql
-- Optimize spatial queries with proper indexes
CREATE INDEX CONCURRENTLY notes_wms_geometry_gist 
ON wms.notes_wms USING GIST (geometry);

-- Partition by year for large datasets
CREATE TABLE wms.notes_wms_2024 PARTITION OF wms.notes_wms
FOR VALUES FROM (2024) TO (2025);

-- Materialized view for common queries
CREATE MATERIALIZED VIEW wms.open_notes_summary AS
SELECT 
    year_created_at,
    COUNT(*) as note_count,
    ST_Extent(geometry) as bbox
FROM wms.notes_wms
WHERE year_closed_at IS NULL
GROUP BY year_created_at;

-- Refresh materialized view
REFRESH MATERIALIZED VIEW wms.open_notes_summary;
```

#### Connection Pooling

```properties
# GeoServer database connection pool configuration
dbtype=postgis
host=localhost
port=5432
database=osm_notes
schema=wms
user=postgres
passwd=password
validate connections=true
max connections=20
min connections=5
fetch size=1000
```

### GeoServer Optimization

#### Memory Configuration

```bash
# Optimize GeoServer memory settings
export GEOSERVER_OPTS="-Xms2g -Xmx4g -XX:+UseG1GC"

# For production systems
export GEOSERVER_OPTS="-Xms4g -Xmx8g -XX:+UseG1GC -XX:+UseStringDeduplication"
```

#### Tile Caching

```xml
<!-- GeoServer tile cache configuration -->
<gwcConfiguration>
  <tileCacheConfiguration>
    <diskQuota>
      <policy>LRU</policy>
      <maxSize>5GB</maxSize>
    </diskQuota>
    <expireAfterWrite>3600</expireAfterWrite>
    <expireAfterAccess>7200</expireAfterAccess>
  </tileCacheConfiguration>
</gwcConfiguration>
```

## Testing and Quality Assurance

### Unit Testing

#### Database Testing

```sql
-- Test WMS functions
DO $$
DECLARE
    result boolean;
BEGIN
    -- Test coordinate validation
    result := wms.validate_coordinates(0, 0);
    ASSERT result = true, 'Coordinate validation failed for valid coordinates';
    
    result := wms.validate_coordinates(200, 100);
    ASSERT result = false, 'Coordinate validation should fail for invalid coordinates';
    
    -- Test year validation
    result := wms.validate_year(2024);
    ASSERT result = true, 'Year validation failed for valid year';
    
    result := wms.validate_year(1800);
    ASSERT result = false, 'Year validation should fail for invalid year';
    
    RAISE NOTICE 'All tests passed';
END $$;
```

#### API Testing

```bash
#!/bin/bash
# Test WMS API endpoints

BASE_URL="http://localhost:8080/geoserver/wms"

# Test GetCapabilities
echo "Testing GetCapabilities..."
curl -s "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities" | \
  grep -q "WMS_Capabilities" && echo "✓ GetCapabilities OK" \
  || echo "✗ GetCapabilities FAILED"

# Test GetMap
echo "Testing GetMap..."
curl -s "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png" | \
  file - | grep -q "PNG" && echo "✓ GetMap OK" || echo "✗ GetMap FAILED"

# Test GetFeatureInfo
echo "Testing GetFeatureInfo..."
curl -s "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS=osm_notes:notes_wms_layer&QUERY_LAYERS=osm_notes:notes_wms_layer&INFO_FORMAT=application/json&I=128&J=128&WIDTH=256&HEIGHT=256&CRS=EPSG:4326&BBOX=-180,-90,180,90" | \
  jq -e . >/dev/null && echo "✓ GetFeatureInfo OK" || echo "✗ GetFeatureInfo FAILED"
```

### Integration Testing

#### End-to-End Testing

```python
import requests
import json
from unittest import TestCase

class WMSTestCase(TestCase):
    
    def setUp(self):
        self.base_url = "http://localhost:8080/geoserver/wms"
        self.session = requests.Session()
    
    def test_wms_capabilities(self):
        """Test WMS GetCapabilities endpoint"""
        response = self.session.get(self.base_url, params={
            'SERVICE': 'WMS',
            'VERSION': '1.3.0',
            'REQUEST': 'GetCapabilities'
        })
        
        self.assertEqual(response.status_code, 200)
        self.assertIn('WMS_Capabilities', response.text)
        self.assertIn('osm_notes:notes_wms_layer', response.text)
    
    def test_wms_getmap(self):
        """Test WMS GetMap endpoint"""
        response = self.session.get(self.base_url, params={
            'SERVICE': 'WMS',
            'VERSION': '1.3.0',
            'REQUEST': 'GetMap',
            'LAYERS': 'osm_notes:notes_wms_layer',
            'STYLES': '',
            'CRS': 'EPSG:4326',
            'BBOX': '-180,-90,180,90',
            'WIDTH': '256',
            'HEIGHT': '256',
            'FORMAT': 'image/png'
        })
        
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.headers['content-type'], 'image/png')
    
    def test_wms_getfeatureinfo(self):
        """Test WMS GetFeatureInfo endpoint"""
        response = self.session.get(self.base_url, params={
            'SERVICE': 'WMS',
            'VERSION': '1.3.0',
            'REQUEST': 'GetFeatureInfo',
            'LAYERS': 'osm_notes:notes_wms_layer',
            'QUERY_LAYERS': 'osm_notes:notes_wms_layer',
            'INFO_FORMAT': 'application/json',
            'I': '128',
            'J': '128',
            'WIDTH': '256',
            'HEIGHT': '256',
            'CRS': 'EPSG:4326',
            'BBOX': '-180,-90,180,90'
        })
        
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn('features', data)
```

### Performance Testing

#### Load Testing

```bash
#!/bin/bash
# Load test WMS service

# Install Apache Bench if not available
# sudo apt-get install apache2-utils

echo "Starting WMS load test..."

# Test GetCapabilities
echo "Testing GetCapabilities (100 requests)..."
ab -n 100 -c 10 "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities"

# Test GetMap
echo "Testing GetMap (100 requests)..."
ab -n 100 -c 10 "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png"
```

## Deployment and CI/CD

### Automated Deployment

#### Ansible Playbook

```yaml
---
- hosts: wms_servers
  become: yes
  tasks:
    - name: Install required packages
      apt:
        name: "{{ item }}"
        state: present
      loop:
        - postgresql
        - postgresql-contrib
        - postgis
        - openjdk-11-jdk
        - curl
        - wget
        - unzip

    - name: Configure PostgreSQL
      postgresql_user:
        name: wms_user
        password: "{{ wms_password }}"
        priv: "CONNECT"
        db: osm_notes
      become_user: postgres

    - name: Install GeoServer
      unarchive:
        src: https://sourceforge.net/projects/geoserver/files/GeoServer/2.24.0/geoserver-2.24.0-bin.zip
        dest: /opt/
        remote_src: yes

    - name: Configure GeoServer service
      template:
        src: geoserver.service.j2
        dest: /etc/systemd/system/geoserver.service
      notify: restart geoserver

    - name: Deploy WMS configuration
      include_tasks: deploy_wms.yml

  handlers:
    - name: restart geoserver
      systemd:
        name: geoserver
        state: restarted
        enabled: yes
```

#### Docker Deployment

```yaml
version: '3.8'
services:
  postgres:
    image: postgis/postgis:13-3.1
    environment:
      POSTGRES_DB: osm_notes
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./sql:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"

  geoserver:
    image: kartoza/geoserver:2.24.0
    environment:
      GEOSERVER_ADMIN_PASSWORD: geoserver
      GEOSERVER_ADMIN_USER: admin
    volumes:
      - geoserver_data:/opt/geoserver/data_dir
      - ./sld:/opt/geoserver/data_dir/styles
    ports:
      - "8080:8080"
    depends_on:
      - postgres

volumes:
  postgres_data:
  geoserver_data:
```

### CI/CD Pipeline

#### GitHub Actions

```yaml
name: WMS CI/CD

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgis/postgis:13-3.1
        env:
          POSTGRES_DB: osm_notes_test
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: password
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    
    - name: Install dependencies
      run: |
        pip install requests pytest
    
    - name: Run database tests
      run: |
        psql -h localhost -U postgres -d osm_notes_test -f sql/wms/prepareDatabase.sql
        # Note: Create test scripts in tests/ directory as needed
    
    - name: Run API tests
      run: |
        # Note: Create test scripts in tests/ directory as needed

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Deploy to production
      run: |
        echo "Deploying WMS to production..."
        # Add deployment steps here
```

## Best Practices

### Code Organization

#### Project Structure

```text
OSM-Notes-Ingestion/
├── bin/wms/
│   ├── wmsManager.sh          # WMS database management
│   ├── geoserverConfig.sh     # GeoServer configuration
│   ├── wmsConfigExample.sh    # Configuration examples
│   └── README.md              # WMS scripts documentation
├── sql/wms/
│   ├── prepareDatabase.sql    # WMS database setup
│   ├── removeFromDatabase.sql # WMS database cleanup
│   └── README.md              # WMS SQL documentation
├── etc/
│   ├── wms.properties.sh      # WMS configuration
│   └── properties.sh          # Main configuration
├── sld/
│   ├── OpenNotes.sld          # Open notes style
│   ├── ClosedNotes.sld        # Closed notes style
│   └── CountriesAndMaritimes.sld
├── docs/
│   ├── WMS_Guide.md           # Complete WMS guide
│   ├── WMS_Technical.md       # Technical specifications
│   ├── WMS_User_Guide.md      # User guide
│   ├── WMS_Administration.md  # Administration guide
│   ├── WMS_API_Reference.md   # API reference
│   ├── WMS_Development.md     # Development guide
│   ├── WMS_Testing.md         # Testing guide
│   └── WMS_Deployment.md      # Deployment guide
└── tests/
    └── docker/                # Docker testing environment
```

### Development Workflow

#### Git Workflow

```bash
# Feature development
git checkout -b feature/wms-enhancement
# Make changes
git add .
git commit -m "Add WMS feature enhancement"
git push origin feature/wms-enhancement

# Create pull request
# Code review
# Merge to main

# Release
git checkout main
git pull origin main
git tag -a v1.2.0 -m "Release WMS v1.2.0"
git push origin v1.2.0
```

#### Code Review Checklist

- [ ] Database schema changes reviewed
- [ ] SQL queries optimized
- [ ] GeoServer configuration tested
- [ ] API endpoints documented
- [ ] Unit tests written
- [ ] Integration tests passing
- [ ] Performance impact assessed
- [ ] Security considerations addressed

### Documentation Standards

#### Code Documentation

```sql
-- Function: wms.calculate_note_density
-- Purpose: Calculate note density within a bounding box
-- Parameters:
--   bbox: geometry - Bounding box for calculation
--   radius_meters: integer - Radius for clustering (default 1000)
-- Returns: Table with center coordinates and note counts
-- Author: Developer Name
-- Date: 2025-07-27
CREATE OR REPLACE FUNCTION wms.calculate_note_density(
    bbox geometry,
    radius_meters integer DEFAULT 1000
)
RETURNS TABLE (
    center_lon double precision,
    center_lat double precision,
    note_count bigint,
    open_count bigint,
    closed_count bigint
) AS $$
BEGIN
    -- Implementation here
END;
$$ LANGUAGE plpgsql;
```

#### API Documentation

```java
/**
 * WMS Notes Controller
 * 
 * Provides REST endpoints for WMS note operations
 * 
 * @author Developer Name
 * @version 1.0
 * @since 2025-07-27
 */
@RestController
@RequestMapping("/rest/notes")
public class NotesController {
    
    /**
     * Get note statistics
     * 
     * @return Map containing note statistics
     */
    @GetMapping("/statistics")
    public ResponseEntity<Map<String, Object>> getStatistics() {
        // Implementation
    }
}
```

## Troubleshooting

### Common Development Issues

#### Database Connection Issues

```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Test connection
psql -h localhost -U postgres -d osm_notes -c "SELECT 1;"

# Check WMS schema
psql -d osm_notes -c "SELECT COUNT(*) FROM wms.notes_wms;"
```

#### GeoServer Issues

```bash
# Check GeoServer logs
tail -f /opt/geoserver/logs/geoserver.log

# Test GeoServer REST API
curl -u admin:geoserver "http://localhost:8080/geoserver/rest/about/status"

# Check GeoServer memory
ps aux | grep geoserver
```

#### Performance Issues

```sql
-- Check slow queries
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements 
WHERE query LIKE '%wms%'
ORDER BY mean_time DESC
LIMIT 10;

-- Check table statistics
SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del
FROM pg_stat_user_tables 
WHERE schemaname = 'wms';
```

## Version Information

- **WMS Version**: 1.3.0
- **GeoServer Version**: 2.24+
- **PostGIS Version**: 3.0+
- **PostgreSQL Version**: 12+
- **Last Updated**: 2025-07-27

## Related Documentation

- **WMS Guide**: See `docs/WMS_Guide.md`
- **Technical Specifications**: See `docs/WMS_Technical.md`
- **API Reference**: See `docs/WMS_API_Reference.md`
- **Administration Guide**: See `docs/WMS_Administration.md`
- **User Guide**: See `docs/WMS_User_Guide.md`
