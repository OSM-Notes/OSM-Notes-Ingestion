# Entry Points Documentation

**Purpose:** Define allowed entry points for OSM-Notes-Ingestion system

## Overview

This document defines the **standardized entry points** (scripts that can be called directly by
users or schedulers) vs **internal scripts** (supporting components that should not be called
directly).

## ✅ Allowed Entry Points

These are the **only scripts** that should be executed directly:

### Primary Processing

1. **`bin/process/processAPINotes.sh`** - Processes recent notes from OSM API
   - **Usage**: `./bin/process/processAPINotes.sh` (no parameters)
   - **Purpose**: Synchronizes recent OSM notes from API
   - **When**: Scheduled every 15 minutes
2. **`bin/process/processPlanetNotes.sh`** - Processes historical notes from Planet dump
   - **Usage**: `./bin/process/processPlanetNotes.sh` (sync) or
     `./bin/process/processPlanetNotes.sh --base`
   - **Purpose**: Loads complete historical data from Planet files
   - **When**: Initial setup or monthly sync
   - **Parameters**: None (sync mode) or `--base` (full setup)

3. **`bin/process/updateCountries.sh`** - Updates country and maritime boundaries
   - **Usage**: `./bin/process/updateCountries.sh` (update) or
     `./bin/process/updateCountries.sh --base`
   - **Purpose**: Downloads and imports country/maritime boundaries
   - **When**: After Planet processing or manual updates
   - **Parameters**: None (update mode) or `--base` (recreate tables)

### Monitoring

4. **`bin/monitor/notesCheckVerifier.sh`** - Validates data integrity
   - **Usage**: `./bin/monitor/notesCheckVerifier.sh` (no parameters)
   - **Purpose**: Compares Planet vs API data and reports differences
   - **When**: Daily automated check

### Maintenance

5. **`bin/cleanupAll.sh`** - Removes all database components
   - **Usage**: `./bin/cleanupAll.sh` (full) or `./bin/cleanupAll.sh -p` (partitions only)
   - **Options**: `-p`/`--partitions-only` (clean partitions only), `-a`/`--all` (full cleanup,
     default)
   - **Purpose**: Complete database cleanup
   - **When**: Testing or complete reset
   - **Database**: Configured in `etc/properties.sh` (DBNAME variable, created from
     `etc/properties.sh.example`)

## ❌ Internal Scripts (DO NOT CALL DIRECTLY)

These scripts are **supporting components** and should **never** be called directly:

### Processing Helpers

- (None - all extraction is done directly via AWK scripts)

### Monitoring Helpers

- `bin/monitor/processCheckPlanetNotes.sh` - Called internally by monitoring system

### Utility Scripts

- `bin/scripts/generateNoteLocationBackup.sh` - Called internally by updateCountries
- `bin/scripts/exportCountriesBackup.sh` - Manual export of country boundaries backup
- `bin/scripts/exportMaritimesBackup.sh` - Manual export of maritime boundaries backup

### Function Libraries

- `bin/lib/functionsProcess.sh` - Library functions (sourced by other scripts)
- `bin/lib/processAPIFunctions.sh` - API-specific functions (sourced by other scripts)
- `bin/lib/processPlanetFunctions.sh` - Planet-specific functions (sourced by other scripts)
- `bin/lib/parallelProcessingFunctions.sh` - Parallel processing functions (sourced by other
  scripts)
- `bin/lib/securityFunctions.sh` - Security/sanitization functions (sourced by other scripts)

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

# Cleanup database
./bin/cleanupAll.sh osm_notes_test
```

### ❌ Incorrect Usage (DO NOT CALL)

```bash
# Internal scripts - will fail or cause issues
./bin/functionsProcess.sh               # WRONG (library, not executable)
./bin/lib/*.sh                          # WRONG (libraries, not executables)
```

## Implementation Notes

### Current Behavior

- All internal scripts currently accept execution (no restrictions)
- No clear separation between entry points and internal scripts
- Users might accidentally call internal scripts

### Recommended Changes

- Add deprecation warnings to internal scripts
- Document that only 5 scripts are valid entry points
- Future: Add guards to prevent direct execution of internal scripts

## For Developers

If you need functionality from an internal script:

1. Check if there's a proper entry point that provides this functionality
2. If not, create a proper entry point or extend an existing one
3. Never call internal scripts directly in new code
