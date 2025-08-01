#!/usr/bin/env bats

# SQL validation integration tests
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

setup() {
 # Setup test environment
 export SCRIPT_BASE_DIRECTORY="$(cd "$(dirname "${BATS_TEST_FILENAME}")/../../.." && pwd)"
 export TMP_DIR="$(mktemp -d)"
 export BASENAME="test_sql_validation"
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

# Test that VACUUM and ANALYZE SQL statements are recognized
@test "VACUUM and ANALYZE SQL statements should be valid" {
 local sql_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_31_analyzeVacuum.sql"
 
 # Check if file exists
 if [[ ! -f "$sql_file" ]]; then
   skip "SQL file not found: $sql_file"
 fi
 
 # Test SQL validation
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
   __validate_sql_structure '$sql_file'
 "
 [ "$status" -eq 0 ]
}

# Test that all SQL files in the project are valid
@test "all SQL files should pass validation" {
 local sql_dir="${SCRIPT_BASE_DIRECTORY}/sql"
 local failed_files=()
 
 # Check if directory exists
 if [[ ! -d "$sql_dir" ]]; then
   skip "SQL directory not found: $sql_dir"
 fi
 
 # Test each SQL file
 while IFS= read -r -d '' sql_file; do
   if [[ -f "$sql_file" ]]; then
     # Test SQL validation
     run bash -c "
       source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
       __validate_sql_structure '$sql_file'
     "
     if [[ "$status" -ne 0 ]]; then
       failed_files+=("$sql_file")
     fi
   fi
 done < <(find "$sql_dir" -name "*.sql" -print0)
 
 # Report results
 if [[ ${#failed_files[@]} -eq 0 ]]; then
   echo "All SQL files passed validation"
 else
   echo "The following SQL files failed validation:"
   for file in "${failed_files[@]}"; do
     echo "  - $file"
   done
   return 1
 fi
}

# Test that specific SQL keywords are recognized
@test "all common SQL keywords should be recognized" {
 local keywords=("SELECT" "INSERT" "UPDATE" "DELETE" "CREATE" "DROP" "ALTER" "BEGIN" "COMMIT" "VACUUM" "ANALYZE" "REINDEX" "CLUSTER" "TRUNCATE" "GRANT" "REVOKE" "SAVEPOINT" "ROLLBACK")
 local failed_keywords=()
 
 # Create temporary SQL files for each keyword
 for keyword in "${keywords[@]}"; do
   local temp_sql="${TMP_DIR}/test_${keyword}.sql"
   echo "${keyword};" > "$temp_sql"
   
   # Test SQL validation
   run bash -c "
     source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
     __validate_sql_structure '$temp_sql'
   "
   if [[ "$status" -ne 0 ]]; then
     failed_keywords+=("$keyword")
   fi
 done
 
 # Report results
 if [[ ${#failed_keywords[@]} -eq 0 ]]; then
   echo "All SQL keywords are recognized"
 else
   echo "The following SQL keywords are not recognized:"
   for keyword in "${failed_keywords[@]}"; do
     echo "  - $keyword"
   done
   return 1
 fi
}

# Test that empty SQL files are rejected
@test "empty SQL files should be rejected" {
 local empty_sql="${TMP_DIR}/empty.sql"
 touch "$empty_sql"
 
 # Test SQL validation
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
   __validate_sql_structure '$empty_sql'
 "
 [ "$status" -eq 1 ]
 [[ "$output" == *"SQL file is empty"* ]]
}

# Test that SQL files with only comments are rejected
@test "SQL files with only comments should be rejected" {
 local comment_sql="${TMP_DIR}/comment.sql"
 cat > "$comment_sql" << 'EOF'
-- This is a comment
-- Another comment
-- No SQL statements here
EOF
 
 # Test SQL validation
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
   __validate_sql_structure '$comment_sql'
 "
 [ "$status" -eq 1 ]
 [[ "$output" == *"No SQL statements found"* ]]
}

# Test that SQL files with mixed content are accepted
@test "SQL files with mixed content should be accepted" {
 local mixed_sql="${TMP_DIR}/mixed.sql"
 cat > "$mixed_sql" << 'EOF'
-- This is a comment
SELECT * FROM table;
-- Another comment
INSERT INTO table VALUES (1, 2, 3);
-- More comments
UPDATE table SET column = 'value';
EOF
 
 # Test SQL validation
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
   __validate_sql_structure '$mixed_sql'
 "
 [ "$status" -eq 0 ]
}

# Test that the specific problematic file is now valid
@test "processPlanetNotes_31_analyzeVacuum.sql should be valid" {
 local sql_file="${SCRIPT_BASE_DIRECTORY}/sql/process/processPlanetNotes_31_analyzeVacuum.sql"
 
 # Check if file exists
 if [[ ! -f "$sql_file" ]]; then
   skip "SQL file not found: $sql_file"
 fi
 
 # Test SQL validation
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
   __validate_sql_structure '$sql_file'
 "
 [ "$status" -eq 0 ]
 [[ "$output" == *"SQL structure validation passed"* ]]
}

# Test that all process SQL files are valid
@test "all process SQL files should be valid" {
 local process_sql_dir="${SCRIPT_BASE_DIRECTORY}/sql/process"
 local failed_files=()
 
 # Check if directory exists
 if [[ ! -d "$process_sql_dir" ]]; then
   skip "Process SQL directory not found: $process_sql_dir"
 fi
 
 # Test each SQL file
 while IFS= read -r -d '' sql_file; do
   if [[ -f "$sql_file" ]]; then
     # Test SQL validation
     run bash -c "
       source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
       __validate_sql_structure '$sql_file'
     "
     if [[ "$status" -ne 0 ]]; then
       failed_files+=("$sql_file")
     fi
   fi
 done < <(find "$process_sql_dir" -name "*.sql" -print0)
 
 # Report results
 if [[ ${#failed_files[@]} -eq 0 ]]; then
   echo "All process SQL files are valid"
 else
   echo "The following process SQL files failed validation:"
   for file in "${failed_files[@]}"; do
     echo "  - $file"
   done
   return 1
 fi
}

# Test that all datamart SQL files are valid
@test "all datamart SQL files should be valid" {
 local datamart_dirs=(
   "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartCountries"
   "${SCRIPT_BASE_DIRECTORY}/sql/dwh/datamartUsers"
 )
 local failed_files=()
 
 # Test each datamart directory
 for datamart_dir in "${datamart_dirs[@]}"; do
   if [[ -d "$datamart_dir" ]]; then
     while IFS= read -r -d '' sql_file; do
       if [[ -f "$sql_file" ]]; then
         # Test SQL validation
         run bash -c "
           source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
           __validate_sql_structure '$sql_file'
         "
         if [[ "$status" -ne 0 ]]; then
           failed_files+=("$sql_file")
         fi
       fi
     done < <(find "$datamart_dir" -name "*.sql" -print0)
   fi
 done
 
 # Report results
 if [[ ${#failed_files[@]} -eq 0 ]]; then
   echo "All datamart SQL files are valid"
 else
   echo "The following datamart SQL files failed validation:"
   for file in "${failed_files[@]}"; do
     echo "  - $file"
   done
   return 1
 fi
}

# Test that the validation function handles edge cases correctly
@test "SQL validation should handle edge cases correctly" {
 # Test with non-existent file
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
   __validate_sql_structure '/non/existent/file.sql'
 "
 [ "$status" -eq 1 ]
 
 # Test with directory instead of file
 run bash -c "
   source '${SCRIPT_BASE_DIRECTORY}/bin/functionsProcess.sh' > /dev/null 2>&1
   __validate_sql_structure '${SCRIPT_BASE_DIRECTORY}/sql'
 "
 [ "$status" -eq 1 ]
}

# Test that the validation function is called correctly in scripts
@test "scripts should use SQL validation correctly" {
 local script_path="${SCRIPT_BASE_DIRECTORY}/bin/process/processPlanetNotes.sh"
 
 # Check if script exists
 if [[ ! -f "$script_path" ]]; then
   skip "Script not found: $script_path"
 fi
 
 # Test that the script sources the validation function
 run grep -q "__validate_sql_structure" "$script_path"
 [ "$status" -eq 0 ]
} 