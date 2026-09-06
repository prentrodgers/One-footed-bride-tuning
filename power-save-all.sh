#!/usr/bin/env bash
# power-save-all.sh — put every render node on the powersave-gpu tuned
# profile and verify it took.
#
# powersave-gpu = tuned's stock powersave (CPU turbo off, powersave
# governor, energy_perf_bias=powersave) plus:
#   - each Intel iGPU (i915) capped at its efficient clock, 550 MHz on all
#     the Core Ultra parts here, instead of its 1900/2000 MHz turbo ceiling
#   - each Arc Pro B50/B70 (xe) allowed to idle down to its 400 MHz
#     efficient clock instead of the driver's 1200 MHz floor; their turbo
#     ceiling is left alone so Cycles throughput is unchanged
#
# The iGPU has two GTs: gt0 renders (the one Blender uses), gt1 is the
# media engine. The cap is written per GT through card*/gt/gt*/ rather
# than the legacy card*/gt_max_freq_mhz, which fans out to both GTs and
# reports the max across them — so one GT refusing the write (fs4's gt1
# GuC firmware was wedged on 6 Sep 2026) made the legacy file read 1400
# although the render GT was capped. Verification checks gt0 strictly and
# only reports gt1.
#
# The sysfs globs are what make one profile fit every host: only the iGPU
# has gt/gt*/rps_*_freq_mhz files and only the Arc cards have
# tile0/gt0/freq0, so the card numbering (which differs per host and
# reorders on fs5 after a reboot) does not matter.
#
# Undo with ./power-balanced.sh. Requires passwordless sudo on the nodes.
#
# Usage:  ./power-save-all.sh [--verify] [host ...]
#         (default: all render nodes; --verify only checks, changes nothing)

set -u
VERIFY_ONLY=0
[ "${1:-}" = "--verify" ] && { VERIFY_ONLY=1; shift; }
HOSTS=("$@")
[ ${#HOSTS[@]} -eq 0 ] && HOSTS=(fs2 fs3 fs4 fs5 fs7 fs8)
SSH="ssh -o BatchMode=yes -o ConnectTimeout=5"

PROFILE='[main]
summary=powersave plus iGPU capped at its efficient clock and Arc floor lowered
include=powersave

[igpu]
type=sysfs
/sys/class/drm/card*/gt/gt*/rps_max_freq_mhz=550
/sys/class/drm/card*/gt/gt*/rps_boost_freq_mhz=550

[arc]
type=sysfs
/sys/class/drm/card*/device/tile0/gt0/freq0/min_freq=400
'

failed=()
if [ $VERIFY_ONLY = 0 ]; then
  for n in "${HOSTS[@]}"; do
    echo "== $n"
    if ! $SSH "$n" "sudo mkdir -p /etc/tuned/profiles/powersave-gpu &&
          printf '%s' \"\$(cat)\" | sudo tee /etc/tuned/profiles/powersave-gpu/tuned.conf >/dev/null &&
          sudo tuned-adm profile powersave-gpu" <<<"$PROFILE"; then
      echo "   FAILED to apply on $n"; failed+=("$n"); continue
    fi
  done
  echo
fi

echo "== verify"
# Per host: active profile, CPU turbo state, then each GPU. The iGPU's
# render GT (gt0) must be at 550; the media GT (gt1) is shown and noted
# if it differs, but does not fail the check.
for n in "${HOSTS[@]}"; do
  $SSH "$n" '
    ok=1; note=""
    prof=$(tuned-adm active 2>/dev/null | sed "s/Current active profile: //")
    [ "$prof" = powersave-gpu ] || ok=0
    nt=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null)
    [ "$nt" = 1 ] || ok=0
    printf "%-4s profile=%-14s no_turbo=%s" "$(hostname)" "$prof" "${nt:-?}"
    for d in /sys/class/drm/card[0-9]; do
      if [ -d $d/gt/gt0 ]; then
        g=$d/gt/gt0; mx=$(cat $g/rps_max_freq_mhz); bo=$(cat $g/rps_boost_freq_mhz)
        printf "  iGPU(%s) gt0 max=%s boost=%s" "$(basename $d)" "$mx" "$bo"
        [ "$mx" = 550 ] && [ "$bo" = 550 ] || ok=0
        if [ -d $d/gt/gt1 ]; then
          m1=$(cat $d/gt/gt1/rps_max_freq_mhz); printf " gt1 max=%s" "$m1"
          [ "$m1" = 550 ] || note=" (media GT not capped: its GuC refused the write, see dmesg)"
        fi
      elif [ -e $d/device/tile0/gt0/freq0/min_freq ]; then
        f=$d/device/tile0/gt0/freq0
        printf "  Arc(%s) min=%s max=%s" "$(basename $d)" "$(cat $f/min_freq)" "$(cat $f/max_freq)"
        [ "$(cat $f/min_freq)" = 400 ] || ok=0
      fi
    done
    [ $ok = 1 ] && echo "   OK$note" || { echo "   MISMATCH$note"; exit 1; }
  ' || failed+=("$n")
done

if [ ${#failed[@]} -gt 0 ]; then
  echo; echo "problems on: ${failed[*]}"; exit 1
fi
echo; echo "all hosts on powersave-gpu"
