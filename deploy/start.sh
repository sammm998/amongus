#!/bin/sh
# Starts the dedicated game server (WebSocket, internal port 8081) and Caddy on $PORT.
set -e
cd /app/game
godot --headless -- --server --transport ws --port 8081 &
exec caddy run --config /app/Caddyfile --adapter caddyfile
