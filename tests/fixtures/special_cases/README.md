# Special Test Cases for Unit Testing

This directory contains XML test files for special cases that may occur when the API returns data.
These cases are designed to test the robustness of the note processing system.

## Test Cases

### 1. Zero Notes (`zero_notes.xml`)

- **Description**: API returns 0 notes
- **Purpose**: Test handling of empty cases
- **Scenario**: `<osm></osm>` without `<note>` elements

### 2. Single Note (`single_note.xml`)

- **Description**: API returns only 1 note
- **Purpose**: Test processing of a single note
- **Scenario**: One note with two comments (creation and closure)

### 3. Less Notes than Threads (`less_than_threads.xml`)

- **Description**: 5 notes (less than 7 available threads)
- **Purpose**: Test when there is less work than available threads
- **Scenario**: 5 notes to test idle thread management

### 4. Equal to Cores (`equal_to_cores.xml`)

- **Description**: 12 notes (equal to the number of cores)
- **Purpose**: Ensure all parallel threads are activated
- **Scenario**: 12 notes to maximize CPU usage

### 5. Many More than Cores (`many_more_than_cores.xml`)

- **Description**: 25 notes (many more than 7 cores)
- **Purpose**: Test batch processing and memory management
- **Scenario**: 25 notes to test massive processing

### 6. Double Close (`double_close.xml`)

- **Description**: Note closed twice consecutively
- **Purpose**: Test API error handling
- **Scenario**: Error that sometimes occurs in the OSM API

### 7. Double Reopen (`double_reopen.xml`)

- **Description**: Note reopened twice consecutively
- **Purpose**: Test API error handling
- **Scenario**: Error that sometimes occurs in the OSM API

### 8. Create and Close (`create_and_close.xml`)

- **Description**: Note created and closed in the same API call
- **Purpose**: Test processing of simultaneous events
- **Scenario**: Same timestamp for creation and closure

### 9. Close and Reopen (`close_and_reopen.xml`)

- **Description**: Note closed and reopened in the same API call
- **Purpose**: Test processing of simultaneous events
- **Scenario**: Same timestamp for closure and reopening

### 10. Open-Close-Reopen (`open_close_reopen.xml`)

- **Description**: Note opened, closed, and reopened in the same call
- **Purpose**: Test processing of complex sequences
- **Scenario**: Complete cycle in a single API call

### 11. Complete Cycle (`open_close_reopen_cycle.xml`)

- **Description**: Note with complete open-close-reopen-close cycle
- **Purpose**: Test processing of complex cycles
- **Scenario**: Multiple state changes in one call

### 12. Comment and Close (`comment_and_close.xml`)

- **Description**: Note commented and then closed
- **Purpose**: Test processing of comments before closure
- **Scenario**: Multiple comments followed by closure

## Usage in Tests

### Running Tests with Special Cases

```bash
# Test with zero notes
./bin/process/processAPINotes.sh tests/fixtures/special_cases/zero_notes.xml

# Test with single note
./bin/process/processAPINotes.sh tests/fixtures/special_cases/single_note.xml

# Test with less notes than threads
./bin/process/processAPINotes.sh tests/fixtures/special_cases/less_than_threads.xml

# Test with equal to cores
./bin/process/processAPINotes.sh tests/fixtures/special_cases/equal_to_cores.xml

# Test with many more than cores
./bin/process/processAPINotes.sh tests/fixtures/special_cases/many_more_than_cores.xml
```

### API Error Cases

```bash
# Test double close
./bin/process/processAPINotes.sh tests/fixtures/special_cases/double_close.xml

# Test double reopen
./bin/process/processAPINotes.sh tests/fixtures/special_cases/double_reopen.xml

# Test create and close
./bin/process/processAPINotes.sh tests/fixtures/special_cases/create_and_close.xml

# Test close and reopen
./bin/process/processAPINotes.sh tests/fixtures/special_cases/close_and_reopen.xml

# Test open-close-reopen
./bin/process/processAPINotes.sh tests/fixtures/special_cases/open_close_reopen.xml

# Test complete cycle
./bin/process/processAPINotes.sh tests/fixtures/special_cases/open_close_reopen_cycle.xml

# Test comment and close
./bin/process/processAPINotes.sh tests/fixtures/special_cases/comment_and_close.xml
```

## Result Validation

### Expected Results

1. **Zero Notes**: Should not generate errors, should process correctly
2. **Single Note**: Should process the note correctly
3. **Less than Threads**: Should use only necessary threads
4. **Equal to Cores**: Should use all available threads
5. **Many More**: Should process in batches efficiently
6. **API Errors**: Should handle errors gracefully

### Verifications

- [ ] Processing without errors
- [ ] Correct use of parallel threads
- [ ] API error handling
- [ ] Comment processing
- [ ] Note state management
- [ ] Acceptable performance

## Technical Notes

- All XML files follow the standard OSM format
- Timestamps are coordinated to simulate real API calls
- Note and comment IDs are unique to avoid conflicts
- Coordinates are in Madrid, Spain for consistency
- Users are fictional for testing purposes

## CI/CD Integration

These special cases can be integrated into the CI/CD pipeline:

```yaml
# Example for GitHub Actions
- name: Test Special Cases
  run: |
    for file in tests/fixtures/special_cases/*.xml; do
      echo "Testing: $file"
      ./bin/process/processAPINotes.sh "$file"
    done
```

## Maintenance

- Add new special cases as needed
- Update this README when adding new cases
- Verify that all cases work with code changes
- Maintain consistency in XML format
