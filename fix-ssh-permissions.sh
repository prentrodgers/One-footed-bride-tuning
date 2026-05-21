#!/bin/bash
# Fix SSH configuration permissions for distrobox
# This script resolves the "Bad owner or permissions" error when connecting to one-footed-bride pod

set -euo pipefail

echo "=== SSH Permission Fix for Distrobox ==="
echo ""

# Check if running in distrobox
if [ -f /run/.containerenv ] || [ -f /.dockerenv ]; then
    echo "✓ Running inside container/distrobox"
else
    echo "⚠ Warning: Not running in a container. This script is designed for distrobox."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""
echo "Current SSH config file status:"
ls -la ~/.ssh/config || echo "Config file not found!"

echo ""
echo "Fixing permissions..."

# Fix config file ownership and permissions
if [ -f ~/.ssh/config ]; then
    chmod 644 ~/.ssh/config
    chown $(whoami):$(whoami) ~/.ssh/config 2>/dev/null || {
        echo "⚠ Cannot change ownership (may require host-level fix)"
        echo "  Attempting to fix permissions only..."
        chmod 644 ~/.ssh/config
    }
fi

# Fix SSH key permissions
if [ -f ~/.ssh/id_ed25519 ]; then
    chmod 600 ~/.ssh/id_ed25519
    echo "✓ Fixed private key permissions"
fi

if [ -f ~/.ssh/id_ed25519.pub ]; then
    chmod 644 ~/.ssh/id_ed25519.pub
    echo "✓ Fixed public key permissions"
fi

# Fix SSH directory permissions
chmod 700 ~/.ssh
echo "✓ Fixed .ssh directory permissions"

echo ""
echo "Updated SSH config file status:"
ls -la ~/.ssh/config

echo ""
echo "Testing SSH connection to one-footed-bride..."
echo "Running: ssh -o ConnectTimeout=5 -o BatchMode=yes one-footed-bride exit 2>&1"
echo ""

if ssh -o ConnectTimeout=5 -o BatchMode=yes one-footed-bride exit 2>&1; then
    echo ""
    echo "✅ SUCCESS! SSH connection to one-footed-bride is working!"
else
    EXIT_CODE=$?
    echo ""
    echo "⚠ SSH connection test failed (exit code: $EXIT_CODE)"
    echo ""
    echo "Common issues:"
    echo "1. If you see 'Bad owner or permissions' - ownership may need to be fixed on the host"
    echo "2. If you see 'Connection refused' - check if the pod is running"
    echo "3. If you see 'Permission denied (publickey)' - check SSH key authentication"
    echo ""
    echo "Try manual connection with verbose output:"
    echo "  ssh -v one-footed-bride"
    echo ""
    echo "Or connect directly without config:"
    echo "  ssh -p 30222 prent@192.168.68.16"
fi

echo ""
echo "=== Fix Complete ==="

# Made with Bob
