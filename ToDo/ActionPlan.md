# Action Plan and Progress Tracking

Project: OSM-Notes-Ingestion  
Version: 2025-10-21  
Status: In Progress

---

## How to Use This Document

- [ ] Not started
- [🔄] In progress
- [✅] Completed
- [❌] Cancelled/Not needed

**Priority Levels:**
- 🔴 **CRITICAL**: Bugs and errors affecting functionality
- 🟡 **HIGH**: Important improvements for stability
- 🟠 **MEDIUM**: Functionality improvements
- 🟢 **LOW**: New features and enhancements

---

## 🔴 CRITICAL PRIORITY

### Database Errors (from errors.md)

#### Foreign Key Violations
- [ ] **Issue #1**: Fix foreign key violation in `note_comments_text` when NeisBot writes duplicate comments
  - **Example**: Note 3037001
  - **Root cause**: Duplicate comments with same text
  - **Solution**: Add deduplication logic before insert
  - **Files**: SQL insert procedures

- [ ] **Issue #2**: Handle desynchronization between notes and comments
  - **Root cause**: If comment insertion fails, sequence gaps are created
  - **Solution**: Implement transaction rollback or separate max tracking
  - **Files**: processAPINotes procedures

- [✅] **Issue #3**: Fix "Trying to reopen an opened note" error
  - **Example**: Note 3924749 - open reopened
  - **Root cause**: OSM API allows invalid state transitions
  - **Solution**: Improved documentation and graceful handling
  - **Files**: sql/process/processPlanetNotes_22_createBaseTables_tables.sql
  - **Completed**: 2025-10-21 - Enhanced trigger to handle invalid transitions gracefully
  - **Changes**: Improved logging, clear documentation of valid/invalid transitions
  - **Behavior**: Invalid transitions logged as WARNING (NOTICE) but don't fail transaction
  - **Impact**: Prevents transaction failures, maintains OSM API data integrity

- [ ] **Issue #4**: NULL value in `recent_opened_dimension_id_date`
  - **Example**: Note 4172438, sequence 2
  - **Root cause**: max_processed_timestamp greater than uninserted notes
  - **Solution**: Process notes in staging that aren't in facts but are older than max_processed
  - **Files**: sql/dwh/Staging_61_loadNotes.sql

#### Geometry Errors
- [✅] **Issue #5**: Fix NULL geometry in countries update
  - **Example**: Country 184818 (Jordan/الأردن)
  - **Root cause**: ST_Union returning NULL for invalid geometries
  - **Solution**: Add geometry validation before insert
  - **Files**: bin/functionsProcess.sh - __processBoundary function
  - **Completed**: 2025-10-21 - Geometry validation before INSERT implemented
  - **Validates**: ST_Union result is NOT NULL before inserting
  - **Diagnostics**: Logs geometry count, validity check, and failure reasons
  - **Impact**: Prevents NULL constraint violations, provides clear error messages

### Error Handling (from prompts)
- [ ] **Issue #6**: Implement robust network failure handling
  - **Current**: Downloads fail without retry
  - **Solution**: Add retry logic with exponential backoff
  - **Files**: All download functions

- [ ] **Issue #7**: Add retry logic for API calls
  - **Current**: Partial implementation
  - **Solution**: Standardize retry mechanism across all API calls
  - **Files**: functionsProcess.sh

- [ ] **Issue #8**: Implement rollback mechanism for failed operations
  - **Current**: No transaction rollback
  - **Solution**: Add trap-based cleanup and DB rollback
  - **Files**: All main scripts

### Security
- [ ] **Issue #9**: Fix potential SQL injection vulnerabilities
  - **Audit all**: Dynamic SQL construction
  - **Solution**: Use parameterized queries or proper escaping
  - **Files**: All SQL-generating bash scripts

- [ ] **Issue #10**: Add input sanitization
  - **Current**: User inputs not validated
  - **Solution**: Sanitize all external inputs
  - **Files**: All scripts accepting parameters

- [ ] **Issue #11**: Secure credentials management
  - **Audit**: Check for exposed credentials in code/logs
  - **Solution**: Use environment variables or secure vault
  - **Files**: Database connection scripts

---

## 🟡 HIGH PRIORITY

### Code TODOs
- [✅] **Code TODO #1**: Implement proper environment detection
  - **File**: bin/functionsProcess.sh:1942-1948
  - **Issue**: Need to detect test vs production for exit/return
  - **Solution**: Add environment variable check (TEST_MODE, BATS_TEST_NAME)
  - **Completed**: 2025-10-21 - Uses exit in production, return in tests

- [✅] **Code TODO #2**: Clarify and document SQL query logic
  - **File**: sql/monitor/notesCheckVerifier-report.sql:118-125
  - **Comment**: "TODO no entiendo esto" on closed_at filter
  - **Solution**: Document why `closed_at < NOW()::DATE` is used
  - **Completed**: 2025-10-21 - Documented Planet vs API comparison logic
  - **Explanation**: Excludes notes closed today from API to match yesterday's Planet snapshot

### Validations (from prompts)
- [✅] **Validation #1**: Validate properties file parameters
  - **Check**: Integer values are positive integers
  - **Extend**: All parameters with appropriate validators
  - **Files**: bin/functionsProcess.sh - __validate_properties function
  - **Completed**: 2025-10-21 - Comprehensive validation implemented
  - **Validates**: DBNAME, DB_USER, EMAILS, URLs, numeric params, booleans
  - **Integration**: Called automatically in __checkPrereqsCommands

- [✅] **Validation #2**: Add database connection check in checkPrereqs
  - **Purpose**: Fail early if DB is unreachable
  - **Files**: checkPrereqs function, updateCountries.sh, assignCountriesToNotes.sh
  - **Completed**: 2025-10-21 - Added __checkPrereqsCommands to all scripts using DB
  - **Impact**: updateCountries.sh and assignCountriesToNotes.sh now validate DB connection
  - **Note**: Validation already existed in __checkPrereqsCommands, just needed integration

- [✅] **Validation #3**: Validate XSLT files before transformation
  - **Check**: XSLT syntax and structure
  - **Tool**: xmllint or xsltproc --valid
  - **Files**: Before CSV transformation
  - **Completed**: 2025-10-21 - CANCELLED: XSLT code eliminated
  - **Action Taken**: Removed all XSLT legacy code (~1,354 lines)
  - **Replaced with**: AWK extraction (faster, simpler, less dependencies)
  - **Impact**: Consistent XML→CSV processing, removed xsltproc dependency

- [✅] **Validation #4**: Check disk space before downloads
  - **Check for**: Planet file download, expansion, CSV generation
  - **Check for**: Boundary downloads
  - **Files**: bin/functionsProcess.sh - __check_disk_space function
  - **Completed**: 2025-10-21 - Comprehensive disk space validation implemented
  - **Integration**: Integrated in __downloadPlanetNotes, __processCountries, __processMaritimes
  - **Estimates**: Planet 20GB, Countries 4GB, Maritimes 2.5GB
  - **Features**: Warnings at 80% usage, detailed error messages with shortfall calculation

- [ ] **Validation #5**: Validate ISO 8601 date format in XML
  - **Purpose**: Ensure date compatibility
  - **Files**: XML processing functions

- [✅] **Validation #6**: Validate generated CSV files
  - **Check**: Escaped quotes, multivalue fields
  - **Tool**: Custom validator __validate_csv_structure
  - **Files**: After AWK transformation, before DB load
  - **Completed**: 2025-10-21 - Comprehensive CSV validation implemented
  - **Validates**: Column count, quote escaping, structure integrity
  - **Integration**: Integrated in all CSV generation functions (API parallel, API sequential)
  - **Features**: Samples first 100 lines, detailed error reporting, >10% threshold for failure

### Base Monitoring (from ToDos.md)
- [ ] **Monitor #1**: Fix differences identified by monitor script
  - **File**: Monitor scripts
  - **Action**: Investigate and resolve discrepancies

- [ ] **Monitor #2**: Send email notification if processPlanet base fails
  - **Condition**: Only on failure or next execution after failure
  - **Implementation**: Email notification function
  - **Files**: processPlanetNotes script

### Sequence Number Optimization (from prompts)
- [ ] **Optimization #1**: Incorporate sequence number in XSLT transformation
  - **Current**: Assigned in DB after transformation
  - **Proposed**: Include in XSLT to CSV transformation
  - **Impact**: Simplify code, reduce DB operations
  - **Files**: XSLT files, processAPINotes, processPlanetNotes

---

## 🟠 MEDIUM PRIORITY

### ETL Improvements (from ToDos.md)

#### Reporting
- [ ] **ETL #1**: Generate change report when loading ETL
  - **Replace**: SELECT statements with exports
  - **Show**: Detailed changes identified
  - **Files**: ETL scripts

- [ ] **ETL #2**: Count hashtags in notes during ETL
  - **Implementation**: Parse note text for hashtags
  - **Store**: In appropriate tables

- [ ] **ETL #3**: Calculate and store hashtag count in FACTS
  - **Column**: Number of hashtags per note
  - **Files**: Staging load procedures

- [ ] **ETL #4**: Calculate currently open notes
  - **Breakdowns**: By user, total
  - **Storage**: DWH summary tables

- [ ] **ETL #5**: Maintain count of open notes per country
  - **Update**: On each ETL run
  - **Files**: Country dimension updates

- [ ] **ETL #6**: Use comment sequence in facts table
  - **Current status**: Check if already implemented
  - **Files**: Facts table structure

#### Refactoring
- [ ] **ETL #7**: Refactor CREATE and INITIAL in Staging
  - **Issue**: Common code duplication
  - **Solution**: Extract common logic to shared function
  - **Files**: Staging scripts

- [ ] **ETL #8**: Use separate database for DWH
  - **Reason**: Separation of concerns, performance
  - **Migration**: Move DWH schema to new DB
  - **Files**: All DWH scripts, connection configs

- [ ] **ETL #9**: Handle country changes for notes
  - **Issue**: When boundaries update, notes may change country
  - **Solution**: Update dimension and affected datamarts
  - **Consider**: Recalculate all affected star schema values
  - **Files**: UpdateCountries, dimension updates

### Monitor ETL (from ToDos.md)
- [ ] **Monitor ETL #1**: Handle reopened notes in DWH
  - **Issue**: Closed flag not removed on reopen (UPDATE is expensive)
  - **Alternative**: Process differently, maintain max action
  - **Files**: DWH update procedures

- [ ] **Monitor ETL #2**: Verify comment count equals actions in facts
  - **Check**: note_comments count = facts actions count
  - **Similar**: Validation for datamarts
  - **Files**: Monitor scripts

- [ ] **Monitor ETL #3**: Fix datamart reload on same day
  - **Issue**: Reloading notes from same day
  - **Status**: May already be fixed
  - **Verify**: Test datamart reload behavior
  - **Files**: Datamart loading scripts

### Scalability (from prompts)
- [ ] **Scale #1**: Implement parallel processing
  - **Current**: Sequential processing
  - **Target**: Note processing, boundary updates
  - **Tools**: GNU parallel or custom implementation
  - **Files**: Main processing scripts

- [ ] **Scale #2**: Add memory control for large files
  - **Issue**: Large XML/CSV files can exhaust memory
  - **Solution**: Stream processing, chunking
  - **Files**: File processing functions

- [ ] **Scale #3**: Add checkpointing for long processes
  - **Purpose**: Resume after interruption
  - **Implementation**: Save state periodically
  - **Files**: processPlanetNotes, updateCountries

---

## 🟢 LOW PRIORITY

### Datamarts - Applications and Hashtags

- [ ] **DM #1**: Show applications used to create notes
  - **Source**: Parse comment text
  - **Display**: By user and country
  - **Files**: Datamart user/country scripts

- [ ] **DM #2**: Complete hashtag analyzer
  - [✅] Include hashtags in note (DONE)
  - [ ] Show most used hashtags by country
  - [ ] Show most used hashtags for notes
  - [ ] Filter notes by hashtag
  - **Files**: Datamart scripts, web interface

- [ ] **DM #3**: Adjust hashtag queries for comment sequence
  - **Link**: Hashtags to specific comment sequence
  - **Files**: Hashtag query procedures

- [ ] **DM #4**: Define and assign badges
  - **Examples**: Top contributor, quick responder, etc.
  - **Storage**: User dimension or separate table
  - **Files**: Datamart user calculations

- [ ] **DM #5**: Parallelize user datamart processing
  - **Issue**: Takes many hours currently
  - **Solution**: Process users in parallel batches
  - **Files**: Datamart user processing

### Datamarts - Quality Metrics

- [ ] **DM #6**: Implement note quality scoring
  - **Bad**: < 5 characters
  - **Regular**: < 10 characters
  - **Complex**: > 200 characters
  - **Detailed**: > 500 characters
  - **Files**: Note dimension, facts

- [ ] **DM #7**: Calculate "time to resolve notes"
  - **Metric**: closed_at - created_at for closed notes
  - **Storage**: Use in datamarts
  - **Files**: Facts, datamart calculations

- [ ] **DM #8**: Identify day with most notes created
  - **Aggregation**: By country, global
  - **Files**: Datamart reports

- [ ] **DM #9**: Identify hour with most notes created
  - **Dimension**: Already have hour_of_week
  - **Files**: Datamart reports

### Datamarts - Open Notes Analysis

- [ ] **DM #10**: Create table of open notes by year
  - **Columns**: Years from 2013 to current
  - **Rows**: Countries
  - **Values**: Notes created in year X still open
  - **Files**: New datamart report

- [ ] **DM #11**: Chart showing evolution of open notes by year
  - **Axes**: Month, note count
  - **Purpose**: Show aging open notes
  - **Tool**: Visualization layer

- [ ] **DM #12**: Show notes that took longest to close by country
  - **Metric**: Time from creation to closure
  - **Display**: Top N per country
  - **Files**: Country datamart

- [ ] **DM #13**: Show average note resolution time
  - **Historical**: All-time average
  - **By year**: Show performance trends
  - **Files**: Summary reports

- [ ] **DM #14**: Show most recent comment timestamp
  - **Purpose**: "Last DB update" indicator
  - **Files**: Summary metadata

- [ ] **DM #15**: Show count of currently open notes
  - **Breakdowns**: By country, global
  - **Files**: Summary reports

### Datamarts - Rankings

- [ ] **DM #16**: Create rankings with time periods
  - **Periods**: All-time, last year, last month, today
  - **Categories**: Most opened, closed, commented, reopened
  - **Top**: 100 users
  - **Files**: Ranking datamarts

- [ ] **DM #17**: Create country ranking (Neis-style)
  - **Metrics**: Opened, closed, currently open, rate
  - **Files**: Country datamart

- [ ] **DM #18**: World user ranking
  - **Categories**: Most opened, most closed
  - **Files**: User ranking global

- [ ] **DM #19**: Average comments per note
  - **Global**: All notes
  - **By country**: Per country statistics
  - **Files**: Summary statistics

### Visualizer (from ToDos.md)

- [ ] **VIZ #1**: Deploy visualization tool
  - **Options**: Metabase (from CapRover), Redash
  - **Setup**: Container deployment
  - **Files**: Deployment configs

- [ ] **VIZ #2**: Create stored procedures for profile queries
  - **Purpose**: Track which profiles are visited
  - **Output**: JSON for static HTML generator
  - **Files**: Profile query procedures

- [ ] **VIZ #3**: Display special accounts differently
  - **Example**: <https://www.openstreetmap.org/user/ContributionReviewer>
  - **Files**: Profile generation

- [ ] **VIZ #4**: Add links to OSM and API
  - **Purpose**: Quick access to details
  - **Note**: API shows hours but no map
  - **Files**: HTML templates

- [ ] **VIZ #5**: Display current database server time
  - **Files**: Web interface

- [ ] **VIZ #6**: Display last processing time
  - **Source**: Processing metadata
  - **Files**: Web interface

- [ ] **VIZ #7**: Implement GitHub-style contribution tiles
  - **Reference**: <https://github.com/sallar/github-contributions-canvas>
  - **Files**: Visualization scripts

### Other Features

- [ ] **OTHER #1**: Export all or last N notes for user
  - **Scope**: Last 10,000 open + 10,000 closed
  - **Format**: CSV, JSON
  - **Files**: Export procedures

- [ ] **OTHER #2**: Export database in CSV format
  - **Purpose**: Public publication
  - **Automation**: Periodic export and publish
  - **Files**: Export scripts

- [ ] **OTHER #3**: Create animated top 10 chart
  - **Style**: Racing bar chart over time
  - **Categories**: Open/closed rankings
  - **Tool**: Data visualization library
  - **Files**: Visualization scripts

### Documentation

- [ ] **DOC #1**: Create activity curve diagram
  - **Style**: GitHub tiles visualization
  - **Data**: Last year's activities
  - **Files**: Documentation

- [ ] **DOC #2**: Create component diagram
  - **Focus**: Information flow
  - **Show**: Where each component gets/stores data
  - **Files**: Documentation

- [ ] **DOC #3**: Verify BACKUP is only for country downloads
  - **Note location**: Should be by default
  - **Files**: Configuration documentation

---

## 📊 CODE REFACTORING (from prompts)

### Entry Points Simplification

- [ ] **REF #1**: Enforce standardized entry points
  - **Allowed**: ProcessAPINotes, CheckNotes, UpdateCountries, ETL, profile
  - **Exception**: processPlanetNotes (divides API vs Planet)
  - **Action**: Remove other entry points
  - **Files**: All main scripts

- [ ] **REF #2**: Standardize environment variables
  - **Common**: CLEAN, log level
  - **Per script**: ProcessAPINotes, CheckNotes, UpdateCountries, ETL, profile
  - **Remove**: Other options/variables
  - **Files**: All scripts

- [ ] **REF #3**: Standardize parameters
  - **No params**: ProcessAPINotes, CheckNotes, UpdateCountries, ETL
  - **With params**: profile (type and name)
  - **Remove**: Other parameter options
  - **Files**: All scripts

### Code Cleanup

- [ ] **REF #4**: Remove unused variables
  - **Tool**: shellcheck analysis
  - **Action**: Remove or document why kept
  - **Files**: All bash scripts

- [ ] **REF #5**: Remove unused functions
  - **Verify**: All functions used in defined flows
  - **Remove**: Functions not part of flows or tests
  - **Files**: All bash scripts

- [ ] **REF #6**: Remove function options not in flows
  - **Example**: ENABLE_PROFILING and associated logic
  - **Action**: Simplify to only support defined flows
  - **Files**: All bash scripts

- [ ] **REF #7**: Remove orphaned files
  - **Keep**: Files used by flows or test suites
  - **Keep**: Documentation files
  - **Remove**: Everything else
  - **Files**: Entire repository

- [ ] **REF #8**: Remove wrapper functions
  - **Issue**: Functions that only call another function
  - **Action**: Redirect calls to actual implementation
  - **Files**: All bash scripts

- [ ] **REF #9**: Remove legacy and backward compatibility
  - **Reason**: No v1.0 released yet, project is unified
  - **Action**: Remove legacy functions and docs
  - **Files**: All scripts and documentation

### Code Style and Format

- [ ] **REF #10**: Fix all shellcheck errors
  - **Command**: `shellcheck -x -o all`
  - **Files**: All bash scripts

- [ ] **REF #11**: Apply shfmt formatting
  - **Command**: `shfmt -w -i 1 -sr -bn`
  - **Files**: All bash scripts

- [ ] **REF #12**: Ensure all variables are UPPERCASE
  - **Exception**: Loop variables can be lowercase if local
  - **Files**: All bash scripts

- [ ] **REF #13**: Ensure all functions start with `__` and lowercase
  - **Pattern**: `__function_name`
  - **Files**: All bash scripts

- [ ] **REF #14**: Ensure single return per function
  - **Refactor**: Multiple returns into single exit point
  - **Files**: All bash scripts

- [ ] **REF #15**: Rename scripts for clarity
  - **Goal**: Self-documenting names
  - **Files**: Scripts with unclear names

- [ ] **REF #16**: Reorganize file locations
  - **Group**: Support scripts (libraries) together
  - **Structure**: Logical directory organization
  - **Files**: Entire repository

### Testing

- [ ] **TEST #1**: Associate all test files to suites
  - **Action**: Group in appropriate suite or delete
  - **Files**: tests/ directory

- [ ] **TEST #2**: Remove redundant test suites
  - **Check**: Each test should be unique
  - **Files**: tests/ directory

- [ ] **TEST #3**: Document test execution matrix
  - **Dimensions**: Type (all/unit/integration/quality/dwh)
  - **Dimensions**: Mode (host/mock/ci/docker)
  - **Show**: Number of scripts per combination
  - **Files**: Test documentation

- [ ] **TEST #4**: Synchronize test documentation with code
  - **Check**: Documentation reflects actual tests
  - **Files**: Test README files

### Documentation

- [ ] **DOC #4**: Add function header documentation
  - **Include**: Purpose, parameters, return values, exit codes
  - **Files**: All bash scripts

- [ ] **DOC #5**: Update README files to reflect current code
  - **Check**: Main README and directory READMEs
  - **Ensure**: Well-structured, includes all options
  - **Files**: All README.md files

- [ ] **DOC #6**: Document test suites
  - **Show**: Test sets and their purposes
  - **Files**: Test documentation

- [ ] **DOC #7**: Review and update code comments
  - **Check**: Comments match code
  - **Check**: Comments are well-positioned
  - **Check**: Comments add value
  - **Files**: All code files

- [ ] **DOC #8**: Ensure documentation is non-redundant
  - **Strategy**: Each file adds depth, not repetition
  - **Files**: All documentation

### Logging

- [ ] **LOG #1**: Review log messages for usefulness
  - **Remove**: Noise messages
  - **Keep**: Valuable information
  - **Files**: All scripts

- [ ] **LOG #2**: Verify log levels are appropriate
  - **ERROR**: Errors and critical messages
  - **INFO**: Information and execution tracking
  - **DEBUG**: Detailed execution information
  - **TRACE**: Low-level details
  - **Files**: All scripts

- [ ] **LOG #3**: Implement separate logs for parallel executions
  - **Purpose**: Independent review of parallel processes
  - **Files**: Parallel processing scripts

### Other Refactoring

- [ ] **OTHER #4**: Ensure all temp files under TMP_DIR
  - **Issue**: No temp files in other directories
  - **Action**: Centralize in TMP_DIR
  - **Files**: All scripts

- [ ] **OTHER #5**: Declare all exit codes as constants
  - **Location**: Single place for all codes
  - **Purpose**: Know what codes are used
  - **Files**: Constants file

- [ ] **OTHER #6**: Validate all commands in checkPrereqs
  - **Purpose**: Fail early if dependency missing
  - **Check**: Every external command used
  - **Files**: checkPrereqs function

---

## 📈 Progress Summary

### Statistics
- **Total Items**: 121
- **Critical**: 11 (9%)
- **High**: 14 (12%)
- **Medium**: 17 (14%)
- **Low**: 35 (29%)
- **Refactoring**: 44 (36%)

### Status Overview
- [✅] Completed: 10 (8.3%)
  - DM #2: Include hashtags in note
  - Code TODO #1: Implement environment detection
  - Code TODO #2: Clarify SQL query logic
  - Validation #1: Validate properties file parameters
  - Validation #2: Add database connection check
  - Validation #3: XSLT validation (cancelled - code eliminated)
  - Validation #4: Check disk space before downloads
  - Validation #6: Validate CSV generated files
  - Issue #5: Fix NULL geometry in countries update
  - Issue #3: Fix "Trying to reopen an opened note"
- [ ] Not Started: 111 (91.7%)
- [🔄] In Progress: 0
- [❌] Cancelled: 0

### By Category
- Database Errors: 5 items
- Error Handling: 3 items
- Security: 3 items
- Validations: 6 items
- Base Monitoring: 2 items
- ETL: 9 items
- Monitor ETL: 3 items
- Scalability: 3 items
- Datamarts: 19 items
- Visualizer: 7 items
- Documentation: 4 items
- Code Refactoring: 44 items
- Other: 3 items

---

## 🎯 Recommended Next Steps

### Sprint 1 (Week 1-2): Critical Bugs
1. Start with database foreign key violations
2. Implement environment detection TODO
3. Fix geometry NULL issues
4. Add basic retry logic

### Sprint 2 (Week 3-4): High Priority Validations
1. Implement all validation checks
2. Add database connection validation
3. Disk space checks
4. CSV validation

### Sprint 3 (Month 2): ETL and Monitoring
1. ETL improvements
2. Monitor enhancements
3. Email notifications

### Sprint 4 (Month 3): Scalability and Refactoring
1. Parallel processing
2. Code cleanup begins
3. Remove unused code

### Sprint 5+ (Month 4+): Features and Polish
1. Datamart enhancements
2. Visualizer implementation
3. Continue refactoring
4. Documentation updates

---

## Notes

- This document should be updated as tasks are completed
- Mark [🔄] when starting work on an item
- Mark [✅] when completed
- Add notes on blockers or dependencies
- Reference GitHub issues when created
- Update statistics after significant progress

---

**Last Updated**: 2025-10-21  
**Updated By**: AI Assistant (initial creation)

