#!/bin/bash
# Runs the headless feel tests. Exits non-zero if any test fails.
set -uo pipefail
GODOT="${GODOT:-$HOME/.local/bin/godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --fixed-fps 60 --path . -s res://tests/run_tests.gd 2>&1 | grep -E "^(PASS|FAIL)|failed|SCRIPT ERROR|ERROR"
exit "${PIPESTATUS[0]}"
