set -euxo pipefail
            
# Verify PVC is mounted and accessible
echo "Verifying PVC mount..."
if [ ! -d "/home/prent" ]; then
    echo "ERROR: /home/prent not mounted!"
    exit 1
fi

if [ ! -w "/home/prent" ]; then
    echo "ERROR: /home/prent not writable!"
    exit 1
fi

echo "PVC Storage Status:"
df -h /home/prent

# Function to check disk usage and warn if too full
check_disk_usage() {
    usage_percent=$(df /home/prent | tail -1 | awk '{print int($5)}')
    if [ $usage_percent -gt 90 ]; then
    echo "⚠️  WARNING: Disk usage is ${usage_percent}% - CRITICAL!"
    elif [ $usage_percent -gt 80 ]; then
    echo "⚠️  WARNING: Disk usage is ${usage_percent}% - getting full"
    else
    echo "✓ Disk usage: ${usage_percent}%"
    fi
}

# cd /home/prent/Dropbox/Tutorials/TonicNet/One-footed-bride-tuning

echo "Starting chord tuning optimization (Production - All Tolerance Levels)"


CHORALES="bwv253 bwv254 bwv255 bwv256 bwv257 bwv258 bwv259 bwv260 bwv261 bwv262 bwv263 bwv264"
NUM_RUNS=30 # recommend 30
MAX_PARALLEL=12 # recommend 12
TOLERANCES="1 2 3 4" # recommend "1 2 3 4"
echo "Running $NUM_RUNS iterations at each tolerance level $TOLERANCES"
echo "Working directory: $(pwd)"
echo "PVC mount point: /home/prent"

for tolerance in $TOLERANCES; do
    echo ""
    echo "=========================================="
    echo "TOLERANCE LEVEL $tolerance"
    echo "=========================================="
    
    # Create tolerance directory if missing
    mkdir -p Archive/opt/tolerance-$tolerance
    echo "Data directory: $(pwd)/Archive/opt/tolerance-$tolerance"
    
    for run in $(seq 1 $NUM_RUNS); do
    echo "  Run $run of $NUM_RUNS (tolerance=$tolerance)"
    
    # Launch chorales in parallel
    counter=0
    for c in $CHORALES; do
        python optimize_chords_sa_v2.py --tolerance $tolerance --chorale $c --limit_max 31 &
        counter=$((counter + 1))
        
        # Wait after every MAX_PARALLEL jobs
        if [ $((counter % MAX_PARALLEL)) -eq 0 ]; then
        wait
        fi
    done
    
    # Wait for any remaining jobs
    wait
    
    # Sync to disk after each run to prevent data loss on OOM kill
    sync
    
    # Report files saved and disk usage
    file_count=$(find Archive/opt/tolerance-$tolerance -name "*-sa-opt.npy" -type f | wc -l)
    echo "    Files saved so far: $file_count"
    check_disk_usage
    done
    
    echo "Tolerance $tolerance complete - $NUM_RUNS runs finished"
done

echo ""
echo "=========================================="
echo "Applying horizontal adjustments to saved files"
echo "=========================================="

for tolerance in $TOLERANCES; do
    echo "Processing tolerance-$tolerance..."
    for c in $CHORALES; do
    if [ -f "Archive/opt/tolerance-$tolerance/$c-sa-opt.npy" ]; then
        python horizontal_transpose.py --destination Archive/opt/tolerance-$tolerance/$c-trans-sa-opt.npy Archive/opt/tolerance-$tolerance/$c-sa-opt.npy --log-level DEBUG
    fi
    done
    file_count=$(find Archive/opt/tolerance-$tolerance -name "*-trans-sa-opt.npy" -type f | wc -l)
    echo "  Tolerance-$tolerance: $file_count transposed files saved"
done

# Final sync
sync

echo ""
echo "=========================================="
echo "All optimization complete!"
echo "Results saved in Archive/opt/tolerance-{1,2,3,4}/"
echo "=========================================="

# List all saved files
echo ""
echo "Summary of saved files:"
for tolerance in $TOLERANCES; do
    opt_count=$(find Archive/opt/tolerance-$tolerance -name "*-sa-opt.npy" -type f | wc -l)
    trans_count=$(find Archive/opt/tolerance-$tolerance -name "*-trans-sa-opt.npy" -type f | wc -l)
    echo "  tolerance-$tolerance: $opt_count optimized, $trans_count transposed"
done