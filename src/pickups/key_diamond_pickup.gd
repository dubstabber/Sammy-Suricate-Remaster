extends Area3D
class_name KeyDiamondPickup

const KEY_RULES := preload("res://src/resources/key_diamond_rules.gd")
const ACKNEX_TIME_UNITS_PER_SECOND := 16.0
const DEFAULT_FRAME_ADVANCE_PER_TIME_UNIT := 3.0
const DEFAULT_HEIGHT_GEM := 25.0 * 0.01

@export var key_type: Resource = null
@export var collect_sound_asset_id: String = "sfx.colored_gem"
@export var visual_frame_count: int = KEY_RULES.VISUAL_FRAME_COUNT
@export var visual_frames_per_second: float = DEFAULT_FRAME_ADVANCE_PER_TIME_UNIT * ACKNEX_TIME_UNITS_PER_SECOND
@export var visual_pixel_size: float = 0.01
@export var visual_ground_clearance: float = DEFAULT_HEIGHT_GEM

var _collected := false
var _visual_sprite: Sprite3D = null
var _visual_frame_accumulator := 0.0
var _is_shrinking := false


func _ready() -> void:
	add_to_group("pickup")
	add_to_group("key_diamond")
	body_entered.connect(_on_body_entered)
	_spawn_visual()


func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if not _collected:
		_update_idle_animation(safe_delta)
	elif _is_shrinking:
		_update_collection_shrink(safe_delta)


func configure_for_key_id(key_id: int) -> bool:
	var resource_path := KEY_RULES.key_resource_path(key_id)
	if resource_path.is_empty():
		return false
	var loaded_key_type := load(resource_path) as Resource
	if loaded_key_type == null:
		return false
	key_type = loaded_key_type
	_apply_visual_texture()
	return true


func collect(player: Node) -> bool:
	return _collect_from(player)


func was_collected() -> bool:
	return _collected


func get_key_type() -> Resource:
	return key_type


func get_key_id() -> int:
	if key_type == null:
		return KEY_RULES.KEY_NONE
	return int(key_type.get("key_id"))


func get_visual_sprite() -> Sprite3D:
	return _visual_sprite


func get_visual_frame_count() -> int:
	return visual_frame_count


func _on_body_entered(body: Node3D) -> void:
	_collect_from(body)


func _collect_from(player: Node) -> bool:
	if _collected or not _is_player_collector(player) or key_type == null:
		return false
	if not player.has_method("collect_key_diamond"):
		return false
	if not bool(player.call("collect_key_diamond", key_type, self)):
		return false

	_collected = true
	_is_shrinking = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_play_collect_sound()
	return true


func _is_player_collector(body: Node) -> bool:
	return body != null and body.is_in_group("player")


func _spawn_visual() -> void:
	var texture := _load_key_texture()
	if texture == null:
		return

	_visual_sprite = Sprite3D.new()
	_visual_sprite.name = "KeyDiamondVisual"
	_visual_sprite.hframes = maxi(visual_frame_count, 1)
	_visual_sprite.vframes = 1
	_visual_sprite.frame = randi_range(0, _visual_sprite.hframes - 1)
	_visual_sprite.pixel_size = visual_pixel_size
	_visual_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_visual_sprite.position.y = visual_ground_clearance
	add_child(_visual_sprite)
	_apply_visual_texture()


func _apply_visual_texture() -> void:
	if _visual_sprite == null:
		return
	var texture := _load_key_texture()
	if texture != null:
		_visual_sprite.texture = texture


func _load_key_texture() -> Texture2D:
	if key_type == null:
		return null
	var texture_asset_id := String(key_type.get("texture_asset_id"))
	if texture_asset_id.is_empty():
		texture_asset_id = KEY_RULES.key_texture_asset_id(get_key_id())
	if texture_asset_id.is_empty():
		return null
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return null
	return assets.load_asset(texture_asset_id) as Texture2D


func _update_idle_animation(delta: float) -> void:
	if _visual_sprite == null or _visual_sprite.hframes <= 1:
		return
	_visual_frame_accumulator += maxf(visual_frames_per_second, 0.0) * delta
	var whole_frames := int(floorf(_visual_frame_accumulator))
	if whole_frames <= 0:
		return
	_visual_frame_accumulator -= float(whole_frames)
	_visual_sprite.frame = (_visual_sprite.frame + whole_frames) % _visual_sprite.hframes


func _update_collection_shrink(delta: float) -> void:
	if _visual_sprite == null:
		_is_shrinking = false
		visible = false
		return
	var shrink_factor := pow(0.8, ACKNEX_TIME_UNITS_PER_SECOND * delta)
	_visual_sprite.scale *= shrink_factor
	if _visual_sprite.scale.x <= 0.05:
		_visual_sprite.visible = false
		_is_shrinking = false
		visible = false


func _play_collect_sound() -> void:
	if collect_sound_asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", collect_sound_asset_id)
