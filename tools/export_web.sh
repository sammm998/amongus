#!/usr/bin/env bash
# Exports the Web client into ./web (committed; served by the Docker image).
# Needs Godot 4.7.2 web export templates installed once:
#   ~/.local/share/godot/export_templates/4.7.2.stable/web_nothreads_release.zip
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
cd "$ROOT/game"
"$GODOT" --headless --import >/dev/null 2>&1 || true
rm -rf "$ROOT/web"
mkdir -p "$ROOT/web"
"$GODOT" --headless --export-release "Web" "$ROOT/web/index.html"
test -f "$ROOT/web/index.wasm"
echo "Web build written to $ROOT/web"
