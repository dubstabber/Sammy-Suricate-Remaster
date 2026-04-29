extends Area3D
class_name WaspPickup

@export var wasp_type: Resource = null
@export var ammo_amount: int = 20
@export var model_asset_id: String = "model.wasp1"
@export var collect_sound_asset_id: String = "sfx.takewasp"
@export var visual_scale_multiplier: float = 1.0
@export var visual_ground_clearance: float = 0.05

var _collected := false
var _model_instance: Node3D = null


func _ready() -> void:
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)
	_spawn_model()


func collect(player: Node) -> bool:
	return _collect_from(player)


func was_collected() -> bool:
	return _collected


func get_wasp_type() -> Resource:
	return wasp_type


func get_ammo_amount() -> int:
	return ammo_amount


func _on_body_entered(body: Node3D) -> void:
	_collect_from(body)


func _collect_from(player: Node) -> bool:
	if _collected or player == null or wasp_type == null or ammo_amount <= 0:
		return false
	if not player.has_method("get_wasp_inventory"):
		return false

	var inventory: Node = player.call("get_wasp_inventory")
	if inventory == null or not inventory.has_method("add_ammo"):
		return false

	inventory.call("add_ammo", wasp_type, ammo_amount)
	_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
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

	_model_instance.name = "WaspPickupVisual"
	var base_scale: Vector3 = assets.get_model_scale(model_asset_id)
	_model_instance.scale = base_scale * _get_wasp_visual_scale() * visual_scale_multiplier
	_model_instance.rotation_degrees = assets.get_model_rotation_degrees(model_asset_id)
	add_child(_model_instance)
	_apply_wasp_skin(assets)
	_lift_model_above_ground(assets)


func _get_wasp_visual_scale() -> float:
	if wasp_type == null:
		return 1.0
	var raw_visual_scale = wasp_type.get("visual_scale")
	if raw_visual_scale == null:
		return 1.0
	return float(raw_visual_scale)


func _apply_wasp_skin(assets: Node) -> void:
	if wasp_type == null or not assets.has_method("apply_wasp_skin"):
		return
	var raw_skin_index = wasp_type.get("skin_index")
	if raw_skin_index == null:
		return
	assets.call("apply_wasp_skin", _model_instance, int(raw_skin_index))


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
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", collect_sound_asset_id)
