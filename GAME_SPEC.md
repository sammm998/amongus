# TRAITOR ISLAND — Build Specification for Claude Code

> **TRUST NOBODY.**
> A stylized third-person multiplayer game that plays like *a social-deduction game (hidden traitors, tasks, reports, votes) inside a colorful battle-royale-style open island (guns, loot, vehicles, helicopters)*.

---

## 0. HOW TO WORK ON THIS PROJECT (read first)

You are building a real, shippable game in stages. The scope is large, so it is built **milestone by milestone** (Section 10). Each milestone must end in a **playable, tested build** — never a pile of half-connected systems.

**Working rules**

1. Read this whole file before writing code. Then create `CLAUDE.md` in the repo root summarizing the rules in this section, the tech stack and the folder layout, so they survive across sessions.
2. Keep `PROGRESS.md` up to date: current milestone, what is done, what is next, known bugs, decisions you made. Read it at the start of every session.
3. Start each milestone in plan mode: write the plan into `PROGRESS.md`, then implement it without asking for confirmation between tasks. Stop at the end of the milestone and report: what works, test results, screenshots, what the user should try.
4. **No fake UI.** A button either works or is not shown. No "Coming soon" cards. If a real service is not available yet (voice, store, push), build it behind an interface with a working local implementation (e.g. `LocalBackend`, `NullVoiceService`) and hide UI that has nothing behind it.
5. **Rules live in pure, testable code** (no scene/rendering dependencies): role assignment, damage, votes, meetings, win conditions, sabotage timers, tasks. Every rule has unit tests.
6. **Numbers live in data files** (`data/*.tres` or `data/*.json`): weapons, vehicles, sabotages, tasks, modes, lobby defaults. No magic numbers in gameplay code.
7. Commit after each working feature with a clear message. Never leave the main branch unrunnable.
8. When this spec is ambiguous, pick the option that best serves the six pillars (Section 1), note the decision in `PROGRESS.md`, and keep going.
9. Visual quality matters as much as function. After any visual change, capture a screenshot and compare it against `docs/art/reference.png` (Section 2).

---

## 1. GAME VISION

**Core idea.** 8–24 players (default 12) spawn on a tropical island. Everyone is armed. A few players are secretly **Traitors**; the rest are **Agents**. Agents complete tasks around the island to raise **Island Security** to 100% and try to identify Traitors. Traitors blend in, sabotage infrastructure and eliminate Agents without getting caught.

**The central tension:** anyone can shoot anyone. Seeing a shooting does *not* prove someone is a Traitor — maybe they were defending themselves. Players must investigate.

**The signature mechanic:** a player who goes down is not simply dead. When someone reports the body, a meeting starts — and the group votes on whether to **REVIVE** the victim or **KEEP THEM ELIMINATED**. Revive the wrong person, and you may have just brought a Traitor back.

**Six design pillars** (every decision must serve these):
1. **Social deduction** — who was nearby, who left, who jammed the cameras, who is lying?
2. **Freedom** — explore, drive, fly, fight, follow, hide, watch cameras, cooperate.
3. **Imperfect information** — never reveal the killer, exact positions, or full combat logs during a match.
4. **Everyone is dangerous** — agents and traitors carry the same weapons; friendly fire always on; hit markers never reveal roles.
5. **Mobile-first quality** — touch controls are first-class, not an afterthought.
6. **Replayability** — random roles, tasks, loot, vehicles, weather, events, sabotage.

**Originality.** Genre inspiration is fine (colorful battle-royale shooters + social-deduction games). But create everything yourself: **no** characters, maps, UI, logos, fonts, sounds, weapon models or names from Fortnite, Among Us or any other game.

---

## 2. ART DIRECTION — match the reference image

The user's reference image must be saved at **`docs/art/reference.png`**. Look at it with your image-reading tool before any visual work. It defines the look of the game.

**Overall style:** premium stylized cartoon 3D in the family of big colorful battle-royale games — bright, saturated, soft and chunky, cinematic lighting, *not* photorealistic, *not* flat low-poly. Think "animated feature film island".

**What the reference shows, and what to reproduce:**

| Element | Target |
|---|---|
| Lighting | Warm golden-hour sun low on the horizon, strong warm key + cool purple/blue sky fill, visible bloom on the sun and lights, soft long shadows, light haze/atmospheric fog in the distance |
| Sky | Painterly gradient (orange → pink → purple), big fluffy stylized clouds, sun disc with glow and a glittering sun path on the sea |
| Water | Vivid turquoise in shallows → deep blue offshore (depth-based color), white stylized foam at shorelines, visible coral/rock shapes under the surface, soft specular sparkle |
| Vegetation | Lush tropical jungle: palms with big glossy leaves, dense broadleaf bushes, ferns; gentle wind sway |
| Terrain | Cream-white sand beaches, chunky rounded dark rocks and cliffs, green hills, a tall smoking volcano/mountain peak, waterfall, sea stacks offshore |
| Buildings | Chunky stylized architecture with warm lit windows: hangars with curved roofs and an airstrip, small base/command buildings, a red-and-white radio tower with dishes, wooden piers and walkways |
| Vehicles | Chunky, slightly toy-like proportions (boat at the pier, small jets/planes on the airstrip) |
| Characters | Small chibi space explorers: big round glossy helmet, large dark reflective visor that picks up warm light, rounded suit, chunky backpack with small details, gloves, boots. Distinct suit colors (white/pink, yellow/orange, etc.) |
| Mood | Adventure + mystery. In the reference, a dark-suited figure with a glowing red visor lurks behind a palm — that is **key art only** |

**Critical gameplay rule:** in-game, visor color/glow is cosmetic only and **never** indicates role. No red eyes for traitors, ever.

**Rendering recipe (Godot 4):**
- Desktop/high: Forward+ renderer, AgX or ACES tonemapping, glow/bloom, SSAO, SDFGI or baked lightmaps for interiors, volumetric fog for distance haze, directional shadows with 3–4 cascades.
- Mobile: Mobile renderer, glow on, 2 shadow cascades, height fog instead of volumetric, baked lighting where possible.
- Stylized PBR: high roughness on most surfaces, saturated albedo, subtle rim/fresnel light on characters (custom shader), glossy clearcoat look on helmets/visors.
- Custom shaders: stylized water (depth color, shoreline foam, normal scroll, sun sparkle), foliage wind sway (vertex shader), sky gradient with clouds, color-grading LUT per time of day.
- Each district gets a distinct palette so players always know where they are (Section 6.4).

**Assets:**
- Allowed: assets you create in code (procedural meshes, Godot primitives/CSG), assets generated with Blender Python scripts (`blender --background --python`), and **CC0** packs from their official sources (e.g. Quaternius, Kenney, KayKit). Record every external asset with source URL and license in `ASSETS.md`.
- Not allowed: ripped game assets, unclear licenses, anything from Epic/Fortnite or Innersloth/Among Us.
- Characters: build the astronaut from primitives first (capsule body, sphere helmet, flattened sphere visor, rounded box backpack, capsule limbs) with procedural animation (walk bob, limb swing, lean). Replace with a Blender-scripted rigged mesh in a later milestone. The silhouette must read instantly at 50 m.
- Audio: synthesize or use CC0 sounds; original music (can be procedural/simple loops at first). Log in `ASSETS.md`.

---

## 3. TECH STACK (decided — do not change without noting why in PROGRESS.md)

| Area | Choice | Why |
|---|---|---|
| Engine | **Godot 4** (latest stable installed; check with `godot --version`), typed **GDScript** | Real 3D lighting/shaders for the target look; exports to iOS, Android, Windows, macOS, Linux, Web; text-based scenes Claude Code can edit; headless mode for servers and tests |
| Game server | Same Godot project, **dedicated server** export (`--headless`, feature tag `dedicated_server`) | One codebase for rules on client and server |
| Transport | ENet for native clients, WebSocket for web; behind a `Transport` interface | |
| Online services | **Nakama** (open source, has a Godot SDK) via `docker-compose`: guest/device auth, accounts, storage (profiles, settings, cloud save), friends, parties, matchmaker, leaderboards | Covers most meta features for real instead of mocks |
| Fallback | `LocalBackend` implementing the same `BackendService` interface (JSON files) — used for tests and when Docker is unavailable | |
| Tests | **gdUnit4**, run headless: `godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd` | |
| Screenshots | Run the client under `xvfb-run` (Linux) or normally (macOS/Windows) with a `--screenshot <path>` debug flag that renders N frames and saves the viewport | Visual verification |

---

## 4. ARCHITECTURE

**Repo layout**

```
/game                 Godot project
  /core               pure rules (no nodes): RoleAssigner, DamageModel, MeetingRules, WinRules, SabotageRules, TaskRules
  /net                transport, replication, prediction, lag compensation, message schemas
  /server             authoritative match simulation, anti-cheat validators
  /client             input, camera, HUD, menus, VFX, audio
  /world              terrain chunks, districts, props, streaming, weather, day/night
  /actors             player, vehicles, bots
  /data               weapons, vehicles, sabotages, tasks, modes, loot tables, lobby defaults
  /ui                 themes, fonts, UI scenes
  /tests
/backend              docker-compose + Nakama config/modules
/docs/art             reference.png + look-dev screenshots
CLAUDE.md  PROGRESS.md  ASSETS.md  GAME_SPEC.md
```

**Managers** (autoloads or match-scoped nodes; keep them small and focused): GameManager, MatchManager, NetworkManager, RoleManager, PlayerManager, InputRouter (Touch/Desktop/Controller), WeaponManager, InventoryManager, DamageManager, DownedManager, IncidentManager, MeetingManager, VotingManager, TaskManager, SabotageManager, VehicleManager, SecurityCameraManager, EvidenceManager, ActivityFeedManager, WorldManager, StreamingManager, WeatherManager, AudioManager, UIManager, SettingsManager, ProfileManager, ProgressionManager, MatchmakingManager, PartyManager, BackendService, AntiCheat, BotDirector.

**State machines**
- Match: `WAITING → COUNTDOWN → ROLE_REVEAL → ACTIVE ⇄ INCIDENT_MEETING (→ RESUMING) → MATCH_END → RESULTS`
- Player: `LOBBY, ALIVE, DOWNED, ELIMINATED, SPECTATING, DISCONNECTED, RECONNECTING` (+ `REVIVING` during respawn)
- Vehicle: `AVAILABLE, OCCUPIED, DAMAGED, DISABLED, DESTROYED, RESPAWNING`

**Networking**
- Server tick 30 Hz; snapshots 20 Hz for nearby entities, lower for distant ones (interest management by distance/zone).
- Own character: client-side prediction + server reconciliation. Others: interpolation (~100 ms buffer).
- Hitscan: server-side lag compensation (rewind ≤ 200 ms). Projectiles simulated on server.
- Priority: player movement, vehicles, shots, damage, incidents, votes, tasks, sabotage > cosmetics, far VFX, props.

**Security invariants (enforced by tests)**
- Roles exist only on the server. Each client receives only: its own role; if Traitor, the list of fellow Traitors. The full role list is sent to everyone **only** at `MATCH_END`.
- Sabotage UI, sabotage cooldowns and traitor teammate data are sent only to Traitor clients.
- Replicated player state contains no role field, ever. Bots use the same information rules.
- Server validates: movement speed/teleport, fire rate, ammo, damage, reload timing, interaction range, task completion steps, vote eligibility, vehicle entry, sabotage cooldowns, match outcome.
- Test: record every message sent to an Agent client during a full bot match and assert no other player's role appears.

---

## 5. CORE RULES (decision-complete)

### 5.1 Roles
- Traitor count = `round(players / 6)`, clamped to 1–4 → 8p:1, 10p:2, 12p:2, 16p:3, 20p:3, 24p:4. Host can override.
- **Agents:** do tasks, repair sabotage, investigate, survive.
- **Traitors:** know each other; get a **fake task list** (they can stand at tasks and "work", but it gives no progress) so they can lie convincingly; get the private sabotage panel.
- Role reveal: fade to black → big role card → Agent subtitle *"Protect the island. Find the Traitors. Do not trust everyone."* / Traitor subtitle *"Blend in. Sabotage the island. Eliminate the Agents."* + fellow Traitor avatars → short spawn cinematic → spawn around Central Command (random slots; traitors have no special spawns).

### 5.2 Win conditions
- **Agents win** if all Traitors are ELIMINATED, or Island Security reaches 100%.
- **Traitors win** if living Traitors ≥ living Agents (downed players count as not living), or a **critical sabotage** runs out its timer (**ISLAND CONTROL LOST**).
- Match time limit (default 25 min): if reached, Traitors win (they survived). Host-configurable.

### 5.3 Health, downed, bleed-out
- 100 health + up to 50 shield. Damage sources: weapons, vehicles, explosions, falls, hazards. No gore — stylized sparks, dust and hit flashes only.
- At 0 health → **DOWNED**: collapses, can crawl slowly, no weapons, and **cannot communicate in any way** (no voice, text, quick chat, pings, emotes, votes). HUD for the victim shows only "YOU ARE DOWN" and the bleed-out timer.
- Bleed-out: 90 s (host: 30–180 s or off). When it expires → ELIMINATED.
- **Any damage to a downed player eliminates them immediately** ("finishing"). This is risky and noisy — a deliberate decision that creates witnesses.
- There is **no field revive**. Revival only happens through a meeting vote.

### 5.4 Reports and meetings
- A living player holds INTERACT for 1 s on a downed or eliminated body → **REPORT INCIDENT**.
- **Emergency meeting:** button in the Central Command meeting chamber, 1 use per player per match, global cooldown 60 s. No revive vote in emergency meetings.
- During meetings: combat and movement freeze, all living players join the meeting UI, bleed-out timers pause.
- Phases (host-configurable):
  1. **Incident review — 8 s**: victim, reporter, district, estimated incident time (±15 s), damage type, weapon family if detectable, nearby camera status, power status.
  2. **Discussion — 45 s**: voice, text, quick chat. Victim is muted.
  3. **Revive vote — 20 s** (only if the victim was still DOWNED when reported): REVIVE / KEEP ELIMINATED / abstain. Majority of cast votes; **tie = keep eliminated** (host can flip). The victim cannot vote.
  4. **Suspect vote — 15 s**: each player may nominate one player; anyone with votes from ≥ 40% of living players gets the **SUSPECT** marker for 2 min (visible warning icon on name/player card; no other effect). Skipped if nobody nominates.
- **Revive result:** respawn at the Medical Center or nearest powered Medical Station (never within 60 m of recent gunfire), 50 health, basic pistol + 24 light ammo, 5 s spawn protection. They may talk normally afterwards — no special UI to reveal their attacker.
- **Keep eliminated:** becomes SPECTATOR for the rest of the match.

### 5.5 Combat
- Friendly fire always on. Hit markers and kill feed never reveal roles; there is **no kill feed** during matches.
- Target body-shot time-to-kill vs. 100 HP: **1.5–3.0 s** for most weapons. Headshot ×1.5 (not shotgun/explosives). A unit test computes TTK from the data file and fails if a weapon leaves its allowed band.

| Weapon | Body dmg | Rate | Mag | Reload | Ammo | Rarity range | Notes / TTK (perfect aim) |
|---|---|---|---|---|---|---|---|
| Pistol | 15 | 3.0/s | 12 | 1.4 s | Light | Standard–Advanced | 2.0 s |
| SMG | 9 | 7.0/s | 30 | 2.0 s | Light | Standard–Elite | 1.6 s, high spread |
| Assault Rifle | 12 | 5.0/s | 30 | 2.3 s | Medium | Standard–Prototype | 1.6 s |
| Burst Rifle | 11 ×3 | burst/0.6 s | 24 | 2.2 s | Medium | Advanced–Elite | 1.8 s |
| Shotgun | 8 pellets × 8 | 1.0/s | 5 | 0.5 s/shell | Shells | Standard–Elite | 1.0 s point blank only, weak past 8 m |
| Marksman Rifle | 30 | 1.5/s | 10 | 2.5 s | Medium | Advanced–Prototype | 2.0 s |
| Sniper Rifle | 75 | 0.5/s | 5 | 3.0 s | Heavy | Elite–Prototype | 2.0 s, loud, visible tracer |
| LMG | 10 | 6.0/s | 75 | 4.5 s | Heavy | Advanced–Elite | 0.4 s spin-up, ~1.9 s |
| Stun Gun | 0 | — | 3 charges | — | Energy Cells | Advanced | Stuns 4 s: no move, no fire |
| Grenade Launcher | 70 splash (4 m, falloff) | 1.0/s | 4 | 3.2 s | Explosive | Prototype | Big vehicle damage |

- Every weapon data entry also defines: accuracy, recoil pattern, spread (hip/ADS/moving), range falloff, movement speed penalty, ADS time, touch aim-assist strength, vehicle damage multiplier, sound profile.
- Rarity tiers (original): **Standard** (grey-white), **Advanced** (teal), **Elite** (violet), **Prototype** (hot coral). Higher rarity = slightly better handling/damage, never more than +10% damage.
- Ammo: Light, Medium, Heavy, Shells, Energy Cells, Explosive. Finite; carry limits per type.
- Healing (takes time, interruptible): Med Patch +25 HP (2 s), Med Kit to 100 HP (5 s), Shield Cell +25 shield (2 s), Trauma Kit +50 HP +25 shield (6 s), Vehicle Repair Kit +50% vehicle HP (5 s, exposed).
- Inventory: 5 slots — Primary, Secondary, Sidearm, Utility, Healing. Every player starts with a pistol + 24 light ammo and a flashlight.
- Loot: semi-random per match from district loot tables (buildings, crates, armories, abandoned vehicles, supply drops, task rewards). Powerful weapons never sit at spawn.

### 5.6 Tasks and Island Security
- Each Agent gets 6 tasks by default (host 3–10), drawn randomly from the pool so they spread players across districts. Traitors get an equal-length fake list.
- Total required progress scales with living Agents at match start; each completed task adds its weight. Cooperative tasks count double.
- Task types: travel, interaction (hold/minigame), multi-step, delivery (carry an item — you can't use your primary weapon while carrying), repair, cooperative (two players at two consoles within 3 s), timed.
- Pool (each with location candidates, steps and a short touch-friendly minigame): Repair Generator, Deliver Medical Supplies, Restart Server, Refuel Radio Tower, Calibrate Radar, Restore Surveillance, Collect Intelligence, Inspect Crash Site, Repair Bridge Controls, Reboot Communications, Recover Data Drive, Activate Emergency Beacon, Repair Fuel Pump, Inspect Power Relay.
- Server validates each step (range, duration, sequence). Minigames are client-side feel only; the server checks timing.

### 5.7 Traitor sabotage
Private panel (traitors only). Shared team cooldown between any two sabotages: 30 s. Only one **critical** sabotage at a time.

| Sabotage | Effect | Duration | Cooldown | Repair |
|---|---|---|---|---|
| Blackout (district) | Lights off in one district, emergency lights remain; flashlights matter | 60 s | 90 s | Auto-ends, or fix breaker in district |
| Camera Jam (district / network) | Feeds show static + SIGNAL LOST; no recording | 45 s / 30 s | 90 s / 180 s | Auto-ends or reset at security room |
| Comms Failure | Disables activity map, task guidance and some quick chat | until repaired | 150 s | Reboot at Radio Station + Central Command |
| False Alarm | Fake event on activity map ("GUNFIRE DETECTED — HARBOR") | instant | 90 s | — |
| Security Door Lock | Locks doors of one facility | 40 s | 120 s | Override at facility panel (hold 4 s) |
| Vehicle Lockdown | One vehicle station can't be used | 60 s | 120 s | Panel at station |
| Radar Spoof | Aircraft/vehicle events on activity map become unreliable | 60 s | 150 s | Recalibrate radar at Military Base |
| Medical System Failure | Medical Stations offline (revives go to Medical Center only) | 60 s | 180 s | Reset at Medical Center |
| Fuel Depot Shutdown | Fuel pumps in one district off | 90 s | 150 s | Pump panel |
| Bridge Lock | Chosen bridge raises/closes | 45 s | 150 s | Bridge control booth |
| **Power Failure** (critical) | Lights, cameras, powered doors, some vehicle stations and activity map off island-wide; **90 s countdown** | until repaired | 240 s | Restore 2 of 3 generators at Power Station (each hold 5 s). Countdown hits 0 → **ISLAND CONTROL LOST**, Traitors win |

Every sabotage has an audio/visual alert for everyone (e.g. POWER FAILURE, CAMERAS OFFLINE, COMMUNICATION FAILURE) — but never says who triggered it. Sabotages cannot be triggered during meetings or in the first 60 s of a match.

### 5.8 Information systems (imperfect by design)
- **Security cameras** at: Central Command, Nova City, Airfield, Power Station, Medical Center, Harbor, Military Base, Research Facility, Radio Station. Viewed from the monitor wall in Central Command's security room. Feeds are real render views of the live world (players, vehicles, fights, doors, explosions) with **no role markers and no name tags**. The viewer's character stays at the terminal, exposed, with no view behind them.
- **Camera replay:** the last 10 s of each feed is kept as a low-rate snapshot buffer (positions/animations, not video) and can be replayed from the terminal after an incident. Jammed or unpowered cameras record nothing.
- **Activity map** (Central Command map room, and on the full map while comms are up): approximate, delayed (5–15 s) event blips per district — gunfire, vehicle activity, aircraft, door breach, power outage. Never exact positions or names.
- **Body inspection** (hold 2 s): estimated time (±15 s), damage category, range band (close/mid/long), weapon family, rough direction of last hit. Never the attacker.
- **Evidence** spawned at incident sites and persisting for 3 min: shell casings (weapon family), impact marks, broken glass, tire tracks, damaged doors, dropped items, destroyed cameras.
- **Sound:** gunshots audible up to 250 m (sniper 400 m), directional 3D audio, distinct sound per weapon family; footsteps, vehicles, aircraft are all directional.
- **Minimap/full map:** roads, districts, objectives, incident markers, world events, vehicles only when nearby/seen. Never all players.
- **Names:** shown above players within 30 m in line of sight (host can reduce). Suspect icon shown next to the name.

---

## 6. WORLD

### 6.1 Island
One continuous island (~2.0 × 2.0 km playable to start; design so it can grow), divided into streaming chunks. Roads, bridges, a tunnel, a river, beaches, cliffs, a volcano/mountain peak, forests, fields, harbor, sea around it.

### 6.2 Streaming and LOD
Chunked terrain (e.g. 128 m chunks) with 3 LOD levels, HLOD impostor silhouettes for distant districts, interiors loaded only near their entrances, visibility ranges on props, multimesh for vegetation and repeated props.

### 6.3 Interactive objects
Doors (automatic, manual, locked, sabotaged, security-controlled), elevators, terminals, switches, security gates, generators, fuel pumps, camera terminals, task consoles, medical stations. One adaptive **context button**: ENTER/EXIT VEHICLE, OPEN, PICK UP, REPORT, INSPECT, USE TERMINAL, REPAIR, START TASK.

### 6.4 Districts (14)

| District | Key contents | Palette |
|---|---|---|
| Central Command (hub) | Meeting chamber, security room (monitor wall), comms room, map room, garages, rooftop helipad, emergency button | Navy + white + cyan signage |
| Nova City | Streets, shops, apartments, rooftops, parking garage, alleys, underground passage, small security post | Bright neon signage, pastel facades |
| Medical Center | Revival stations, pharmacy, emergency ward, ambulance bay, helipad | White + teal |
| Airfield | Runway, curved-roof hangars, control tower, fuel tanks, planes, helicopters | Grey concrete + aviation yellow |
| Military Base | Armory, bunkers, watchtowers, vehicle depot, radar, underground area | Olive + sand |
| Power Station | Generators, transformers, cooling area, control room | Industrial orange + steel |
| Deep Forest | Cabins, trails, watchtowers, caves, hidden roads | Deep green + warm wood |
| Mountain Observatory / Volcano | Observatory dome, radio tower, tunnels, cliff roads, helipad, viewpoints | Dark rock + white dome |
| Harbor | Containers, cranes, warehouses, boats, fishing docks, fuel storage | Blue + rust |
| Farm District | Fields, barns, silos, dirt roads, tractors | Golden wheat + red barns |
| Radio Station | Red-and-white lattice tower with dishes (as in the reference), relay rooms | Red + white |
| Research Facility | Labs, server rooms, experimental equipment, underground level | Clean white + violet light |
| Coastal Village | Small houses, market, beach huts, piers | Warm pastels + sand |
| Industrial Zone | Factories, warehouses, cranes, construction site | Concrete + hazard stripes |

Every district: multiple entrances, cover, escape routes, vehicle and walking paths.

### 6.5 Dynamic world
- **Weather:** sunny, cloudy, rain, fog, storm (mobile-friendly effects). **Time of day:** day, sunset (default — matches reference), night (flashlights, streetlights; blackouts become scary).
- **Events** every 2–4 min: supply drop (plane flies over, crate with smoke/beam, rare loot), storm front, fog bank, power surge, vehicle delivery, radar ping, emergency broadcast, crash site, temporary bridge closure.

---

## 7. VEHICLES

Arcade handling everywhere — fun first, not simulation. All vehicles have: health, fuel, driver + passenger seats (passengers can shoot), damage states with smoke/fire, destruction explosion, engine sounds, network sync, timed respawn at vehicle stations (never instant).

| Vehicle | HP | Seats | Top speed | Notes |
|---|---|---|---|---|
| Compact car | 600 | 4 | 110 km/h | Common |
| SUV | 900 | 5 | 100 km/h | Tough |
| Pickup | 800 | 2 + 4 in bed | 100 km/h | Bed passengers exposed |
| Sports car | 450 | 2 | 150 km/h | Rare, loud |
| ATV | 300 | 2 | 90 km/h | Off-road |
| Motorboat | 500 | 4 | 80 km/h | Coast + river; rare version with mounted gun |
| Helicopter | 700 | 4 | 160 km/h | Arcade controls; rare variant with light MG (limited ammo, overheat) |
| Small aircraft | 500 | 2 | 220 km/h | Auto forward thrust, bank steering, boost, light guns, needs runway/space to take off |

Fuel: consumption per vehicle type (aircraft fastest), fuel stations in several districts (can be sabotaged), Repair Kit restores health. Vehicle respawn: 90–240 s depending on type; helicopters/aircraft limited per match (host setting).

---

## 8. CONTROLS & UI

### 8.1 Input
Auto-detect the last used input and switch UI instantly (touch / mouse+keyboard / controller).

- **Touch (landscape):** left half = floating virtual joystick (push to edge = sprint, optional auto-sprint); right half = swipe to look (smooth acceleration); buttons: FIRE, AIM, JUMP, CROUCH, RELOAD, CONTEXT, weapon slots, flashlight (only when dark). Aim assist (slowdown + gentle magnetism, never hard lock), optional gyro (OFF / ADS ONLY / ALWAYS). Auto options: pickup ammo, reload, open doors, sprint, equip better weapon. If a match starts in portrait: "ROTATE YOUR DEVICE".
- **Custom HUD editor:** drag, resize, opacity, hide optional buttons, reset, save profiles; presets STANDARD, COMPACT, TWO/THREE/FOUR FINGER, TABLET.
- **Desktop:** WASD, mouse look, LMB fire, RMB aim, Space jump, Shift sprint, Ctrl crouch, R reload, E interact, F vehicle, T flashlight, 1–5 slots, Tab activity/score panel, M map, Enter chat, Esc menu.
- **Controller:** LS move, RS look, RT fire, LT aim, A/✕ jump, B/◯ crouch, X/▢ reload/interact, Y/△ swap, D-pad slots/quick chat.
- **Vehicles:** touch — left steer/move, right throttle/brake/handbrake/exit (+ ASCEND/DESCEND for helicopters); desktop — W/S/A/D, Space handbrake/ascend, Ctrl descend, F exit.

### 8.2 HUD
Top-left minimap · top-center objective + Island Security bar · top-right network, match time, alerts · bottom-left health + shield · bottom-right weapons, ammo · center crosshair + context prompt. Respect safe areas (notch, Dynamic Island, rounded corners, nav bars). Show only what matters right now.

### 8.3 UI language
Original design: dark translucent rounded panels, bright cyan highlights, amber warnings, red danger, bold chunky display font (open-license), big icons, subtle glow, snappy motion. Menus must feel like a game, not a website: live 3D island background (the sunset cove), animated characters, particles, sound feedback. No UI elements copied from other games.

### 8.4 Key screens
Security cameras (phone: 2-column grid, tap = fullscreen, swipe = switch, big EXIT; desktop: larger grid, click to expand) · Meeting (phone: incident summary top, scrollable player cards middle, chat + big REVIVE / KEEP ELIMINATED / MARK SUSPECT buttons bottom; desktop: 3 columns) · Full map (pinch/drag/zoom, waypoints) · Results (winner, all roles revealed, per-player stats, match timeline).

### 8.5 Communication
Text chat, quick chat wheel (Where were you? / I saw someone here / I heard gunshots / Camera was disabled / Power went out / Follow me / Stay together / I don't trust them / I was at Medical / Check the cameras / Someone took a vehicle / I saw a helicopter / Report the body), pings (location, danger, vehicle, task, item, SUSPICIOUS — never "traitor here"), emotes. Proximity voice + meeting voice behind a `VoiceService` interface (WebRTC or platform SDK later); proximity text bubbles work now. Dead players can talk only to other dead players/spectators.

---

## 9. META, ONLINE AND PLATFORM

- **Flow:** launch → first-time flyover ("DRIVE. FLY. INVESTIGATE. DECEIVE. SURVIVE. TRUST NOBODY.") → guest login → main menu (PLAY, CHARACTER, LOADOUT, CAREER, HOW TO PLAY, SETTINGS, SHOP) → play menu (QUICK PLAY, CASUAL, RANKED, PRIVATE MATCH, JOIN CODE, TRAINING) → matchmaking → pre-game lobby (run, jump, emote, test controls, no damage, ready up) → match → results → XP → back to lobby / queue again.
- **Modes:** Standard, Chaos (more vehicles/weapons, faster sabotage), Hardcore (less HUD, limited cameras, more damage), Casual (less damage, longer discussion, revive ties = revive).
- **Private lobby settings:** player count, traitor count, tasks, sabotage cooldown multiplier, discussion/vote durations, revive rules, bleed-out, friendly-fire multiplier, loot/vehicle/event frequency, weather, time of day, cameras on/off, name distance, voice.
- **Profile & progression:** level, XP (tasks, wins, repairs, reports, revives, sabotage, objectives), stats (matches, wins, agent/traitor wins, tasks, revives, vehicle distance, camera time, accuracy), daily/weekly challenges, cosmetic unlocks only. Ranked rating from team result + role-appropriate contribution, not kills.
- **Customization:** helmet, visor, head accessory, suit, backpack, gloves, boots, emote, banner, badge; 12 base colors (red, blue, green, yellow, orange, purple, cyan, pink, black, white, lime, navy). Duplicate color+helmet combos in a match are auto-adjusted so players stay recognizable. Shop is cosmetic-only (implement with a soft currency earned by playing; real payments later).
- **Social:** friends, parties, recent players, mute, block, report (cheating, harassment, voice abuse, name, intentional team sabotage, exploiting).
- **Settings:** Gameplay, Controls, Audio, Graphics (AUTO/LOW/MEDIUM/HIGH/ULTRA + individual toggles, auto-downgrade on sustained low FPS, **Battery Saver**: 30 FPS, lower res/shadows/particles), Accessibility (colorblind modes, UI scale, text size, subtitles, reduced motion, high contrast, hold/toggle aim & crouch, vibration), Voice, Account. Everything persists and syncs through the backend.
- **Reconnect:** slot reserved 120 s; restore role, inventory, health, position, tasks, votes. App backgrounding (call, lock screen) → auto-reconnect on resume. AFK: warning at 60 s idle, removal at 180 s without revealing role.
- **Bots:** navigate (navmesh), do tasks, drive, fight, react to incidents, report bodies, vote with simple heuristics, and as Traitors sabotage and pick isolated targets. Bots receive exactly the same information a human in their role would. Used for training, filling casual matches and automated tests.
- **Performance targets:** 60 FPS on modern phones, 30 FPS minimum on low-end; security feeds render only when visible, at reduced resolution/rate on low settings; every expensive feature (shadows, SSAO, volumetric fog, foliage sway, reflections, particles, camera-feed resolution) individually toggleable.

---

## 10. MILESTONES

Each milestone ends with: all tests green, a playable build, screenshots in `docs/art/`, an updated `PROGRESS.md`, and a short report to the user.

**M0 — Foundation**
Godot project, folder layout, `CLAUDE.md`, `PROGRESS.md`, `ASSETS.md`, gdUnit4, data-file loading, dedicated server boots headless, 2 clients connect locally, input router with touch/desktop/controller detection, debug console + `--screenshot` flag, `BackendService` interface with `LocalBackend`.
*Done when:* server + 2 clients run, tests run headless from one command.

**M1 — Look development: "Sunset Cove"**
Build one small vista reproducing the reference image: sky, sun, clouds, water shader with shoreline foam, sand beach, rocks, palms with wind, a hangar, radio tower, wooden pier, boat, distant volcano with smoke, 3 astronaut characters in different colors with procedural idle/walk. Desktop and mobile render presets.
*Done when:* side-by-side screenshot next to `reference.png` looks like the same game; mobile preset holds 60 FPS on a mid-range target (measure with the in-game FPS counter on the lowest desktop GPU available + note the result).

**M2 — Core loop vertical slice (the heart of the game)**
Small map (Central Command, Medical Center, Harbor, a beach and connecting road). Third-person controller (walk/run/sprint/jump/crouch, ledge step), over-shoulder camera with collision and aim mode, pistol + assault rifle + shotgun, server-authoritative hitscan with lag comp, health/shield, downed/bleed-out/finishing, reports, full meeting (4 phases), revive/keep eliminated, suspect marker, roles + role reveal, 3 task types with Island Security, fake traitor tasks, 3 sabotages (Blackout, Camera Jam, Power Failure), win conditions, results screen with role reveal. Bots fill to 8 players. Touch HUD fully usable.
*Done when:* a full 8-player match (1 human + 7 bots, or all bots headless) plays start to finish with a winner; role-leak test passes; tests cover every rule in Section 5.

**M3 — Deduction depth**
Security room + live camera feeds + 10 s replay, activity map with delays and false alarms, body inspection, evidence props, all remaining sabotages, all tasks incl. cooperative/delivery, text chat, quick chat, pings, emotes, proximity text bubbles, emergency meeting, spectator mode, directional audio for gunfire/footsteps.
*Done when:* the "stories" in Section 11 can happen in a bot + human playtest.

**M4 — Vehicles**
Car, SUV, pickup, sports car, ATV, boat, helicopter, small aircraft; seats, passengers shooting, damage/destruction, fuel + stations, repair kit, vehicle stations with timed respawn, touch + desktop + controller vehicle controls, network-smoothed vehicle sync.
*Done when:* each vehicle can be driven/flown across the map on touch and desktop and synced to other clients without jitter.

**M5 — The full island**
All 14 districts, roads, bridges, tunnel, river, volcano, interiors, chunk streaming + LOD, full weapon roster + loot tables + supply drops, weather, day/sunset/night, world events, doors/elevators/gates, 12–24 player support, bots using vehicles.
*Done when:* a 16-bot headless match completes; client streaming keeps memory and frame time within budget.

**M6 — Meta and online**
Nakama via docker-compose: guest/device auth, profiles, cloud-saved settings/HUD/loadouts, friends, parties, matchmaking (region, mode, crossplay, input preference), private lobbies with join codes and all host settings, reconnect, AFK handling, main menu with live 3D background, character customization, loadout, career/stats, progression, challenges, cosmetic shop (soft currency), modes (Standard/Chaos/Hardcore/Casual), ranked rating.
*Done when:* two real clients can log in, party up, queue, play, earn XP and see it persist after restart.

**M7 — Platforms, polish, onboarding**
Export presets for Android, iOS, Windows, macOS, Web; graphics tiers + auto-graphics + battery saver; safe areas; tablet layouts; accessibility; full audio pass + original music; VFX pass (muzzle flash, impacts, dust, rotor wash, explosions, rain, lightning, camera glitch); interactive training mode; first-time flyover; polished error screens (CONNECTION LOST, MATCH FULL, SERVER UNAVAILABLE, VERSION MISMATCH, LOGIN FAILED) with recovery actions; anti-cheat hardening; replace primitive characters with rigged Blender-scripted models and full animation set.
*Done when:* the checklist in Section 12 passes.

---

## 11. EXPERIENCE TARGET

The game succeeds when players say things like:
- "I saw yellow leaving the airfield right before the shooting."
- "The cameras cut out ten seconds before the incident."
- "Blue says they were fixing the generator, but the camera showed their boat at the harbor."
- "Should we revive them? What if they're a Traitor?"
- "We revived the wrong person."
- "Someone stole the helicopter."
- "The one everyone trusted was the Traitor."

---

## 12. FINAL VERIFICATION CHECKLIST

- [ ] Touch landscape controls fully usable; HUD fits 16:9, 19.5:9, 20:9 phones and 4:3 tablets; safe areas respected
- [ ] Desktop and controller controls fully usable; input auto-switch works mid-match
- [ ] Camera never blocks shooting; aim assist never hard-locks
- [ ] Menus work in portrait and landscape
- [ ] Role privacy: automated leak test passes; roles revealed only at match end
- [ ] Downed players cannot communicate in any way
- [ ] Meetings, revive vote, suspect vote and ties behave per Section 5.4
- [ ] All sabotages, repairs and the critical countdown work
- [ ] All tasks, co-op tasks and Island Security work; fake traitor tasks give no progress
- [ ] Security cameras, replay, activity map, evidence and body inspection work and never reveal the attacker
- [ ] Cars, helicopters, aircraft and boats work on all input types
- [ ] Combat TTK test passes; friendly fire works; no role-revealing hit feedback
- [ ] Revive respawn is safe; spectator mode works
- [ ] Results, timeline, XP and stats persist
- [ ] Reconnect restores the same role and state
- [ ] Settings and HUD layouts persist across restarts and devices
- [ ] Visuals match `docs/art/reference.png` in style; all assets logged in `ASSETS.md` with licenses
