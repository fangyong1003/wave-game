#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BLENDER_EXECUTABLE="${BLENDER_EXECUTABLE:-/Applications/Blender.app/Contents/MacOS/Blender}"
"$BLENDER_EXECUTABLE" --background --python "$TASK_ROOT/tools/build_apartment.py"
"$BLENDER_EXECUTABLE" --background --python "$TASK_ROOT/tools/build_tools.py"
"$BLENDER_EXECUTABLE" --background --python "$TASK_ROOT/tools/build_survival_assets.py"
"$BLENDER_EXECUTABLE" --background --python "$TASK_ROOT/tools/import_zombie.py"
"$BLENDER_EXECUTABLE" --background --python "$TASK_ROOT/tools/build_district.py"
"$BLENDER_EXECUTABLE" --background --python "$TASK_ROOT/tools/build_ranged_assets.py"
"$BLENDER_EXECUTABLE" --background --disable-autoexec --python "$TASK_ROOT/tools/import_hands.py"
python3 "$TASK_ROOT/tools/build_audio.py"
