# Configuration Files

This directory contains configuration files for the OSM-Notes-profile project.

## Files

### 1. properties.sh
Main configuration file with general project settings.

### 2. wms.properties.sh
**NEW**: WMS-specific configuration file for Web Map Service components.

## WMS Properties Configuration

The `wms.properties.sh` file provides centralized configuration for all WMS-related components:

### Database Configuration
```bash
WMS_DBNAME="osm_notes"           # Database name
WMS_DBUSER="postgres"            # Database user
WMS_DBPASSWORD=""                # Database password
WMS_DBHOST="localhost"           # Database host
WMS_DBPORT="5432"               # Database port
WMS_SCHEMA="wms"                # WMS schema name
WMS_TABLE="notes_wms"           # WMS table name
```

### GeoServer Configuration
```bash
GEOSERVER_URL="http://localhost:8080/geoserver"  # GeoServer URL
GEOSERVER_USER="admin"                           # GeoServer admin user
GEOSERVER_PASSWORD="geoserver"                   # GeoServer admin password
GEOSERVER_WORKSPACE="osm_notes"                  # Workspace name
GEOSERVER_STORE="notes_wms"                      # Datastore name
GEOSERVER_LAYER="notes_wms_layer"                # Layer name
```

### WMS Service Configuration
```bash
WMS_SERVICE_TITLE="OSM Notes WMS Service"        # Service title
WMS_SERVICE_DESCRIPTION="OpenStreetMap Notes for WMS service"  # Service description
WMS_LAYER_TITLE="OSM Notes WMS Layer"            # Layer title
WMS_LAYER_SRS="EPSG:4326"                        # Spatial reference system
WMS_BBOX_MINX="-180"                             # Bounding box minimum X
WMS_BBOX_MAXX="180"                              # Bounding box maximum X
WMS_BBOX_MINY="-90"                              # Bounding box minimum Y
WMS_BBOX_MAXY="90"                               # Bounding box maximum Y
```

### Style Configuration
```bash
WMS_STYLE_NAME="osm_notes_style"                 # Style name
WMS_STYLE_FILE="${PROJECT_ROOT}/sld/OpenNotes.sld"  # SLD file path
WMS_STYLE_FALLBACK="true"                        # Enable style fallback
```

### Performance Configuration
```bash
WMS_DB_POOL_SIZE="10"                            # Database connection pool size
WMS_CACHE_ENABLED="true"                         # Enable caching
WMS_CACHE_TTL="3600"                             # Cache TTL in seconds
WMS_CACHE_MAX_SIZE="100"                         # Maximum cache size
```

### Security Configuration
```bash
WMS_AUTH_ENABLED="false"                         # Enable authentication
WMS_CORS_ENABLED="true"                          # Enable CORS
WMS_CORS_ALLOW_ORIGIN="*"                        # CORS allowed origins
```

### Logging Configuration
```bash
WMS_LOG_LEVEL="INFO"                              # Log level
WMS_LOG_FILE="${PROJECT_ROOT}/logs/wms.log"       # Log file path
WMS_LOG_MAX_SIZE="10MB"                           # Maximum log file size
WMS_LOG_MAX_FILES="5"                             # Maximum number of log files
```

### Development Configuration
```bash
WMS_DEV_MODE="false"                              # Development mode
WMS_DEBUG_ENABLED="false"                         # Debug mode
```

## Usage

### Loading Properties
```bash
# Load WMS properties in a script
source etc/wms.properties.sh

# Or set custom values before loading
export WMS_DBNAME="my_database"
source etc/wms.properties.sh
```

### Validation
```bash
# Validate WMS properties
source etc/wms.properties.sh
__validate_wms_properties

# Show current configuration
source etc/wms.properties.sh
__show_wms_config
```

### Customization Examples

#### Regional Configuration (Europe)
```bash
export WMS_BBOX_MINX="-10"
export WMS_BBOX_MAXX="40"
export WMS_BBOX_MINY="35"
export WMS_BBOX_MAXY="70"
export WMS_SERVICE_TITLE="European OSM Notes WMS Service"
```

#### Custom Database
```bash
export WMS_DBNAME="my_osm_notes"
export WMS_DBUSER="myuser"
export WMS_DBPASSWORD="mypassword"
export WMS_DBHOST="my-db-server.com"
```

#### Custom GeoServer
```bash
export GEOSERVER_URL="https://my-geoserver.com/geoserver"
export GEOSERVER_USER="admin"
export GEOSERVER_PASSWORD="secure_password"
export GEOSERVER_WORKSPACE="my_workspace"
```

#### Performance Tuning
```bash
export WMS_DB_POOL_SIZE="20"
export WMS_CACHE_TTL="7200"
export WMS_CACHE_MAX_SIZE="200"
```

#### Development Mode
```bash
export WMS_DEV_MODE="true"
export WMS_DEBUG_ENABLED="true"
export WMS_LOG_LEVEL="DEBUG"
```

## Integration

All WMS scripts automatically load these properties:

- `bin/wms/wmsManager.sh` - WMS database management
- `bin/wms/geoserverConfig.sh` - GeoServer configuration
- `bin/wms/wmsConfigExample.sh` - Configuration examples and validation

## Benefits

1. **Centralized Configuration**: All WMS settings in one place
2. **Easy Customization**: Simple environment variable overrides
3. **Validation**: Built-in property validation
4. **Documentation**: Self-documenting configuration
5. **Flexibility**: Support for different environments (dev, test, prod)
6. **Maintainability**: Clear separation of concerns

## Best Practices

1. **Environment-Specific Files**: Create custom property files for different environments
2. **Secure Credentials**: Use environment variables for sensitive data
3. **Validation**: Always validate properties before use
4. **Documentation**: Document custom configurations
5. **Version Control**: Keep property files in version control (excluding secrets) 

