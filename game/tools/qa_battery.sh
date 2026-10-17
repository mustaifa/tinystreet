#!/bin/bash
# Full UI QA battery. Every scenario gets its own fresh save file, because the
# scenarios assume a new player (rewards paid once, tasks unclaimed, ...).
#   game/tools/qa_battery.sh OUT_DIR [scenario ...]
# Default scenarios: the whole battery. Results: OUT_DIR/summary.txt
# Exception: player_reopen relaunches on the save that `player` left behind
# (close/reopen after wins), so it must run after `player`.
set -u
cd "$(dirname "$0")/.."
G=${GODOT:-~/tools/godot/godot}
OUT=$(realpath -m "$1"); shift
mkdir -p "$OUT"
SCEN=("$@")
[ ${#SCEN[@]} -eq 0 ] && SCEN=(player player_reopen finale play=1-48 play=49-96 slice v3 v2 nav rewards rapid ledger layouts tour tour:ar)
for s in "${SCEN[@]}"; do
  n=${s//[=:]/_}
  save="$OUT/$n.save.json"
  qa_out="$OUT/$n"
  if [[ $s == player_reopen ]]; then
    save="$OUT/player.save.json"; qa_out="$OUT/player"
  else
    rm -f "$save" "$save".*
  fi
  extra=()
  q=$s
  if [[ $s == *:ar ]]; then q=${s%:ar}; extra=(--qa-lang=ar); fi
  timeout 1500 xvfb-run -a "$G" --path . --rendering-driver opengl3 --resolution 720x1280 -- \
    --save-path="$save" --qa="$q" "${extra[@]}" --qa-out="$qa_out" > "$OUT/$n.log" 2>&1
  code=$?
  echo "$s exit=$code pass=$(grep -c 'QA: PASS' "$OUT/$n.log") fail=$(grep -c 'QA: FAIL' "$OUT/$n.log") script_errors=$(grep -c 'SCRIPT ERROR' "$OUT/$n.log") $(grep -E '^QA: play .* won=' "$OUT/$n.log")" | tee -a "$OUT/summary.txt"
done
