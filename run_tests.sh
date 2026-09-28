#!/usr/bin/env bash
# Runs every automated test headless from one command.
#   ./run_tests.sh          unit tests (gdUnit4) + networking smoke tests
#   ./run_tests.sh --unit   unit tests only
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT_BIN:-godot}"
cd "$ROOT/game"

echo "== Importing project"
timeout 300 "$GODOT" --headless --import >/dev/null 2>&1

echo "== Unit tests (gdUnit4)"
timeout 600 "$GODOT" --headless --path . -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests -rd res://../reports/gdunit -c
UNIT=$?
echo "== Unit tests exit code: $UNIT"

SMOKE=0
if [ "${1:-}" != "--unit" ]; then
  echo "== Networking smoke tests (server + 2 clients)"
  "$ROOT/tools/smoke_net.sh" enet || SMOKE=1
  "$ROOT/tools/smoke_net.sh" ws || SMOKE=1
fi

if [ "$UNIT" -eq 0 ] && [ "$SMOKE" -eq 0 ]; then
  echo "== ALL TESTS PASSED"
  exit 0
fi
echo "== TESTS FAILED (unit=$UNIT smoke=$SMOKE)"
exit 1
