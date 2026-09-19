#!/usr/bin/env bash
# build-image.sh — build quay.io/prentrodgers/python-music:<tag> on fs2.
#
#     parallel-jobs/build-image.sh 0.11
#     BUILD_HOST=fs3 parallel-jobs/build-image.sh 0.11
#
# Run from the workstation; the build itself happens over ssh on BUILD_HOST
# (fs2), which is where podman and the 384 MB Blender tarball the
# Containerfile COPYs live (parallel-jobs/blender-*.tar.xz is gitignored, so it
# is not in any checkout — fetch it once onto the build host).
#
# The Containerfile is piped over stdin (`podman build -f -`) with fs2's
# checkout as the build context.  That way the Containerfile you just edited
# here is what gets built, without pushing first or dirtying fs2's tree — the
# context only supplies the COPY sources: the Blender tarball, requirements.txt
# and entrypoint.sh, so a change to one of THOSE does need to reach fs2 (git
# pull there) before this runs.
#
# The push is not automated.  fs2 has no quay login and it should stay that
# way; when the build finishes:
#
#     ssh fs2 podman login quay.io
#     ssh fs2 podman push quay.io/prentrodgers/python-music:<tag>
#
# then bump the pins that should follow: k8s-grid-search-job-template.yaml,
# k8s-ray-cluster.yaml, one-footed-bride-jupyter.yaml, render_farm.sh.
set -euo pipefail
TAG="${1:?usage: $0 <tag>   e.g. 0.11}"
BUILD_HOST="${BUILD_HOST:-fs2}"
IMAGE="quay.io/prentrodgers/python-music:${TAG}"
CONTEXT='~/Repos/One-footed-bride-tuning/parallel-jobs'
HERE=$(cd "$(dirname "$0")" && pwd)

echo "== $IMAGE on $BUILD_HOST, context $CONTEXT"
ssh "$BUILD_HOST" "ls $CONTEXT/blender-*-linux-x64.tar.xz $CONTEXT/requirements.txt $CONTEXT/entrypoint.sh" \
    || { echo "build context on $BUILD_HOST is missing a COPY source (see header)" >&2; exit 1; }

# The log stays on the build host next to the context so a dropped ssh
# session does not lose it.
ssh "$BUILD_HOST" "cd $CONTEXT && podman build -f - -t $IMAGE . 2>&1 | tee build-${TAG}.log | tail -n 40" \
    < "$HERE/Containerfile"

echo
echo "== built"
ssh "$BUILD_HOST" "podman images --format '{{.Repository}}:{{.Tag}}  {{.Size}}  {{.Created}}' | grep python-music"
echo
echo "smoke test:  ssh $BUILD_HOST podman run --rm $IMAGE python -c 'import ray, music21, numpy; print(ray.__version__)'"
echo "push:        ssh $BUILD_HOST podman login quay.io; ssh $BUILD_HOST podman push $IMAGE"
