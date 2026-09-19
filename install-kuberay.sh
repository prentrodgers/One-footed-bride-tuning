#!/usr/bin/env bash
# install-kuberay.sh — install (or upgrade) the KubeRay operator, which turns
# RayCluster / RayJob manifests into pods.  The tuning grid runs on a
# RayCluster (see k8s-ray-cluster.yaml and ray_ratchet.py) instead of one
# Kubernetes Job per cell.
#
#     ./install-kuberay.sh                # install KUBERAY_VER below
#     KUBERAY_VER=v1.8.0 ./install-kuberay.sh
#
# What this did on 19 Sep 2026 (v1.7.0):
#   - CRDs rayclusters, rayjobs, rayservices, raycronjobs (all ray.io)
#   - the operator Deployment, ServiceAccount, RBAC and Service
#
# Helm is not installed on the WSL box, so this uses the kustomize bundle
# KubeRay publishes in its repo, which kubectl renders natively.  Two things
# about that bundle worth knowing:
#
#   1. It has no namespace of its own.  Everything lands in the kubeconfig's
#      current namespace — `default` here, which is where dropbox-pvc, regcred
#      and the grid-search jobs already live, so a RayCluster in the same
#      namespace mounts the PVC with no cross-namespace copies.  (The Helm
#      chart's README talks about `ray-system`; that is the chart, not this.)
#   2. `kubectl create`, not `apply`: the RayCluster CRD is far larger than
#      the 256 KiB the client-side last-applied annotation allows, and apply
#      fails on it.  On a re-run, create reports AlreadyExists for everything
#      that is unchanged and creates whatever is new; to upgrade the operator
#      image, set the new version and let the Deployment be replaced below.
set -uo pipefail
KUBERAY_VER="${KUBERAY_VER:-v1.7.0}"
BUNDLE="github.com/ray-project/kuberay/ray-operator/config/default?ref=${KUBERAY_VER}&timeout=120s"

echo "== KubeRay ${KUBERAY_VER} into namespace '$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null || echo default)'"
# AlreadyExists lines are expected on a re-run; anything else is a real error.
kubectl create -k "$BUNDLE" 2>&1 | grep -v AlreadyExists || true

# An upgrade: the Deployment exists from an earlier version, so create left it
# alone.  Server-side apply replaces the image without tripping the annotation
# limit (only the CRDs are that large, and their schema seldom changes within
# a minor version).
current=$(kubectl get deploy kuberay-operator -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)
if [ -n "$current" ] && [ "${current##*:}" != "$KUBERAY_VER" ]; then
    echo "== operator is $current — moving to $KUBERAY_VER"
    kubectl kustomize "$BUNDLE" | kubectl apply --server-side --force-conflicts -f -
fi

echo "== waiting for the operator"
kubectl rollout status deploy/kuberay-operator --timeout=300s
echo "== CRDs"
kubectl get crd | grep '\.ray\.io'
echo "== operator"
kubectl get deploy kuberay-operator -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,IMAGE:.spec.template.spec.containers[0].image
echo
echo "Next: kubectl apply -f k8s-ray-cluster.yaml   (needs python-music:0.11, see parallel-jobs/build-image.sh)"
