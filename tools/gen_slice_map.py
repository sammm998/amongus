#!/usr/bin/env python3
"""Generates game/data/maps/slice.json (M2 vertical-slice map).
Coordinates: metres, x = east, z = south, y from the terrain. Run from repo root."""
import json, math

terrain = {
    "sea_floor": -16, "land_level": 2.4, "beach_width": 12, "shelf_width": 26, "shelf_depth": 2.5, "dropoff": 60,
    "noise": {"amplitude": 1.6, "frequency": 0.02, "seed": 21},
    "land": [
        {"x": 0, "z": -15, "rx": 185, "rz": 118},
        {"x": -80, "z": 100, "rx": 50, "rz": 30},
    ],
    "hills": [
        {"x": 0, "z": -110, "radius": 60, "height": 16},
        {"x": -120, "z": -92, "radius": 50, "height": 12},
        {"x": 90, "z": -98, "radius": 45, "height": 9},
        {"x": -165, "z": 20, "radius": 35, "height": 8},
        {"x": 70, "z": 55, "radius": 40, "height": 6},
    ],
    "flats": [
        {"x": 0, "z": -18, "radius": 52, "height": 3.0, "blend": 0.35, "paved": True},
        {"x": -115, "z": -18, "radius": 34, "height": 2.8, "blend": 0.35, "paved": True},
        {"x": 148, "z": -22, "radius": 38, "height": 2.6, "blend": 0.3, "paved": True},
        {"x": 0, "z": 40, "radius": 16, "height": 2.7, "blend": 0.6},
    ],
}

districts = [
    {"id": "central_command", "name": "Central Command", "x": 0, "z": -20, "radius": 55, "color": "#1f3a66", "accent": "#2de2e6"},
    {"id": "medical", "name": "Medical Center", "x": -115, "z": -18, "radius": 42, "color": "#e8f4f2", "accent": "#18b3a8"},
    {"id": "harbor", "name": "Harbor", "x": 150, "z": -20, "radius": 48, "color": "#2a5d8f", "accent": "#b5562c"},
    {"id": "beach", "name": "Sunset Beach", "x": -10, "z": 100, "radius": 70, "color": "#f5e4c3", "accent": "#ff9f5a"},
    {"id": "roads", "name": "Island Road", "x": 0, "z": 30, "radius": 400, "color": "#666666", "accent": "#ffcc33"},
]

# Buildings: axis-aligned halls with door gaps. doors: side n/s/e/w, offset along the side, width.
buildings = [
    {"id": "cc_hall", "district": "central_command", "style": "command", "x": 0, "z": -20, "w": 36, "d": 26, "h": 6.5,
     "doors": [{"side": "s", "offset": 0, "width": 4}, {"side": "n", "offset": 0, "width": 4},
               {"side": "e", "offset": 0, "width": 3.5}, {"side": "w", "offset": 0, "width": 3.5}]},
    {"id": "cc_annex", "district": "central_command", "style": "industrial", "x": 32, "z": -44, "w": 12, "d": 16, "h": 4.5,
     "doors": [{"side": "w", "offset": 0, "width": 4}]},
    {"id": "med_center", "district": "medical", "style": "medical", "x": -115, "z": -20, "w": 26, "d": 18, "h": 5.5,
     "doors": [{"side": "e", "offset": 0, "width": 4}, {"side": "s", "offset": 0, "width": 3.5}]},
    {"id": "harbor_warehouse", "district": "harbor", "style": "warehouse", "x": 140, "z": -40, "w": 24, "d": 14, "h": 7,
     "doors": [{"side": "w", "offset": 0, "width": 5}, {"side": "s", "offset": 0, "width": 5}]},
    {"id": "beach_hut", "district": "beach", "style": "hut", "x": 18, "z": 86, "w": 6, "d": 5, "h": 3.2,
     "doors": [{"side": "s", "offset": 0, "width": 2}]},
]

# Props with collision (x, z, size w/h/d, kind) — furniture, containers, wreck.
props = [
    {"kind": "meeting_table", "x": 0, "z": -22, "w": 6, "h": 1.0, "d": 6},
    {"kind": "monitor_wall", "x": -10, "z": -32.2, "w": 9, "h": 3.2, "d": 0.6},
    {"kind": "server_rack", "x": 16.5, "z": -11, "w": 1.2, "h": 2.4, "d": 4},
    {"kind": "container", "x": 152, "z": -2, "w": 6, "h": 2.6, "d": 2.5, "color": "#c0392b"},
    {"kind": "container", "x": 160, "z": -4, "w": 6, "h": 2.6, "d": 2.5, "color": "#2980b9"},
    {"kind": "container", "x": 156, "z": 2, "w": 6, "h": 2.6, "d": 2.5, "color": "#f1c40f"},
    {"kind": "container", "x": 146, "z": 4, "w": 2.5, "h": 2.6, "d": 6, "color": "#27ae60"},
    {"kind": "fuel_tank", "x": 132, "z": -8, "w": 5, "h": 4.5, "d": 5},
    {"kind": "crane", "x": 172, "z": -32, "w": 4, "h": 16, "d": 4},
    {"kind": "wreck", "x": -30, "z": 99, "w": 7, "h": 2.2, "d": 4},
    {"kind": "radar", "x": 8, "z": -44, "w": 2.5, "h": 6, "d": 2.5},
    {"kind": "crate_stack", "x": -8, "z": 2, "w": 2, "h": 1.6, "d": 2},
    {"kind": "crate_stack", "x": 24, "z": -6, "w": 2, "h": 1.6, "d": 3},
    {"kind": "crate_stack", "x": 120, "z": -20, "w": 3, "h": 1.6, "d": 2},
    {"kind": "helipad", "x": -115, "z": 8, "w": 12, "h": 0.2, "d": 12},
]

# Interactive stations: id, kind, x, z, district. kind drives visuals + interaction.
S = []
def st(i, kind, x, z, district, **kw):
    d = {"id": i, "kind": kind, "x": x, "z": z, "district": district}
    d.update(kw)
    S.append(d)

st("cc_security", "console", -12.5, -31, "central_command", label="Security console")
st("security_reset", "security_desk", -7.5, -31, "central_command", label="Camera network reset")
st("cc_comms", "console", 12, -31, "central_command", label="Comms array")
st("cc_server", "console", 15, -13, "central_command", label="Server racks")
st("emergency_button", "button", 0, -17.6, "central_command", label="Emergency button")
st("cc_power_1", "console", 36, -50, "central_command", label="Generator control A")
st("cc_power_2", "console", 36, -38, "central_command", label="Generator control B")
st("gen_a", "generator", 30, -49, "central_command", label="Generator A")
st("gen_b", "generator", 30, -44, "central_command", label="Generator B")
st("gen_c", "generator", 30, -39, "central_command", label="Generator C")
st("cc_roof_radar", "console", 8, -40.5, "central_command", label="Radar calibration")
st("breaker_central_command", "breaker", -19.2, -12, "central_command", label="Breaker")
st("med_pharmacy", "console", -124, -26.5, "medical", label="Pharmacy")
st("med_records", "console", -107, -26.5, "medical", label="Records terminal")
st("med_pod_1", "medpod", -121, -14, "medical", label="Revival station")
st("med_pod_2", "medpod", -109, -14, "medical", label="Revival station")
st("breaker_medical", "breaker", -101.2, -14, "medical", label="Breaker")
st("harbor_office", "console", 133, -45, "harbor", label="Harbor office")
st("harbor_cargo", "crate", 150, -9, "harbor", label="Cargo")
st("harbor_crane", "console", 168, -27, "harbor", label="Crane controls")
st("harbor_fuel", "console", 136, -12, "harbor", label="Fuel pump")
st("harbor_generator", "generator", 126, -27, "harbor", label="Harbor generator")
st("breaker_harbor", "breaker", 127.2, -35, "harbor", label="Breaker")
st("beacon_harbor", "beacon", 199, -15, "harbor", label="Harbor beacon")
st("relay_road", "relay", -60, -14, "roads", label="Roadside relay")
st("relay_harbor", "relay", 90, -26, "roads", label="Harbor relay")
st("relay_beach", "relay", 30, 97, "beach", label="Beach relay")
st("crash_beach", "wreck_site", -26, 95, "beach", label="Crash site")
st("beacon_point", "beacon", -86, 117, "beach", label="Point beacon")
st("breaker_beach", "breaker", 18, 88.9, "beach", label="Breaker")
st("cc_uplink_a", "console", -15.5, -25, "central_command", label="Uplink console A")
st("cc_uplink_b", "console", 15.5, -27, "central_command", label="Uplink console B")
# Facility door-override panels (Security Door Lock repairs).
st("panel_cc_hall", "door_panel", 3.2, -5.4, "central_command", label="Door override", building="cc_hall")
st("panel_cc_annex", "door_panel", 23.8, -48.5, "central_command", label="Door override", building="cc_annex")
st("panel_med_center", "door_panel", -99.8, -24.5, "medical", label="Door override", building="med_center")
st("panel_harbor_warehouse", "door_panel", 125.8, -44.5, "harbor", label="Door override", building="harbor_warehouse")

# Security cameras: position, look-at target (world, y = metres above ground).
cameras = [
    {"id": "cam_cc", "district": "central_command", "x": 14, "y": 7, "z": 2, "tx": 0, "ty": 1, "tz": -12, "label": "CENTRAL COMMAND"},
    {"id": "cam_medical", "district": "medical", "x": -96, "y": 7, "z": -2, "tx": -110, "ty": 1, "tz": -14, "label": "MEDICAL CENTER"},
    {"id": "cam_harbor", "district": "harbor", "x": 120, "y": 8, "z": -10, "tx": 150, "ty": 1, "tz": -12, "label": "HARBOR"},
    {"id": "cam_beach", "district": "beach", "x": -5, "y": 9, "z": 72, "tx": -10, "ty": 1, "tz": 98, "label": "SUNSET BEACH"},
]

spawns = []
for i in range(12):
    a = math.radians(-30 + i * 22)
    spawns.append({"x": round(math.sin(a) * 3 + (i - 5.5) * 3.2, 1), "z": round(4 + (i % 3) * 3.0, 1)})

loot = [
    {"item": "assault_rifle", "rarity": "standard", "x": 137, "z": -37},
    {"item": "assault_rifle", "rarity": "advanced", "x": -112, "z": -24},
    {"item": "assault_rifle", "rarity": "standard", "x": -24, "z": 99},
    {"item": "shotgun", "rarity": "standard", "x": 158, "z": -10},
    {"item": "shotgun", "rarity": "standard", "x": -130, "z": -6},
    {"item": "shotgun", "rarity": "advanced", "x": 40, "z": 99},
    {"item": "ammo_medium", "amount": 60, "x": 140, "z": -36},
    {"item": "ammo_medium", "amount": 60, "x": -118, "z": -24},
    {"item": "ammo_medium", "amount": 60, "x": -20, "z": 97},
    {"item": "ammo_shells", "amount": 10, "x": 160, "z": -12},
    {"item": "ammo_shells", "amount": 10, "x": -128, "z": -8},
    {"item": "ammo_shells", "amount": 10, "x": 42, "z": 96},
    {"item": "ammo_light", "amount": 36, "x": 10, "z": -10},
    {"item": "ammo_light", "amount": 36, "x": 60, "z": -30},
    {"item": "ammo_light", "amount": 36, "x": -60, "z": -22},
    {"item": "med_patch", "amount": 2, "x": -116, "z": -27},
    {"item": "med_patch", "amount": 2, "x": -104, "z": -16},
    {"item": "shield_cell", "amount": 2, "x": 145, "z": -44},
    {"item": "shield_cell", "amount": 2, "x": 5, "z": 92},
]

roads = [
    [[0, -6], [0, 20], [0, 50], [2, 80], [6, 92]],
    [[20, -20], [45, -24], [70, -28], [95, -30], [124, -40]],
    [[-20, -20], [-45, -20], [-70, -18], [-100, -20]],
    [[140, -32], [142, -22], [150, -16], [176, -15]],
]

W = {}
def wp(i, x, z):
    W[i] = [x, z]
E = []
def chain(*ids):
    for a, b in zip(ids, ids[1:]):
        E.append([a, b])

# Central Command hall interior + doors
wp("cc_c", 0, -16); wp("cc_w", -12, -20); wp("cc_e", 12, -20); wp("cc_n", 0, -28)
wp("cc_nw", -10, -28); wp("cc_ne", 12, -28); wp("cc_se", 13, -12); wp("cc_sw", -12, -12)
wp("cc_ds_in", 0, -10); wp("cc_ds_out", 0, -3); wp("cc_dn_in", 0, -30.5); wp("cc_dn_out", 0, -37)
wp("cc_de_in", 15.5, -20); wp("cc_de_out", 21, -20); wp("cc_dw_in", -15.5, -20); wp("cc_dw_out", -21, -20)
chain("cc_ds_out", "cc_ds_in", "cc_c"); chain("cc_c", "cc_sw", "cc_w", "cc_nw", "cc_n", "cc_ne", "cc_e", "cc_se", "cc_c")
chain("cc_w", "cc_dw_in", "cc_dw_out"); chain("cc_e", "cc_de_in", "cc_de_out"); chain("cc_n", "cc_dn_in", "cc_dn_out")
chain("cc_ds_in", "cc_sw"); chain("cc_ds_in", "cc_se")
# Annex
wp("an_out", 22, -44); wp("an_in", 28, -44); wp("an_n", 33, -49); wp("an_s", 33, -39)
chain("cc_de_out", "an_out", "an_in", "an_n"); chain("an_in", "an_s")
# Exterior around CC
wp("ex_s", 0, 2); wp("ex_sw", -22, 0); wp("ex_se", 22, -2); wp("ex_n", 0, -42); wp("ex_nw", -22, -40); wp("ex_ne", 16, -44)
wp("breaker_cc_wp", -21, -12); wp("cc_upa", -13, -24); wp("cc_upb", 13, -26); wp("radar_wp", 4, -42)
chain("cc_ds_out", "ex_s"); chain("ex_s", "ex_sw", "cc_dw_out"); chain("ex_s", "ex_se", "cc_de_out")
chain("cc_dw_out", "breaker_cc_wp"); chain("cc_w", "cc_upa"); chain("cc_e", "cc_upb"); chain("cc_dn_out", "ex_n", "radar_wp"); chain("ex_n", "ex_nw", "cc_dw_out"); chain("ex_n", "ex_ne", "an_out")
# Road west to Medical
wp("rw1", -40, -20); wp("rw2", -60, -18); wp("rw3", -85, -20)
wp("med_de_out", -97, -20); wp("med_de_in", -105, -20); wp("med_c", -115, -20)
wp("med_ph", -122, -24); wp("med_rc", -108, -24); wp("med_p1", -120, -16.5); wp("med_p2", -110, -16.5)
wp("med_ds_in", -115, -14); wp("med_ds_out", -115, -6); wp("heli", -115, 8); wp("breaker_med_wp", -99, -14)
chain("cc_dw_out", "rw1", "rw2", "rw3", "med_de_out", "med_de_in", "med_c")
chain("med_c", "med_ph"); chain("med_c", "med_rc"); chain("med_c", "med_p1"); chain("med_c", "med_p2")
chain("med_c", "med_ds_in", "med_ds_out", "heli"); chain("med_de_out", "breaker_med_wp")
wp("med_west", -134, -6); chain("med_ds_out", "med_west")
# Road east to Harbor
wp("re1", 40, -24); wp("re2", 65, -28); wp("re3", 90, -30); wp("re4", 112, -36)
wp("hw_out", 123, -40); wp("hw_in", 131, -40); wp("wh_c", 140, -40); wp("wh_off", 134, -43)
wp("hs_in", 140, -36); wp("hs_out", 140, -29); wp("hy1", 142, -20); wp("hy_cargo", 150, -12)
wp("hy_fuel", 138, -14); wp("hy_crane", 166, -24); wp("pier_s", 176, -15); wp("pier_e", 197, -15)
wp("hgen", 124, -28); wp("breaker_h_wp", 124, -35); wp("hy_cont", 160, -12)
chain("cc_de_out", "re1", "re2", "re3", "re4", "hw_out", "hw_in", "wh_c", "wh_off")
chain("wh_c", "hs_in", "hs_out", "hy1", "hy_cargo", "hy_cont", "hy_crane"); chain("hy1", "hy_fuel"); chain("hy_cargo", "pier_s", "pier_e")
chain("hw_out", "breaker_h_wp", "hgen", "hy1"); chain("hy_crane", "pier_s")
# Road south to the beach
wp("rs1", 0, 15); wp("rs2", 0, 40); wp("rs3", 2, 65); wp("beach_c", 6, 92); wp("crash", -24, 93)
wp("relay_b", 28, 94); wp("hut", 18, 91); wp("bw1", -45, 100); wp("bw2", -70, 108); wp("beacon", -84, 114)
wp("loot_b", 40, 96)
chain("ex_s", "rs1", "rs2", "rs3", "beach_c", "crash", "bw1", "bw2", "beacon"); chain("beach_c", "hut"); chain("beach_c", "relay_b", "loot_b")
chain("crash", "loot_b") if False else None
# Road relay and connections
wp("relay_r", -60, -15); chain("rw2", "relay_r"); wp("relay_h", 90, -27); chain("re3", "relay_h")
wp("mid_e", 40, 30); chain("rs2", "mid_e", "re2")
wp("mid_w", -50, 30); chain("rs2", "mid_w", "rw2")

out = {
    "id": "slice", "name": "Sunset Island — Slice",
    "terrain": terrain,
    "collision": {"center": [0, -10], "size": 440},
    "boundary": {"x": 0, "z": -10, "rx": 205, "rz": 145, "segments": 40, "height": 30},
    "sun_direction": [0.72, 0.075, -0.69],
    "districts": districts, "buildings": buildings, "props": props, "stations": S,
    "cameras": cameras, "spawns": spawns, "loot": loot, "roads": roads,
    "meeting_center": [0, -22], "medical_respawn": ["med_pod_1", "med_pod_2"],
    "generators": ["gen_a", "gen_b", "gen_c"],
    "features": [],
    "lockable_buildings": ["cc_hall", "cc_annex", "med_center", "harbor_warehouse"],
    "medical_center_respawn": [-115, -4],
    "waypoints": W, "edges": E,
}
json.dump(out, open("game/data/maps/slice.json", "w"), indent=1)
print("stations", len(S), "waypoints", len(W), "edges", len(E))
