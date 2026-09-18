#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")" && pwd)"
bash "$TASK_ROOT/tools/setup_runtime.sh"
exec "$TASK_ROOT/.tools/Godot.app/Contents/MacOS/Godot" --path "$TASK_ROOT/game" --editor
