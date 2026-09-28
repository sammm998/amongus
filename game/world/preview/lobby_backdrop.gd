class_name LobbyBackdrop
extends Node3D
## Simple sunset beach backdrop for the M0 dev lobby. The full look-dev scene
## ("Sunset Cove") replaces this in M1.

const SUIT_COLORS := [
	[Color(0.96, 0.96, 0.98), Color(1.0, 0.45, 0.72)],
	[Color(1.0, 0.72, 0.1), Color(1.0, 0.5, 0.15)],
	[Color(0.3, 0.75, 1.0), Color(0.95, 0.95, 0.98)],
]

var _camera: Camera3D
var _time := 0.0


func _ready() -> void:
	_build_environment()
	_build_ground()
	for i in SUIT_COLORS.size():
		var a := Astronaut.new()
		a.suit_color = SUIT_COLORS[i][0]
		a.accent_color = SUIT_COLORS[i][1]
		a.phase_offset = i * 1.7
		a.position = Vector3(1.2 + i * 1.3, 0.35, -0.6 - i * 0.9)
		a.rotation.y = deg_to_rad(-20.0 - i * 15.0)
		add_child(a)
	_camera = Camera3D.new()
	_camera.fov = 50
	add_child(_camera)
	_update_camera()


func _process(delta: float) -> void:
	_time += delta
	_update_camera()


func _update_camera() -> void:
	var sway := sin(_time * 0.15) * 0.4
	_camera.position = Vector3(-0.8 + sway, 2.2, 5.5)
	_camera.look_at(Vector3(2.4, 1.1, -2.0))


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.22, 0.52)
	sky_mat.sky_horizon_color = Color(1.0, 0.56, 0.38)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(1.0, 0.6, 0.45)
	sky_mat.ground_bottom_color = Color(0.1, 0.2, 0.35)
	sky_mat.sun_angle_max = 20.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.fog_enabled = true
	env.fog_light_color = Color(1.0, 0.62, 0.5)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.2
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.72, 0.45)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-12, 125, 0)
	add_child(sun)


func _build_ground() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(400, 400)
	sea.mesh = plane
	var sea_mat := StandardMaterial3D.new()
	sea_mat.albedo_color = Color(0.05, 0.62, 0.72)
	sea_mat.roughness = 0.08
	sea_mat.metallic = 0.2
	sea.material_override = sea_mat
	add_child(sea)
	var sand := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 9.0
	disc.bottom_radius = 11.0
	disc.height = 0.7
	sand.mesh = disc
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.98, 0.9, 0.74)
	sand_mat.roughness = 0.95
	sand.material_override = sand_mat
	sand.position = Vector3(2, 0.0, -3)
	add_child(sand)
