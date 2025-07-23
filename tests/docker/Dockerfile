# Dockerfile for OSM-Notes-profile Test Environment
# Author: Andres Gomez (AngocA)
# Version: 2025-07-20

FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    libxml2-dev \
    libxslt1-dev \
    postgresql-client \
    bats \
    python3 \
    python3-pip \
    netcat \
    iputils-ping \
    aria2 \
    mutt \
    bzip2 \
    libxml2-utils \
    xsltproc \
    xmlstarlet \
    nodejs \
    npm \
    gdal-bin \
    && rm -rf /var/lib/apt/lists/*

# Install additional tools
RUN pip3 install \
    requests \
    pytest \
    pytest-mock \
    psutil

# Install Node.js tools
RUN npm install -g ajv-cli osmtogeojson

# Create test user
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser:testpass" | chpasswd

# PostgreSQL is handled by a separate container

# Create application directory
WORKDIR /app

# Copy application files
COPY . /app/

# Set permissions
RUN chown -R testuser:testuser /app && \
    chmod +x /app/tests/run_tests.sh && \
    chmod +x /app/bin/process/*.sh && \
    chmod +x /app/bin/functionsProcess.sh

# Switch to test user
USER testuser

# Set environment variables for tests
ENV TEST_DBNAME=osm_notes_test
ENV TEST_DBUSER=testuser
ENV TEST_DBPASSWORD=testpass
ENV TEST_DBHOST=localhost
ENV TEST_DBPORT=5432
ENV LOG_LEVEL=INFO
ENV MAX_THREADS=2

# PostgreSQL port is handled by the postgres container

# Default command
CMD ["/bin/bash"] 