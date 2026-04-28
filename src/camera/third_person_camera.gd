extends Camera3D
class_name ThirdPersonCamera

@export var target_path: NodePath
@export var follow_distance: float = 4.25
@export var follow_height: float = 4.0
@export var look_height: float = 1.25
@export var field_of_view: float = 60.0
@export var smoothing: float = 8.0

var _target: Node3D


func _ready() -> void:
    current = true
    fov = field_of_view
    _resolve_target()


func _physics_process(delta: float) -> void:
    if _target == null:
        _resolve_target()
    if _target == null:
        return

    var desired := _target.global_position + Vector3(0.0, follow_height, follow_distance)
    global_position = global_position.lerp(desired, minf(1.0, smoothing * delta))
    look_at(_target.global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)


func reset_to_target() -> void:
    if _target == null:
        _resolve_target()
    if _target == null:
        return
    global_position = _target.global_position + Vector3(0.0, follow_height, follow_distance)
    look_at(_target.global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("camera_reset"):
        reset_to_target()


func _resolve_target() -> void:
    if not target_path.is_empty():
        _target = get_node_or_null(target_path) as Node3D
    if _target == null:
        _target = get_tree().get_first_node_in_group("player") as Node3D
