# Traitor Island — Railway / Docker image.
# Serves the Web client over HTTP and runs the dedicated game server
# (WebSocket) behind the same public port: / -> web build, /ws -> game server.

ARG GODOT_VERSION=4.7.2

FROM ubuntu:24.04 AS build
ARG GODOT_VERSION
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /tmp/godot
RUN curl -fsSL -o godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
 && unzip -q godot.zip \
 && mv "Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
 && rm godot.zip
# Only the web (no threads) templates are needed; they come inside the full template archive.
RUN curl -fsSL -o templates.tpz "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" \
 && mkdir -p "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" \
 && unzip -q -j templates.tpz templates/web_nothreads_release.zip templates/web_nothreads_debug.zip templates/version.txt \
      -d "/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" \
 && rm templates.tpz
COPY game /src/game
WORKDIR /src/game
RUN godot --headless --import >/dev/null 2>&1 || true
RUN mkdir -p /out/web \
 && godot --headless --export-release "Web" /out/web/index.html \
 && test -f /out/web/index.wasm

FROM caddy:2 AS caddy

FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates libfontconfig1 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=caddy /usr/bin/caddy /usr/local/bin/caddy
COPY --from=build /usr/local/bin/godot /usr/local/bin/godot
COPY --from=build /src/game /app/game
COPY --from=build /out/web /app/web
COPY deploy/Caddyfile /app/Caddyfile
COPY deploy/start.sh /app/start.sh
RUN chmod +x /app/start.sh
ENV PORT=8080
EXPOSE 8080
CMD ["/app/start.sh"]
