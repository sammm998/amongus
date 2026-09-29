class_name DropVisuals
extends RefCounted
## Procedural meshes for the opening drop: the transport plane and a parachute
## canopy (original designs; colours never hint at roles).

const CANOPY_A := Color(0.93, 0.38, 0.16)
const CANOPY_B := Color(0.95, 0.93, 0.88)


static func plane() -> Node3D:
	var kit := MeshKit.new()
	var body := Color(0.78, 0.8, 0.82)
	var dark := Color(0.2, 0.22, 0.25)
	var stripe := Color(0.12, 0.3, 0.55)
	# Fuselage along -Z (forward), nose cone and tail cone.
	kit.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 2.1, 2.1, 22.0, body, 16, MeshKit.SLOT_METAL)
	kit.add_cylinder(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -13.5)), 0.4, 2.1, 5.0, body, 16, MeshKit.SLOT_METAL)
	kit.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.5, 14.0)), 0.5, 2.1, 6.0, body, 16, MeshKit.SLOT_METAL)
	kit.add_box(Transform3D(Basis(), Vector3(0, 0.2, 0)), Vector3(4.3, 0.5, 18.0), stripe)
	kit.add_box(Transform3D(Basis(), Vector3(0, 0.9, -13.2)), Vector3(2.4, 0.8, 1.6), dark, MeshKit.SLOT_GLASS)
	# High wing with four engines.
	kit.add_box(Transform3D(Basis(), Vector3(0, 1.9, -2.0)), Vector3(38.0, 0.45, 5.0), body, MeshKit.SLOT_METAL)
	for x: float in [-12.0, -6.5, 6.5, 12.0]:
		kit.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x, 1.2, -3.6)), 0.75, 0.75, 3.4, dark, 12, MeshKit.SLOT_METAL)
		kit.add_box(Transform3D(Basis(), Vector3(x, 1.2, -5.4)), Vector3(3.2, 0.12, 0.25), dark)
	# Tail.
	kit.add_box(Transform3D(Basis(), Vector3(0, 1.4, 16.0)), Vector3(13.0, 0.3, 3.0), body, MeshKit.SLOT_METAL)
	kit.add_box(Transform3D(Basis(), Vector3(0, 4.3, 16.2)), Vector3(0.35, 6.0, 3.6), stripe)
	var root := Node3D.new()
	var mi := kit.to_instance()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return root


## Canopy above a player's feet origin, with suspension lines to the shoulders.
static func canopy() -> Node3D:
	var kit := MeshKit.new()
	var cells := 7
	for i in cells:
		var t := (float(i) / (cells - 1)) - 0.5
		var x := t * 5.6
		var y := 5.2 - absf(t) * absf(t) * 2.4
		var xf := Transform3D(Basis(Vector3.FORWARD, -t * 1.2), Vector3(x, y, 0))
		kit.add_box(xf, Vector3(0.86, 0.22, 2.2), CANOPY_A if i % 2 == 0 else CANOPY_B)
	var line := Color(0.15, 0.15, 0.15)
	for x: float in [-2.8, -1.4, 1.4, 2.8]:
		for z: float in [-0.9, 0.9]:
			kit.add_beam(Vector3(signf(x) * 0.25, 1.5, 0), Vector3(x, 5.2 - (x / 5.6) * (x / 5.6) * 2.4 - 0.1, z), 0.025, line)
	var root := Node3D.new()
	var mi := kit.to_instance()
	mi.layers = RenderLayers.AVATARS
	root.add_child(mi)
	root.visible = false
	return root
