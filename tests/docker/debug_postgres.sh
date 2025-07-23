#!/bin/bash

# PostgreSQL Debug Script for Docker Environment
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"

echo "=========================================="
echo "PostgreSQL Debug Script"
echo "=========================================="
echo

# Check if Docker is running
log_info "Checking Docker status..."
if ! docker info &> /dev/null; then
    # Try with sudo
    if sudo docker info &> /dev/null; then
        log_warning "Docker requires sudo access"
        DOCKER_CMD="sudo docker"
        DOCKER_COMPOSE_CMD="sudo docker-compose"
    else
        log_error "Docker daemon is not running"
        exit 1
    fi
else
    DOCKER_CMD="docker"
    DOCKER_COMPOSE_CMD="docker-compose"
fi
log_success "Docker is running"

# Check if containers are running
log_info "Checking container status..."
if ! ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" ps &> /dev/null; then
    log_error "Docker Compose file not found or invalid"
    exit 1
fi

# Show running containers
log_info "Running containers:"
${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" ps

# Check PostgreSQL container specifically
log_info "Checking PostgreSQL container..."
if ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" ps postgres | grep -q "Up"; then
    log_success "PostgreSQL container is running"
else
    log_error "PostgreSQL container is not running"
    log_info "Starting PostgreSQL container..."
    ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" up -d postgres
    sleep 10
fi

# Check PostgreSQL logs
log_info "PostgreSQL logs:"
${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" logs postgres

# Check if PostgreSQL is ready
log_info "Checking PostgreSQL readiness..."
if ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" exec -T postgres pg_isready -U testuser -d osm_notes_test; then
    log_success "PostgreSQL is ready"
else
    log_error "PostgreSQL is not ready"
    log_info "Waiting for PostgreSQL to be ready..."
    for i in {1..30}; do
        if ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" exec -T postgres pg_isready -U testuser -d osm_notes_test; then
            log_success "PostgreSQL is now ready"
            break
        else
            log_warning "PostgreSQL not ready, waiting... ($i/30)"
            sleep 2
        fi
    done
fi

# Test database connection
log_info "Testing database connection..."
if ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" exec -T postgres psql -U testuser -d osm_notes_test -c "SELECT 1;" &> /dev/null; then
    log_success "Database connection successful"
else
    log_error "Database connection failed"
fi

# Check database tables
log_info "Checking database tables..."
${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" exec -T postgres psql -U testuser -d osm_notes_test -c "\dt"

# Check pgTAP extension
log_info "Checking pgTAP extension..."
if ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" exec -T postgres psql -U testuser -d osm_notes_test -c "SELECT 1 FROM pg_extension WHERE extname = 'pgtap';" &> /dev/null; then
    log_success "pgTAP extension is available"
else
    log_warning "pgTAP extension is not available"
fi

# Check container resources
log_info "Container resource usage:"
${DOCKER_CMD} stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"

echo
echo "=========================================="
echo "Debug Summary"
echo "=========================================="
echo "If PostgreSQL is not working, try:"
echo "1. docker-compose down -v"
echo "2. docker-compose up -d postgres"
echo "3. Wait 30 seconds for initialization"
echo "4. Run this script again"
echo 