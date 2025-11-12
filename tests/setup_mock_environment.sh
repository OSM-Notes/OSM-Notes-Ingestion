#!/bin/bash

# Setup mock environment for testing
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

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
 create_mock_wget
 create_mock_psql
 create_mock_xmllint
 create_mock_aria2c
 create_mock_osmtogeojson
 # Note: bzip2 is not mocked - we use the real command
 # The aria2c mock copies a valid .bz2 fixture file, so bzip2 can decompress it normally

 # Make all mock commands executable
 chmod +x "${MOCK_COMMANDS_DIR}"/*

 log_success "Mock environment setup completed"
}

# Function to create mock wget
create_mock_wget() {
 if [[ ! -f "${MOCK_COMMANDS_DIR}/wget" ]]; then
  log_info "Creating mock wget..."
  cat > "${MOCK_COMMANDS_DIR}/wget" << 'EOF'
#!/bin/bash

# Mock wget command for testing
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

# Function to create mock files
create_mock_file() {
 local url="$1"
 local output_file="$2"
 
 # Extract filename from URL if no output file specified
 if [[ -z "$output_file" ]]; then
   output_file=$(basename "$url")
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
 elif [[ "$url" == *".json" ]]; then
   cat > "$output_file" << 'INNER_EOF'
{
 "type": "FeatureCollection",
 "features": [
  {
   "type": "Feature",
   "properties": {"name": "Test Country"},
   "geometry": {"type": "Polygon", "coordinates": [[[0,0],[1,0],[1,1],[0,1],[0,0]]]}
  }
 ]
}
INNER_EOF
 elif [[ "$url" == *".bz2" ]]; then
   # Create a small bzip2 file
   echo "Mock bzip2 content" | bzip2 > "$output_file" 2>/dev/null || echo "Mock bzip2 content" > "$output_file"
 elif [[ "$url" == *".md5" ]]; then
   # When downloading an MD5 file, calculate the MD5 of the related file
   # The related file should be in the same directory without the .md5 extension
   local related_file
   related_file="${output_file%.md5}"
   
   # Check if the related file exists
   if [[ -f "$related_file" ]]; then
     # Calculate MD5 of the related file
     local md5_checksum
     if command -v md5sum > /dev/null 2>&1; then
       md5_checksum=$(md5sum < "$related_file" | cut -d ' ' -f 1)
     elif command -v md5 > /dev/null 2>&1; then
       md5_checksum=$(md5 -q < "$related_file")
     else
       # Fallback to fixed checksum if md5 command is not available
       md5_checksum="d41d8cd98f00b204e9800998ecf8427e"
     fi
     echo "$md5_checksum" > "$output_file"
   else
     # If related file doesn't exist, use default checksum
     echo "d41d8cd98f00b204e9800998ecf8427e" > "$output_file"
   fi
 else
   echo "Mock content for $url" > "$output_file"
 fi
 
 echo "Mock file created: $output_file"
}

# Parse arguments
ARGS=()
OUTPUT_FILE=""
QUIET=false
TIMEOUT=""
POST_FILE=""

while [[ $# -gt 0 ]]; do
 case $1 in
  -O)
   OUTPUT_FILE="$2"
   shift 2
   ;;
  -q)
   QUIET=true
   shift
   ;;
  --timeout=*)
   TIMEOUT="${1#*=}"
   shift
   ;;
  --post-file=*)
   POST_FILE="${1#*=}"
   shift
   ;;
  --version)
   echo "GNU Wget 1.21.3"
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
 echo "Usage: wget [OPTIONS] URL" >&2
 exit 1
fi

# Create mock file
if [[ -n "$OUTPUT_FILE" ]]; then
 create_mock_file "$URL" "$OUTPUT_FILE"
else
 create_mock_file "$URL"
fi

# Simulate HTTP response
if [[ "$QUIET" != true ]]; then
 echo "HTTP/1.1 200 OK"
 echo "Content-Type: application/octet-stream"
 echo "Content-Length: $(wc -c < "${OUTPUT_FILE:-$(basename "$URL")}" 2>/dev/null || echo "0")"
 echo ""
fi

exit 0
EOF
 fi
}

# Function to create mock psql
create_mock_psql() {
 if [[ ! -f "${MOCK_COMMANDS_DIR}/psql" ]]; then
  log_info "Creating mock psql..."
  cat > "${MOCK_COMMANDS_DIR}/psql" << 'EOF'
#!/bin/bash

# Mock psql command for testing
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

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
   if [[ "$args" == *"SELECT"* ]]; then
     if [[ "$args" == *"COUNT"* ]]; then
       echo "100"
     elif [[ "$args" == *"TABLE_NAME"* ]]; then
       echo "notes"
       echo "note_comments"
       echo "countries"
       echo "logs"
       echo "tries"
     else
       echo "1|test|2023-01-01"
     fi
   elif [[ "$args" == *"CREATE"* ]]; then
     echo "CREATE TABLE"
   elif [[ "$args" == *"INSERT"* ]]; then
     echo "INSERT 0 1"
   elif [[ "$args" == *"UPDATE"* ]]; then
     echo "UPDATE 1"
   elif [[ "$args" == *"DELETE"* ]]; then
     echo "DELETE 1"
   elif [[ "$args" == *"DROP"* ]]; then
     echo "DROP TABLE"
   elif [[ "$args" == *"VACUUM"* ]]; then
     echo "VACUUM"
   elif [[ "$args" == *"ANALYZE"* ]]; then
     echo "ANALYZE"
   else
     echo "OK"
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
   # Variable assignment
   echo "Variable set: $args"
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
  --version)
   echo "psql (PostgreSQL) 15.1"
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

# Process variables first
for var in "${VARIABLES[@]}"; do
 mock_database_operation "-v" "$var"
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
 fi
}

# Function to create mock xmllint
create_mock_xmllint() {
 if [[ ! -f "${MOCK_COMMANDS_DIR}/xmllint" ]]; then
  log_info "Creating mock xmllint..."
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
 fi
}

# Function to create mock aria2c
create_mock_aria2c() {
 if [[ ! -f "${MOCK_COMMANDS_DIR}/aria2c" ]]; then
  log_info "Creating mock aria2c..."
  cat > "${MOCK_COMMANDS_DIR}/aria2c" << 'EOF'
#!/bin/bash

# Mock aria2c command for testing
# Author: Andres Gomez (AngocA)
# Version: 2025-01-23

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
 fi
}

# Function create_mock_bzip2 removed - we now use the real bzip2 command
# The aria2c mock copies a valid .bz2 fixture file, so bzip2 can decompress it normally

# Function to create mock osmtogeojson
create_mock_osmtogeojson() {
 if [[ ! -f "${MOCK_COMMANDS_DIR}/osmtogeojson" ]]; then
  log_info "Creating mock osmtogeojson..."
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
 export DBNAME="mock_db"
 export DB_USER="mock_user"
 export DB_PASSWORD="mock_password"

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
 unset DBNAME
 unset DB_USER
 unset DB_PASSWORD

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
