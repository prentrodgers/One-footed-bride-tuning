#!/usr/bin/env bash
# power-balanced.sh — put every render node back on tuned's stock balanced
# profile (undoing ./power-save-all.sh) and verify it took.
#
# tuned restores what it changed when the profile switches, so the iGPU
# render GT's ceiling returns to its turbo maximum (RP0: 1900 or 2000 MHz
# by SKU), the Arc cards' floor returns to the xe driver's 1200 MHz, and
# CPU turbo is re-enabled. The powersave-gpu profile file is left
# installed so power-save-all.sh can switch back without rewriting it.
#
# Usage:  ./power-balanced.sh [--verify] [host ...]
#         (default: all render nodes; --verify only checks, changes nothing)

set -u
VERIFY_ONLY=0
[ "${1:-}" = "--verify" ] && { VERIFY_ONLY=1; shift; }
HOSTS=("$@")
[ ${#HOSTS[@]} -eq 0 ] && HOSTS=(fs2 fs3 fs4 fs5 fs7 fs8)
SSH="ssh -o BatchMode=yes -o ConnectTimeout=5"

failed=()
if [ $VERIFY_ONLY = 0 ]; then
  for n in "${HOSTS[@]}"; do
    echo "== $n"
    $SSH "$n" "sudo tuned-adm profile balanced" || { echo "   FAILED on $n"; failed+=("$n"); }
  done
  echo
fi

echo "== verify"
# Per host: profile, CPU turbo, and each GPU back at its hardware default
# (iGPU gt0 max = its RP0, Arc min = 1200).
for n in "${HOSTS[@]}"; do
  $SSH "$n" '
    ok=1
    prof=$(tuned-adm active 2>/dev/null | sed "s/Current active profile: //")
    [ "$prof" = balanced ] || ok=0
    nt=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null)
    [ "$nt" = 0 ] || ok=0
    printf "%-4s profile=%-14s no_turbo=%s" "$(hostname)" "$prof" "${nt:-?}"
    for d in /sys/class/drm/card[0-9]; do
      if [ -d $d/gt/gt0 ]; then
        g=$d/gt/gt0; mx=$(cat $g/rps_max_freq_mhz); rp0=$(cat $g/rps_RP0_freq_mhz)
        printf "  iGPU(%s) gt0 max=%s/RP0=%s" "$(basename $d)" "$mx" "$rp0"
        [ "$mx" = "$rp0" ] || ok=0
      elif [ -e $d/device/tile0/gt0/freq0/min_freq ]; then
        f=$d/device/tile0/gt0/freq0
        printf "  Arc(%s) min=%s max=%s" "$(basename $d)" "$(cat $f/min_freq)" "$(cat $f/max_freq)"
        [ "$(cat $f/min_freq)" = 1200 ] || ok=0
      fi
    done
    [ $ok = 1 ] && echo "   OK" || { echo "   MISMATCH"; exit 1; }
  ' || failed+=("$n")
done

if [ ${#failed[@]} -gt 0 ]; then
  echo; echo "problems on: ${failed[*]}"; exit 1
fi
echo; echo "all hosts on balanced"
