# WMS Administration Guide

## Overview

This guide provides comprehensive administration procedures for the WMS (Web Map Service)
component of the OSM-Notes-profile project. It covers installation, configuration,
monitoring, maintenance, and troubleshooting for system administrators.

### Target Audience

- **System Administrators**: Responsible for server infrastructure
- **DevOps Engineers**: Managing deployment and automation
- **Database Administrators**: Handling PostgreSQL and PostGIS
- **Application Administrators**: Managing GeoServer and WMS services

### Prerequisites

Before administering the WMS system, ensure you have:

- **Linux/Unix system** (Ubuntu 20.04+, CentOS 8+, or similar)
- **Root or sudo access** for system-level operations
- **Basic knowledge** of PostgreSQL, GeoServer, and shell scripting
- **Network access** to install packages and download software

## Installation

### System Requirements

#### Minimum Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **CPU** | 2 cores | 4+ cores |
| **RAM** | 4GB | 8GB+ |
| **Storage** | 20GB | 50GB+ |
| **Network** | 10 Mbps | 100 Mbps+ |

#### Software Requirements

| Software | Version | Purpose |
|----------|---------|---------|
| **PostgreSQL** | 12+ | Database server |
| **PostGIS** | 3.0+ | Spatial extensions |
| **Java** | 11+ | GeoServer runtime |
| **GeoServer** | 2.24+ | WMS service |
| **Bash** | 4.0+ | Scripting environment |

### Installation Steps

#### Step 1: System Preparation

```bash
# Update system packages
sudo apt-get update && sudo apt-get upgrade -y

# Install required packages
sudo apt-get install -y \
    postgresql postgresql-contrib postgis \
    openjdk-11-jdk \
    curl wget unzip \
    git

# Verify installations
java -version
psql --version
```

#### Step 2: PostgreSQL Configuration

```bash
# Configure PostgreSQL for WMS
sudo -u postgres psql -c "CREATE DATABASE osm_notes;"
sudo -u postgres psql -c "CREATE EXTENSION postgis;" osm_notes
sudo -u postgres psql -c "CREATE EXTENSION postgis_topology;" osm_notes

# Create WMS user (optional)
sudo -u postgres psql -c "CREATE USER wms_user WITH PASSWORD 'secure_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE osm_notes TO wms_user;"
```

#### Step 3: GeoServer Installation

```bash
# Download GeoServer
wget https://sourceforge.net/projects/geoserver/files/GeoServer/2.24.0/geoserver-2.24.0-bin.zip

# Extract to /opt
sudo unzip geoserver-2.24.0-bin.zip -d /opt/
sudo ln -s /opt/geoserver-2.24.0 /opt/geoserver

# Create GeoServer user
sudo useradd -r -m -d /opt/geoserver geoserver
sudo chown -R geoserver:geoserver /opt/geoserver

# Configure GeoServer service
sudo tee /etc/systemd/system/geoserver.service > /dev/null <<EOF
[Unit]
Description=GeoServer
After=network.target

[Service]
Type=forking
User=geoserver
ExecStart=/opt/geoserver/bin/startup.sh
ExecStop=/opt/geoserver/bin/shutdown.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start GeoServer
sudo systemctl daemon-reload
sudo systemctl enable geoserver
sudo systemctl start geoserver
```

#### Step 4: OSM-Notes-profile Setup

```bash
# Clone the repository
git clone https://github.com/your-org/OSM-Notes-profile.git
cd OSM-Notes-profile

# Configure properties
cp etc/properties.sh.example etc/properties.sh
cp etc/wms.properties.sh.example etc/wms.properties.sh

# Edit configuration files
nano etc/properties.sh
nano etc/wms.properties.sh
```

#### Step 5: WMS Installation

```bash
# Install WMS components
./bin/wms/wmsManager.sh install

# Configure GeoServer
./bin/wms/geoserverConfig.sh install

# Verify installation
./bin/wms/wmsManager.sh status
./bin/wms/geoserverConfig.sh status
```

### Automated Installation

For automated deployment, use the provided scripts:

```bash
# Complete automated installation
./bin/wms/wmsManager.sh install --auto
./bin/wms/geoserverConfig.sh install --auto

# Or use the combined script
# Note: Use wmsManager.sh and geoserverConfig.sh instead
./bin/wms/wmsManager.sh install && ./bin/wms/geoserverConfig.sh install
```

## Configuration Management

### WMS Properties Configuration

The WMS system uses a centralized configuration file: `etc/wms.properties.sh`

#### Key Configuration Sections

1. **Database Configuration**

   ```bash
   # Database connection
   WMS_DBNAME="osm_notes"
   WMS_DBUSER="postgres"
   WMS_DBPASSWORD=""
   WMS_DBHOST="localhost"
   WMS_DBPORT="5432"
   WMS_SCHEMA="wms"
   WMS_TABLE="notes_wms"
   ```

2. **GeoServer Configuration**

   ```bash
   # GeoServer settings
   GEOSERVER_URL="http://localhost:8080/geoserver"
   GEOSERVER_USER="admin"
   GEOSERVER_PASSWORD="geoserver"
   GEOSERVER_WORKSPACE="osm_notes"
   GEOSERVER_STORE="notes_wms"
   GEOSERVER_LAYER="notes_wms_layer"
   ```

3. **Service Configuration**

   ```bash
   # WMS service settings
   WMS_SERVICE_TITLE="OSM Notes WMS Service"
   WMS_SERVICE_DESCRIPTION="OpenStreetMap Notes for WMS service"
   WMS_LAYER_TITLE="OSM Notes WMS Layer"
   WMS_LAYER_SRS="EPSG:4326"
   ```

#### Environment-Specific Configurations

**Development Environment**

```bash
export WMS_DEV_MODE="true"
export WMS_DEBUG_ENABLED="true"
export WMS_LOG_LEVEL="DEBUG"
export WMS_DBNAME="osm_notes_dev"
```

**Production Environment**

```bash
export WMS_DEV_MODE="false"
export WMS_DEBUG_ENABLED="false"
export WMS_LOG_LEVEL="INFO"
export WMS_CACHE_ENABLED="true"
export WMS_CACHE_TTL="3600"
```

**Testing Environment**

```bash
export WMS_DBNAME="osm_notes_test"
export WMS_TEST_MODE="true"
export WMS_LOG_LEVEL="DEBUG"
```

### GeoServer Configuration

#### Memory Configuration

```bash
# Configure GeoServer memory
export GEOSERVER_OPTS="-Xms2g -Xmx4g -XX:+UseG1GC"

# For production systems
export GEOSERVER_OPTS="-Xms4g -Xmx8g -XX:+UseG1GC -XX:+UseStringDeduplication"
```

#### Security Configuration

```bash
# Enable authentication
export WMS_AUTH_ENABLED="true"
export WMS_AUTH_USER="wms_user"
export WMS_AUTH_PASSWORD="secure_password"

# Configure CORS
export WMS_CORS_ENABLED="true"
export WMS_CORS_ALLOW_ORIGIN="https://yourdomain.com"
```

### Database Configuration

#### PostgreSQL Optimization

```sql
-- Configure PostgreSQL for WMS
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET work_mem = '4MB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;

-- Reload configuration
SELECT pg_reload_conf();
```

#### WMS Schema Optimization

```sql
-- Create indexes for performance
CREATE INDEX CONCURRENTLY notes_wms_geometry_gist
ON wms.notes_wms USING GIST (geometry);

CREATE INDEX CONCURRENTLY notes_wms_temporal
ON wms.notes_wms (year_created_at, year_closed_at);

-- Update statistics
ANALYZE wms.notes_wms;
```

## Monitoring and Maintenance

### System Monitoring

#### Health Check Script

Create a monitoring script: `/usr/local/bin/wms-health-check.sh`

```bash
#!/bin/bash
# WMS Health Check Script

LOG_FILE="/var/log/wms-health-check.log"
ALERT_EMAIL="admin@yourdomain.com"

# Check database connection
check_database() {
    psql -h localhost -U postgres -d osm_notes -c \
      "SELECT COUNT(*) FROM wms.notes_wms;" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "$(date): Database connection OK" >> $LOG_FILE
        return 0
    else
        echo "$(date): Database connection FAILED" >> $LOG_FILE
        return 1
    fi
}

# Check GeoServer status
check_geoserver() {
    curl -s "http://localhost:8080/geoserver/rest/about/status" >/dev/null
    if [ $? -eq 0 ]; then
        echo "$(date): GeoServer status OK" >> $LOG_FILE
        return 0
    else
        echo "$(date): GeoServer status FAILED" >> $LOG_FILE
        return 1
    fi
}

# Check WMS service
check_wms_service() {
    curl -s "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities" \
      >/dev/null
    if [ $? -eq 0 ]; then
        echo "$(date): WMS service OK" >> $LOG_FILE
        return 0
    else
        echo "$(date): WMS service FAILED" >> $LOG_FILE
        return 1
    fi
}

# Main health check
main() {
    local failed=0
    
    check_database || failed=1
    check_geoserver || failed=1
    check_wms_service || failed=1
    
    if [ $failed -eq 1 ]; then
        echo "$(date): WMS health check FAILED" >> $LOG_FILE
        echo "WMS health check failed. Check logs at $LOG_FILE" | mail -s "WMS Alert" $ALERT_EMAIL
        return 1
    else
        echo "$(date): WMS health check PASSED" >> $LOG_FILE
        return 0
    fi
}

main
```

#### Cron Job Setup

```bash
# Add to crontab for regular monitoring
# Check every 5 minutes
*/5 * * * * /usr/local/bin/wms-health-check.sh

# Daily maintenance at 2 AM
0 2 * * * /opt/OSM-Notes-profile/bin/wms/wmsManager.sh maintenance
```

### Performance Monitoring

#### Database Performance

```sql
-- Monitor query performance
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
WHERE query LIKE '%wms%'
ORDER BY mean_time DESC
LIMIT 10;

-- Monitor table statistics
SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del
FROM pg_stat_user_tables
WHERE schemaname = 'wms';

-- Monitor index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read
FROM pg_stat_user_indexes
WHERE schemaname = 'wms';
```

#### GeoServer Performance

```bash
# Monitor GeoServer memory usage
ps aux | grep geoserver

# Check GeoServer logs
tail -f /opt/geoserver/logs/geoserver.log

# Monitor WMS response times
curl -w "@curl-format.txt" -o /dev/null -s \
  "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png"
```

### Log Management

#### Log Rotation

Create logrotate configuration: `/etc/logrotate.d/wms`

```text
/var/log/wms*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload geoserver
    endscript
}
```

#### Log Analysis

```bash
# Analyze WMS access logs
grep "WMS" /opt/geoserver/logs/geoserver.log | \
  awk '{print $1, $2}' | \
  sort | uniq -c | sort -nr

# Monitor error patterns
grep "ERROR" /opt/geoserver/logs/geoserver.log | \
  tail -100 | \
  awk '{print $5}' | \
  sort | uniq -c | sort -nr
```

## Maintenance Procedures

### Regular Maintenance

#### Daily Tasks

```bash
# Check system health
/usr/local/bin/wms-health-check.sh

# Monitor disk space
df -h | grep -E "(/$|/opt)"

# Check service status
systemctl status geoserver
systemctl status postgresql
```

#### Weekly Tasks

```bash
# Update database statistics
psql -d osm_notes -c "ANALYZE wms.notes_wms;"

# Clean old logs
find /opt/geoserver/logs -name "*.log.*" -mtime +7 -delete

# Check for updates
apt list --upgradable | grep -E "(postgresql|geoserver)"
```

#### Monthly Tasks

```bash
# Full system backup
pg_dump osm_notes > /backup/osm_notes_$(date +%Y%m).sql

# GeoServer backup
cp -r /opt/geoserver/data_dir /backup/geoserver_$(date +%Y%m)

# Performance review
# Note: Performance monitoring can be implemented as needed
echo "Performance monitoring not yet implemented"
```

### Backup and Recovery

#### Database Backup

```bash
#!/bin/bash
# Database backup script

BACKUP_DIR="/backup/database"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="osm_notes"

# Create backup directory
mkdir -p $BACKUP_DIR

# Full database backup
pg_dump -h localhost -U postgres $DB_NAME > $BACKUP_DIR/${DB_NAME}_${DATE}.sql

# WMS schema only backup
pg_dump -h localhost -U postgres -n wms $DB_NAME > $BACKUP_DIR/wms_schema_${DATE}.sql

# Compress backups
gzip $BACKUP_DIR/${DB_NAME}_${DATE}.sql
gzip $BACKUP_DIR/wms_schema_${DATE}.sql

# Clean old backups (keep 30 days)
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR/${DB_NAME}_${DATE}.sql.gz"
```

#### GeoServer Backup

```bash
#!/bin/bash
# GeoServer backup script

BACKUP_DIR="/backup/geoserver"
DATE=$(date +%Y%m%d_%H%M%S)
GEOSERVER_DIR="/opt/geoserver/data_dir"

# Create backup directory
mkdir -p $BACKUP_DIR

# Stop GeoServer
systemctl stop geoserver

# Backup data directory
tar -czf $BACKUP_DIR/geoserver_${DATE}.tar.gz -C /opt geoserver/data_dir

# Start GeoServer
systemctl start geoserver

# Clean old backups (keep 30 days)
find $BACKUP_DIR -name "geoserver_*.tar.gz" -mtime +30 -delete

echo "GeoServer backup completed: $BACKUP_DIR/geoserver_${DATE}.tar.gz"
```

#### Recovery Procedures

**Database Recovery**

```bash
# Restore from backup
psql -h localhost -U postgres -d osm_notes < /backup/database/osm_notes_20250101_120000.sql

# Restore WMS schema only
psql -h localhost -U postgres -d osm_notes < /backup/database/wms_schema_20250101_120000.sql
```

**GeoServer Recovery**

```bash
# Stop GeoServer
systemctl stop geoserver

# Restore data directory
tar -xzf /backup/geoserver/geoserver_20250101_120000.tar.gz -C /opt

# Start GeoServer
systemctl start geoserver
```

### Performance Optimization

#### Database Optimization

```sql
-- Optimize WMS table
VACUUM ANALYZE wms.notes_wms;

-- Update column statistics
ALTER TABLE wms.notes_wms ALTER COLUMN year_created_at SET STATISTICS 1000;
ALTER TABLE wms.notes_wms ALTER COLUMN year_closed_at SET STATISTICS 1000;

-- Create additional indexes if needed
CREATE INDEX CONCURRENTLY IF NOT EXISTS notes_wms_recent
ON wms.notes_wms (year_created_at)
WHERE year_created_at >= extract(year from current_date) - 1;
```

#### GeoServer Optimization

```bash
# Optimize GeoServer memory
export GEOSERVER_OPTS="-Xms4g -Xmx8g -XX:+UseG1GC -XX:+UseStringDeduplication"

# Configure tile cache
# Edit /opt/geoserver/data_dir/gwc/geowebcache.xml
```

## Troubleshooting

### Common Issues

#### Database Connection Issues

**Symptoms:**

- WMS layers not loading
- Database connection errors in logs
- GeoServer unable to connect to PostgreSQL

**Diagnosis:**

```bash
# Test database connection
psql -h localhost -U postgres -d osm_notes -c "SELECT 1;"

# Check PostgreSQL status
systemctl status postgresql

# Check connection parameters
grep -E "(host|port|database)" /opt/geoserver/data_dir/workspaces/osm_notes/notes_wms/datastore.xml
```

**Solutions:**

```bash
# Restart PostgreSQL
sudo systemctl restart postgresql

# Check PostgreSQL logs
tail -f /var/log/postgresql/postgresql-*.log

# Verify WMS schema exists
psql -d osm_notes -c "SELECT COUNT(*) FROM wms.notes_wms;"
```

#### GeoServer Issues

**Symptoms:**

- GeoServer not responding
- 404 errors for WMS requests
- Memory errors in logs

**Diagnosis:**

```bash
# Check GeoServer status
systemctl status geoserver

# Check memory usage
ps aux | grep geoserver

# Check GeoServer logs
tail -f /opt/geoserver/logs/geoserver.log
```

**Solutions:**

```bash
# Restart GeoServer
sudo systemctl restart geoserver

# Increase memory if needed
export GEOSERVER_OPTS="-Xms4g -Xmx8g"
sudo systemctl restart geoserver

# Check disk space
df -h /opt/geoserver
```

#### Performance Issues

**Symptoms:**

- Slow WMS responses
- Timeout errors
- High CPU/memory usage

**Diagnosis:**

```bash
# Check system resources
top
iostat -x 1 5
free -h

# Check slow queries
psql -d osm_notes -c "SELECT query, calls, total_time, mean_time \
  FROM pg_stat_statements WHERE query LIKE '%wms%' \
  ORDER BY mean_time DESC LIMIT 5;"
```

**Solutions:**

```bash
# Optimize database
psql -d osm_notes -c "VACUUM ANALYZE wms.notes_wms;"

# Add indexes if needed
psql -d osm_notes -c "CREATE INDEX CONCURRENTLY IF NOT EXISTS notes_wms_geometry_gist \
  ON wms.notes_wms USING GIST (geometry);"

# Restart services
sudo systemctl restart postgresql geoserver
```

### Diagnostic Tools

#### System Health Check

```bash
#!/bin/bash
# Comprehensive system health check

echo "=== WMS System Health Check ==="
echo "Date: $(date)"
echo

# System resources
echo "=== System Resources ==="
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memory Usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
echo "Disk Usage: $(df -h / | awk 'NR==2 {print $5}')"
echo

# Database status
echo "=== Database Status ==="
if systemctl is-active --quiet postgresql; then
    echo "PostgreSQL: RUNNING"
    echo "WMS Records: $(psql -t -c "SELECT COUNT(*) FROM wms.notes_wms;" \
      osm_notes 2>/dev/null || echo "ERROR")"
else
    echo "PostgreSQL: STOPPED"
fi
echo

# GeoServer status
echo "=== GeoServer Status ==="
if systemctl is-active --quiet geoserver; then
    echo "GeoServer: RUNNING"
    if curl -s "http://localhost:8080/geoserver/rest/about/status" >/dev/null; then
        echo "WMS Service: RESPONDING"
    else
        echo "WMS Service: NOT RESPONDING"
    fi
else
    echo "GeoServer: STOPPED"
fi
echo

# Recent errors
echo "=== Recent Errors ==="
tail -5 /opt/geoserver/logs/geoserver.log | grep ERROR || echo "No recent errors"
echo
```

#### Performance Monitoring

```bash
#!/bin/bash
# Performance monitoring script

LOG_FILE="/var/log/wms-performance.log"

# Database performance
echo "$(date): Database Performance" >> $LOG_FILE
psql -d osm_notes -c "
SELECT
    schemaname,
    tablename,
    n_tup_ins,
    n_tup_upd,
    n_tup_del,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_stat_user_tables
WHERE schemaname = 'wms';" >> $LOG_FILE

# GeoServer performance
echo "$(date): GeoServer Performance" >> $LOG_FILE
ps aux | grep geoserver >> $LOG_FILE

# WMS response time
echo "$(date): WMS Response Time" >> $LOG_FILE
curl -w "Time: %{time_total}s\n" -o /dev/null -s \
  "http://localhost:8080/geoserver/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&LAYERS=osm_notes:notes_wms_layer&STYLES=&CRS=EPSG:4326&BBOX=-180,-90,180,90&WIDTH=256&HEIGHT=256&FORMAT=image/png" \
    >> $LOG_FILE
```

## Security Considerations

### Access Control

#### Database Security

```sql
-- Create dedicated WMS user with limited privileges
CREATE USER wms_user WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE osm_notes TO wms_user;
GRANT USAGE ON SCHEMA wms TO wms_user;
GRANT SELECT ON ALL TABLES IN SCHEMA wms TO wms_user;
```

#### GeoServer Security

```bash
# Enable authentication
export WMS_AUTH_ENABLED="true"
export WMS_AUTH_USER="wms_user"
export WMS_AUTH_PASSWORD="secure_password"

# Configure SSL/TLS
# Edit /opt/geoserver/webapps/geoserver/WEB-INF/web.xml
```

### Network Security

#### Firewall Configuration

```bash
# Allow only necessary ports
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 5432/tcp  # PostgreSQL (if remote)
sudo ufw allow 8080/tcp  # GeoServer
sudo ufw enable
```

#### SSL/TLS Configuration

```bash
# Configure SSL for GeoServer
# Generate SSL certificate
sudo keytool -genkey -alias geoserver -keyalg RSA -keystore /opt/geoserver/keystore.jks

# Configure GeoServer for HTTPS
# Edit /opt/geoserver/webapps/geoserver/WEB-INF/web.xml
```

## Automation and Scripting

### Automated Deployment

#### Ansible Playbook

Create `deploy-wms.yml`:

```yaml
---
- hosts: wms_servers
  become: yes
  tasks:
    - name: Install required packages
      apt:
        name: "{{ item }}"
        state: present
      loop:
        - postgresql
        - postgresql-contrib
        - postgis
        - openjdk-11-jdk
        - curl
        - wget
        - unzip

    - name: Configure PostgreSQL
      postgresql_user:
        name: wms_user
        password: "{{ wms_password }}"
        priv: "CONNECT"
        db: osm_notes
      become_user: postgres

    - name: Install GeoServer
      unarchive:
        src: https://sourceforge.net/projects/geoserver/files/GeoServer/2.24.0/geoserver-2.24.0-bin.zip
        dest: /opt/
        remote_src: yes

    - name: Configure GeoServer service
      template:
        src: geoserver.service.j2
        dest: /etc/systemd/system/geoserver.service
      notify: restart geoserver

  handlers:
    - name: restart geoserver
      systemd:
        name: geoserver
        state: restarted
        enabled: yes
```

#### Docker Deployment

Create `docker-compose.yml`:

```yaml
version: '3.8'
services:
  postgres:
    image: postgis/postgis:13-3.1
    environment:
      POSTGRES_DB: osm_notes
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  geoserver:
    image: kartoza/geoserver:2.24.0
    environment:
      GEOSERVER_ADMIN_PASSWORD: geoserver
      GEOSERVER_ADMIN_USER: admin
    volumes:
      - geoserver_data:/opt/geoserver/data_dir
    ports:
      - "8080:8080"
    depends_on:
      - postgres

volumes:
  postgres_data:
  geoserver_data:
```

### Monitoring Integration

#### Prometheus Metrics

```bash
# Install Prometheus node exporter
sudo apt-get install prometheus-node-exporter

# Configure GeoServer metrics
# Edit /opt/geoserver/webapps/geoserver/WEB-INF/web.xml
```

#### Grafana Dashboard

Create WMS dashboard configuration for Grafana to visualize:

- Database performance metrics
- GeoServer response times
- WMS request statistics
- System resource usage

## Version Information

- **WMS Version**: 1.3.0
- **GeoServer Version**: 2.24+
- **PostGIS Version**: 3.0+
- **PostgreSQL Version**: 12+
- **Last Updated**: 2025-07-27

## Related Documentation

- **WMS Guide**: See `docs/WMS_Guide.md`
- **Technical Specifications**: See `docs/WMS_Technical.md`
- **API Reference**: See `docs/WMS_API_Reference.md`
- **User Guide**: See `docs/WMS_User_Guide.md`
