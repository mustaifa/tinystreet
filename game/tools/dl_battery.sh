#!/bin/bash
# Delivery Logic real-input QA battery. Each scenario gets its own fresh save.
#   game/tools/dl_battery.sh OUT_DIR [V7_SAVE]
# V7_SAVE (optional): a save written by the v7 build, for dl_migrated.
# Results: OUT_DIR/summary.txt
set -u
cd "$(dirname "$0")/.."
G=${GODOT:-~/tools/godot/godot}
OUT=$(realpath -m "$1"); V7=${2:-}
mkdir -p "$OUT"
run() {  # name scenario resolution [extra args...]
  local n=$1 s=$2 res=$3; shift 3
  local save="$OUT/$n.save.json"
  case $n in life_b) save="$OUT/life_a.save.json";; *) rm -f "$save" "$save".*;; esac
  if [[ $s == dl_migrated ]]; then cp "$V7" "$save"; fi
  timeout 2400 xvfb-run -a "$G" --path . --rendering-driver opengl3 --resolution "$res" -- \
    --save-path="$save" --qa="$s" --qa-out="$OUT/$n" "$@" > "$OUT/$n.log" 2>&1
  echo "$n exit=$? pass=$(grep -c 'QA: PASS' "$OUT/$n.log") fail=$(grep -c 'QA: FAIL' "$OUT/$n.log") script_errors=$(grep -c 'SCRIPT ERROR' "$OUT/$n.log")" | tee -a "$OUT/summary.txt"
}
run journey dl_journey 720x1280
run journey_ar_small_large dl_journey 480x800 --qa-lang=ar --qa-large-text
run journey_reduced_motion dl_journey 720x1280 --qa-reduced-motion
run life_a dl_life_a 720x1280
run life_b dl_life_b 720x1280
run rapid dl_rapid 720x1280
run evidence dl_evidence 720x1280
[ -n "$V7" ] && run migrated dl_migrated 720x1280
run look dl_look 720x1280
run look_ar dl_look 720x1280 --qa-lang=ar
