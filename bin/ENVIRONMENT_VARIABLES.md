# Environment Variables Documentation

**Version:** 2025-10-30  
**Purpose:** Define standard environment variables for OSM-Notes-Ingestion

## Overview

This document defines all environment variables used across the OSM-Notes-Ingestion system, categorized as:
- **Common**: Used by all scripts
- **Per-Script**: Specific to individual entry points
- **Internal**: Used internally (do not modify)

## ✅ Common Variables

These variables are used across **all scripts** and should be standardized:

### `LOG_LEVEL`
- **Purpose**: Controls logging verbosity
- **Values**: `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL`
- **Default**: `ERROR`
- **Usage**: Set higher for debugging, lower for production
- **Example**: `export LOG_LEVEL=DEBUG`

### `LOG_FILE`
- **Purpose**: Forces logger to write to a specific file
- **Values**: Absolute path to a writable `.log` file
- **Default**: Not set (scripts may auto-create a temp log file)
- **Behavior**:
  - When set, `__start_logger` routes output to this file.
  - Recommended for interactive/TTY sessions to persist logs.
- **Examples**:
  - `export LOG_FILE=/tmp/processCheckPlanetNotes.log`
  - `LOG_FILE=/tmp/processPlanetNotes.log LOG_LEVEL=INFO \
    ./bin/process/processPlanetNotes.sh --base`

### `DOWNLOAD_USER_AGENT`
- **Purpose**: Sets the HTTP User-Agent for all outbound downloads (Overpass, etc.)
- **Format**: `Project/Version (+project_url; contact: email)`
- **Default**: empty (no explicit header)
- **Example**:
  - `export DOWNLOAD_USER_AGENT="OSM-Notes-Ingestion/2025-10-30 (+https://github.com/angoca/OSM-Notes-Ingestion; contact: you@example.com)"`

### `CLEAN`
- **Purpose**: Whether to delete temporary files after processing
- **Values**: `true`, `false`
- **Default**: `true`
- **Usage**: Set to `false` to keep files for debugging
- **Example**: `export CLEAN=false`

### `DBNAME`
- **Purpose**: PostgreSQL database name
- **Values**: String (e.g., `osm-notes`, `osm-notes_test`)
- **Default**: `osm-notes` (from `etc/properties.sh`)
- **Usage**: Change for test/production environments
- **Example**: `export DBNAME=osm_notes_test`

### `SKIP_XML_VALIDATION`
- **Purpose**: Skip XML structure/date validation for faster processing
- **Values**: `true`, `false`
- **Default**: `true` (assumes OSM data is valid)
- **Usage**: Set to `false` for strict validation (slower)
- **Example**: `export SKIP_XML_VALIDATION=false`

### Overpass Fallback and Validation

These variables control the Overpass API behavior for boundary downloads.

#### `OVERPASS_ENDPOINTS`
- **Purpose**: Ordered, comma-separated list of Overpass interpreter endpoints for fallback
- **Default**: value of `OVERPASS_INTERPRETER`
- **Example**: `export OVERPASS_ENDPOINTS="https://overpass-api.de/api/interpreter,https://overpass.kumi.systems/api/interpreter"`

#### `OVERPASS_RETRIES_PER_ENDPOINT`
- **Purpose**: Max retries per endpoint for a single boundary
- **Default**: `3`
- **Example**: `export OVERPASS_RETRIES_PER_ENDPOINT=4`

#### `OVERPASS_BACKOFF_SECONDS`
- **Purpose**: Base backoff (seconds) between retries (exponential per attempt)
- **Default**: `5`
- **Example**: `export OVERPASS_BACKOFF_SECONDS=10`

#### `CONTINUE_ON_OVERPASS_ERROR`
- **Purpose**: Continue processing other boundaries when JSON validation fails
- **Values**: `true`, `false`
- **Default**: `true`
- **Behavior**: When `true`, boundary IDs that fail are added to `${TMP_DIR}/failed_boundaries.txt`

#### `JSON_VALIDATOR`
- **Purpose**: JSON validation command (must support `jq -e .`)
- **Default**: `jq`
- **Example**: `export JSON_VALIDATOR=/usr/bin/jq`

## 📝 Per-Script Variables

### `processAPINotes.sh` Specific

#### Alert Configuration
- **`ADMIN_EMAIL`**: Email address for failure alerts (default: `root@localhost`)
- **`SEND_ALERT_EMAIL`**: Enable/disable email alerts (`true`/`false`, default: `true`)

#### Example
```bash
export ADMIN_EMAIL="admin@example.com"
export SEND_ALERT_EMAIL="true"
export LOG_LEVEL=DEBUG
./bin/process/processAPINotes.sh
```

### `processPlanetNotes.sh` Specific

#### Base/Update Mode
- No specific env vars for `--base` mode (uses parameter)
- No specific env vars for `--boundaries` mode (uses parameter)

#### Example
```bash
export LOG_LEVEL=DEBUG
./bin/process/processPlanetNotes.sh --base
```

### `updateCountries.sh` Specific
- Same as common variables
- No script-specific variables
- Uses `--base` parameter for base mode

#### Example
```bash
export LOG_LEVEL=INFO
./bin/process/updateCountries.sh
```

### `notesCheckVerifier.sh` Specific

#### Email Recipients
- **`EMAILS`**: Comma-separated list of email recipients for reports
- **Default**: `maptime.bogota@gmail.com,contact@osm.org`
- **Usage**: Override for custom recipients

#### Example
```bash
export EMAILS="admin@example.com,backup@example.com"
export LOG_LEVEL=WARN
./bin/monitor/notesCheckVerifier.sh
```

### `wmsManager.sh` Specific
All WMS configuration is done via **`bin/wms/wms.properties.sh`** or environment variables:
- **`GEOSERVER_URL`**: GeoServer base URL
- **`GEOSERVER_USER`**: GeoServer username
- **`GEOSERVER_PASSWORD`**: GeoServer password
- **`GEOSERVER_WORKSPACE`**: Workspace name
- **`GEOSERVER_LAYER`**: Layer name
- **`WMS_*`**: Various WMS configuration options

#### Example
```bash
export GEOSERVER_URL="https://geoserver.example.com/geoserver"
export GEOSERVER_USER="admin"
export GEOSERVER_PASSWORD="secure_password"
./bin/wms/wmsManager.sh install
```

### `cleanupAll.sh` Specific
No script-specific variables. Accepts database name as **argument**.

#### Example
```bash
./bin/cleanupAll.sh osm_notes_test
```

## 🔧 Internal Variables (Do Not Modify)

These variables are used internally and should **never** be set manually:

- **`GENERATE_FAILED_FILE`**: Controls whether to create failed execution files
- **`ONLY_EXECUTION`**: Controls execution mode (for testing)
- **`RET_FUNC`**: Return value from functions
- **`RUNNING_IN_SETSID`**: SIGHUP protection flag
- **`SCRIPT_BASE_DIRECTORY`**: Base directory (auto-detected)
- **`BASENAME`**: Script name (auto-detected)
- **`TMP_DIR`**: Temporary directory (auto-created)
- **`LOCK`**: Lock file path (auto-created)

## 📋 Properties File Variables

Defined in `etc/properties.sh` (can be overridden by environment):

- **`DB_USER`**: PostgreSQL user (default: `angoca`)
- **`OSM_API`**: OSM API URL (default: `https://api.openstreetmap.org/api/0.6`)
- **`PLANET`**: Planet dump URL (default: `https://planet.openstreetmap.org`)
- **`OVERPASS_INTERPRETER`**: Overpass API URL
- **`DOWNLOAD_USER_AGENT`**: User-Agent for downloads (Overpass, etc.)
- **`OVERPASS_ENDPOINTS`**: Fallback endpoints (comma-separated)
- **`OVERPASS_RETRIES_PER_ENDPOINT`**: Retries per endpoint
- **`OVERPASS_BACKOFF_SECONDS`**: Base backoff between retries
- **`CONTINUE_ON_OVERPASS_ERROR`**: Continue on JSON validation failure
- **`JSON_VALIDATOR`**: JSON validator command (jq)
- **`LOOP_SIZE`**: Notes processed per loop (default: `10000`)
- **`MAX_NOTES`**: Max notes from API (default: `10000`)
- **`MAX_THREADS`**: Parallel processing threads (auto-calculated)
- **`MIN_NOTES_FOR_PARALLEL`**: Minimum notes for parallel processing (default: `10`)

## 🎯 Standard Usage Patterns

### Development/Debugging
```bash
export LOG_LEVEL=DEBUG
export CLEAN=false
export SKIP_XML_VALIDATION=false
./bin/process/processAPINotes.sh
```

### Production
```bash
export LOG_LEVEL=ERROR
export CLEAN=true
export SKIP_XML_VALIDATION=true
export SEND_ALERT_EMAIL=true
export ADMIN_EMAIL="admin@production.com"
./bin/process/processAPINotes.sh
```

### Testing
```bash
export DBNAME=osm_notes_test
export LOG_LEVEL=INFO
export CLEAN=true
./bin/process/processAPINotes.sh
```

### Monitoring
```bash
export EMAILS="monitoring@example.com"
export LOG_LEVEL=WARN
./bin/monitor/notesCheckVerifier.sh
```

## 📝 Recommendations

### For Users
1. **Never** set internal variables manually
2. Use `etc/properties.sh` for local customization
3. Only override environment variables when necessary
4. Document any custom configuration

### For Developers
1. Add new variables to this documentation
2. Use descriptive names in UPPERCASE
3. Always provide defaults via `${VAR:-default}`
4. Document in script header comments

## 🔄 Migration from Old Patterns

Old patterns to avoid:
- ~~`export GENERATE_FAILED_FILE=true`~~ (internal, do not set)
- ~~`export ONLY_EXECUTION="no"`~~ (internal, do not set)
- ~~Hardcoded paths~~ (use `${SCRIPT_BASE_DIRECTORY}`)

New standard:
- Set only documented variables
- Use `etc/properties.sh` for configuration
- Override via environment when needed

## See Also

- `bin/ENTRY_POINTS.md` - Allowed entry points
- `etc/properties.sh` - Default configuration
- `README.md` - General usage guide

