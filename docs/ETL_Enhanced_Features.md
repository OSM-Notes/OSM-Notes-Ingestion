# ETL Enhanced Features

## Overview

The ETL script has been enhanced with several new features to improve reliability, performance, and maintainability. This document describes the new capabilities and how to use them, including the comprehensive DWH enhanced features.

## New Features

### 1. DWH Enhanced Dimensions and Functions

The ETL now supports enhanced data warehouse capabilities:

#### New Dimensions

- **`dimension_timezones`**: Timezone support for local time calculations
- **`dimension_seasons`**: Seasonal analysis based on date and latitude
- **`dimension_continents`**: Continental grouping for geographical analysis
- **`dimension_application_versions`**: Application version tracking
- **`fact_hashtags`**: Bridge table for many-to-many hashtag relationships

#### Enhanced Dimensions

- **`dimension_time_of_week`**: Renamed from `dimension_hours_of_week` with enhanced attributes (hour_of_week, period_of_day)
- **`dimension_users`**: SCD2 implementation for username changes (valid_from, valid_to, is_current)
- **`dimension_countries`**: ISO codes support (iso_alpha2, iso_alpha3)
- **`dimension_days`**: Enhanced date attributes (ISO week, quarter, names, flags)
- **`dimension_applications`**: Enhanced attributes (pattern_type, vendor, category)

#### New Functions

- **`get_timezone_id_by_lonlat(lon, lat)`**: Timezone calculation from coordinates
- **`get_season_id(ts, lat)`**: Season calculation from date and latitude
- **`get_application_version_id(app_id, version)`**: Application version management
- **`get_local_date_id(ts, tz_id)`**: Local date calculation
- **`get_local_hour_of_week_id(ts, tz_id)`**: Local hour calculation

#### Enhanced ETL

- New columns in facts: `action_timezone_id`, `local_action_dimension_id_date`, `action_dimension_id_season`
- SCD2 support for user dimension
- Bridge table for hashtag relationships
- Application version parsing and storage

### 2. Configuration Management

The ETL now uses a dedicated configuration file (`etc/etl.properties`) that allows fine-tuning of various parameters without modifying the script.

#### Configuration Parameters

**Performance Configuration:**

- `ETL_BATCH_SIZE`: Number of records per batch (default: 1000)
- `ETL_COMMIT_INTERVAL`: Commit every N records (default: 100)
- `ETL_VACUUM_AFTER_LOAD`: Run VACUUM ANALYZE after load (default: true)
- `ETL_ANALYZE_AFTER_LOAD`: Run ANALYZE on dimension tables (default: true)

**Resource Control:**

- `MAX_MEMORY_USAGE`: Maximum memory usage percentage (default: 80)
- `MAX_DISK_USAGE`: Maximum disk usage percentage (default: 90)
- `ETL_TIMEOUT`: Maximum execution time in seconds (default: 7200)

**Recovery Configuration:**

- `ETL_RECOVERY_ENABLED`: Enable recovery functionality (default: true)
- `ETL_RECOVERY_FILE`: Path to recovery file (default: /tmp/ETL_recovery.json)

**Data Integrity Validation:**

- `ETL_VALIDATE_INTEGRITY`: Enable data integrity validation (default: true)
- `ETL_VALIDATE_DIMENSIONS`: Validate dimension tables (default: true)
- `ETL_VALIDATE_FACTS`: Validate fact table references (default: true)

**Parallel Processing:**

- `ETL_PARALLEL_ENABLED`: Enable parallel processing (default: true)
- `ETL_MAX_PARALLEL_JOBS`: Maximum parallel jobs (default: 4)

**Monitoring:**

- `ETL_MONITOR_RESOURCES`: Enable resource monitoring (default: true)
- `ETL_MONITOR_INTERVAL`: Monitoring interval in seconds (default: 30)

### 3. Execution Modes

The ETL script now supports multiple execution modes:

#### `--create` (Default)

Creates or updates the entire data warehouse. This is the traditional mode.

#### `--incremental`

Processes only new data since the last run. This is faster for regular updates.

#### `--validate`

Only validates data integrity without making any changes. Useful for checking data quality.

#### `--resume`

Attempts to resume from the last successful step. Useful for recovery after failures.

#### `--dry-run`

Shows what would be executed without making actual changes. Useful for testing.

#### `--help` or `-h`

Shows help information and available options.

### 4. Recovery System

The ETL now includes a robust recovery system that tracks progress and allows resuming from the last successful step.

#### Recovery File Format

The recovery file (`/tmp/ETL_recovery.json`) contains:

```json
{
    "last_step": "process_notes_etl",
    "status": "completed",
    "timestamp": "1640995200",
    "etl_start_time": "1640995200"
}
```

#### Recovery Steps

1. **check_base_tables**: Verifies and creates base tables
2. **process_notes_etl**: Processes notes and comments
3. **database_maintenance**: Performs VACUUM and ANALYZE
4. **update_datamart_countries**: Updates country datamart
5. **update_datamart_users**: Updates user datamart
6. **final_validation**: Validates data integrity

### 5. Data Integrity Validation

The ETL includes comprehensive data integrity validation:

#### Dimension Validation

- Checks that all dimension tables have data
- Validates dimension table counts
- Ensures no empty dimensions

#### Fact Table Validation

- Validates foreign key references
- Checks for orphaned facts
- Ensures referential integrity

#### Validation Queries

```sql
-- Check dimension counts
SELECT 'dimension_users' as table_name, COUNT(*) as count FROM dwh.dimension_users
UNION ALL
SELECT 'dimension_countries', COUNT(*) FROM dwh.dimension_countries
-- ... other dimensions

-- Check for orphaned facts
SELECT COUNT(*) FROM dwh.facts f
LEFT JOIN dwh.dimension_countries c ON f.dimension_id_country = c.dimension_country_id
WHERE c.dimension_country_id IS NULL
```

### 6. Resource Monitoring

The ETL includes real-time resource monitoring:

#### Memory Monitoring

- Monitors memory usage percentage
- Pauses processing if memory usage exceeds threshold
- Logs memory usage warnings

#### Disk Monitoring

- Monitors disk usage percentage
- Stops processing if disk usage exceeds threshold
- Prevents disk space issues

#### Timeout Control

- Tracks total execution time
- Stops processing if timeout is reached
- Prevents runaway processes

### 7. Database Maintenance

The ETL now includes automatic database maintenance:

#### VACUUM ANALYZE

- Runs VACUUM ANALYZE on fact table after load
- Updates table statistics
- Reclaims disk space

#### ANALYZE Dimensions

- Runs ANALYZE on all dimension tables
- Updates query planner statistics
- Improves query performance

## Usage Examples

### Basic Usage

```bash
# Create/update data warehouse
./bin/dwh/ETL.sh --create

# Incremental update
./bin/dwh/ETL.sh --incremental

# Validate only
./bin/dwh/ETL.sh --validate

# Resume from last step
./bin/dwh/ETL.sh --resume

# Dry run
./bin/dwh/ETL.sh --dry-run
```

### Configuration Examples

```bash
# Use custom configuration
export ETL_BATCH_SIZE=500
export ETL_TIMEOUT=3600
./bin/dwh/ETL.sh --create

# Disable recovery
export ETL_RECOVERY_ENABLED=false
./bin/dwh/ETL.sh --create

# Disable resource monitoring
export ETL_MONITOR_RESOURCES=false
./bin/dwh/ETL.sh --create
```

### Environment Variables

```bash
# Performance tuning
export ETL_BATCH_SIZE=1000
export ETL_COMMIT_INTERVAL=100

# Resource limits
export MAX_MEMORY_USAGE=80
export MAX_DISK_USAGE=90
export ETL_TIMEOUT=7200

# Recovery settings
export ETL_RECOVERY_ENABLED=true
export ETL_RECOVERY_FILE="/tmp/ETL_recovery.json"

# Validation settings
export ETL_VALIDATE_INTEGRITY=true
export ETL_VALIDATE_DIMENSIONS=true
export ETL_VALIDATE_FACTS=true

# Parallel processing
export ETL_PARALLEL_ENABLED=true
export ETL_MAX_PARALLEL_JOBS=4

# Monitoring
export ETL_MONITOR_RESOURCES=true
export ETL_MONITOR_INTERVAL=30
```

## Testing

### Unit Tests

Run unit tests for enhanced ETL features:

```bash
./tests/unit/bash/ETL_enhanced.test.bats
```

### Integration Tests

Run integration tests:

```bash
./tests/integration/ETL_enhanced_integration.test.bats
```

## Troubleshooting

### Common Issues

1. **Recovery file not found**
   - Check if `ETL_RECOVERY_ENABLED=true`
   - Verify file permissions on recovery file location

2. **Resource monitoring warnings**
   - Check system resources
   - Adjust `MAX_MEMORY_USAGE` and `MAX_DISK_USAGE` values

3. **Timeout issues**
   - Increase `ETL_TIMEOUT` value
   - Check for long-running queries

4. **Validation failures**
   - Check database connectivity
   - Verify dimension tables have data
   - Check for orphaned facts

### Log Files

The ETL creates several log files:

- Main log: `/tmp/ETL_*/ETL.log`
- Recovery file: `/tmp/ETL_recovery.json`
- Thread-specific logs: `/tmp/ETL_*/ETL.log.*`

### Debug Mode

Enable debug logging:

```bash
export LOG_LEVEL=DEBUG
./bin/dwh/ETL.sh --create
```

## Migration from Previous Version

The enhanced ETL is backward compatible. Existing scripts will continue to work with default settings. To enable new features:

1. Create `etc/etl.properties` file
2. Set desired configuration parameters
3. Use new execution modes as needed

## Performance Considerations

- **Batch Size**: Larger batch sizes improve performance but use more memory
- **Parallel Jobs**: More parallel jobs use more CPU but may improve throughput
- **Resource Monitoring**: Adds minimal overhead but prevents resource issues
- **Validation**: Adds processing time but ensures data quality
- **Recovery**: Minimal overhead, significant reliability improvement

## Security Considerations

- Recovery files contain execution state information
- Ensure proper file permissions on recovery files
- Consider encrypting sensitive configuration data
- Validate all configuration parameters

## Future Enhancements

- **Distributed Processing**: Support for multi-node processing
- **Real-time Monitoring**: Web-based monitoring dashboard
- **Advanced Recovery**: Point-in-time recovery capabilities
- **Performance Analytics**: Detailed performance metrics
- **Automated Tuning**: Self-tuning based on system resources
