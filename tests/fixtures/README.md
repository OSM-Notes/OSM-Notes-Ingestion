# Test Fixtures and Sample Data

This directory contains test fixtures, sample data, and mock files used by the
test suite.

## Directory Structure

```
fixtures/
├── command/          # Command fixtures for mock commands
│   └── extra/       # JSON, XML, and data files
├── special_cases/   # Special case XML scenarios
├── xml/             # XML test data files
├── sample_data.sql  # SQL sample data
└── planet-notes-latest.osn.xml  # Planet dump sample
```

## Fixture Types

### 1. Command Fixtures (`command/extra/`)

**Purpose**: Deterministic fixture files used by mock commands for offline
testing.

**Location**: `tests/fixtures/command/extra/`

**Contents**:
- **JSON files**: Note IDs (e.g., `3394115.json`) used for API testing
- **XML files**: OSM notes data (e.g., `OSM-notes-API-0.xml`, `apiCall_1.xml`,
  `mockPlanetDump.osn.xml`)
- **Data files**: Boundaries data (`countries`, `maritimes`)

**Usage**: Mock commands in `tests/mock_commands/` automatically resolve these
fixtures from URLs.

**Example**:
```bash
# Mock curl resolves this URL to a fixture file
curl https://api.openstreetmap.org/api/0.6/notes/3394115.json
# -> tests/fixtures/command/extra/3394115.json
```

**Documentation**: See `command/README.md` for detailed information.

### 2. Special Cases (`special_cases/`)

**Purpose**: XML test files for special scenarios that may occur when the API
returns data.

**Location**: `tests/fixtures/special_cases/`

**Contents**:
- `zero_notes.xml` - API returns 0 notes
- `single_note.xml` - API returns only 1 note
- `less_than_threads.xml` - 5 notes (less than available threads)
- `equal_to_cores.xml` - 12 notes (equal to number of cores)
- `many_more_than_cores.xml` - 25 notes (many more than cores)
- `double_close.xml` - Note closed twice consecutively
- `double_reopen.xml` - Note reopened twice consecutively
- `create_and_close.xml` - Note created and closed in same API call
- `close_and_reopen.xml` - Note closed and reopened in same API call
- `open_close_reopen.xml` - Note opened, closed, and reopened
- `open_close_reopen_cycle.xml` - Complete open-close-reopen-close cycle
- `comment_and_close.xml` - Note commented and then closed

**Usage**:
```bash
# Test with zero notes
./bin/process/processAPINotes.sh tests/fixtures/special_cases/zero_notes.xml

# Test with single note
./bin/process/processAPINotes.sh tests/fixtures/special_cases/single_note.xml
```

**Documentation**: See `special_cases/README.md` for detailed descriptions of
each special case.

### 3. XML Test Data (`xml/`)

**Purpose**: XML files for testing XML processing functionality.

**Location**: `tests/fixtures/xml/`

**Contents**:
- `api_notes_sample.xml` - Sample API notes XML
- `large_planet_notes.xml` - Large planet notes for performance testing
- `mockPlanetDump.osn.xml` - Mock planet dump file
- `planet_notes_real.xml` - Real planet notes data
- `planet_notes_sample.xml` - Sample planet notes

**Usage**:
```bash
# Test XML processing
run process_xml_file "${TEST_BASE_DIR}/tests/fixtures/xml/api_notes_sample.xml"
```

### 4. SQL Sample Data (`sample_data.sql`)

**Purpose**: SQL INSERT statements for populating test databases with sample
data.

**Location**: `tests/fixtures/sample_data.sql`

**Contents**:
- Sample notes data
- Sample users data
- Sample note comments data
- Sample note comments text data
- Sample sync tables data

**Usage**:
```bash
# Load sample data into test database
psql -d test_db -f tests/fixtures/sample_data.sql
```

**Structure**:
```sql
-- Sample notes data
INSERT INTO notes (note_id, latitude, longitude, created_at, status, closed_at, id_country) VALUES
(123, 40.7128, -74.0060, '2013-04-28T02:39:27Z', 'open', NULL, 1),
(456, 34.0522, -118.2437, '2013-04-30T15:20:45Z', 'closed', '2013-05-01T10:15:30Z', 1);
```

### 5. Planet Dump Sample (`planet-notes-latest.osn.xml`)

**Purpose**: Sample planet dump file for testing planet processing
functionality.

**Location**: `tests/fixtures/planet-notes-latest.osn.xml`

**Usage**:
```bash
# Test planet processing
./bin/process/processPlanetNotes.sh tests/fixtures/planet-notes-latest.osn.xml
```

## Using Fixtures in Tests

### Loading Fixtures

```bash
@test "Process should handle special case XML" {
  # Load fixture using TEST_BASE_DIR
  local fixture_file="${TEST_BASE_DIR}/tests/fixtures/special_cases/single_note.xml"
  
  run process_xml_file "${fixture_file}"
  
  [[ "${status}" -eq 0 ]]
}
```

### Creating Inline Test Data

For simple test data, create it inline in tests:

```bash
@test "Function should process valid JSON" {
  # Create minimal test JSON
  local json_file="${TEST_DIR}/test.json"
  cat > "${json_file}" << 'EOF'
{
  "type": "Feature",
  "properties": {"name": "Test"}
}
EOF
  
  run process_json "${json_file}"
  [[ "${status}" -eq 0 ]]
}
```

### Using Mock Commands with Fixtures

Mock commands automatically resolve fixtures:

```bash
setup() {
  # Mock curl uses fixtures from command/extra/
  # No additional setup needed
  export MOCK_FIXTURES_DIR="${TEST_BASE_DIR}/tests/fixtures/command/extra"
}

@test "Download should use fixture data" {
  # Mock curl will automatically use fixture file
  run download_note "3394115"
  [[ "${status}" -eq 0 ]]
}
```

## Environment Variables

### MOCK_FIXTURES_DIR

Override the fixtures directory location:

```bash
export MOCK_FIXTURES_DIR="/custom/path/to/fixtures"
```

Default is `../fixtures/command/extra` relative to `tests/mock_commands/`.

## Best Practices

### When to Use Fixtures

1. **Reusable test data**: Use fixtures for data used by multiple tests
2. **Complex data structures**: Use fixtures for complex XML/JSON structures
3. **Real-world scenarios**: Use fixtures that represent real API responses
4. **Special cases**: Use fixtures for edge cases and error scenarios

### When to Create Inline Data

1. **Simple test data**: Create inline for simple, test-specific data
2. **One-time use**: Create inline for data used only once
3. **Dynamic data**: Create inline for data that needs to be modified per test

### Fixture Maintenance

1. **Keep fixtures small**: Use minimal data needed for testing
2. **Keep fixtures deterministic**: Ensure fixtures produce consistent results
3. **Update fixtures when APIs change**: Keep fixtures in sync with real API
   responses
4. **Document fixture purpose**: Add comments explaining what each fixture
   tests
5. **Do not commit generated files**: Use `.gitignore` to exclude temporary
   files

## Adding New Fixtures

### Steps

1. **Determine fixture type**: Choose appropriate directory
2. **Create fixture file**: Use appropriate format (XML, JSON, SQL, etc.)
3. **Add to appropriate directory**: Place in correct subdirectory
4. **Update documentation**: Add entry to this README or subdirectory README
5. **Test fixture usage**: Verify fixture works in tests

### Example: Adding New Special Case

```bash
# 1. Create XML file
cat > tests/fixtures/special_cases/new_case.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<osm>
  <note id="1" lat="0.0" lon="0.0">
    <comment action="opened" uid="1" user="test"/>
  </note>
</osm>
EOF

# 2. Update special_cases/README.md with description

# 3. Create test using fixture
@test "Process should handle new special case" {
  local fixture="${TEST_BASE_DIR}/tests/fixtures/special_cases/new_case.xml"
  run process_xml_file "${fixture}"
  [[ "${status}" -eq 0 ]]
}
```

## Fixture Documentation

- **Command Fixtures**: `command/README.md`
- **Special Cases**: `special_cases/README.md`
- **Mock Commands**: `../mock_commands/README.md`

## Related Documentation

- [Contributing Tests Guide](../CONTRIBUTING_TESTS.md)
- [Testing Guide](../../docs/Testing_Guide.md)
- [Test Suites Reference](../../docs/Testing_Suites_Reference.md)

