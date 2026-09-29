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
[ ${#HOSTS[@]} -eq 0 ] && HOSTS=(fs2 fs3 fs4 fs5 fs6 fs7 fs8 fs9)   # fs6/fs9 (Ryzen + B580) added 13 Sep 2026
SSH="ssh -o BatchMode=yes -o ConnectTimeout=5"

SSHN="$SSH -n"      # never swallow the caller's stdin

# Per host: profile, CPU turbo, and each GPU back at its hardware default
# (iGPU gt0 max = its RP0, Arc min = 1200). Exits 1 on a mismatch.
read -r -d '' VERIFY <<'EOS'
    ok=1
    prof=$(tuned-adm active 2>/dev/null | sed "s/Current active profile: //")
    [ "$prof" = balanced ] || ok=0
    # turbo state, normalised to no_turbo terms (1 = off): intel_pstate
    # exposes no_turbo; the Ryzens on fs6/fs9 (amd-pstate, active mode)
    # take tuned's boost=0 in the PER-POLICY cpu*/cpufreq/boost files —
    # the global cpufreq/boost stays 1 there and means nothing.
    if [ -e /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
      nt=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)
    elif [ -e /sys/devices/system/cpu/cpu0/cpufreq/boost ]; then
      nt=$(( 1 - $(cat /sys/devices/system/cpu/cpu0/cpufreq/boost) ))
    elif [ -e /sys/devices/system/cpu/cpufreq/boost ]; then
      nt=$(( 1 - $(cat /sys/devices/system/cpu/cpufreq/boost) ))
    else
      nt=""
    fi
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
EOS

# A host running tuned-ppd (fs2, KDE) is switched through its desktop
# power mode, which ppd.conf maps onto the tuned profile — a tuned-adm
# call there would be undone at the next mode change. $1 = timeout, s.
apply_host() {
  $SSHN "$n" "if systemctl is-active -q tuned-ppd; then
            timeout $1 sudo busctl set-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile s balanced
          else timeout $1 sudo tuned-adm profile balanced; fi"
}

# Did it take? Polls the verify checks for up to 10 s.
settled() {
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    $SSHN "$n" "$VERIFY" >/dev/null 2>&1 && return 0
    sleep 1
  done
  return 1
}

failed=()
if [ $VERIFY_ONLY = 0 ]; then
  for n in "${HOSTS[@]}"; do
    echo "== $n"
    # tuned has been stalling or half-applying profile switches: an exception
    # from its udev monitor mid-switch on fs7, fs6 and fs4 (26 Sep 2026), and
    # a switch on fs9 that named the profile without applying it (29 Sep).
    # Restarting tuned clears both, so do that once before reporting FAILED
    # (see power-save-all.sh).
    apply_host 20 && settled && continue
    echo "   $n did not take balanced; restarting tuned and trying again"
    $SSHN "$n" "timeout 60 sudo systemctl restart tuned && sleep 3 &&
                { ! systemctl is-active -q tuned-ppd || { timeout 60 sudo systemctl restart tuned-ppd && sleep 2; }; }"
    apply_host 60 && settled || { echo "   FAILED on $n"; failed+=("$n"); }
  done
  echo
fi

echo "== verify"
for n in "${HOSTS[@]}"; do
  $SSHN "$n" "$VERIFY" || failed+=("$n")
done
readarray -t failed < <(printf '%s\n' "${failed[@]}" | awk 'NF && !seen[$0]++')

if [ ${#failed[@]} -gt 0 ]; then
  echo; echo "problems on: ${failed[*]}"; exit 1
fi
echo; echo "all hosts on balanced"
