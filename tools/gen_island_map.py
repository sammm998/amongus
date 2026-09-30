#!/usr/bin/env python3
"""Generates game/data/maps/island.json — the full ~1.4 x 1.0 km island.

The four vertical-slice districts (Central Command, Medical, Harbor, Beach) are
reused from gen_slice_map.py, moved apart, and five new districts are added.
Hand-made waypoints are kept inside districts; the open land between them is
covered by an automatic 20 m walking grid. Run from the repo root, then bake
the height cache: godot --headless --path game --script res://tools/bake_maps.gd
"""
import json, math, os, sys

sys.path.insert(0, os.path.dirname(__file__))
import gen_slice_map as S

# Where each slice district moves to (offset added to all its content).
OFFSETS = {
    "central_command": (0, 0),
    "medical": (-215, 78),
    "harbor": (445, 80),
    "beach": (0, 327),
}
SLICE_CENTERS = {d["id"]: (d["x"], d["z"], d["radius"]) for d in S.districts if d["id"] != "roads"}


def slice_district(x, z, slack=10.0):
    """Nearest slice district whose radius (+slack) contains the point, else None."""
    best, best_d = None, 1e9
    for did, (cx, cz, r) in SLICE_CENTERS.items():
        d = math.hypot(x - cx, z - cz)
        if d <= r + slack and d < best_d:
            best, best_d = did, d
    return best


def moved(item, did, keys=("x", "z")):
    ox, oz = OFFSETS[did]
    out = dict(item)
    out[keys[0]] = round(item[keys[0]] + ox, 2)
    out[keys[1]] = round(item[keys[1]] + oz, 2)
    return out


terrain = {
    "sea_floor": -18, "land_level": 2.4, "beach_width": 14, "shelf_width": 34, "shelf_depth": 2.5, "dropoff": 80,
    "noise": {"amplitude": 2.2, "frequency": 0.012, "seed": 21},
    "land": [
        {"x": 0, "z": 0, "rx": 650, "rz": 430},
        {"x": -80, "z": 427, "rx": 50, "rz": 30},
        {"x": 420, "z": 330, "rx": 190, "rz": 130},
        {"x": -520, "z": -250, "rx": 200, "rz": 170},
    ],
    "hills": [
        {"x": -40, "z": -300, "radius": 170, "height": 28},
        {"x": -230, "z": -120, "radius": 110, "height": 14},
        {"x": 200, "z": -90, "radius": 95, "height": 12},
        {"x": -250, "z": 260, "radius": 90, "height": 10},
        {"x": 150, "z": 210, "radius": 110, "height": 9},
        {"x": 470, "z": -130, "radius": 120, "height": 16},
        {"x": -600, "z": 20, "radius": 80, "height": 11},
    ],
    "flats": [],
}

districts = [
    {"id": "central_command", "name": "Central Command", "x": 0, "z": -20, "radius": 60, "color": "#1f3a66", "accent": "#2de2e6"},
    {"id": "medical", "name": "Medical Center", "x": -330, "z": 60, "radius": 48, "color": "#e8f4f2", "accent": "#18b3a8"},
    {"id": "harbor", "name": "Harbor", "x": 595, "z": 60, "radius": 55, "color": "#2a5d8f", "accent": "#b5562c"},
    {"id": "beach", "name": "Sunset Beach", "x": -10, "z": 427, "radius": 75, "color": "#f5e4c3", "accent": "#ff9f5a"},
    {"id": "power_station", "name": "Power Station", "x": 290, "z": -250, "radius": 55, "color": "#5a5f66", "accent": "#ff8a1e"},
    {"id": "airfield", "name": "Airfield", "x": -440, "z": -240, "radius": 90, "color": "#7c8a70", "accent": "#e8e04a"},
    {"id": "radio_station", "name": "Radio Station", "x": -60, "z": -330, "radius": 40, "color": "#3a4452", "accent": "#e84a4a"},
    {"id": "research", "name": "Research Lab", "x": -470, "z": 200, "radius": 48, "color": "#dfe7ee", "accent": "#7a5cff"},
    {"id": "village", "name": "Coastal Village", "x": 340, "z": 300, "radius": 60, "color": "#c9a878", "accent": "#e8603a"},
    {"id": "roads", "name": "Island Road", "x": 0, "z": 0, "radius": 900, "color": "#666666", "accent": "#ffcc33"},
]

# --- Slice content, moved -------------------------------------------------------
for f in S.terrain["flats"]:
    did = slice_district(f["x"], f["z"], 0)
    if did:
        terrain["flats"].append(moved(f, did))

buildings, props, stations, cameras, loot = [], [], [], [], []
for b in S.buildings:
    buildings.append(moved(b, b["district"]))
for p in S.props:
    did = slice_district(p["x"], p["z"], 30)
    if did:
        props.append(moved(p, did))
for s in S.S:
    did = s["district"] if s["district"] in OFFSETS else None
    if did:
        stations.append(moved(s, did))
for c in S.cameras:
    c2 = moved(c, c["district"])
    ox, oz = OFFSETS[c["district"]]
    c2["tx"], c2["tz"] = c["tx"] + ox, c["tz"] + oz
    cameras.append(c2)
for l in S.loot:
    did = slice_district(l["x"], l["z"], 30)
    if did:
        loot.append(moved(l, did))

# --- New districts ----------------------------------------------------------------
def building(i, district, style, x, z, w, d, h, doors):
    buildings.append({"id": i, "district": district, "style": style, "x": x, "z": z, "w": w, "d": d, "h": h, "doors": doors})

def station(i, kind, x, z, district, **kw):
    s = {"id": i, "kind": kind, "x": x, "z": z, "district": district}
    s.update(kw)
    stations.append(s)

def prop(kind, x, z, w, h, d, **kw):
    p = {"kind": kind, "x": x, "z": z, "w": w, "h": h, "d": d}
    p.update(kw)
    props.append(p)

def item(kind, x, z, **kw):
    l = {"item": kind, "x": x, "z": z}
    l.update(kw)
    loot.append(l)

def camera(i, district, label, x, z, y, tx, tz):
    cameras.append({"id": i, "district": district, "x": x, "y": y, "z": z, "tx": tx, "ty": 1, "tz": tz, "label": label})

# Power Station
terrain["flats"].append({"x": 290, "z": -250, "radius": 60, "height": 3.2, "blend": 0.35, "paved": True})
building("ps_turbine", "power_station", "industrial", 280, -262, 30, 18, 8, [{"side": "s", "offset": 0, "width": 5}, {"side": "w", "offset": 0, "width": 4}])
building("ps_control", "power_station", "command", 318, -230, 12, 10, 4.5, [{"side": "w", "offset": 0, "width": 3}])
prop("fuel_tank", 250, -228, 6, 5, 6); prop("fuel_tank", 262, -226, 6, 5, 6)
prop("container", 305, -210, 6, 2.6, 2.5, color="#e67e22"); prop("crate_stack", 296, -236, 2, 1.6, 2)
prop("radar", 330, -262, 2.5, 6, 2.5)
station("breaker_power_station", "breaker", 263.8, -256, "power_station", label="Breaker")
station("ps_turbine_panel", "console", 290, -268, "power_station", label="Turbine control")
camera("cam_power", "power_station", "POWER STATION", 250, -215, 8, 282, -245)
item("assault_rifle", 284, -255, rarity="advanced"); item("ammo_medium", 290, -240, amount=60)
item("shield_cell", 316, -228, amount=2); item("ammo_shells", 300, -205, amount=10)

# Airfield (runway drawn as a wide road)
terrain["flats"].append({"x": -440, "z": -240, "radius": 105, "height": 3.0, "blend": 0.3, "paved": False})
building("af_hangar", "airfield", "warehouse", -470, -205, 34, 22, 9, [{"side": "e", "offset": 0, "width": 10}, {"side": "s", "offset": 8, "width": 4}])
building("af_tower", "airfield", "command", -405, -200, 9, 9, 7, [{"side": "s", "offset": 0, "width": 3}])
prop("container", -430, -175, 6, 2.6, 2.5, color="#95a5a6"); prop("crate_stack", -445, -190, 2, 1.6, 2)
prop("fuel_tank", -500, -175, 5, 4.5, 5); prop("helipad", -390, -170, 12, 0.2, 12)
station("breaker_airfield", "breaker", -452.8, -200, "airfield", label="Breaker")
station("af_tower_desk", "console", -405, -202, "airfield", label="Tower radio")
camera("cam_airfield", "airfield", "AIRFIELD", -420, -170, 9, -460, -210)
item("shotgun", -468, -205, rarity="advanced"); item("ammo_shells", -472, -198, amount=10)
item("assault_rifle", -405, -198, rarity="standard"); item("med_patch", -440, -186, amount=2)
item("ammo_medium", -380, -250, amount=60)

# Radio Station on the northern hill
terrain["flats"].append({"x": -60, "z": -330, "radius": 34, "height": 27.5, "blend": 0.55, "paved": True})
building("radio_hut", "radio_station", "command", -60, -334, 14, 10, 4.5, [{"side": "s", "offset": 0, "width": 3}])
prop("radar", -44, -326, 2.5, 6, 2.5); prop("radar", -76, -324, 2.5, 6, 2.5)
station("breaker_radio_station", "breaker", -53.0, -329.2, "radio_station", label="Breaker")
station("radio_console", "console", -64, -337, "radio_station", label="Long-range radio")
item("assault_rifle", -58, -333, rarity="advanced"); item("shield_cell", -70, -320, amount=2)

# Research Lab (west)
terrain["flats"].append({"x": -470, "z": 200, "radius": 50, "height": 3.0, "blend": 0.35, "paved": True})
building("lab_main", "research", "medical", -470, 196, 28, 16, 6, [{"side": "e", "offset": 0, "width": 4}, {"side": "n", "offset": -6, "width": 3}])
prop("server_rack", -480, 192, 1.2, 2.4, 4); prop("crate_stack", -448, 214, 2, 1.6, 2)
station("breaker_research", "breaker", -457.2, 200, "research", label="Breaker")
station("lab_terminal", "console", -466, 190.5, "research", label="Lab terminal")
camera("cam_research", "research", "RESEARCH LAB", -440, 225, 7, -468, 200)
item("shotgun", -472, 200, rarity="standard"); item("med_patch", -462, 202, amount=2)
item("ammo_light", -445, 190, amount=36)

# Coastal Village (south-east)
terrain["flats"].append({"x": 340, "z": 300, "radius": 62, "height": 2.8, "blend": 0.45, "paved": False})
for k, (hx, hz) in enumerate([(310, 280), (335, 272), (362, 285), (318, 318), (352, 322)]):
    building("village_hut_%d" % k, "village", "hut", hx, hz, 7, 6, 3.4, [{"side": "s" if hz < 300 else "n", "offset": 0, "width": 2}])
prop("wreck", 390, 350, 7, 2.2, 4); prop("crate_stack", 340, 300, 2, 1.6, 2)
station("breaker_village", "breaker", 331.8, 272, "village", label="Breaker")
camera("cam_village", "village", "COASTAL VILLAGE", 300, 300, 7, 338, 298)
item("assault_rifle", 312, 280, rarity="standard"); item("shotgun", 360, 322, rarity="standard")
item("ammo_medium", 336, 272, amount=60); item("ammo_shells", 318, 318, amount=10)
item("shield_cell", 362, 285, amount=2); item("med_patch", 352, 322, amount=2)

# Relays live on the roads between districts (task stations from the slice).
station("relay_road", "relay", -170, 22, "roads", label="Roadside relay")
station("relay_harbor", "relay", 300, 18, "roads", label="Harbor relay")

# --- Roads ------------------------------------------------------------------------
roads = [
    [[0, -6], [0, 60], [-5, 160], [0, 260], [3, 340], [6, 419]],          # CC -> Beach
    [[-20, -20], [-80, -5], [-170, 20], [-260, 45], [-312, 58]],          # CC -> Medical
    [[20, -20], [100, -10], [200, 5], [300, 20], [420, 40], [560, 55]],   # CC -> Harbor
    [[20, -30], [90, -90], [170, -170], [250, -225]],                     # CC -> Power
    [[-20, -40], [-60, -140], [-70, -230], [-62, -300]],                  # CC -> Radio
    [[-80, -5], [-200, -80], [-320, -160], [-420, -200]],                 # -> Airfield
    [[-312, 58], [-380, 120], [-440, 180]],                               # Medical -> Research
    [[300, 20], [330, 140], [335, 265]],                                  # -> Village
    [[-490, -245], [-340, -245]],                                         # runway
]
for r in S.roads:  # district-local slice roads
    did = slice_district(r[0][0], r[0][1], 0)
    if did and did != "central_command" and all(slice_district(x, z, 20) == did for x, z in r):
        ox, oz = OFFSETS[did]
        roads.append([[x + ox, z + oz] for x, z in r])

# --- Waypoints --------------------------------------------------------------------
W, E = {}, []
for name, (x, z) in S.W.items():
    did = slice_district(x, z)
    if did:
        ox, oz = OFFSETS[did]
        W[name] = [x + ox, z + oz]
for a, b in S.E:
    if a in W and b in W and slice_district(*S.W[a]) == slice_district(*S.W[b]):
        E.append([a, b])


def door_points(b, door, dist):
    """Door centre moved `dist` metres outward (negative = inward)."""
    side, off = door["side"], door.get("offset", 0)
    hw, hd = b["w"] / 2, b["d"] / 2
    if side == "n":
        return [b["x"] + off, b["z"] - hd - dist]
    if side == "s":
        return [b["x"] + off, b["z"] + hd + dist]
    if side == "e":
        return [b["x"] + hw + dist, b["z"] + off]
    return [b["x"] - hw - dist, b["z"] + off]


new_ids = {"power_station", "airfield", "radio_station", "research", "village"}
for b in buildings:
    if b["district"] not in new_ids:
        continue
    W[b["id"] + "_c"] = [b["x"], b["z"]]
    for k, door in enumerate(b["doors"]):
        din, dout = "%s_d%d_in" % (b["id"], k), "%s_d%d_out" % (b["id"], k)
        W[din] = door_points(b, door, -2.0)
        W[dout] = door_points(b, door, 4.0)
        E.extend([[b["id"] + "_c", din], [din, dout]])


def coast(x, z):
    d = -1e9
    for e in terrain["land"]:
        k = math.hypot((x - e["x"]) / e["rx"], (z - e["z"]) / e["rz"])
        ed = (1 - k) * min(e["rx"], e["rz"])
        d = max(d, ed)
    return d


def rects(margin):
    out = []
    for b in buildings:
        out.append((b["x"] - b["w"] / 2 - margin, b["z"] - b["d"] / 2 - margin, b["x"] + b["w"] / 2 + margin, b["z"] + b["d"] / 2 + margin))
    for p in props:
        if p["kind"] in ("helipad",):
            continue
        out.append((p["x"] - p["w"] / 2 - margin, p["z"] - p["d"] / 2 - margin, p["x"] + p["w"] / 2 + margin, p["z"] + p["d"] / 2 + margin))
    return out


def inside(r, x, z):
    return r[0] <= x <= r[2] and r[1] <= z <= r[3]


def seg_hits(r, a, b):
    """Segment a-b intersects axis-aligned rect r (Liang-Barsky)."""
    t0, t1 = 0.0, 1.0
    dx, dz = b[0] - a[0], b[1] - a[1]
    for p, q in ((-dx, a[0] - r[0]), (dx, r[2] - a[0]), (-dz, a[1] - r[1]), (dz, r[3] - a[1])):
        if p == 0:
            if q < 0:
                return False
        else:
            t = q / p
            if p < 0:
                t0 = max(t0, t)
            else:
                t1 = min(t1, t)
            if t0 > t1:
                return False
    return True


BLOCK = rects(1.0)
GRID = 20
grid = {}
for gz in range(-460, 461, GRID):
    for gx in range(-700, 701, GRID):
        if coast(gx, gz) < 10 or any(inside(r, gx, gz) for r in rects(3.0)):
            continue
        grid[(gx, gz)] = "g_%d_%d" % (gx, gz)
        W[grid[(gx, gz)]] = [gx, gz]
for (gx, gz), name in grid.items():
    for dx, dz in ((GRID, 0), (0, GRID), (GRID, GRID), (GRID, -GRID)):
        other = grid.get((gx + dx, gz + dz))
        if other and not any(seg_hits(r, (gx, gz), (gx + dx, gz + dz)) for r in BLOCK):
            E.append([name, other])
# Connect hand-made waypoints standing outside buildings to nearby grid nodes.
brects = rects(0.5)[:len(buildings)]
for name, (x, z) in list(W.items()):
    if name.startswith("g_") or any(inside(r, x, z) for r in brects):
        continue
    links = 0
    for (gx, gz), g in sorted(grid.items(), key=lambda kv: math.hypot(kv[0][0] - x, kv[0][1] - z))[:6]:
        if math.hypot(gx - x, gz - z) > 30:
            break
        if not any(seg_hits(r, (x, z), (gx, gz)) for r in BLOCK):
            E.append([name, g])
            links += 1
            if links >= 3:
                break

spawns = [dict(s) for s in S.spawns]

# Drivable vehicles: buggies in every district, prop planes on the airfield.
HALF_PI = math.pi / 2
vehicles = [
    {"type": "buggy", "x": 26, "z": 8, "yaw": math.pi},
    {"type": "buggy", "x": 32, "z": 8, "yaw": math.pi},
    {"type": "buggy", "x": -300, "z": 92, "yaw": HALF_PI},
    {"type": "buggy", "x": 548, "z": 78, "yaw": -HALF_PI},
    {"type": "buggy", "x": 24, "z": 392, "yaw": 0.0},
    {"type": "buggy", "x": 262, "z": -205, "yaw": 0.6},
    {"type": "buggy", "x": 322, "z": 250, "yaw": math.pi},
    {"type": "buggy", "x": -438, "z": 228, "yaw": HALF_PI},
    {"type": "buggy", "x": -395, "z": -215, "yaw": 0.0},
    {"type": "buggy", "x": -48, "z": -305, "yaw": math.pi},
    {"type": "prop_plane", "x": -482, "z": -245, "yaw": -HALF_PI},
    {"type": "prop_plane", "x": -470, "z": -262, "yaw": -HALF_PI},
    {"type": "prop_plane", "x": -470, "z": -228, "yaw": -HALF_PI},
]

out = {
    "id": "island", "name": "Traitor Island",
    "terrain": terrain,
    "grid": {"origin": [-800, -560], "size": [1600, 1120], "cell": 2.0},
    "collision": {"center": [0, 0], "size": 1600},
    "boundary": {"x": 0, "z": 10, "rx": 730, "rz": 500, "segments": 72, "height": 30},
    "sun_direction": S.__dict__.get("sun_direction", [0.72, 0.075, -0.69]),
    "vegetation": {"area": [-680, -460, 680, 470], "samples": 70000, "palms": 1500},
    "districts": districts, "buildings": buildings, "props": props, "stations": stations,
    "cameras": cameras, "spawns": spawns, "loot": loot, "roads": roads,
    "meeting_center": [0, -22], "medical_respawn": ["med_pod_1", "med_pod_2"],
    "generators": ["gen_a", "gen_b", "gen_c"],
    "features": [],
    "lockable_buildings": ["cc_hall", "cc_annex", "med_center", "harbor_warehouse"],
    "medical_center_respawn": [-330, 74],
    "drop": {"from": [-760, -420], "to": [760, 440]},
    "vehicles": vehicles,
    "waypoints": W, "edges": E,
}
json.dump(out, open("game/data/maps/island.json", "w"), separators=(",", ":"))
print("buildings", len(buildings), "stations", len(stations), "waypoints", len(W), "edges", len(E))
