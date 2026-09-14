#!/usr/bin/env bash
# ratchet-until-still.sh — keep ratcheting a set of chorales, one pass at a
# time, until none of them improves any more.
#
#     ./ratchet-until-still.sh bwv415 bwv419
#     MAX_ROUNDS=20 PATIENCE=3 TOP=3 INTERVAL=15 ./ratchet-until-still.sh bwv415 bwv419
#
# Each round: take the current report (select_best_and_render.py on the PVC,
# sorted by GapSum), pick each chorale's TOP lowest-GapSum cells, run ONE
# ratchet pass over them (ratchet-passes.sh), take a new report, and compare
# each chorale's best cell. A chorale improved if its best GapSum, gap count,
# p90 or worst gap went down, or its chord average dropped by 0.3 or more
# without GapSum rising. A chorale that has not improved for PATIENCE
# consecutive rounds is retired; the loop ends when none are left or after
# MAX_ROUNDS. The keep-previous ratchet in the tuner keeps whichever result
# is better, so a pass can only hold or improve a cell.
#
# Power: the fleet goes to powersave-gpu once at the start and back to
# balanced at the end (also on interrupt), not on every pass.
set -uo pipefail
[ $# -gt 0 ] || { echo "usage: $0 bwvNNN [bwvNNN ...]" >&2; exit 2; }
MAX_ROUNDS="${MAX_ROUNDS:-20}"; PATIENCE="${PATIENCE:-2}"; TOP="${TOP:-3}"; export INTERVAL="${INTERVAL:-15}"
POD=deploy/one-footed-bride
WORK=${TMPDIR:-/tmp}/ratchet-until-still; mkdir -p "$WORK"
log(){ echo "$(date +%T) $*"; }

report(){   # $1 = output file, rest = chorales
    local out=$1; shift
    kubectl exec "$POD" -c one-footed-bride -- bash -c "cd /home/prent/Repos/One-footed-bride-tuning && \
        python select_best_and_render.py --numpy_dir_root Archive/straw-man --chorale_list $* --suffix='-opt.npy' --sort_by gapsum 2>/dev/null" > "$out"
}

declare -A stall
active=("$@")
./power-save-all.sh | grep -E "all hosts|problems|FAILED|MISMATCH"
trap './power-balanced.sh | grep -E "all hosts|problems"' EXIT

report "$WORK/before.tsv.raw" "${active[@]}"
python3 ratchet_best.py "$WORK/before.tsv.raw" > "$WORK/before.tsv"
log "start: $(cat "$WORK/before.tsv" | awk '{printf "%s sum=%s n=%s p90=%s avg=%s; ", $1, $5, $4, $6, $3}')"

rounds=0
for round in $(seq 1 "$MAX_ROUNDS"); do
    [ ${#active[@]} -gt 0 ] || break
    rounds=$round
    log "===== round $round: ${active[*]}"
    python3 ratchet_best.py "$WORK/before.tsv.raw" --top "$TOP" --cells ratchet-cells.txt >/dev/null
    # only the still-active chorales
    grep -E "^#|$(IFS='|'; echo "${active[*]}")\b" ratchet-cells.txt > "$WORK/cells.txt" && cp "$WORK/cells.txt" ratchet-cells.txt
    CELLS_FILE=ratchet-cells.txt ./generate-grid-search-jobs.sh >/dev/null 2>&1
    RATCHET_POWER=0 PASSES=1 ./ratchet-passes.sh | grep -E "finished|FAILED" | sed 's/^/    /'
    report "$WORK/after.tsv.raw" "${active[@]}"
    python3 ratchet_best.py "$WORK/after.tsv.raw" > "$WORK/after.tsv"
    still=()
    for c in "${active[@]}"; do
        b=$(grep "^$c" "$WORK/before.tsv"); a=$(grep "^$c" "$WORK/after.tsv")
        read -r _ bcell bavg bn bsum bp90 bmx <<<"$b"; read -r _ acell aavg an asum ap90 amx <<<"$a"
        improved=$(python3 -c "print(int($asum < $bsum or $an < $bn or $ap90 < $bp90 or $amx < $bmx or ($aavg <= $bavg - 0.3 and $asum <= $bsum)))")
        if [ "$improved" = 1 ]; then stall[$c]=0; mark="improved"; else stall[$c]=$(( ${stall[$c]:-0} + 1 )); mark="no change (${stall[$c]}/$PATIENCE)"; fi
        printf "    %-7s sum %3s->%-3s n %2s->%-2s p90 %4s->%-4s max %4s->%-4s avg %5s->%-5s %s  %s\n" "$c" "$bsum" "$asum" "$bn" "$an" "$bp90" "$ap90" "$bmx" "$amx" "$bavg" "$aavg" "$acell" "$mark"
        if [ "${stall[$c]}" -lt "$PATIENCE" ]; then still+=("$c"); else log "    $c retired"; fi
    done
    active=("${still[@]}")
    cp "$WORK/after.tsv.raw" "$WORK/before.tsv.raw"; cp "$WORK/after.tsv" "$WORK/before.tsv"
done
log "done after $rounds round(s); final: $(cat "$WORK/before.tsv" | awk '{printf "%s sum=%s n=%s p90=%s avg=%s; ", $1, $5, $4, $6, $3}')"
