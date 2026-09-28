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


static func _wrap(kit: MeshKit) -> Node3D:
	var root := Node3D.new()
	root.add_child(kit.to_instance())
	return root
