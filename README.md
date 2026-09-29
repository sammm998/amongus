# Traitor Island

**TRUST NOBODY.** A stylized third-person social-deduction shooter on a tropical island, built with Godot 4.7.2.
Full design: [`GAME_SPEC.md`](GAME_SPEC.md) · status: [`PROGRESS.md`](PROGRESS.md).

## Play in the browser (Railway)

The repo deploys to Railway as a Docker service (`Dockerfile` + `railway.json`):

- `/` serves the Web build of the game (exported during the Docker build).
- `/ws` is the dedicated game server (WebSocket) for online matches.
- `/healthz` is the health check.

Railway settings: the service must build from the branch that contains the `Dockerfile`
(Settings → Source → Branch). No variables are needed; Railway provides `$PORT`.
The first build downloads Godot and its export templates (~1.3 GB), so it takes a few minutes.

In the browser:
- **PLAY VS BOTS** — a full match against 7 bots, running entirely in your browser.
- **JOIN** — joins the online server on the same domain (`wss://<your-app>/ws`). The first player in the lobby is the host and presses **START MATCH**; empty seats are filled with bots. Send the link to friends so they can join the same lobby before the host starts.

## Play on desktop

Install Godot 4.7.2, then from the repo root:

```
godot --path game                 # client (PLAY VS BOTS, HOST LOCAL, JOIN)
godot --path game -- --play       # straight into a match vs bots
godot --headless --path game -- --server --port 24650   # dedicated server (ENet)
```

Controls: WASD move · mouse look · LMB fire · RMB aim · Space jump · Shift sprint · Ctrl crouch ·
R reload · E interact (hold: report, tasks, repairs, pick up) · 1–5 slots · T flashlight · Enter chat · Esc menu.
Touch controls appear automatically on touch screens; controllers work too.

## Tests

`./run_tests.sh` — gdUnit4 unit tests (rules, networking, backend, a full 8-bot match, the role-leak audit) plus
ENet/WebSocket smoke tests with a real server and two clients.
