# Input Validation Functions

## Overview

This document describes the centralized input validation functions that have been added to the OSM-Notes-profile project to address the critical issue of **"Falta de Validación de Entrada"** (Lack of Input Validation).

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

## Available Functions

### 1. `__validate_input_file()`

Validates basic file properties (existence, readability, type).

**Parameters:**

- `$1`: File path to validate
- `$2`: Description of the file (optional)
- `$3`: Expected file type (optional: "file", "dir", "executable")

**Returns:**

- `0` if valid, `1` if invalid

**Example:**

```bash
if ! __validate_input_file "/path/to/file.sql" "SQL script"; then
  echo "ERROR: File validation failed"
  exit 1
fi
```

### 2. `__validate_input_files()`

Validates multiple files at once.

**Parameters:**

- `$@`: List of file paths to validate

**Returns:**

- `0` if all valid, `1` if any invalid

**Example:**

```bash
files=("file1.sql" "file2.xml" "file3.csv")
if ! __validate_input_files "${files[@]}"; then
  echo "ERROR: Some files are invalid"
  exit 1
fi
```

### 3. `__validate_sql_structure()`

Validates SQL files for basic structure and content.

**Parameters:**

- `$1`: SQL file path

**Returns:**

- `0` if valid, `1` if invalid

**Example:**

```bash
if ! __validate_sql_structure "database_setup.sql"; then
  echo "ERROR: SQL file is invalid"
  exit 1
fi
```

### 4. `__validate_xml_structure()`

Validates XML files for syntax and optional root element.

**Parameters:**

- `$1`: XML file path
- `$2`: Expected root element (optional)

**Returns:**

- `0` if valid, `1` if invalid

**Example:**

```bash
if ! __validate_xml_structure "notes.xml" "osm-notes"; then
  echo "ERROR: XML file is invalid"
  exit 1
fi
```

### 5. `__validate_csv_structure()`

Validates CSV files for structure and optional column count.

**Parameters:**

- `$1`: CSV file path
- `$2`: Expected number of columns (optional)

**Returns:**

- `0` if valid, `1` if invalid

**Example:**

```bash
if ! __validate_csv_structure "data.csv" "5"; then
  echo "ERROR: CSV file is invalid"
  exit 1
fi
```

### 6. `__validate_config_file()`

Validates configuration files for proper format.

**Parameters:**

- `$1`: Config file path

**Returns:**

- `0` if valid, `1` if invalid

**Example:**

```bash
if ! __validate_config_file "config.properties"; then
  echo "ERROR: Configuration file is invalid"
  exit 1
fi
```

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
}
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
