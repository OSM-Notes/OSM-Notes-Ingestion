#!/bin/bash
# Script to install shfmt from GitHub releases
# Author: Andres Gomez (AngocA)
# Version: 2025-10-12

set -euo pipefail

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

# Map architecture names
case "${ARCH}" in
x86_64)
 ARCH="amd64"
 ;;
aarch64 | arm64)
 ARCH="arm64"
 ;;
armv7l)
 ARCH="arm"
 ;;
*)
 echo "Unsupported architecture: ${ARCH}"
 exit 1
 ;;
esac

# shfmt version to install
SHFMT_VERSION="v3.7.0"

# Download URL
DOWNLOAD_URL="https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_${OS}_${ARCH}"

echo "Downloading shfmt ${SHFMT_VERSION} for ${OS}/${ARCH}..."
echo "URL: ${DOWNLOAD_URL}"

# Download to /usr/local/bin or ~/.local/bin depending on permissions
if [[ -w /usr/local/bin ]]; then
 INSTALL_DIR="/usr/local/bin"
else
 INSTALL_DIR="${HOME}/.local/bin"
 mkdir -p "${INSTALL_DIR}"
 export PATH="${INSTALL_DIR}:${PATH}"
 # For GitHub Actions, also write to GITHUB_PATH if available
 if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "${INSTALL_DIR}" >> "${GITHUB_PATH}"
 fi
fi

# Download shfmt
curl -sSL "${DOWNLOAD_URL}" -o "${INSTALL_DIR}/shfmt"

# Make it executable
chmod +x "${INSTALL_DIR}/shfmt"

# Verify installation
if command -v shfmt > /dev/null 2>&1; then
 echo "✓ shfmt installed successfully"
 shfmt --version
else
 echo "✗ shfmt installation failed"
 exit 1
fi
