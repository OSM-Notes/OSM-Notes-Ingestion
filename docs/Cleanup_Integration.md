# Cleanup Script Integration

## Overview

The cleanup functionality has been integrated into a single comprehensive script (`cleanupAll.sh`) that can perform both full cleanup and partition-only cleanup operations.

## Integration Details

### Previous State

- **`cleanupAll.sh`**: Performed comprehensive cleanup (ETL, WMS, base tables, temporary files)
- **`cleanupPartitions.sh`**: Performed partition-only cleanup

### Current State

- **`cleanupAll.sh`**: Integrated script that supports both modes:
  - **Full cleanup** (default): Removes all components
  - **Partition-only cleanup**: Removes only partition tables

## Usage

### Full Cleanup (Default)

```bash
# Clean everything using default database
./bin/cleanupAll.sh

# Clean everything using specific database
./bin/cleanupAll.sh my_database

# Explicit full cleanup
./bin/cleanupAll.sh -a my_database
./bin/cleanupAll.sh --all my_database
```

### Partition-Only Cleanup

```bash
# Clean only partitions using default database
./bin/cleanupAll.sh -p

# Clean only partitions using specific database
./bin/cleanupAll.sh -p my_database

# Explicit partition-only cleanup
./bin/cleanupAll.sh --partitions-only my_database
```

### Help and Options

```bash
# Show help
./bin/cleanupAll.sh --help

# Available options
-p, --partitions-only    Clean only partition tables
-a, --all               Clean everything (default)
-h, --help              Show help message
```

## Features

### Full Cleanup Mode

1. **Database Check**: Verifies database existence
2. **ETL Components**: Removes datamarts, staging, DWH objects
3. **WMS Components**: Removes WMS-related objects
4. **Base Components**: Removes tables, functions, procedures
5. **Temporary Files**: Cleans up temporary directories

### Partition-Only Mode

1. **Database Check**: Verifies database existence
2. **List Partitions**: Shows existing partition tables
3. **Drop Partitions**: Removes all partition tables
4. **Verify Cleanup**: Confirms all partitions are removed

## Benefits of Integration

1. **Reduced Maintenance**: Single script to maintain instead of two
2. **Consistent Interface**: Same command-line interface for both operations
3. **Shared Code**: Common functions (database connection, validation, logging)
4. **Better Testing**: Comprehensive test coverage for both modes
5. **Simplified Documentation**: One set of documentation instead of two

## Migration Guide

### For Users

- **Old**: `./bin/cleanupPartitions.sh database_name`
- **New**: `./bin/cleanupAll.sh -p database_name`

- **Old**: `./bin/cleanupAll.sh database_name` (still works)
- **New**: `./bin/cleanupAll.sh database_name` (same)

### For Developers

- All partition cleanup functionality is now in `cleanupAll.sh`
- Functions are prefixed with `__` for internal use
- Both modes use the same validation and logging infrastructure
- Tests have been updated to cover both modes

## Testing

The integration includes comprehensive tests:

```bash
# Run cleanup integration tests
bats tests/unit/bash/cleanupAll_integration.test.bats

# Test both modes
./bin/cleanupAll.sh --help
./bin/cleanupAll.sh -p --help
```

## Error Handling

- **Database Not Found**: Gracefully handles missing databases
- **SQL Validation**: Validates all SQL scripts before execution
- **Logging**: Comprehensive logging for all operations
- **Cleanup**: Proper cleanup of temporary files and resources

## Version History

- **2025-08-04**: Integrated `cleanupPartitions.sh` functionality into `cleanupAll.sh`
- **Previous**: Separate scripts for different cleanup operations
- **Current**: Single integrated script with multiple modes

## Future Enhancements

1. **Dry-Run Mode**: Add `--dry-run` option for testing
2. **Selective Cleanup**: Allow cleaning specific components only
3. **Backup Integration**: Automatic backup before cleanup operations
4. **Progress Reporting**: Real-time progress indicators for long operations
