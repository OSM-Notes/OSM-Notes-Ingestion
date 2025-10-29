# Input Validation Functions

## Overview

This document describes the centralized input validation functions that have been added to the OSM-Notes-Ingestion project to address the critical issue of **"Falta de Validación de Entrada"** (Lack of Input Validation).

## Problem Statement

Previously, the project had inconsistent and scattered input validation across different scripts. This led to:

- Runtime errors when files were missing or corrupted
- Inconsistent error handling
- Difficult maintenance and debugging
- Potential security issues

## Solution

A centralized set of validation functions has been implemented in `bin/functionsProcess.sh` that provides:

- **Consistent validation logic** across all scripts
- **Comprehensive error reporting** with detailed messages
- **Multiple validation types** for different file formats
- **Easy integration** into existing scripts

## Available Validation Functions

The following validation functions are available in `bin/functionsProcess.sh`:

### Basic File Validation

- **`__validate_input_file(file_path, description, expected_type)`**
  - Validates file existence, readability, and type
  - Supports `file`, `dir`, and `executable` types
  - Returns 0 if valid, 1 if invalid

- **`__validate_input_files(file_paths...)`**
  - Validates multiple input files
  - Returns 0 if all valid, 1 if any invalid

### Structure Validation

- **`__validate_xml_structure(xml_file, expected_root)`**
  - Validates XML syntax and structure
  - Checks for expected root element
  - Uses `xmllint` (optional, only if SKIP_XML_VALIDATION=false)

- **`__validate_csv_structure(csv_file, expected_columns)`**
  - Validates CSV structure and content
  - Checks for expected number of columns
  - Validates file is not empty

- **`__validate_sql_structure(sql_file)`**
  - Validates SQL file existence and readability
  - Checks file is not empty

- **`__validate_config_file(config_file)`**
  - Validates configuration file structure
  - Checks for valid variable declarations

- **`__validate_json_structure(json_file, expected_root)`**
  - Validates JSON syntax and structure
  - Checks for expected root element
  - Uses `jq` if available, with fallback to `grep`

- **`__validate_json_with_element(json_file, expected_element)`**
  - Validates JSON syntax and structure (calls `__validate_json_structure`)
  - Verifies that the JSON contains a specific expected element
  - Checks that the element is not null and not empty
  - Uses `jq` for element validation (requires `jq` command)
  - Returns 0 if valid and contains expected element, 1 if invalid or missing element
  - **Parameters:**
    - `json_file`: Path to the JSON file to validate
    - `expected_element`: Name of the expected element (e.g., `"elements"` for OSM JSON, `"features"` for GeoJSON)
  - **Usage examples:**
    - Validate OSM JSON with elements: `__validate_json_with_element "${json_file}" "elements"`
    - Validate GeoJSON with features: `__validate_json_with_element "${geojson_file}" "features"`
  - **Common use cases:**
    - Validating Overpass API responses before processing
    - Ensuring GeoJSON files have the expected structure after conversion
    - Verifying downloaded boundary files contain required data

### Date Validation

- **`__validate_iso8601_date(date_string, expected_format)`**
  - Validates ISO 8601 date format
  - Supports multiple formats:
    - `YYYY-MM-DDTHH:MM:SSZ` (UTC)
    - `YYYY-MM-DDTHH:MM:SS±HH:MM` (with timezone offset)
    - `YYYY-MM-DD HH:MM:SS UTC` (API format)
  - Restricts years to 2020-2023 (based on project requirements)
  - Uses `date` command for additional validation

- **`__validate_xml_dates(xml_file, xpath_expression)`**
  - Validates dates in XML files
  - Extracts dates using grep/sed pattern matching
  - Validates created_at, closed_at, and timestamp attributes

- **`__validate_csv_dates(csv_file, date_column)`**
  - Validates dates in CSV files
  - Auto-detects date columns by name
  - Supports manual column specification
  - Validates all dates in the specified column

### Database Validation

- **`__validate_database_connection(db_name, db_user, db_host, db_port)`**
  - Validates database connection parameters
  - Tests actual connection to PostgreSQL
  - Checks for required extensions (PostGIS)

- **`__validate_database_tables(db_name, db_user, db_host, db_port, required_tables...)`**
  - Validates existence of required database tables
  - Uses `information_schema.tables`

- **`__validate_database_extensions(db_name, db_user, db_host, db_port, required_extensions...)`**
  - Validates existence of required database extensions
  - Uses `pg_extension` catalog

## JSON Validation with Retry Logic

The `__validate_json_with_element` function is particularly important for validating downloaded files from external APIs (like Overpass API) where downloads may be corrupted or incomplete. The system implements automatic retry logic when validation fails.

### Download and Validation Flow

The boundary processing workflow (`__processBoundary`) demonstrates the complete flow:

1. **Download** JSON file from Overpass API
2. **Validate** JSON structure and check for expected elements
3. **Retry** download if validation fails (up to 3 attempts)
4. **Convert** to GeoJSON format
5. **Validate** GeoJSON structure and check for features
6. **Retry** conversion if validation fails (up to 3 attempts)

### Example: Boundary Processing with Validation

```bash
# Download boundary from Overpass API with validation retry
local DOWNLOAD_VALIDATION_RETRIES=3
local DOWNLOAD_VALIDATION_RETRY_COUNT=0
local DOWNLOAD_SUCCESS=false

while [[ ${DOWNLOAD_VALIDATION_RETRY_COUNT} -lt ${DOWNLOAD_VALIDATION_RETRIES} ]] && [[ "${DOWNLOAD_SUCCESS}" == "false" ]]; do
  # Attempt download
  wget -O "${JSON_FILE}" --post-file="${QUERY_FILE}" "${OVERPASS_INTERPRETER}" 2> "${OUTPUT_OVERPASS}"

  # Validate JSON structure and ensure it contains elements
  if ! __validate_json_with_element "${JSON_FILE}" "elements"; then
    __loge "JSON validation failed - will retry download"
    DOWNLOAD_VALIDATION_RETRY_COUNT=$((DOWNLOAD_VALIDATION_RETRY_COUNT + 1))
    # Clean up and retry
    rm -f "${JSON_FILE}"
    sleep ${RETRY_DELAY}
    continue
  fi

  # Success - exit retry loop
  DOWNLOAD_SUCCESS=true
done

if [[ "${DOWNLOAD_SUCCESS}" != "true" ]]; then
  __loge "Failed to download and validate JSON after ${DOWNLOAD_VALIDATION_RETRIES} attempts"
  return 1
fi
```

### Example: GeoJSON Conversion with Validation

```bash
# Convert to GeoJSON with validation retry
local GEOJSON_VALIDATION_RETRIES=3
local GEOJSON_VALIDATION_RETRY_COUNT=0
local GEOJSON_SUCCESS=false

while [[ ${GEOJSON_VALIDATION_RETRY_COUNT} -lt ${GEOJSON_VALIDATION_RETRIES} ]] && [[ "${GEOJSON_SUCCESS}" == "false" ]]; do
  # Convert JSON to GeoJSON
  osmtogeojson "${JSON_FILE}" > "${GEOJSON_FILE}"

  # Validate GeoJSON structure and ensure it contains features
  if ! __validate_json_with_element "${GEOJSON_FILE}" "features"; then
    __loge "GeoJSON validation failed - will retry conversion"
    GEOJSON_VALIDATION_RETRY_COUNT=$((GEOJSON_VALIDATION_RETRY_COUNT + 1))
    # Clean up and retry
    rm -f "${GEOJSON_FILE}"
    sleep ${RETRY_DELAY}
    continue
  fi

  # Success - exit retry loop
  GEOJSON_SUCCESS=true
done
```

### Benefits of JSON Validation with Retry

1. **Robustness**: Automatically handles corrupted downloads
2. **Data Quality**: Ensures files contain expected structure before processing
3. **Resilience**: Recovers from transient network issues or API problems
4. **Clear Logging**: Provides detailed error messages for debugging
5. **Prevents Errors**: Catches structural problems early before expensive operations

### When to Use `__validate_json_with_element`

Use this function when:

- Downloading JSON files from external APIs (Overpass, OSM API, etc.)
- Converting between JSON formats (OSM JSON → GeoJSON)
- Processing files that may be corrupted or incomplete
- Ensuring data integrity before database operations
- Validating API responses that must contain specific elements

## Integration Examples

### Before (Old Validation)

```bash
# Scattered validation across scripts
if [[ ! -r "${SQL_FILE}" ]]; then
  __loge "ERROR: File is missing at ${SQL_FILE}."
  exit "${ERROR_MISSING_LIBRARY}"
fi
```

### After (New Validation)

```bash
# Centralized validation
if ! __validate_sql_structure "${SQL_FILE}"; then
  __loge "ERROR: SQL file validation failed: ${SQL_FILE}"
  exit "${ERROR_MISSING_LIBRARY}"
fi
```

## Implementation in Scripts

### ETL Script Example

```bash
function __checkPrereqs {
  # Validate SQL script files using centralized validation
  __logi "Validating SQL script files..."
  
  local sql_files=(
    "${POSTGRES_11_CHECK_DWH_BASE_TABLES}"
    "${POSTGRES_12_DROP_DATAMART_OBJECTS}"
    "${POSTGRES_13_DROP_DWH_OBJECTS}"
    # ... more files
  )
  
  # Validate each SQL file
  for sql_file in "${sql_files[@]}"; do
    if ! __validate_sql_structure "${sql_file}"; then
      __loge "ERROR: SQL file validation failed: ${sql_file}"
      exit "${ERROR_MISSING_LIBRARY}"
    fi
  done
}
```

### Process Script Example

```bash
function __checkPrereqs {
  # Validate XML schema files
  # Validate XML schema files (only if validation is enabled)
  if [[ "${SKIP_XML_VALIDATION}" != "true" ]]; then
    __logi "Validating XML schema files..."
    if ! __validate_input_file "${XMLSCHEMA_PLANET_NOTES}" "XML schema file"; then
      __loge "ERROR: XML schema validation failed: ${XMLSCHEMA_PLANET_NOTES}"
      exit "${ERROR_MISSING_LIBRARY}"
    fi
  fi
  
  # Validate dates in XML files if they exist
  __logi "Validating dates in XML files..."
  if [[ -f "${PLANET_NOTES_FILE}" ]]; then
    if ! __validate_xml_dates "${PLANET_NOTES_FILE}"; then
      __loge "ERROR: XML date validation failed: ${PLANET_NOTES_FILE}"
      exit "${ERROR_MISSING_LIBRARY}"
    fi
  fi
}
```

### Date Validation Examples

```bash
# Validate individual ISO 8601 dates
if ! __validate_iso8601_date "2023-01-15T10:30:00Z"; then
  echo "ERROR: Invalid date format"
  exit 1
fi

# Validate dates in XML files
if ! __validate_xml_dates "notes.xml"; then
  echo "ERROR: XML contains invalid dates"
  exit 1
fi

# Validate dates in CSV files
if ! __validate_csv_dates "notes.csv"; then
  echo "ERROR: CSV contains invalid dates"
  exit 1
fi

# Validate dates with custom XPath
if ! __validate_xml_dates "api_notes.xml" "//@created_at|//@closed_at"; then
  echo "ERROR: API notes contain invalid dates"
  exit 1
fi
```

## Benefits

1. **Consistency**: All scripts now use the same validation logic
2. **Maintainability**: Changes to validation logic only need to be made in one place
3. **Error Reporting**: Detailed error messages help with debugging
4. **Flexibility**: Multiple validation types for different file formats
5. **Reliability**: Prevents runtime errors from invalid input files

## Testing

A comprehensive test suite has been created in `tests/unit/bash/input_validation.test.bats` that covers:

- Valid file validation
- Invalid file handling
- Empty file detection
- XML structure validation
- CSV structure validation
- SQL structure validation
- Configuration file validation
- Multiple file validation

## Usage Guidelines

1. **Always validate input files** before processing
2. **Use the appropriate validation function** for the file type
3. **Provide descriptive error messages** when validation fails
4. **Exit with appropriate error codes** when validation fails
5. **Log validation results** for debugging purposes

## Migration Guide

To migrate existing scripts to use the new validation functions:

1. **Identify validation points** in existing scripts
2. **Replace manual checks** with appropriate validation functions
3. **Update error handling** to use the new validation results
4. **Test thoroughly** to ensure no regressions
5. **Update documentation** to reflect the new validation approach

## Example Script

The validation functions are demonstrated in the comprehensive test suite at `tests/unit/bash/input_validation.test.bats`.

## Version History

- **2025-10-29**: Added `__validate_json_with_element` function
  - Validates JSON structure and verifies expected elements exist and are not empty
  - Integrated with retry logic in boundary processing workflow
  - Enables automatic retry when downloaded files are corrupted or incomplete
  - Used for validating Overpass API responses and GeoJSON conversions

- **2025-07-27**: Initial implementation of centralized validation functions
  - Added support for SQL, XML, CSV, and configuration file validation
  - Created comprehensive test suite
  - Updated ETL and process scripts to use new validation functions
  - **Added date validation functions**:
    - `__validate_iso8601_date()` - Validates ISO 8601 date formats
    - `__validate_xml_dates()` - Validates dates in XML files
    - `__validate_csv_dates()` - Validates dates in CSV files
  - **Integrated date validation** in process scripts:
    - `processPlanetNotes.sh` - Validates dates in planet XML files
    - `processAPINotes.sh` - Validates dates in API XML files
  - **Created comprehensive test suite** for date validation functions

## Contributing

When adding new validation functions:

1. Follow the existing naming convention (`__validate_*`)
2. Include comprehensive error reporting
3. Add corresponding tests to the test suite
4. Update this documentation
5. Ensure the function is independent of the logging system

---

## SQL Sanitization (Security)

In addition to input validation, the project implements SQL sanitization functions to prevent SQL injection attacks. These functions are located in `lib/osm-common/validationFunctions.sh`.

### SQL Sanitization Functions

#### `__sanitize_sql_string(input)`

- **Purpose**: Escapes SQL string literals to prevent injection
- **Method**: Doubles single quotes (PostgreSQL standard: `'` → `''`)
- **Usage**:
  ```bash
  local NAME_RAW=$(extract_from_file)
  local NAME=$(__sanitize_sql_string "${NAME_RAW}")
  psql -c "INSERT INTO table VALUES ('${NAME}')"
  ```

#### `__sanitize_sql_identifier(input)`

- **Purpose**: Sanitizes table/column names
- **Method**: Wraps identifier in double quotes if not already quoted
- **Usage**:
  ```bash
  local TABLE_NAME="users"
  local SAFE_TABLE=$(__sanitize_sql_identifier "${TABLE_NAME}")
  psql -c "SELECT * FROM ${SAFE_TABLE}"
  ```

#### `__sanitize_sql_integer(input)`

- **Purpose**: Validates and sanitizes integer values
- **Method**: Ensures value is a valid integer
- **Usage**:
  ```bash
  local ID_RAW="${1}"
  local SAFE_ID=$(__sanitize_sql_integer "${ID_RAW}")
  psql -c "SELECT * FROM table WHERE id=${SAFE_ID}"
  ```

### Why SQL Sanitization Matters

SQL injection is a critical security vulnerability that occurs when user input is directly interpolated into SQL queries without proper sanitization. The sanitization functions ensure:

1. **String Values**: Single quotes are escaped to prevent breaking out of string literals
2. **Identifiers**: Table/column names are properly quoted to prevent injection
3. **Integers**: Values are validated to ensure they're numeric

### Implementation Example

**Before (Vulnerable)**:
```bash
NAME=$(grep "name" file | sed "s/'/''/")
psql -c "INSERT INTO table VALUES ('${NAME}')"
```

**After (Secure)**:
```bash
NAME_RAW=$(grep "name" file)
NAME=$(__sanitize_sql_string "${NAME_RAW}")
SANITIZED_ID=$(__sanitize_sql_integer "${ID}")
psql -c "INSERT INTO table VALUES ('${NAME}') WHERE id=${SANITIZED_ID}"
```

### Security Notes

- Always use sanitization functions when constructing dynamic SQL
- Never trust user input or external data sources
- Validate data types before using in SQL queries
- Prefer parameterized queries (`psql -v`) when possible

---

**Author**: Andres Gomez (AngocA)  
**Version**: 2025-07-27  
**Updated**: 2025-10-25 (Added SQL sanitization section)  
**Status**: Implemented and tested
