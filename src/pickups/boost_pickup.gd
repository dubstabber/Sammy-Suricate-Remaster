extends Area3D
class_name BoostPickup

const MODEL_ANIMATION_CONTROLLER_SCRIPT := preload("res://src/animation/model_animation_controller.gd")
const BOOST_PICKUP_EFFECT_SCRIPT := preload("res://src/effects/boost_pickup_effect.gd")
const COLLECT_SOUND_WDL_RANGE_UNITS := 800.0

@export var boost_amount: float = 150.0
@export var model_asset_id: String = "model.boost"
@export var collect_sound_asset_id: String = "sfx.boost_pickup"
@export var visual_ground_clearance: float = 0.035
@export var boost_animation_speed: float = 2.0

var _collected := false
var _model_instance: Node3D
var _effect_instance: Node3D


func _ready() -> void:
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)
	_spawn_model()


func collect(player: Node) -> bool:
	return _collect_from(player)


func was_collected() -> bool:
	return _collected


func get_boost_amount() -> float:
	return boost_amount


func _on_body_entered(body: Node3D) -> void:
	_collect_from(body)


func _collect_from(player: Node) -> bool:
	if _collected or player == null or not player.has_method("add_boost_capacity"):
		return false

	var added := float(player.call("add_boost_capacity", boost_amount))
	if added <= 0.0:
		return false

	_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_stop_effect()
	visible = false
	_play_collect_sound()
	return true


func _spawn_model() -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return

	var packed_scene: PackedScene = assets.load_asset(model_asset_id)
	if packed_scene == null:
		return

	_model_instance = packed_scene.instantiate() as Node3D
	if _model_instance == null:
		return

	_model_instance.name = model_asset_id.replace(".", "_")
	_model_instance.scale = assets.get_model_scale(model_asset_id)
	_model_instance.rotation_degrees = assets.get_model_rotation_degrees(model_asset_id)
	add_child(_model_instance)
	_configure_model_animation(assets)
	_lift_model_above_ground(assets)
	_spawn_boost_effect(assets)


func _configure_model_animation(assets: Node) -> void:
	if _model_instance == null:
		return

	var library_path: String = assets.get_model_animation_library_path(model_asset_id)
	if library_path.is_empty():
		return

	var controller := MODEL_ANIMATION_CONTROLLER_SCRIPT.new()
	controller.name = "ModelAnimationController"
	_model_instance.add_child(controller)
	var default_animation: String = assets.get_model_default_animation(model_asset_id)
	var autoplay := model_asset_id != "model.boost"
	controller.configure(_model_instance, library_path, default_animation, autoplay)
	if not autoplay:
		controller.play_action(default_animation, 0.0, -boost_animation_speed, true, true)


func _spawn_boost_effect(assets: Node) -> void:
	var texture := assets.load_asset("texture.particle.small_star_1a") as Texture2D
	if texture == null:
		return

	_effect_instance = BOOST_PICKUP_EFFECT_SCRIPT.new() as Node3D
	_effect_instance.name = "BoostPickupEffect"
	_effect_instance.call("configure", texture, assets.get_model_scale(model_asset_id), _model_instance)
	add_child(_effect_instance)


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


func _play_collect_sound() -> void:
	if collect_sound_asset_id.is_empty():
		return

	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_spatial_sfx"):
		audio.call("play_spatial_sfx", collect_sound_asset_id, self, COLLECT_SOUND_WDL_RANGE_UNITS)
	elif audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", collect_sound_asset_id)


func _stop_effect() -> void:
	if _effect_instance != null and _effect_instance.has_method("stop_emission"):
		_effect_instance.call("stop_emission")
