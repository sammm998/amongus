class_name RemoteAvatar
extends Node3D
## Another player as seen by this client: interpolated astronaut, name tag
## (within range + line of sight), suspect marker, flashlight, muzzle flash.
## Nothing here ever depends on role.

const NAME_LAYER := 2

var player_id := 0
var avatar: Astronaut
var name_tag: Label3D
var suspect_tag: Label3D
var flashlight: SpotLight3D
var feet := Vector3.ZERO
var state := 0
var crouch := false
var _last_pos := Vector3.ZERO
var _flash_time := 0.0
var _flash: OmniLight3D
var _bubble: Label3D
var _bubble_time := 0.0
var _emote: Label3D
var _crate: MeshInstance3D
var _emote_t := 0.0
var _canopy: Node3D


func setup(id: int, display_name: String, suit: Color, accent: Color) -> void:
	player_id = id
	avatar = Astronaut.new()
	avatar.suit_color = suit
	avatar.accent_color = accent
	avatar.phase_offset = id * 0.37
	add_child(avatar)
	avatar.set_render_layers(RenderLayers.AVATARS)
	name_tag = _label(display_name, Vector3(0, 2.35, 0), 48, Color.WHITE)
	suspect_tag = _label("⚠ SUSPECT", Vector3(0, 2.7, 0), 36, UITheme.AMBER)
	suspect_tag.visible = false
	flashlight = SpotLight3D.new()
	flashlight.spot_range = 24.0
	flashlight.spot_angle = 28.0
	flashlight.light_energy = 3.0
	flashlight.position = Vector3(0.2, 1.4, -0.3)
	flashlight.visible = false
	avatar.add_child(flashlight)
	_bubble = _label("", Vector3(0, 3.1, 0), 34, Color(0.05, 0.08, 0.14))
	_bubble.outline_modulate = Color(1, 1, 1, 0.95)
	_bubble.outline_size = 18
	_bubble.width = 400.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.visible = false
	_emote = _label("", Vector3(0, 2.95, 0), 64, UITheme.AMBER)
	_emote.visible = false
	_crate = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 0.95)
	box.material = mat
	_crate.mesh = box
	_crate.position = Vector3(0, 1.0, -0.45)
	_crate.layers = RenderLayers.AVATARS
	_crate.visible = false
	avatar.add_child(_crate)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.8, 0.4)
	_flash.light_energy = 0.0
	_flash.omni_range = 6.0
	_flash.position = Vector3(0.35, 1.3, -0.6)
	avatar.add_child(_flash)
	_canopy = DropVisuals.canopy()
	add_child(_canopy)


func _label(text: String, pos: Vector3, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = font_size
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.layers = 1 << (NAME_LAYER - 1)  # hidden from security camera feeds
	add_child(l)
	return l


func apply(pos: Vector3, yaw: float, p_state: int, flags: int, delta: float) -> void:
	feet = pos
	state = p_state
	crouch = flags & 1 != 0
	global_position = pos
	avatar.rotation.y = lerp_angle(avatar.rotation.y, yaw + PI, clampf(delta * 12.0, 0.0, 1.0))
	var speed := Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length() / maxf(delta, 0.001)
	_last_pos = pos
	avatar.move_blend = clampf(speed / 7.0, 0.0, 1.0)
	avatar.downed = p_state != Vitals.State.ALIVE
	flashlight.visible = flags & 16 != 0 and p_state == Vitals.State.ALIVE
	avatar.scale = Vector3(1, 0.8 if crouch else 1.0, 1)
	_crate.visible = flags & 128 != 0 and p_state == Vitals.State.ALIVE
	_bubble_time = maxf(0.0, _bubble_time - delta)
	_bubble.visible = _bubble_time > 0.0
	# Opening drop: hidden inside the plane, face-down in freefall, canopy when gliding.
	avatar.visible = flags & 256 == 0
	avatar.rotation.x = lerpf(avatar.rotation.x, -1.25 if flags & 512 != 0 else 0.0, clampf(delta * 8.0, 0.0, 1.0))
	_canopy.visible = flags & 1024 != 0
	_canopy.rotation.y = avatar.rotation.y
	_flash_time = maxf(0.0, _flash_time - delta)
	_flash.light_energy = 6.0 * _flash_time / 0.06
	_flash.visible = _flash_time > 0.0


const EMOTE_ICONS := {"wave": "* waves *", "point": "* points *", "shrug": "* shrugs *", "cheer": "\\o/", "facepalm": "* facepalm *", "dance": "* dances *"}


func set_emote(emote_id: String, delta: float) -> void:
	_emote.visible = not emote_id.is_empty() and state == Vitals.State.ALIVE
	if _emote.visible:
		_emote.text = EMOTE_ICONS.get(emote_id, emote_id)
		_emote_t += delta
		avatar.position.y = absf(sin(_emote_t * 6.0)) * 0.25 if emote_id in ["dance", "cheer"] else 0.0
	else:
		_emote_t = 0.0
		avatar.position.y = 0.0


## Proximity text bubble above the head (GAME_SPEC §8.5).
func say(text: String, seconds: float) -> void:
	_bubble.text = text
	_bubble_time = seconds


func muzzle_flash() -> void:
	_flash_time = 0.06


func update_tag(viewer_eye: Vector3, max_distance: float, visible_los: bool, suspect: bool) -> void:
	var d := viewer_eye.distance_to(global_position)
	name_tag.visible = d <= max_distance and visible_los and state == Vitals.State.ALIVE
	suspect_tag.visible = suspect and name_tag.visible


func hitbox_height() -> float:
	if state != Vitals.State.ALIVE:
		return 0.7
	return 1.15 if crouch else 1.7
