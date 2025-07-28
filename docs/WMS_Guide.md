# WMS (Web Map Service) Guide

## Overview

The WMS (Web Map Service) component of the OSM-Notes-profile project provides a map service that displays the location of open and closed OSM notes. This service allows mappers to visualize note activity geographically, helping identify areas that need attention or have been recently processed.

### What is WMS?

WMS (Web Map Service) is an OGC (Open Geospatial Consortium) standard that provides map images over the internet. In our context, it serves OSM notes as map layers that can be viewed in mapping applications like JOSM or Vespucci.

### Key Features

- **Geographic Visualization**: View notes on a map with their exact locations
- **Status Differentiation**: Distinguish between open and closed notes
- **Temporal Information**: Color coding based on note age
- **Real-time Updates**: Synchronized with the main OSM notes database
- **Standard Compliance**: OGC WMS 1.3.0 compliant service

### Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   OSM Notes     │     │   PostgreSQL     │     │    GeoServer    │
│   Database      │───▶│   WMS Schema     │───▶│   WMS Service   │
│                 │     │   (wms.notes_wms)│     │                 │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                │                       │
                                ▼                       ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   Triggers &    │    │   JOSM/Vespucci │
                       │   Functions     │    │   Applications  │
                       └─────────────────┘    └─────────────────┘
```

## Installation & Setup

### Prerequisites

Before installing WMS, ensure you have:

1. **PostgreSQL with PostGIS**
   ```bash
   # Ubuntu/Debian
   sudo apt-get install postgresql postgis
   
   # CentOS/RHEL
   sudo yum install postgresql postgis
   ```

2. **GeoServer**
   ```bash
   # Download from https://geoserver.org/download/
   # Or use Docker
   docker run -p 8080:8080 kartoza/geoserver
   ```

3. **Java Runtime Environment**
   ```bash
   # Required for GeoServer
   java -version
   ```

4. **OSM-Notes-profile Database**
   - Main database must be populated with notes data
   - API or Planet processing should be completed

### Installation Steps

#### Step 1: Install WMS Database Components

```bash
# Navigate to project directory
cd OSM-Notes-profile

# Install WMS database components
./bin/wms/wmsManager.sh install

# Verify installation
./bin/wms/wmsManager.sh status
```

#### Step 2: Configure GeoServer

```bash
# Configure GeoServer for WMS
./bin/wms/geoserverConfig.sh install

# Verify configuration
./bin/wms/geoserverConfig.sh status
```

#### Step 3: Verify Setup

```bash
# Test WMS service
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities"

# Check layer availability
curl "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png"
```

### Quick Setup (Automated)

For a complete automated setup:

```bash
# Run complete WMS setup
./bin/wms/wmsManager.sh install && \
./bin/wms/geoserverConfig.sh install

# Verify everything is working
./bin/wms/wmsManager.sh status && \
./bin/wms/geoserverConfig.sh status
```

## Configuration

### WMS Properties File

The WMS system uses a centralized configuration file: `etc/wms.properties.sh`

#### Key Configuration Sections

1. **Database Configuration**
   ```bash
   WMS_DBNAME="osm_notes"
   WMS_DBUSER="postgres"
   WMS_DBHOST="localhost"
   WMS_DBPORT="5432"
   ```

2. **GeoServer Configuration**
   ```bash
   GEOSERVER_URL="http://localhost:8080/geoserver"
   GEOSERVER_USER="admin"
   GEOSERVER_PASSWORD="geoserver"
   ```

3. **Service Configuration**
   ```bash
   WMS_SERVICE_TITLE="OSM Notes WMS Service"
   WMS_LAYER_SRS="EPSG:4326"
   WMS_BBOX_MINX="-180"
   WMS_BBOX_MAXX="180"
   ```

#### Customization Examples

**Regional Configuration (Europe)**
```bash
export WMS_BBOX_MINX="-10"
export WMS_BBOX_MAXX="40"
export WMS_BBOX_MINY="35"
export WMS_BBOX_MAXY="70"
export WMS_SERVICE_TITLE="European OSM Notes WMS Service"
```

**Custom Database**
```bash
export WMS_DBNAME="my_osm_notes"
export WMS_DBUSER="myuser"
export WMS_DBPASSWORD="mypassword"
export WMS_DBHOST="my-db-server.com"
```

**Custom GeoServer**
```bash
export GEOSERVER_URL="https://my-geoserver.com/geoserver"
export GEOSERVER_USER="admin"
export GEOSERVER_PASSWORD="secure_password"
```

### Style Configuration

The WMS service includes three main styles:

1. **OpenNotes.sld**: For open notes (darker = older)
2. **ClosedNotes.sld**: For closed notes (lighter = older)
3. **CountriesAndMaritimes.sld**: For geographic boundaries

#### Custom Styles

To use custom styles:

```bash
# Set custom style file
export WMS_STYLE_OPEN_FILE="/path/to/my/custom_open.sld"
export WMS_STYLE_CLOSED_FILE="/path/to/my/custom_closed.sld"

# Reconfigure GeoServer
./bin/wms/geoserverConfig.sh install --force
```

## Usage

### Accessing the WMS Service

#### Service URLs

- **GetCapabilities**: `http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities`
- **GetMap**: `http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png`

#### Layer Names

- **Open Notes**: `osm_notes:notes_wms_layer` (filtered for open notes)
- **Closed Notes**: `osm_notes:notes_wms_layer` (filtered for closed notes)

### Integration with Mapping Applications

#### JOSM Integration

1. **Add WMS Layer**
   - Open JOSM
   - Go to `Imagery` → `Add WMS Layer`
   - Enter WMS URL: `http://localhost:8080/geoserver/wms`
   - Select layer: `osm_notes:notes_wms_layer`

2. **Configure Layer**
   - Set transparency as needed
   - Choose appropriate style
   - Adjust zoom levels

#### Vespucci Integration

1. **Add WMS Layer**
   - Open Vespucci
   - Go to `Layer` → `Add WMS Layer`
   - Enter WMS URL: `http://localhost:8080/geoserver/wms`
   - Select layer: `osm_notes:notes_wms_layer`

### Interpreting the Map

#### Color Coding

**Open Notes:**
- **Dark Red**: Recently opened notes (high priority)
- **Medium Red**: Notes open for a few days
- **Light Red**: Notes open for weeks/months

**Closed Notes:**
- **Dark Green**: Recently closed notes
- **Medium Green**: Notes closed some time ago
- **Light Green**: Notes closed long ago

#### Spatial Patterns

- **Clusters**: Areas with many notes may indicate mapping issues
- **Sparse Areas**: Few notes might indicate well-mapped areas
- **Linear Patterns**: Notes along roads or features being mapped

### Best Practices

1. **Layer Management**
   - Use appropriate zoom levels
   - Combine with other data sources
   - Adjust transparency for better visibility

2. **Performance**
   - Cache frequently accessed areas
   - Use appropriate bounding boxes
   - Monitor service performance

3. **Data Interpretation**
   - Consider temporal patterns
   - Look for geographic clusters
   - Cross-reference with other OSM data

## Troubleshooting

### Common Issues

#### 1. WMS Service Not Accessible

**Symptoms:**
- 404 errors when accessing WMS URLs
- GeoServer not responding

**Solutions:**
```bash
# Check GeoServer status
./bin/wms/geoserverConfig.sh status

# Restart GeoServer
sudo systemctl restart geoserver

# Check logs
tail -f /opt/geoserver/logs/geoserver.log
```

#### 2. Database Connection Issues

**Symptoms:**
- WMS layers not loading
- Database connection errors

**Solutions:**
```bash
# Test database connection
./bin/wms/wmsConfigExample.sh test-connection

# Check WMS schema
psql -d osm_notes -c "SELECT COUNT(*) FROM wms.notes_wms;"

# Reinstall WMS components if needed
./bin/wms/wmsManager.sh install --force
```

#### 3. Empty or Missing Data

**Symptoms:**
- WMS layers show no data
- Empty map tiles

**Solutions:**
```bash
# Check if notes data exists
psql -d osm_notes -c "SELECT COUNT(*) FROM notes;"

# Verify WMS data population
psql -d osm_notes -c "SELECT COUNT(*) FROM wms.notes_wms;"

# Check triggers
psql -d osm_notes -c "SELECT * FROM information_schema.triggers WHERE trigger_name LIKE '%wms%';"
```

#### 4. Performance Issues

**Symptoms:**
- Slow WMS responses
- Timeout errors
- High memory usage

**Solutions:**
```bash
# Check GeoServer memory
ps aux | grep geoserver

# Optimize database
psql -d osm_notes -c "VACUUM ANALYZE wms.notes_wms;"

# Check indexes
psql -d osm_notes -c "SELECT schemaname, tablename, indexname FROM pg_indexes WHERE schemaname = 'wms';"
```

### Diagnostic Commands

#### System Health Check

```bash
# Comprehensive health check
./bin/wms/wmsConfigExample.sh validate
./bin/wms/wmsManager.sh status
./bin/wms/geoserverConfig.sh status
```

#### Performance Monitoring

```bash
# Check database performance
psql -d osm_notes -c "SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del FROM pg_stat_user_tables WHERE schemaname = 'wms';"

# Check GeoServer performance
curl -s "http://localhost:8080/geoserver/rest/about/status" | jq .
```

#### Log Analysis

```bash
# Check WMS logs
tail -f logs/wms.log

# Check GeoServer logs
tail -f /opt/geoserver/logs/geoserver.log

# Check system logs
journalctl -u geoserver -f
```

### Recovery Procedures

#### Complete WMS Reset

```bash
# Remove WMS configuration
./bin/wms/geoserverConfig.sh remove
./bin/wms/wmsManager.sh deinstall

# Reinstall from scratch
./bin/wms/wmsManager.sh install
./bin/wms/geoserverConfig.sh install
```

#### Database Recovery

```bash
# Recreate WMS schema
psql -d osm_notes -f sql/wms/prepareDatabase.sql

# Repopulate WMS data
psql -d osm_notes -c "INSERT INTO wms.notes_wms SELECT note_id, extract(year from created_at), extract(year from closed_at), ST_SetSRID(ST_MakePoint(lon, lat), 4326) FROM notes WHERE lon IS NOT NULL AND lat IS NOT NULL;"
```

## Advanced Configuration

### Custom Layer Filters

Create custom SQL views for specific note types:

```sql
-- Custom view for high-priority notes
CREATE VIEW wms.high_priority_notes AS
SELECT note_id, year_created_at, year_closed_at, geometry
FROM wms.notes_wms
WHERE year_closed_at IS NULL 
  AND year_created_at >= extract(year from current_date) - 1;
```

### Performance Optimization

#### Database Optimization

```sql
-- Add spatial index
CREATE INDEX IF NOT EXISTS notes_wms_geometry_gist ON wms.notes_wms USING GIST (geometry);

-- Add temporal index
CREATE INDEX IF NOT EXISTS notes_wms_temporal ON wms.notes_wms (year_created_at, year_closed_at);

-- Analyze table
ANALYZE wms.notes_wms;
```

#### GeoServer Optimization

```bash
# Configure GeoServer memory
export GEOSERVER_OPTS="-Xms2g -Xmx4g"

# Enable tile caching
# Configure in GeoServer admin interface
```

### Security Considerations

#### Authentication

```bash
# Enable WMS authentication
export WMS_AUTH_ENABLED="true"
export WMS_AUTH_USER="wms_user"
export WMS_AUTH_PASSWORD="secure_password"
```

#### CORS Configuration

```bash
# Configure CORS for web applications
export WMS_CORS_ENABLED="true"
export WMS_CORS_ALLOW_ORIGIN="https://myapp.com"
```

## Support and Resources

### Getting Help

1. **Check Documentation**
   - This guide
   - Technical specifications
   - API reference

2. **Community Support**
   - OSM community forums
   - GeoServer mailing lists
   - GitHub issues

3. **Logs and Debugging**
   - Enable debug logging
   - Check system logs
   - Monitor performance metrics

### Related Documentation

- **Technical Specifications**: See `docs/WMS_Technical.md`
- **API Reference**: See `docs/WMS_API_Reference.md`
- **Administration Guide**: See `docs/WMS_Administration.md`
- **User Guide**: See `docs/WMS_User_Guide.md`

### Version Information

- **WMS Version**: 1.3.0
- **GeoServer Version**: 2.24+
- **PostGIS Version**: 3.0+
- **Last Updated**: 2025-07-27 