# WMS Manager Scripts

This directory contains scripts for managing WMS (Web Map Service) components for the OSM Notes Profile project.

## Configuration

### WMS Properties (`etc/wms.properties.sh`)
The WMS system uses a dedicated properties file for easy customization:

```bash
# Load WMS properties
source etc/wms.properties.sh

# Or set custom values
export WMS_DBNAME="my_database"
export GEOSERVER_URL="https://my-geoserver.com/geoserver"
```

**Key Configuration Sections:**
- **Database Configuration**: Connection settings for PostgreSQL
- **GeoServer Configuration**: GeoServer access and workspace settings
- **WMS Service Configuration**: Service metadata and layer settings
- **Style Configuration**: SLD style file and fallback options
- **Performance Configuration**: Connection pools and caching
- **Security Configuration**: Authentication and CORS settings
- **Logging Configuration**: Log levels and file management
- **Development Configuration**: Debug and development mode settings

### Configuration Examples (`bin/wms/wmsConfigExample.sh`)
Use this script to explore and validate WMS configuration:

```bash
# Show current configuration
./bin/wms/wmsConfigExample.sh show-config

# Validate properties
./bin/wms/wmsConfigExample.sh validate

# Test connections
./bin/wms/wmsConfigExample.sh test-connection

# Show customization examples
./bin/wms/wmsConfigExample.sh customize
```

## Scripts

### 1. wmsManager.sh
Manages the installation and deinstallation of WMS components in the database.

**Usage:**
```bash
# Install WMS components
./bin/wms/wmsManager.sh install

# Check installation status
./bin/wms/wmsManager.sh status

# Remove WMS components
./bin/wms/wmsManager.sh deinstall

# Show help
./bin/wms/wmsManager.sh help
```

### 2. geoserverConfig.sh
Automates GeoServer setup for WMS layers. This script configures GeoServer to serve OSM notes as WMS layers.

**Prerequisites:**
- GeoServer installed and running
- PostgreSQL with PostGIS extension
- WMS components installed in database
- curl and jq installed

**Usage:**
```bash
# Install and configure GeoServer
./bin/wms/geoserverConfig.sh install

# Configure existing GeoServer installation
./bin/wms/geoserverConfig.sh configure

# Check configuration status
./bin/wms/geoserverConfig.sh status

# Remove configuration
./bin/wms/geoserverConfig.sh remove

# Show help
./bin/wms/geoserverConfig.sh help
```

**Options:**
- `--force`: Force configuration even if already configured
- `--dry-run`: Show what would be done without executing
- `--verbose`: Show detailed output
- `--geoserver-url URL`: GeoServer REST API URL
- `--geoserver-user USER`: GeoServer admin username
- `--geoserver-pass PASS`: GeoServer admin password

**Configuration:**
The script automatically uses WMS properties from `etc/wms.properties.sh`:
- Database connection settings
- GeoServer access configuration
- WMS service metadata
- Style and layer settings

## Complete WMS Setup Workflow

1. **Install WMS database components:**
   ```bash
   ./bin/wms/wmsManager.sh install
   ```

2. **Configure GeoServer:**
   ```bash
   ./bin/wms/geoserverConfig.sh install
   ```

3. **Verify configuration:**
   ```bash
   ./bin/wms/wmsManager.sh status
   ./bin/wms/geoserverConfig.sh status
   ```

4. **Access WMS service:**
   - WMS URL: `http://localhost:8080/geoserver/wms`
   - Layer Name: `osm_notes:notes_wms_layer`

## Features

### WMS Manager
- ✅ Automatic validation of prerequisites (PostgreSQL, PostGIS)
- ✅ Database connection testing
- ✅ Installation status checking
- ✅ Safe installation with conflict detection
- ✅ Force reinstallation option
- ✅ Dry-run mode for testing
- ✅ Comprehensive error handling

### GeoServer Config
- ✅ Automated GeoServer workspace creation
- ✅ PostGIS datastore configuration
- ✅ WMS layer setup
- ✅ SLD style upload and assignment
- ✅ Configuration status checking
- ✅ Complete removal functionality
- ✅ REST API integration
- ✅ Error handling and validation

## Troubleshooting

### Common Issues

1. **GeoServer not accessible:**
   - Ensure GeoServer is running
   - Check credentials (default: admin/geoserver)
   - Verify URL (default: http://localhost:8080/geoserver)

2. **Database connection failed:**
   - Verify PostgreSQL is running
   - Check database credentials
   - Ensure PostGIS extension is installed

3. **WMS schema not found:**
   - Run `./bin/wms/wmsManager.sh install` first
   - Check if WMS components are properly installed

4. **Style upload failed:**
   - Ensure SLD file exists at `sld/OpenNotes.sld`
   - Check GeoServer permissions

### Logs and Debugging

Enable verbose output for detailed information:
```bash
./bin/wms/geoserverConfig.sh install --verbose
```

Check GeoServer logs for detailed error information:
```bash
tail -f /opt/geoserver/logs/geoserver.log
```

## Integration with CI/CD

Both scripts are designed to work with the CI/CD pipeline:

- **WMS Manager**: Installs database components in test environment
- **GeoServer Config**: Configures GeoServer for integration testing
- **Status checks**: Verify configuration in deployment pipeline

## Security Considerations

- Use strong passwords for GeoServer admin account
- Configure database user with minimal required permissions
- Consider using environment variables for sensitive data
- Regularly update GeoServer and PostgreSQL
- Monitor access logs for suspicious activity 