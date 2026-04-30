extends Node3D
class_name KeyMixEffect

const KEY_RULES := preload("res://src/resources/key_diamond_rules.gd")

const DEFAULT_DURATION_SECONDS := 1.0
const ORBIT_RADIUS_METERS := 0.8
const HEIGHT_OFFSET_METERS := 0.45
const HEIGHT_RISE_METERS := 0.35
const ROTATION_DEGREES_PER_SECOND := 360.0
const FRAME_RATE := 48.0

var _target: Node3D = null
var _sprites: Array[Sprite3D] = []
var _elapsed_seconds := 0.0
var _duration_seconds := DEFAULT_DURATION_SECONDS
var _end_sound_asset_id := ""
var _key_ids: PackedInt32Array = PackedInt32Array()
var _frame_accumulator := 0.0


func configure(target: Node3D, first_key_id: int, second_key_id: int, end_sound_asset_id: String = "sfx.key_mix_end") -> void:
	_target = target
	_key_ids = PackedInt32Array([first_key_id, second_key_id])
	_end_sound_asset_id = end_sound_asset_id
	if _target != null:
		global_position = _target.global_position + Vector3(0.0, HEIGHT_OFFSET_METERS, 0.0)
	_spawn_sprite(first_key_id, 0.0)
	_spawn_sprite(second_key_id, PI)


func get_key_ids() -> PackedInt32Array:
	return _key_ids


func get_sprite_count() -> int:
	return _sprites.size()


func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	_elapsed_seconds += safe_delta
	_frame_accumulator += FRAME_RATE * safe_delta
	var whole_frames := int(floorf(_frame_accumulator))
	if whole_frames > 0:
		_frame_accumulator -= float(whole_frames)

	var progress := clampf(_elapsed_seconds / _duration_seconds, 0.0, 1.0)
	if _target != null and is_instance_valid(_target):
		global_position = _target.global_position + Vector3(0.0, HEIGHT_OFFSET_METERS + HEIGHT_RISE_METERS * progress, 0.0)

	var radius := ORBIT_RADIUS_METERS * sin(progress * PI)
	var base_angle := deg_to_rad(ROTATION_DEGREES_PER_SECOND) * _elapsed_seconds
	for index in range(_sprites.size()):
		var sprite := _sprites[index]
		if sprite == null:
			continue
		var angle := base_angle + (PI * float(index))
		sprite.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if whole_frames > 0 and sprite.hframes > 1:
			sprite.frame = (sprite.frame + whole_frames) % sprite.hframes

	if _elapsed_seconds >= _duration_seconds:
		_play_sfx(_end_sound_asset_id)
		queue_free()


func _spawn_sprite(key_id: int, angle: float) -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	var texture := assets.load_asset(KEY_RULES.key_texture_asset_id(key_id)) as Texture2D
	if texture == null:
		return

	var sprite := Sprite3D.new()
	sprite.name = "%sKeyMixSprite" % KEY_RULES.key_name(key_id)
	sprite.texture = texture
	sprite.hframes = KEY_RULES.VISUAL_FRAME_COUNT
	sprite.vframes = 1
	sprite.frame = randi_range(0, sprite.hframes - 1)
	sprite.pixel_size = 0.01
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position = Vector3(cos(angle) * ORBIT_RADIUS_METERS, 0.0, sin(angle) * ORBIT_RADIUS_METERS)
	add_child(sprite)
	_sprites.append(sprite)


func _play_sfx(asset_id: String) -> void:
	if asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", asset_id)
