# Dockerfile for OSM-Notes-profile Test Environment
# Author: Andres Gomez (AngocA)
# Version: 2025-10-24

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
    postgresql-client \
    python3 \
    python3-pip \
    netcat \
    iputils-ping \
    aria2 \
    mutt \
    bzip2 \
    libxml2-utils \
    xmlstarlet \
    nodejs \
    npm \
    gdal-bin \
    bc \
    shellcheck \
    cmake \
    libcurl4-openssl-dev \
    libelf-dev \
    libdw-dev \
    gawk \
    && rm -rf /var/lib/apt/lists/*

# Install BATS-core (modern version with bats_require_minimum_version support)
RUN git clone --depth 1 --branch v1.11.0 https://github.com/bats-core/bats-core.git /tmp/bats-core && \
    cd /tmp/bats-core && \
    ./install.sh /usr/local && \
    rm -rf /tmp/bats-core

# Install bats-support and bats-assert
RUN git clone --depth 1 https://github.com/bats-core/bats-support.git /usr/local/lib/bats-support && \
    git clone --depth 1 https://github.com/bats-core/bats-assert.git /usr/local/lib/bats-assert

# Install shfmt
RUN wget -O /usr/local/bin/shfmt https://github.com/mvdan/sh/releases/download/v3.8.0/shfmt_v3.8.0_linux_amd64 && \
    chmod +x /usr/local/bin/shfmt

# Install additional tools
RUN pip3 install \
    requests \
    pytest \
    pytest-mock \
    psutil

# Install Node.js tools
RUN npm install -g ajv-cli osmtogeojson

# Install kcov for code coverage
RUN git clone https://github.com/SimonKagstrom/kcov.git && \
    cd kcov && mkdir build && cd build && \
    cmake .. && make && make install && \
    cd / && rm -rf /kcov

# Create test user
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser:testpass" | chpasswd

# PostgreSQL is handled by a separate container

# Create application directory
WORKDIR /app

# Copy application files
COPY . /app/

# Ensure AWK scripts are available
RUN mkdir -p /app/awk

# Create test directories with proper permissions
RUN mkdir -p /app/tests/output && \
    mkdir -p /app/tests/tmp && \
    mkdir -p /app/tests/results && \
    chmod 777 /app/tests/output && \
    chmod 777 /app/tests/tmp && \
    chmod 777 /app/tests/results

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