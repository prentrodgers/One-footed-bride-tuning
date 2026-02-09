#!/bin/bash
# Copy all tolerance results from fedora-d deployment to host

DEPLOYMENT="fedora-app"
REMOTE_BASE="Tutorials/TonicNet/One-footed-bride-tuning/Archive/opt"
LOCAL_BASE="$HOME/TonicNet-results"

# Create local directories
mkdir -p "$LOCAL_BASE"

echo "Copying tolerance directories from app=$DEPLOYMENT deployment..."

for tol in 1 2 3 4; do
  REMOTE_DIR="$REMOTE_BASE/tolerance-$tol"
  LOCAL_DIR="$LOCAL_BASE/tolerance-$tol"
  
  echo ""
  echo "Copying tolerance-$tol..."
  
  # Get a pod from the fedora-app deployment
  POD=$(kubectl get pods -l app=$DEPLOYMENT -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  
  if [ -z "$POD" ]; then
    echo "ERROR: No pod found for $DEPLOYMENT deployment"
    exit 1
  fi
  
  mkdir -p "$LOCAL_DIR"
  kubectl cp "$POD:$REMOTE_DIR/" "$LOCAL_DIR/"
  
  # Verify
  FILE_COUNT=$(ls -1 "$LOCAL_DIR"/*.npy 2>/dev/null | wc -l)
  echo "  ✓ Copied $FILE_COUNT files to $LOCAL_DIR"
done

echo ""
echo "Done! Results in $LOCAL_BASE"
echo ""
echo "Summary:"
for tol in 1 2 3 4; do
  COUNT=$(ls -1 "$LOCAL_BASE/tolerance-$tol"/*.npy 2>/dev/null | wc -l)
  echo "  tolerance-$tol: $COUNT files"
done