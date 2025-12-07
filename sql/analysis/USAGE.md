# Performance Analysis Scripts Usage

## Automatic Execution

### Main Script: `analyzeDatabasePerformance.sh`

The `bin/monitor/analyzeDatabasePerformance.sh` script runs all analysis scripts and generates a summary report.

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

## Manual Execution of Individual Scripts

You can also execute individual scripts directly:

```bash
# Specific script
psql -d "${DBNAME}" -f sql/analysis/analyze_integrity_verification_performance.sql

# Save output to file
psql -d "${DBNAME}" -f sql/analysis/analyze_integrity_verification_performance.sql > results.txt 2>&1
```

## Production Safety

**✅ SAFE FOR PRODUCTION**

All analysis scripts are safe to run on production databases because:

1. **Use ROLLBACK**: All scripts that modify data use `ROLLBACK` at the end
2. **Read-only**: Most operations are read-only queries
3. **No permanent modifications**: No permanent changes are made to data

### Verification

You can verify that a script is safe by checking that it contains:

```sql
-- At the end of the script
ROLLBACK;
```

Or that it only contains read queries (SELECT, EXPLAIN, etc.).

## Result Interpretation

### Status: PASSED ✓

- All performance thresholds are met
- Indexes are being used correctly
- No problems detected

### Status: WARNING ⚠

- Warnings detected but no critical errors
- May indicate:
  - Sequential scan usage instead of index scan
  - Execution times near thresholds
  - Unused indexes (normal if queries haven't been executed yet)

### Status: FAILED ✗

- Critical errors detected
- May indicate:
  - Missing indexes
  - SQL execution errors
  - Connectivity problems

## Regular Scheduling

For continuous monitoring, you can schedule regular execution:

```bash
# Crontab to run daily at 2 AM
0 2 * * * /path/to/project/bin/monitor/analyzeDatabasePerformance.sh --db osm_notes > /var/log/db_performance.log 2>&1
```

## Monitoring Integration

The script can be integrated with monitoring systems:

```bash
# Execute and send alert if there are failures
if ! ./bin/monitor/analyzeDatabasePerformance.sh --db osm_notes; then
  # Send alert (email, Slack, etc.)
  echo "Performance analysis failed" | mail -s "DB Performance Alert" admin@example.com
fi
```

## Troubleshooting

### Error: "Cannot connect to database"

- Verify that `DBNAME` is configured in `etc/properties.sh`
- Verify PostgreSQL connection permissions
- Verify that the database exists

### Error: "No analysis scripts found"

- Verify that the `sql/analysis/` directory exists
- Verify that scripts have `.sql` extension

### Scripts fail with SQL errors

- Verify that all required tables exist
- Verify that necessary extensions are installed (PostGIS, etc.)
- Review individual output files for details
