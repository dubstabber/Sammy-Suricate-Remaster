extends Resource
class_name AssetEntry

@export var id: String = ""
@export var path: String = ""
@export var source_path: String = ""
@export var kind: String = ""
@export var description: String = ""
@export var acknex_entity_scale: Vector3 = Vector3.ONE
@export var rotation_degrees: Vector3 = Vector3.ZERO
@export var ground_to_floor: bool = false
@export var origin_ground_height: float = 0.0
@export var animation_library_path: String = ""
@export var default_animation: String = ""


func _init(
        entry_id: String = "",
        asset_resource_path: String = "",
        original_source_path: String = "",
        asset_kind: String = "",
        asset_description: String = "",
        original_entity_scale: Vector3 = Vector3.ONE,
        model_rotation_degrees: Vector3 = Vector3.ZERO,
        should_ground_to_floor: bool = false,
        model_origin_ground_height: float = 0.0,
        generated_animation_library_path: String = "",
        default_animation_name: String = ""
) -> void:
    id = entry_id
    path = asset_resource_path
    source_path = original_source_path
    kind = asset_kind
    description = asset_description
    acknex_entity_scale = original_entity_scale
    rotation_degrees = model_rotation_degrees
    ground_to_floor = should_ground_to_floor
    origin_ground_height = model_origin_ground_height
    animation_library_path = generated_animation_library_path
    default_animation = default_animation_name
