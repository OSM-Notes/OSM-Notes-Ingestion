# Entry Points Documentation

**Version:** 2025-10-26  
**Purpose:** Define allowed entry points for OSM-Notes-Ingestion system

## Overview

This document defines the **standardized entry points** (scripts that can be called directly by users or schedulers) vs **internal scripts** (supporting components that should not be called directly).

## ✅ Allowed Entry Points

These are the **only scripts** that should be executed directly:

### Primary Processing
1. **`bin/process/processAPINotes.sh`** - Processes recent notes from OSM API
   - **Usage**: `./bin/process/processAPINotes.sh`
   - **Purpose**: Synchronizes recent OSM notes from API
   - **When**: Scheduled every 15 minutes
   
2. **`bin/process/processPlanetNotes.sh`** - Processes historical notes from Planet dump
   - **Usage**: `./bin/process/processPlanetNotes.sh [--base|--boundaries]`
   - **Purpose**: Loads complete historical data from Planet files
   - **When**: Initial setup or monthly sync

3. **`bin/process/updateCountries.sh`** - Updates country and maritime boundaries
   - **Usage**: `./bin/process/updateCountries.sh [--base]`
   - **Purpose**: Downloads and imports country/maritime boundaries
   - **When**: After Planet processing or manual updates

### Monitoring
4. **`bin/monitor/notesCheckVerifier.sh`** - Validates data integrity
   - **Usage**: `./bin/monitor/notesCheckVerifier.sh`
   - **Purpose**: Compares Planet vs API data and reports differences
   - **When**: Daily automated check

### WMS (Web Map Service)
5. **`bin/wms/wmsManager.sh`** - Manages WMS installation/status
   - **Usage**: `./bin/wms/wmsManager.sh [install|deinstall|status]`
   - **Purpose**: Installs/manages GeoServer WMS layer for notes
   - **When**: Manual WMS setup or maintenance

### Maintenance
6. **`bin/cleanupAll.sh`** - Removes all database components
   - **Usage**: `./bin/cleanupAll.sh [OPTIONS]`
   - **Options**: `-p` (partitions only), `-a` (all, default)
   - **Purpose**: Complete database cleanup
   - **When**: Testing or complete reset
   - **Database**: Configured in `etc/properties.sh` (DBNAME variable)

## ❌ Internal Scripts (DO NOT CALL DIRECTLY)

These scripts are **supporting components** and should **never** be called directly:

### Processing Helpers
- `bin/process/assignCountriesToNotes.sh` - Called internally by processPlanetNotes
- `bin/process/extractPlanetNotesAwk.sh` - Called internally by processPlanetNotes

### Monitoring Helpers
- `bin/monitor/processCheckPlanetNotes.sh` - Called internally by monitoring system

### Utility Scripts
- `bin/scripts/generateNoteLocationBackup.sh` - Called internally by updateCountries

### Function Libraries
- `bin/functionsProcess.sh` - Library functions (sourced by other scripts)
- `bin/processAPIFunctions.sh` - API-specific functions (sourced by other scripts)
- `bin/processPlanetFunctions.sh` - Planet-specific functions (sourced by other scripts)
- `bin/parallelProcessingFunctions.sh` - Parallel processing functions (sourced by other scripts)
- `bin/securityFunctions.sh` - Security/sanitization functions (sourced by other scripts)

### WMS Helpers
- `bin/wms/geoserverConfig.sh` - Called internally by wmsManager
- `bin/wms/wmsConfigExample.sh` - Example configuration (not executable)

## Examples

### ✅ Correct Usage
```bash
# Process API notes (scheduled every 15 min)
./bin/process/processAPINotes.sh

# Initialize with Planet data
./bin/process/processPlanetNotes.sh --base

# Update boundaries
./bin/process/updateCountries.sh --base

# Check data integrity (daily)
./bin/monitor/notesCheckVerifier.sh

# Install WMS
./bin/wms/wmsManager.sh install

# Cleanup database
./bin/cleanupAll.sh osm_notes_test
```

### ❌ Incorrect Usage (DO NOT CALL)
```bash
# Internal scripts - will fail or cause issues
./bin/process/assignCountriesToNotes.sh  # WRONG
./bin/process/extractPlanetNotesAwk.sh  # WRONG
./bin/functionsProcess.sh               # WRONG
./bin/wms/geoserverConfig.sh            # WRONG
```

## Implementation Notes

### Current Behavior
- All internal scripts currently accept execution (no restrictions)
- No clear separation between entry points and internal scripts
- Users might accidentally call internal scripts

### Recommended Changes
- Add deprecation warnings to internal scripts
- Document that only 6 scripts are valid entry points
- Future: Add guards to prevent direct execution of internal scripts

## For Developers

If you need functionality from an internal script:
1. Check if there's a proper entry point that provides this functionality
2. If not, create a proper entry point or extend an existing one
3. Never call internal scripts directly in new code

