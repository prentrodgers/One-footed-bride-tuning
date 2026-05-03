#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-default}"

kubectl -n "$NAMESPACE" port-forward svc/one-footed-bride-ssh 2222:22
