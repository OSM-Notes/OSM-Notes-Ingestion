#!/bin/bash

# Setup hybrid mock environment for testing (only internet downloads mocked)
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

set -euo pipefail

# Colors for output (only define if not already set)
if [[ -z "${RED:-}" ]]; then
  RED='\033[0;31m'
fi
if [[ -z "${GREEN:-}" ]]; then
  GREEN='\033[0;32m'
fi
if [[ -z "${YELLOW:-}" ]]; then
  YELLOW='\033[1;33m'
fi
if [[ -z "${BLUE:-}" ]]; then
  BLUE='\033[0;34m'
fi
if [[ -z "${NC:-}" ]]; then
  NC='\033[0m' # No Color
fi

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

# Configuration (only define if not already set)
if [[ -z "${SCRIPT_DIR:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -z "${MOCK_COMMANDS_DIR:-}" ]]; then
  MOCK_COMMANDS_DIR="${SCRIPT_DIR}/mock_commands"
fi

# Function to setup hybrid mock environment
setup_hybrid_mock_environment() {
 log_info "Setting up hybrid mock environment (internet downloads only)..."

 # Create mock commands directory if it doesn't exist
 mkdir -p "${MOCK_COMMANDS_DIR}"

# Create only internet-related mock commands
create_mock_aria2c
 # Create mock ogr2ogr for transparent country data insertion
 create_mock_ogr2ogr

 # Make mock commands executable
 for file in "${MOCK_COMMANDS_DIR}"/*; do
  if [[ -f "${file}" ]]; then
   chmod +x "${file}" 2> /dev/null || true
  fi
 done

 log_success "Hybrid mock environment setup completed"
}

# Function to create mock aria2c
create_mock_aria2c() {
 if [[ ! -f "${MOCK_COMMANDS_DIR}/aria2c" ]]; then
  log_info "Creating mock aria2c..."
  cat > "${MOCK_COMMANDS_DIR}/aria2c" << 'EOF'
#!/bin/bash

# Mock aria2c command for testing (internet downloads only)
# Author: Andres Gomez (AngocA)
# Version: 2025-12-07

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
 <note id="2001" lat="40.7128" lon="-74.0060" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="12345" user="testuser">Aria2c test note 1</comment>
 </note>
 <note id="2002" lat="40.7129" lon="-74.0061" created_at="2023-01-01T01:00:00Z">
  <comment action="opened" timestamp="2023-01-01T01:00:00Z" uid="12346" user="testuser2">Aria2c test note 2</comment>
  <comment action="commented" timestamp="2023-01-01T02:00:00Z" uid="12347" user="testuser3">Aria2c comment</comment>
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
     # Fallback: Create a minimal valid bzip2 file if fixture not found
     # Create a simple XML content and compress it with bzip2
     if command -v bzip2 >/dev/null 2>&1; then
       cat > "${output_file}.tmp" << 'BZIP2_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note id="1001" lat="40.7128" lon="-74.0060" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="12345" user="testuser">Mock bzip2 test note</comment>
 </note>
</osm-notes>
BZIP2_EOF
       bzip2 -c "${output_file}.tmp" > "$output_file" 2>/dev/null
       rm -f "${output_file}.tmp" 2>/dev/null || true
       # Verify the file was created successfully
       if [[ ! -f "$output_file" ]] || [[ ! -s "$output_file" ]]; then
         echo "Error: Failed to create bzip2 file" >&2
         exit 1
       fi
     else
       # Last resort: create a file that looks like bzip2 (magic bytes)
       # This is not a valid bzip2 but will pass basic file checks
       printf '\x42\x5a\x68' > "$output_file"
       echo "Mock bzip2 content" >> "$output_file"
     fi
   fi
 else
   echo "Mock aria2c content for $url" > "$output_file"
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

# Function to create mock ogr2ogr
create_mock_ogr2ogr() {
 # Always create/update the mock ogr2ogr with hybrid mode logic
 # This ensures it has the correct logic for hybrid mode (delegate to real ogr2ogr when not countries/import)
 log_info "Creating mock ogr2ogr for transparent country data insertion..."
 cat > "${MOCK_COMMANDS_DIR}/ogr2ogr" << 'OGR2OGR_EOF'
#!/bin/bash

# Mock ogr2ogr command for hybrid mode testing
# When importing to import table, inserts test data into import table only.
# The script (updateCountries.sh) will copy data from import to countries table.
# When importing directly to countries table, inserts test data directly.
# This is completely transparent to updateCountries.sh
# Author: Andres Gomez (AngocA)
# Version: 2025-12-14

# Parse arguments
DBNAME="${DBNAME:-osm-notes}"
LAYER_NAME=""
INPUT_FILE=""
OUTPUT_DB=""
IS_COUNTRIES_TABLE=false
GEOM_COLUMN="geom"  # Default geometry column name

# Detect mode: hybrid (use real ogr2ogr for most operations) vs mock (simulate everything)
# HYBRID_MOCK_DIR is set in hybrid mode, MOCK_COMMANDS_DIR is set in both modes
IS_HYBRID_MODE=false
if [[ -n "${HYBRID_MOCK_DIR:-}" ]] && [[ "${PATH}" == *"${HYBRID_MOCK_DIR}"* ]]; then
 IS_HYBRID_MODE=true
fi

# Debug: Log that mock was called (redirect to stderr so it doesn't interfere with ogr2ogr output)
# This helps verify the mock is being executed
if [[ "${HYBRID_MOCK_DEBUG:-false}" == "true" ]]; then
 echo "Mock ogr2ogr DEBUG: called with args: $*" >&2
 echo "Mock ogr2ogr DEBUG: IS_HYBRID_MODE=${IS_HYBRID_MODE}" >&2
 echo "Mock ogr2ogr DEBUG: PATH=${PATH}" >&2
fi

# Save all arguments for later parsing
ALL_ARGS=("$@")

while [[ $# -gt 0 ]]; do
 case $1 in
  -f)
   OUTPUT_FORMAT="$2"
   shift 2
   ;;
  -nln)
   LAYER_NAME="$2"
   if [[ "$LAYER_NAME" == "countries" ]]; then
    IS_COUNTRIES_TABLE=true
   elif [[ "$LAYER_NAME" == "import" ]] || [[ "$LAYER_NAME" == "countries_import" ]] || [[ "$LAYER_NAME" == *"_import" ]]; then
    # Import table is used as temporary table before mapping to countries
    # We'll detect this and insert directly into countries
    IS_COUNTRIES_TABLE=true
   fi
   shift 2
   ;;
  -nlt)
   GEOMETRY_TYPE="$2"
   shift 2
   ;;
  -a_srs)
   SRS="$2"
   shift 2
   ;;
  -lco)
   # Capture layer creation options, especially GEOMETRY_NAME
   LCO_VALUE="$2"
   if [[ "$LCO_VALUE" == *"GEOMETRY_NAME"* ]]; then
    # Extract value from GEOMETRY_NAME=value
    # Handle both formats: GEOMETRY_NAME=geometry and GEOMETRY_NAME=geom
    if [[ "$LCO_VALUE" =~ GEOMETRY_NAME=([^[:space:]]+) ]]; then
     GEOM_COLUMN="${BASH_REMATCH[1]}"
    elif [[ "$LCO_VALUE" == "GEOMETRY_NAME" ]]; then
     # If next argument is the value (separate argument)
     if [[ $# -ge 3 ]]; then
      GEOM_COLUMN="$3"
      shift 1
     fi
    fi
   fi
   shift 2
   ;;
  -select)
   # Skip field selection - we'll insert all needed fields anyway
   shift 2
   ;;
  -mapFieldType)
   # Skip field type mapping
   shift 2
   ;;
  -skipfailures)
   # Skip failures flag - just continue
   shift
   ;;
  --config)
   # Skip config options
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
   if [[ "$1" == *"PG:dbname"* ]] || [[ "$1" == *"PostgreSQL"* ]]; then
    OUTPUT_DB="$1"
    # Extract DBNAME from PostgreSQL connection string if present
    # Format: PG:dbname=DBNAME or PG:dbname=DBNAME host=... etc.
    if [[ "$OUTPUT_DB" =~ dbname=([^[:space:]]+) ]]; then
     DBNAME="${BASH_REMATCH[1]}"
    fi
   elif [[ -z "$INPUT_FILE" ]]; then
    # Check if it's a file (exists) or looks like a file path (ends with .geojson, .json, etc.)
    if [[ -f "$1" ]]; then
     INPUT_FILE="$1"
    elif [[ "$1" == *".geojson"* ]] || [[ "$1" == *".json"* ]]; then
     # Even if file doesn't exist yet, capture it as input file
     # This handles cases where ogr2ogr is called before the file is created
     INPUT_FILE="$1"
    fi
   fi
   shift
   ;;
 esac
done

# If in hybrid mode and NOT importing to countries/import tables, delegate to real ogr2ogr
if [[ "${IS_HYBRID_MODE}" == "true" ]] && [[ "${IS_COUNTRIES_TABLE}" != "true" ]]; then
 # Find real ogr2ogr by temporarily removing mock directories from PATH
 REAL_OGR2OGR=""
 OLD_PATH="${PATH}"
 # Temporarily remove mock directories from PATH to find real ogr2ogr
 NEW_PATH=$(echo "${OLD_PATH}" | sed "s|${HYBRID_MOCK_DIR}:||g" | sed "s|:${HYBRID_MOCK_DIR}||g")
 if [[ -n "${MOCK_COMMANDS_DIR:-}" ]]; then
  NEW_PATH=$(echo "${NEW_PATH}" | sed "s|${MOCK_COMMANDS_DIR}:||g" | sed "s|:${MOCK_COMMANDS_DIR}||g")
 fi
 PATH="${NEW_PATH}" REAL_OGR2OGR=$(command -v ogr2ogr 2> /dev/null || true)
 PATH="${OLD_PATH}"
 
 if [[ -n "${REAL_OGR2OGR}" ]] && [[ -x "${REAL_OGR2OGR}" ]]; then
  # Delegate to real ogr2ogr
  if [[ "${HYBRID_MOCK_DEBUG:-false}" == "true" ]]; then
   echo "Mock ogr2ogr DEBUG: Delegating to real ogr2ogr: ${REAL_OGR2OGR}" >&2
  fi
  exec "${REAL_OGR2OGR}" "${ALL_ARGS[@]}"
 else
  # Real ogr2ogr not found, simulate success
  if [[ "$QUIET" != "true" ]]; then
   echo "Mock ogr2ogr: Real ogr2ogr not found, simulating success" >&2
  fi
  exit 0
 fi
fi

# If importing to countries table (or import table which maps to countries), insert test data directly
if [[ "${IS_COUNTRIES_TABLE}" == "true" ]]; then
 # Find real psql by temporarily removing mock directories from PATH
 REAL_PSQL=""
 if [[ -n "${MOCK_COMMANDS_DIR:-}" ]]; then
  OLD_PATH="${PATH}"
  # Temporarily remove mock directory from PATH to find real psql
  NEW_PATH=$(echo "${OLD_PATH}" | sed "s|${MOCK_COMMANDS_DIR}:||g" | sed "s|:${MOCK_COMMANDS_DIR}||g")
  # Also remove hybrid_mock_dir if it exists
  if [[ -n "${HYBRID_MOCK_DIR:-}" ]]; then
   NEW_PATH=$(echo "${NEW_PATH}" | sed "s|${HYBRID_MOCK_DIR}:||g" | sed "s|:${HYBRID_MOCK_DIR}||g")
  fi
  PATH="${NEW_PATH}" REAL_PSQL=$(command -v psql 2> /dev/null || true)
  PATH="${OLD_PATH}"
 else
  # If MOCK_COMMANDS_DIR not set, just search PATH normally
  REAL_PSQL=$(command -v psql 2> /dev/null || true)
 fi

 if [[ -z "${REAL_PSQL}" ]] || [[ ! -x "${REAL_PSQL}" ]]; then
  echo "Error: Real psql not found. Cannot insert test countries data." >&2
  exit 1
 fi

 # Handle import table or countries table
 if [[ "$LAYER_NAME" == "import" ]] || [[ "$LAYER_NAME" == "countries_import" ]] || [[ "$LAYER_NAME" == *"_import" ]]; then
  # If importing to temporary import table, create it and populate it with test data
  # The script will then map this data to the countries table
  # Check for import table names (could be "import" or "countries_import" or any table ending in "_import")
  # GEOM_COLUMN is already set from parsing -lco GEOMETRY_NAME above
  # Default is "geom" which matches what the script uses
  
  # Try to extract boundary ID from input file name
  # boundaryProcessingFunctions.sh uses files like: ${TMP_DIR}/${ID}.geojson
  # Extract ID from filename if possible
  BOUNDARY_ID=""
  if [[ -n "${INPUT_FILE:-}" ]] && [[ -f "${INPUT_FILE}" ]]; then
   # Try to extract ID from filename like: /tmp/updateCountries_XXXXX/148838.geojson
   BASENAME_FILE=$(basename "${INPUT_FILE}" .geojson)
   if [[ "${BASENAME_FILE}" =~ ^[0-9]+$ ]]; then
    BOUNDARY_ID="${BASENAME_FILE}"
   fi
  fi
  
  # Create the temporary table that ogr2ogr expects
  # Use real psql explicitly
  # Don't use ON_ERROR_STOP=1 here to avoid failing if table doesn't exist
  "${REAL_PSQL}" -d "${DBNAME}" -c "DROP TABLE IF EXISTS ${LAYER_NAME};" > /dev/null 2>&1 || true
  
  # Determine table structure based on what columns are expected
  # boundaryProcessingFunctions.sh uses -select name,admin_level,type
  # but processPlanetFunctions.sh expects id, name, name_es, name_en, geom
  # We'll create a table with both sets of columns to handle both cases
  # Don't use ON_ERROR_STOP=1 to avoid failing if there's a minor error
  # Create table - ignore errors (table might already exist)
  "${REAL_PSQL}" -d "${DBNAME}" << EOF 2>/dev/null || true
CREATE TABLE ${LAYER_NAME} (
 id VARCHAR,
 name VARCHAR,
 name_es VARCHAR,
 name_en VARCHAR,
 admin_level VARCHAR,
 type VARCHAR,
 ${GEOM_COLUMN} GEOMETRY
);
EOF
  
  # If we have a boundary ID, try to insert data that matches that specific boundary
  # Otherwise, insert generic test data
  if [[ -n "${BOUNDARY_ID}" ]]; then
   # Insert data for this specific boundary ID into import table
   # Use a simple geometry that will work with ST_Union(ST_makeValid())
   # Use a valid geometry that doesn't cross the 180 meridian to avoid PostGIS errors
   # Don't use ON_ERROR_STOP=1 to avoid failing if insert fails
   # NOTE: We only insert into import table. The script (updateCountries.sh) will copy
   # data from import to countries table using its normal flow.
   "${REAL_PSQL}" -d "${DBNAME}" << EOF 2>/dev/null || true
INSERT INTO ${LAYER_NAME} (name, admin_level, type, ${GEOM_COLUMN}) VALUES
 ('Country ${BOUNDARY_ID}', '2', 'boundary', ST_GeomFromText('POLYGON((-10 -10, 10 -10, 10 10, -10 10, -10 -10))', 4326));
EOF
   if [[ "$QUIET" != "true" ]]; then
    echo "Mock ogr2ogr: Inserted test data for boundary ${BOUNDARY_ID} into ${LAYER_NAME} table" >&2
   fi
  else
   # Insert generic test data (fallback)
   # Use a valid geometry that doesn't cross the 180 meridian to avoid PostGIS errors
   # Don't use ON_ERROR_STOP=1 to avoid failing if insert fails
   # NOTE: We only insert into import table. The script (updateCountries.sh) will copy
   # data from import to countries table using its normal flow.
   "${REAL_PSQL}" -d "${DBNAME}" << EOF 2>/dev/null || true
INSERT INTO ${LAYER_NAME} (name, admin_level, type, ${GEOM_COLUMN}) VALUES
 ('Test Country', '2', 'boundary', ST_GeomFromText('POLYGON((-10 -10, 10 -10, 10 10, -10 10, -10 -10))', 4326));
EOF
   if [[ "$QUIET" != "true" ]]; then
    echo "Mock ogr2ogr: Inserted generic test data into ${LAYER_NAME} table (boundary ID not detected)" >&2
   fi
  fi
  # Always return success (exit 0) to simulate successful ogr2ogr import
  exit 0
 fi

 if [[ "$LAYER_NAME" == "countries" ]]; then
  # If importing directly to countries table, insert test data directly
  # Insert test countries with simple but valid geometries
  # These cover major regions to allow get_country() function to work
  # Don't use ON_ERROR_STOP=1 to avoid failing if insert fails
  "${REAL_PSQL}" -d "${DBNAME}" << 'SQL' 2>/dev/null || true
INSERT INTO countries (country_id, country_name, geom, updated) VALUES
 (1, 'United States', ST_GeomFromText('POLYGON((-125 25, -66 25, -66 49, -125 49, -125 25))', 4326), FALSE),
 (2, 'Canada', ST_GeomFromText('POLYGON((-141 42, -52 42, -52 83, -141 83, -141 42))', 4326), FALSE),
 (3, 'Mexico', ST_GeomFromText('POLYGON((-118 14, -86 14, -86 32, -118 32, -118 14))', 4326), FALSE),
 (4, 'United Kingdom', ST_GeomFromText('POLYGON((-8 50, 2 50, 2 61, -8 61, -8 50))', 4326), FALSE),
 (5, 'France', ST_GeomFromText('POLYGON((-5 42, 8 42, 8 51, -5 51, -5 42))', 4326), FALSE),
 (6, 'Germany', ST_GeomFromText('POLYGON((6 47, 15 47, 15 55, 6 55, 6 47))', 4326), FALSE),
 (7, 'Spain', ST_GeomFromText('POLYGON((-10 36, 4 36, 4 44, -10 44, -10 36))', 4326), FALSE),
 (8, 'Italy', ST_GeomFromText('POLYGON((7 36, 19 36, 19 47, 7 47, 7 36))', 4326), FALSE),
 (9, 'Brazil', ST_GeomFromText('POLYGON((-74 -34, -34 -34, -34 6, -74 6, -74 -34))', 4326), FALSE),
 (10, 'Argentina', ST_GeomFromText('POLYGON((-73 -55, -54 -55, -54 -22, -73 -22, -73 -55))', 4326), FALSE),
 (11, 'Colombia', ST_GeomFromText('POLYGON((-79 4, -67 4, -67 12, -79 12, -79 4))', 4326), FALSE),
 (12, 'China', ST_GeomFromText('POLYGON((73 18, 135 18, 135 54, 73 54, 73 18))', 4326), FALSE),
 (13, 'Japan', ST_GeomFromText('POLYGON((123 24, 146 24, 146 46, 123 46, 123 24))', 4326), FALSE),
 (14, 'India', ST_GeomFromText('POLYGON((68 6, 97 6, 97 37, 68 37, 68 6))', 4326), FALSE),
 (15, 'Australia', ST_GeomFromText('POLYGON((113 -44, 154 -44, 154 -10, 113 -10, 113 -44))', 4326), FALSE),
 (16, 'Russia', ST_GeomFromText('POLYGON((19 41, 180 41, 180 82, 19 82, 19 41))', 4326), FALSE),
 (17, 'South Africa', ST_GeomFromText('POLYGON((16 -35, 33 -35, 33 -22, 16 -22, 16 -35))', 4326), FALSE),
 (18, 'Egypt', ST_GeomFromText('POLYGON((25 22, 37 22, 37 32, 25 32, 25 22))', 4326), FALSE),
 (19, 'Nigeria', ST_GeomFromText('POLYGON((3 4, 15 4, 15 14, 3 14, 3 4))', 4326), FALSE),
 (20, 'Turkey', ST_GeomFromText('POLYGON((26 36, 45 36, 45 42, 26 42, 26 36))', 4326), FALSE)
ON CONFLICT (country_id) DO NOTHING;
SQL
  if [[ "$QUIET" != "true" ]]; then
   echo "Mock ogr2ogr: Inserted test countries data directly into countries table" >&2
  fi
  # Always return success (exit 0) to simulate successful ogr2ogr import
  exit 0
 fi
fi

# For other tables in mock mode (not hybrid), simulate success
# In hybrid mode, we already delegated above, so this should not be reached
# But if we reach here, simulate success for mock mode
if [[ "${IS_HYBRID_MODE}" != "true" ]]; then
 # Mock mode: simulate success
 if [[ "$QUIET" != "true" ]]; then
  echo "Mock ogr2ogr: Simulating successful import (mock mode)"
 fi
 exit 0
fi

# Fallback: if we reach here in hybrid mode and it's not countries/import, try real ogr2ogr
# Find real ogr2ogr by temporarily removing mock directories from PATH
REAL_OGR2OGR=""
OLD_PATH="${PATH}"
# Temporarily remove mock directories from PATH to find real ogr2ogr
NEW_PATH=$(echo "${OLD_PATH}" | sed "s|${HYBRID_MOCK_DIR}:||g" | sed "s|:${HYBRID_MOCK_DIR}||g")
if [[ -n "${MOCK_COMMANDS_DIR:-}" ]]; then
 NEW_PATH=$(echo "${NEW_PATH}" | sed "s|${MOCK_COMMANDS_DIR}:||g" | sed "s|:${MOCK_COMMANDS_DIR}||g")
fi
PATH="${NEW_PATH}" REAL_OGR2OGR=$(command -v ogr2ogr 2> /dev/null || true)
PATH="${OLD_PATH}"

if [[ -n "${REAL_OGR2OGR}" ]] && [[ -x "${REAL_OGR2OGR}" ]]; then
 # Use real ogr2ogr for non-countries tables
 exec "${REAL_OGR2OGR}" "${ALL_ARGS[@]}"
else
 # Simulate success for other operations
 if [[ "$QUIET" != "true" ]]; then
  echo "Mock ogr2ogr: Simulated conversion (real ogr2ogr not available)"
 fi
 exit 0
fi
OGR2OGR_EOF
 chmod +x "${MOCK_COMMANDS_DIR}/ogr2ogr"
}

# Function to activate hybrid mock environment
activate_hybrid_mock_environment() {
 log_info "Activating hybrid mock environment (internet downloads only)..."

 # Export MOCK_COMMANDS_DIR so mock ogr2ogr can find real ogr2ogr
 export MOCK_COMMANDS_DIR="${MOCK_COMMANDS_DIR}"

 # Add mock commands to PATH (only internet-related)
 export PATH="${MOCK_COMMANDS_DIR}:${PATH}"
 hash -r 2> /dev/null || true

 local aria2c_path
 aria2c_path=$(command -v aria2c 2> /dev/null || true)
 if [[ "${aria2c_path}" == "${MOCK_COMMANDS_DIR}/aria2c" ]]; then
  log_info "Mock aria2c detected: ${aria2c_path}"
 else
  log_warning "Mock aria2c not detected. Current path: ${aria2c_path:-unknown}"
  log_warning "Ensure ${MOCK_COMMANDS_DIR} precedes PATH"
 fi

 # Define awkproc as a wrapper around awk
 # awkproc mimics an XSLT processor style interface for AWK scripts
 awkproc() {
   # Parse arguments
   local awk_file=""
   local input_file=""
   
   # Parse --maxdepth and --stringparam flags
   while [[ $# -gt 0 ]]; do
     case "$1" in
       --maxdepth)
         # Ignore maxdepth parameter for AWK
         shift 2
         ;;
       --stringparam)
         # Ignore stringparam for AWK (we don't use it in our AWK scripts)
         shift 2
         ;;
       -o)
         # Ignore output file parameter for AWK (we use redirection instead)
         shift 2
         ;;
       *.awk)
         awk_file="$1"
         shift
         ;;
       *)
         if [[ -z "$input_file" ]]; then
           input_file="$1"
         fi
         shift
         ;;
     esac
   done
   
   # Run awk with the input file
   if [[ -n "$awk_file" ]] && [[ -n "$input_file" ]]; then
     awk -f "$awk_file" "$input_file"
   elif [[ -n "$awk_file" ]]; then
     awk -f "$awk_file"
   else
     echo "Error: awkproc requires an AWK file" >&2
     return 1
   fi
 }

 # Export the function so it's available in subshells
 export -f awkproc

 # Set hybrid mock environment variables
 export HYBRID_MOCK_MODE=true
 export TEST_MODE=true
 # Only set DBNAME if not already set (allow override from calling script)
 if [[ -z "${DBNAME:-}" ]]; then
   export DBNAME="osm_notes" # Use real database name
 fi
 export DB_USER="${DB_USER:-postgres}"
 export DB_PASSWORD="${DB_PASSWORD:-}"

 log_success "Hybrid mock environment activated"
}

# Function to deactivate hybrid mock environment
deactivate_hybrid_mock_environment() {
 log_info "Deactivating hybrid mock environment..."

 # Remove mock commands from PATH
 local new_path
 new_path=$(echo "$PATH" | sed "s|${MOCK_COMMANDS_DIR}:||g")
 export PATH="$new_path"
 hash -r 2> /dev/null || true

 # Unset the awkproc function
 unset -f awkproc

 # Unset hybrid mock environment variables
 unset HYBRID_MOCK_MODE
 unset TEST_MODE
 unset DBNAME
 unset DB_USER
 unset DB_PASSWORD

 log_success "Hybrid mock environment deactivated"
}

# Function to check if real commands are available
check_real_commands() {
 log_info "Checking availability of real commands..."

 local missing_commands=()

 # Check database commands
 if ! command -v psql > /dev/null 2>&1; then
  missing_commands+=("psql")
 fi

 # Check XML processing commands
 if ! command -v xmllint > /dev/null 2>&1; then
  missing_commands+=("xmllint")
 fi

 # awkproc is now defined as a function, so we don't need to check for it

 # Check compression commands
 if ! command -v bzip2 > /dev/null 2>&1; then
  missing_commands+=("bzip2")
 fi

 # Check conversion commands
 if ! command -v osmtogeojson > /dev/null 2>&1; then
  log_warning "osmtogeojson not found - some tests may fail"
 fi

 if [[ ${#missing_commands[@]} -gt 0 ]]; then
  log_error "Missing required commands: ${missing_commands[*]}"
  log_error "Please install the missing commands before running hybrid tests"
  return 1
 else
  log_success "All required real commands are available"
  return 0
 fi
}

# Main execution - only run when script is executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
 case "${1:-}" in
 setup)
  setup_hybrid_mock_environment
  ;;
 activate)
  activate_hybrid_mock_environment
  ;;
 deactivate)
  deactivate_hybrid_mock_environment
  ;;
 check)
  check_real_commands
  ;;
 test)
  setup_hybrid_mock_environment
  check_real_commands
  activate_hybrid_mock_environment
  log_info "Running hybrid tests with real database and XML processing..."
  # Add your test commands here
  deactivate_hybrid_mock_environment
  ;;
 --help | -h)
  echo "Usage: $0 [COMMAND]"
  echo
  echo "Commands:"
  echo "  setup      Setup hybrid mock environment (internet downloads only)"
  echo "  activate   Activate hybrid mock environment"
  echo "  deactivate Deactivate hybrid mock environment"
  echo "  check      Check if real commands are available"
  echo "  test       Setup, check, activate, run tests, and deactivate"
  echo "  --help     Show this help"
  echo
  echo "This environment mocks only internet downloads (aria2c)"
  echo "but uses real commands for database and XML processing."
  exit 0
  ;;
 *)
  log_error "Unknown command: ${1:-}"
  log_error "Use --help for usage information"
  exit 1
  ;;
 esac
fi

