extends Node3D
class_name PrototypeModelProp

@export var asset_id: String = ""
@export var visual_path: NodePath = ^"Visual"
@export var apply_catalog_transform: bool = true


func _ready() -> void:
	_apply_asset_catalog_settings()


func _apply_asset_catalog_settings() -> void:
	if asset_id.is_empty():
		return
	var visual := get_node_or_null(visual_path) as Node3D
	if visual == null:
		return
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return

	if apply_catalog_transform:
		visual.scale = assets.get_model_scale(asset_id)
		visual.rotation_degrees = assets.get_model_rotation_degrees(asset_id)
	if assets.should_ground_model(asset_id):
		assets.align_model_instance_to_ground(visual, global_position.y)
