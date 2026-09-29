class_name Astronaut
extends Node3D
## Chibi space explorer built from primitives (GAME_SPEC §2) with procedural
## idle/walk: body bob, limb swing, lean into movement.
## The visor tint is cosmetic only and never tied to a role.

const HELMET_SCALE := 1.0

@export var suit_color := Color(0.96, 0.96, 0.98)
@export var accent_color := Color(1.0, 0.45, 0.72)
@export var visor_tint := Color(0.05, 0.06, 0.1)
## 0 = idle, 1 = full run. Set by the controller each frame.
@export var move_blend := 0.0
@export var phase_offset := 0.0

var downed := false
var _body: Node3D
var _torso: Node3D
var _head: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _time := 0.0
var _cycle := 0.0
var _suit_mat: StandardMaterial3D
var _accent_mat: StandardMaterial3D


func _ready() -> void:
	if _body == null:
		_build()


## Render layers for every mesh (live avatars vs. replay ghosts).
func set_render_layers(mask: int) -> void:
	if _body == null:
		_build()
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).layers = mask


func set_colors(suit: Color, accent: Color) -> void:
	suit_color = suit
	accent_color = accent
	if _suit_mat != null:
		_suit_mat.albedo_color = suit
		_accent_mat.albedo_color = accent


func _process(delta: float) -> void:
	_time += delta
	if downed:
		_body.rotation.x = lerpf(_body.rotation.x, -PI * 0.5, minf(1.0, delta * 6.0))
		_body.position.y = lerpf(_body.position.y, 0.35, minf(1.0, delta * 6.0))
		return
	_body.rotation.x = lerpf(_body.rotation.x, 0.0, minf(1.0, delta * 8.0))
	var m := clampf(move_blend, 0.0, 1.0)
	_cycle += delta * lerpf(1.5, 11.0, m)
	var c := _cycle + phase_offset
	var swing := sin(c) * lerpf(0.05, 0.8, m)
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.9
	_arm_r.rotation.x = swing * 0.9
	var bob := absf(sin(c)) * 0.09 * m + sin(_time * 2.0 + phase_offset) * 0.02 * (1.0 - m)
	_body.position.y = bob
	_torso.rotation.x = lerpf(_torso.rotation.x, -0.18 * m, minf(1.0, delta * 6.0))
	_head.rotation.z = sin(_time * 0.9 + phase_offset) * 0.05 * (1.0 - m)


func _build() -> void:
	_suit_mat = _mat(suit_color, 0.55)
	_suit_mat.rim_enabled = true
	_suit_mat.rim = 0.35
	_suit_mat.rim_tint = 0.6
	_accent_mat = _mat(accent_color, 0.5)
	var helmet := _mat(suit_color, 0.22)
	helmet.clearcoat_enabled = true
	helmet.clearcoat = 1.0
	helmet.clearcoat_roughness = 0.1
	helmet.rim_enabled = true
	helmet.rim = 0.4
	var visor := _mat(visor_tint, 0.06)
	visor.metallic = 0.75
	visor.clearcoat_enabled = true
	visor.clearcoat = 1.0
	var dark := _mat(Color(0.22, 0.24, 0.28), 0.6)

	_body = Node3D.new()
	add_child(_body)
	_torso = _pivot(_body, Vector3(0, 0.45, 0))
	_part(_torso, _capsule(0.33, 0.8), _suit_mat, Vector3(0, 0.3, 0))
	_part(_torso, _box(Vector3(0.5, 0.12, 0.3)), _accent_mat, Vector3(0, 0.12, 0.08))              # belt
	_part(_torso, _box(Vector3(0.52, 0.6, 0.32)), _accent_mat, Vector3(0, 0.42, -0.36))             # backpack
	_part(_torso, _box(Vector3(0.3, 0.14, 0.06)), dark, Vector3(0, 0.55, -0.53))                    # pack panel
	_part(_torso, _cylinder(0.06, 0.24), dark, Vector3(0.18, 0.78, -0.36))                         # tank cap
	_part(_torso, _box(Vector3(0.18, 0.12, 0.04)), _mat(Color(0.3, 0.9, 1.0), 0.3), Vector3(-0.1, 0.45, 0.33))  # chest light
	_head = _pivot(_torso, Vector3(0, 0.78, 0))
	_part(_head, _sphere(0.44), helmet, Vector3(0, 0.3, 0))
	_part(_head, _sphere(0.3), visor, Vector3(0, 0.32, 0.22), Vector3(1.2, 0.86, 0.8))
	_arm_l = _pivot(_torso, Vector3(0.38, 0.55, 0))
	_arm_r = _pivot(_torso, Vector3(-0.38, 0.55, 0))
	for arm: Node3D in [_arm_l, _arm_r]:
		var side := signf(arm.position.x)
		_part(arm, _capsule(0.11, 0.5), _suit_mat, Vector3(0.06 * side, -0.2, 0), Vector3.ONE, Vector3(0, 0, 0.25 * side))
		_part(arm, _sphere(0.13), _accent_mat, Vector3(0.13 * side, -0.46, 0))
	_leg_l = _pivot(_body, Vector3(0.16, 0.42, 0))
	_leg_r = _pivot(_body, Vector3(-0.16, 0.42, 0))
	for leg: Node3D in [_leg_l, _leg_r]:
		_part(leg, _capsule(0.13, 0.45), _suit_mat, Vector3(0, -0.2, 0))
		_part(leg, _box(Vector3(0.24, 0.15, 0.34)), _accent_mat, Vector3(0, -0.38, 0.04))


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3, scale_v := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.scale = scale_v
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _mat(color: Color, roughness: float) -> StandardMaterial3D:
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


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	return m
