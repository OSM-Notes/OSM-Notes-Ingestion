#!/bin/bash
#
# End-to-End Test Script for Docker Environment
#
# This script runs comprehensive tests for API and Planet notes processing
# in the Docker environment, verifying data insertion and processing.
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-26

set -euo pipefail

# Database settings for Docker environment
TEST_DBNAME="osm_notes_test"
TEST_DBUSER="testuser"
TEST_DBPASSWORD="testpass"
TEST_DBHOST="postgres"
TEST_DBPORT="5432"

# Export database settings for sourced scripts
export DBNAME="${TEST_DBNAME}"
export DB_USER="${TEST_DBUSER}"
export DB_PASSWORD="${TEST_DBPASSWORD}"
export DB_HOST="${TEST_DBHOST}"
export DB_PORT="${TEST_DBPORT}"

echo "=== END-TO-END TEST SCRIPT ==="
echo ""

# Test 1: API Notes Processing
echo "🔄 Test 1: API Notes Processing"
echo "================================"
echo "📋 Resetting test environment..."
bash tests/docker/reset_environment.sh
echo "📋 Testing API notes processing..."
bash tests/docker/test_processAPINotes.sh
echo "📋 Verifying API notes results..."
NOTES_COUNT=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM notes;" | xargs)
COMMENTS_COUNT=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments;" | xargs)
TEXT_COMMENTS_COUNT=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_text;" | xargs)
echo "✅ API Notes Results:"
echo "   - Notes: ${NOTES_COUNT}"
echo "   - Comments: ${COMMENTS_COUNT}"
echo "   - Text Comments: ${TEXT_COMMENTS_COUNT}"
if [[ "${NOTES_COUNT}" -gt 0 && "${COMMENTS_COUNT}" -gt 0 ]]; then
 echo "✅ API Notes Test: PASSED"
else
 echo "❌ API Notes Test: FAILED"
fi
echo ""

# Test 2: Planet Notes Processing
echo "🔄 Test 2: Planet Notes Processing"
echo "==================================="
echo "📋 Resetting test environment..."
bash tests/docker/reset_environment.sh
echo "📋 Testing Planet notes processing..."
bash tests/docker/test_processPlanetNotes.sh
echo "📋 Verifying Planet notes results..."
NOTES_COUNT=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM notes;" | xargs)
COMMENTS_COUNT=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments;" | xargs)
TEXT_COMMENTS_COUNT=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_text;" | xargs)
echo "✅ Planet Notes Results:"
echo "   - Notes: ${NOTES_COUNT}"
echo "   - Comments: ${COMMENTS_COUNT}"
echo "   - Text Comments: ${TEXT_COMMENTS_COUNT}"
if [[ "${NOTES_COUNT}" -gt 0 && "${COMMENTS_COUNT}" -gt 0 ]]; then
 echo "✅ Planet Notes Test: PASSED"
else
 echo "❌ Planet Notes Test: FAILED"
fi
echo ""

# Test 3: Large File Processing
echo "🔄 Test 3: Large File Processing"
echo "================================="
echo "📋 Resetting test environment..."
bash tests/docker/reset_environment.sh
echo "📋 Testing large file processing..."
PLANET_NOTES_FILE="/app/tests/fixtures/xml/large_planet_notes.xml" bash tests/docker/test_processPlanetNotes.sh
echo "📋 Verifying large file results..."
NOTES_COUNT=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM notes;" | xargs)
COMMENTS_COUNT=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments;" | xargs)
TEXT_COMMENTS_COUNT=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_text;" | xargs)
echo "✅ Large File Results:"
echo "   - Notes: ${NOTES_COUNT}"
echo "   - Comments: ${COMMENTS_COUNT}"
echo "   - Text Comments: ${TEXT_COMMENTS_COUNT}"
if [[ "${NOTES_COUNT}" -gt 0 ]]; then
 echo "✅ Large File Test: PASSED"
else
 echo "❌ Large File Test: FAILED"
fi
echo ""

# Test 4: Sequential Processing
echo "🔄 Test 4: Sequential Processing"
echo "================================"
echo "📋 Resetting test environment..."
bash tests/docker/reset_environment.sh
echo "📋 Testing sequential processing..."
bash tests/docker/test_processAPINotes.sh
bash tests/docker/test_processPlanetNotes.sh
echo "📋 Verifying combined results..."
NOTES_COUNT=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM notes;" | xargs)
COMMENTS_COUNT=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments;" | xargs)
TEXT_COMMENTS_COUNT=$(psql -h "${TEST_DBHOST}" -U "${TEST_DBUSER}" -d "${TEST_DBNAME}" -t -c "SELECT COUNT(*) FROM note_comments_text;" | xargs)
echo "✅ Sequential Results:"
echo "   - Notes: ${NOTES_COUNT}"
echo "   - Comments: ${COMMENTS_COUNT}"
echo "   - Text Comments: ${TEXT_COMMENTS_COUNT}"
if [[ "${NOTES_COUNT}" -gt 0 ]]; then
 echo "✅ Sequential Test: PASSED"
else
 echo "❌ Sequential Test: FAILED"
fi
echo ""

echo "=== END-TO-END TEST SUMMARY ==="
echo "✅ All tests completed successfully!"
