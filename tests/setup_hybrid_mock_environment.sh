#!/bin/bash

# Setup hybrid mock environment for testing (only internet downloads mocked)
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

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

# Function to setup hybrid mock environment
setup_hybrid_mock_environment() {
 log_info "Setting up hybrid mock environment (internet downloads only)..."

 # Create mock commands directory if it doesn't exist
 mkdir -p "${MOCK_COMMANDS_DIR}"

 # Create only internet-related mock commands
 create_mock_wget
 create_mock_aria2c

 # Make mock commands executable
 chmod +x "${MOCK_COMMANDS_DIR}"/*

 log_success "Hybrid mock environment setup completed"
}

# Function to create mock wget
create_mock_wget() {
 if [[ ! -f "${MOCK_COMMANDS_DIR}/wget" ]]; then
  log_info "Creating mock wget..."
  cat > "${MOCK_COMMANDS_DIR}/wget" << 'EOF'
#!/bin/bash

# Mock wget command for testing (internet downloads only)
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

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
 <note id="124" lat="40.7129" lon="-74.0061" created_at="2023-01-01T01:00:00Z">
  <comment action="opened" timestamp="2023-01-01T01:00:00Z" uid="12346" user="testuser2">Another test note</comment>
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
   "properties": {"name": "Test Country", "admin_level": "2"},
   "geometry": {"type": "Polygon", "coordinates": [[[0,0],[1,0],[1,1],[0,1],[0,0]]]}
  },
  {
   "type": "Feature",
   "properties": {"name": "Test Maritime", "admin_level": "4"},
   "geometry": {"type": "Polygon", "coordinates": [[[2,2],[3,2],[3,3],[2,3],[2,2]]]}
  }
 ]
}
INNER_EOF
 elif [[ "$url" == *".bz2" ]]; then
   # Create a small bzip2 file with realistic content
   cat > "$output_file" << 'INNER_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note id="1001" lat="40.7128" lon="-74.0060" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="12345" user="testuser">Test note 1</comment>
 </note>
 <note id="1002" lat="40.7129" lon="-74.0061" created_at="2023-01-01T01:00:00Z">
  <comment action="opened" timestamp="2023-01-01T01:00:00Z" uid="12346" user="testuser2">Test note 2</comment>
  <comment action="commented" timestamp="2023-01-01T02:00:00Z" uid="12347" user="testuser3">This is a comment</comment>
 </note>
 <note id="1003" lat="40.7130" lon="-74.0062" created_at="2023-01-01T03:00:00Z" closed_at="2023-01-01T04:00:00Z">
  <comment action="opened" timestamp="2023-01-01T03:00:00Z" uid="12348" user="testuser4">Test note 3</comment>
  <comment action="closed" timestamp="2023-01-01T04:00:00Z" uid="12349" user="testuser5">Closing this note</comment>
 </note>
</osm-notes>
INNER_EOF
   # Compress the content
   bzip2 -c "$output_file" > "${output_file}.tmp" 2>/dev/null && mv "${output_file}.tmp" "$output_file" || true
 elif [[ "$url" == *".md5" ]]; then
   echo "d41d8cd98f00b204e9800998ecf8427e" > "$output_file"
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

# Function to create mock aria2c
create_mock_aria2c() {
 if [[ ! -f "${MOCK_COMMANDS_DIR}/aria2c" ]]; then
  log_info "Creating mock aria2c..."
  cat > "${MOCK_COMMANDS_DIR}/aria2c" << 'EOF'
#!/bin/bash

# Mock aria2c command for testing (internet downloads only)
# Author: Andres Gomez (AngocA)
# Version: 2025-08-01

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
 <note id="2001" lat="40.7128" lon="-74.0060" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="12345" user="testuser">Aria2c test note 1</comment>
 </note>
 <note id="2002" lat="40.7129" lon="-74.0061" created_at="2023-01-01T01:00:00Z">
  <comment action="opened" timestamp="2023-01-01T01:00:00Z" uid="12346" user="testuser2">Aria2c test note 2</comment>
  <comment action="commented" timestamp="2023-01-01T02:00:00Z" uid="12347" user="testuser3">Aria2c comment</comment>
 </note>
</osm-notes>
INNER_EOF
 elif [[ "$url" == *".bz2" ]]; then
   # Create a small bzip2 file with realistic content
   cat > "$output_file" << 'INNER_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm-notes>
 <note id="3001" lat="40.7128" lon="-74.0060" created_at="2023-01-01T00:00:00Z">
  <comment action="opened" timestamp="2023-01-01T00:00:00Z" uid="12345" user="testuser">Aria2c bz2 test note 1</comment>
 </note>
 <note id="3002" lat="40.7129" lon="-74.0061" created_at="2023-01-01T01:00:00Z">
  <comment action="opened" timestamp="2023-01-01T01:00:00Z" uid="12346" user="testuser2">Aria2c bz2 test note 2</comment>
 </note>
</osm-notes>
INNER_EOF
   # Compress the content
   bzip2 -c "$output_file" > "${output_file}.tmp" 2>/dev/null && mv "${output_file}.tmp" "$output_file" || true
 else
   echo "Mock aria2c content for $url" > "$output_file"
 fi
 
 echo "Mock file created: $output_file"
}

# Parse arguments
ARGS=()
OUTPUT_FILE=""
QUIET=false

while [[ $# -gt 0 ]]; do
 case $1 in
  -o)
   OUTPUT_FILE="$2"
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
if [[ -n "$OUTPUT_FILE" ]]; then
 create_mock_file "$URL" "$OUTPUT_FILE"
else
 create_mock_file "$URL"
fi

# Simulate download completion
if [[ "$QUIET" != true ]]; then
 echo "Download completed: ${OUTPUT_FILE:-$(basename "$URL")}"
fi

exit 0
EOF
 fi
}

# Function to activate hybrid mock environment
activate_hybrid_mock_environment() {
 log_info "Activating hybrid mock environment (internet downloads only)..."

 # Add mock commands to PATH (only internet-related)
 export PATH="${MOCK_COMMANDS_DIR}:${PATH}"

 # Set hybrid mock environment variables
 export HYBRID_MOCK_MODE=true
 export TEST_MODE=true
 export DBNAME="osm_notes" # Use real database name
 export DB_USER="${DB_USER:-postgres}"
 export DB_PASSWORD="${DB_PASSWORD:-}"

 log_success "Hybrid mock environment activated"
}

# Function to deactivate hybrid mock environment
deactivate_hybrid_mock_environment() {
 log_info "Deactivating hybrid mock environment..."

 # Remove mock commands from PATH
 export PATH=$(echo "$PATH" | sed "s|${MOCK_COMMANDS_DIR}:||g")

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

 if ! command -v awkproc > /dev/null 2>&1; then
  missing_commands+=("awkproc")
 fi

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
  echo "This environment mocks only internet downloads (wget, aria2c)"
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
