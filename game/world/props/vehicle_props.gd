class_name VehicleProps
extends RefCounted
## Chunky toy-like vehicle meshes (visual only; drivable vehicles come in M4).

const HULL := Color(0.93, 0.93, 0.9)
const STRIPE := Color(1.0, 0.45, 0.15)
const DARK := Color(0.15, 0.17, 0.2)


## Motorboat, bow toward -Z.
static func boat() -> Node3D:
	var kit := MeshKit.new()
	kit.add_box(Transform3D(Basis(), Vector3(0, 0.5, 0.5)), Vector3(3.0, 1.2, 6.5), HULL, MeshKit.SLOT_GLOSS)
	var bow := Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	kit.add_prism(Transform3D(bow, Vector3(0, 0.5, -3.6)), Vector3(3.0, 1.8, 1.2), HULL, MeshKit.SLOT_GLOSS)
	kit.add_box(Transform3D(Basis(), Vector3(0, 0.75, 0.5)), Vector3(3.05, 0.25, 6.55), STRIPE)
	kit.add_box(Transform3D(Basis(), Vector3(0, 1.1, 0.5)), Vector3(2.7, 0.1, 6.0), Color(0.7, 0.55, 0.38))
	kit.add_box(Transform3D(Basis(), Vector3(0, 1.8, 0.9)), Vector3(2.0, 1.3, 2.2), HULL, MeshKit.SLOT_GLOSS)
	kit.add_box(Transform3D(Basis(), Vector3(0, 1.95, -0.22)), Vector3(1.8, 0.7, 0.05), DARK, MeshKit.SLOT_GLASS)
	kit.add_box(Transform3D(Basis(), Vector3(0, 2.5, 0.9)), Vector3(2.2, 0.12, 2.4), STRIPE)
	kit.add_box(Transform3D(Basis(), Vector3(0, 1.2, 3.9)), Vector3(0.9, 1.0, 0.6), DARK, MeshKit.SLOT_METAL)
	return _wrap(kit)


## Small jet, nose toward -Z.
static func small_jet(body: Color = HULL, accent: Color = Color(0.2, 0.55, 0.9)) -> Node3D:
	var kit := MeshKit.new()
	kit.add_capsule(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.3, 0)), 0.7, 7.5, body, MeshKit.SLOT_GLOSS)
	kit.add_sphere(Transform3D(Basis().scaled(Vector3(0.5, 0.45, 1.0)), Vector3(0, 1.8, -1.8)), 1.0, DARK, 12, MeshKit.SLOT_GLASS)
	kit.add_box(Transform3D(Basis(), Vector3(0, 1.1, 0.3)), Vector3(8.0, 0.18, 1.8), body, MeshKit.SLOT_GLOSS)
	kit.add_box(Transform3D(Basis(), Vector3(0, 1.3, 3.2)), Vector3(3.0, 0.14, 1.0), body)
	kit.add_box(Transform3D(Basis(), Vector3(0, 2.2, 3.3)), Vector3(0.14, 1.6, 1.2), accent)
	kit.add_box(Transform3D(Basis(), Vector3(0, 1.3, 0.0)), Vector3(1.45, 0.25, 6.0), accent)
	for side: float in [-1.0, 1.0]:
		kit.add_cylinder(Transform3D(Basis(), Vector3(side * 1.2, 0.35, 0.5)), 0.3, 0.3, 0.3, DARK, 10)
	kit.add_cylinder(Transform3D(Basis(), Vector3(0, 0.35, -2.5)), 0.25, 0.25, 0.3, DARK, 10)
	return _wrap(kit)


## Off-road buggy, nose toward -Z (drivable; 2.2 x 1.3 x 3.8 m).
static func buggy(paint: Color = Color(0.85, 0.32, 0.12)) -> Node3D:
	var kit := MeshKit.new()
	kit.add_box(Transform3D(Basis(), Vector3(0, 0.75, 0)), Vector3(1.9, 0.35, 3.6), paint, MeshKit.SLOT_GLOSS)
	kit.add_box(Transform3D(Basis(), Vector3(0, 0.95, -1.35)), Vector3(1.7, 0.3, 0.9), paint, MeshKit.SLOT_GLOSS)
	kit.add_box(Transform3D(Basis(), Vector3(0, 0.62, 0)), Vector3(2.0, 0.12, 3.7), DARK)
	for x: float in [-0.45, 0.45]:
		kit.add_box(Transform3D(Basis(), Vector3(x, 1.05, 0.2)), Vector3(0.6, 0.25, 0.6), DARK)
		kit.add_box(Transform3D(Basis(), Vector3(x, 1.35, 0.5)), Vector3(0.6, 0.6, 0.12), DARK)
	# Roll cage.
	var bar := Color(0.12, 0.12, 0.13)
	for x: float in [-0.85, 0.85]:
		kit.add_beam(Vector3(x, 0.95, 0.9), Vector3(x * 0.9, 2.0, 0.6), 0.05, bar, MeshKit.SLOT_METAL)
		kit.add_beam(Vector3(x, 0.95, -0.5), Vector3(x * 0.9, 2.0, -0.1), 0.05, bar, MeshKit.SLOT_METAL)
		kit.add_beam(Vector3(x * 0.9, 2.0, 0.6), Vector3(x * 0.9, 2.0, -0.1), 0.05, bar, MeshKit.SLOT_METAL)
	kit.add_beam(Vector3(-0.77, 2.0, 0.6), Vector3(0.77, 2.0, 0.6), 0.05, bar, MeshKit.SLOT_METAL)
	kit.add_beam(Vector3(-0.77, 2.0, -0.1), Vector3(0.77, 2.0, -0.1), 0.05, bar, MeshKit.SLOT_METAL)
	# Wheels.
	for x: float in [-1.05, 1.05]:
		for z: float in [-1.25, 1.25]:
			kit.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x, 0.45, z)), 0.45, 0.45, 0.4, Color(0.08, 0.08, 0.09), 14)
			kit.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x * 1.01, 0.45, z)), 0.22, 0.22, 0.42, Color(0.7, 0.7, 0.72), 10, MeshKit.SLOT_METAL)
	kit.add_box(Transform3D(Basis(), Vector3(-0.6, 0.8, -1.82)), Vector3(0.3, 0.15, 0.05), Color(1, 0.95, 0.8), MeshKit.SLOT_GLOW)
	kit.add_box(Transform3D(Basis(), Vector3(0.6, 0.8, -1.82)), Vector3(0.3, 0.15, 0.05), Color(1, 0.95, 0.8), MeshKit.SLOT_GLOW)
	return _wrap(kit)


## Single-engine prop plane, nose toward -Z (drivable). The propeller is a
## separate child named "Prop" so it can spin.
static func prop_plane(paint: Color = Color(0.92, 0.92, 0.9), stripe: Color = Color(0.1, 0.35, 0.7)) -> Node3D:
	var kit := MeshKit.new()
	kit.add_capsule(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.2, 0.2)), 0.65, 6.6, paint, MeshKit.SLOT_GLOSS)
	kit.add_box(Transform3D(Basis(), Vector3(0, 1.2, 0.2)), Vector3(1.32, 0.18, 5.4), stripe)
	kit.add_sphere(Transform3D(Basis().scaled(Vector3(0.55, 0.45, 1.0)), Vector3(0, 1.75, -0.7)), 0.9, DARK, 12, MeshKit.SLOT_GLASS)
	kit.add_box(Transform3D(Basis(), Vector3(0, 1.75, -0.3)), Vector3(9.5, 0.14, 1.5), paint, MeshKit.SLOT_GLOSS)
	kit.add_box(Transform3D(Basis(), Vector3(-4.3, 1.78, -0.3)), Vector3(0.9, 0.15, 1.52), stripe)
	kit.add_box(Transform3D(Basis(), Vector3(4.3, 1.78, -0.3)), Vector3(0.9, 0.15, 1.52), stripe)
	kit.add_box(Transform3D(Basis(), Vector3(0, 1.4, 3.2)), Vector3(3.2, 0.1, 0.9), paint)
	kit.add_box(Transform3D(Basis(), Vector3(0, 2.05, 3.3)), Vector3(0.1, 1.3, 1.0), stripe)
	kit.add_cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.2, -3.2)), 0.25, 0.5, 0.5, DARK, 10, MeshKit.SLOT_METAL)
	for x: float in [-1.0, 1.0]:
		kit.add_beam(Vector3(x * 0.4, 0.9, -0.6), Vector3(x * 1.0, 0.35, -0.6), 0.05, DARK)
		kit.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(x * 1.0, 0.3, -0.6)), 0.3, 0.3, 0.2, Color(0.08, 0.08, 0.09), 10)
	kit.add_cylinder(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, 0.2, 3.0)), 0.15, 0.15, 0.12, Color(0.08, 0.08, 0.09), 8)
	var root := _wrap(kit)
	var prop_kit := MeshKit.new()
	prop_kit.add_box(Transform3D(), Vector3(0.18, 2.2, 0.06), DARK, MeshKit.SLOT_METAL)
	var prop := prop_kit.to_instance()
	prop.name = "Prop"
	prop.position = Vector3(0, 1.2, -3.5)
	root.add_child(prop)
	return root


static func _wrap(kit: MeshKit) -> Node3D:
	var root := Node3D.new()
	root.add_child(kit.to_instance())
	return root
