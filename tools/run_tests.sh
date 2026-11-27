#!/bin/bash
# Run every headless test suite and print one summary table. Exit 1 if any suite fails.
# usage: bash tools/run_tests.sh            all suites, in parallel (fast)
#        bash tools/run_tests.sh rules df   only these suites (names below)
#        SERIAL=1 bash tools/run_tests.sh   one at a time (cleaner timings)
#        CI=1 bash tools/run_tests.sh       only the CI gate (rules, df, touch)
# Logs: build/test-logs/<name>.log  (look there when a suite fails)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="$(command -v godot || echo "$HOME/godot/godot")"
# name | scene | quit-after | pass pattern
SUITES="rules|test_runner|30000|passed, 0 failed
df|dogfight_test|20000|passed, 0 failed
touch|touch_test|6000|passed, 0 failed
ui|ui_smoke|8000|ALL PASSED
cards|cards_test|8000|passed, 0 failed
pool|pool_test|8000|passed, 0 failed
chal|challenges_test|8000|passed, 0 failed
holdem|holdem_test|8000|passed, 0 failed"
[ -n "${CI:-}" ] && SUITES="$(echo "$SUITES" | grep -E '^(rules|df|touch)\|')"
if [ $# -gt 0 ]; then
  pat="^($(IFS='|'; echo "$*"))\|"
  SUITES="$(echo "$SUITES" | grep -E "$pat")"
  [ -z "$SUITES" ] && { echo "no suite matches: $*"; exit 2; }
fi
[ -d .godot ] || "$GODOT" --headless --path . --import >/dev/null 2>&1
L=build/test-logs; mkdir -p "$L"
run() {  # name scene quit
  local t0=$SECONDS
  timeout 120 "$GODOT" --headless --path . "res://tests/$2.tscn" --quit-after "$3" -- --fresh >"$L/$1.log" 2>&1
  echo $((SECONDS - t0)) >"$L/$1.time"
}
while IFS='|' read -r n s q p; do
  if [ -n "${SERIAL:-}" ]; then run "$n" "$s" "$q"; else run "$n" "$s" "$q" & fi
done <<<"$SUITES"
wait
fail=0
printf '%-7s %-5s %5s  %s\n' SUITE OK SEC RESULT
while IFS='|' read -r n s q p; do
  res="$(grep -hoE '[0-9]+ passed, [0-9]+ failed|ALL PASSED' "$L/$n.log" | tail -1)"
  if grep -q "$p" "$L/$n.log" && ! grep -q "SCRIPT ERROR: Parse Error" "$L/$n.log"; then ok=PASS; else ok=FAIL; fail=1; fi
  printf '%-7s %-5s %5s  %s\n' "$n" "$ok" "$(cat "$L/$n.time")" "${res:-no result line (see $L/$n.log)}"
done <<<"$SUITES"
[ $fail -eq 0 ] && echo "ALL SUITES PASSED" || echo "SOME SUITES FAILED"
exit $fail
