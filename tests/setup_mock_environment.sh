#!/bin/bash

# Setup mock environment for testing
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
 echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
 echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
 echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
 echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MOCK_COMMANDS_DIR="${SCRIPT_DIR}/mock_commands"

# Function to setup mock environment
setup_mock_environment() {
 log_info "Setting up mock test environment..."

 # Create mock commands directory if it doesn't exist
 mkdir -p "${MOCK_COMMANDS_DIR}"

 # Create mock commands
 create_mock_psql
 create_mock_xmllint
 create_mock_aria2c
 create_mock_osmtogeojson
 create_mock_mutt
 # Note: ogr2ogr is only mocked when DB is mocked (full mock mode)
 # In hybrid mode (real DB), ogr2ogr should be real to import data
 # Note: bzip2 is not mocked - we use the real command
 # The aria2c mock copies a valid .bz2 fixture file, so bzip2 can decompress it normally

 # Make all mock commands executable
 chmod +x "${MOCK_COMMANDS_DIR}"/*

 log_success "Mock environment setup completed"
}

# Function to create mock psql
create_mock_psql() {
 # Always recreate the mock psql to ensure it has the latest logic
 log_info "Creating/updating mock psql..."
 cat > "${MOCK_COMMANDS_DIR}/psql" << 'EOF'
#!/bin/bash

# Mock psql command for testing
# Author: Andres Gomez (AngocA)
# Version: 2025-12-15

# Function to simulate database operations
mock_database_operation() {
 local operation="$1"
 local args="$2"
 
 case "$operation" in
  -d)
   # Database connection
   echo "Connected to database: $args"
   ;;
  -c)
   # SQL command
   # IMPORTANT: Check for COPY commands FIRST, before SELECT
   # The SQL may contain both COPY and SELECT commands, but COPY must be processed
   # Handle COPY ... TO commands that generate CSV files
   # The SQL may contain multiple COPY commands, so we need to process all of them
   # Note: We check for "COPY" followed by "TO" to ensure we're matching COPY commands,
   # not SELECT statements that might be inside COPY subqueries
   # Normalize SQL first to handle multi-line format
   local sql_check
   sql_check=$(echo "$args" | tr '\n' ' ' | tr '\r' ' ' | sed 's/[[:space:]]\+/ /g')
   
   # Debug: log what we're checking (only in test mode)
   if [[ "${TEST_MODE:-}" == "true" ]]; then
     echo "Mock psql: Checking SQL for COPY commands (length: ${#sql_check})" >&2
     echo "Mock psql: First 200 chars: ${sql_check:0:200}..." >&2
   fi
   
   # Check if SQL contains COPY ... TO pattern
   if echo "$sql_check" | grep -q "COPY.*TO" 2>/dev/null; then
     # Always log when COPY is detected (for debugging)
     echo "Mock psql: COPY.*TO pattern detected, processing COPY commands" >&2
     echo "Mock psql: SQL length: ${#sql_check}, first 300 chars: ${sql_check:0:300}..." >&2
     # Function to create CSV file based on path
     create_csv_file() {
       local filepath="$1"
       
       # Create directory if it doesn't exist
       local filedir
       filedir=$(dirname "$filepath")
       if [[ -n "$filedir" ]] && [[ "$filedir" != "." ]]; then
         mkdir -p "$filedir" 2>/dev/null || true
       fi
       
       # Create CSV file with header based on file name
       if [[ "$filepath" == *"lastNote"* ]] || [[ "$filepath" == *"LAST_NOTE"* ]]; then
         echo "note_id,latitude,longitude,created_at,status,closed_at" > "$filepath"
         echo "123,40.7128,-74.0060,2023-01-01 00:00:00,open," >> "$filepath"
       elif [[ "$filepath" == *"lastComment"* ]] || [[ "$filepath" == *"LAST_COMMENT"* ]]; then
         echo "comment_id,note_id,sequence_action,created_at,action,user_id,username" > "$filepath"
         echo "456,123,1,2023-01-01 00:00:00,opened,12345,testuser" >> "$filepath"
       elif [[ "$filepath" == *"differentNoteIds"* ]] || [[ "$filepath" == *"DIFFERENT_NOTE_IDS"* ]]; then
         echo "note_id,latitude,longitude,created_at,status,closed_at" > "$filepath"
         # Empty file (no differences) - just header
       elif [[ "$filepath" == *"differentCommentIds"* ]] || [[ "$filepath" == *"DIFFERENT_COMMENT_IDS"* ]]; then
         echo "comment_id,note_id,sequence_action,created_at,action,user_id,username" > "$filepath"
         # Empty file (no differences) - just header
       elif [[ "$filepath" == *"differentNotes"* ]] || [[ "$filepath" == *"DIFFERENT_NOTES"* ]] || [[ "$filepath" == *"DIRRERENT_NOTES"* ]]; then
         echo "note_id,latitude,longitude,created_at,status,closed_at" > "$filepath"
         # Empty file (no differences) - just header
       elif [[ "$filepath" == *"differentNoteComments"* ]] || [[ "$filepath" == *"DIFFERENT_COMMENTS"* ]] || [[ "$filepath" == *"DIRRERENT_COMMENTS"* ]]; then
         echo "comment_id,note_id,sequence_action,created_at,action,user_id,username" > "$filepath"
         # Empty file (no differences) - just header
       elif [[ "$filepath" == *"differentTextComments"* ]] || [[ "$filepath" == *"DIFFERENT_TEXT_COMMENTS"* ]]; then
         echo "text_comment_id,note_id,sequence_action,text" > "$filepath"
         # Empty file (no differences) - just header
       elif [[ "$filepath" == *"textComments"* ]] || [[ "$filepath" == *"DIFFERENCES_TEXT_COMMENT"* ]]; then
         echo "qty,note_id,sequence_action" > "$filepath"
         # Empty file (no differences) - just header
       else
         # Generic CSV file
         echo "id,value" > "$filepath"
       fi
     }
     
     # Process all COPY ... TO commands in the SQL
     # The SQL may have multi-line format, so we need to normalize it first
     # Normalize SQL: replace newlines with spaces and collapse multiple spaces
     local sql_normalized
     sql_normalized=$(echo "$args" | tr '\n' ' ' | tr '\r' ' ' | sed 's/[[:space:]]\+/ /g')
     
     # Extract all file paths from COPY ... TO 'path' patterns
     local temp_file
     temp_file=$(mktemp)
     
     # Extract all TO 'path' patterns from the normalized SQL
     # Use multiple methods to ensure we catch all paths
     
     # Method 1: Extract paths with single quotes followed by WITH
     echo "$sql_normalized" | sed -n "s/.*TO[[:space:]]*'\\([^']*\\)'[[:space:]]*WITH.*/\\1/p" >> "$temp_file" 2>/dev/null || true
     
     # Method 2: Extract paths with single quotes followed by semicolon
     echo "$sql_normalized" | sed -n "s/.*TO[[:space:]]*'\\([^']*\\)'[[:space:]]*;.*/\\1/p" >> "$temp_file" 2>/dev/null || true
     
     # Method 3: Extract paths with double quotes
     echo "$sql_normalized" | sed -n 's/.*TO[[:space:]]*"\([^"]*\)"[[:space:]]*WITH.*/\1/p' >> "$temp_file" 2>/dev/null || true
     echo "$sql_normalized" | sed -n 's/.*TO[[:space:]]*"\([^"]*\)"[[:space:]]*;.*/\1/p' >> "$temp_file" 2>/dev/null || true
     
     # Method 4: Split by COPY and extract from each COPY block (most reliable)
     # This handles multi-line SQL better
     {
       # Split SQL by COPY keyword to get individual COPY commands
       echo "$sql_normalized" | sed 's/COPY/\n---COPY---/g' | grep "^---COPY---" | sed 's/^---COPY---/COPY/' | while IFS= read -r copy_block; do
         # Extract path with single quotes from this COPY block
         echo "$copy_block" | sed -n "s/.*TO[[:space:]]*'\\([^']*\\)'.*/\\1/p"
         # Extract path with double quotes from this COPY block
         echo "$copy_block" | sed -n 's/.*TO[[:space:]]*"\([^"]*\)".*/\1/p'
       done
     } >> "$temp_file" 2>/dev/null || true
     
     # Method 5: Simple extraction - find all TO 'path' patterns (last resort)
     # This catches any remaining patterns
     echo "$sql_normalized" | grep -o "TO[[:space:]]*'[^']*'" | sed "s/TO[[:space:]]*'\\([^']*\\)'/\\1/" >> "$temp_file" 2>/dev/null || true
     echo "$sql_normalized" | grep -o 'TO[[:space:]]*"[^"]*"' | sed 's/TO[[:space:]]*"\([^"]*\)"/\1/' >> "$temp_file" 2>/dev/null || true
     
     # Remove duplicates and process each unique path
     local processed_paths=()
     while IFS= read -r filepath; do
       # Clean up the path (remove leading/trailing whitespace)
       filepath=$(echo "$filepath" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
       
       # Skip empty paths or paths with variables not substituted
       [[ -z "$filepath" ]] && continue
       [[ "$filepath" == *'$'* ]] && continue  # Skip if contains unsubstituted variable
       
       # Remove WITH clause if present
       filepath=$(echo "$filepath" | sed 's/[[:space:]]*WITH.*$//')
       
       # Check if we've already processed this path
       local already_processed=0
       for processed in "${processed_paths[@]}"; do
         if [[ "$processed" == "$filepath" ]]; then
           already_processed=1
           break
         fi
       done
       
       if [[ $already_processed -eq 0 ]]; then
         processed_paths+=("$filepath")
         create_csv_file "$filepath"
         # Always log CSV creation (for debugging)
         echo "Mock psql: Created CSV file: $filepath" >&2
       fi
     done < "$temp_file"
     
     rm -f "$temp_file"
     
     # Always show what was processed (for debugging)
     if [[ ${#processed_paths[@]} -gt 0 ]]; then
       echo "Mock psql: Processed ${#processed_paths[@]} COPY commands" >&2
       for path in "${processed_paths[@]}"; do
         echo "Mock psql:   - $path" >&2
       done
     else
       echo "Mock psql: WARNING - No paths were processed from COPY commands!" >&2
     fi
     
     # Output result for each COPY command found
     # PostgreSQL outputs one COPY result per command
     local copy_count=${#processed_paths[@]}
     if [[ $copy_count -gt 0 ]]; then
       # Output one COPY result per file created
       for filepath in "${processed_paths[@]}"; do
         local lines
         lines=$(wc -l < "$filepath" 2>/dev/null || echo 1)
         echo "COPY $lines"
       done
     else
       echo "COPY 0"
     fi
     # Exit early after processing COPY commands - don't process SELECT or other commands
     # This ensures COPY commands are handled even if SQL also contains SELECT
     # We've already output the COPY results, so we're done - exit the case with ;;
   else
     # If we get here, it means COPY was not processed, so handle other SQL commands
     if [[ "$sql_check" == *"SELECT"* ]]; then
       if [[ "${TEST_MODE:-}" == "true" ]]; then
         echo "Mock psql: No COPY commands found, processing SELECT" >&2
       fi
       if [[ "$sql_check" == *"COUNT"* ]]; then
         # Check for pg_extension queries (btree_gist, postgis)
         if [[ "$sql_check" == *"pg_extension"* ]] && [[ "$sql_check" == *"extname"* ]]; then
           if [[ "$sql_check" == *"btree_gist"* ]] || [[ "$sql_check" == *"postgis"* ]]; then
             echo "1"
           else
             echo "0"
           fi
         else
           echo "100"
         fi
       elif [[ "$sql_check" == *"TABLE_NAME"* ]]; then
         echo "notes"
        echo "note_comments"
        echo "countries"
        echo "logs"
       else
         echo "1|test|2023-01-01"
       fi
     elif [[ "$sql_check" == *"CREATE"* ]]; then
       echo "CREATE TABLE"
     elif [[ "$sql_check" == *"INSERT"* ]]; then
       echo "INSERT 0 1"
     elif [[ "$sql_check" == *"UPDATE"* ]]; then
       echo "UPDATE 1"
     elif [[ "$sql_check" == *"DELETE"* ]]; then
       echo "DELETE 1"
     elif [[ "$sql_check" == *"DROP"* ]]; then
       echo "DROP TABLE"
     elif [[ "$sql_check" == *"VACUUM"* ]]; then
       echo "VACUUM"
     elif [[ "$sql_check" == *"ANALYZE"* ]]; then
       echo "ANALYZE"
     else
       echo "OK"
     fi
   fi
   ;;
  -f)
   # SQL file
   if [[ -f "$args" ]]; then
     echo "Executing SQL file: $args"
     echo "OK"
   else
     echo "ERROR: File not found: $args" >&2
     exit 1
   fi
   ;;
  -v)
   # Variable assignment - write to stderr, not stdout
   echo "Variable set: $args" >&2
   ;;
  --version)
   echo "psql (PostgreSQL) 15.1"
   exit 0
   ;;
  *)
   echo "Unknown operation: $operation $args"
   ;;
 esac
}

# Parse arguments
ARGS=()
DATABASE=""
COMMAND=""
FILE=""
VARIABLES=()
LIST_DATABASES=false
QUIET_MODE=false
TUPLE_ONLY=false

while [[ $# -gt 0 ]]; do
 case $1 in
  -d)
   DATABASE="$2"
   shift 2
   ;;
  -c)
   COMMAND="$2"
   shift 2
   ;;
  -f)
   FILE="$2"
   shift 2
   ;;
  -v)
   VARIABLES+=("$2")
   shift 2
   ;;
  -l)
   LIST_DATABASES=true
   shift
   ;;
  -q)
   QUIET_MODE=true
   shift
   ;;
  -t)
   TUPLE_ONLY=true
   shift
   ;;
  --version)
   echo "psql (PostgreSQL) 15.1"
   exit 0
   ;;
  -*)
   # Handle combined flags like -lqt
   if [[ "$1" == *"l"* ]]; then
    LIST_DATABASES=true
   fi
   if [[ "$1" == *"q"* ]]; then
    QUIET_MODE=true
   fi
   if [[ "$1" == *"t"* ]]; then
    TUPLE_ONLY=true
   fi
   shift
   ;;
  *)
   ARGS+=("$1")
   shift
   ;;
 esac
done

# Handle list databases request
if [[ "$LIST_DATABASES" == "true" ]]; then
 # Return list of databases including osm-notes-test
 if [[ "$TUPLE_ONLY" == "true" ]]; then
  # -t flag: tuple only (no headers)
  echo "template0"
  echo "template1"
  echo "postgres"
  echo "osm-notes-test"
 else
  # Normal list format
  echo "                                  List of databases"
  echo "   Name    |  Owner   | Encoding |   Collate   |    Ctype    | ICU Locale | Locale Provider |   Access privileges"
  echo "-----------+----------+----------+-------------+-------------+------------+-----------------+---------------------"
  echo " template0 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |            | libc            | =c/postgres"
  echo " template1 | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |            | libc            | =c/postgres"
  echo " postgres  | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |            | libc            |"
  echo " osm-notes-test | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |            | libc            |"
 fi
 exit 0
fi

# Process variables first (output to stderr, not stdout)
for var in "${VARIABLES[@]}"; do
 mock_database_operation "-v" "$var" >&2
done

# Process main operation
if [[ -n "$DATABASE" ]]; then
 mock_database_operation "-d" "$DATABASE"
fi

if [[ -n "$COMMAND" ]]; then
 mock_database_operation "-c" "$COMMAND"
fi

if [[ -n "$FILE" ]]; then
 mock_database_operation "-f" "$FILE"
fi

exit 0
EOF
 chmod +x "${MOCK_COMMANDS_DIR}/psql"
}

# Function to create mock xmllint
create_mock_xmllint() {
 # Always recreate the mock xmllint to ensure it has the latest logic
 log_info "Creating/updating mock xmllint..."
  cat > "${MOCK_COMMANDS_DIR}/xmllint" << 'EOF'
#!/bin/bash

# Mock xmllint command for testing
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

# Function to simulate XML validation
mock_xml_validation() {
 local file="$1"
 local schema="$2"
 
 # Check if file exists
 if [[ ! -f "$file" ]]; then
   echo "ERROR: File not found: $file" >&2
   return 1
 fi
 
 # Simulate validation based on file content
 if grep -q "osm-notes" "$file" 2>/dev/null; then
   echo "XML validation passed: $file"
   return 0
 elif grep -q "xs:schema" "$file" 2>/dev/null; then
   echo "XML Schema validation passed: $file"
   return 0
 else
   echo "ERROR: Invalid XML structure: $file" >&2
   return 1
 fi
}

# Function to simulate XPath queries
mock_xpath_query() {
 local file="$1"
 local xpath="$2"
 
 # Check if file exists
 if [[ ! -f "$file" ]]; then
   echo "ERROR: File not found: $file" >&2
   return 1
 fi
 
 # Simulate XPath results
 case "$xpath" in
  "count(//note)")
   echo "5"
   ;;
  "//osm-notes")
   echo "<osm-notes>"
   echo "  <note id=\"123\" lat=\"40.7128\" lon=\"-74.0060\">"
   echo "    <comment action=\"opened\" timestamp=\"2023-01-01T00:00:00Z\">Test note</comment>"
   echo "  </note>"
   echo "</osm-notes>"
   ;;
  *)
   echo "Mock XPath result for: $xpath"
   ;;
 esac
}

# Parse arguments
ARGS=()
NOOUT=false
SCHEMA=""
XPATH=""
QUIET=false

while [[ $# -gt 0 ]]; do
 case $1 in
  --noout)
   NOOUT=true
   shift
   ;;
  --schema)
   SCHEMA="$2"
   shift 2
   ;;
  --xpath)
   XPATH="$2"
   shift 2
   ;;
  -q)
   QUIET=true
   shift
   ;;
  --version)
   echo "xmllint: using libxml version 20900"
   exit 0
   ;;
  -*)
   # Skip other options
   shift
   ;;
  *)
   ARGS+=("$1")
   shift
   ;;
 esac
done

# Get file from arguments
FILE="${ARGS[0]:-}"

if [[ -z "$FILE" ]]; then
 echo "Usage: xmllint [OPTIONS] FILE" >&2
 exit 1
fi

# Process based on options
if [[ -n "$XPATH" ]]; then
 mock_xpath_query "$FILE" "$XPATH"
elif [[ -n "$SCHEMA" ]]; then
 mock_xml_validation "$FILE" "$SCHEMA"
else
 mock_xml_validation "$FILE"
fi

exit $?
EOF
 chmod +x "${MOCK_COMMANDS_DIR}/xmllint"
}

# Function to create mock aria2c
create_mock_aria2c() {
 # Always recreate the mock aria2c to ensure it has the latest logic
 log_info "Creating/updating mock aria2c..."
  cat > "${MOCK_COMMANDS_DIR}/aria2c" << 'EOF'
#!/bin/bash

# Mock aria2c command for testing
# Author: Andres Gomez (AngocA)
# Version: 2025-11-13

# Function to create mock files
create_mock_file() {
 local url="$1"
 local output_file="$2"
 local output_dir="$3"
 
 # Build full path if directory is specified
 if [[ -n "$output_dir" && -n "$output_file" ]]; then
   output_file="${output_dir}/${output_file}"
 elif [[ -n "$output_dir" ]]; then
   output_file="${output_dir}/$(basename "$url")"
 fi
 
 # Extract filename from URL if no output file specified
 if [[ -z "$output_file" ]]; then
   output_file=$(basename "$url")
 fi
   
 # Ensure directory exists
 local file_dir
 file_dir=$(dirname "$output_file")
 if [[ -n "$file_dir" && "$file_dir" != "." ]]; then
   mkdir -p "$file_dir"
 fi
 
 # Create mock content based on URL
 if [[ "$url" == *".xml" ]]; then
   cat > "$output_file" << 'INNER_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note id="123" lat="40.7128" lon="-74.0060" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="12345" user="testuser">Test note</comment>
 </note>
</osm-notes>
INNER_EOF
 elif [[ "$url" == *".bz2" ]] || [[ "$url" == *".osn.bz2" ]]; then
   # Use pre-prepared fixture file instead of generating on the fly
   # This ensures the file is always valid and avoids PATH resolution issues
   # Find the fixture file by trying multiple possible paths
   local fixture_file=""
   
   # Function to find project root from a starting directory
   find_project_root() {
     local start_dir="$1"
     local search_dir="${start_dir}"
     while [[ "${search_dir}" != "/" ]]; do
       if [[ -d "${search_dir}/tests" ]] && [[ -d "${search_dir}/tests/fixtures" ]] && [[ -f "${search_dir}/tests/fixtures/planet-notes-latest.osn.bz2" ]]; then
         echo "${search_dir}"
         return 0
       fi
       search_dir=$(dirname "${search_dir}")
     done
     return 1
   }
   
   # Try multiple starting points to find the project root
   local project_root=""
   
   # 1. Try from SCRIPT_BASE_DIRECTORY environment variable (if set)
   if [[ -n "${SCRIPT_BASE_DIRECTORY:-}" ]] && [[ -d "${SCRIPT_BASE_DIRECTORY}" ]]; then
     project_root=$(find_project_root "${SCRIPT_BASE_DIRECTORY}" 2>/dev/null || true)
   fi
   
   # 2. Try from current working directory (PWD)
   if [[ -z "${project_root}" ]]; then
     project_root=$(find_project_root "${PWD}" 2>/dev/null || true)
   fi
   
   # 3. Try from the directory where this script is located
   if [[ -z "${project_root}" ]]; then
     local script_dir
     script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || echo "")"
     if [[ -n "${script_dir}" ]]; then
       project_root=$(find_project_root "${script_dir}" 2>/dev/null || true)
     fi
   fi
   
   # 4. Try absolute path (hardcoded fallback)
   if [[ -z "${project_root}" ]] && [[ -f "/home/angoca/github/OSM-Notes-Ingestion/tests/fixtures/planet-notes-latest.osn.bz2" ]]; then
     project_root="/home/angoca/github/OSM-Notes-Ingestion"
   fi
   
   # Try multiple possible paths for the fixture file
   for possible_path in "${project_root}/tests/fixtures/planet-notes-latest.osn.bz2" "/home/angoca/github/OSM-Notes-Ingestion/tests/fixtures/planet-notes-latest.osn.bz2"; do
     if [[ -n "${possible_path}" ]] && [[ -f "${possible_path}" ]]; then
       fixture_file="${possible_path}"
       break
     fi
   done
   
   # Check if fixture file exists
   if [[ -n "${fixture_file}" ]] && [[ -f "${fixture_file}" ]]; then
     # Copy the pre-prepared fixture file
     cp "${fixture_file}" "$output_file" 2>/dev/null
     local copy_exit=$?
     if [[ $copy_exit -ne 0 ]]; then
       echo "Error: Failed to copy fixture file from ${fixture_file}" >&2
       exit 1
     fi
     # Verify the copied file is actually a bzip2 file
     if ! file "$output_file" 2>/dev/null | grep -q "bzip2"; then
       echo "Error: Copied file is not a valid bzip2 file" >&2
       rm -f "$output_file" 2>/dev/null || true
       exit 1
     fi
   else
     echo "Error: Fixture file not found. Searched from:" >&2
     echo "  - SCRIPT_BASE_DIRECTORY: ${SCRIPT_BASE_DIRECTORY:-not set}" >&2
     echo "  - PWD: ${PWD}" >&2
     echo "  - Script dir: $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || echo unknown)" >&2
     echo "  - Project root found: ${project_root:-none}" >&2
     echo "Please ensure tests/fixtures/planet-notes-latest.osn.bz2 exists in the project root" >&2
     exit 1
   fi
 else
   echo "Mock content for $url" > "$output_file"
 fi
 
 echo "Mock file created: $output_file"
}

# Parse arguments
ARGS=()
OUTPUT_FILE=""
OUTPUT_DIR=""
QUIET=false

while [[ $# -gt 0 ]]; do
 case $1 in
  -d)
   OUTPUT_DIR="$2"
   shift 2
   ;;
  -o)
   OUTPUT_FILE="$2"
   shift 2
   ;;
  -x)
   # Number of connections (ignore)
   shift 2
   ;;
  -q)
   QUIET=true
   shift
   ;;
  --version)
   echo "aria2c version 1.36.0"
   exit 0
   ;;
  -*)
   # Skip other options
   shift
   ;;
  *)
   ARGS+=("$1")
   shift
   ;;
 esac
done

# Get URL from arguments
URL="${ARGS[0]:-}"

if [[ -z "$URL" ]]; then
 echo "Usage: aria2c [OPTIONS] URL" >&2
 exit 1
fi

# Create mock file
create_mock_file "$URL" "$OUTPUT_FILE" "$OUTPUT_DIR"

# Simulate download completion
if [[ "$QUIET" != true ]]; then
 final_name=""
 if [[ -n "$OUTPUT_DIR" && -n "$OUTPUT_FILE" ]]; then
   final_name="${OUTPUT_DIR}/${OUTPUT_FILE}"
 elif [[ -n "$OUTPUT_DIR" ]]; then
   final_name="${OUTPUT_DIR}/$(basename "$URL")"
 elif [[ -n "$OUTPUT_FILE" ]]; then
   final_name="$OUTPUT_FILE"
 else
   final_name=$(basename "$URL")
 fi
 echo "Download completed: $final_name"
fi

exit 0
EOF
 chmod +x "${MOCK_COMMANDS_DIR}/aria2c"
}

# Function create_mock_bzip2 removed - we now use the real bzip2 command
# The aria2c mock copies a valid .bz2 fixture file, so bzip2 can decompress it normally

# Function to create mock osmtogeojson
create_mock_osmtogeojson() {
 # Always recreate the mock osmtogeojson to ensure it has the latest logic
 log_info "Creating/updating mock osmtogeojson..."
  cat > "${MOCK_COMMANDS_DIR}/osmtogeojson" << 'EOF'
#!/bin/bash

# Mock osmtogeojson command for testing
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

# Parse arguments
ARGS=()

while [[ $# -gt 0 ]]; do
 case $1 in
  --version)
   echo "osmtogeojson 1.0.0"
   exit 0
   ;;
  -*)
   # Skip other options
   shift
   ;;
  *)
   ARGS+=("$1")
   shift
   ;;
 esac
done

# Get file from arguments
FILE="${ARGS[0]:-}"

if [[ -z "$FILE" ]]; then
 echo "Usage: osmtogeojson [OPTIONS] FILE" >&2
 exit 1
fi

# Check if file exists
if [[ ! -f "$FILE" ]]; then
 echo "ERROR: File not found: $FILE" >&2
 exit 1
fi

# Create mock GeoJSON output
cat << 'INNER_EOF'
{
 "type": "FeatureCollection",
 "features": [
  {
   "type": "Feature",
   "properties": {
    "name": "Test Country",
    "admin_level": "2",
    "boundary": "administrative"
   },
   "geometry": {
    "type": "Polygon",
    "coordinates": [[[0,0],[1,0],[1,1],[0,1],[0,0]]]
   }
  }
 ]
}
INNER_EOF

exit 0
EOF
 chmod +x "${MOCK_COMMANDS_DIR}/osmtogeojson"
}

# Function to create mock mutt
create_mock_mutt() {
 # Always recreate the mock mutt to ensure it has the latest logic
 log_info "Creating/updating mock mutt..."
  cat > "${MOCK_COMMANDS_DIR}/mutt" << 'EOF'
#!/bin/bash

# Mock mutt command for testing
# Author: Andres Gomez (AngocA)
# Version: 2025-11-12

# Parse arguments
ARGS=()
SUBJECT=""
BODY_FILE=""
ATTACHMENT=""
RECIPIENTS=""
QUIET=false

while [[ $# -gt 0 ]]; do
 case $1 in
  -s)
   SUBJECT="$2"
   shift 2
   ;;
  -i)
   BODY_FILE="$2"
   shift 2
   ;;
  -a)
   ATTACHMENT="$2"
   shift 2
   ;;
  --)
   # Recipients come after --
   shift
   RECIPIENTS="$*"
   break
   ;;
  --version)
   echo "Mutt 2.2.0"
   exit 0
   ;;
  -*)
   # Skip other options
   shift
   ;;
  *)
   ARGS+=("$1")
   shift
   ;;
 esac
done

# Simulate email sending (just log it)
if [[ -n "${SUBJECT}" ]]; then
 echo "Mock email sent:"
 echo "  Subject: ${SUBJECT}"
 if [[ -n "${BODY_FILE}" ]] && [[ -f "${BODY_FILE}" ]]; then
   echo "  Body: $(head -5 "${BODY_FILE}" | tr '\n' ' ')"
 fi
 if [[ -n "${ATTACHMENT}" ]]; then
   echo "  Attachment: ${ATTACHMENT}"
 fi
 if [[ -n "${RECIPIENTS}" ]]; then
   echo "  Recipients: ${RECIPIENTS}"
 fi
fi

exit 0
EOF
 chmod +x "${MOCK_COMMANDS_DIR}/mutt"
}

# Function to create mock ogr2ogr
create_mock_ogr2ogr() {
 if [[ ! -f "${MOCK_COMMANDS_DIR}/ogr2ogr" ]]; then
  log_info "Creating mock ogr2ogr..."
  cat > "${MOCK_COMMANDS_DIR}/ogr2ogr" << 'EOF'
#!/bin/bash

# Mock ogr2ogr command for testing
# Author: Andres Gomez (AngocA)
# Version: 2025-11-12

# Parse arguments
ARGS=()
OUTPUT=""
INPUT=""
QUIET=false

while [[ $# -gt 0 ]]; do
 case $1 in
  -f)
   OUTPUT_FORMAT="$2"
   shift 2
   ;;
  -nln)
   LAYER_NAME="$2"
   shift 2
   ;;
  -nlt)
   GEOMETRY_TYPE="$2"
   shift 2
   ;;
  -q)
   QUIET=true
   shift
   ;;
  --version)
   echo "GDAL 3.6.0"
   exit 0
   ;;
  -*)
   # Skip other options
   shift
   ;;
  *)
   ARGS+=("$1")
   shift
   ;;
 esac
done

# Get input and output from arguments
if [[ ${#ARGS[@]} -ge 2 ]]; then
 OUTPUT="${ARGS[0]}"
 INPUT="${ARGS[1]}"
elif [[ ${#ARGS[@]} -eq 1 ]]; then
 OUTPUT="${ARGS[0]}"
fi

# Simulate conversion (just verify files exist)
if [[ -n "${INPUT}" ]] && [[ ! -f "${INPUT}" ]]; then
 echo "ERROR: Input file not found: ${INPUT}" >&2
 exit 1
fi

if [[ -n "${OUTPUT}" ]]; then
 # Create a dummy output file
 touch "${OUTPUT}" 2>/dev/null || true
fi

if [[ "$QUIET" != true ]]; then
 echo "Mock ogr2ogr: Converted ${INPUT:-stdin} to ${OUTPUT:-stdout}"
fi

exit 0
EOF
 fi
}

# Function to activate mock environment
activate_mock_environment() {
 log_info "Activating mock environment..."

 # Add mock commands to PATH
 export PATH="${MOCK_COMMANDS_DIR}:${PATH}"

 # Set mock environment variables
 export MOCK_MODE=true
 export TEST_MODE=true
 # Database variables are loaded from properties file, do not export
 # to prevent overriding properties file values in child scripts

 log_success "Mock environment activated"
}

# Function to deactivate mock environment
deactivate_mock_environment() {
 log_info "Deactivating mock environment..."

 # Remove mock commands from PATH
 export PATH=$(echo "$PATH" | sed "s|${MOCK_COMMANDS_DIR}:||g")

 # Unset mock environment variables
 unset MOCK_MODE
 unset TEST_MODE
 # Database variables are controlled by properties file, do not unset

 log_success "Mock environment deactivated"
}

# Main execution
case "${1:-}" in
setup)
 setup_mock_environment
 ;;
activate)
 activate_mock_environment
 ;;
deactivate)
 deactivate_mock_environment
 ;;
test)
 setup_mock_environment
 activate_mock_environment
 log_info "Running tests with mock environment..."
 # Add your test commands here
 deactivate_mock_environment
 ;;
--help | -h)
 echo "Usage: $0 [COMMAND]"
 echo
 echo "Commands:"
 echo "  setup      Setup mock environment (create mock commands)"
 echo "  activate   Activate mock environment (set PATH and variables)"
 echo "  deactivate Deactivate mock environment (restore original PATH)"
 echo "  test       Setup, activate, run tests, and deactivate"
 echo "  --help     Show this help"
 exit 0
 ;;
*)
 log_error "Unknown command: ${1:-}"
 log_error "Use --help for usage information"
 exit 1
 ;;
esac
