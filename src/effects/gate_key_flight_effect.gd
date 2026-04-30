extends Node3D
class_name GateKeyFlightEffect

const KEY_RULES := preload("res://src/resources/key_diamond_rules.gd")
const DEFAULT_FRAME_RATE := 48.0
const DEFAULT_HEIGHT_OFFSET := 0.55
const DEFAULT_ARC_HEIGHT := 0.35
const MIN_DURATION_SECONDS := 0.05

signal flight_finished(key_id: int)

var _key_id := KEY_RULES.KEY_NONE
var _start_position := Vector3.ZERO
var _end_position := Vector3.ZERO
var _duration_seconds := MIN_DURATION_SECONDS
var _elapsed_seconds := 0.0
var _frame_accumulator := 0.0
var _sprite: Sprite3D = null
var _finished := false


func configure(source: Node3D, target: Node3D, key_id: int, speed: float, height_offset: float = DEFAULT_HEIGHT_OFFSET) -> void:
	_key_id = key_id
	var offset := Vector3(0.0, height_offset, 0.0)
	_start_position = source.global_position + offset if source != null else global_position
	_end_position = target.global_position + offset if target != null else _start_position
	var distance := _start_position.distance_to(_end_position)
	_duration_seconds = maxf(distance / maxf(speed, 0.01), MIN_DURATION_SECONDS)
	global_position = _start_position
	_spawn_sprite()


func get_key_id() -> int:
	return _key_id


func get_progress() -> float:
	return clampf(_elapsed_seconds / _duration_seconds, 0.0, 1.0)


func get_visual_sprite() -> Sprite3D:
	return _sprite


func _process(delta: float) -> void:
	if _finished:
		return
	var safe_delta := maxf(delta, 0.0)
	_elapsed_seconds += safe_delta
	_update_sprite_frame(safe_delta)
	var progress := get_progress()
	global_position = _start_position.lerp(_end_position, progress)
	global_position.y += sin(progress * PI) * DEFAULT_ARC_HEIGHT
	if progress >= 1.0:
		_finished = true
		flight_finished.emit(_key_id)
		queue_free()


func _spawn_sprite() -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	var texture := assets.load_asset(KEY_RULES.key_texture_asset_id(_key_id)) as Texture2D
	if texture == null:
		return
	_sprite = Sprite3D.new()
	_sprite.name = "%sGateKeyFlightSprite" % KEY_RULES.key_name(_key_id)
	_sprite.texture = texture
	_sprite.hframes = KEY_RULES.VISUAL_FRAME_COUNT
	_sprite.vframes = 1
	_sprite.frame = 0
	_sprite.pixel_size = 0.01
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func _update_sprite_frame(delta: float) -> void:
	if _sprite == null or _sprite.hframes <= 1:
		return
	_frame_accumulator += DEFAULT_FRAME_RATE * delta
	var whole_frames := int(floorf(_frame_accumulator))
	if whole_frames <= 0:
		return
	_frame_accumulator -= float(whole_frames)
	_sprite.frame = (_sprite.frame + whole_frames) % _sprite.hframes
