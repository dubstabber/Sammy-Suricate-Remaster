extends Area3D
class_name LifeHeartPickup

const ACKNEX_TIME_UNITS_PER_SECOND := 16.0
const IDLE_TURN_DEGREES_PER_TIME_UNIT := 10.0
const COLLECT_SOUND_WDL_RANGE_UNITS := 1500.0

@export var life_amount: int = 1
@export var model_asset_id: String = "model.life_heart"
@export var collect_sound_asset_id: String = "sfx.get_life"
@export var visual_scale_multiplier: float = 1.0
@export var visual_ground_clearance: float = 0.035
@export var idle_turn_degrees_per_second: float = IDLE_TURN_DEGREES_PER_TIME_UNIT * ACKNEX_TIME_UNITS_PER_SECOND
@export var collect_shrink_rate_per_tick: float = 0.98
@export var collect_light_range: float = 2.5
@export var collect_light_energy: float = 1.2

var _collected := false
var _model_instance: Node3D = null
var _collecting := false
var _collect_light: OmniLight3D = null


func _ready() -> void:
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)
	_spawn_model()


func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if not _collected and _model_instance != null:
		_model_instance.rotate_y(deg_to_rad(idle_turn_degrees_per_second * safe_delta))
	elif _collecting:
		_update_collect_effect(safe_delta)


func collect(player: Node) -> bool:
	return _collect_from(player)


func was_collected() -> bool:
	return _collected


func get_life_amount() -> int:
	return life_amount


func get_visual_model() -> Node3D:
	return _model_instance


func _on_body_entered(body: Node3D) -> void:
	_collect_from(body)


func _collect_from(player: Node) -> bool:
	if _collected or player == null or not player.has_method("add_lives"):
		return false

	var added := int(player.call("add_lives", life_amount))
	if added <= 0:
		return false

	_collected = true
	_collecting = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_start_collect_light()
	_play_collect_sound()
	return true


func _spawn_model() -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return

	var packed_scene := assets.load_asset(model_asset_id) as PackedScene
	if packed_scene == null:
		return

	_model_instance = packed_scene.instantiate() as Node3D
	if _model_instance == null:
		return

	_model_instance.name = "LifeHeartVisual"
	_model_instance.scale = assets.get_model_scale(model_asset_id) * visual_scale_multiplier
	_model_instance.rotation_degrees = assets.get_model_rotation_degrees(model_asset_id)
	add_child(_model_instance)
	_lift_model_above_ground(assets)


func _lift_model_above_ground(assets: Node) -> void:
	if _model_instance == null:
		return
	var bounds: AABB = assets.get_model_global_bounds(_model_instance)
	if bounds.size == Vector3.ZERO:
		return
	var target_bottom_y := global_position.y + visual_ground_clearance
	var lift := target_bottom_y - bounds.position.y
	if lift > 0.0:
		_model_instance.global_position.y += lift


func _start_collect_light() -> void:
	_collect_light = OmniLight3D.new()
	_collect_light.name = "LifeHeartCollectLight"
	_collect_light.light_color = Color(50.0 / 255.0, 250.0 / 255.0, 10.0 / 255.0)
	_collect_light.light_energy = maxf(collect_light_energy, 0.0)
	_collect_light.omni_range = maxf(collect_light_range, 0.0)
	add_child(_collect_light)


func _update_collect_effect(delta: float) -> void:
	if _model_instance != null:
		var shrink_factor := pow(maxf(collect_shrink_rate_per_tick, 0.0), ACKNEX_TIME_UNITS_PER_SECOND * delta)
		_model_instance.scale *= shrink_factor
		if _model_instance.scale.x <= 0.05:
			_model_instance.visible = false
	if _collect_light != null:
		_collect_light.omni_range = maxf(0.0, _collect_light.omni_range - 0.4 * ACKNEX_TIME_UNITS_PER_SECOND * delta)
		if _collect_light.omni_range <= 0.05:
			_collect_light.queue_free()
			_collect_light = null
	if (_model_instance == null or not _model_instance.visible) and _collect_light == null:
		_collecting = false
		visible = false


func _play_collect_sound() -> void:
	if collect_sound_asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_spatial_sfx"):
		audio.call("play_spatial_sfx", collect_sound_asset_id, self, COLLECT_SOUND_WDL_RANGE_UNITS)
	elif audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", collect_sound_asset_id)
