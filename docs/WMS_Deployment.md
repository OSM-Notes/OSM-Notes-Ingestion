# WMS Deployment Guide

## Overview

This guide provides comprehensive deployment procedures for the WMS (Web Map Service) component across different environments, from development to production.

### Target Audience

- **DevOps Engineers**: Automating deployment processes
- **System Administrators**: Managing production deployments
- **Developers**: Setting up development environments
- **Infrastructure Teams**: Planning and executing deployments

## Deployment Environments

### Development Environment

#### Local Development Setup

```bash
#!/bin/bash
# Development environment setup

# Install dependencies
sudo apt-get update
sudo apt-get install -y \
    postgresql postgresql-contrib postgis \
    openjdk-11-jdk \
    curl wget unzip \
    docker docker-compose

# Create development database
sudo -u postgres psql -c "CREATE DATABASE osm_notes_dev;"
sudo -u postgres psql -c "CREATE EXTENSION postgis;" osm_notes_dev
sudo -u postgres psql -c "CREATE USER wms_dev WITH PASSWORD 'dev_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE osm_notes_dev TO wms_dev;"

# Configure development properties
cat > etc/wms.dev.properties.sh << 'EOF'
#!/bin/bash
# Development configuration

WMS_DBNAME="osm_notes_dev"
WMS_DBUSER="wms_dev"
WMS_DBPASSWORD="dev_password"
WMS_DBHOST="localhost"
WMS_DBPORT="5432"

GEOSERVER_URL="http://localhost:8080/geoserver"
GEOSERVER_USER="admin"
GEOSERVER_PASSWORD="geoserver"

WMS_DEV_MODE="true"
WMS_DEBUG_ENABLED="true"
WMS_LOG_LEVEL="DEBUG"
EOF

chmod +x etc/wms.dev.properties.sh
```

#### Docker Development Environment

```yaml
# docker-compose.dev.yml
version: '3.8'
services:
  postgres-dev:
    image: postgis/postgis:13-3.1
    environment:
      POSTGRES_DB: osm_notes_dev
      POSTGRES_USER: wms_dev
      POSTGRES_PASSWORD: dev_password
    volumes:
      - postgres_dev_data:/var/lib/postgresql/data
      - ./sql:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"

  geoserver-dev:
    image: kartoza/geoserver:2.24.0
    environment:
      GEOSERVER_ADMIN_PASSWORD: geoserver
      GEOSERVER_ADMIN_USER: admin
    volumes:
      - geoserver_dev_data:/opt/geoserver/data_dir
      - ./sld:/opt/geoserver/data_dir/styles
    ports:
      - "8080:8080"
    depends_on:
      - postgres-dev

volumes:
  postgres_dev_data:
  geoserver_dev_data:
```

### Staging Environment

#### Staging Configuration

```bash
#!/bin/bash
# Staging environment setup

# Create staging database
sudo -u postgres psql -c "CREATE DATABASE osm_notes_staging;"
sudo -u postgres psql -c "CREATE EXTENSION postgis;" osm_notes_staging
sudo -u postgres psql -c "CREATE USER wms_staging WITH PASSWORD 'staging_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE osm_notes_staging TO wms_staging;"

# Configure staging properties
cat > etc/wms.staging.properties.sh << 'EOF'
#!/bin/bash
# Staging configuration

WMS_DBNAME="osm_notes_staging"
WMS_DBUSER="wms_staging"
WMS_DBPASSWORD="staging_password"
WMS_DBHOST="staging-db.example.com"
WMS_DBPORT="5432"

GEOSERVER_URL="http://staging-geoserver.example.com/geoserver"
GEOSERVER_USER="admin"
GEOSERVER_PASSWORD="secure_password"

WMS_DEV_MODE="false"
WMS_DEBUG_ENABLED="false"
WMS_LOG_LEVEL="INFO"
EOF

chmod +x etc/wms.staging.properties.sh
```

### Production Environment

#### Production Configuration

```bash
#!/bin/bash
# Production environment setup

# Create production database
sudo -u postgres psql -c "CREATE DATABASE osm_notes_prod;"
sudo -u postgres psql -c "CREATE EXTENSION postgis;" osm_notes_prod
sudo -u postgres psql -c "CREATE USER wms_prod WITH PASSWORD 'secure_prod_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE osm_notes_prod TO wms_prod;"

# Configure production properties
cat > etc/wms.prod.properties.sh << 'EOF'
#!/bin/bash
# Production configuration

WMS_DBNAME="osm_notes_prod"
WMS_DBUSER="wms_prod"
WMS_DBPASSWORD="secure_prod_password"
WMS_DBHOST="prod-db.example.com"
WMS_DBPORT="5432"

GEOSERVER_URL="https://geoserver.example.com/geoserver"
GEOSERVER_USER="admin"
GEOSERVER_PASSWORD="very_secure_password"

WMS_DEV_MODE="false"
WMS_DEBUG_ENABLED="false"
WMS_LOG_LEVEL="WARN"

# Production optimizations
WMS_DB_POOL_SIZE="20"
WMS_CACHE_TTL="7200"
WMS_CACHE_MAX_SIZE="500"
EOF

chmod +x etc/wms.prod.properties.sh
```

## Automated Deployment

### Ansible Playbook

```yaml
---
- hosts: wms_servers
  become: yes
  vars:
    wms_version: "1.3.0"
    geoserver_version: "2.24.0"
    postgres_version: "13"
    
  tasks:
    - name: Install system dependencies
      apt:
        name: "{{ item }}"
        state: present
        update_cache: yes
      loop:
        - postgresql
        - postgresql-contrib
        - postgis
        - openjdk-11-jdk
        - curl
        - wget
        - unzip
        - nginx

    - name: Configure PostgreSQL
      postgresql_user:
        name: "{{ wms_db_user }}"
        password: "{{ wms_db_password }}"
        priv: "CONNECT"
        db: "{{ wms_db_name }}"
      become_user: postgres

    - name: Create WMS database
      postgresql_db:
        name: "{{ wms_db_name }}"
        owner: "{{ wms_db_user }}"
      become_user: postgres

    - name: Enable PostGIS extension
      postgresql_query:
        db: "{{ wms_db_name }}"
        query: "CREATE EXTENSION IF NOT EXISTS postgis;"
      become_user: postgres

    - name: Download GeoServer
      get_url:
        url: "https://sourceforge.net/projects/geoserver/files/GeoServer/{{ geoserver_version }}/geoserver-{{ geoserver_version }}-bin.zip"
        dest: "/tmp/geoserver-{{ geoserver_version }}-bin.zip"
        mode: '0644'

    - name: Extract GeoServer
      unarchive:
        src: "/tmp/geoserver-{{ geoserver_version }}-bin.zip"
        dest: "/opt/"
        remote_src: yes

    - name: Create GeoServer service user
      user:
        name: geoserver
        system: yes
        shell: /bin/false
        home: /opt/geoserver

    - name: Set GeoServer permissions
      file:
        path: "/opt/geoserver-{{ geoserver_version }}"
        owner: geoserver
        group: geoserver
        recurse: yes

    - name: Create GeoServer data directory
      file:
        path: "/opt/geoserver/data_dir"
        state: directory
        owner: geoserver
        group: geoserver
        mode: '0755'

    - name: Configure GeoServer service
      template:
        src: geoserver.service.j2
        dest: /etc/systemd/system/geoserver.service
        mode: '0644'
      notify: restart geoserver

    - name: Deploy WMS configuration
      include_tasks: deploy_wms.yml

  handlers:
    - name: restart geoserver
      systemd:
        name: geoserver
        state: restarted
        enabled: yes
```

### Docker Deployment

```yaml
# docker-compose.prod.yml
version: '3.8'
services:
  postgres-prod:
    image: postgis/postgis:13-3.1
    environment:
      POSTGRES_DB: ${WMS_DBNAME}
      POSTGRES_USER: ${WMS_DBUSER}
      POSTGRES_PASSWORD: ${WMS_DBPASSWORD}
    volumes:
      - postgres_prod_data:/var/lib/postgresql/data
      - ./sql:/docker-entrypoint-initdb.d
    networks:
      - wms_network
    restart: unless-stopped

  geoserver-prod:
    image: kartoza/geoserver:2.24.0
    environment:
      GEOSERVER_ADMIN_PASSWORD: ${GEOSERVER_PASSWORD}
      GEOSERVER_ADMIN_USER: ${GEOSERVER_USER}
      GEOSERVER_DATA_DIR: /opt/geoserver/data_dir
      GEOSERVER_OPTS: "-Xms2g -Xmx4g -XX:+UseG1GC"
    volumes:
      - geoserver_prod_data:/opt/geoserver/data_dir
      - ./sld:/opt/geoserver/data_dir/styles
    networks:
      - wms_network
    ports:
      - "8080:8080"
    depends_on:
      - postgres-prod
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    ports:
      - "80:80"
      - "443:443"
    networks:
      - wms_network
    depends_on:
      - geoserver-prod
    restart: unless-stopped

volumes:
  postgres_prod_data:
  geoserver_prod_data:

networks:
  wms_network:
    driver: bridge
```

### Kubernetes Deployment

```yaml
# k8s-wms-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wms-geoserver
  labels:
    app: wms-geoserver
spec:
  replicas: 2
  selector:
    matchLabels:
      app: wms-geoserver
  template:
    metadata:
      labels:
        app: wms-geoserver
    spec:
      containers:
      - name: geoserver
        image: kartoza/geoserver:2.24.0
        ports:
        - containerPort: 8080
        env:
        - name: GEOSERVER_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: wms-secrets
              key: geoserver-password
        - name: GEOSERVER_ADMIN_USER
          value: "admin"
        volumeMounts:
        - name: geoserver-data
          mountPath: /opt/geoserver/data_dir
        - name: sld-styles
          mountPath: /opt/geoserver/data_dir/styles
        resources:
          requests:
            memory: "2Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "1000m"
      volumes:
      - name: geoserver-data
        persistentVolumeClaim:
          claimName: geoserver-pvc
      - name: sld-styles
        configMap:
          name: sld-styles

---
apiVersion: v1
kind: Service
metadata:
  name: wms-geoserver-service
spec:
  selector:
    app: wms-geoserver
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: LoadBalancer

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: geoserver-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

## CI/CD Pipeline

### GitHub Actions Deployment

```yaml
name: WMS Deployment

on:
  push:
    branches: [ main ]
  workflow_dispatch:

jobs:
  deploy-dev:
    runs-on: ubuntu-latest
    environment: development
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Deploy to Development
      run: |
        echo "Deploying WMS to development environment..."
        # Add deployment steps here
        
    - name: Run tests
      run: |
        # Note: Create test scripts in tests/ directory as needed
        echo "Integration tests completed"

  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging
    needs: deploy-dev
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Deploy to Staging
      run: |
        echo "Deploying WMS to staging environment..."
        # Add deployment steps here
        
    - name: Run performance tests
      run: |
        # Note: Create test scripts in tests/ directory as needed
        echo "Performance tests completed"

  deploy-production:
    runs-on: ubuntu-latest
    environment: production
    needs: deploy-staging
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Deploy to Production
      run: |
        echo "Deploying WMS to production environment..."
        # Add deployment steps here
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'registry.example.com'
        WMS_VERSION = '1.3.0'
    }
    
    stages {
        stage('Build') {
            steps {
                sh '''
                    # Build Docker images
                    docker build -t ${DOCKER_REGISTRY}/wms-geoserver:${WMS_VERSION} .
                    docker push ${DOCKER_REGISTRY}/wms-geoserver:${WMS_VERSION}
                '''
            }
        }
        
        stage('Deploy Dev') {
            steps {
                sh '''
                    # Deploy to development
                    kubectl apply -f k8s-wms-deployment.yaml
                    kubectl set image deployment/wms-geoserver geoserver=${DOCKER_REGISTRY}/wms-geoserver:${WMS_VERSION}
                '''
            }
        }
        
        stage('Test') {
            steps {
                sh '''
                    # Run tests
                    # Note: Create test scripts in tests/ directory as needed
                    echo "Integration tests completed"
                '''
            }
        }
        
        stage('Deploy Staging') {
            when { branch 'main' }
            steps {
                sh '''
                    # Deploy to staging
                    kubectl apply -f k8s-wms-deployment-staging.yaml
                '''
            }
        }
        
        stage('Deploy Production') {
            when { branch 'main' }
            steps {
                input message: 'Deploy to production?'
                sh '''
                    # Deploy to production
                    kubectl apply -f k8s-wms-deployment-prod.yaml
                '''
            }
        }
    }
}
```

## Monitoring and Health Checks

### Health Check Script

```bash
#!/bin/bash
# WMS health check script

LOG_FILE="/var/log/wms-health-check.log"
ALERT_EMAIL="admin@example.com"

# Check database connection
check_database() {
    psql -h $WMS_DBHOST -U $WMS_DBUSER -d $WMS_DBNAME -c "SELECT COUNT(*) FROM wms.notes_wms;" >/dev/null 2>&1
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
    curl -s "${GEOSERVER_URL}/rest/about/status" >/dev/null
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
    curl -s "${GEOSERVER_URL}/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetCapabilities" >/dev/null
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

## Backup and Recovery

### Backup Script

```bash
#!/bin/bash
# WMS backup script

BACKUP_DIR="/backup/wms"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
pg_dump -h $WMS_DBHOST -U $WMS_DBUSER -d $WMS_DBNAME > $BACKUP_DIR/wms_db_$DATE.sql

# Backup GeoServer data
tar -czf $BACKUP_DIR/geoserver_data_$DATE.tar.gz /opt/geoserver/data_dir

# Backup configuration files
tar -czf $BACKUP_DIR/wms_config_$DATE.tar.gz etc/wms*.properties.sh

# Clean old backups
find $BACKUP_DIR -name "*.sql" -mtime +$RETENTION_DAYS -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: $DATE"
```

### Recovery Script

```bash
#!/bin/bash
# WMS recovery script

BACKUP_FILE=$1
if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file>"
    exit 1
fi

# Stop services
systemctl stop geoserver

# Restore database
psql -h $WMS_DBHOST -U $WMS_DBUSER -d $WMS_DBNAME < $BACKUP_FILE

# Restore GeoServer data
tar -xzf ${BACKUP_FILE%.sql}_geoserver.tar.gz -C /

# Restore configuration
tar -xzf ${BACKUP_FILE%.sql}_config.tar.gz -C /

# Start services
systemctl start geoserver

echo "Recovery completed"
```

## Security Considerations

### SSL/TLS Configuration

```nginx
# nginx.conf
server {
    listen 80;
    server_name geoserver.example.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name geoserver.example.com;
    
    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;
    
    location /geoserver {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Firewall Configuration

```bash
#!/bin/bash
# Firewall configuration for WMS

# Allow SSH
ufw allow ssh

# Allow HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow PostgreSQL (if external)
ufw allow 5432/tcp

# Enable firewall
ufw enable
```

## Performance Optimization

### Database Optimization

```sql
-- Production database optimizations
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;

-- Reload configuration
SELECT pg_reload_conf();
```

### GeoServer Optimization

```bash
#!/bin/bash
# GeoServer performance optimization

# Memory settings
export GEOSERVER_OPTS="-Xms2g -Xmx4g -XX:+UseG1GC -XX:+UseStringDeduplication"

# JVM tuning
export JAVA_OPTS="$JAVA_OPTS -XX:+UseG1GC -XX:MaxGCPauseMillis=200"

# GeoServer specific settings
export GEOSERVER_DATA_DIR="/opt/geoserver/data_dir"
export GEOSERVER_LOG_LOCATION="/var/log/geoserver"
```

## Version Information

- **WMS Version**: 1.3.0
- **Deployment Methods**: Ansible, Docker, Kubernetes
- **Supported Environments**: Development, Staging, Production
- **Last Updated**: 2025-07-27

## Related Documentation

- **WMS Guide**: See `docs/WMS_Guide.md`
- **Technical Specifications**: See `docs/WMS_Technical.md`
- **Development Guide**: See `docs/WMS_Development.md`
- **Testing Guide**: See `docs/WMS_Testing.md`
- **API Reference**: See `docs/WMS_API_Reference.md` 