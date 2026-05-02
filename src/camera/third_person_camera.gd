extends Camera3D
class_name ThirdPersonCamera

@export var target_path: NodePath
@export var follow_distance: float = 4.25
@export var follow_height: float = 4.0
@export var look_height: float = 1.25
@export var field_of_view: float = 60.0
@export var smoothing: float = 8.0

var _target: Node3D
var _camera_mode_index: int = 0


func _ready() -> void:
    current = true
    fov = field_of_view
    _resolve_target()


func _physics_process(delta: float) -> void:
    if _target == null:
        _resolve_target()
    if _target == null:
        return
    if _target_locks_camera_follow():
        return

    var desired := _target.global_position + _get_follow_offset()
    global_position = global_position.lerp(desired, minf(1.0, smoothing * delta))
    look_at(_target.global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)


func reset_to_target() -> void:
    if _target == null:
        _resolve_target()
    if _target == null:
        return
    if _target_locks_camera_follow():
        return
    global_position = _target.global_position + _get_follow_offset()
    look_at(_target.global_position + Vector3(0.0, look_height, 0.0), Vector3.UP)


func cycle_camera_mode() -> void:
    if _target == null:
        _resolve_target()
    if _target_locks_camera_follow():
        return
    _camera_mode_index = (_camera_mode_index + 1) % 4
    reset_to_target()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("camera_change"):
        cycle_camera_mode()


func _resolve_target() -> void:
    if not target_path.is_empty():
        _target = get_node_or_null(target_path) as Node3D
    if _target == null:
        _target = get_tree().get_first_node_in_group("player") as Node3D


func _target_locks_camera_follow() -> bool:
    return _target != null and _target.has_method("is_exit_pad_victory_active") and bool(_target.call("is_exit_pad_victory_active"))


func _get_follow_offset() -> Vector3:
    var local_offset := _get_camera_mode_offset()
    if _target == null:
        return local_offset

    var target_basis := _target.global_transform.basis
    var right := target_basis.x
    right.y = 0.0
    right = right.normalized()

    var back := target_basis.z
    back.y = 0.0
    back = back.normalized()

    if right.length_squared() == 0.0:
        right = Vector3.RIGHT
    if back.length_squared() == 0.0:
        back = Vector3.BACK

    return right * local_offset.x + Vector3.UP * local_offset.y + back * local_offset.z


func _get_camera_mode_offset() -> Vector3:
    match _camera_mode_index:
        1:
            return Vector3(0.0, follow_height + 1.25, follow_distance + 1.75)
        2:
            return Vector3(2.25, follow_height, follow_distance)
        3:
            return Vector3(-2.25, follow_height, follow_distance)
        _:
            return Vector3(0.0, follow_height, follow_distance)
