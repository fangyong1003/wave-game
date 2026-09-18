#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$TASK_ROOT/tools/setup_runtime.sh"
ENGINE_BIN="$TASK_ROOT/.tools/Godot.app/Contents/MacOS/Godot"
CHECK_LOG="$(mktemp -t south-block-tests)"
trap 'rm -f "$CHECK_LOG"' EXIT
run_check() {
  # Godot can report a script parse error with status 0; inspect diagnostics too.
  "$@" 2>&1 | tee "$CHECK_LOG"
  if grep -Eq '^((SCRIPT )?ERROR:|FAIL:)|[1-9][0-9]* failures' "$CHECK_LOG"; then
    return 1
  fi
}
run_check "$ENGINE_BIN" --headless --path "$TASK_ROOT/game" --editor --import
run_check "$ENGINE_BIN" --headless --path "$TASK_ROOT/game" --script "$TASK_ROOT/tests/test_repair_state.gd"
run_check "$ENGINE_BIN" --headless --path "$TASK_ROOT/game" --script "$TASK_ROOT/tests/test_scene.gd"
run_check "$ENGINE_BIN" --headless --path "$TASK_ROOT/game" --script "$TASK_ROOT/tests/test_survival_state.gd"
run_check "$ENGINE_BIN" --headless --path "$TASK_ROOT/game" --script "$TASK_ROOT/tests/test_survival_scene.gd"

run_check "$ENGINE_BIN" --headless --path "$TASK_ROOT/game" --script "$TASK_ROOT/tests/test_survival_search.gd"

run_check "$ENGINE_BIN" --headless --path "$TASK_ROOT/game" --script "$TASK_ROOT/tests/test_east_wing.gd"

run_check "$ENGINE_BIN" --headless --path "$TASK_ROOT/game" --script "$TASK_ROOT/tests/test_district.gd"

run_check "$ENGINE_BIN" --headless --path "$TASK_ROOT/game" --script "$TASK_ROOT/tests/test_ranged.gd"

run_check "$ENGINE_BIN" --headless --path "$TASK_ROOT/game" --script "$TASK_ROOT/tests/test_melee_upgrades.gd"
