# Traitor Island — working notes for Claude Code

Full spec: `GAME_SPEC.md`. Current state and decisions: `PROGRESS.md` — **read it at the start of every session.**

## Working rules (from GAME_SPEC §0)
1. Build milestone by milestone (GAME_SPEC §10). Every milestone ends in a playable, tested build.
2. Keep `PROGRESS.md` current: milestone, done, next, known bugs, decisions.
3. Start a milestone by writing its plan into `PROGRESS.md`, then implement without asking between tasks. Stop at the end of the milestone and report (what works, test results, screenshots, what to try).
4. **No fake UI.** A button works or is not shown. Unavailable services go behind an interface with a working local implementation (`LocalBackend`, `NullVoiceService`); hide UI with nothing behind it.
5. **Rules live in pure code** under `game/core` (RefCounted/static, no nodes, no rendering). Every rule has gdUnit4 tests.
6. **Numbers live in data files** (`game/data/*.json`, listed in `game/data/manifest.json`). No magic numbers in gameplay code.
7. Commit after each working feature. Never leave the branch unrunnable.
8. Ambiguity → choose what best serves the six pillars (§1), log the decision in `PROGRESS.md`.
9. After visual changes, screenshot and compare with `docs/art/reference.png`.

Hard invariants: roles exist only on the server; clients get only their own role (+ fellow traitors if traitor) until MATCH_END; replicated state never carries a role; visor colour/glow never indicates role; no assets/names from Fortnite, Among Us or other games; all external assets logged in `ASSETS.md` (CC0 only).

## Tech stack
- Godot **4.7.2** (typed GDScript), binary at `/usr/local/bin/godot` (install: download `Godot_v4.7.2-stable_linux.x86_64.zip` from the godotengine GitHub releases).
- Dedicated server: same project, `--headless -- --server` (or `dedicated_server` feature tag).
- Transport: `Transport` interface (`game/net/transport.gd`) with ENet, WebSocket and in-memory Loopback implementations. Messages are `var_to_bytes([type, payload])`, validated by `Protocol`.
- Online services: `BackendService` interface; `LocalBackend` (JSON files) now, Nakama in M6. Callers always `await` backend calls.
- Tests: gdUnit4 6.2.1 in `game/addons/gdUnit4`, suites in `game/tests`.

## Commands (run from repo root)
- All tests (unit + networking smoke): `./run_tests.sh`
- Unit tests only: `./run_tests.sh --unit`
- Dedicated server: `godot --headless --path game -- --server --port 24650`
- Client: `godot --path game -- --connect 127.0.0.1 --name Alice`
- Screenshot: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path game -- --screenshot ../docs/art/shot.png --frames 60`
- Debug console in client: backquote (`) or F1 (debug builds). Type `help`.

## Folder layout
```
/game                 Godot project (project.godot here)
  /autoload           thin autoload nodes (GameData, NetworkManager, InputRouter, Backend, DebugConsole, Screenshotter)
  /core               pure rules + data loading (no nodes)
  /net                transport, protocol/message schemas, (later) replication/prediction
  /server             authoritative server session + dedicated server scene
  /client             client session, input classification, boot/menus, debug tools
  /services           BackendService interface + LocalBackend (+ Nakama later)
  /world /actors      world and actor scenes (from M1)
  /data               JSON data files + manifest.json
  /ui                 theme + UI helpers
  /tests              gdUnit4 suites (*_test.gd)
/backend              docker-compose + Nakama (M6)
/docs/art             reference.png + screenshots
/tools                scripts (net smoke test, screenshots)
```

## Conventions
- Typed GDScript everywhere (`var x: int`, typed returns). `class_name` for reusable scripts.
- Pure classes extend `RefCounted`; take config dictionaries from `GameData` in their constructor so tests can inject data.
- Autoloads stay thin: they wire pure classes to the engine.
- Test files: `game/tests/<area>/<name>_test.gd`, extending `GdUnitTestSuite`.
