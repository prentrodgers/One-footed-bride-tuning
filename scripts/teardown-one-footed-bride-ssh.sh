#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-default}"

kubectl -n "$NAMESPACE" delete service one-footed-bride-ssh --ignore-not-found
kubectl -n "$NAMESPACE" delete secret one-footed-bride-ssh-authorized-keys --ignore-not-found
kubectl -n "$NAMESPACE" delete configmap one-footed-bride-sshd-config --ignore-not-found
kubectl -n "$NAMESPACE" patch deployment one-footed-bride --type='strategic' -p='{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "pod-ssh",
            "$patch": "delete"
          }
        ],
        "volumes": [
          {
            "name": "ssh-authorized-keys",
            "$patch": "delete"
          },
          {
            "name": "sshd-config",
            "$patch": "delete"
          }
        ]
      }
    }
  }
}' || true

kubectl -n "$NAMESPACE" rollout restart deployment/one-footed-bride
