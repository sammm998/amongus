class_name AstronautPlaceholder
extends Node3D
## Primitive chibi explorer (GAME_SPEC §2): capsule suit, big round helmet,
## dark glossy visor, chunky backpack, capsule limbs, with a procedural idle.
## Visor colour is cosmetic only — never tied to role.

@export var suit_color := Color(0.95, 0.95, 0.97)
@export var accent_color := Color(1.0, 0.45, 0.7)
@export var idle_phase := 0.0

var _body: Node3D
var _time := 0.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	_time += delta
	var t := _time * 2.2 + idle_phase
	_body.position.y = 0.03 * sin(t)
	_body.rotation.z = 0.03 * sin(t * 0.5)


func _build() -> void:
	_body = Node3D.new()
	add_child(_body)
	var suit := _material(suit_color, 0.55)
	var accent := _material(accent_color, 0.5)
	var visor := _material(Color(0.05, 0.06, 0.1), 0.08)
	visor.metallic = 0.6
	visor.clearcoat_enabled = true
	visor.rim_enabled = true
	visor.rim = 0.6
	var helmet := _material(suit_color, 0.25)
	helmet.clearcoat_enabled = true
	helmet.clearcoat = 1.0

	_part(_capsule(0.32, 0.9), suit, Vector3(0, 0.75, 0))                        # torso
	_part(_sphere(0.42), helmet, Vector3(0, 1.45, 0))                              # helmet
	_part(_sphere(0.3), visor, Vector3(0, 1.47, 0.2), Vector3(1.25, 0.8, 0.7))     # visor
	_part(_box(Vector3(0.5, 0.55, 0.28)), accent, Vector3(0, 0.9, -0.36))         # backpack
	_part(_box(Vector3(0.3, 0.1, 0.06)), suit, Vector3(0, 1.0, -0.51))            # backpack panel
	for side: float in [-1.0, 1.0]:
		_part(_capsule(0.11, 0.55), suit, Vector3(0.4 * side, 0.85, 0), Vector3.ONE, Vector3(0, 0, 0.35 * side))  # arms
		_part(_sphere(0.12), accent, Vector3(0.5 * side, 0.6, 0))                                                  # gloves
		_part(_capsule(0.13, 0.5), suit, Vector3(0.16 * side, 0.25, 0))                                            # legs
		_part(_box(Vector3(0.24, 0.14, 0.34)), accent, Vector3(0.16 * side, 0.05, 0.04))                         # boots


func _part(mesh: Mesh, material: Material, pos: Vector3, scale_v := Vector3.ONE, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.scale = scale_v
	mi.rotation = rot
	_body.add_child(mi)


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m


static func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
