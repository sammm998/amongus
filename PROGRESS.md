# PROGRESS

## Current milestone: M2 — Core loop vertical slice (M0 ✅, M1 ✅)

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
- `mesa-vulkan-drivers` (lavapipe) is installed in the build container so screenshots use the real Forward+ renderer.

### How to try it
- `godot --headless --path game -- --server` then two clients: `godot --path game -- --connect 127.0.0.1 --name Alice --profile a` and `... --name Bob --profile b`.
- Or one client: press HOST LOCAL, then a second client presses JOIN.
- Press ` (backquote) for the console; try `net`, `roster`, `fps`, `screenshot`.

## M1 — Look development "Sunset Cove" ✅
Plan: custom sky/water/foliage shaders, data-driven island height field, procedural props, animated primitive astronauts, render presets, side-by-side check vs the reference.

Done:
- Shaders (`world/shaders`): painterly sky (gradient, sun disc + glow, fbm clouds), stylized water (baked depth map → turquoise shallows/deep blue, refraction, shoreline foam bands, sun glints, stylized self-illumination), foliage wind sway, waterfall.
- `HeightField` (pure): union-of-ellipses coastline with signed distance → beach → shallow shelf → drop-off, plus hills/cones/plateaus/flat pads; `TerrainMeshBuilder` (vertex-coloured sand/grass/jungle/rock/coral, heightmap collision).
- Props via `MeshKit` (primitives merged into few surfaces): hangars with curved roofs, command buildings with warm windows, red/white lattice radio tower with dishes + beacon, pier with lanterns, lamp posts, airstrip, boat, small jets, rocks/sea stacks, palms/bushes/ferns (MultiMesh), volcano smoke particles.
- `Astronaut`: chibi explorer from primitives with pivots and procedural idle/walk (bob, limb swing, lean) + downed pose; rim light and clearcoat helmet/visor.
- `SunsetEnvironment` (ACES, glow, SSAO, fog, volumetric fog) — the visible sun disc is decoupled from the light elevation so flat ground stays bright at golden hour.
- `data/render_presets.json` + `RenderPresets`: ultra/high/medium/mobile/low/battery_saver with individual toggles (glow, SSAO, SSIL, volumetric fog, cascades, shadow distance/size, MSAA, render scale, foliage sway, FPS cap).
- Scene: `--scene cove` or SUNSET COVE in the dev lobby. F = fly camera, 1–6 = presets, Esc = back.
- Tools: `tools/terrain_map.gd` (top-down layout map), `tools/side_by_side.gd` (comparison image), `--measure-fps S`, `--preset NAME`.
- Screenshots: `docs/art/m1_cove.png`, `docs/art/m1_compare.png`.

Measurements: this build machine only has a CPU rasteriser (llvmpipe, 4 cores): high 0.9 FPS, mobile 1.4 FPS at 1280×720 — not representative. **Needs measuring on a real mid-range GPU/phone** (run `godot --path game -- --scene cove --preset mobile --measure-fps 10`).

Honest gap vs reference: our vista is less detailed (fewer props, simpler building shapes, faint clouds, volcano reads as a plain cone, smoke barely visible). Palette, lighting direction, water and characters are in the right family. Further art passes are planned in M5 (full island) and M7 (rigged characters).

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
- Screenshots need `mesa-vulkan-drivers` in the container (`apt-get install -y mesa-vulkan-drivers`); without it Godot falls back to the Compatibility renderer.
- Debug console opens with a keyboard only; a touch gesture to open it comes with the touch HUD (M2).
- Nakama backend not implemented yet (M6); `LocalBackend` is the active service.
- The dev lobby is an M0 test front end; the real main menu with live 3D island comes in M6.
