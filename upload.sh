#!/usr/bin/env bash
set -euo pipefail

# Upload a file from host -> container (run on M70q).
# Defaults match current one-footed-bride workflow.

POD="one-footed-bride-797b5c96f9-s28lk"
CONTAINER="one-footed-bride"
CONTAINER_DIR="/home/prent/Repos/One-footed-bride-tuning"
HOST_DIR="."
FILENAME=""

usage() {
  cat <<'EOF'
Usage: upload.sh --filename <name> [--host_dir <dir>] [--pod <pod>] [--container <name>] [--container_dir <dir>]

Copies one file from host filesystem to container filesystem.

Examples:
  ./upload.sh --filename sagittal_codepoint_chart_bravura.pdf
  ./upload.sh --filename bwv255_sagittal.pdf --host_dir ~/Downloads
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --filename)
      FILENAME="${2:-}"
      shift 2
      ;;
    --host_dir)
      HOST_DIR="${2:-}"
      shift 2
      ;;
    --pod)
      POD="${2:-}"
      shift 2
      ;;
    --container)
      CONTAINER="${2:-}"
      shift 2
      ;;
    --container_dir)
      CONTAINER_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$FILENAME" ]]; then
  echo "Error: --filename is required" >&2
  usage
  exit 1
fi

SRC="${HOST_DIR%/}/${FILENAME}"
DEST="${POD}:${CONTAINER_DIR%/}/${FILENAME}"

if [[ ! -f "$SRC" ]]; then
  echo "Error: host file not found: $SRC" >&2
  exit 1
fi

echo "Uploading: $SRC"
echo "To container path: $DEST"
kubectl cp "$SRC" "$DEST" -c "$CONTAINER"
echo "Done."
