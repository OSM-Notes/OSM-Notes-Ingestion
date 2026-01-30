# SQL Analysis Scripts

This directory contains SQL scripts for performance analysis and validation of database optimizations.

## Overview

These scripts help validate that performance optimizations are working correctly by checking query execution plans, timing, and index usage. They focus on validating **CURRENT performance** rather than comparing with old implementations, making them useful long-term for performance monitoring.

## ⚠️ Resource-Intensive Scripts

Some scripts are **very resource-intensive** and should be run **monthly** (not daily or weekly):

| Script | Execution Time | Resource Usage | Reason |
|--------|---------------|----------------|--------|
| `analyze_integrity_verification_performance.sql` | **15-30+ minutes** | ⚠️ **HIGH** | Uses `ST_Contains` on complex geometries with millions of notes |
| `analyze_country_reassignment_performance.sql` | **5-15 minutes** | ⚠️ **MEDIUM-HIGH** | Uses `ST_Intersects` spatial queries on large datasets |
| Other scripts | < 1 minute each | ✅ **LOW** | Fast queries, minimal resource usage |

**Recommendation**: Run `analyzeDatabasePerformance.sh` **monthly** (first day of month, 2-4 AM) to avoid impacting production performance.

## Scripts

### `analyze_integrity_verification_performance.sql`

**Purpose**: Validates performance of integrity verification queries.

**⚠️ WARNING: RESOURCE INTENSIVE SCRIPT**

This script is **very resource-intensive** and can take **15-30+ minutes** to execute on large databases. It performs expensive spatial operations (`ST_Contains`) on complex geometries.

**What it analyzes:**
- Integrity verification query performance (validates that coordinates belong to assigned country)
- Composite index `notes_country_note_id` usage
- Query execution plans (EXPLAIN ANALYZE)
- Execution times against performance thresholds
- Buffer usage and I/O statistics
- Scalability with different data sizes

**Usage:**

```bash
psql -d "${DBNAME}" -f sql/analysis/analyze_integrity_verification_performance.sql
```

**Prerequisites:**
- Tables `notes` and `countries` must exist
- Index `notes_country_note_id` should exist
- PostGIS extension enabled

**Performance Thresholds:**
- 5000 notes: < 1ms execution time
- 100000 notes: < 10ms execution time

**⚠️ Performance Considerations:**
- **Execution time**: Can take 15-30+ minutes on production databases with millions of notes
- **Resource usage**: High CPU and memory consumption due to spatial geometry operations
- **Recommendation**: Run only during low-traffic periods (e.g., 2-4 AM)
- **Frequency**: Monthly execution is sufficient for monitoring purposes

---

### `analyze_partition_loading_performance.sql`

**Purpose**: Validates performance of partition loading operations (COPY masivo).

**What it analyzes:**
- COPY operation efficiency (simulated with INSERT)
- UPDATE part_id performance on partitioned tables
- Partition table statistics (sizes, row counts)
- Index usage on partition tables
- Buffer usage and I/O statistics

**Usage:**

```bash
psql -d "${DBNAME}" -f sql/analysis/analyze_partition_loading_performance.sql
```

**Prerequisites:**
- Partition tables must exist (`notes_sync_part_*`, etc.)
- Tables used during Planet notes processing

**Performance Thresholds:**
- 1000 row INSERT: < 100ms
- 1000 row UPDATE: < 50ms

**Related Operations:**
- `sql/process/processPlanetNotes_30_loadPartitionedSyncNotes.sql`

---

### `analyze_partition_consolidation_performance.sql`

**Purpose**: Validates performance of partition consolidation operations (INSERT masivo).

**What it analyzes:**
- INSERT FROM partition performance
- INSERT with sequence generation overhead
- INSERT with EXISTS check (FK validation)
- Consolidation loop performance (dynamic SQL)
- Table statistics after consolidation

**Usage:**

```bash
psql -d "${DBNAME}" -f sql/analysis/analyze_partition_consolidation_performance.sql
```

**Prerequisites:**
- Partition tables and sync tables must exist
- Sequences for comments must exist

**Performance Thresholds:**
- 1000 row INSERT: < 200ms
- 1000 row INSERT with EXISTS: < 300ms

**Related Operations:**
- `sql/process/processPlanetNotes_31_consolidatePartitions.sql`

---

### `analyze_api_insertion_performance.sql`

**Purpose**: Validates performance of API note insertion operations (cursor/batch).

**What it analyzes:**
- Stored procedure call performance (`insert_note()`)
- Batch INSERT vs procedure call comparison
- Cursor overhead and batch processing efficiency
- Transaction batch size optimization
- API table statistics

**Usage:**

```bash
psql -d "${DBNAME}" -f sql/analysis/analyze_api_insertion_performance.sql
```

**Prerequisites:**
- API tables must exist (`notes_api`, `note_comments_api`, etc.)
- Procedure `insert_note()` must exist

**Performance Thresholds:**
- Single procedure call: < 50ms
- 100 row batch INSERT: < 100ms

**Related Operations:**
- `sql/process/processAPINotes_31_insertNewNotesAndComments.sql`

---

### `analyze_country_assignment_performance.sql`

**Purpose**: Validates performance of country assignment operations (UPDATE masivo).

**What it analyzes:**
- UPDATE with `get_country()` function performance
- Function execution time and spatial query efficiency
- Chunk-based assignment performance
- Spatial index usage validation
- Notes table index usage for assignment

**Usage:**

```bash
psql -d "${DBNAME}" -f sql/analysis/analyze_country_assignment_performance.sql
```

**Prerequisites:**
- Tables `notes` and `countries` must exist
- Function `get_country()` must exist
- PostGIS extension enabled

**Performance Thresholds:**
- Single `get_country()` call: < 10ms
- 100 row UPDATE: < 500ms

**Related Operations:**
- `sql/functionsProcess_32_assignCountryToNotesChunk.sql`

---

### `analyze_country_reassignment_performance.sql`

**Purpose**: Validates performance of country reassignment operations (consultas espaciales).

**What it analyzes:**
- UPDATE with `ST_Intersects` spatial queries
- Bounding box vs full geometry comparison
- Updated countries identification
- Spatial index usage for reassignment
- Notes table spatial index usage

**Usage:**

```bash
psql -d "${DBNAME}" -f sql/analysis/analyze_country_reassignment_performance.sql
```

**Prerequisites:**
- Tables `notes` and `countries` must exist
- Function `get_country()` must exist
- PostGIS extension enabled
- Spatial indexes on `countries` table

**Performance Thresholds:**
- 100 row UPDATE with bounding box: < 1000ms

**Related Operations:**
- `sql/functionsProcess_36_reassignAffectedNotes.sql`

---

## General Usage

### Automated Execution (Recommended)

**Use the automated script** `bin/monitor/analyzeDatabasePerformance.sh` to run all analysis scripts and generate a comprehensive report:

#### Basic Usage

```bash
# Execute with database from properties
./bin/monitor/analyzeDatabasePerformance.sh

# Execute with specific database
./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes

# Execute with detailed output
./bin/monitor/analyzeDatabasePerformance.sh --verbose
```

#### Options

- `--db DATABASE`: Specifies the database (overrides DBNAME from properties)
- `--output DIR`: Output directory for results (default: `/tmp/analyzeDatabasePerformance_*/analysis_results`)
- `--verbose`: Shows detailed output from each analysis script
- `--help`: Shows help

#### Output

The script generates:

1. **Console report**: Summary with color codes
   - ✓ Green: Scripts that passed
   - ⚠ Yellow: Scripts with warnings
   - ✗ Red: Scripts that failed

2. **Report file**: `performance_report.txt` in the output directory
   - Executive summary
   - Status of each script
   - List of detailed output files

3. **Individual files**: One `.txt` file per executed script
   - Contains all SQL script output
   - Includes EXPLAIN ANALYZE, statistics, etc.

#### Example Output

```
==============================================================================
DATABASE PERFORMANCE ANALYSIS
==============================================================================
Database: osm_notes
Output directory: /tmp/analyzeDatabasePerformance_12345/analysis_results
==============================================================================

Running analysis: analyze_integrity_verification_performance.sql
  ✓ analyze_integrity_verification_performance.sql - PASSED
Running analysis: analyze_partition_loading_performance.sql
  ✓ analyze_partition_loading_performance.sql - PASSED
Running analysis: analyze_api_insertion_performance.sql
  ⚠ analyze_api_insertion_performance.sql - WARNING

==============================================================================
DATABASE PERFORMANCE ANALYSIS REPORT
==============================================================================
Database: osm_notes
Date: 2025-11-25 10:30:45
Total Scripts: 6

Results Summary:
  Passed:   4 (✓)
  Warnings: 1 (⚠)
  Failed:   1 (✗)
```

#### Exit Codes

- `0`: Analysis completed (may have warnings)
- `1`: Analysis completed with errors

#### Result Interpretation

**Status: PASSED ✓**
- All performance thresholds are met
- Indexes are being used correctly
- No problems detected

**Status: WARNING ⚠**
- Warnings detected but no critical errors
- May indicate:
  - Sequential scan usage instead of index scan
  - Execution times near thresholds
  - Unused indexes (normal if queries haven't been executed yet)

**Status: FAILED ✗**
- Critical errors detected
- May indicate:
  - Missing indexes
  - SQL execution errors
  - Connectivity problems

#### Regular Scheduling

**⚠️ IMPORTANT: Monthly Execution Recommended**

Due to resource-intensive scripts (especially `analyze_integrity_verification_performance.sql`), **monthly execution is recommended** rather than daily or weekly. The script can take 30+ minutes and consume significant database resources.

For continuous monitoring, schedule monthly execution:

```bash
# Crontab to run monthly (first day of month at 2 AM)
# Note: Script creates its own log. Redirection is optional.
# Use logs directory in home (no special permissions required)
0 2 1 * * /path/to/project/bin/monitor/analyzeDatabasePerformance.sh --db osm_notes >> ~/logs/db_performance_monthly_$(date +\%Y\%m\%d).log 2>&1

# Alternative: Without redirection (script creates its own log)
0 2 1 * * /path/to/project/bin/monitor/analyzeDatabasePerformance.sh --db osm_notes >/dev/null 2>&1
```

**⚠️ Not Recommended:**
- Daily execution: Too resource-intensive, unnecessary for monitoring
- Weekly execution: Still too frequent for the value provided
- During peak hours: Can impact production performance

#### Monitoring Integration

The script can be integrated with monitoring systems:

```bash
# Execute and send alert if there are failures
if ! ./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes; then
  # Send alert (email, Slack, etc.)
  echo "Performance analysis failed" | mail -s "DB Performance Alert" admin@example.com
fi
```

#### Troubleshooting

**Error: "Cannot connect to database"**
- Verify that `DBNAME` is configured in `etc/properties.sh`
- Verify PostgreSQL connection permissions
- Verify that the database exists

**Error: "No analysis scripts found"**
- Verify that the `sql/analysis/` directory exists
- Verify that scripts have `.sql` extension

**Scripts fail with SQL errors**
- Verify that all required tables exist
- Verify that necessary extensions are installed (PostGIS, etc.)
- Review individual output files for details

### Manual Execution

You can also run scripts individually:

```bash
# Run all analysis scripts and save output
for script in sql/analysis/analyze_*.sql; do
  echo "Running $script..."
  psql -d "${DBNAME}" -f "$script" > "${script%.sql}_results.txt" 2>&1
done
```

### Interpreting Results

All scripts follow a similar pattern:

1. **TEST 1-N**: Individual performance tests with EXPLAIN ANALYZE
2. **Performance Benchmarks**: Execution time validation against thresholds
3. **Statistics**: Table/index statistics and health checks
4. **Final Validation Summary**: Automated checks with `RAISE NOTICE` output

**What to look for:**

- ✅ **Good**: Execution times meet thresholds, indexes are being used, query plans are efficient
- ⚠️ **Warning**: Performance below thresholds - check indexes, statistics, table sizes
- ❌ **Bad**: Sequential scans instead of index scans, missing indexes, very slow execution

### Common Issues and Solutions

**Issue**: Sequential scans instead of index scans
- **Solution**: Check if indexes exist, run `ANALYZE` on tables, verify query conditions match index

**Issue**: Slow execution times
- **Solution**: Check table statistics (`ANALYZE`), verify indexes exist, check for dead rows (`VACUUM`)

**Issue**: Missing indexes
- **Solution**: Check creation scripts, verify indexes were created successfully

**Issue**: High dead row percentage
- **Solution**: Run `VACUUM ANALYZE` on affected tables

---

## Summary

All analysis scripts follow the same pattern:

1. **Performance Tests**: EXPLAIN ANALYZE queries to validate execution plans
2. **Benchmarks**: Execution time validation against defined thresholds
3. **Statistics**: Table/index health checks and usage statistics
4. **Automated Validation**: `DO $$` blocks with `RAISE NOTICE` for summary

**Key Points:**

- All scripts validate **CURRENT performance**, not comparisons with old code
- Scripts are designed for **long-term monitoring** and regression detection
- Each script includes **automated validation** with clear pass/fail indicators
- Scripts use **ROLLBACK** to avoid modifying production data during analysis
- **✅ SAFE FOR PRODUCTION**: All scripts are read-only or use ROLLBACK

## Production Safety

**All analysis scripts are safe to run on production databases:**

- ✅ **Read-only operations**: Most queries are SELECT, EXPLAIN, etc.
- ✅ **ROLLBACK protection**: Scripts that modify data use `ROLLBACK` at the end
- ✅ **No permanent changes**: No data is permanently modified
- ✅ **Non-blocking**: Analysis queries don't lock tables for extended periods

You can safely run these scripts on production databases to monitor performance without risk of data modification.

## Scripts to Processes Mapping

This section maps each performance analysis script to its corresponding main process.

### 📦 `processPlanetNotes.sh` - Planet Notes Processing

This is the main process for loading historical notes from the complete Planet dump.

**Related analysis scripts:**

1. **`analyze_partition_loading_performance.sql`**
   - **Related SQL**: `sql/process/processPlanetNotes_30_loadPartitionedSyncNotes.sql`
   - **Bash function**: `__loadPartitionedSyncNotes()` in `bin/lib/functionsProcess.sh`
   - **What it analyzes**: Performance of massive COPY operations to load partitions
   - **When it runs**: During initial loading of Planet notes in parallel partitions

2. **`analyze_partition_consolidation_performance.sql`**
   - **Related SQL**: `sql/process/processPlanetNotes_31_consolidatePartitions.sql`
   - **Bash function**: `__consolidatePartitions()` in `bin/lib/functionsProcess.sh`
   - **What it analyzes**: Performance of massive INSERT operations to consolidate partitions
   - **When it runs**: After loading all partitions, when consolidating into sync tables

3. **`analyze_integrity_verification_performance.sql`**
   - **Related SQL**: `sql/functionsProcess_33_verifyNoteIntegrity.sql`
   - **Bash function**: `__getLocationNotes()` → `__getLocationNotes_impl()` in `bin/lib/noteProcessingFunctions.sh`
   - **What it analyzes**: Performance of note location integrity verification
   - **When it runs**: During integrity verification (process that takes hours)
   - **Called from**: `processPlanetNotes.sh` after assigning countries

4. **`analyze_country_assignment_performance.sql`**
   - **Related SQL**: `sql/functionsProcess_32_assignCountryToNotesChunk.sql`
   - **Bash function**: `__getLocationNotes()` → `__getLocationNotes_impl()` in `bin/lib/noteProcessingFunctions.sh`
   - **What it analyzes**: Performance of country assignment to notes (massive UPDATE with get_country())
   - **When it runs**: During initial country assignment to Planet notes
   - **Called from**: `processPlanetNotes.sh` (automatically)

### 🔄 `processAPINotes.sh` - API Notes Processing

This is the main process for synchronizing recent notes from the OSM API.

**Related analysis scripts:**

1. **`analyze_partition_loading_performance.sql`**
   - **Related SQL**: `sql/process/processAPINotes_30_loadApiNotes.sql`
   - **Bash function**: `__loadApiNotes()` in `bin/lib/processAPIFunctions.sh`
   - **What it analyzes**: Performance of massive COPY operations to load API data into partitions
   - **When it runs**: During loading of notes from API in parallel partitions

2. **`analyze_api_insertion_performance.sql`**
   - **Related SQL**: `sql/process/processAPINotes_31_insertNewNotesAndComments.sql`
   - **Bash function**: `__insertNewNotesAndComments()` in `bin/process/processAPINotes.sh`
   - **What it analyzes**: Performance of note insertion using cursors and stored procedures
   - **When it runs**: When inserting new notes and comments from API tables to main tables

3. **`analyze_partition_consolidation_performance.sql`**
   - **Related SQL**: `sql/process/processAPINotes_35_consolidatePartitions.sql`
   - **Bash function**: `__consolidatePartitions()` in `bin/process/processAPINotes.sh`
   - **What it analyzes**: Performance of API partition consolidation
   - **When it runs**: After loading API partitions, when consolidating into main API tables

### 🌍 `updateCountries.sh` - Country Boundaries Update

This process updates country boundaries when they change in OSM.

**Related analysis scripts:**

1. **`analyze_country_reassignment_performance.sql`**
   - **Related SQL**: `sql/functionsProcess_36_reassignAffectedNotes.sql`
   - **Bash function**: `__reassignAffectedNotes()` in `bin/process/updateCountries.sh`
   - **What it analyzes**: Performance of country reassignment using spatial queries with bounding box
   - **When it runs**: When country boundaries are updated and affected notes need to be reassigned

### Summary Table

| Analysis Script | Main Process | Related SQL | Bash Function |
|----------------|--------------|-------------|---------------|
| `analyze_partition_loading_performance.sql` | `processPlanetNotes.sh` | `processPlanetNotes_30_loadPartitionedSyncNotes.sql` | `__loadPartitionedSyncNotes()` |
| `analyze_partition_loading_performance.sql` | `processAPINotes.sh` | `processAPINotes_30_loadApiNotes.sql` | `__loadApiNotes()` |
| `analyze_partition_consolidation_performance.sql` | `processPlanetNotes.sh` | `processPlanetNotes_31_consolidatePartitions.sql` | `__consolidatePartitions()` |
| `analyze_partition_consolidation_performance.sql` | `processAPINotes.sh` | `processAPINotes_35_consolidatePartitions.sql` | `__consolidatePartitions()` |
| `analyze_api_insertion_performance.sql` | `processAPINotes.sh` | `processAPINotes_31_insertNewNotesAndComments.sql` | `__insertNewNotesAndComments()` |
| `analyze_integrity_verification_performance.sql` | `processPlanetNotes.sh` | `functionsProcess_33_verifyNoteIntegrity.sql` | `__getLocationNotes()` |
| `analyze_country_assignment_performance.sql` | `processPlanetNotes.sh` | `functionsProcess_32_assignCountryToNotesChunk.sql` | `__getLocationNotes()` |
| `analyze_country_reassignment_performance.sql` | `updateCountries.sh` | `functionsProcess_36_reassignAffectedNotes.sql` | `__reassignAffectedNotes()` |

### When to Run the Analyses

**Analysis for `processPlanetNotes.sh`**

Run after:
- ✅ Initial Planet notes loading
- ✅ Partition consolidation
- ✅ Country assignment
- ✅ Integrity verification

**Analysis for `processAPINotes.sh`**

Run after:
- ✅ Each API synchronization (typically every 15 minutes)
- ✅ API partition loading
- ✅ API partition consolidation
- ✅ New note insertion

**Analysis for `updateCountries.sh`**

Run after:
- ✅ Country boundary updates
- ✅ Affected notes reassignment

**Command:**

```bash
# Run all analyses
./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes
```

### Important Notes

1. **Some analyses are shared**:
   - `analyze_partition_loading_performance.sql` is used for both Planet and API
   - `analyze_partition_consolidation_performance.sql` is used for both Planet and API
   - `analyze_country_assignment_performance.sql` is used in multiple processes

2. **Most critical analyses**:
   - `analyze_integrity_verification_performance.sql`: ⚠️ **VERY RESOURCE INTENSIVE** - Process that takes 15-30+ minutes, critical to optimize
   - `analyze_country_assignment_performance.sql`: Runs frequently, affects overall performance
   - `analyze_country_reassignment_performance.sql`: Uses spatial queries, can be slow on large datasets

3. **Recommended frequency**:
   - **Monthly execution**: Recommended for all analyses (first day of month, 2-4 AM)
   - **Planet**: After each complete load (weeks/months)
   - **API**: Monthly monitoring sufficient (not after each sync)
   - **Countries**: After each boundary update (if needed, but monthly is sufficient)

**⚠️ Resource-Intensive Scripts:**
- `analyze_integrity_verification_performance.sql`: Uses `ST_Contains` on complex geometries - **15-30+ minutes**
- `analyze_country_reassignment_performance.sql`: Uses `ST_Intersects` spatial queries - **5-15 minutes**
- Other scripts are generally fast (< 1 minute each)


