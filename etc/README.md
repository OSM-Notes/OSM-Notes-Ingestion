# Configuration Files

This directory contains configuration files for the OSM-Notes-Ingestion project.

## Initial Setup

**IMPORTANT**: The actual configuration files (`properties.sh` and `wms.properties.sh`) are
not tracked in Git for security reasons. You must create them from the example
files:

```bash
# Copy example files to create your local configuration
cp etc/properties.sh.example etc/properties.sh
cp etc/wms.properties.sh.example etc/wms.properties.sh

# Edit the files with your database credentials and settings
vi etc/properties.sh
vi etc/wms.properties.sh
```

The example files contain default values and detailed comments. Replace the
example values (like `myuser`, `changeme`, `your-email@domain.com`) with your
actual configuration.

## Files

### 1. properties.sh.example → properties.sh

Main configuration file with general project settings.

- **Example file**: `properties.sh.example` (tracked in Git)
- **Your local file**: `properties.sh` (not tracked in Git, contains your
  credentials)

### 2. wms.properties.sh.example → wms.properties.sh

WMS-specific configuration file for Web Map Service components.

- **Example file**: `wms.properties.sh.example` (tracked in Git)
- **Your local file**: `wms.properties.sh` (not tracked in Git, contains your
  credentials)

## WMS Properties Configuration

The `wms.properties.sh` file (copied from `wms.properties.sh.example`) provides
centralized configuration for all WMS-related components:

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

## Benefits

1. **Centralized Configuration**: All WMS settings in one place
2. **Easy Customization**: Simple environment variable overrides
3. **Validation**: Built-in property validation
4. **Documentation**: Self-documenting configuration
5. **Flexibility**: Support for different environments (dev, test, prod)
6. **Maintainability**: Clear separation of concerns

## Best Practices

1. **Use Example Files**: Always copy from `.example` files to create your local
   configuration
2. **Never Commit Secrets**: The actual `properties.sh` and `wms.properties.sh`
   files are in `.gitignore` and should never be committed
3. **Environment-Specific Files**: Create custom property files for different
   environments using the `_local` suffix (e.g., `properties.sh_local`)
4. **Secure Credentials**: Use environment variables for sensitive data when
   possible
5. **Validation**: Always validate properties before use
6. **Documentation**: Document custom configurations in your local files
7. **Version Control**: Only the `.example` files are tracked in Git (excluding
   secrets)
