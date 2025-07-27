#!/bin/bash
# Script to clean database state before running tests
# Version: 2025-07-27

set -euo pipefail

# Database configuration
export DBNAME="osm_notes_test"
export DB_USER="testuser"
export DB_PASSWORD="testpass"
export DB_HOST="postgres"
export DB_PORT="5432"

echo "🧹 Cleaning database state..."

# Drop and recreate database
echo "📋 Dropping and recreating database..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "DROP DATABASE IF EXISTS ${DBNAME};" 2> /dev/null || true
psql -h "${DB_HOST}" -U "${DB_USER}" -d postgres -c "CREATE DATABASE ${DBNAME};" 2> /dev/null || true

echo "✅ Database cleaned successfully"
