# WMS API Reference

## Overview

This document provides a comprehensive reference for the WMS (Web Map Service) API used in
the OSM-Notes-Ingestion project. The WMS service follows the OGC WMS 1.3.0 specification
and provides access to OSM notes as map layers.

### Base URL

```text
http://localhost:8080/geoserver/wms
```

### Service Information

- **Service Type**: WMS (Web Map Service)
- **Version**: 1.3.0
- **Provider**: GeoServer
- **Data Source**: PostgreSQL with PostGIS
- **Coordinate System**: EPSG:4326 (WGS84)

## Service Endpoints

### 1. GetCapabilities

Returns service metadata and available layers.

#### Request

```text
GET /wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities
```

#### Parameters

| Parameter | Required | Type | Description |
|-----------|----------|------|-------------|
| `SERVICE` | Yes | String | Service type (WMS) |
| `VERSION` | Yes | String | WMS version (1.3.0) |
| `REQUEST` | Yes | String | Request type (GetCapabilities) |

#### Example Request

```bash
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities"
```

#### Response

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
      <GetFeatureInfo>
        <Format>text/html</Format>
        <Format>text/plain</Format>
        <Format>application/json</Format>
        <DCPType>
          <HTTP>
            <Get>
              <OnlineResource xmlns:xlink="http://www.w3.org/1999/xlink" xlink:href="http://localhost:8080/geoserver/wms?"/>
            </Get>
          </HTTP>
        </DCPType>
      </GetFeatureInfo>
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

### 2. GetMap

Returns a map image for the specified parameters.

#### Request

```text
GET /wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png
```

#### Parameters

| Parameter | Required | Type | Description | Example |
|-----------|----------|------|-------------|---------|
| `SERVICE` | Yes | String | Service type | `WMS` |
| `VERSION` | Yes | String | WMS version | `1.3.0` |
| `REQUEST` | Yes | String | Request type | `GetMap` |
| `LAYERS` | Yes | String | Layer name | `osm_notes:notes_wms_layer` |
| `STYLES` | Yes | String | Style name | `OpenNotes` or `ClosedNotes` |
| `CRS` | Yes | String | Coordinate reference system | `EPSG:4326` |
| `BBOX` | Yes | String | Bounding box (minx,miny,maxx,maxy) | `-180,-90,180,90` |
| `WIDTH` | Yes | Integer | Image width in pixels | `256` |
| `HEIGHT` | Yes | Integer | Image height in pixels | `256` |
| `FORMAT` | Yes | String | Image format | `image/png` |
| `TRANSPARENT` | No | Boolean | Enable transparency | `true` |
| `BGCOLOR` | No | String | Background color | `0xFFFFFF` |
| `TIME` | No | String | Time parameter | `2024-01-01` |
| `ELEVATION` | No | String | Elevation parameter | `0` |

#### Example Requests

**Basic Map Request**

```bash
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png" -o map.png
```

**Transparent Background**

```bash
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png&TRANSPARENT=true" -o map_transparent.png
```

**Specific Style**

```bash
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=OpenNotes&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png" -o open_notes.png
```

**Regional View**

```bash
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-74.1,40.7,-73.9,40.8&WIDTH=512&HEIGHT=512&FORMAT=image/png" -o nyc_notes.png
```

#### Response

Returns a PNG, JPEG, or GIF image file.

### 3. GetFeatureInfo

Returns feature information for a specific pixel location.

#### Request

```text
GET /wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS=osm_notes:notes_wms_layer&QUERY_LAYERS=osm_notes:notes_wms_layer&INFO_FORMAT=text/html&I=128&J=128&WIDTH=256&HEIGHT=256&CRS=EPSG:4326&BBOX=-180,-90,180,90
```

#### Parameters

| Parameter | Required | Type | Description | Example |
|-----------|----------|------|-------------|---------|
| `SERVICE` | Yes | String | Service type | `WMS` |
| `VERSION` | Yes | String | WMS version | `1.3.0` |
| `REQUEST` | Yes | String | Request type | `GetFeatureInfo` |
| `LAYERS` | Yes | String | Layer name | `osm_notes:notes_wms_layer` |
| `QUERY_LAYERS` | Yes | String | Query layer name | `osm_notes:notes_wms_layer` |
| `INFO_FORMAT` | Yes | String | Response format | `text/html` |
| `I` | Yes | Integer | Pixel X coordinate | `128` |
| `J` | Yes | Integer | Pixel Y coordinate | `128` |
| `WIDTH` | Yes | Integer | Image width | `256` |
| `HEIGHT` | Yes | Integer | Image height | `256` |
| `CRS` | Yes | String | Coordinate reference system | `EPSG:4326` |
| `BBOX` | Yes | String | Bounding box | `-180,-90,180,90` |
| `FEATURE_COUNT` | No | Integer | Maximum features to return | `10` |
| `EXCEPTIONS` | No | String | Exception format | `XML` |

#### Info Formats

| Format | Description | Content Type |
|--------|-------------|--------------|
| `text/html` | HTML table | `text/html` |
| `text/plain` | Plain text | `text/plain` |
| `application/json` | JSON format | `application/json` |
| `application/vnd.ogc.gml` | GML format | `application/vnd.ogc.gml` |

#### Example Requests

**HTML Format**

```bash
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS=osm_notes:notes_wms_layer&QUERY_LAYERS=osm_notes:notes_wms_layer&INFO_FORMAT=text/html&I=128&J=128&WIDTH=256&HEIGHT=256&CRS=EPSG:4326&BBOX=-180,-90,180,90"
```

**JSON Format**

```bash
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS=osm_notes:notes_wms_layer&QUERY_LAYERS=osm_notes:notes_wms_layer&INFO_FORMAT=application/json&I=128&J=128&WIDTH=256&HEIGHT=256&CRS=EPSG:4326&BBOX=-180,-90,180,90" | jq .
```

#### Response Examples

**HTML Response**

```html
<html>
<head><title>GetFeatureInfo output</title></head>
<body>
<table border="1">
<tr><th>note_id</th><th>year_created_at</th><th>year_closed_at</th><th>geometry</th></tr>
<tr><td>12345</td><td>2024</td><td>null</td><td>POINT(-73.9857 40.7484)</td></tr>
<tr><td>12346</td><td>2023</td><td>2024</td><td>POINT(-73.9858 40.7485)</td></tr>
</table>
</body>
</html>
```

**JSON Response**

```json
{
  "type": "FeatureCollection",
  "features": [
    {
      "type": "Feature",
      "id": "notes_wms.12345",
      "geometry": {
        "type": "Point",
        "coordinates": [-73.9857, 40.7484]
      },
      "properties": {
        "note_id": 12345,
        "year_created_at": 2024,
        "year_closed_at": null
      }
    },
    {
      "type": "Feature",
      "id": "notes_wms.12346",
      "geometry": {
        "type": "Point",
        "coordinates": [-73.9858, 40.7485]
      },
      "properties": {
        "note_id": 12346,
        "year_created_at": 2023,
        "year_closed_at": 2024
      }
    }
  ]
}
```

## Layer Specifications

### Available Layers

#### `osm_notes:notes_wms_layer`

The main layer containing OSM notes with their geographic locations and temporal information.

**Layer Properties**

- **Name**: `osm_notes:notes_wms_layer`
- **Title**: OSM Notes WMS Layer
- **Description**: OpenStreetMap Notes for WMS service
- **SRS**: EPSG:4326
- **Bounding Box**: -180, -90, 180, 90
- **Queryable**: Yes

**Data Structure**

```sql
CREATE TABLE wms.notes_wms (
    note_id INTEGER PRIMARY KEY,
    year_created_at INTEGER,
    year_closed_at INTEGER,
    geometry GEOMETRY(POINT, 4326)
);
```

**Field Descriptions**

| Field | Type | Description |
|-------|------|-------------|
| `note_id` | INTEGER | OSM note identifier |
| `year_created_at` | INTEGER | Year when note was created |
| `year_closed_at` | INTEGER | Year when note was closed (null for open notes) |
| `geometry` | GEOMETRY | Geographic location (WGS84) |

### Layer Filtering

#### By Note Status

**Open Notes Only**

```sql
SELECT * FROM wms.notes_wms WHERE year_closed_at IS NULL
```

**Closed Notes Only**

```sql
SELECT * FROM wms.notes_wms WHERE year_closed_at IS NOT NULL
```

#### By Time Period

**Recent Notes (Last Year)**

```sql
SELECT * FROM wms.notes_wms
WHERE year_created_at >= extract(year from current_date) - 1
```

**Historical Notes (Older than 1 Year)**

```sql
SELECT * FROM wms.notes_wms
WHERE year_created_at < extract(year from current_date) - 1
```

## Style Specifications

### Available Styles

#### 1. OpenNotes

Style for open (unresolved) notes.

**Visual Characteristics**

- **Symbol**: Circle
- **Color**: Red gradient (darker = older)
- **Size**: Based on note age
- **Priority**: High visibility for recent notes

**Color Scheme**

- **Dark Red**: Recently opened notes (high priority)
- **Medium Red**: Notes open for moderate time
- **Light Red**: Notes open for extended time

#### 2. ClosedNotes

Style for closed (resolved) notes.

**Visual Characteristics**

- **Symbol**: Circle
- **Color**: Green gradient (lighter = older)
- **Size**: Based on note age
- **Priority**: Lower visibility than open notes

**Color Scheme**

- **Dark Green**: Recently closed notes
- **Medium Green**: Notes closed some time ago
- **Light Green**: Notes closed long ago

#### 3. CountriesAndMaritimes

Style for geographic boundaries.

**Visual Characteristics**

- **Symbol**: Polygon fill with outline
- **Color**: Blue for countries, cyan for maritime areas
- **Purpose**: Geographic context

### Style Usage

#### Default Style

```bash
# Use default style (OpenNotes)
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png"
```

#### Specific Style

```bash
# Use OpenNotes style
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=OpenNotes&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png"

# Use ClosedNotes style
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=ClosedNotes&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png"
```

## Coordinate Systems

### Supported CRS

| CRS | Description | Usage |
|-----|-------------|-------|
| `EPSG:4326` | WGS84 (Lat/Lon) | Default, recommended |
| `EPSG:3857` | Web Mercator | Web mapping |
| `EPSG:900913` | Google Mercator | Web mapping |

### Bounding Box Examples

#### Global View

```text
BBOX=-180,-90,180,90
```

#### Continental View (North America)

```text
BBOX=-180,15,-50,75
```

#### Regional View (New York City)

```text
BBOX=-74.1,40.7,-73.9,40.8
```

#### Local View (Manhattan)

```text
BBOX=-74.05,40.75,-73.95,40.8
```

## Image Formats

### Supported Formats

| Format | Description | Transparency | File Extension |
|--------|-------------|--------------|----------------|
| `image/png` | PNG format | Yes | `.png` |
| `image/jpeg` | JPEG format | No | `.jpg` |
| `image/gif` | GIF format | Yes | `.gif` |
| `image/tiff` | TIFF format | Yes | `.tiff` |

### Format Selection

**For Web Applications**

```bash
# PNG with transparency (recommended)
FORMAT=image/png&TRANSPARENT=true
```

**For Print/High Quality**

```bash
# TIFF format
FORMAT=image/tiff
```

**For Bandwidth Optimization**

```bash
# JPEG format (no transparency)
FORMAT=image/jpeg
```

## Error Handling

### Common Error Codes

| HTTP Code | WMS Exception | Description |
|-----------|---------------|-------------|
| 400 | `InvalidParameterValue` | Invalid parameter value |
| 400 | `MissingParameterValue` | Required parameter missing |
| 400 | `InvalidCRS` | Invalid coordinate reference system |
| 400 | `InvalidBBOX` | Invalid bounding box |
| 400 | `LayerNotDefined` | Layer does not exist |
| 400 | `StyleNotDefined` | Style does not exist |
| 500 | `NoApplicableCode` | Internal server error |
| 500 | `ServiceException` | Service-specific error |

### Error Response Format

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ServiceExceptionReport version="1.3.0" xmlns="http://www.opengis.net/ogc">
  <ServiceException code="InvalidParameterValue">
    Invalid parameter value: LAYERS
  </ServiceException>
</ServiceExceptionReport>
```

### Error Handling Examples

**Missing Required Parameter**

```bash
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer"
# Returns: MissingParameterValue for CRS
```

**Invalid Bounding Box**

```bash
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=invalid&WIDTH=256&HEIGHT=256&FORMAT=image/png"
# Returns: InvalidBBOX
```

**Non-existent Layer**

```bash
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=non_existent_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png"
# Returns: LayerNotDefined
```

## Performance Considerations

### Request Optimization

#### Image Size Guidelines

| Use Case | Width | Height | Description |
|----------|-------|--------|-------------|
| Thumbnail | 64-128 | 64-128 | Small preview |
| Standard | 256-512 | 256-512 | Normal viewing |
| High Quality | 1024-2048 | 1024-2048 | Detailed view |
| Print | 2048+ | 2048+ | High resolution |

#### Bounding Box Optimization

**Efficient Requests**

```bash
# Appropriate zoom level
BBOX=-74.1,40.7,-73.9,40.8&WIDTH=512&HEIGHT=512
```

**Inefficient Requests**

```bash
# Too large area with small image
BBOX=-180,-90,180,90&WIDTH=64&HEIGHT=64
```

### Caching

#### Client-Side Caching

```http
# Cache headers for static content
Cache-Control: public, max-age=3600
ETag: "abc123"
Last-Modified: Wed, 27 Jul 2025 10:30:00 GMT
```

#### Server-Side Caching

- GeoServer tile cache enabled
- Cache expiration: 1 hour
- Disk quota: 5GB
- Cache policy: LRU

## Security

### Authentication

#### Basic Authentication

```bash
# Include credentials in request
curl -u username:password "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities"
```

#### Token Authentication

```bash
# Include token in request
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities&token=your_token_here"
```

### CORS Configuration

```http
# CORS headers for web applications
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization
```

## Usage Examples

### Web Application Integration

#### HTML/JavaScript Example

```html
<!DOCTYPE html>
<html>
<head>
    <title>OSM Notes WMS Viewer</title>
    <script src="https://cdn.jsdelivr.net/npm/leaflet@1.7.1/dist/leaflet.js"></script>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/leaflet@1.7.1/dist/leaflet.css">
</head>
<body>
    <div id="map" style="height: 500px;"></div>
    <script>
        var map = L.map('map').setView([40.7484, -73.9857], 10);
        
        // Add WMS layer
        var wmsLayer = L.tileLayer.wms('http://localhost:8080/geoserver/wms', {
            layers: 'osm_notes:notes_wms_layer',
            format: 'image/png',
            transparent: true,
            version: '1.3.0'
        }).addTo(map);
        
        // Add base map
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors'
        }).addTo(map);
    </script>
</body>
</html>
```

#### Python Example

```python
import requests
from PIL import Image
from io import BytesIO

# Get WMS capabilities
response = requests.get('http://localhost:8080/geoserver/wms', params={
    'SERVICE': 'WMS',
    'VERSION': '1.3.0',
    'REQUEST': 'GetCapabilities'
})
print(response.text)

# Get map image
response = requests.get('http://localhost:8080/geoserver/wms', params={
    'SERVICE': 'WMS',
    'VERSION': '1.3.0',
    'REQUEST': 'GetMap',
    'LAYERS': 'osm_notes:notes_wms_layer',
    'STYLES': '',
    'CRS': 'EPSG:4326',
    'BBOX': '-74.1,40.7,-73.9,40.8',
    'WIDTH': '512',
    'HEIGHT': '512',
    'FORMAT': 'image/png',
    'TRANSPARENT': 'true'
})

# Save image
image = Image.open(BytesIO(response.content))
image.save('osm_notes_map.png')
```

#### R Example

```r
library(leaflet)
library(httr)

# Get WMS capabilities
capabilities_url <- "http://localhost:8080/geoserver/wms"
capabilities_params <- list(
  SERVICE = "WMS",
  VERSION = "1.3.0",
  REQUEST = "GetCapabilities"
)

response <- GET(capabilities_url, query = capabilities_params)
capabilities_xml <- content(response, "text")

# Create map with WMS layer
map <- leaflet() %>%
  addTiles() %>%
  addWMSTiles(
    baseUrl = "http://localhost:8080/geoserver/wms",
    layers = "osm_notes:notes_wms_layer",
    options = WMSTileOptions(
      format = "image/png",
      transparent = TRUE,
      version = "1.3.0"
    )
  )

map
```

### Command Line Examples

#### Get Service Information

```bash
# Get capabilities
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities" | xmllint --format -

# Save capabilities to file
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities" > capabilities.xml
```

#### Download Map Images

```bash
# Download global view
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=1024&HEIGHT=512&FORMAT=image/png" -o world_notes.png

# Download regional view
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-74.1,40.7,-73.9,40.8&WIDTH=512&HEIGHT=512&FORMAT=image/png" -o nyc_notes.png
```

#### Get Feature Information

```bash
# Get feature info in HTML format
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS=osm_notes:notes_wms_layer&QUERY_LAYERS=osm_notes:notes_wms_layer&INFO_FORMAT=text/html&I=256&J=256&WIDTH=512&HEIGHT=512&CRS=EPSG:4326&BBOX=-74.1,40.7,-73.9,40.8"

# Get feature info in JSON format
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS=osm_notes:notes_wms_layer&QUERY_LAYERS=osm_notes:notes_wms_layer&INFO_FORMAT=application/json&I=256&J=256&WIDTH=512&HEIGHT=512&CRS=EPSG:4326&BBOX=-74.1,40.7,-73.9,40.8" | jq .
```

## Version Information

- **WMS Version**: 1.3.0
- **GeoServer Version**: 2.24+
- **PostGIS Version**: 3.0+
- **Last Updated**: 2025-07-27

## Related Documentation

- **WMS Guide**: See `docs/WMS_Guide.md`
- **Technical Specifications**: See `docs/WMS_Technical.md`
- **Administration Guide**: See `docs/WMS_Administration.md`
- **User Guide**: See `docs/WMS_User_Guide.md`
