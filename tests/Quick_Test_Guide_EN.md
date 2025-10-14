# Quick Test Execution Guide

**Version:** 2025-10-14

## 🚀 Quick Commands

### Quick Verification (15-20 min)

```bash
cd /home/angoca/github/OSM-Notes-Ingestion
./tests/run_tests_sequential.sh quick
```

### Basic Tests - Levels 1-3 (20-35 min)

```bash
./tests/run_tests_sequential.sh basic
```

### Standard Tests - Levels 1-6 (45-75 min)

```bash
./tests/run_tests_sequential.sh standard
```

### Complete Suite - All levels (90-135 min)

```bash
./tests/run_tests_sequential.sh full
```

---

## 📋 Execute Specific Level

### Level 1 - Basic Tests (5-10 min)

```bash
./tests/run_tests_sequential.sh level 1
```

### Level 2 - Validation (10-15 min)

```bash
./tests/run_tests_sequential.sh level 2
```

### Level 3 - XML/XSLT (8-12 min)

```bash
./tests/run_tests_sequential.sh level 3
```

### Level 4 - Processing (15-25 min)

```bash
./tests/run_tests_sequential.sh level 4
```

### Level 5 - Parallel Processing (10-15 min)

```bash
./tests/run_tests_sequential.sh level 5
```

### Level 6 - Cleanup and Error Handling (12-18 min)

```bash
./tests/run_tests_sequential.sh level 6
```

### Level 7 - Monitoring and WMS (8-12 min)

```bash
./tests/run_tests_sequential.sh level 7
```

### Level 8 - Advanced Tests (10-15 min)

```bash
./tests/run_tests_sequential.sh level 8
```

### Level 9 - End-to-End Integration (10-20 min)

```bash
./tests/run_tests_sequential.sh level 9
```

---

## 🎯 Tests by Functional Category

### ProcessAPI

```bash
bats tests/unit/bash/processAPINotes*.bats \
     tests/unit/bash/api_download_verification.test.bats \
     tests/unit/bash/historical_data_validation.test.bats
```

### ProcessPlanet

```bash
bats tests/unit/bash/processPlanetNotes*.bats \
     tests/unit/bash/mock_planet_functions.test.bats
```

### XML/XSLT

```bash
bats tests/unit/bash/xml*.bats tests/unit/bash/xslt*.bats
```

### Parallel Processing

```bash
bats tests/parallel_processing_test_suite.bats \
     tests/unit/bash/parallel*.bats
```

### Validation

```bash
bats tests/unit/bash/*validation*.bats
```

### Cleanup

```bash
bats tests/unit/bash/cleanup*.bats tests/unit/bash/clean*.bats
```

### WMS

```bash
bats tests/unit/bash/wms*.bats \
     tests/integration/wms_integration.test.bats
```

### Error Handling

```bash
bats tests/unit/bash/error_handling*.bats
```

---

## 🔍 Execute Individual Suite

### Specific suite

```bash
bats tests/unit/bash/processAPINotes.test.bats
```

### Suite with verbose output

```bash
bats -t tests/unit/bash/processAPINotes.test.bats
```

### Specific test within a suite

```bash
bats tests/unit/bash/processAPINotes.test.bats -f "test_name"
```

---

## 📊 Recommendations by Situation

### Before Commit

```bash
# Option 1: Quick check (15-20 min)
./tests/run_tests_sequential.sh quick

# Option 2: Basic (20-35 min)
./tests/run_tests_sequential.sh basic
```

### Before Push

```bash
# Standard (45-75 min)
./tests/run_tests_sequential.sh standard
```

### Before Merge/PR

```bash
# Full (90-135 min)
./tests/run_tests_sequential.sh full
```

### During Feature Development

```bash
# Execute only the level related to your feature
./tests/run_tests_sequential.sh level N

# Or specific category
bats tests/unit/bash/[category]*.bats
```

### Debugging Failures

```bash
# Re-execute specific suite with verbose
bats -t tests/unit/bash/failing_suite.test.bats

# View only specific test
bats tests/unit/bash/suite.test.bats -f "specific_test"
```

---

## 🔧 Troubleshooting

### PostgreSQL not available

```bash
# Check status
sudo systemctl status postgresql

# Start if stopped
sudo systemctl start postgresql

# Verify connection
psql -U notes -d notes -c "SELECT 1;"
```

### BATS not found

```bash
# Install BATS
sudo apt-get update
sudo apt-get install bats
```

### Tests too slow

```bash
# Use mock mode (without database)
cd tests
source setup_mock_environment.sh
bats unit/bash/*.bats
```

### View error details

```bash
# Execute with TAP format for more details
bats -t tests/unit/bash/suite.test.bats

# Or redirect to a file
bats tests/unit/bash/suite.test.bats 2>&1 | tee test_output.log
```

---

## 📈 Level Structure

| Level | Description | Tests | Time |
|-------|-------------|-------|------|
| 1 | Basic (logging, format) | ~50-60 | 5-10 min |
| 2 | Validation (data, coordinates, dates) | ~100-120 | 10-15 min |
| 3 | XML/XSLT | ~80-100 | 8-12 min |
| 4 | Processing (API, Planet) | ~120-150 | 15-25 min |
| 5 | Parallel Processing | ~80-100 | 10-15 min |
| 6 | Cleanup and Error Handling | ~100-120 | 12-18 min |
| 7 | Monitoring and WMS | ~50-70 | 8-12 min |
| 8 | Advanced and Edge Cases | ~100-130 | 10-15 min |
| 9 | E2E Integration | ~68 | 10-20 min |

---

## 💡 Tips

1. **For active development:** Use `quick` or specific level for your feature
2. **For local CI/CD:** Use `standard` or `full`
3. **For debugging:** Execute specific suite with `-t` for verbose
4. **For time saving:** Use mock mode when you don't need database
5. **For progress:** Sequential script shows banners with progress

---

## 📚 More Information

- **Complete matrix:** See `docs/Test_Matrix.md`
- **Detailed sequence:** See `docs/Test_Execution_Sequence.md`
- **Testing guide:** See `docs/Testing_Guide.md`

---

**Last update:** 2025-10-14  
**Maintainer:** Andres Gomez (AngocA)

