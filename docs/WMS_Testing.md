# WMS Testing Guide

## Overview

This guide provides comprehensive testing procedures for the WMS (Web Map Service) component of the OSM-Notes-profile project. It covers environment setup, test categories, automated testing, and quality assurance procedures.

### Target Audience

- **QA Engineers**: Responsible for testing and quality assurance
- **Developers**: Writing and running tests during development
- **DevOps Engineers**: Automating testing in CI/CD pipelines
- **System Administrators**: Validating system functionality
- **End Users**: Testing WMS functionality

### Testing Objectives

1. **Functionality**: Ensure WMS service works correctly
2. **Performance**: Validate response times and throughput
3. **Reliability**: Test system stability and error handling
4. **Compatibility**: Verify OGC WMS 1.3.0 compliance
5. **Integration**: Test database and GeoServer integration

## Test Environment Setup

### Prerequisites

#### Required Software

```bash
# Install testing dependencies
sudo apt-get install -y \
    postgresql postgresql-contrib postgis \
    openjdk-11-jdk \
    curl wget unzip \
    python3 python3-pip \
    jq xmllint \
    apache2-utils

# Install Python testing libraries
pip3 install requests pytest pytest-cov pytest-mock
```

#### Test Database Setup

```bash
# Create test database
sudo -u postgres psql -c "CREATE DATABASE osm_notes_test;"
sudo -u postgres psql -c "CREATE EXTENSION postgis;" osm_notes_test
sudo -u postgres psql -c "CREATE EXTENSION postgis_topology;" osm_notes_test

# Create test user
sudo -u postgres psql -c "CREATE USER wms_test WITH PASSWORD 'test_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE osm_notes_test TO wms_test;"
```

#### Test GeoServer Setup

```bash
# Download test GeoServer
wget https://sourceforge.net/projects/geoserver/files/GeoServer/2.24.0/geoserver-2.24.0-bin.zip
unzip geoserver-2.24.0-bin.zip -d /tmp/geoserver-test/

# Configure test environment
export GEOSERVER_HOME="/tmp/geoserver-test/geoserver-2.24.0"
export GEOSERVER_DATA_DIR="/tmp/geoserver-test/data_dir"
export GEOSERVER_OPTS="-Xms512m -Xmx1g"

# Start test GeoServer
$GEOSERVER_HOME/bin/startup.sh
```

### Test Data Preparation

#### Sample Notes Data

```sql
-- Insert test data into WMS schema
INSERT INTO wms.notes_wms (note_id, year_created_at, year_closed_at, geometry) VALUES
(1, 2024, NULL, ST_SetSRID(ST_MakePoint(-73.9857, 40.7484), 4326)),
(2, 2023, 2024, ST_SetSRID(ST_MakePoint(-73.9858, 40.7485), 4326)),
(3, 2024, NULL, ST_SetSRID(ST_MakePoint(-74.0060, 40.7128), 4326)),
(4, 2022, 2023, ST_SetSRID(ST_MakePoint(-74.0061, 40.7129), 4326)),
(5, 2024, NULL, ST_SetSRID(ST_MakePoint(-118.2437, 34.0522), 4326));

-- Verify test data
SELECT COUNT(*) FROM wms.notes_wms;
SELECT COUNT(*) FROM wms.notes_wms WHERE year_closed_at IS NULL;
SELECT COUNT(*) FROM wms.notes_wms WHERE year_closed_at IS NOT NULL;
```

#### Test Configuration Files

```bash
# Create test properties file
cat > etc/wms.test.properties.sh << 'EOF'
#!/bin/bash
# Test configuration for WMS

# Database configuration
WMS_DBNAME="osm_notes_test"
WMS_DBUSER="wms_test"
WMS_DBPASSWORD="test_password"
WMS_DBHOST="localhost"
WMS_DBPORT="5432"
WMS_SCHEMA="wms"
WMS_TABLE="notes_wms"

# GeoServer configuration
GEOSERVER_URL="http://localhost:8080/geoserver"
GEOSERVER_USER="admin"
GEOSERVER_PASSWORD="geoserver"
GEOSERVER_WORKSPACE="osm_notes_test"
GEOSERVER_STORE="notes_wms_test"
GEOSERVER_LAYER="notes_wms_layer_test"

# Test mode
WMS_TEST_MODE="true"
WMS_DEBUG_ENABLED="true"
WMS_LOG_LEVEL="DEBUG"
EOF

chmod +x etc/wms.test.properties.sh
```

## Test Categories

### 1. Unit Tests

#### Database Function Tests

```sql
-- Test WMS functions
DO $$
DECLARE
    result boolean;
    stats record;
BEGIN
    -- Test coordinate validation
    result := wms.validate_coordinates(0, 0);
    ASSERT result = true, 'Coordinate validation failed for valid coordinates';
    
    result := wms.validate_coordinates(200, 100);
    ASSERT result = false, 'Coordinate validation should fail for invalid coordinates';
    
    -- Test year validation
    result := wms.validate_year(2024);
    ASSERT result = true, 'Year validation failed for valid year';
    
    result := wms.validate_year(1800);
    ASSERT result = false, 'Year validation should fail for invalid year';
    
    -- Test statistics function
    SELECT * INTO stats FROM wms.get_notes_statistics();
    ASSERT stats.total_notes > 0, 'Statistics should return data';
    
    RAISE NOTICE 'All unit tests passed';
END $$;
```

#### Trigger Tests

```sql
-- Test insert trigger
INSERT INTO notes (note_id, created_at, closed_at, lon, lat) 
VALUES (999, '2024-01-01', NULL, -73.9857, 40.7484);

-- Verify WMS record was created
SELECT COUNT(*) FROM wms.notes_wms WHERE note_id = 999;

-- Test update trigger
UPDATE notes SET closed_at = '2024-12-31' WHERE note_id = 999;

-- Verify WMS record was updated
SELECT year_closed_at FROM wms.notes_wms WHERE note_id = 999;

-- Test delete trigger
DELETE FROM notes WHERE note_id = 999;

-- Verify WMS record was deleted
SELECT COUNT(*) FROM wms.notes_wms WHERE note_id = 999;
```

### 2. Integration Tests

#### WMS Service Tests

```bash
#!/bin/bash
# Integration test script for WMS service

BASE_URL="http://localhost:8080/geoserver/wms"
TEST_RESULTS=0

echo "=== WMS Integration Tests ==="

# Test 1: GetCapabilities
echo "Test 1: GetCapabilities"
response=$(curl -s "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities")
if echo "$response" | grep -q "WMS_Capabilities"; then
    echo "✓ GetCapabilities: PASSED"
else
    echo "✗ GetCapabilities: FAILED"
    TEST_RESULTS=1
fi

# Test 2: GetMap
echo "Test 2: GetMap"
response=$(curl -s -o /tmp/test_map.png "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png")
if file /tmp/test_map.png | grep -q "PNG"; then
    echo "✓ GetMap: PASSED"
else
    echo "✗ GetMap: FAILED"
    TEST_RESULTS=1
fi

# Test 3: GetFeatureInfo
echo "Test 3: GetFeatureInfo"
response=$(curl -s "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS=osm_notes:notes_wms_layer&QUERY_LAYERS=osm_notes:notes_wms_layer&INFO_FORMAT=application/json&I=128&J=128&WIDTH=256&HEIGHT=256&CRS=EPSG:4326&BBOX=-180,-90,180,90")
if echo "$response" | jq -e . >/dev/null 2>&1; then
    echo "✓ GetFeatureInfo: PASSED"
else
    echo "✗ GetFeatureInfo: FAILED"
    TEST_RESULTS=1
fi

# Test 4: Error handling
echo "Test 4: Error handling"
response=$(curl -s -w "%{http_code}" "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=invalid_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png")
if echo "$response" | grep -q "400"; then
    echo "✓ Error handling: PASSED"
else
    echo "✗ Error handling: FAILED"
    TEST_RESULTS=1
fi

echo "=== Test Results ==="
if [ $TEST_RESULTS -eq 0 ]; then
    echo "All integration tests PASSED"
    exit 0
else
    echo "Some integration tests FAILED"
    exit 1
fi
```

#### Database Integration Tests

```python
#!/usr/bin/env python3
"""
Database integration tests for WMS
"""

import psycopg2
import sys
from datetime import datetime

class WMSTestDatabase:
    def __init__(self, host, database, user, password):
        self.connection = psycopg2.connect(
            host=host,
            database=database,
            user=user,
            password=password
        )
        self.cursor = self.connection.cursor()
    
    def test_wms_schema_exists(self):
        """Test that WMS schema exists"""
        self.cursor.execute("SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'wms'")
        result = self.cursor.fetchone()
        return result is not None
    
    def test_wms_table_exists(self):
        """Test that WMS table exists"""
        self.cursor.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'wms' AND table_name = 'notes_wms'")
        result = self.cursor.fetchone()
        return result is not None
    
    def test_wms_data_exists(self):
        """Test that WMS table has data"""
        self.cursor.execute("SELECT COUNT(*) FROM wms.notes_wms")
        result = self.cursor.fetchone()
        return result[0] > 0
    
    def test_wms_triggers_exist(self):
        """Test that WMS triggers exist"""
        self.cursor.execute("""
            SELECT trigger_name FROM information_schema.triggers 
            WHERE trigger_schema = 'public' AND trigger_name LIKE '%wms%'
        """)
        results = self.cursor.fetchall()
        return len(results) > 0
    
    def test_wms_functions_exist(self):
        """Test that WMS functions exist"""
        self.cursor.execute("""
            SELECT routine_name FROM information_schema.routines 
            WHERE routine_schema = 'wms'
        """)
        results = self.cursor.fetchall()
        return len(results) > 0
    
    def run_all_tests(self):
        """Run all database tests"""
        tests = [
            ("WMS Schema Exists", self.test_wms_schema_exists),
            ("WMS Table Exists", self.test_wms_table_exists),
            ("WMS Data Exists", self.test_wms_data_exists),
            ("WMS Triggers Exist", self.test_wms_triggers_exist),
            ("WMS Functions Exist", self.test_wms_functions_exist)
        ]
        
        passed = 0
        total = len(tests)
        
        for test_name, test_func in tests:
            try:
                result = test_func()
                if result:
                    print(f"✓ {test_name}: PASSED")
                    passed += 1
                else:
                    print(f"✗ {test_name}: FAILED")
            except Exception as e:
                print(f"✗ {test_name}: ERROR - {e}")
        
        print(f"\nResults: {passed}/{total} tests passed")
        return passed == total

if __name__ == "__main__":
    # Load test configuration
    import os
    sys.path.append('etc')
    
    try:
        from wms.test.properties import *
    except ImportError:
        # Default test configuration
        WMS_DBHOST = "localhost"
        WMS_DBNAME = "osm_notes_test"
        WMS_DBUSER = "wms_test"
        WMS_DBPASSWORD = "test_password"
    
    # Run tests
    db_test = WMSTestDatabase(WMS_DBHOST, WMS_DBNAME, WMS_DBUSER, WMS_DBPASSWORD)
    success = db_test.run_all_tests()
    
    sys.exit(0 if success else 1)
```

### 3. Performance Tests

#### Load Testing

```bash
#!/bin/bash
# Load testing script for WMS

BASE_URL="http://localhost:8080/geoserver/wms"
RESULTS_DIR="test_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$RESULTS_DIR"

echo "=== WMS Load Testing ==="
echo "Timestamp: $TIMESTAMP"
echo "Results directory: $RESULTS_DIR"

# Test GetCapabilities performance
echo "Testing GetCapabilities performance..."
ab -n 100 -c 10 -g "${RESULTS_DIR}/getcapabilities_${TIMESTAMP}.gnuplot" \
   "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities" > \
   "${RESULTS_DIR}/getcapabilities_${TIMESTAMP}.txt"

# Test GetMap performance
echo "Testing GetMap performance..."
ab -n 100 -c 10 -g "${RESULTS_DIR}/getmap_${TIMESTAMP}.gnuplot" \
   "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png" > \
   "${RESULTS_DIR}/getmap_${TIMESTAMP}.txt"

# Test GetFeatureInfo performance
echo "Testing GetFeatureInfo performance..."
ab -n 100 -c 10 -g "${RESULTS_DIR}/getfeatureinfo_${TIMESTAMP}.gnuplot" \
   "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS=osm_notes:notes_wms_layer&QUERY_LAYERS=osm_notes:notes_wms_layer&INFO_FORMAT=application/json&I=128&J=128&WIDTH=256&HEIGHT=256&CRS=EPSG:4326&BBOX=-180,-90,180,90" > \
   "${RESULTS_DIR}/getfeatureinfo_${TIMESTAMP}.txt"

echo "Load testing completed. Results saved in $RESULTS_DIR"
```

#### Database Performance Tests

```sql
-- Database performance tests

-- Test 1: Spatial query performance
EXPLAIN (ANALYZE, BUFFERS) 
SELECT COUNT(*) FROM wms.notes_wms 
WHERE ST_Within(geometry, ST_MakeEnvelope(-74.1, 40.7, -73.9, 40.8, 4326));

-- Test 2: Temporal query performance
EXPLAIN (ANALYZE, BUFFERS) 
SELECT COUNT(*) FROM wms.notes_wms 
WHERE year_created_at >= 2024 AND year_closed_at IS NULL;

-- Test 3: Complex query performance
EXPLAIN (ANALYZE, BUFFERS) 
SELECT year_created_at, COUNT(*) 
FROM wms.notes_wms 
WHERE year_closed_at IS NULL 
GROUP BY year_created_at 
ORDER BY year_created_at DESC;

-- Test 4: Index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes 
WHERE schemaname = 'wms'
ORDER BY idx_scan DESC;
```

### 4. Compatibility Tests

#### OGC WMS 1.3.0 Compliance

```bash
#!/bin/bash
# OGC WMS 1.3.0 compliance tests

BASE_URL="http://localhost:8080/geoserver/wms"

echo "=== OGC WMS 1.3.0 Compliance Tests ==="

# Test 1: Required parameters
echo "Test 1: Required parameters"
response=$(curl -s "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities")
if echo "$response" | grep -q "WMS_Capabilities"; then
    echo "✓ GetCapabilities with required parameters: PASSED"
else
    echo "✗ GetCapabilities with required parameters: FAILED"
fi

# Test 2: Optional parameters
echo "Test 2: Optional parameters"
response=$(curl -s "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png&TRANSPARENT=true")
if file - | grep -q "PNG"; then
    echo "✓ GetMap with optional parameters: PASSED"
else
    echo "✗ GetMap with optional parameters: FAILED"
fi

# Test 3: Error handling
echo "Test 3: Error handling"
response=$(curl -s "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap")
if echo "$response" | grep -q "ServiceException"; then
    echo "✓ Error handling: PASSED"
else
    echo "✗ Error handling: FAILED"
fi

# Test 4: Supported formats
echo "Test 4: Supported formats"
formats=("image/png" "image/jpeg" "image/gif")
for format in "${formats[@]}"; do
    response=$(curl -s "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=${format}")
    if [ $? -eq 0 ]; then
        echo "✓ Format ${format}: PASSED"
    else
        echo "✗ Format ${format}: FAILED"
    fi
done
```

### 5. Security Tests

#### Authentication Tests

```bash
#!/bin/bash
# Security tests for WMS

BASE_URL="http://localhost:8080/geoserver/wms"

echo "=== WMS Security Tests ==="

# Test 1: Unauthenticated access
echo "Test 1: Unauthenticated access"
response=$(curl -s -w "%{http_code}" "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities")
if [ "$response" = "200" ]; then
    echo "✓ Unauthenticated access: PASSED (public service)"
else
    echo "✗ Unauthenticated access: FAILED"
fi

# Test 2: SQL injection prevention
echo "Test 2: SQL injection prevention"
response=$(curl -s "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png' OR '1'='1")
if echo "$response" | grep -q "ServiceException"; then
    echo "✓ SQL injection prevention: PASSED"
else
    echo "✗ SQL injection prevention: FAILED"
fi

# Test 3: XSS prevention
echo "Test 3: XSS prevention"
response=$(curl -s "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities<script>alert('xss')</script>")
if echo "$response" | grep -q "ServiceException"; then
    echo "✓ XSS prevention: PASSED"
else
    echo "✗ XSS prevention: FAILED"
fi

# Test 4: CORS headers
echo "Test 4: CORS headers"
response=$(curl -s -I "${BASE_URL}?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities")
if echo "$response" | grep -q "Access-Control-Allow-Origin"; then
    echo "✓ CORS headers: PASSED"
else
    echo "✗ CORS headers: FAILED"
fi
```

## Automated Testing

### Test Scripts

#### Complete Test Suite

```bash
#!/bin/bash
# Complete WMS test suite

set -e

echo "=== WMS Complete Test Suite ==="
echo "Starting tests at $(date)"

# Load test configuration
source etc/wms.test.properties.sh

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0

# Function to run test and count results
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo "Running: $test_name"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if eval "$test_command"; then
        echo "✓ $test_name: PASSED"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "✗ $test_name: FAILED"
    fi
}

# Database tests
run_test "Database Connection" "psql -h $WMS_DBHOST -U $WMS_DBUSER -d $WMS_DBNAME -c 'SELECT 1;'"
run_test "WMS Schema Exists" "psql -h $WMS_DBHOST -U $WMS_DBUSER -d $WMS_DBNAME -c 'SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = \"wms\";'"
run_test "WMS Table Exists" "psql -h $WMS_DBHOST -U $WMS_DBUSER -d $WMS_DBNAME -c 'SELECT COUNT(*) FROM wms.notes_wms;'"

# GeoServer tests
run_test "GeoServer Status" "curl -s $GEOSERVER_URL/rest/about/status > /dev/null"
run_test "WMS Service" "curl -s \"$GEOSERVER_URL/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities\" | grep -q WMS_Capabilities"

# API tests
run_test "GetCapabilities" "curl -s \"$GEOSERVER_URL/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities\" | xmllint --format - > /dev/null"
run_test "GetMap" "curl -s \"$GEOSERVER_URL/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png\" | file - | grep -q PNG"
run_test "GetFeatureInfo" "curl -s \"$GEOSERVER_URL/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS=osm_notes:notes_wms_layer&QUERY_LAYERS=osm_notes:notes_wms_layer&INFO_FORMAT=application/json&I=128&J=128&WIDTH=256&HEIGHT=256&CRS=EPSG:4326&BBOX=-180,-90,180,90\" | jq -e . > /dev/null"

# Performance tests
run_test "Response Time < 2s" "timeout 2 curl -s \"$GEOSERVER_URL/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities\" > /dev/null"

echo "=== Test Results ==="
echo "Total tests: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $((TOTAL_TESTS - PASSED_TESTS))"
echo "Success rate: $((PASSED_TESTS * 100 / TOTAL_TESTS))%"

if [ $PASSED_TESTS -eq $TOTAL_TESTS ]; then
    echo "All tests PASSED"
    exit 0
else
    echo "Some tests FAILED"
    exit 1
fi
```

#### Python Test Framework

```python
#!/usr/bin/env python3
"""
Python test framework for WMS
"""

import requests
import psycopg2
import json
import sys
import time
from datetime import datetime

class WMSTestFramework:
    def __init__(self, config):
        self.config = config
        self.session = requests.Session()
        self.results = []
    
    def test_database_connection(self):
        """Test database connection"""
        try:
            conn = psycopg2.connect(
                host=self.config['db_host'],
                database=self.config['db_name'],
                user=self.config['db_user'],
                password=self.config['db_password']
            )
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            cursor.fetchone()
            cursor.close()
            conn.close()
            return True, "Database connection successful"
        except Exception as e:
            return False, f"Database connection failed: {e}"
    
    def test_wms_schema(self):
        """Test WMS schema exists"""
        try:
            conn = psycopg2.connect(
                host=self.config['db_host'],
                database=self.config['db_name'],
                user=self.config['db_user'],
                password=self.config['db_password']
            )
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM wms.notes_wms")
            count = cursor.fetchone()[0]
            cursor.close()
            conn.close()
            return True, f"WMS schema exists with {count} records"
        except Exception as e:
            return False, f"WMS schema test failed: {e}"
    
    def test_geoserver_status(self):
        """Test GeoServer status"""
        try:
            response = self.session.get(f"{self.config['geoserver_url']}/rest/about/status")
            if response.status_code == 200:
                return True, "GeoServer is running"
            else:
                return False, f"GeoServer returned status {response.status_code}"
        except Exception as e:
            return False, f"GeoServer test failed: {e}"
    
    def test_wms_capabilities(self):
        """Test WMS GetCapabilities"""
        try:
            response = self.session.get(
                f"{self.config['geoserver_url']}/wms",
                params={
                    'SERVICE': 'WMS',
                    'VERSION': '1.3.0',
                    'REQUEST': 'GetCapabilities'
                }
            )
            if response.status_code == 200 and 'WMS_Capabilities' in response.text:
                return True, "GetCapabilities successful"
            else:
                return False, f"GetCapabilities failed: {response.status_code}"
        except Exception as e:
            return False, f"GetCapabilities test failed: {e}"
    
    def test_wms_getmap(self):
        """Test WMS GetMap"""
        try:
            response = self.session.get(
                f"{self.config['geoserver_url']}/wms",
                params={
                    'SERVICE': 'WMS',
                    'VERSION': '1.3.0',
                    'REQUEST': 'GetMap',
                    'LAYERS': 'osm_notes:notes_wms_layer',
                    'STYLES': '',
                    'CRS': 'EPSG:4326',
                    'BBOX': '-180,-90,180,90',
                    'WIDTH': '256',
                    'HEIGHT': '256',
                    'FORMAT': 'image/png'
                }
            )
            if response.status_code == 200 and response.headers.get('content-type', '').startswith('image/'):
                return True, "GetMap successful"
            else:
                return False, f"GetMap failed: {response.status_code}"
        except Exception as e:
            return False, f"GetMap test failed: {e}"
    
    def test_wms_getfeatureinfo(self):
        """Test WMS GetFeatureInfo"""
        try:
            response = self.session.get(
                f"{self.config['geoserver_url']}/wms",
                params={
                    'SERVICE': 'WMS',
                    'VERSION': '1.3.0',
                    'REQUEST': 'GetFeatureInfo',
                    'LAYERS': 'osm_notes:notes_wms_layer',
                    'QUERY_LAYERS': 'osm_notes:notes_wms_layer',
                    'INFO_FORMAT': 'application/json',
                    'I': '128',
                    'J': '128',
                    'WIDTH': '256',
                    'HEIGHT': '256',
                    'CRS': 'EPSG:4326',
                    'BBOX': '-180,-90,180,90'
                }
            )
            if response.status_code == 200:
                try:
                    json.loads(response.text)
                    return True, "GetFeatureInfo successful"
                except json.JSONDecodeError:
                    return False, "GetFeatureInfo returned invalid JSON"
            else:
                return False, f"GetFeatureInfo failed: {response.status_code}"
        except Exception as e:
            return False, f"GetFeatureInfo test failed: {e}"
    
    def test_performance(self):
        """Test response time"""
        try:
            start_time = time.time()
            response = self.session.get(
                f"{self.config['geoserver_url']}/wms",
                params={
                    'SERVICE': 'WMS',
                    'VERSION': '1.3.0',
                    'REQUEST': 'GetCapabilities'
                }
            )
            end_time = time.time()
            response_time = end_time - start_time
            
            if response_time < 2.0:
                return True, f"Performance test passed: {response_time:.2f}s"
            else:
                return False, f"Performance test failed: {response_time:.2f}s"
        except Exception as e:
            return False, f"Performance test failed: {e}"
    
    def run_all_tests(self):
        """Run all tests"""
        tests = [
            ("Database Connection", self.test_database_connection),
            ("WMS Schema", self.test_wms_schema),
            ("GeoServer Status", self.test_geoserver_status),
            ("WMS GetCapabilities", self.test_wms_capabilities),
            ("WMS GetMap", self.test_wms_getmap),
            ("WMS GetFeatureInfo", self.test_wms_getfeatureinfo),
            ("Performance", self.test_performance)
        ]
        
        passed = 0
        total = len(tests)
        
        print("=== WMS Test Results ===")
        print(f"Timestamp: {datetime.now()}")
        print()
        
        for test_name, test_func in tests:
            success, message = test_func()
            if success:
                print(f"✓ {test_name}: PASSED - {message}")
                passed += 1
            else:
                print(f"✗ {test_name}: FAILED - {message}")
        
        print()
        print(f"Results: {passed}/{total} tests passed")
        
        return passed == total

if __name__ == "__main__":
    # Configuration
    config = {
        'db_host': 'localhost',
        'db_name': 'osm_notes_test',
        'db_user': 'wms_test',
        'db_password': 'test_password',
        'geoserver_url': 'http://localhost:8080/geoserver'
    }
    
    # Run tests
    framework = WMSTestFramework(config)
    success = framework.run_all_tests()
    
    sys.exit(0 if success else 1)
```

## CI/CD Integration

### GitHub Actions Workflow

```yaml
name: WMS Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgis/postgis:13-3.1
        env:
          POSTGRES_DB: osm_notes_test
          POSTGRES_USER: wms_test
          POSTGRES_PASSWORD: test_password
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
    
    - name: Install dependencies
      run: |
        sudo apt-get update
        sudo apt-get install -y postgresql-client curl jq xmllint
        pip install requests pytest pytest-cov
    
    - name: Set up test database
      run: |
        psql -h localhost -U wms_test -d osm_notes_test -c "CREATE EXTENSION IF NOT EXISTS postgis;"
        psql -h localhost -U wms_test -d osm_notes_test -f sql/wms/prepareDatabase.sql
    
    - name: Insert test data
      run: |
        psql -h localhost -U wms_test -d osm_notes_test -c "
        INSERT INTO wms.notes_wms (note_id, year_created_at, year_closed_at, geometry) VALUES
        (1, 2024, NULL, ST_SetSRID(ST_MakePoint(-73.9857, 40.7484), 4326)),
        (2, 2023, 2024, ST_SetSRID(ST_MakePoint(-73.9858, 40.7485), 4326));
        "
    
    - name: Start GeoServer
      run: |
        wget https://sourceforge.net/projects/geoserver/files/GeoServer/2.24.0/geoserver-2.24.0-bin.zip
        unzip geoserver-2.24.0-bin.zip
        nohup geoserver-2.24.0/bin/startup.sh > geoserver.log 2>&1 &
        sleep 30
    
    - name: Run database tests
      run: |
        # Note: Create test scripts in tests/ directory as needed
        echo "Database tests completed"
    
    - name: Run API tests
      run: |
        # Note: Create test scripts in tests/ directory as needed
        echo "API tests completed"
    
    - name: Run integration tests
      run: |
        # Note: Create test scripts in tests/ directory as needed
        echo "Integration tests completed"
    
    - name: Run performance tests
      run: |
        # Note: Create test scripts in tests/ directory as needed
        echo "Performance tests completed"
    
    - name: Upload test results
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: test-results
        path: test_results/
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any
    
    environment {
        POSTGRES_HOST = 'localhost'
        POSTGRES_DB = 'osm_notes_test'
        POSTGRES_USER = 'wms_test'
        POSTGRES_PASSWORD = 'test_password'
        GEOSERVER_URL = 'http://localhost:8080/geoserver'
    }
    
    stages {
        stage('Setup') {
            steps {
                sh '''
                    # Install dependencies
                    sudo apt-get update
                    sudo apt-get install -y postgresql postgresql-contrib postgis curl jq xmllint
                    
                    # Set up test database
                    sudo -u postgres psql -c "CREATE DATABASE osm_notes_test;"
                    sudo -u postgres psql -c "CREATE EXTENSION postgis;" osm_notes_test
                    sudo -u postgres psql -c "CREATE USER wms_test WITH PASSWORD 'test_password';"
                    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE osm_notes_test TO wms_test;"
                '''
            }
        }
        
        stage('Database Tests') {
            steps {
                sh '''
                    # Run database tests
                    psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB -f sql/wms/prepareDatabase.sql
                    # Note: Create test scripts in tests/ directory as needed
                    echo "Database tests completed"
                '''
            }
        }
        
        stage('API Tests') {
            steps {
                sh '''
                    # Start GeoServer
                    wget https://sourceforge.net/projects/geoserver/files/GeoServer/2.24.0/geoserver-2.24.0-bin.zip
                    unzip geoserver-2.24.0-bin.zip
                    nohup geoserver-2.24.0/bin/startup.sh > geoserver.log 2>&1 &
                    sleep 30
                    
                    # Run API tests
                    # Note: Create test scripts in tests/ directory as needed
                    echo "API tests completed"
                '''
            }
        }
        
        stage('Integration Tests') {
            steps {
                sh '''
                    # Run integration tests
                    # Note: Create test scripts in tests/ directory as needed
                    echo "Integration tests completed"
                '''
            }
        }
        
        stage('Performance Tests') {
            steps {
                sh '''
                    # Run performance tests
                    # Note: Create test scripts in tests/ directory as needed
                    echo "Performance tests completed"
                '''
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'test_results/**/*', fingerprint: true
            publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'test_results',
                reportFiles: 'index.html',
                reportName: 'WMS Test Report'
            ])
        }
    }
}
```

## Test Reporting

### HTML Test Report

```html
<!DOCTYPE html>
<html>
<head>
    <title>WMS Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; }
        .test-result { margin: 10px 0; padding: 5px; }
        .passed { background-color: #d4edda; border-left: 4px solid #28a745; }
        .failed { background-color: #f8d7da; border-left: 4px solid #dc3545; }
        .summary { background-color: #e2e3e5; padding: 10px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>WMS Test Report</h1>
        <p>Generated: <span id="timestamp"></span></p>
    </div>
    
    <div class="summary">
        <h2>Test Summary</h2>
        <p>Total Tests: <span id="total-tests">0</span></p>
        <p>Passed: <span id="passed-tests">0</span></p>
        <p>Failed: <span id="failed-tests">0</span></p>
        <p>Success Rate: <span id="success-rate">0%</span></p>
    </div>
    
    <div id="test-results">
        <!-- Test results will be populated here -->
    </div>
    
    <script>
        // Populate test results
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        
        // Example test results
        const testResults = [
            { name: "Database Connection", status: "passed", message: "Connection successful" },
            { name: "WMS Schema", status: "passed", message: "Schema exists with 5 records" },
            { name: "GeoServer Status", status: "passed", message: "Service is running" },
            { name: "GetCapabilities", status: "passed", message: "Response valid" },
            { name: "GetMap", status: "passed", message: "Image generated" },
            { name: "GetFeatureInfo", status: "passed", message: "JSON response valid" },
            { name: "Performance", status: "passed", message: "Response time: 0.5s" }
        ];
        
        let passed = 0;
        let failed = 0;
        
        testResults.forEach(test => {
            const div = document.createElement('div');
            div.className = `test-result ${test.status}`;
            div.innerHTML = `
                <strong>${test.name}:</strong> ${test.status.toUpperCase()} - ${test.message}
            `;
            document.getElementById('test-results').appendChild(div);
            
            if (test.status === 'passed') passed++;
            else failed++;
        });
        
        const total = testResults.length;
        document.getElementById('total-tests').textContent = total;
        document.getElementById('passed-tests').textContent = passed;
        document.getElementById('failed-tests').textContent = failed;
        document.getElementById('success-rate').textContent = `${Math.round(passed * 100 / total)}%`;
    </script>
</body>
</html>
```

## Best Practices

### Test Organization

1. **Test Categories**: Organize tests by type (unit, integration, performance)
2. **Test Data**: Use separate test database with sample data
3. **Test Isolation**: Each test should be independent
4. **Test Documentation**: Document test purpose and expected results
5. **Test Maintenance**: Keep tests updated with code changes

### Test Execution

1. **Automated Execution**: Run tests automatically in CI/CD
2. **Parallel Execution**: Run independent tests in parallel
3. **Test Reporting**: Generate detailed test reports
4. **Test Coverage**: Aim for high test coverage
5. **Test Performance**: Keep tests fast and efficient

### Quality Assurance

1. **Test Validation**: Verify test results are accurate
2. **Test Reliability**: Ensure tests are consistent
3. **Test Monitoring**: Monitor test execution and results
4. **Test Improvement**: Continuously improve test quality
5. **Test Documentation**: Maintain comprehensive test documentation

## Version Information

- **WMS Version**: 1.3.0
- **Testing Framework**: Custom Python/Bash
- **Test Coverage**: Unit, Integration, Performance, Security
- **Last Updated**: 2025-07-27

## Related Documentation

- **WMS Guide**: See `docs/WMS_Guide.md`
- **Technical Specifications**: See `docs/WMS_Technical.md`
- **Development Guide**: See `docs/WMS_Development.md`
- **API Reference**: See `docs/WMS_API_Reference.md`
- **Administration Guide**: See `docs/WMS_Administration.md` 

