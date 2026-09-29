class_name SoundPlayer
extends Node3D
## Pools of 2D and positional 3D players so gunfire, footsteps and aircraft are
## directional (GAME_SPEC §5.8: gunshots audible to 250 m, sniper 400 m).

const POOL_3D := 24
const POOL_2D := 8

var _p3d: Array[AudioStreamPlayer3D] = []
var _p2d: Array[AudioStreamPlayer] = []
var _i3 := 0
var _i2 := 0


func _ready() -> void:
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 12.0
		p.panning_strength = 1.2
		add_child(p)
		_p3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_p2d.append(p)


func play_at(sound: String, pos: Vector3, max_distance: float = 250.0, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var p := _p3d[_i3]
	_i3 = (_i3 + 1) % POOL_3D
	p.stream = SoundBank.get_sound(sound)
	p.global_position = pos
	p.max_distance = max_distance
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var p := _p2d[_i2]
	_i2 = (_i2 + 1) % POOL_2D
	p.stream = SoundBank.get_sound(sound)
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
