#!/usr/bin/env bash
CHORALES="bwv253 bwv254 bwv255 bwv256 bwv257 bwv258 bwv259 bwv260 bwv261 bwv262 bwv263 bwv264"
python select_best_and_render.py --numpy_dir_root Archive/straw-man --chorale_list $CHORALES --spread_weight 0.5 \
  | grep -E "Chorale|BEST" \
  | awk '
      BEGIN { printf "%-8s %-26s %4s %6s %5s %5s %7s %9s\n",
                     "Chorale","Directory","lm","Mean","Max","MaxCh","Spread","Combined" }
      /^Chorale:/ { match($0, /bwv[0-9]+/); chorale = substr($0, RSTART, RLENGTH); next }
      /BEST/      { gsub(/^[[:space:]]+/, "")
                    printf "%-8s %-26s %4s %6s %5s %5s %7s %9s <-- BEST\n",
                           chorale, $1, $2, $3, $4, $5, $6, $7 }
    '