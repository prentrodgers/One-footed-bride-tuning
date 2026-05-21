#!/bin/bash
# Manual installation of Bob IDE server on remote host without wget/curl
# This script downloads the server locally and copies it to the remote host

set -euo pipefail

REMOTE_HOST="one-footed-bride"
DISTRO_COMMIT="473fcbe9e52a0216936d3c384820ebb51fb5cfc2"
SERVER_URL="https://api.us-east.bob.ibm.com/update/reh/ibm-bob/linux/x64/1.109.5+bob1.0.2"
LOCAL_TEMP="/tmp/bobide-server-${DISTRO_COMMIT}.tar.gz"
REMOTE_DIR="\$HOME/.bobide-server/bin/${DISTRO_COMMIT}"

echo "=== Bob IDE Server Manual Installation ==="
echo ""
echo "This script will:"
echo "1. Download Bob IDE server locally (requires wget or curl on YOUR machine)"
echo "2. Copy it to the remote host via SSH"
echo "3. Extract and set up the server"
echo ""

# Check if we have wget or curl locally
if command -v wget &> /dev/null; then
    DOWNLOAD_CMD="wget -O"
elif command -v curl &> /dev/null; then
    DOWNLOAD_CMD="curl -L -o"
else
    echo "Error: Neither wget nor curl found on local machine"
    exit 1
fi

# Download the server locally
echo "Step 1: Downloading Bob IDE server locally..."
echo "URL: $SERVER_URL"
$DOWNLOAD_CMD "$LOCAL_TEMP" "$SERVER_URL"

if [ ! -f "$LOCAL_TEMP" ]; then
    echo "Error: Download failed"
    exit 1
fi

echo "✓ Downloaded to $LOCAL_TEMP"
echo ""

# Create remote directory
echo "Step 2: Creating remote directory..."
ssh "$REMOTE_HOST" "mkdir -p $REMOTE_DIR"
echo "✓ Remote directory created"
echo ""

# Copy to remote host
echo "Step 3: Copying server to remote host..."
scp "$LOCAL_TEMP" "${REMOTE_HOST}:/tmp/bobide-server.tar.gz"
echo "✓ Copied to remote host"
echo ""

# Extract on remote host
echo "Step 4: Extracting server on remote host..."
ssh "$REMOTE_HOST" "cd $REMOTE_DIR && tar -xzf /tmp/bobide-server.tar.gz --strip-components 1 && rm /tmp/bobide-server.tar.gz"
echo "✓ Server extracted"
echo ""

# Verify installation
echo "Step 5: Verifying installation..."
ssh "$REMOTE_HOST" "ls -la $REMOTE_DIR/bin/bobide-server"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ SUCCESS! Bob IDE server installed successfully"
    echo ""
    echo "Now try connecting with Bob IDE Remote SSH again."
else
    echo ""
    echo "⚠ Warning: Server binary not found after extraction"
    exit 1
fi

# Clean up local temp file
rm -f "$LOCAL_TEMP"
echo ""
echo "=== Installation Complete ==="

# Made with Bob
