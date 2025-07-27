#!/bin/bash
# Script to check actual table structure
# Version: 2025-07-27

set -euo pipefail

# Database configuration
export DBNAME="osm_notes_test"
export DB_USER="testuser"
export DB_PASSWORD="testpass"
export DB_HOST="postgres"
export DB_PORT="5432"

echo "=== Checking Table Structure ==="
echo "Database: ${DBNAME}"
echo "User: ${DB_USER}"
echo "Host: ${DB_HOST}:${DB_PORT}"
echo ""

# Check table structure
echo "📋 Checking table structure..."
psql -h "${DB_HOST}" -U "${DB_USER}" -d "${DBNAME}" << 'EOF'
-- Check notes table structure
SELECT 'Notes table structure:' as table_name;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'notes' 
ORDER BY ordinal_position;

-- Check note_comments table structure
SELECT 'Note_comments table structure:' as table_name;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'note_comments' 
ORDER BY ordinal_position;

-- Check note_comments_text table structure
SELECT 'Note_comments_text table structure:' as table_name;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'note_comments_text' 
ORDER BY ordinal_position;

-- Check users table structure
SELECT 'Users table structure:' as table_name;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'users' 
ORDER BY ordinal_position;

-- Check properties table structure
SELECT 'Properties table structure:' as table_name;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'properties' 
ORDER BY ordinal_position;
EOF

echo "✅ Table structure check completed" 