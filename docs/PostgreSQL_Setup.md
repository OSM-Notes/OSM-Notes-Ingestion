# PostgreSQL Setup Guide

This guide helps you configure PostgreSQL for the OSM-Notes-Ingestion
project.

## Quick Start

If you're getting authentication errors, follow these steps:

### Step 1: Create the Database

```bash
createdb notes
```

### Step 2: Create PostgreSQL User

```bash
# Create user with password (recommended)
sudo -u postgres createuser -d -P myuser

# Or create user without password (for development only)
sudo -u postgres createuser -d myuser
```

### Step 3: Grant Permissions

```bash
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"notes\" TO myuser;"
```

### Step 4: Install Extensions

```bash
psql -U myuser -d notes -c 'CREATE EXTENSION postgis;'
psql -U myuser -d notes -c 'CREATE EXTENSION btree_gist;'
```

### Step 5: Configure Authentication

Edit PostgreSQL authentication configuration:

```bash
sudo nano /etc/postgresql/*/main/pg_hba.conf
```

Add or modify these lines (before the default "peer" lines):

```conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD
local   notes           myuser                                  md5
local   all             myuser                                  md5
```

Reload PostgreSQL:

```bash
sudo systemctl reload postgresql
```

### Step 6: Test Connection

```bash
psql -U myuser -d notes -c "SELECT 1;"
```

If this works, you're ready to go!

---

## Common Issues and Solutions

### Issue 1: "FATAL: Peer authentication failed"

**Problem**: PostgreSQL is using "peer" authentication which requires the
system username to match the database username.

**Solution**: Change authentication method to "md5" in `pg_hba.conf` (see
Step 5 above).

### Issue 2: "User does not exist"

**Problem**: The PostgreSQL user hasn't been created.

**Solution**: Run Step 2 above.

### Issue 3: "Database does not exist"

**Problem**: The database hasn't been created.

**Solution**: Run Step 1 above.

### Issue 4: "Permission denied"

**Problem**: User doesn't have permissions on the database.

**Solution**: Run Step 3 above.

### Issue 5: "PostGIS extension is missing"

**Problem**: PostGIS extension is not installed or not enabled.

**Solution**:

```bash
# Install PostGIS (if not installed)
sudo apt-get install postgresql-postgis

# Enable in database
   psql -U myuser -d notes -c 'CREATE EXTENSION postgis;'
```

---

## Alternative: Use Current System User

If you don't want to configure a separate PostgreSQL user, you can use your
current system user:

1. Create PostgreSQL user matching your system username:

   ```bash
   sudo -u postgres createuser -d $(whoami)
   ```

2. Create and configure `etc/properties.sh` from the example file:

   ```bash
   # Copy the example file
   cp etc/properties.sh.example etc/properties.sh
   
   # Edit with your settings
   vi etc/properties.sh
   
   # Or set environment variable to override:
   export DB_USER=$(whoami)
   ```

3. Create database and extensions:

   ```bash
   createdb notes
   psql -d notes -c 'CREATE EXTENSION postgis;'
   psql -d notes -c 'CREATE EXTENSION btree_gist;'
   ```

---

## Verification Script

Run this script to verify your setup:

```bash
#!/bin/bash

DBNAME="notes"
DB_USER="myuser"

echo "=== PostgreSQL Setup Verification ==="
echo

# Check PostgreSQL
if psql --version > /dev/null 2>&1; then
    echo "✅ PostgreSQL is installed"
else
    echo "❌ PostgreSQL is NOT installed"
    exit 1
fi

# Check database exists
if psql -lqt | cut -d \| -f 1 | grep -qw "${DBNAME}"; then
    echo "✅ Database '${DBNAME}' exists"
else
    echo "❌ Database '${DBNAME}' does NOT exist"
    echo "   Run: createdb ${DBNAME}"
    exit 1
fi

# Check user can connect
if psql -U "${DB_USER}" -d "${DBNAME}" -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✅ User '${DB_USER}' can connect to database"
else
    echo "❌ User '${DB_USER}' CANNOT connect to database"
    echo "   Check authentication configuration"
    exit 1
fi

# Check PostGIS
if psql -U "${DB_USER}" -d "${DBNAME}" -c "SELECT PostGIS_version();" > /dev/null 2>&1; then
    echo "✅ PostGIS extension is installed"
else
    echo "❌ PostGIS extension is NOT installed"
    echo "   Run: psql -U ${DB_USER} -d ${DBNAME} -c 'CREATE EXTENSION postgis;'"
    exit 1
fi

# Check btree_gist
RESULT=$(psql -U "${DB_USER}" -t -A -c "SELECT COUNT(1) FROM pg_extension WHERE extname = 'btree_gist';" "${DBNAME}" 2>/dev/null)
if [[ "${RESULT}" -eq 1 ]]; then
    echo "✅ btree_gist extension is installed"
else
    echo "❌ btree_gist extension is NOT installed"
    echo "   Run: psql -U ${DB_USER} -d ${DBNAME} -c 'CREATE EXTENSION btree_gist;'"
    exit 1
fi

echo
echo "✅ All checks passed! Your PostgreSQL setup is ready."
```

---

## Configuration Files

### `etc/properties.sh`

The database configuration is defined in `etc/properties.sh`. **Important**: This
file is not tracked in Git for security reasons. You must create it from the
example file:

```bash
# Copy the example file
cp etc/properties.sh.example etc/properties.sh

# Edit with your database credentials
vi etc/properties.sh
```

The configuration file defines:

```bash
# Database name (default: notes)
DBNAME="${DBNAME:-notes}"

# Database user (default: myuser)
DB_USER="${DB_USER:-myuser}"
```

You can override these values using environment variables:

```bash
export DBNAME="my-custom-db"
export DB_USER="my-custom-user"
```

---

## Security Considerations

1. **Production**: Always use password authentication (md5 or scram-sha-256)
2. **Development**: You can use "trust" for local development, but this is
   not secure
3. **Network Access**: If accessing from another machine, use appropriate
   host-based authentication
4. **Strong Passwords**: Use strong passwords for database users

---

## Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [PostGIS Documentation](https://postgis.net/documentation/)
- [PostgreSQL Authentication Methods](https://www.postgresql.org/docs/current/auth-methods.html)

## Related Documentation

- **[Documentation.md](./Documentation.md)**: System architecture and database schema
- **[sql/README.md](../sql/README.md)**: SQL scripts and database functions documentation
- **[Troubleshooting_Guide.md](./Troubleshooting_Guide.md)**: Database troubleshooting and common issues
- **[Process_Planet.md](./Process_Planet.md)**: Initial database setup with `--base` mode
For **WMS database setup and configuration**, see the
[OSM-Notes-WMS](https://github.com/OSMLatam/OSM-Notes-WMS) repository.

---
