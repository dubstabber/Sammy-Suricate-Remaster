extends Area3D
class_name WaspProjectile

const WASP_TYPE_SCRIPT := preload("res://src/resources/wasp_type.gd")

@export var model_asset_id: String = "model.wasp1"
@export var hit_sound_asset_id: String = "sfx.wasp_kaput"

var _wasp_type: Resource = null
var _source_player: Node = null
var _velocity: Vector3 = Vector3.ZERO
var _lifetime_remaining: float = 0.0
var _model_instance: Node3D = null
var _consumed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func configure(wasp_type: Resource, source_player: Node, spawn_transform: Transform3D) -> void:
	_wasp_type = wasp_type
	_source_player = source_player
	global_transform = spawn_transform
	_lifetime_remaining = wasp_type.lifetime_seconds
	_velocity = -global_transform.basis.z.normalized() * wasp_type.speed
	_spawn_visual()


func _physics_process(delta: float) -> void:
	if _consumed:
		return

	_lifetime_remaining -= delta
	if _lifetime_remaining <= 0.0:
		_despawn(false)
		return

	global_position += _velocity * delta


func _on_body_entered(body: Node) -> void:
	if _consumed or body == null or body == _source_player:
		return

	if body.has_method("take_damage") and _wasp_type != null:
		body.call("take_damage", int(_wasp_type.damage), self)

	_despawn(true)


func _spawn_visual() -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return

	var packed_scene: PackedScene = assets.load_asset(model_asset_id)
	if packed_scene == null:
		return

	_model_instance = packed_scene.instantiate() as Node3D
	if _model_instance == null:
		return

	_model_instance.name = "WaspVisual"
	var base_scale: Vector3 = assets.get_model_scale(model_asset_id)
	_model_instance.scale = base_scale * _get_wasp_visual_scale()
	_model_instance.rotation_degrees = assets.get_model_rotation_degrees(model_asset_id)
	add_child(_model_instance)
	_apply_wasp_skin(assets)


func _get_wasp_visual_scale() -> float:
	if _wasp_type == null:
		return 1.0
	var raw_visual_scale = _wasp_type.get("visual_scale")
	if raw_visual_scale == null:
		return 1.0
	return float(raw_visual_scale)


func _apply_wasp_skin(assets: Node) -> void:
	if _wasp_type == null or not assets.has_method("apply_wasp_skin"):
		return
	var raw_skin_index = _wasp_type.get("skin_index")
	if raw_skin_index == null:
		return
	assets.call("apply_wasp_skin", _model_instance, int(raw_skin_index))


func _despawn(play_hit_sound: bool) -> void:
	if _consumed:
		return
	_consumed = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if play_hit_sound and not hit_sound_asset_id.is_empty():
		var audio := get_node_or_null("/root/Audio")
		if audio != null and audio.has_method("play_sfx"):
			audio.call("play_sfx", hit_sound_asset_id)
	queue_free()


func get_wasp_type() -> Resource:
	return _wasp_type


func is_consumed() -> bool:
	return _consumed
