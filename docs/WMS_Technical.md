# WMS Technical Specifications

## Architecture

### System Components

The WMS system consists of several interconnected components:

```
┌─────────────────────────────────────────────────────────────────┐
│                    OSM-Notes-profile WMS                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐          │
│  │   OSM API   │    │   Planet    │    │  Boundaries │          │
│  │  Processing │    │ Processing  │    │  Processing │          │
│  └─────────────┘    └─────────────┘    └─────────────┘          │
│           │                │                │                   │
│           └────────────────┼────────────────┘                   │
│                            │                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │              PostgreSQL Database                        │    │
│  │  ┌─────────────┐  ┌──────────────┐  ┌─────────────┐     │    │
│  │  │   notes     │  │ note_comments│  │  countries  │     │    │
│  │  │             │  │              │  │             │     │    │
│  │  └─────────────┘  └──────────────┘  └─────────────┘     │    │
│  │           │                │                │           │    │
│  │           └────────────────┼────────────────┘           │    │
│  │                            │                            │    │
│  │  ┌─────────────────────────────────────────────┐        │    │
│  │  │              WMS Schema                     │        │    │
│  │  │  ┌─────────────┐  ┌─────────────────────┐   │        │    │
│  │  │  │ notes_wms   │  │ Triggers & Functions│   │        │    │
│  │  │  │             │  │                     │   │        │    │
│  │  │  └─────────────┘  └─────────────────────┘   │        │    │
│  │  └─────────────────────────────────────────────┘        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                            │                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    GeoServer                            │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │    │
│  │  │  Workspace  │  │  Datastore  │  │    Layer    │      │    │
│  │  │  (osm_notes)│  │ (notes_wms) │  │(notes_wms_  │      │    │
│  │  │             │  │             │  │   layer)    │      │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘      │    │
│  │           │                │                │           │    │
│  │           └────────────────┼────────────────┘           │    │
│  │                            │                            │    │
│  │  ┌─────────────────────────────────────────────┐        │    │
│  │  │              Styles                         │        │    │
│  │  │  ┌─────────────┐  ┌─────────────┐           │        │    │
│  │  │  │ OpenNotes   │  │ ClosedNotes │           │        │    │
│  │  │  │    .sld     │  │    .sld     │           │        │    │
│  │  │  └─────────────┘  └─────────────┘           │        │    │
│  │  └─────────────────────────────────────────────┘        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                            │                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    WMS Service                          │    │
│  │  ┌────────────────┐  ┌─────────────┐  ┌──────────────┐  │    │
│  │  │ GetCapabilities│  │   GetMap    │  │GetFeatureInfo│  │    │
│  │  │                │  │             │  │              │  │    │
│  │  └────────────────┘  └─────────────┘  └──────────────┘  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                            │                                    │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  Client Applications                    │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │    │
│  │  │    JOSM     │  │   Vespucci  │  │   Web Apps  │      │    │
│  │  │             │  │             │  │             │      │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘      │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Data Ingestion**
   - OSM API provides real-time note updates
   - Planet files provide historical data
   - Geographic boundaries from Overpass API

2. **Data Processing**
   - Notes are processed and stored in PostgreSQL
   - Geographic coordinates are validated
   - Temporal data is extracted (creation/closure years)

3. **WMS Synchronization**
   - Triggers automatically sync new/updated notes to WMS schema
   - Geometry is created from coordinates
   - Temporal information is preserved

4. **Service Delivery**
   - GeoServer serves WMS layers
   - Styles are applied based on note status and age
   - Clients request map tiles via WMS protocol

## Database Schema

### WMS Schema Overview

The WMS system uses a dedicated schema (`wms`) to optimize performance and maintain separation of concerns.

#### Schema Structure

```sql
-- WMS Schema
CREATE SCHEMA IF NOT EXISTS wms;
COMMENT ON SCHEMA wms IS 'Objects to publish the WMS layer';
```

### Core Tables

#### `wms.notes_wms`

The main WMS table containing optimized note data for map visualization.

```sql
CREATE TABLE wms.notes_wms (
    note_id INTEGER PRIMARY KEY,
    year_created_at INTEGER,
    year_closed_at INTEGER,
    geometry GEOMETRY(POINT, 4326)
);

COMMENT ON TABLE wms.notes_wms IS 'Locations of the notes and its opening and closing year';
COMMENT ON COLUMN wms.notes_wms.note_id IS 'OSM note id';
COMMENT ON COLUMN wms.notes_wms.year_created_at IS 'Year when the note was created';
COMMENT ON COLUMN wms.notes_wms.year_closed_at IS 'Year when the note was closed';
COMMENT ON COLUMN wms.notes_wms.geometry IS 'Location of the note';
```

#### Column Specifications

| Column | Type | Description | Constraints |
|--------|------|-------------|-------------|
| `note_id` | INTEGER | OSM note identifier | PRIMARY KEY, NOT NULL |
| `year_created_at` | INTEGER | Year when note was created | NULL for unknown |
| `year_closed_at` | INTEGER | Year when note was closed | NULL for open notes |
| `geometry` | GEOMETRY(POINT, 4326) | Geographic location | SRID 4326 (WGS84) |

### Indexes

#### Performance Indexes

```sql
-- Index for open notes (most important queries)
CREATE INDEX notes_open ON wms.notes_wms (year_created_at);
COMMENT ON INDEX notes_open IS 'Queries based on creation year';

-- Index for closed notes
CREATE INDEX notes_closed ON wms.notes_wms (year_closed_at);
COMMENT ON INDEX notes_closed IS 'Queries based on closed year';

-- Spatial index for geometry queries
CREATE INDEX notes_wms_geometry_idx ON wms.notes_wms USING GIST (geometry);
COMMENT ON INDEX notes_wms_geometry_idx IS 'Spatial index for geometry queries';
```

#### Composite Indexes

```sql
-- Composite index for temporal-spatial queries
CREATE INDEX notes_wms_temporal_spatial ON wms.notes_wms (year_created_at, year_closed_at)
WHERE geometry IS NOT NULL;

-- Index for specific year ranges
CREATE INDEX notes_wms_recent ON wms.notes_wms (year_created_at)
WHERE year_created_at >= extract(year from current_date) - 1;
```

### Triggers and Functions

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
    UPDATE wms.notes_wms
    SET year_closed_at = extract(year from NEW.closed_at)
    WHERE note_id = NEW.note_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_notes
    AFTER UPDATE ON notes
    FOR EACH ROW
    WHEN (OLD.closed_at IS DISTINCT FROM NEW.closed_at)
    EXECUTE FUNCTION wms.update_notes();
```

### Data Population

#### Initial Population

```sql
-- Populate WMS table from main notes table
INSERT INTO wms.notes_wms
SELECT 
    note_id,
    extract(year from created_at) AS year_created_at,
    extract(year from closed_at) AS year_closed_at,
    ST_SetSRID(ST_MakePoint(lon, lat), 4326) AS geometry
FROM notes
WHERE lon IS NOT NULL AND lat IS NOT NULL;
```

#### Incremental Updates

The triggers automatically handle:

- New note insertions
- Note status changes (open → closed, closed → reopened)
- Coordinate updates

## GeoServer Configuration

### Workspace Configuration

#### Workspace Details

```json
{
  "workspace": {
    "name": "osm_notes",
    "isolated": false
  }
}
```

#### Namespace Configuration

```json
{
  "namespace": {
    "prefix": "osm_notes",
    "uri": "http://osm-notes-profile",
    "isolated": false
  }
}
```

### Datastore Configuration

#### PostGIS Datastore

```json
{
  "dataStore": {
    "name": "notes_wms",
    "type": "PostGIS",
    "enabled": true,
    "connectionParameters": {
      "entry": [
        {"@key": "host", "$": "localhost"},
        {"@key": "port", "$": "5432"},
        {"@key": "database", "$": "osm_notes"},
        {"@key": "schema", "$": "wms"},
        {"@key": "user", "$": "postgres"},
        {"@key": "passwd", "$": "password"},
        {"@key": "dbtype", "$": "postgis"},
        {"@key": "validate connections", "$": "true"}
      ]
    }
  }
}
```

### Layer Configuration

#### Feature Type Details

```json
{
  "featureType": {
    "name": "notes_wms_layer",
    "nativeName": "notes_wms",
    "title": "OSM Notes WMS Layer",
    "description": "OpenStreetMap Notes for WMS service",
    "enabled": true,
    "srs": "EPSG:4326",
    "nativeBoundingBox": {
      "minx": -180,
      "maxx": 180,
      "miny": -90,
      "maxy": 90,
      "crs": "EPSG:4326"
    },
    "latLon": {
      "minx": -180,
      "maxx": 180,
      "miny": -90,
      "maxy": 90,
      "crs": "EPSG:4326"
    }
  }
}
```

### Style Configuration

#### Style Files

1. **OpenNotes.sld**
   - Purpose: Style for open notes
   - Color scheme: Red gradient (darker = older)
   - Symbol: Circle with size based on age

2. **ClosedNotes.sld**
   - Purpose: Style for closed notes
   - Color scheme: Green gradient (lighter = older)
   - Symbol: Circle with size based on age

3. **CountriesAndMaritimes.sld**
   - Purpose: Style for geographic boundaries
   - Color scheme: Blue for countries, cyan for maritime areas
   - Symbol: Polygon fill with outline

#### Style Assignment

```json
{
  "layer": {
    "defaultStyle": {
      "name": "OpenNotes"
    }
  }
}
```

## WMS Service Specification

### Service Metadata

#### GetCapabilities Response

```xml
<?xml version="1.0" encoding="UTF-8"?>
<WMS_Capabilities version="1.3.0" xmlns="http://www.opengis.net/wms">
  <Service>
    <Name>WMS</Name>
    <Title>OSM Notes WMS Service</Title>
    <Abstract>OpenStreetMap Notes for WMS service</Abstract>
    <KeywordList>
      <Keyword>osm</Keyword>
      <Keyword>notes</Keyword>
      <Keyword>openstreetmap</Keyword>
    </KeywordList>
    <OnlineResource xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href="http://localhost:8080/geoserver/wms"/>
  </Service>
  <Capability>
    <Request>
      <GetCapabilities>
        <Format>text/xml</Format>
        <DCPType>
          <HTTP>
            <Get>
              <OnlineResource xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href="http://localhost:8080/geoserver/wms?"/>
            </Get>
          </HTTP>
        </DCPType>
      </GetCapabilities>
      <GetMap>
        <Format>image/png</Format>
        <Format>image/jpeg</Format>
        <DCPType>
          <HTTP>
            <Get>
              <OnlineResource xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href="http://localhost:8080/geoserver/wms?"/>
            </Get>
          </HTTP>
        </DCPType>
      </GetMap>
    </Request>
    <Layer>
      <Title>OSM Notes WMS Service</Title>
      <Layer queryable="1">
        <Name>osm_notes:notes_wms_layer</Name>
        <Title>OSM Notes WMS Layer</Title>
        <Abstract>OpenStreetMap Notes for WMS service</Abstract>
        <SRS>EPSG:4326</SRS>
        <BoundingBox CRS="EPSG:4326" minx="-180" miny="-90" maxx="180" maxy="90"/>
      </Layer>
    </Layer>
  </Capability>
</WMS_Capabilities>
```

### Request Parameters

#### GetMap Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `SERVICE` | Yes | Service type | `WMS` |
| `VERSION` | Yes | WMS version | `1.3.0` |
| `REQUEST` | Yes | Request type | `GetMap` |
| `LAYERS` | Yes | Layer name | `osm_notes:notes_wms_layer` |
| `STYLES` | Yes | Style name | `OpenNotes` |
| `CRS` | Yes | Coordinate reference system | `EPSG:4326` |
| `BBOX` | Yes | Bounding box | `-180,-90,180,90` |
| `WIDTH` | Yes | Image width | `256` |
| `HEIGHT` | Yes | Image height | `256` |
| `FORMAT` | Yes | Image format | `image/png` |
| `TRANSPARENT` | No | Transparency | `true` |
| `BGCOLOR` | No | Background color | `0xFFFFFF` |

#### GetFeatureInfo Parameters

| Parameter | Required | Description | Example |
|-----------|----------|-------------|---------|
| `SERVICE` | Yes | Service type | `WMS` |
| `VERSION` | Yes | WMS version | `1.3.0` |
| `REQUEST` | Yes | Request type | `GetFeatureInfo` |
| `LAYERS` | Yes | Layer name | `osm_notes:notes_wms_layer` |
| `QUERY_LAYERS` | Yes | Query layer | `osm_notes:notes_wms_layer` |
| `INFO_FORMAT` | Yes | Response format | `text/html` |
| `I` | Yes | Pixel X coordinate | `128` |
| `J` | Yes | Pixel Y coordinate | `128` |
| `WIDTH` | Yes | Image width | `256` |
| `HEIGHT` | Yes | Image height | `256` |
| `CRS` | Yes | Coordinate reference system | `EPSG:4326` |
| `BBOX` | Yes | Bounding box | `-180,-90,180,90` |

### Response Formats

#### Image Formats

- **PNG**: Lossless format, supports transparency
- **JPEG**: Compressed format, no transparency
- **GIF**: Limited color support, basic transparency

#### Feature Info Formats

- **text/html**: HTML table format
- **text/plain**: Plain text format
- **application/json**: JSON format
- **application/vnd.ogc.gml**: GML format

## Performance Optimization

### Database Optimization

#### Query Optimization

```sql
-- Optimize spatial queries
CREATE INDEX CONCURRENTLY notes_wms_geometry_gist
ON wms.notes_wms USING GIST (geometry);

-- Optimize temporal queries
CREATE INDEX CONCURRENTLY notes_wms_temporal
ON wms.notes_wms (year_created_at, year_closed_at);

-- Partition by year for large datasets
CREATE TABLE wms.notes_wms_2024 PARTITION OF wms.notes_wms
FOR VALUES FROM (2024) TO (2025);
```

#### Statistics Management

```sql
-- Update table statistics
ANALYZE wms.notes_wms;

-- Update column statistics
ALTER TABLE wms.notes_wms ALTER COLUMN year_created_at SET STATISTICS 1000;
ALTER TABLE wms.notes_wms ALTER COLUMN year_closed_at SET STATISTICS 1000;
```

### GeoServer Optimization

#### Memory Configuration

```bash
# GeoServer memory settings
export GEOSERVER_OPTS="-Xms2g -Xmx4g -XX:+UseG1GC"

# JVM optimization
export GEOSERVER_OPTS="$GEOSERVER_OPTS -XX:+UseStringDeduplication"
export GEOSERVER_OPTS="$GEOSERVER_OPTS -XX:+OptimizeStringConcat"
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
  </tileCacheConfiguration>
</gwcConfiguration>
```

### Network Optimization

#### Compression

```bash
# Enable GZIP compression
# Configure in web server (Apache/Nginx)
```

#### Caching Headers

```http
# Cache control headers
Cache-Control: public, max-age=3600
ETag: "abc123"
Last-Modified: Wed, 27 Jul 2025 10:30:00 GMT
```

## Security Considerations

### Authentication

#### Basic Authentication

```bash
# Enable basic authentication
export WMS_AUTH_ENABLED="true"
export WMS_AUTH_USER="wms_user"
export WMS_AUTH_PASSWORD="secure_password"
```

#### Token-based Authentication

```xml
<!-- GeoServer security configuration -->
<security>
  <authProvider>token</authProvider>
  <tokenExpiration>3600</tokenExpiration>
</security>
```

### CORS Configuration

```bash
# Configure CORS for web applications
export WMS_CORS_ENABLED="true"
export WMS_CORS_ALLOW_ORIGIN="https://myapp.com"
export WMS_CORS_ALLOW_METHODS="GET, POST, OPTIONS"
export WMS_CORS_ALLOW_HEADERS="Content-Type, Authorization"
```

### Data Protection

#### Input Validation

```sql
-- Validate coordinates
CREATE OR REPLACE FUNCTION wms.validate_coordinates(lon double precision, lat double precision)
RETURNS boolean AS $$
BEGIN
    RETURN lon BETWEEN -180 AND 180 AND lat BETWEEN -90 AND 90;
END;
$$ LANGUAGE plpgsql;
```

#### SQL Injection Prevention

```sql
-- Use parameterized queries
-- Avoid dynamic SQL construction
-- Validate all inputs
```

## Monitoring and Metrics

### Database Metrics

#### Performance Queries

```sql
-- Query performance
SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del
FROM pg_stat_user_tables
WHERE schemaname = 'wms';

-- Index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes
WHERE schemaname = 'wms';
```

#### Space Usage

```sql
-- Table sizes
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables
WHERE schemaname = 'wms';
```

### GeoServer Metrics

#### Service Metrics

```bash
# GeoServer status
curl -s "http://localhost:8080/geoserver/rest/about/status" | jq .

# Layer statistics
curl -s "http://localhost:8080/geoserver/rest/layers/osm_notes:notes_wms_layer" | jq .
```

#### Performance Monitoring

```bash
# Memory usage
ps aux | grep geoserver

# Response times
curl -w "@curl-format.txt" -o /dev/null -s "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png"
```

## Troubleshooting

### Common Issues

#### Database Connection Issues

```bash
# Test database connection
psql -h localhost -U postgres -d osm_notes -c "SELECT 1;"

# Check WMS schema
psql -h localhost -U postgres -d osm_notes -c "SELECT COUNT(*) FROM wms.notes_wms;"
```

#### GeoServer Issues

```bash
# Check GeoServer logs
tail -f /opt/geoserver/logs/geoserver.log

# Test GeoServer REST API
curl -u admin:geoserver "http://localhost:8080/geoserver/rest/about/status"
```

#### Performance Issues

```sql
-- Check slow queries
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
WHERE query LIKE '%wms%'
ORDER BY mean_time DESC;
```

### Diagnostic Tools

#### Health Check Script

```bash
#!/bin/bash
# WMS health check

echo "=== WMS Health Check ==="

# Database connection
echo "Database connection:"
psql -h localhost -U postgres -d osm_notes -c "SELECT COUNT(*) FROM wms.notes_wms;" 2>/dev/null || echo "FAILED"

# GeoServer status
echo "GeoServer status:"
curl -s "http://localhost:8080/geoserver/rest/about/status" >/dev/null && echo "OK" || echo "FAILED"

# WMS service
echo "WMS service:"
curl -s "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities" >/dev/null && echo "OK" || echo "FAILED"
```

## Version Information

- **WMS Version**: 1.3.0
- **GeoServer Version**: 2.24+
- **PostGIS Version**: 3.0+
- **PostgreSQL Version**: 12+
- **Last Updated**: 2025-07-27

## Related Documentation

- **WMS Guide**: See `docs/WMS_Guide.md`
- **API Reference**: See `docs/WMS_API_Reference.md`
- **Administration Guide**: See `docs/WMS_Administration.md`
- **User Guide**: See `docs/WMS_User_Guide.md`
