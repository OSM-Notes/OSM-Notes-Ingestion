---
title: "Cleanup Script Documentation"
description: "The `cleanupAll.sh` script provides comprehensive cleanup functionality for the OSM Notes Ingestion"
version: "1.0.0"
last_updated: "2026-01-25"
author: "AngocA"
tags:
  - "documentation"
audience:
  - "developers"
project: "OSM-Notes-Ingestion"
status: "active"
---


# Cleanup Script Documentation

## Overview

The `cleanupAll.sh` script provides comprehensive cleanup functionality for the OSM Notes Ingestion
system. It can perform both full cleanup (removing all components) and partition-only cleanup
(removing only partition tables).

## Usage

### Full Cleanup (Default)

Removes all components: base tables, functions, procedures, and temporary files.

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

Removes only partition tables, keeping base tables and other components intact.

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
2. **Base Components**: Removes tables, functions, procedures
3. **Temporary Files**: Cleans up temporary directories

### Partition-Only Mode

1. **Database Check**: Verifies database existence
2. **List Partitions**: Shows existing partition tables
3. **Drop Partitions**: Removes all partition tables
4. **Verify Cleanup**: Confirms all partitions are removed

## Benefits

1. **Unified Interface**: Single script for all cleanup operations
2. **Consistent Behavior**: Same command-line interface for both modes
3. **Shared Code**: Common functions (database connection, validation, logging)
4. **Comprehensive Testing**: Full test coverage for both modes
5. **Simplified Maintenance**: One script to maintain instead of multiple

## Testing

The script includes comprehensive tests:

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

## When to Use Each Mode

### Use Full Cleanup When:

- Starting fresh with a new database
- Removing all data and components
- Resetting the entire system
- Before major upgrades or migrations

### Use Partition-Only Cleanup When:

- Removing old partition tables to free disk space
- Cleaning up after data retention policies
- Maintaining base tables while removing historical partitions
- Regular maintenance operations

## Future Enhancements

Potential improvements planned:

1. **Dry-Run Mode**: Add `--dry-run` option for testing
2. **Selective Cleanup**: Allow cleaning specific components only
3. **Backup Integration**: Automatic backup before cleanup operations
4. **Progress Reporting**: Real-time progress indicators for long operations

## Related Documentation

- **[bin/README.md](../bin/README.md)**: Script usage examples including cleanupAll.sh
- **[bin/cleanupAll.sh](../bin/cleanupAll.sh)**: Cleanup script implementation
- **[Documentation.md](./Documentation.md)**: System architecture and cleanup procedures
- **[Troubleshooting_Guide.md](./Troubleshooting_Guide.md)**: Troubleshooting cleanup issues
- **[sql/README.md](../sql/README.md)**: SQL cleanup scripts documentation
