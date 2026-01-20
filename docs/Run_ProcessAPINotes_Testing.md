# Guide to Run processAPINotes in Testing Mode

## Overview

This document explains how to run `processAPINotes.sh` in hybrid testing mode:

- **Hybrid Mode**: Real database with mocked internet downloads

This mode allows testing `processAPINotes.sh` without requiring full production setup or internet
connectivity.

---

**Note:** Full mock mode (with mocked PostgreSQL) has been removed due to complexity and error-prone
nature. Only hybrid mode is supported, which uses a real PostgreSQL database but mocks internet
downloads.

---

## Hybrid Mode (Real Database, Mocked Downloads)

### Description

Run `processAPINotes.sh` in hybrid mock mode, using a real PostgreSQL database but mocking internet
downloads. This allows testing the complete database integration without requiring internet
connectivity.

### Requirements

- Bash 4.0 or higher
- PostgreSQL server running and accessible
- PostgreSQL client (psql) installed
- PostGIS extension available
- Mock scripts in `tests/mock_commands/` (curl, aria2c, pgrep)
- Setup script `tests/setup_hybrid_mock_environment.sh`

### Basic Usage

#### Simple execution

```bash
cd /home/angoca/github/OSM-Notes-Ingestion
./tests/run_processAPINotes_hybrid.sh
```

#### With custom database

```bash
DBNAME=my_test_db DB_USER=postgres ./tests/run_processAPINotes_hybrid.sh
```

#### With custom logging level

```bash
LOG_LEVEL=DEBUG ./tests/run_processAPINotes_hybrid.sh
```

#### Cleaning temporary files after execution

```bash
CLEAN=true ./tests/run_processAPINotes_hybrid.sh
```

### What the Script Does

The `run_processAPINotes_hybrid.sh` script performs the following:

1. **Checks PostgreSQL availability:**
   - Verifies that PostgreSQL client (psql) is installed
   - Tests connection to PostgreSQL server

2. **Sets up test database:**
   - Creates database if it doesn't exist (default: `osm_notes_ingestion_test`)
   - Installs PostGIS and btree_gist extensions

3. **Cleans lock files and failed execution markers:**
   - Removes lock files (works in both installed and fallback modes):
     - `/var/run/osm-notes-ingestion/processAPINotes.lock` or
       `/tmp/osm-notes-ingestion/locks/processAPINotes.lock`
     - `/var/run/osm-notes-ingestion/processAPINotes_failed_execution` or
       `/tmp/osm-notes-ingestion/locks/processAPINotes_failed_execution`
     - `/var/run/osm-notes-ingestion/processPlanetNotes.lock` or
       `/tmp/osm-notes-ingestion/locks/processPlanetNotes.lock`

4. **Sets up hybrid mock environment:**
   - Creates mock commands if they don't exist (curl, aria2c, pgrep)
   - Activates hybrid mock environment (only internet downloads mocked)
   - Ensures real `psql` is used (not mock)

5. **Configures environment variables:**
   - `HYBRID_MOCK_MODE=true`: Indicates hybrid mock mode
   - `TEST_MODE=true`: Indicates test mode
   - Database connection variables (DBNAME, DB_USER, DB_HOST, DB_PORT)
   - `SEND_ALERT_EMAIL=false`: Disables email alerts
   - `SKIP_XML_VALIDATION=true`: Skip XML validation

6. **Executes processAPINotes.sh TWICE:**
   - **First execution**: Drops base tables, which causes `processAPINotes.sh` to execute
     `processPlanetNotes.sh --base` (REAL script) to create the base structure and load historical
     data.
   - **Second execution**: Base tables already exist (created by the first execution), so only
     `processAPINotes.sh` is executed without calling `processPlanetNotes.sh`.

7. **Cleans up environment:**
   - Deactivates hybrid mock environment when finished
   - Restores original PATH

### Mock Commands Used

- **curl**: Simulates HTTP downloads, creates mock XML files
- **aria2c**: Simulates downloads with aria2c, creates mock files
- **pgrep**: Always returns that no processes are running (allows execution)
- **psql**: Uses REAL PostgreSQL client (not mocked)
- **processPlanetNotes.sh**: The REAL script (not mock) is executed when base tables don't exist

### Available Environment Variables

| Variable              | Description                                            | Default Value              |
| --------------------- | ------------------------------------------------------ | -------------------------- |
| `LOG_LEVEL`           | Logging level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL) | `INFO`                     |
| `CLEAN`               | Clean temporary files after execution                  | `false`                    |
| `DBNAME`              | Database name                                          | `osm_notes_ingestion_test` |
| `DB_USER`             | Database user                                          | Current user (`$USER`)     |
| `DB_HOST`             | Database host (empty for unix socket)                  | Empty                      |
| `DB_PORT`             | Database port                                          | `5432`                     |
| `DB_PASSWORD`         | Database password (if required)                        | Empty                      |
| `SEND_ALERT_EMAIL`    | Send email alerts                                      | `false`                    |
| `SKIP_XML_VALIDATION` | Skip XML validation                                    | `true`                     |

### Usage Examples

#### Example 1: Basic execution with default database

```bash
./tests/run_processAPINotes_hybrid.sh
```

#### Example 2: Execution with custom database

```bash
DBNAME=my_test_db DB_USER=postgres ./tests/run_processAPINotes_hybrid.sh
```

#### Example 3: Execution with remote database

```bash
DBNAME=notes DB_USER=notes DB_HOST=192.168.0.100 DB_PORT=5432 \
  DB_PASSWORD=mypass ./tests/run_processAPINotes_hybrid.sh
```

#### Example 4: Execution with debug logging

```bash
LOG_LEVEL=DEBUG ./tests/run_processAPINotes_hybrid.sh
```

#### Example 5: Execution with automatic cleanup

```bash
CLEAN=true LOG_LEVEL=INFO ./tests/run_processAPINotes_hybrid.sh
```

### Database Setup

The script automatically:

1. **Checks PostgreSQL availability** - Verifies psql is installed and PostgreSQL server is
   accessible
2. **Creates database if needed** - Creates the database if it doesn't exist
3. **Installs extensions** - Automatically installs PostGIS and btree_gist extensions
4. **Drops base tables** - Before first execution, drops base tables to trigger
   `processPlanetNotes.sh --base`

---

## When processPlanetNotes.sh is Called

The `processAPINotes.sh` script can call `processPlanetNotes.sh` in two situations:

1. **Full synchronization from Planet** (line 658):
   - When `TOTAL_NOTES >= MAX_NOTES` (default 10000)
   - Calls `processPlanetNotes.sh` without arguments
   - In both modes with only 3 notes, **it is NOT called**

2. **Base structure creation** (line 1183):
   - When base tables don't exist (`RET_FUNC == 1`)
   - Calls `processPlanetNotes.sh --base` (the REAL script)
   - In hybrid mode: Base tables are dropped before first execution

**Double execution:**

Both scripts execute `processAPINotes.sh` twice to test both scenarios:

1. First execution: Base tables are missing, so `processPlanetNotes.sh --base` is executed to create
   them
2. Second execution: Base tables exist, so only `processAPINotes.sh` runs

**Important note:** The `processPlanetNotes.sh` script that is executed is the **REAL** one, not a
mock. This allows testing the complete integration.

---

## Troubleshooting

### Hybrid Mode Issues

#### Error: PostgreSQL client (psql) is not installed

**Problem:** The script cannot find `psql` command

**Solution:** Install PostgreSQL client:

```bash
# Ubuntu/Debian
sudo apt-get install postgresql-client

# CentOS/RHEL
sudo yum install postgresql
```

#### Error: Cannot connect to PostgreSQL

**Problem:** The script cannot connect to PostgreSQL server

**Solution:** Check PostgreSQL is running and accessible:

```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql

# Test connection manually
psql -d postgres -c "SELECT 1;"

# If using remote host, verify connection
psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} -d postgres -c "SELECT 1;"
```

#### Error: Failed to create extension postgis

**Problem:** PostGIS extension is not available

**Solution:** Install PostGIS extension:

```bash
# Ubuntu/Debian
sudo apt-get install postgis postgresql-<version>-postgis

# Then connect and create extension manually if needed
psql -d ${DBNAME} -c "CREATE EXTENSION postgis;"
```

#### Error: Database already exists

**Problem:** The database already exists and contains data

**Solution:** The script will use the existing database. If you want to start fresh, drop it
manually:

```bash
dropdb ${DBNAME}
# Then run the script again
```

#### Error: Mock commands are being used instead of real psql

**Problem:** The mock psql is in PATH before the real psql

**Solution:** This should be automatically handled by the script. If it persists, verify:

```bash
which psql
# Should NOT point to tests/mock_commands/psql
```

### Common Issues

#### Error: processAPINotes is currently running (code 246)

**Problem:** The script detects that there is a process running

**Solution:** This error is already automatically resolved. The script cleans lock files before
executing and uses a `pgrep` mock that always returns that no processes are running. If you still
see this error:

1. Verify that the `pgrep` mock exists:

   ```bash
   ls -la tests/mock_commands/pgrep
   ```

2. Verify that the mock is in PATH:

   ```bash
   which pgrep
   # Should show: tests/mock_commands/pgrep
   ```

3. Manually clean locks if necessary:

   ```bash
   rm -f /tmp/processAPINotes.lock
   rm -f /tmp/processAPINotes_failed_execution
   ```

---

## Important Notes

### Hybrid Mode

1. **Real database is used:** All database operations use the real PostgreSQL database. Data will
   persist between executions.
2. **Internet downloads are mocked:** All internet downloads (curl, aria2c) are simulated using mock
   files.
3. **Base tables are dropped:** Before the first execution, base tables are dropped to ensure
   `processPlanetNotes.sh --base` is executed.
4. **Database must exist or be creatable:** The script will create the database if it doesn't exist,
   but you need proper permissions.
5. **PostGIS required:** The database must support PostGIS extension for the scripts to work
   correctly.
6. **Temporary files:** Temporary files are created in `/tmp/` and can be automatically cleaned if
   `CLEAN=true`.
7. **Logs:** Logs are generated in the temporary directory created by processAPINotes.sh.

---

## References

- `tests/setup_hybrid_mock_environment.sh`: Hybrid mock environment setup script
- `tests/mock_commands/README.md`: Mock commands documentation
- `docs/Test_Matrix.md`: Test compatibility matrix
- `docs/Testing_Guide.md`: Complete testing guide
