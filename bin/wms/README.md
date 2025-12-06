# WMS Manager Scripts

This directory contains scripts for managing WMS (Web Map Service) components for
the OSM-Notes-Ingestion project.

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

Manages the installation and removal of WMS components in the database.

**Usage:**

```bash
# Install WMS components
./bin/wms/wmsManager.sh install

# Check installation status
./bin/wms/wmsManager.sh status

# Remove WMS components
./bin/wms/wmsManager.sh remove

# Show help
./bin/wms/wmsManager.sh help
```

**Options:**

- `--force`: Force installation even if already installed
- `--dry-run`: Show what would be done without executing
- `--verbose`: Show detailed output


### 2. geoserverConfig.sh

Automates GeoServer setup for WMS layers. This script configures GeoServer to
serve OSM notes as WMS layers.

**Prerequisites:**

- GeoServer installed and running
- PostgreSQL with PostGIS extension
- WMS components installed in database
- curl and jq installed
- **Database user `geoserver` with read-only permissions** (see Database Permissions below)

**Database Permissions:**

Before running `geoserverConfig.sh`, you must grant read-only permissions to the
`geoserver` user. This user is used by GeoServer to access WMS data with read-only
privileges (principle of least privilege):

```bash
# Execute as database owner (angoca) or postgres superuser
psql -d notes -f sql/wms/grantGeoserverPermissions.sql
```

This script will:
- Create the `geoserver` user if it doesn't exist
- Grant CONNECT privilege on the `notes` database
- Grant USAGE on `public` and `wms` schemas
- Grant SELECT (read-only) on all tables in the `wms` schema
- Grant SELECT on the `countries` table
- Set default privileges for future tables in the `wms` schema

**Security Note:** The `geoserver` user has read-only permissions only, which
is appropriate for WMS data access.

**Usage:**

```bash
# Install and configure GeoServer
./bin/wms/geoserverConfig.sh install

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
- `--geoserver-home DIR`: GeoServer installation directory
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

1. **Install WMS database components (as user 'notes' with elevated privileges):**

   ```bash
   # wmsManager.sh uses the system user (notes) via peer authentication
   # This user has privileges to create tables, triggers, etc.
   ./bin/wms/wmsManager.sh install
   ```

2. **Grant read-only permissions to geoserver user:**

   ```bash
   # Execute as database owner (angoca) or postgres superuser
   # This grants read-only access to the geoserver user
   psql -d notes -f sql/wms/grantGeoserverPermissions.sql
   ```

3. **Configure GeoServer (uses 'geoserver' user for datastore):**

   ```bash
   # geoserverConfig.sh uses the 'geoserver' user to configure GeoServer datastores
   # This user has read-only permissions (principle of least privilege)
   ./bin/wms/geoserverConfig.sh install
   ```

**User Privileges Summary:**
- **User 'notes'**: Elevated privileges (CREATE, ALTER, etc.) - used by `wmsManager.sh`
- **User 'geoserver'**: Read-only permissions (SELECT) - used by `geoserverConfig.sh` and GeoServer

## GeoServer Objects Created

When you run `geoserverConfig.sh install`, the following objects are created in GeoServer:

### 1. **Workspace**
- **Name**: `osm_notes` (configurable via `GEOSERVER_WORKSPACE`)
- **Type**: Workspace
- **Purpose**: Organizes all WMS layers for OSM notes
- **Location**: GeoServer → Data → Workspaces

### 2. **Namespace**
- **Prefix**: `osm_notes` (same as workspace name)
- **URI**: `urn:osm-notes-profile` (configurable via `GEOSERVER_NAMESPACE`)
- **Type**: Namespace
- **Purpose**: Provides a unique identifier for the workspace (URN format, not a web URL)
- **Location**: GeoServer → Data → Namespaces

### 3. **Datastore**
- **Name**: `notes_wms` (configurable via `GEOSERVER_STORE`)
- **Type**: PostGIS
- **Purpose**: Connection to PostgreSQL database containing WMS data
- **Connection Details**:
  - Database: `notes` (configurable via `WMS_DBNAME`)
  - Schema: `wms` (configurable via `WMS_SCHEMA`)
  - User: `geoserver` (read-only permissions)
  - Type: PostGIS
- **Location**: GeoServer → Data → Stores → `osm_notes:notes_wms`

### 4. **Feature Type (Layer)**
- **Name**: `notes_wms_layer` (configurable via `GEOSERVER_LAYER`)
- **Native Name**: `notes_wms` (table name in database)
- **Type**: Feature Type
- **Purpose**: Exposes the `wms.notes_wms` table as a WMS layer
- **SRS**: EPSG:4326 (WGS84)
- **Bounding Box**: Worldwide (-180 to 180, -90 to 90)
- **Location**: GeoServer → Data → Layers → `osm_notes:notes_wms_layer`

### 5. **Style (SLD)**
- **Name**: `osm_notes_style` (configurable via `WMS_STYLE_NAME`, defaults to `OpenNotes` if not set)
- **Type**: SLD (Styled Layer Descriptor)
- **Purpose**: Defines how the layer is rendered (colors, symbols, etc.)
- **File**: `sld/OpenNotes.sld` (configurable via `WMS_STYLE_FILE` or `WMS_STYLE_OPEN_FILE`)
- **Location**: GeoServer → Styles → `osm_notes_style` (or `OpenNotes`)

**Note**: The style is automatically assigned to the layer as the default style. The style name comes from `WMS_STYLE_NAME` (default: `osm_notes_style`), and the file comes from `WMS_STYLE_FILE` (default: `sld/OpenNotes.sld`).

### Accessing the WMS Service

After installation, the WMS service is available at:

- **WMS URL**: `http://localhost:8888/geoserver/wms` (or your GeoServer URL)
- **Layer Name**: `osm_notes:notes_wms_layer`
- **GetCapabilities**: `http://localhost:8888/geoserver/wms?service=WMS&version=1.1.0&request=GetCapabilities`

### Verifying Objects Were Created

#### Method 1: Using the Script Status Command

The easiest way to verify objects is using the built-in status command:

```bash
./bin/wms/geoserverConfig.sh status
```

This will check and report the status of all objects (workspace, namespace, datastore, layer).

#### Method 2: Using REST API (Command Line)

You can verify objects directly using the GeoServer REST API:

```bash
# Set your GeoServer credentials
export GEOSERVER_URL="http://localhost:8888/geoserver"
export GEOSERVER_USER="admin"
export GEOSERVER_PASSWORD="geoserver"

# Check workspace
curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  "${GEOSERVER_URL}/rest/workspaces/osm_notes.xml"

# List all workspaces
curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  "${GEOSERVER_URL}/rest/workspaces.xml"

# Check datastore
curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  "${GEOSERVER_URL}/rest/workspaces/osm_notes/datastores/notes_wms.xml"

# List all datastores in workspace
curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  "${GEOSERVER_URL}/rest/workspaces/osm_notes/datastores.xml"

# Check layer
curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  "${GEOSERVER_URL}/rest/layers/osm_notes:notes_wms_layer.xml"

# List all layers
curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  "${GEOSERVER_URL}/rest/layers.xml"

# List all styles
curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
  "${GEOSERVER_URL}/rest/styles.xml"
```

#### Method 3: Using GeoServer Web Interface

You can view all created objects in the GeoServer web interface:

1. **Access GeoServer Web**: `http://localhost:8888/geoserver/web`
2. **Login** with your admin credentials
3. **Navigate to**:
   - **Workspaces**: Data → Workspaces → Look for `osm_notes`
   - **Stores**: Data → Stores → Look for `osm_notes:notes_wms`
   - **Layers**: Data → Layers → Look for `osm_notes:notes_wms_layer`
   - **Styles**: Styles → Look for `osm_notes_style` or `OpenNotes`

**Direct Links** (after logging in):
- Workspaces: `http://localhost:8888/geoserver/web/?wicket:bookmarkablePage=:org.geoserver.web.data.workspace.WorkspacePage`
- Stores: `http://localhost:8888/geoserver/web/?wicket:bookmarkablePage=:org.geoserver.web.data.store.DataStoresPage`
- Layers: `http://localhost:8888/geoserver/web/?wicket:bookmarkablePage=:org.geoserver.web.data.layers.LayersPage`
- Styles: `http://localhost:8888/geoserver/web/?wicket:bookmarkablePage=:org.geoserver.web.data.style.StylesPage`

#### Troubleshooting: Objects Not Visible

If you don't see the objects in the web interface:

1. **Check if installation actually succeeded**:
   ```bash
   ./bin/wms/geoserverConfig.sh status
   ```

2. **Verify GeoServer URL is correct**:
   ```bash
   echo $GEOSERVER_URL
   # Should match your actual GeoServer URL (e.g., http://localhost:8888/geoserver)
   ```

3. **Verify credentials are loaded correctly**:
   
   The script loads credentials from `etc/wms.properties.sh`. Make sure your credentials are set there:
   
   ```bash
   # Check current credentials in properties file
   grep GEOSERVER_USER etc/wms.properties.sh
   grep GEOSERVER_PASSWORD etc/wms.properties.sh
   ```
   
   Or set them as environment variables:
   ```bash
   export GEOSERVER_USER=admin
   export GEOSERVER_PASSWORD=your_password
   ./bin/wms/geoserverConfig.sh status
   ```

4. **Check REST API directly**:
   ```bash
   # Using credentials from properties file
   source etc/wms.properties.sh
   curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
     "${GEOSERVER_URL}/rest/workspaces.xml"
   ```

5. **Verify credentials work**:
   ```bash
   source etc/wms.properties.sh
   curl -u "${GEOSERVER_USER}:${GEOSERVER_PASSWORD}" \
     "${GEOSERVER_URL}/rest/about/status"
   ```

6. **Check GeoServer logs** for errors:
   ```bash
   tail -f /opt/geoserver/logs/geoserver.log
   # Or wherever your GeoServer logs are located
   ```

**Common Issues:**
- **HTTP 401 (Unauthorized)**: Credentials are incorrect. Check `etc/wms.properties.sh` or set environment variables.
- **HTTP 404 (Not Found)**: GeoServer URL is incorrect. Verify `GEOSERVER_URL` matches your actual GeoServer installation.
- **HTTP 409 (Conflict)**: Object already exists. This is normal if you're re-running the installation.
- **HTTP 500 (Internal Server Error)**: GeoServer encountered an error. Check GeoServer logs for details.
- **Objects not visible**: Installation may have failed silently. The script now shows HTTP codes and error messages for each operation.

**Testing with Public GeoServer URL:**

If your GeoServer is publicly accessible (e.g., `https://geoserver.osm.lat/geoserver`):

```bash
export GEOSERVER_URL="https://geoserver.osm.lat/geoserver"
export GEOSERVER_USER="admin"
export GEOSERVER_PASSWORD="your_password"
./bin/wms/geoserverConfig.sh install
```

The script will now show detailed error messages including HTTP status codes and API responses if creation fails.

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
   - Verify URL (default: <http://localhost:8080/geoserver>)

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
