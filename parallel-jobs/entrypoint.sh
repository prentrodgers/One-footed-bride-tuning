#!/usr/bin/env bash
set -euo pipefail

INDEX="${JOB_COMPLETION_INDEX:-0}"

if [[ -z "${ARG_LIST_FILE:-}" ]]; then
  echo "ARG_LIST_FILE not set — starting interactive shell..."
  exec /bin/bash
fi

if [[ ! -f "${ARG_LIST_FILE}" ]]; then
  echo "ARG_LIST_FILE not found: ${ARG_LIST_FILE} — starting interactive shell..."
  exec /bin/bash
fi

# Get the Nth line (1-based) for this pod
LINE="$(sed -n "$((INDEX + 1))p" "${ARG_LIST_FILE}" || true)"

if [[ -z "${LINE}" ]]; then
  echo "No argument line for index ${INDEX} — starting interactive shell..."
  exec /bin/bash
fi

echo "Pod index ${INDEX} running: python ${SCRIPT_PATH} ${LINE}"

# Keep NumPy/SciPy single-threaded
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"

exec python "${SCRIPT_PATH}" ${LINE}
