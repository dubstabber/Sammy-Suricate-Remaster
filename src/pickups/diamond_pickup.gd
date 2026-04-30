extends Area3D
class_name DiamondPickup

const ACKNEX_TIME_UNITS_PER_SECOND := 16.0
const DEFAULT_FRAME_ADVANCE_PER_TIME_UNIT := 3.0
const DEFAULT_HEIGHT_GEM := 25.0 * 0.01

@export var points: int = 50
@export var texture_asset_id: String = "texture.diamond.default"
@export var collect_sound_asset_id: String = "sfx.diamond"
@export var plus_50_texture_asset_id: String = "texture.score.plus50"
@export var plus_100_texture_asset_id: String = "texture.score.plus100"
@export var visual_frame_count: int = 17
@export var visual_frames_per_second: float = DEFAULT_FRAME_ADVANCE_PER_TIME_UNIT * ACKNEX_TIME_UNITS_PER_SECOND
@export var visual_pixel_size: float = 0.01
@export var visual_ground_clearance: float = DEFAULT_HEIGHT_GEM
@export var point_popup_pixel_size: float = 0.01
@export var point_popup_speed: float = 0.4
@export var point_popup_duration_seconds: float = 1.0

var _collected := false
var _visual_sprite: Sprite3D = null
var _point_popup: Sprite3D = null
var _visual_frame_accumulator := 0.0
var _point_popup_remaining := 0.0
var _is_shrinking := false


func _ready() -> void:
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)
	_spawn_visual()


func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if not _collected:
		_update_idle_animation(safe_delta)
	elif _is_shrinking:
		_update_collection_shrink(safe_delta)
	_update_point_popup(safe_delta)


func collect(player: Node) -> bool:
	return _collect_from(player)


func was_collected() -> bool:
	return _collected


func get_points() -> int:
	return points


func get_visual_sprite() -> Sprite3D:
	return _visual_sprite


func get_point_popup() -> Sprite3D:
	return _point_popup


func get_visual_frame_count() -> int:
	return visual_frame_count


func _on_body_entered(body: Node3D) -> void:
	_collect_from(body)


func _collect_from(player: Node) -> bool:
	if _collected or not _is_player_collector(player):
		return false
	var game := get_node_or_null("/root/Game")
	if game == null or not game.has_method("add_points"):
		return false

	game.call("add_points", points)
	_collected = true
	_is_shrinking = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_spawn_point_popup()
	_play_collect_sound()
	return true


func _is_player_collector(body: Node) -> bool:
	return body != null and body.is_in_group("player")


func _spawn_visual() -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	var texture := assets.load_asset(texture_asset_id) as Texture2D
	if texture == null:
		return

	_visual_sprite = Sprite3D.new()
	_visual_sprite.name = "DiamondVisual"
	_visual_sprite.texture = texture
	_visual_sprite.hframes = maxi(visual_frame_count, 1)
	_visual_sprite.vframes = 1
	_visual_sprite.frame = randi_range(0, _visual_sprite.hframes - 1)
	_visual_sprite.pixel_size = visual_pixel_size
	_visual_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_visual_sprite.position.y = visual_ground_clearance
	add_child(_visual_sprite)


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
		return
	var shrink_factor := pow(0.8, ACKNEX_TIME_UNITS_PER_SECOND * delta)
	_visual_sprite.scale *= shrink_factor
	if _visual_sprite.scale.x <= 0.05:
		_visual_sprite.visible = false
		_is_shrinking = false


func _spawn_point_popup() -> void:
	var texture_asset := ""
	var frame_count := 0
	if points == 50:
		texture_asset = plus_50_texture_asset_id
		frame_count = 6
	elif points == 100:
		texture_asset = plus_100_texture_asset_id
		frame_count = 2
	if texture_asset.is_empty():
		return

	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	var texture := assets.load_asset(texture_asset) as Texture2D
	if texture == null:
		return

	_point_popup = Sprite3D.new()
	_point_popup.name = "PointPopup"
	_point_popup.texture = texture
	_point_popup.hframes = frame_count
	_point_popup.vframes = 1
	_point_popup.frame = 0
	_point_popup.pixel_size = point_popup_pixel_size
	_point_popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_point_popup.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_point_popup.position.y = visual_ground_clearance + 0.25
	add_child(_point_popup)
	_point_popup_remaining = maxf(point_popup_duration_seconds, 0.0)


func _update_point_popup(delta: float) -> void:
	if _point_popup == null or not is_instance_valid(_point_popup):
		return
	_point_popup.position.y += point_popup_speed * delta
	_point_popup_remaining -= delta
	if _point_popup.hframes > 1:
		var progress := 1.0 - clampf(_point_popup_remaining / maxf(point_popup_duration_seconds, 0.001), 0.0, 1.0)
		_point_popup.frame = mini(_point_popup.hframes - 1, int(floorf(progress * float(_point_popup.hframes))))
	if _point_popup_remaining <= 0.0:
		_point_popup.visible = false


func _play_collect_sound() -> void:
	if collect_sound_asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", collect_sound_asset_id)
