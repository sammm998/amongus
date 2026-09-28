# PROGRESS

## Current milestone: M0 — Foundation (in progress)

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

### Done
- (filled in as work lands)

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

## Known bugs / limitations
- None yet.
