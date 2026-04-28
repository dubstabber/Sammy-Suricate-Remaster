extends Resource
class_name AssetEntry

@export var id: String = ""
@export var path: String = ""
@export var source_path: String = ""
@export var kind: String = ""
@export var description: String = ""
@export var acknex_entity_scale: Vector3 = Vector3.ONE
@export var rotation_degrees: Vector3 = Vector3.ZERO


func _init(
        entry_id: String = "",
        resource_path: String = "",
        original_source_path: String = "",
        asset_kind: String = "",
        asset_description: String = "",
        original_entity_scale: Vector3 = Vector3.ONE,
        model_rotation_degrees: Vector3 = Vector3.ZERO
) -> void:
    id = entry_id
    path = resource_path
    source_path = original_source_path
    kind = asset_kind
    description = asset_description
    acknex_entity_scale = original_entity_scale
    rotation_degrees = model_rotation_degrees
