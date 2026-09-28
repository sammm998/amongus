#!/usr/bin/env bash
# Starts a headless dedicated server and two headless clients as separate
# processes and checks both clients see a roster of 2 players.
# Usage: tools/smoke_net.sh [enet|ws]
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
TRANSPORT="${1:-enet}"
PORT=$((24700 + RANDOM % 200))
LOG_DIR="$(mktemp -d)"
cd "$ROOT/game"

timeout 40 "$GODOT" --headless -- --server --port "$PORT" --transport "$TRANSPORT" --quit-after 20 >"$LOG_DIR/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 50); do
  grep -q SERVER_READY "$LOG_DIR/server.log" 2>/dev/null && break
  sleep 0.2
done

timeout 30 "$GODOT" --headless -- --connect 127.0.0.1 --port "$PORT" --transport "$TRANSPORT" --name Alice --profile smoke_a \
  --backend-dir "$LOG_DIR/backend_a" --expect-roster 2 --quit-after 15 >"$LOG_DIR/client_a.log" 2>&1 &
A_PID=$!
timeout 30 "$GODOT" --headless -- --connect 127.0.0.1 --port "$PORT" --transport "$TRANSPORT" --name Bob --profile smoke_b \
  --backend-dir "$LOG_DIR/backend_b" --expect-roster 2 --quit-after 15 >"$LOG_DIR/client_b.log" 2>&1 &
B_PID=$!

wait $A_PID; A=$?
wait $B_PID; B=$?
kill $SERVER_PID 2>/dev/null; wait $SERVER_PID 2>/dev/null

JOINED=$(grep -c SERVER_CLIENT_JOINED "$LOG_DIR/server.log")
echo "[smoke:$TRANSPORT] server joins=$JOINED client_a=$A client_b=$B"
grep -h -E "CLIENT_ROSTER_OK|CLIENT_TIMEOUT" "$LOG_DIR"/client_*.log | sed 's/^/  /'
if [ "$A" -eq 0 ] && [ "$B" -eq 0 ] && [ "$JOINED" -ge 2 ]; then
  echo "[smoke:$TRANSPORT] PASS"
  rm -rf "$LOG_DIR"
  exit 0
fi
echo "[smoke:$TRANSPORT] FAIL — logs in $LOG_DIR"
tail -n 20 "$LOG_DIR"/*.log
exit 1
