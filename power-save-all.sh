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
# Hosts running tuned-ppd (Fedora's default — fs2, fs3, fs9 at least) are
# switched through the desktop power mode instead of tuned-adm: tuned-ppd
# re-applies its own mode at boot and on any mode change, which is how a
# tuned-adm setting on fs3 quietly reverted to balanced. ppd.conf maps
# power-saver to powersave-gpu (installed here if missing); busctl runs as
# root because over ssh there is no polkit agent to authorise it.
#
# Undo with ./power-balanced.sh. Requires passwordless sudo on the nodes.
#
# Usage:  ./power-save-all.sh [--verify] [host ...]
#         (default: all render nodes; --verify only checks, changes nothing)

set -u
VERIFY_ONLY=0
[ "${1:-}" = "--verify" ] && { VERIFY_ONLY=1; shift; }
HOSTS=("$@")
[ ${#HOSTS[@]} -eq 0 ] && HOSTS=(fs2 fs3 fs4 fs5 fs6 fs7 fs8 fs9)   # fs6/fs9 (Ryzen + B580) added 13 Sep 2026
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

SSHN="$SSH -n"      # for calls that must not swallow the caller's stdin

# Per host: active profile, CPU turbo state, then each GPU. The iGPU's
# render GT (gt0) must be at 550; the media GT (gt1) is shown and noted
# if it differs, but does not fail the check. Exits 1 on a mismatch.
read -r -d '' VERIFY <<'EOS'
    ok=1; note=""
    prof=$(tuned-adm active 2>/dev/null | sed "s/Current active profile: //")
    [ "$prof" = powersave-gpu ] || ok=0
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
EOS

# Switch one host. tuned-ppd hosts go through the desktop power mode (see the
# header); the rest through tuned-adm. $1 = seconds to wait for the switch.
apply_host() {
  $SSH "$n" "sudo mkdir -p /etc/tuned/profiles/powersave-gpu &&
        printf '%s' \"\$(cat)\" | sudo tee /etc/tuned/profiles/powersave-gpu/tuned.conf >/dev/null &&
        if systemctl is-active -q tuned-ppd; then
          grep -q '^power-saver=powersave-gpu' /etc/tuned/ppd.conf ||
            { sudo sed -i 's/^power-saver=.*/power-saver=powersave-gpu/' /etc/tuned/ppd.conf && sudo systemctl restart tuned-ppd && sleep 2; }
          timeout $1 sudo busctl set-property org.freedesktop.UPower.PowerProfiles /org/freedesktop/UPower/PowerProfiles org.freedesktop.UPower.PowerProfiles ActiveProfile s power-saver
        else timeout $1 sudo tuned-adm profile powersave-gpu; fi" <<<"$PROFILE"
}

# Did the profile actually take? Polls the verify checks for up to 10 s:
# tuned applies the sysfs settings a moment after the switch returns.
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
    # Two ways a switch goes wrong (Sep 2026). On 26 Sep tuned threw an
    # exception mid-switch on fs7, fs6 and fs4 in turn (FileNotFoundError from
    # its udev monitor, all on daemons that had run for weeks) and tuned-adm
    # waited on it forever or failed. On 29 Sep fs9's switch returned and
    # named the new profile, but tuned never applied its settings (CPU boost
    # on, Arc floor still 1200). Either way restarting tuned clears it, so:
    # a short timeout, a check that the settings really took, and one retry
    # after a restart. A host that still fails is reported, and the verify
    # below shows what state it was left in.
    apply_host 20 && settled && continue
    echo "   $n did not take powersave-gpu; restarting tuned and trying again"
    $SSHN "$n" "timeout 60 sudo systemctl restart tuned && sleep 3 &&
                { ! systemctl is-active -q tuned-ppd || { timeout 60 sudo systemctl restart tuned-ppd && sleep 2; }; }"
    apply_host 60 && settled || { echo "   FAILED to apply on $n"; failed+=("$n"); }
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
echo; echo "all hosts on powersave-gpu"
