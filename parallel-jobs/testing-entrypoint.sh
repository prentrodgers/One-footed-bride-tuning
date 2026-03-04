#!/usr/bin/env bash
set -euo pipefail

echo "Container started — opening interactive shell."
echo "Mounted PVC is at /mnt/dropbox (if present)."
echo "Python version:"
python --version
echo "Installed packages:"
pip list

# Drop into an interactive shell
exec bash
