#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
bash "$TASK_ROOT/tools/setup_runtime.sh"
ENGINE_BIN="$TASK_ROOT/.tools/Godot.app/Contents/MacOS/Godot"
if ! "$ENGINE_BIN" --headless --path "$TASK_ROOT/game" --editor --import > "$TASK_ROOT/.tools/launch-import.log" 2>&1; then
  cat "$TASK_ROOT/.tools/launch-import.log"
  exit 1
fi
exec "$ENGINE_BIN" --path "$TASK_ROOT/game" "$@"
