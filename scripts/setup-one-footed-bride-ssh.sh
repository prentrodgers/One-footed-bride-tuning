#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-default}"
PUBKEY_FILE="${2:-$HOME/.ssh/id_ed25519.pub}"

if [[ ! -f "$PUBKEY_FILE" ]]; then
  echo "Public key not found: $PUBKEY_FILE" >&2
  exit 1
fi

kubectl -n "$NAMESPACE" create secret generic one-footed-bride-ssh-authorized-keys \
  --from-file=authorized_keys="$PUBKEY_FILE" \
  --dry-run=client -o yaml | kubectl -n "$NAMESPACE" apply -f -

kubectl -n "$NAMESPACE" apply -f one-footed-bride-jupyter.yaml
kubectl -n "$NAMESPACE" rollout status deployment/one-footed-bride

echo "SSH sidecar is ready. Start forwarding with:"
echo "  scripts/port-forward-one-footed-bride-ssh.sh $NAMESPACE"
