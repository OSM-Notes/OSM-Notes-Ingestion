# SQL Analysis Scripts

This directory contains SQL scripts for performance analysis and validation of database optimizations.

## Overview

These scripts help validate that performance optimizations are working correctly by checking query execution plans, timing, and index usage. They focus on validating **CURRENT performance** rather than comparing with old implementations, making them useful long-term for performance monitoring.

## Scripts

### `analyze_integrity_verification_performance.sql`

**Purpose**: Validates performance of integrity verification queries.

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
- `sql/process/processPlanetNotes_41_loadPartitionedSyncNotes.sql`

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
- `sql/process/processPlanetNotes_42_consolidatePartitions.sql`

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
- `sql/process/processAPINotes_32_insertNewNotesAndComments.sql`

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
- `sql/functionsProcess_37_assignCountryToNotesChunk.sql`

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

```bash
# Run with default database from properties
./bin/monitor/analyzeDatabasePerformance.sh

# Run with specific database
./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes

# Run with verbose output
./bin/monitor/analyzeDatabasePerformance.sh --verbose
```

The script will:
- ✅ Execute all analysis scripts automatically
- ✅ Parse results and check performance thresholds
- ✅ Generate a summary report with pass/fail/warning status
- ✅ Identify performance regressions
- ✅ Save detailed output for each script

**See [USAGE.md](./USAGE.md) for detailed usage instructions.**

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


