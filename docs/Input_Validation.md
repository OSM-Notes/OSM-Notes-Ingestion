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
  - Uses `xmllint` and `xmlstarlet`

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
  - Extracts dates using XPath expressions
  - Default XPath: `//@created_at|//@closed_at|//@timestamp|//date`
  - Requires `xmlstarlet` for XPath processing

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
  __logi "Validating XML schema files..."
  if ! __validate_xml_structure "${XMLSCHEMA_PLANET_NOTES}" "osm-notes"; then
    __loge "ERROR: XML schema validation failed: ${XMLSCHEMA_PLANET_NOTES}"
    exit "${ERROR_MISSING_LIBRARY}"
  fi
  
  # Validate XSLT files
  __logi "Validating XSLT files..."
  if ! __validate_input_file "${XSLT_NOTES_PLANET_FILE}" "XSLT notes file"; then
    __loge "ERROR: XSLT notes file validation failed: ${XSLT_NOTES_PLANET_FILE}"
    exit "${ERROR_MISSING_LIBRARY}"
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

**Author**: Andres Gomez (AngocA)  
**Version**: 2025-07-27  
**Status**: Implemented and tested
