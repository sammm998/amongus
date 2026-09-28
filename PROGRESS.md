# PROGRESS

## Current milestone: M0 — Foundation ✅ complete (next: M1 — Look development)

### M0 plan
1. Repo docs: `GAME_SPEC.md`, `CLAUDE.md`, `PROGRESS.md`, `ASSETS.md`; reference image at `docs/art/reference.png`.
2. Godot 4.7.2 project in `/game` with the spec folder layout; gdUnit4 installed; `run_tests.sh` runs everything headless.
3. Data loading: `data/manifest.json` lists tables; `GameDataRegistry` (pure) loads + validates them; `GameData` autoload. First tables: weapons, combat, lobby_defaults, network, input_bindings. Weapon TTK test from data (§5.5).
4. Networking: `Transport` interface with `ENetTransport`, `WebSocketTransport`, `LoopbackTransport`; `Protocol` (message types, encode/decode, schema validation, size limit); pure `ServerSession` (handshake, version check, capacity, roster, ping) and `ClientSession`; `NetworkManager` autoload.
5. Boot: `CliArgs` parser (pure); boot scene routes to dedicated server scene (`--server` / `dedicated_server` feature) or client scene. Client dev-lobby screen with working HOST / JOIN / LEAVE / QUIT, roster, connection + input-mode status.
6. `InputRouter` autoload: registers actions from `input_bindings.json`, `InputClassifier` (pure) detects touch / desktop / controller from events (ignores touch-emulated mouse events and stick noise below dead zone), emits `mode_changed`.
7. Debug console (backquote/F1): command registry (pure) + overlay; commands help, fps, net, roster, input, data, backend, screenshot, quit. `--screenshot <path> --frames N` flag.
8. `BackendService` interface + `LocalBackend` (device/guest auth, versioned storage, profile) + `Backend` autoload doing guest login at start.
9. Tests: unit suites for every pure class; in-process ENet + WebSocket + loopback handshake tests; `tools/smoke_net.sh` launches a real headless server + 2 headless clients and asserts both see a roster of 2.
10. Screenshot of client dev lobby in `docs/art/`.

### Done (M0)
- Docs: `GAME_SPEC.md`, `CLAUDE.md`, `PROGRESS.md`, `ASSETS.md`, `docs/art/reference.png`.
- Godot 4.7.2 project in `/game`, gdUnit4 6.2.1, `./run_tests.sh` (unit + smoke) from the repo root.
- Data: `data/manifest.json` + tables `weapons`, `combat`, `lobby_defaults`, `network`, `input_bindings`, `debug`; `GameDataRegistry` + `DataSchemas` validation; `GameData` autoload.
- Combat maths: `TTKCalculator`; the TTK test checks every weapon in `weapons.json` against its band and the spec table.
- Networking: `Transport` (ENet / WebSocket / Loopback), strict `Protocol` (HELLO, WELCOME, REJECT, ROSTER, PING, PONG), `ServerSession` (version check, capacity, name sanitising + de-duplication, handshake timeout, delayed kick after REJECT, `message_sent` signal for the future role-leak test), `ClientSession` (timeouts, RTT), `NetworkManager` autoload.
- Dedicated server scene (`--server`, 30 Hz physics tick) and client dev lobby (HOST LOCAL / JOIN / LEAVE / QUIT, roster, account, input mode) over a placeholder sunset backdrop with 3 primitive astronauts.
- `InputRouter` + `InputClassifier` + `InputBindings` (all spec desktop/controller bindings from data).
- Debug console (` or F1) with help/clear/echo/fps/net/roster/input/data/backend/screenshot/quit; FPS overlay; `--screenshot <path> --frames N`.
- `BackendService` + `BackendResult` + `LocalBackend` (device/guest auth, versioned storage with conflict detection, profile, path-traversal protection, atomic writes) + `DeviceIdentity`; `Backend` autoload signs in as a guest at start.

### Test results (M0)
- `./run_tests.sh`: 72 gdUnit4 cases, 0 failures; smoke test PASS over ENet and WebSocket (headless server + 2 headless clients in separate processes, both see a 2-player roster).
- Screenshot: `docs/art/m0_dev_lobby.png` (xvfb, llvmpipe).

### How to try it
- `godot --headless --path game -- --server` then two clients: `godot --path game -- --connect 127.0.0.1 --name Alice --profile a` and `... --name Bob --profile b`.
- Or one client: press HOST LOCAL, then a second client presses JOIN.
- Press ` (backquote) for the console; try `net`, `roster`, `fps`, `screenshot`.

### Next (M1 — Look development "Sunset Cove")
See GAME_SPEC §10.

## Decisions
- **Godot 4.7.2** (latest stable at project start, 2026-09).
- Autoloads live in `game/autoload/` (not listed in the spec layout) so the pure folders (`core`, `net`) stay node-free. Backend code lives in `game/services/`.
- Networking uses raw `MultiplayerPeer` packets with our own `Protocol` (not Godot RPCs): messages are plain `[type, payload]` arrays, which lets tests record every message a client receives (needed for the role-leak test in M2) and keeps a loopback transport trivial.
- `var_to_bytes` / `bytes_to_var` (never the `_with_objects` variants) so peers cannot inject objects.
- Input actions are registered at runtime from `data/input_bindings.json` (numbers/bindings live in data) instead of `project.godot`.
- Data tables are listed explicitly in `data/manifest.json` (directory listing of `res://` is unreliable in exported builds). Export presets must include `*.json` (M7).
- Mouse events whose `device` is the touch-emulation id are ignored for input-mode detection, so touch devices don't flip to desktop mode.
- Default game port 24650 (ENet UDP; WebSocket uses the same number on TCP).
- Launch flags: `--server --host --port --connect --transport enet|ws --name --profile --backend-dir --screenshot --frames --quit-after --expect-roster --console`. `--profile` gives each local client its own device id (separate guest accounts on one machine).
- After a REJECT the server waits `reject_kick_delay_seconds` before dropping the peer so the reason is delivered.

## Known bugs / limitations
- A server process runs one transport at a time (`--transport enet|ws`). Serving native and web clients from one match needs a multi-transport server (peer-id namespacing) — planned with M6 matchmaking.
- Under `xvfb-run` the Vulkan driver lacks `VK_KHR_surface`, so screenshots fall back to the OpenGL Compatibility renderer. M1 look-dev must verify Forward+ features (volumetric fog, SSAO, SDFGI) on real hardware or get a working Vulkan surface in CI; compare carefully.
- Debug console opens with a keyboard only; a touch gesture to open it comes with the touch HUD (M2).
- Nakama backend not implemented yet (M6); `LocalBackend` is the active service.
- The dev lobby is an M0 test front end; the real main menu with live 3D island comes in M6.
