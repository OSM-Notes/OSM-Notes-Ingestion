# Mocking Best Practices Guide

**Version:** 2025-12-27  
**Purpose:** Comprehensive guide for implementing effective mocking in OSM-Notes-Ingestion project tests.

---

## Table of Contents

- [Fundamental Principles](#fundamental-principles)
- [When to Use Mocks](#when-to-use-mocks)
- [When NOT to Use Mocks](#when-not-to-use-mocks)
- [Common Helpers vs Inline Mocks](#common-helpers-vs-inline-mocks)
- [Implementation Guide](#implementation-guide)
- [Common Patterns](#common-patterns)
- [Common Errors and How to Avoid Them](#common-errors-and-how-to-avoid-them)
- [Practical Examples](#practical-examples)
- [References](#references)

---

## Fundamental Principles

### 1. Isolation

Tests must be **independent** and **isolated**:

- ✅ Each test must be able to run independently
- ✅ Tests must not depend on execution order
- ✅ Mocks must be reset between tests

### 2. Simplicity

Mocks must be **simple** and **easy to understand**:

- ✅ Simulate behavior, don't replicate full implementation
- ✅ Document expected behavior with comments
- ✅ Avoid complex logic in mocks

### 3. Maintainability

Use **common helpers** instead of inline mocks:

- ✅ Reuse helpers from `test_helpers_common.bash`
- ✅ Avoid duplication of mocking code
- ✅ Centralize changes in a single place

### 4. Clarity

Mocks must make **explicit** what they are simulating:

- ✅ Descriptive names for mock functions
- ✅ Comments explaining simulated behavior
- ✅ Document special cases or edge cases

---

## When to Use Mocks

### ✅ Always Mock: Services Requiring Internet

**Reason:** External services may be unavailable, slow, or rate-limited.

**Services to mock:**
- **OSM Notes API** (`api.openstreetmap.org`)
- **Overpass API** (`overpass-api.de`)
- **OSM Planet Server** (`planet.openstreetmap.org`)

**Example:**
```bash
# Mock curl to avoid real API calls
__setup_mock_curl_for_api "https://api.openstreetmap.org" "200" '{"notes":[]}'
```

### ✅ Mock in Unit Tests: Slow Operations

**Reason:** Unit tests must be fast and not depend on I/O.

**Operations to mock:**
- Database access (in unit tests)
- File operations (when not the focus of the test)
- Calls to complex external commands

**Example:**
```bash
# Mock psql for unit tests
__setup_mock_psql_for_query "SELECT.*FROM notes" "5" 0
```

### ✅ Mock: Internal Functions for Isolation

**Reason:** Test components in isolation without depending on internal implementations.

**Example:**
```bash
# Mock internal function to test specific component
__validate_json_with_element() {
  local file="${1}"
  [[ -f "${file}" ]] && [[ -s "${file}" ]]
}
export -f __validate_json_with_element
```

---

## When NOT to Use Mocks

### ❌ DON'T Mock: Reliable Local Services

**Reason:** Local services are fast, reliable, and provide better coverage.

**Services to use real:**
- **PostgreSQL** (local database `osm_notes_ingestion_test`)
- **System tools** (`xmllint`, `bzip2`, `jq`)

**Example:**
```bash
# Use real PostgreSQL in integration tests
@test "Function should insert into database" {
  __skip_if_no_database "${DBNAME}" "Database not available"
  
  # Use real database
  run function_that_inserts_data
  [[ "${status}" -eq 0 ]]
}
```

### ❌ DON'T Mock: What You're Testing

**Reason:** If you mock what you're testing, you're not testing anything.

**Example:**
```bash
# ❌ BAD: Mock the function you're testing
@test "Function should process data" {
  function_being_tested() {
    echo "mocked result"
  }
  # This doesn't test anything useful
}

# ✅ GOOD: Mock dependencies, not the main function
@test "Function should process data" {
  __setup_mock_curl_for_api "http://api.example.com" "200" '{"data":[]}'
  
  run function_being_tested
  [[ "${status}" -eq 0 ]]
}
```

### ❌ DON'T Mock: Simple System Tools

**Reason:** Tools like `grep`, `awk`, `sed` are fast and reliable.

**Example:**
```bash
# ✅ Use real grep
result=$(grep "pattern" "${file}")

# ❌ DON'T mock grep unnecessarily
```

### ⚠️ Conditional Mocking: Geographic Tools

**Tools:** `osmtogeojson`, `ogr2ogr`, `xmllint`

**Reason:** These tools are local and deterministic, but may not be installed in all test environments.

**Strategy:**
- **Unit tests**: Mock to avoid dependencies and test logic in isolation
- **Integration tests**: Use real tools when available, skip tests if not available
- **Hybrid tests**: Use real tools (they need to work with real database)

**Example - Unit Test (Mock):**
```bash
# Mock osmtogeojson for unit tests
__setup_mock_osmtogeojson "input.json" "output.geojson"
```

**Example - Integration Test (Real):**
```bash
# Check availability and use real tool
if ! command -v osmtogeojson > /dev/null; then
  skip "osmtogeojson not available"
fi

# Use real osmtogeojson
osmtogeojson "${JSON_FILE}" > "${GEOJSON_FILE}"
```

**Example - Hybrid Test (Real with Fallback):**
```bash
# In hybrid mode, mock delegates to real command if available
# See: tests/setup_hybrid_mock_environment.sh
# Mock ogr2ogr checks for real command and delegates if found
```

---

## Common Helpers vs Inline Mocks

### ✅ Prefer: Common Helpers

**Location:** `tests/test_helpers_common.bash`

**Advantages:**
- ✅ Code reuse
- ✅ Consistency across tests
- ✅ Centralized maintenance
- ✅ Fewer errors

**Example:**
```bash
load "${BATS_TEST_DIRNAME}/../../test_helpers_common"

setup() {
  # Use common helper for psql mock
  __setup_mock_psql_for_query "SELECT.*FROM notes" "5" 0
}
```

### ❌ Avoid: Inline Mocks

**Problems:**
- ❌ Code duplication
- ❌ Inconsistencies between implementations
- ❌ Difficult maintenance
- ❌ Less readable tests

**Example:**
```bash
# ❌ BAD: Inline mock duplicated
psql() {
  local ARGS=("$@")
  # ... complex duplicated logic ...
  echo "result"
  return 0
}
export -f psql
```

### Exception: Test-Specific Mocks

**When to use inline mocks:**
- When the mock is specific to a single test
- When the simulated behavior is unique and not reusable
- When the mock is very simple (1-2 lines)

**Example:**
```bash
@test "Function should handle specific error case" {
  # Mock specific to this unique test
  __specific_helper() {
    return 1  # Simulate specific error
  }
  export -f __specific_helper
  
  run function_under_test
  [[ "${status}" -ne 0 ]]
}
```

---

## Implementation Guide

### Step 1: Identify Dependencies

Before writing the test, identify:
1. **What external services** the function uses
2. **What system commands** it executes
3. **What internal functions** it calls

### Step 2: Decide Mocking Strategy

Use this decision table:

| Dependency | Type | Mock? | Helper Available? | Notes |
|------------|------|-------|-------------------|-------|
| OSM API | Internet | ✅ Yes | `__setup_mock_curl_for_api` | Always mock |
| Overpass API | Internet | ✅ Yes | `__setup_mock_curl_overpass` | Always mock |
| PostgreSQL | Local | ❌ No (integration tests) | `__skip_if_no_database` | Use real DB |
| PostgreSQL | Local | ✅ Yes (unit tests) | `__setup_mock_psql_for_query` | Mock for isolation |
| osmtogeojson | Tool | ⚠️ Conditional | `__setup_mock_osmtogeojson` | Mock in unit tests, real in integration |
| ogr2ogr | Tool | ⚠️ Conditional | `__setup_mock_ogr2ogr` | Mock in unit tests, real in hybrid tests |
| xmllint | Tool | ❌ No | - | Always use real (check availability) |

### Step 3: Implement Mocks

**Use common helpers when available:**

```bash
load "${BATS_TEST_DIRNAME}/../../test_helpers_common"

setup() {
  # Mock PostgreSQL for unit tests
  __setup_mock_psql_for_query "SELECT.*FROM notes" "5" 0
  
  # Mock curl for external API
  __setup_mock_curl_for_api "https://api.openstreetmap.org" "200" '{"notes":[]}'
  
  # Mock osmtogeojson
  __setup_mock_osmtogeojson "input.json" "output.geojson"
}
```

**Create inline mocks only when necessary:**

```bash
@test "Function should handle specific case" {
  # Mock specific to this test only
  __specific_function() {
    # Specific simulated behavior
    return 0
  }
  export -f __specific_function
  
  run function_under_test
  [[ "${status}" -eq 0 ]]
}
```

### Step 4: Document Mocks

**Always document:**
- What service/command is being mocked
- Why it's being mocked
- What behavior is being simulated

```bash
# Mock curl to avoid real API calls
# Simulates successful response with empty notes list
# This allows testing logic without depending on external services
__setup_mock_curl_for_api "https://api.openstreetmap.org" "200" '{"notes":[]}'
```

---

## Common Patterns

### Pattern 1: PostgreSQL Mock

**For unit tests:**
```bash
# Mock psql to return specific result
__setup_mock_psql_for_query "SELECT COUNT" "5" 0

# Mock psql to return boolean
__setup_mock_psql_boolean "SELECT EXISTS" "t"

# Mock psql with advanced tracking
__setup_mock_psql_with_tracking \
  "${TRACK_FILE}" \
  "${MATCH_FILE}" \
  "SELECT.*FROM notes:5" \
  "INSERT.*INTO notes:0"
```

**For integration tests:**
```bash
# Check database availability
__skip_if_no_database "${DBNAME}" "Database not available"

# Use real database
run function_that_queries_db
```

### Pattern 2: External API Mock

```bash
# Mock OSM Notes API
__setup_mock_curl_for_api \
  "https://api.openstreetmap.org/api/0.6/notes" \
  "200" \
  '{"notes":[{"id":12345}]}'

# Mock Overpass API
__setup_mock_curl_overpass \
  "query.12345.op" \
  "12345.json" \
  '{"elements":[]}'
```

### Pattern 3: GeoJSON Tools Mock (Unit Tests Only)

**For unit tests** (testing logic without real conversion):
```bash
# Mock osmtogeojson (OSM→GeoJSON conversion)
__setup_mock_osmtogeojson "input.json" "output.geojson"

# Mock ogr2ogr (GeoJSON→PostgreSQL import)
__setup_mock_ogr2ogr "true"  # Simulate success
```

**For integration tests** (testing real functionality):
```bash
# Check availability and use real tool
if ! command -v osmtogeojson > /dev/null; then
  skip "osmtogeojson not available"
fi

# Use real osmtogeojson
osmtogeojson "${JSON_FILE}" > "${GEOJSON_FILE}"

# For ogr2ogr in hybrid tests, mock delegates to real command
# See: tests/setup_hybrid_mock_environment.sh
```

**Note:** These tools are local and deterministic. Mocking is only needed in unit tests where you're testing logic, not the actual conversion/import functionality.

### Pattern 4: Internal Functions Mock

```bash
# Mock validation function
__validate_json_with_element() {
  local file="${1}"
  [[ -f "${file}" ]] && [[ -s "${file}" ]]
}
export -f __validate_json_with_element

# Mock sanitization function
__sanitize_sql_string() {
  echo "${1}" | sed "s/'/''/g"
}
export -f __sanitize_sql_string
```

### Pattern 5: Hybrid Tests

**Mock internet, use real local services:**

```bash
# Mock services requiring internet
__setup_mock_curl_for_api "https://api.openstreetmap.org" "200" '{}'

# Use real local database
__skip_if_no_database "${DBNAME}" "Database not available"

# Run test with hybrid services
run processAPINotes.sh
```

---

## Common Errors and How to Avoid Them

### Error 1: Mocking What You're Testing

**❌ Incorrect:**
```bash
@test "Function should process data" {
  function_being_tested() {
    echo "mocked"
  }
  # This doesn't test anything useful
}
```

**✅ Correct:**
```bash
@test "Function should process data" {
  # Mock dependencies, not the main function
  __setup_mock_curl_for_api "http://api.example.com" "200" '{"data":[]}'
  
  run function_being_tested
  [[ "${status}" -eq 0 ]]
}
```

### Error 2: Duplicating Inline Mocks

**❌ Incorrect:**
```bash
# In each test file...
psql() {
  local ARGS=("$@")
  # ... same duplicated logic ...
}
export -f psql
```

**✅ Correct:**
```bash
load "${BATS_TEST_DIRNAME}/../../test_helpers_common"

setup() {
  __setup_mock_psql_for_query "SELECT.*FROM notes" "5" 0
}
```

### Error 3: Not Checking Service Availability

**❌ Incorrect:**
```bash
@test "Function should query database" {
  # Assumes database is available
  run function_that_queries_db
  [[ "${status}" -eq 0 ]]
}
```

**✅ Correct:**
```bash
@test "Function should query database" {
  # Check availability before using
  __skip_if_no_database "${DBNAME}" "Database not available"
  
  run function_that_queries_db
  [[ "${status}" -eq 0 ]]
}
```

### Error 4: Overly Complex Mocks

**❌ Incorrect:**
```bash
psql() {
  # ... 50 lines of complex logic replicating real psql ...
}
```

**✅ Correct:**
```bash
# Use common helper that handles complexity
__setup_mock_psql_for_query "SELECT.*FROM notes" "5" 0
```

### Error 5: Not Documenting Mock Behavior

**❌ Incorrect:**
```bash
curl() {
  echo "{}"
  return 0
}
```

**✅ Correct:**
```bash
# Mock curl to avoid real API calls
# Simulates successful response with empty JSON
# This allows testing logic without depending on external services
__setup_mock_curl_for_api "https://api.openstreetmap.org" "200" '{}'
```

---

## Practical Examples

### Example 1: Unit Test with Mocks

```bash
#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../test_helpers_common"

setup() {
  # Mock PostgreSQL to avoid real connections
  __setup_mock_psql_for_query "SELECT COUNT" "5" 0
  
  # Mock curl to avoid external API calls
  __setup_mock_curl_for_api \
    "https://api.openstreetmap.org/api/0.6/notes" \
    "200" \
    '{"notes":[{"id":12345}]}'
}

@test "Function should count notes correctly" {
  run function_that_counts_notes
  
  [[ "${status}" -eq 0 ]]
  [[ "${output}" == "5" ]]
}
```

### Example 2: Hybrid Integration Test

```bash
#!/usr/bin/env bats

load "${BATS_TEST_DIRNAME}/../../test_helpers_common"
load "${BATS_TEST_DIRNAME}/../../integration/service_availability_helpers"

setup() {
  # Mock services requiring internet
  __setup_mock_curl_for_api \
    "https://api.openstreetmap.org/api/0.6/notes" \
    "200" \
    '{"notes":[]}'
  
  # Check local database availability
  __skip_if_no_database "${DBNAME}" "Database not available"
}

@test "E2E: Complete workflow with real database" {
  # Use real database for better coverage
  run processAPINotes.sh
  
  [[ "${status}" -eq 0 ]]
  
  # Verify results in real database
  local count
  count=$(psql -d "${DBNAME}" -Atq -c "SELECT COUNT(*) FROM notes_api")
  [[ "${count}" -gt 0 ]]
}
```

### Example 3: Internal Function Mock

```bash
#!/usr/bin/env bats

setup() {
  # Mock validation function to test specific component
  __validate_json_with_element() {
    local file="${1}"
    local element="${2}"
    
    # Simulate successful validation
    [[ -f "${file}" ]] && [[ -s "${file}" ]]
    return 0
  }
  export -f __validate_json_with_element
}

@test "Function should process valid JSON" {
  # Create test JSON
  local json_file="${TMP_DIR}/test.json"
  echo '{"elements":[]}' > "${json_file}"
  
  run function_that_processes_json "${json_file}"
  
  [[ "${status}" -eq 0 ]]
}
```

### Example 4: Test-Specific Mock

```bash
@test "Function should handle network timeout" {
  # Mock specific to this test only
  # Simulates network timeout
  curl() {
    sleep 2
    return 124  # Timeout exit code
  }
  export -f curl
  
  # Function should retry 3 times before failing
  run function_with_retry "http://example.com"
  
  [[ "${status}" -eq 1 ]]
  [[ "${output}" == *"retry"* ]]
}
```

---

## References

### Related Documentation

- **`tests/CONTRIBUTING_TESTS.md`**: Complete guide for contributing tests
- **`tests/TESTING_STRATEGIES.md`**: Project testing strategies
- **`docs/External_Services_Mocking_Analysis.md`**: Detailed mocking analysis

### Available Helpers

- **`tests/test_helpers_common.bash`**: Common mocking helpers
  - `__setup_mock_psql_for_query`: Mock psql for queries
  - `__setup_mock_psql_boolean`: Mock psql for booleans
  - `__setup_mock_psql_count`: Mock psql for counts
  - `__setup_mock_psql_with_tracking`: Advanced psql mock
  - `__setup_mock_curl_for_api`: Mock curl for APIs
  - `__setup_mock_curl_overpass`: Mock curl for Overpass
  - `__setup_mock_osmtogeojson`: Mock osmtogeojson
  - `__setup_mock_ogr2ogr`: Mock ogr2ogr
  - `__check_database_connectivity`: Check database connectivity
  - `__skip_if_no_database`: Skip test if database unavailable

- **`tests/integration/service_availability_helpers.bash`**: Availability helpers
  - `__check_postgresql_available`: Check PostgreSQL
  - `__check_osm_api_available`: Check OSM API
  - `__check_overpass_api_available`: Check Overpass API
  - `__skip_if_postgresql_unavailable`: Skip if PostgreSQL unavailable

### Code Examples

- **Unit tests with mocks**: `tests/unit/bash/note_processing_retry.test.bats`
- **Hybrid tests**: `tests/run_processAPINotes_hybrid.sh`
- **Integration tests**: `tests/integration/api_complete_e2e.test.bats`

---

## Conclusion

Following these best practices ensures:

- ✅ **Fast tests**: Without dependencies on slow services
- ✅ **Reliable tests**: Don't depend on external availability
- ✅ **Maintainable tests**: Reusable and consistent code
- ✅ **Clear tests**: Easy to understand and modify

**Remember:** The goal of mocking is to **facilitate testing**, not complicate it. When in doubt, ask: "Does this mock make the test simpler and clearer?"

---

**Last updated:** 2025-12-27
