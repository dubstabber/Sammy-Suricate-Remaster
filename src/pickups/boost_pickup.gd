extends Area3D
class_name BoostPickup

const MODEL_ANIMATION_CONTROLLER_SCRIPT := preload("res://src/animation/model_animation_controller.gd")

@export var boost_amount: float = 150.0
@export var model_asset_id: String = "model.boost"
@export var collect_sound_asset_id: String = "sfx.boost_pickup"

var _collected := false
var _model_instance: Node3D


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
	monitoring = false
	monitorable = false
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


func _configure_model_animation(assets: Node) -> void:
	if _model_instance == null:
		return

	var library_path: String = assets.get_model_animation_library_path(model_asset_id)
	if library_path.is_empty():
		return

	var controller := MODEL_ANIMATION_CONTROLLER_SCRIPT.new()
	controller.name = "ModelAnimationController"
	_model_instance.add_child(controller)
	controller.configure(_model_instance, library_path, assets.get_model_default_animation(model_asset_id))


func _play_collect_sound() -> void:
	if collect_sound_asset_id.is_empty():
		return

	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", collect_sound_asset_id)
