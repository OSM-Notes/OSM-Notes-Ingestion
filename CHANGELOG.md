# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

#### Critical API Query Bug Fix (2025-12-12)

- **Fixed incorrect API URL in `__getNewNotesFromApi` function**:
  - **Problem**: Function in `bin/lib/processAPIFunctions.sh` was using incorrect API endpoint without date filter
  - **Impact**: Daemon was downloading all notes without filtering by last update timestamp, causing it to always process the same old notes
  - **Solution**: Updated function to use correct endpoint `/notes/search.xml` with `from` parameter to filter notes by last update timestamp
  - **Files changed**: `bin/lib/processAPIFunctions.sh` (version updated to 2025-12-12)

- **Fixed timestamp format bug in SQL queries**:
  - **Problem**: Timestamp queries were generating malformed dates like `2025-12-09THH24:33:04Z` (with literal "HH24" instead of actual hour)
  - **Impact**: API rejected malformed timestamps, preventing any notes from being downloaded
  - **Solution**: Fixed SQL `TO_CHAR` queries to use PostgreSQL escape string syntax (`E'...'`) for proper quote escaping
  - **Files changed**:
    - `bin/lib/processAPIFunctions.sh` (line 107)
    - `bin/process/processAPINotesDaemon.sh` (lines 546, 667, version updated to 2025-12-12)

- **Fixed API timeout insufficient for large downloads** (2025-12-13):
  - **Problem**: Timeout of 30 seconds was insufficient for downloading 10,000 notes (can be 12MB+)
  - **Impact**: API calls were timing out after 5 retry attempts, preventing notes from being downloaded
  - **Solution**: Increased timeout from 30 to 120 seconds in `__getNewNotesFromApi` function call to `__retry_osm_api`
  - **Files changed**: `bin/lib/processAPIFunctions.sh` (line 135, version updated to 2025-12-13)

- **Root cause analysis**:
  - The daemon was correctly checking for updates using the right URL format
  - However, when downloading notes, it used a simplified function that didn't include the date filter
  - Additionally, timestamp formatting had incorrect quote escaping in SQL queries
  - The timeout was too short for large downloads (10,000 notes can take 60-90 seconds)
  - All issues combined prevented any new notes from being processed since December 9, 2025

### Added

#### Daemon Mode for API Processing

- **New daemon script**: `bin/process/processAPINotesDaemon.sh`
  - Continuous execution mode for lower latency (30-60 seconds vs 15 minutes)
  - Adaptive sleep logic that adjusts wait time based on processing duration
  - One-time setup instead of recreating database structures each execution
  - Automatic error recovery with consecutive error limit
  - Graceful shutdown via signals (SIGTERM, SIGINT)
  - Configuration reload via SIGHUP
  - Status reporting via SIGUSR1

- **systemd integration**: `examples/systemd/osm-notes-api-daemon.service`
  - Service file for managing daemon with systemd
  - Automatic restart on failure
  - Integrated logging with journalctl
  - Dependency management (PostgreSQL)

- **Testing infrastructure**:
  - `tests/unit/bash/processAPINotesDaemon_sleep_logic.test.bats` - Unit tests for adaptive sleep logic
  - `tests/unit/bash/processAPINotesDaemon_integration.test.bats` - Integration tests for daemon functionality
  - `tests/run_processAPINotesDaemon_tests.sh` - Test runner script
  - `tests/unit/bash/process/reassignAffectedNotes_optimization.test.bats` - Unit tests for SQL optimization in country reassignment batch processing

- **Documentation**:
  - Added "Daemon Mode" section to `docs/Process_API.md`
  - Comprehensive daemon documentation integrated with existing API processing docs
  - Troubleshooting guide for common systemd errors integrated into `Process_API.md`

### Changed

- **Documentation updates**:
  - Updated `docs/Process_API.md` to recommend daemon mode over cron
  - Reduced cron documentation to legacy/alternative status
  - All daemon documentation unified and translated to English
  - Enhanced troubleshooting documentation for systemd service configuration errors

- **systemd service file improvements**:
  - Made `Group=` optional in `examples/systemd/osm-notes-api-daemon.service` (commented out by default)
  - Added `PATH` environment variable to ensure command availability
  - Added comments explaining user/group configuration

- **Error handling enhancements**:
  - Improved error handling in `bin/lib/noteProcessingFunctions.sh` to differentiate between network and non-network errors
  - Automatic retry mechanism for temporary network issues
  - Enhanced error reporting in `bin/process/processAPINotes.sh` with tracking of failed jobs during note insertion

- **SQL optimization**:
  - Optimized `sql/functionsProcess_36_reassignAffectedNotes_batch.sql` to only update notes where the country has changed
  - Reduced unnecessary database writes, improving performance in country reassignment operations

- **Documentation updates**:
  - Enhanced `docs/Process_API.md` to reflect new automatic recovery features
  - Clarified error handling processes in API processing documentation
  - Updated `sql/README.md` with relevant information

### Technical Details

#### Relationship Between Scripts

**Important:** `processAPINotesDaemon.sh` does **NOT** use or call `processAPINotes.sh` directly. They are **independent scripts** that share code through common libraries:

**Shared libraries** (both scripts source the same files):

- `bin/lib/functionsProcess.sh` - Core processing functions
- `bin/lib/processAPIFunctions.sh` - API-specific functions (defines `__getNewNotesFromApi`, etc.)
- `lib/osm-common/commonFunctions.sh` - Common utilities and logging
- `lib/osm-common/validationFunctions.sh` - Validation functions
- `lib/osm-common/errorHandlingFunctions.sh` - Error handling
- `bin/lib/parallelProcessingFunctions.sh` - Parallel processing

**Shared functions** (both scripts call the same library functions):

- `__getNewNotesFromApi()` - Download notes from API (from `processAPIFunctions.sh`)
- `__processXMLorPlanet()` - Process XML data (from `functionsProcess.sh`)
- `__insertNewNotesAndComments()` - Insert data into database (from `functionsProcess.sh`)
- `__loadApiTextComments()` - Load comment text (from `functionsProcess.sh`)
- `__updateLastValue()` - Update timestamp (from `functionsProcess.sh`)

**Key architectural differences**:

- `processAPINotes.sh`: Executes once, exits (designed for cron)
- `processAPINotesDaemon.sh`: Continuous loop, stays running (designed for systemd)
- Daemon uses `TRUNCATE` instead of `DROP/CREATE` for tables (optimization)
- Daemon implements adaptive sleep logic (optimization)
- Daemon has signal handling for graceful shutdown (daemon requirement)

**⚠️ Warning:** Do NOT run both scripts simultaneously. They use the same database tables and will conflict.

### Performance Improvements

- **Reduced setup overhead**: Daemon performs setup once instead of every execution
- **Lower latency**: 30-60 seconds between checks vs 15 minutes with cron
- **Adaptive sleep**: Optimizes wait time based on actual processing duration
- **Better resource utilization**: Reuses database structures instead of recreating

### Migration Notes

- The daemon is a **complete replacement** for cron-based `processAPINotes.sh`
- Migration requires:
  1. Stop cron job for `processAPINotes.sh`
  2. Install daemon service file
  3. Enable and start daemon with systemd
- See `docs/Process_API.md` "Daemon Mode" section for detailed migration guide

---

## Previous Versions

For changes before this version, see git history.
