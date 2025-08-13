#!/bin/bash

# Test connection script for Docker environment
# Author: Andres Gomez (AngocA)
# Version: 2025-07-28

set -euo pipefail

echo "=== Testing PostgreSQL Connection in Docker ==="

# Check environment variables
echo "Environment variables:"
echo "TEST_DBHOST: ${TEST_DBHOST:-not set}"
echo "TEST_DBPORT: ${TEST_DBPORT:-not set}"
echo "TEST_DBUSER: ${TEST_DBUSER:-not set}"
echo "TEST_DBNAME: ${TEST_DBNAME:-not set}"
echo "PGPASSWORD: ${PGPASSWORD:-not set}"

# Test pg_isready
echo ""
echo "Testing pg_isready..."
if pg_isready -h "${TEST_DBHOST}" -p "${TEST_DBPORT}" -U "${TEST_DBUSER}"; then
 echo "✅ pg_isready successful"
else
 echo "❌ pg_isready failed"
 exit 1
fi

# Test psql connection
echo ""
echo "Testing psql connection..."
if PGPASSWORD="${PGPASSWORD}" psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -c "SELECT 1 as test;" 2> /dev/null; then
 echo "✅ psql connection successful"
else
 echo "❌ psql connection failed"
 exit 1
fi

echo ""
echo "✅ All connection tests passed!"
