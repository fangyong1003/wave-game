#!/bin/bash
# Portable, project-local macOS runtime; does not modify the system installation.
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE_BIN="$TASK_ROOT/.tools/Godot.app/Contents/MacOS/Godot"
if [[ -x "$ENGINE_BIN" ]]; then exit 0; fi
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo '此启动脚本用于 macOS。其他系统请用 Godot 4.7.2 打开 game/project.godot。' >&2
  exit 1
fi
mkdir -p "$TASK_ROOT/.tools"
echo '正在从 Godot 官方下载 Godot 4.7.2（仅首次需要）…'
curl --fail --location --retry 2 \
  'https://godot-releases.nbg1.your-objectstorage.com/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip' \
  --output "$TASK_ROOT/.tools/godot-4.7.2.zip.part"
unzip -q -o "$TASK_ROOT/.tools/godot-4.7.2.zip.part" -d "$TASK_ROOT/.tools"
test -x "$ENGINE_BIN"
"$ENGINE_BIN" --version
