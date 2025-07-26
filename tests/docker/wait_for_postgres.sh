#!/bin/bash
#
# Wait for PostgreSQL to be ready before running tests
#
# Author: Andres Gomez (AngocA)
# Version: 2025-07-26

set -e

# Load test properties only
if [[ -f "/app/tests/properties.sh" ]]; then
 source "/app/tests/properties.sh"
elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/../properties.sh" ]]; then
 source "$(dirname "${BASH_SOURCE[0]}")/../properties.sh"
fi

# Default values using test properties only
DB_HOST="${DB_HOST:-${TEST_DBHOST:-postgres}}"
DB_PORT="${DB_PORT:-${TEST_DBPORT:-5432}}"
DB_USER="${DB_USER:-${TEST_DBUSER:-testuser}}"
DB_NAME="${DB_NAME:-${TEST_DBNAME:-osm_notes_test}}"
MAX_RETRIES="${MAX_RETRIES:-30}"
RETRY_INTERVAL="${RETRY_INTERVAL:-2}"

echo "🔍 Waiting for PostgreSQL to be ready..."
echo "   Host: ${DB_HOST}"
echo "   Port: ${DB_PORT}"
echo "   User: ${DB_USER}"
echo "   Database: ${DB_NAME}"
echo "   Max retries: ${MAX_RETRIES}"
echo "   Retry interval: ${RETRY_INTERVAL}s"
echo ""

# Wait for PostgreSQL to be ready
for i in $(seq 1 "${MAX_RETRIES}"); do
 echo "⏳ Attempt ${i}/${MAX_RETRIES}: Checking PostgreSQL connection..."

 if pg_isready -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" > /dev/null 2>&1; then
  echo "✅ PostgreSQL is ready!"
  echo "   Connection successful to ${DB_HOST}:${DB_PORT}/${DB_NAME}"
  exit 0
 else
  echo "❌ PostgreSQL not ready yet (attempt ${i}/${MAX_RETRIES})"
  if [[ "${i}" -lt "${MAX_RETRIES}" ]]; then
   echo "   Waiting ${RETRY_INTERVAL} seconds before next attempt..."
   sleep "${RETRY_INTERVAL}"
  fi
 fi
done

echo "❌ ERROR: PostgreSQL failed to start within ${MAX_RETRIES} attempts"
echo "   Please check the PostgreSQL container logs:"
echo "   docker logs osm_notes_postgres"
exit 1
