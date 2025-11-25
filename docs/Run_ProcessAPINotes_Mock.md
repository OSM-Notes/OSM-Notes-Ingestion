# Guide to Run processAPINotes in Local Mock Mode

## Description

This document explains how to run `processAPINotes.sh` in full mock mode, without
requiring internet connection or access to a real database.

## Requirements

- Bash 4.0 or higher
- Mock scripts in `tests/mock_commands/`
- Setup script `tests/setup_mock_environment.sh`

## Basic Usage

### Simple execution

```bash
cd /home/angoca/github/OSM-Notes-Ingestion
./tests/run_processAPINotes_mock.sh
```

### With custom logging level

```bash
LOG_LEVEL=DEBUG ./tests/run_processAPINotes_mock.sh
```

### Cleaning temporary files after execution

```bash
CLEAN=true ./tests/run_processAPINotes_mock.sh
```

## What the Script Does

The `run_processAPINotes_mock.sh` script performs the following:

1. **Cleans lock files and failed execution markers:**
   - Removes `/tmp/processAPINotes.lock` if it exists
   - Removes `/tmp/processAPINotes_failed_execution` if it exists
   - Removes `/tmp/processPlanetNotes.lock` if it exists
   - This prevents errors from previous executions

2. **Sets up complete mock environment:**
   - Creates mock commands if they don't exist (wget, aria2c, psql, pgrep, etc.)
   - Activates mock environment by adding mock commands to PATH
   - The `pgrep` mock always returns that no processes are running

3. **Configures environment variables:**
   - `MOCK_MODE=true`: Indicates we are in mock mode
   - `TEST_MODE=true`: Indicates test mode
   - `DBNAME=mock_db`: Mock database
   - `SEND_ALERT_EMAIL=false`: Disables email alerts

4. **Executes processAPINotes.sh TWICE:**
   - **First execution**: Resets the base tables marker, which causes
     `processAPINotes.sh` to execute `processPlanetNotes.sh --base` (REAL script)
     to create the base structure and load historical data.
   - **Second execution**: The base tables marker already exists (created by the
     first execution), so only `processAPINotes.sh` is executed without calling
     `processPlanetNotes.sh`.

5. **Cleans up environment:**
   - Deactivates mock environment when finished
   - Restores original PATH

## When processPlanetNotes.sh is Called

The `processAPINotes.sh` script can call `processPlanetNotes.sh` in two
situations:

1. **Full synchronization from Planet** (line 658):
   - When `TOTAL_NOTES >= MAX_NOTES` (default 10000)
   - Calls `processPlanetNotes.sh` without arguments
   - In mock mode with only 3 notes, **it is NOT called**

2. **Base structure creation** (line 1183):
   - When base tables don't exist (`RET_FUNC == 1`)
   - Calls `processPlanetNotes.sh --base` (the REAL script, not mock)
   - The `psql` mock simulates that tables don't exist the first time

**psql mock behavior:**

The `psql` mock uses a marker at `/tmp/osm_notes_base_tables_created` to simulate
the state of base tables:

- **First mock script execution**: The marker is reset (doesn't exist), the mock
  returns error when `checkBaseTables` is executed, which causes
  `processAPINotes.sh` to execute `processPlanetNotes.sh --base` (the REAL script).

- **After creating tables**: When `processPlanetNotes.sh --base` executes
  `processPlanetNotes_23_createBaseTables_constraints.sql`, the `psql` mock
  detects this and creates the marker.

- **Second mock script execution**: The marker exists (created during the first
  execution), the mock returns success and `processAPINotes.sh` continues
  normally without calling `processPlanetNotes.sh`.

**Important note:** The `processPlanetNotes.sh` script that is executed is the
**REAL** one, not a mock. This allows testing the complete integration, but
requires that `processPlanetNotes.sh` can execute correctly (it may need
internet access and real database, depending on its configuration).

**Double execution:**

The `run_processAPINotes_mock.sh` script executes `processAPINotes.sh` twice to
test both scenarios:

1. First execution: With missing base tables (executes `processPlanetNotes.sh --base`)
2. Second execution: With existing base tables (only `processAPINotes.sh`)

## Mock Commands Used

- **wget**: Simulates HTTP downloads, creates mock XML files
- **aria2c**: Simulates downloads with aria2c, creates mock files
- **psql**: Simulates PostgreSQL database operations. The first time it simulates
  that base tables don't exist to allow the REAL `processPlanetNotes.sh --base`
  to execute
- **pgrep**: Always returns that no processes are running (allows execution)
- **processPlanetNotes.sh**: The REAL script (not mock) is executed when base
  tables don't exist
- **xmllint**: Validates mock XML
- **bzip2**: Handles mock compressed files

## Available Environment Variables

| Variable | Description | Default Value |
|----------|-------------|---------------|
| `LOG_LEVEL` | Logging level (TRACE, DEBUG, INFO, WARN, ERROR, FATAL) | `INFO` |
| `CLEAN` | Clean temporary files after execution | `false` |
| `DBNAME` | Mock database name | `mock_db` |
| `DB_USER` | Mock database user | `mock_user` |
| `DB_PASSWORD` | Mock database password | `mock_password` |
| `SEND_ALERT_EMAIL` | Send email alerts | `false` |

## Usage Examples

### Example 1: Basic execution with INFO logging

```bash
./tests/run_processAPINotes_mock.sh
```

### Example 2: Execution with detailed logging

```bash
LOG_LEVEL=DEBUG ./tests/run_processAPINotes_mock.sh
```

### Example 3: Execution with automatic cleanup

```bash
CLEAN=true LOG_LEVEL=INFO ./tests/run_processAPINotes_mock.sh
```

### Example 4: Execution with custom mock database

```bash
DBNAME=my_mock_db DB_USER=my_user ./tests/run_processAPINotes_mock.sh
```

## Mock Environment Verification

To verify that the mock environment is active, you can execute:

```bash
# Verify that mock commands are in PATH
which psql
which wget
which aria2c

# They should point to tests/mock_commands/
```

## Troubleshooting

### Error: Mock setup script not found

**Problem:** The script cannot find `setup_mock_environment.sh`

**Solution:** Make sure you are in the project root directory:

```bash
cd /home/angoca/github/OSM-Notes-Ingestion
```

### Error: processAPINotes.sh not found

**Problem:** The script cannot find `processAPINotes.sh`

**Solution:** Verify that the script exists:

```bash
ls -la bin/process/processAPINotes.sh
```

### Error: processAPINotes is currently running (code 246)

**Problem:** The script detects that there is a process running

**Solution:** This error is already automatically resolved. The script cleans lock
files before executing and uses a `pgrep` mock that always returns that no
processes are running. If you still see this error:

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

### Mock commands are not being used

**Problem:** Real commands are being executed instead of mocks

**Solution:** Verify PATH:

```bash
echo $PATH | grep mock_commands
```

If it doesn't appear, the script should add it automatically. If it persists,
execute manually:

```bash
export PATH="$(pwd)/tests/mock_commands:$PATH"
```

## Important Notes

1. **No real downloads:** All internet downloads are simulated using mock files.

2. **No real database access:** All database operations are simulated by the
   psql mock.

3. **Temporary files:** Temporary files are created in `/tmp/` and can be
   automatically cleaned if `CLEAN=true`.

4. **Logs:** Logs are generated in the temporary directory created by
   processAPINotes.sh.

5. **Exit codes:** The script respects exit codes from processAPINotes.sh.

## Alternative: Hybrid Mock (internet only)

If you need to use a real database but mock only internet downloads, you can use
the hybrid mock environment:

```bash
source tests/setup_hybrid_mock_environment.sh
setup_hybrid_mock_environment
activate_hybrid_mock_environment
./bin/process/processAPINotes.sh
deactivate_hybrid_mock_environment
```

## References

- `tests/setup_mock_environment.sh`: Mock environment setup script
- `tests/setup_hybrid_mock_environment.sh`: Hybrid mock environment setup script
- `tests/mock_commands/README.md`: Mock commands documentation
- `docs/Test_Matrix.md`: Test compatibility matrix
