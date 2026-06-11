#!/usr/bin/env bash
# run_tests.sh — runs the headless regression suite (one Godot process; autoloads load once).
# Exits non-zero if any assertion failed, so /shipit and CI can gate on it.
#   GODOT=/path/to/Godot ./tests/run_tests.sh
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"   # game-client/ (the Godot project root)
cd "$HERE"

if [[ ! -x "$GODOT" ]]; then
  echo "Godot not found at '$GODOT' — set GODOT=/path/to/Godot" >&2
  exit 2
fi

"$GODOT" --headless --import >/dev/null 2>&1 || true

# --quit-after is a hang safety-net; tests quit themselves with the right exit code first.
out="$("$GODOT" --headless --fixed-fps 60 --quit-after 3000 res://tests/TestRunner.tscn 2>&1)" && code=0 || code=$?

# Show the per-test lines + summary + any GDScript errors.
echo "$out" | grep -E "^(===|  [✓✗]|SUITE:| {4}✗)|SCRIPT ERROR|Parse Error" || true

# A clean run prints "SUITE: PASS" and exits 0; anything else is a failure.
if echo "$out" | grep -q "^SUITE: PASS" && [[ "$code" -eq 0 ]]; then
  exit 0
fi
echo "run_tests.sh: FAILED (exit $code)" >&2
exit 1
