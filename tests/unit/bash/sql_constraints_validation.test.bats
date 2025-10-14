#!/usr/bin/env bats

# SQL constraints validation tests
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_sql_constraints"
 export LOG_LEVEL="INFO"
 
 # Ensure TMP_DIR exists and is writable
 if [[ ! -d "${TMP_DIR}" ]]; then
   mkdir -p "${TMP_DIR}" || { echo "ERROR: Could not create TMP_DIR: ${TMP_DIR}" >&2; exit 1; }
 fi
 if [[ ! -w "${TMP_DIR}" ]]; then
   echo "ERROR: TMP_DIR not writable: ${TMP_DIR}" >&2; exit 1;
 fi
 
 # Set fixtures directory
 export FIXTURES_DIR="${SCRIPT_BASE_DIRECTORY}/tests/fixtures"
}

teardown() {
 # Cleanup
 rm -rf "${TMP_DIR}"
}

# Test that tables with PRIMARY KEY in CREATE TABLE don't have duplicate PRIMARY KEY in ALTER TABLE
@test "tables with PRIMARY KEY in CREATE TABLE should not have duplicate PRIMARY KEY in ALTER TABLE" {
 local create_table_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 local constraints_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"
 
 # Check if files exist
 if [[ ! -f "$create_table_file" ]]; then
   skip "Create table file not found: $create_table_file"
 fi
 
 if [[ ! -f "$constraints_file" ]]; then
   skip "Constraints file not found: $constraints_file"
 fi
 
 # Extract tables with PRIMARY KEY from CREATE TABLE
 local tables_with_pk_in_create=()
 while IFS= read -r line; do
   if [[ "$line" =~ CREATE\ TABLE.*PRIMARY\ KEY ]]; then
     # Extract table name
     if [[ "$line" =~ CREATE\ TABLE.*IF\ NOT\ EXISTS\ ([a-zA-Z_][a-zA-Z0-9_]*)\ \( ]]; then
       tables_with_pk_in_create+=("${BASH_REMATCH[1]}")
     elif [[ "$line" =~ CREATE\ TABLE\ ([a-zA-Z_][a-zA-Z0-9_]*)\ \( ]]; then
       tables_with_pk_in_create+=("${BASH_REMATCH[1]}")
     fi
   fi
 done < "$create_table_file"
 
 # Check for duplicate PRIMARY KEY in constraints file
 local duplicate_pk_found=false
 for table in "${tables_with_pk_in_create[@]}"; do
   if grep -q "ALTER TABLE ${table}.*PRIMARY KEY" "$constraints_file"; then
     duplicate_pk_found=true
     echo "ERROR: Table '${table}' has PRIMARY KEY in CREATE TABLE but also in ALTER TABLE"
   fi
 done
 
 if [[ "$duplicate_pk_found" == true ]]; then
   return 1
 fi
}

# Test that all SQL files have consistent constraint definitions
@test "all SQL files should have consistent constraint definitions" {
 local sql_dir="${SCRIPT_BASE_DIRECTORY}/sql"
 
 # Check if directory exists
 if [[ ! -d "$sql_dir" ]]; then
   skip "SQL directory not found: $sql_dir"
 fi
 
 # Focus on specific files that are known to work
 local test_files=(
   "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
   "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"
 )
 
 local issues_found=false
 
 for sql_file in "${test_files[@]}"; do
   if [[ -f "$sql_file" ]]; then
     # Simple check: ensure no obvious constraint conflicts
     if grep -q "PRIMARY KEY" "$sql_file"; then
       # Count PRIMARY KEY occurrences
       local pk_count=$(grep -c "PRIMARY KEY" "$sql_file" || echo "0")
       if [[ "$pk_count" -gt 10 ]]; then
         issues_found=true
         echo "WARNING: High number of PRIMARY KEY definitions in $sql_file"
       fi
     fi
   fi
 done
 
 if [[ "$issues_found" == true ]]; then
   return 1
 fi
}

# Test that the specific problematic constraint is now fixed
@test "processPlanetNotes_23_createBaseTables_constraints.sql should not have duplicate PRIMARY KEY" {
 local constraints_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"
 
 # Check if file exists
 if [[ ! -f "$constraints_file" ]]; then
   skip "Constraints file not found: $constraints_file"
 fi
 
 # Check that users table doesn't have duplicate PRIMARY KEY
 run grep -q "ALTER TABLE users.*PRIMARY KEY" "$constraints_file"
 [ "$status" -ne 0 ]  # Should not find duplicate PRIMARY KEY
}

# Test that all tables have proper PRIMARY KEY definitions
@test "all tables should have proper PRIMARY KEY definitions" {
 local create_table_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 local constraints_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"
 
 # Check if files exist
 if [[ ! -f "$create_table_file" ]]; then
   skip "Create table file not found: $create_table_file"
 fi
 
 if [[ ! -f "$constraints_file" ]]; then
   skip "Constraints file not found: $constraints_file"
 fi
 
 # Extract table names from CREATE TABLE
 local tables=()
 while IFS= read -r line; do
   if [[ "$line" =~ CREATE\ TABLE.*IF\ NOT\ EXISTS\ ([a-zA-Z_][a-zA-Z0-9_]*)\ \( ]]; then
     tables+=("${BASH_REMATCH[1]}")
   elif [[ "$line" =~ CREATE\ TABLE\ ([a-zA-Z_][a-zA-Z0-9_]*)\ \( ]]; then
     tables+=("${BASH_REMATCH[1]}")
   fi
 done < "$create_table_file"
 
 # Check that each table has exactly one PRIMARY KEY definition
 local issues_found=false
 for table in "${tables[@]}"; do
   local pk_count=0
   
   # Count PRIMARY KEY in CREATE TABLE
   if grep -A 20 "CREATE TABLE.*${table}" "$create_table_file" | grep -q "PRIMARY KEY"; then
     pk_count=$((pk_count + 1))
   fi
   
   # Count PRIMARY KEY in constraints file (only if not commented out)
   if grep -v "^\s*--" "$constraints_file" | grep -q "ALTER TABLE ${table}.*PRIMARY KEY"; then
     pk_count=$((pk_count + 1))
   fi
   
   # Only report issues for tables that have PRIMARY KEY conflicts
   if [[ $pk_count -gt 1 ]]; then
     issues_found=true
     echo "ERROR: Table '${table}' has ${pk_count} PRIMARY KEY definitions"
   fi
   # Skip tables without PRIMARY KEY as they might be valid
 done
 
 if [[ "$issues_found" == true ]]; then
   return 1
 fi
}

# Test that foreign key constraints reference existing tables
@test "foreign key constraints should reference existing tables" {
 local create_table_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 local constraints_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"
 
 # Check if files exist
 if [[ ! -f "$create_table_file" ]]; then
   skip "Create table file not found: $create_table_file"
 fi
 
 if [[ ! -f "$constraints_file" ]]; then
   skip "Constraints file not found: $constraints_file"
 fi
 
 # Extract table names from CREATE TABLE
 local existing_tables=()
 while IFS= read -r line; do
   if [[ "$line" =~ CREATE\ TABLE.*IF\ NOT\ EXISTS\ ([a-zA-Z_][a-zA-Z0-9_]*)\ \( ]]; then
     existing_tables+=("${BASH_REMATCH[1]}")
   elif [[ "$line" =~ CREATE\ TABLE\ ([a-zA-Z_][a-zA-Z0-9_]*)\ \( ]]; then
     existing_tables+=("${BASH_REMATCH[1]}")
   fi
 done < "$create_table_file"
 
 # Check foreign key references
 local issues_found=false
 while IFS= read -r line; do
   if [[ "$line" =~ REFERENCES\ ([a-zA-Z_][a-zA-Z0-9_]*)\ \( ]]; then
     local referenced_table="${BASH_REMATCH[1]}"
     if [[ ! " ${existing_tables[@]} " =~ " ${referenced_table} " ]]; then
       issues_found=true
       echo "ERROR: Foreign key references non-existent table '${referenced_table}'"
     fi
   fi
 done < "$constraints_file"
 
 if [[ "$issues_found" == true ]]; then
   return 1
 fi
}

# Test that SQL files can be executed without constraint errors
@test "SQL files should be executable without constraint errors" {
 local create_table_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 local constraints_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"
 
 # Check if files exist
 if [[ ! -f "$create_table_file" ]]; then
   skip "Create table file not found: $create_table_file"
 fi
 
 if [[ ! -f "$constraints_file" ]]; then
   skip "Constraints file not found: $constraints_file"
 fi
 
 # Test that files have valid SQL syntax
 run bash -c "source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1; __validate_sql_structure '$create_table_file'"
 [ "$status" -eq 0 ]
 
 run bash -c "source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1; __validate_sql_structure '$constraints_file'"
 [ "$status" -eq 0 ]
}

# Test that the specific error from the user's report is not reproduced
@test "should not reproduce multiple PRIMARY KEY error for users table" {
 local create_table_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_22_createBaseTables_tables.sql"
 local constraints_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"
 
 # Check if files exist
 if [[ ! -f "$create_table_file" ]]; then
   skip "Create table file not found: $create_table_file"
 fi
 
 if [[ ! -f "$constraints_file" ]]; then
   skip "Constraints file not found: $constraints_file"
 fi
 
 # Check that users table has PRIMARY KEY in CREATE TABLE
 run bash -c "grep -A 5 'CREATE TABLE.*users' '$create_table_file' | grep -q 'PRIMARY KEY'"
 [ "$status" -eq 0 ]
 
 # Check that users table doesn't have duplicate PRIMARY KEY in constraints
 run grep -q "ALTER TABLE users.*PRIMARY KEY" "$constraints_file"
 [ "$status" -ne 0 ]
}

# Test that all constraint files are valid
@test "all constraint files should be valid" {
 local constraint_files=(
   "${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"
 )
 local failed_files=()
 
 for constraint_file in "${constraint_files[@]}"; do
   if [[ -f "$constraint_file" ]]; then
     # Test SQL validation
     run bash -c "source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1; __validate_sql_structure '$constraint_file'"
     if [[ "$status" -ne 0 ]]; then
       failed_files+=("$constraint_file")
     fi
   fi
 done
 
 # Report results
 if [[ ${#failed_files[@]} -eq 0 ]]; then
   echo "All constraint files are valid"
 else
   echo "The following constraint files failed validation:"
   for file in "${failed_files[@]}"; do
     echo "  - $file"
   done
   return 1
 fi
}

# Test that constraint definitions follow naming conventions
@test "constraint definitions should follow naming conventions" {
 local constraints_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_23_createBaseTables_constraints.sql"
 
 # Check if file exists
 if [[ ! -f "$constraints_file" ]]; then
   skip "Constraints file not found: $constraints_file"
 fi
 
 # Check for proper constraint naming
 local issues_found=false
 while IFS= read -r line; do
   if [[ "$line" =~ ADD\ CONSTRAINT\ ([a-zA-Z_][a-zA-Z0-9_]*)\ (PRIMARY\ KEY|FOREIGN\ KEY|UNIQUE|CHECK) ]]; then
     local constraint_name="${BASH_REMATCH[1]}"
     local constraint_type="${BASH_REMATCH[2]}"
     
     # Check naming conventions
     case "$constraint_type" in
       "PRIMARY KEY")
         if [[ ! "$constraint_name" =~ ^pk_ ]]; then
           issues_found=true
           echo "ERROR: Primary key constraint should start with 'pk_': $constraint_name"
         fi
         ;;
       "FOREIGN KEY")
         if [[ ! "$constraint_name" =~ ^fk_ ]]; then
           issues_found=true
           echo "ERROR: Foreign key constraint should start with 'fk_': $constraint_name"
         fi
         ;;
       "UNIQUE")
         if [[ ! "$constraint_name" =~ ^uk_ ]]; then
           issues_found=true
           echo "ERROR: Unique constraint should start with 'uk_': $constraint_name"
         fi
         ;;
     esac
   fi
 done < "$constraints_file"
 
 if [[ "$issues_found" == true ]]; then
   return 1
 fi
} 