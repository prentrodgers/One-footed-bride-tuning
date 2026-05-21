#!/bin/bash
# Fix SSH configuration permissions from HOST system
# Run this on the host (outside distrobox) to fix ownership issues

set -euo pipefail

echo "=== SSH Permission Fix (Host Side) ==="
echo ""

# Check if NOT running in distrobox
if [ -f /run/.containerenv ] || [ -f /.dockerenv ]; then
    echo "❌ ERROR: This script must be run on the HOST, not inside distrobox!"
    echo "   Exit the distrobox first with: exit"
    echo "   Then run this script from the host."
    exit 1
fi

echo "✓ Running on host system"
echo ""

SSH_CONFIG="$HOME/.ssh/config"

if [ ! -f "$SSH_CONFIG" ]; then
    echo "❌ ERROR: SSH config file not found at $SSH_CONFIG"
    exit 1
fi

echo "Current SSH config file status:"
ls -la "$SSH_CONFIG"

CURRENT_OWNER=$(stat -c '%U:%G' "$SSH_CONFIG")
echo "Current owner: $CURRENT_OWNER"

if [ "$CURRENT_OWNER" != "$USER:$USER" ]; then
    echo ""
    echo "⚠ File is owned by $CURRENT_OWNER, need sudo to fix..."
    echo "Running: sudo chown $USER:$USER on SSH files"
    echo ""
fi

echo "Fixing ownership and permissions..."

# Fix ownership to current user (may need sudo)
sudo chown "$USER:$USER" "$SSH_CONFIG"
sudo chmod 644 "$SSH_CONFIG"

echo "✓ Fixed config file ownership and permissions"

# Fix SSH key permissions if they exist
if [ -f "$HOME/.ssh/id_ed25519" ]; then
    sudo chown "$USER:$USER" "$HOME/.ssh/id_ed25519"
    sudo chmod 600 "$HOME/.ssh/id_ed25519"
    echo "✓ Fixed private key permissions"
fi

if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    sudo chown "$USER:$USER" "$HOME/.ssh/id_ed25519.pub"
    sudo chmod 644 "$HOME/.ssh/id_ed25519.pub"
    echo "✓ Fixed public key permissions"
fi

# Fix SSH directory permissions
sudo chown "$USER:$USER" "$HOME/.ssh"
sudo chmod 700 "$HOME/.ssh"
echo "✓ Fixed .ssh directory permissions"

echo ""
echo "Updated SSH config file status:"
ls -la "$SSH_CONFIG"

echo ""
echo "=== Fix Complete ==="
echo ""
echo "Now you can enter the distrobox and test SSH:"
echo "  distrobox enter ubuntu  # or your distrobox name"
echo "  ssh one-footed-bride"
echo ""

# Made with Bob
