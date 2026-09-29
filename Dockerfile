# Traitor Island — Railway / Docker image.
# Serves the prebuilt Web client (web/, exported with tools/export_web.sh) and
# runs the dedicated game server (WebSocket) behind the same public port:
#   /        -> web client
#   /ws      -> game server
#   /healthz -> health check
# Only the Godot binary (~75 MB) is downloaded at build time.

ARG GODOT_VERSION=4.7.2

FROM ubuntu:24.04 AS godot
ARG GODOT_VERSION
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL --retry 5 -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
 && unzip -q /tmp/godot.zip -d /tmp \
 && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
 && chmod +x /usr/local/bin/godot \
 && rm /tmp/godot.zip

FROM caddy:2 AS caddy

FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates libfontconfig1 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=godot /usr/local/bin/godot /usr/local/bin/godot
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY game /app/game
# Import once at build time so the server starts fast.
RUN cd /app/game && (godot --headless --import >/dev/null 2>&1 || true)
COPY web /app/web
COPY deploy/Caddyfile /app/Caddyfile
COPY deploy/start.sh /app/start.sh
RUN chmod +x /app/start.sh
ENV PORT=8080
EXPOSE 8080
CMD ["/app/start.sh"]
