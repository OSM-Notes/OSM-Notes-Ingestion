#!/bin/bash

# Reset Docker Environment Script
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
echo "Docker Environment Reset Script"
echo "=========================================="
echo

# Function to stop and remove containers
cleanup_containers() {
 log_info "Stopping and removing containers..."
 cd "${SCRIPT_DIR}"

 # Determine Docker commands
 if ! docker info &> /dev/null; then
  if sudo docker info &> /dev/null; then
   DOCKER_CMD="sudo docker"
   DOCKER_COMPOSE_CMD="sudo docker compose"
  else
   log_error "Docker is not accessible"
   return 1
  fi
 else
  DOCKER_CMD="docker"
  DOCKER_COMPOSE_CMD="docker compose"
 fi

 # Stop containers
 ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" down --remove-orphans

 # Remove containers if they still exist
 ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" rm -f

 log_success "Containers stopped and removed"
}

# Function to remove volumes
cleanup_volumes() {
 log_info "Removing volumes..."

 # Determine Docker commands
 if ! docker info &> /dev/null; then
  if sudo docker info &> /dev/null; then
   DOCKER_CMD="sudo docker"
   DOCKER_COMPOSE_CMD="sudo docker compose"
  else
   log_error "Docker is not accessible"
   return 1
  fi
 else
  DOCKER_CMD="docker"
  DOCKER_COMPOSE_CMD="docker compose"
 fi

 # Remove PostgreSQL data volume
 ${DOCKER_CMD} volume rm osm-notes-profile_postgres_data 2> /dev/null || true

 # Remove any other volumes
 ${DOCKER_CMD} volume prune -f

 log_success "Volumes removed"
}

# Function to rebuild images
rebuild_images() {
 log_info "Rebuilding Docker images..."

 cd "${SCRIPT_DIR}"

 # Determine Docker commands
 if ! docker info &> /dev/null; then
  if sudo docker info &> /dev/null; then
   DOCKER_CMD="sudo docker"
   DOCKER_COMPOSE_CMD="sudo docker compose"
  else
   log_error "Docker is not accessible"
   return 1
  fi
 else
  DOCKER_CMD="docker"
  DOCKER_COMPOSE_CMD="docker compose"
 fi

 # Build images with no cache
 ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" build --no-cache

 log_success "Images rebuilt"
}

# Function to start services
start_services() {
 log_info "Starting services..."

 cd "${SCRIPT_DIR}"

 # Determine Docker commands
 if ! docker info &> /dev/null; then
  if sudo docker info &> /dev/null; then
   DOCKER_CMD="sudo docker"
   DOCKER_COMPOSE_CMD="sudo docker compose"
  else
   log_error "Docker is not accessible"
   return 1
  fi
 else
  DOCKER_CMD="docker"
  DOCKER_COMPOSE_CMD="docker compose"
 fi

 # Start all services
 ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" up -d

 log_success "Services started"
}

# Function to wait for services
wait_for_services() {
 log_info "Waiting for services to be ready..."

 # Determine Docker commands
 if ! docker info &> /dev/null; then
  if sudo docker info &> /dev/null; then
   DOCKER_CMD="sudo docker"
   DOCKER_COMPOSE_CMD="sudo docker compose"
  else
   log_error "Docker is not accessible"
   return 1
  fi
 else
  DOCKER_CMD="docker"
  DOCKER_COMPOSE_CMD="docker compose"
 fi

 # Wait for PostgreSQL
 log_info "Waiting for PostgreSQL..."
 local retries=0
 while [[ "${retries}" -lt 30 ]]; do
  if ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" exec -T postgres pg_isready -U testuser -d osm_notes_test &> /dev/null; then
   log_success "PostgreSQL is ready"
   break
  else
   retries=$((retries + 1))
   log_warning "PostgreSQL not ready, waiting... (${retries}/30)"
   sleep 2
  fi
 done

 if [[ "${retries}" -eq 30 ]]; then
  log_error "PostgreSQL failed to start within timeout"
  return 1
 fi

 # Wait for mock API
 log_info "Waiting for mock API..."
 retries=0
 while [[ "${retries}" -lt 30 ]]; do
  if curl -s http://localhost:8001/api/0.6/notes &> /dev/null; then
   log_success "Mock API is ready"
   break
  else
   retries=$((retries + 1))
   log_warning "Mock API not ready, waiting... (${retries}/30)"
   sleep 2
  fi
 done

 if [[ "${retries}" -eq 30 ]]; then
  log_error "Mock API failed to start within timeout"
  return 1
 fi
}

# Function to verify services
verify_services() {
 log_info "Verifying services..."

 # Determine Docker commands
 if ! docker info &> /dev/null; then
  if sudo docker info &> /dev/null; then
   DOCKER_CMD="sudo docker"
   DOCKER_COMPOSE_CMD="sudo docker compose"
  else
   log_error "Docker is not accessible"
   return 1
  fi
 else
  DOCKER_CMD="docker"
  DOCKER_COMPOSE_CMD="docker compose"
 fi

 # Check PostgreSQL
 if ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" exec -T postgres psql -U testuser -d osm_notes_test -c "SELECT 1;" &> /dev/null; then
  log_success "PostgreSQL connection verified"
 else
  log_error "PostgreSQL connection failed"
  return 1
 fi

 # Check mock API
 if curl -s http://localhost:8001/api/0.6/notes &> /dev/null; then
  log_success "Mock API connection verified"
 else
  log_error "Mock API connection failed"
  return 1
 fi

 # Show running containers
 log_info "Running containers:"
 ${DOCKER_COMPOSE_CMD} -f "${DOCKER_COMPOSE_FILE}" ps
}

# Main function
main() {
 case "${1:-}" in
 --help | -h)
  echo "Usage: $0 [OPTIONS]"
  echo
  echo "Options:"
  echo "  --help, -h           Show this help message"
  echo "  --cleanup-only       Only cleanup containers and volumes"
  echo "  --rebuild-only       Only rebuild images"
  echo "  --start-only         Only start services"
  echo "  --verify-only        Only verify services"
  echo "  --full-reset         Full reset (cleanup + rebuild + start)"
  echo
  exit 0
  ;;
 --cleanup-only)
  cleanup_containers
  cleanup_volumes
  ;;
 --rebuild-only)
  rebuild_images
  ;;
 --start-only)
  start_services
  wait_for_services
  ;;
 --verify-only)
  verify_services
  ;;
 --full-reset | "")
  log_info "Performing full reset..."
  cleanup_containers
  cleanup_volumes
  rebuild_images
  start_services
  wait_for_services
  verify_services
  ;;
 *)
  log_error "Unknown option: $1"
  log_error "Use --help for usage information"
  exit 1
  ;;
 esac

 log_success "Reset completed successfully!"
}

# Run main function
main "$@"
