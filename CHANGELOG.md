# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

#### OSM API Version Detection Fix (2025-12-15)

- **Fixed OSM API version detection**:
  - **Issue**: Daemon was failing to start with error "Cannot detect OSM API version from response"
  - **Root Cause**: Code was attempting to extract API version from `/api/0.6/notes?limit=1` response, which doesn't contain version information
  - **Fix**: Changed to use dedicated `/api/versions` endpoint for version detection
  - **Implementation**:
    - Updated `__checkPrereqsCommands()` in `bin/lib/functionsProcess.sh` to use `/api/versions` endpoint
    - Changed regex pattern from `version="\K[0-9.]+` to `<version>\K[0-9.]+` to match XML element format
    - The `/api/versions` endpoint returns: `<api><version>0.6</version></api>`
  - **Impact**:
    - Daemon can now start successfully
    - Version detection is more reliable and doesn't require making a data request
    - Prevents false failures during prerequisites check
  - **Files changed**:
    - `bin/lib/functionsProcess.sh`
    - `tests/unit/bash/prerequisites_network.test.bats` (updated tests to match new endpoint)
    - `docs/External_Dependencies_and_Risks.md` (updated documentation)
    - `docs/Documentation.md` (updated prerequisites description)

### Changed

#### Daemon Enhancements and Feature Parity (2025-12-15)

- **Added gap detection to daemon**:
  - **Change**: Daemon now includes `__recover_from_gaps()` and `__check_and_log_gaps()` functions, equivalent to `processAPINotes.sh`
  - **Rationale**: Ensures daemon detects data integrity issues (notes without comments) before processing new data
  - **Implementation**:
    - `__recover_from_gaps()`: Checks for notes without comments in the last 7 days before processing
    - `__check_and_log_gaps()`: Reads and logs gaps from `data_gaps` table after processing
    - Both functions are called in the daemon's processing flow, matching `processAPINotes.sh` behavior
  - **Impact**:
    - Early detection of data integrity issues
    - Consistent behavior between daemon and standalone script
    - Better monitoring and troubleshooting capabilities
  - **Files changed**: `bin/process/processAPINotesDaemon.sh`

- **Added auto-initialization for empty database**:
  - **Change**: Daemon now automatically detects empty database and triggers `processPlanetNotes.sh --base` for initial data load
  - **Rationale**: Allows daemon to start with a fresh database without manual intervention
  - **Implementation**:
    - Detects empty database by checking if `max_note_timestamp` table exists or is empty
    - Detects if `notes` table exists or is empty
    - Automatically executes `processPlanetNotes.sh --base` if database is empty
    - Skips API table creation if base tables are missing (prevents enum errors)
  - **Impact**:
    - Daemon can start with completely empty database
    - No manual intervention required for initial setup
    - Prevents errors when starting daemon on fresh database
  - **Files changed**: `bin/process/processAPINotesDaemon.sh`

- **Refactored daemon for feature parity with processAPINotes.sh**:
  - **Change**: Consolidated and aligned daemon processing flow with `processAPINotes.sh` to prevent regressions
  - **Rationale**: Ensures daemon has all functionality of standalone script, preventing feature gaps
  - **Implementation**:
    - Removed duplicate code for XML validation and processing
    - Integrated full processing flow: validation, counting, processing, insertion, gap checking
    - Ensured all critical steps are present and correctly called
    - Moved `__prepareApiTables()` to beginning of each cycle to prevent data accumulation
  - **Impact**:
    - Daemon now has complete feature parity with standalone script
    - Reduced risk of regressions
    - Consistent behavior across both execution modes
  - **Files changed**: `bin/process/processAPINotesDaemon.sh`

### Fixed

#### Daemon and Processing Fixes (2025-12-15)

- **Fixed syntax error in daemon gap detection**:
  - **Problem**: `NOTE_COUNT` variable in `__check_api_for_updates` contained newlines, causing bash arithmetic comparison to fail with "syntax error in expression"
  - **Impact**: Daemon failed to check for API updates, preventing processing
  - **Solution**: Added `tr -d '[:space:]'` to clean `NOTE_COUNT` variable before comparison
  - **Files changed**: `bin/process/processAPINotesDaemon.sh`

- **Fixed daemon initialization with empty database**:
  - **Problem**: Daemon exited with error when database was empty, preventing auto-initialization
  - **Impact**: Daemon could not start with fresh database, requiring manual `processPlanetNotes.sh --base` execution
  - **Solution**:
    - Modified `__daemon_init` to not exit if base tables are missing (allows main loop to handle initialization)
    - Modified `__process_api_data` to detect empty database and automatically trigger `processPlanetNotes.sh --base`
    - Added table existence checks before counting rows to prevent SQL errors
  - **Files changed**: `bin/process/processAPINotesDaemon.sh`

- **Fixed API table creation errors with empty database**:
  - **Problem**: Daemon tried to create API tables before base tables existed, causing "type does not exist" errors for enums
  - **Impact**: Daemon failed to initialize when database was empty
  - **Solution**: Skip `__prepareApiTables`, `__createPropertiesTable`, `__ensureGetCountryFunction`, and `__createProcedures` if base tables are missing (these depend on enums created by `processPlanetNotes.sh --base`)
  - **Files changed**: `bin/process/processAPINotesDaemon.sh`

#### Database Schema Enhancements (2025-12-14)

- **Added `insert_time` and `update_time` columns to `notes` table**:
  - **Change**: Added automatic timestamp tracking for when notes are inserted and updated in the database
  - **Rationale**: Provides audit trail and enables tracking of data lifecycle in the database
  - **Implementation**:
    - Added `insert_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP` column
    - Added `update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP` column
    - Created `set_notes_timestamps()` trigger function
    - Created `set_notes_timestamps_insert` trigger (BEFORE INSERT)
    - Created `set_notes_timestamps_update` trigger (BEFORE UPDATE)
    - Triggers automatically set `insert_time` on INSERT and `update_time` on INSERT/UPDATE
    - Preserves `insert_time` on UPDATE (only updates `update_time`)
  - **Migration**: Created and executed migration script `sql/migrations/add_insert_update_time_to_notes.sql` for production
  - **Impact**:
    - All new notes automatically track insertion and update times
    - Existing notes populated with `created_at` as proxy for `insert_time`
    - No changes required to application code (triggers handle everything)
  - **Files changed**:
    - `sql/process/processPlanetNotes_22_createBaseTables_tables.sql`
    - `sql/process/processPlanetNotes_24_createSyncTables.sql`
    - `tests/unit/sql/tables.test.sql`
    - `tests/unit/sql/tables_simple.test.sql`
    - `docs/Documentation.md`
    - `docs/Process_Planet.md`

- **Removed partitioning from API tables**:
  - **Change**: Converted `notes_api`, `note_comments_api`, and `note_comments_text_api` from partitioned tables to regular tables
  - **Rationale**: API processing is sequential (not parallel), so partitioning adds unnecessary complexity without performance benefits
  - **Implementation**:
    - Removed `part_id` column from all API tables
    - Removed all partition tables (`*_api_part_*`)
    - Updated SQL scripts to remove `part_id` from COPY statements
    - Updated Bash scripts to remove `part_id` from CSV processing
  - **Migration**: Created and executed migration script `sql/migrations/remove_partitioning_from_api_tables.sql` for production
  - **Impact**:
    - Simplified API processing code
    - Reduced database complexity
    - No performance impact (API processing is sequential anyway)
  - **Files changed**:
    - `sql/process/processAPINotes_21_createApiTables.sql`
    - `sql/process/processAPINotes_31_loadApiNotes.sql`
    - `sql/process/processAPINotes_12_dropApiTables.sql`
    - `bin/process/processAPINotes.sh`
  - **Note**: Planet processing (`processPlanetNotes.sh`) still uses partitioning for parallel processing

- **Enhanced documentation for data integrity checks**:
  - **Change**: Added comprehensive documentation section "Data Integrity Check and Gap Management" to `docs/Process_API.md`
  - **Rationale**: Provides clear explanation of how the integrity check system works, the 5% threshold, and how `notesCheckVerifier.sh` corrects data gaps
  - **Content**:
    - Detailed explanation of `app.integrity_check_passed` session variable
    - Explanation of the 5% gap threshold
    - How `notesCheckVerifier.sh` corrects gaps by downloading Planet data from days ahead
    - Session variable persistence mechanism
  - **Files changed**: `docs/Process_API.md`

#### Network Operations Migration: wget to curl (2025-12-13)

- **Replaced wget with curl for all network operations**:
  - **Change**: Migrated all network operations from `wget` to `curl` across the codebase
  - **Rationale**: Improved compatibility, better error handling, and reduced dependencies
  - **Implementation**:
    - Replaced `wget` calls with `curl` in all processing scripts
    - Added User-Agent headers to curl requests for better API compliance
    - Updated documentation to reflect `curl` as the network tool dependency
  - **Impact**:
    - Removed `wget` as a project dependency
    - Better error handling and HTTP status code support
    - Improved compatibility across different systems
  - **Files changed**:
    - `bin/lib/boundaryProcessingFunctions.sh`
    - `bin/lib/functionsProcess.sh`
    - `bin/lib/noteProcessingFunctions.sh`
    - `bin/process/processAPINotes.sh`
    - `bin/process/processAPINotesDaemon.sh`
    - `bin/process/processPlanetNotes.sh`
    - `bin/process/updateCountries.sh`
    - `bin/lib/README.md`

#### API Processing Simplified to Sequential Mode (2025-12-12)

- **Removed parallel processing from API processing**:
  - **Change**: API processing (`processAPINotes.sh`) now uses sequential processing instead of parallel processing
  - **Rationale**: For daemon mode with frequent small incremental updates (every 60 seconds), parallelism overhead is not justified
  - **Impact**:
    - Simplified codebase and reduced complexity
    - Lower memory footprint for small incremental updates
    - Faster startup time for daemon cycles
    - All operations now use connection pool consistently
  - **Technical details**:
    - Removed parallel processing logic from `processAPINotes.sh`
    - Simplified API tables (removed partitioning)
    - Converted `__createPartitions` and `__consolidatePartitions` to NO-OP functions
    - Removed `__checkMemoryForProcessing` function
    - Simplified `__insertNewNotesAndComments` to sequential only
    - Introduced `__processApiXmlSequential` function for sequential processing
    - AWK scripts still generate `part_id` (empty) for Planet compatibility, but API processing removes this column from CSV before COPY
  - **Pool improvements**:
    - Added `__db_simple_pool_ensure_alive()` to detect and restart dead coprocess
    - Removed all redundant fallbacks to direct psql calls
    - Pool now handles recovery automatically, simplifying calling code
  - **Files changed**:
    - `bin/process/processAPINotes.sh`
    - `bin/lib/processAPIFunctions.sh`
    - `sql/process/processAPINotes_*.sql` (updated to reflect non-partitioned table structure)
  - **Note**: Planet processing (`processPlanetNotes.sh`) still uses parallel processing for large bulk operations

### Fixed

#### Daemon and Processing Fixes (2025-12-14)

- **Fixed API tables not being cleaned after each daemon cycle**:
  - **Problem**: When migrating from cron to daemon, API tables were created once and never cleaned, causing data accumulation
  - **Impact**: Tables accumulated data from all cycles, slowing down queries and wasting disk space
  - **Solution**: Added `__prepareApiTables()` call after each cycle to TRUNCATE tables after data insertion
  - **Files changed**: `bin/process/processAPINotesDaemon.sh`

- **Fixed `pgrep` false positives in daemon startup check**:
  - **Problem**: `pgrep -f "processPlanetNotes"` was too broad and detected other processes like `processCheckPlanetNotes.sh`
  - **Impact**: Daemon failed to start even when `processPlanetNotes.sh` was not running
  - **Solution**: Changed pattern to `pgrep -f "processPlanetNotes\.sh"` to match only the exact script
  - **Files changed**: `bin/process/processAPINotesDaemon.sh`

- **Fixed `rmdir` failure on non-empty directories in `processPlanetNotes.sh`**:
  - **Problem**: `rmdir` command failed when trying to remove temporary directories that still contained files
  - **Impact**: Script failed during cleanup phase even though data processing was successful
  - **Solution**: Changed `rmdir "${TMP_DIR}"` to `rm -rf "${TMP_DIR}"` to forcefully remove directory and contents
  - **Files changed**: `bin/process/processPlanetNotes.sh`

- **Fixed `local` keyword usage in trap handlers**:
  - **Problem**: `local` variables were used in trap handlers which execute in script's global context, not a function
  - **Impact**: Script failed with "local: can only be used in a function" error
  - **Solution**: Replaced `local` with regular variables in trap handlers within `__trapOn()` function
  - **Files changed**: `bin/process/processPlanetNotes.sh`

- **Fixed `VACUUM ANALYZE` timeout in cleanup script**:
  - **Problem**: `statement_timeout = '30s'` was too short for `VACUUM ANALYZE` on large tables (7GB+)
  - **Impact**: `VACUUM ANALYZE` was being killed before completion
  - **Solution**: Reset `statement_timeout` to `DEFAULT` before executing `VACUUM ANALYZE`
  - **Files changed**: `sql/consolidated_cleanup.sql`

- **Fixed integrity check handling for databases without comments**:
  - **Problem**: Integrity check failed when database had no comments (e.g., after data deletion with `deleteDataAfterTimestamp.sql`)
  - **Impact**: Integrity check incorrectly flagged all notes as having gaps, preventing timestamp updates
  - **Solution**: Added special case handling to allow integrity check to pass when `total_comments_in_db = 0`
  - **Implementation**:
    - In `processAPINotes_32_insertNewNotesAndComments.sql`: If `m_total_comments_in_db = 0`, set `integrity_check_passed = TRUE` permissively
    - In `processAPINotes_34_updateLastValues.sql`: If `total_comments_in_db = 0`, set gap metrics to 0 to avoid false positives
  - **Files changed**:
    - `sql/process/processAPINotes_32_insertNewNotesAndComments.sql`
    - `sql/process/processAPINotes_34_updateLastValues.sql`

#### Performance Optimizations (2025-12-14)

- **Optimized `notesCheckVerifier` scripts for large datasets**:
  - **Problem**: Scripts used `NOT IN` with subqueries on millions of records, causing queries to run for 12+ hours
  - **Impact**: `notesCheckVerifier` was blocking database resources and preventing normal operations
  - **Solution**: Replaced `NOT IN` subqueries with `LEFT JOIN` for much better performance
  - **Performance improvement**: Reduced execution time from 12+ hours to ~14 seconds (approximately 3,000x faster)
  - **Files changed**:
    - `sql/monitor/notesCheckVerifier_51_insertMissingNotes.sql`
    - `sql/monitor/notesCheckVerifier_52_insertMissingComments.sql`
    - `sql/monitor/notesCheckVerifier_53_insertMissingTextComments.sql`
  - **Technical details**:
    - Changed from: `WHERE (note_id, sequence_action) NOT IN (SELECT ... FROM note_comments)`
    - Changed to: `LEFT JOIN note_comments ... WHERE main_c.note_id IS NULL`
    - `LEFT JOIN` can use indexes efficiently, while `NOT IN` with large subqueries requires full table scans

#### Critical API Query Bug Fix (2025-12-12)

- **Fixed incorrect API URL in `__getNewNotesFromApi` function**:
  - **Problem**: Function in `bin/lib/processAPIFunctions.sh` was using incorrect API endpoint without date filter
  - **Impact**: Daemon was downloading all notes without filtering by last update timestamp, causing it to always process the same old notes
  - **Solution**: Updated function to use correct endpoint `/notes/search.xml` with `from` parameter to filter notes by last update timestamp
  - **Files changed**: `bin/lib/processAPIFunctions.sh`

- **Fixed timestamp format bug in SQL queries**:
  - **Problem**: Timestamp queries were generating malformed dates like `2025-12-09THH24:33:04Z` (with literal "HH24" instead of actual hour)
  - **Impact**: API rejected malformed timestamps, preventing any notes from being downloaded
  - **Solution**: Fixed SQL `TO_CHAR` queries to use PostgreSQL escape string syntax (`E'...'`) for proper quote escaping
  - **Files changed**:
    - `bin/lib/processAPIFunctions.sh` (line 107)
    - `bin/process/processAPINotesDaemon.sh`

- **Fixed API timeout insufficient for large downloads** (2025-12-13):
  - **Problem**: Timeout of 30 seconds was insufficient for downloading 10,000 notes (can be 12MB+)
  - **Impact**: API calls were timing out after 5 retry attempts, preventing notes from being downloaded
  - **Solution**: Increased timeout from 30 to 120 seconds in `__retry_osm_api` call within `__getNewNotesFromApi`
  - **Files changed**: `bin/lib/processAPIFunctions.sh`

- **Fixed missing processing functions in daemon** (2025-12-13):
  - **Problem**: Daemon was calling functions (`__processXMLorPlanet`, `__insertNewNotesAndComments`, `__loadApiTextComments`, `__updateLastValue`) that were only defined in `processAPINotes.sh`, which the daemon was not loading
  - **Impact**: Daemon failed with "command not found" errors when trying to process downloaded notes
  - **Solution**:
    - Modified `processAPINotes.sh` to detect when it's being sourced (not executed) and skip main execution
    - Modified `processAPINotesDaemon.sh` to source `processAPINotes.sh` to load the required functions
  - **Files changed**:
    - `bin/process/processAPINotes.sh`
    - `bin/process/processAPINotesDaemon.sh`

- **Fixed `app.integrity_check_passed` variable not persisting between connections** (2025-12-13):
  - **Problem**: The `app.integrity_check_passed` variable was set using `set_config(..., false)`, which makes it local to the current transaction. Additionally, `__insertNewNotesAndComments` and `__updateLastValue` were executed in separate `psql` connections, so even with `set_config(..., true)`, the variable didn't persist because each `psql` call creates a new connection
  - **Impact**: In production, `max_note_timestamp` was not being updated even when notes were successfully processed, causing the daemon to repeatedly process the same notes
  - **Solution**:
    - Changed `set_config('app.integrity_check_passed', ..., false)` to `set_config('app.integrity_check_passed', ..., true)` to make the variable persist at the session level
    - Modified `__insertNewNotesAndComments` to execute both `processAPINotes_32_insertNewNotesAndComments.sql` and `processAPINotes_34_updateLastValues.sql` in the same `psql` connection, ensuring the variable persists between transactions
  - **Files changed**:
    - `sql/process/processAPINotes_32_insertNewNotesAndComments.sql`
    - `bin/process/processAPINotes.sh`
    - `bin/process/processAPINotesDaemon.sh`

- **Root cause analysis**:
  - The daemon was correctly checking for updates using the right URL format
  - However, when downloading notes, it used a simplified function that didn't include the date filter
  - Additionally, timestamp formatting had incorrect quote escaping in SQL queries
  - The timeout was too short for large downloads (10,000 notes can take 60-90 seconds)
  - The `app.integrity_check_passed` variable wasn't persisting between transactions, preventing timestamp updates
  - All issues combined prevented any new notes from being processed since December 9, 2025

### Added

#### Network Connectivity Validation (2025-12-13)

- **Added comprehensive network connectivity checks**:
  - **Change**: Implemented validation functions in `functionsProcess.sh` to check connectivity before processing
  - **Rationale**: Prevents processing failures due to network issues and provides clear error messages
  - **Implementation**:
    - Internet connectivity check
    - Planet server accessibility validation
    - OSM API access and version validation
    - Overpass API accessibility check
  - **Impact**:
    - Early detection of network issues before processing starts
    - Clear error messages for troubleshooting
    - Prevents wasted processing time on network failures
  - **Files changed**: `bin/lib/functionsProcess.sh`

#### Enhanced Hybrid Test Verification for Timestamp Updates (2025-12-13)

- **Improved test detection of timestamp update failures**:
  - **Change**: Enhanced `tests/run_processAPINotes_hybrid.sh` to verify that `max_note_timestamp` is actually updated after each execution
  - **Rationale**: Previous test only checked exit codes, which didn't catch cases where processing completed but timestamp wasn't updated (e.g., due to `set_config` persistence issues)
  - **Implementation**:
    - Added `verify_timestamp_updated()` function that compares timestamp before and after execution
    - Only fails if there are newer notes but timestamp wasn't updated (allows for cases with no new notes)
    - Provides clear error messages indicating the root cause (e.g., `app.integrity_check_passed` not persisting)
  - **Impact**: Test now catches issues like the `set_config(..., false)` bug that prevented timestamp updates in production
  - **Files changed**:
    - `tests/run_processAPINotes_hybrid.sh`

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
  - Added `docs/External_Dependencies_and_Risks.md` documenting critical external dependencies and associated risks
  - Added `docs/GDPR_Annual_Checklist.md` for annual GDPR compliance reviews
  - Updated GDPR documentation to include references to the annual checklist

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

**Important:** `processAPINotesDaemon.sh` and `processAPINotes.sh` are **independent scripts** that share code through common libraries. As of 2025-12-13, the daemon also sources `processAPINotes.sh` to load processing functions, but only when sourced (not executed directly).

**Shared libraries** (both scripts source the same files):

- `bin/lib/functionsProcess.sh` - Core processing functions
- `bin/lib/processAPIFunctions.sh` - API-specific functions (defines `__getNewNotesFromApi`, etc.)
- `lib/osm-common/commonFunctions.sh` - Common utilities and logging
- `lib/osm-common/validationFunctions.sh` - Validation functions
- `lib/osm-common/errorHandlingFunctions.sh` - Error handling
- `bin/lib/parallelProcessingFunctions.sh` - Parallel processing
- `bin/process/processAPINotes.sh` - Processing functions (loaded by daemon when sourced, not executed)

**Shared functions** (both scripts call the same library functions):

- `__getNewNotesFromApi()` - Download notes from API (from `processAPIFunctions.sh`)
- `__processXMLorPlanet()` - Process XML data (from `processAPINotes.sh`)
- `__insertNewNotesAndComments()` - Insert data into database (from `processAPINotes.sh`)
- `__loadApiTextComments()` - Load text comments (from `processAPINotes.sh`)
- `__updateLastValue()` - Update last processed timestamp (from `processAPINotes.sh`)
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
