extends CharacterBody3D
class_name SammyPlayerController

const PLAYER_MOVEMENT_CONFIG_SCRIPT := preload("res://src/resources/player_movement_config.gd")

@export var movement_config: Resource = PLAYER_MOVEMENT_CONFIG_SCRIPT.new()
@export var model_asset_id: String = "model.sammy.animated"
@export var camera_path: NodePath

@onready var visual_pivot: Node3D = $VisualPivot

var _model_instance: Node3D


func _ready() -> void:
    add_to_group("player")
    _spawn_model()


func _physics_process(delta: float) -> void:
    var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var world_direction := _camera_relative_direction(input_vector)
    var target_velocity: Vector3 = world_direction * movement_config.walk_speed
    var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
    var rate: float = movement_config.acceleration if world_direction.length_squared() > 0.0 else movement_config.deceleration
    horizontal_velocity = horizontal_velocity.move_toward(target_velocity, rate * delta)

    velocity.x = horizontal_velocity.x
    velocity.z = horizontal_velocity.z

    if is_on_floor():
        if Input.is_action_just_pressed("jump"):
            velocity.y = movement_config.jump_velocity
    else:
        velocity.y -= movement_config.gravity * delta

    move_and_slide()
    _face_motion(horizontal_velocity)


func _spawn_model() -> void:
    var assets := get_node_or_null("/root/Assets")
    var model_scale := Vector3.ONE
    var model_rotation_degrees := Vector3.ZERO
    var packed_scene: PackedScene
    if assets != null:
        packed_scene = assets.load_asset(model_asset_id)
        model_scale = assets.get_model_scale(model_asset_id)
        model_rotation_degrees = assets.get_model_rotation_degrees(model_asset_id)

    if packed_scene != null:
        _model_instance = packed_scene.instantiate()
    else:
        _model_instance = _make_fallback_visual()

    _model_instance.name = "SammyModel"
    _model_instance.scale = model_scale * movement_config.visual_scale_multiplier
    _model_instance.rotation_degrees = model_rotation_degrees
    visual_pivot.add_child(_model_instance)


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
    if input_vector.length_squared() == 0.0:
        return Vector3.ZERO

    var camera := get_node_or_null(camera_path) as Camera3D
    if camera == null:
        camera = get_viewport().get_camera_3d()

    if camera == null:
        return Vector3(input_vector.x, 0.0, input_vector.y).normalized()

    var forward := -camera.global_transform.basis.z
    forward.y = 0.0
    forward = forward.normalized()

    var right := camera.global_transform.basis.x
    right.y = 0.0
    right = right.normalized()

    return (right * input_vector.x + forward * -input_vector.y).normalized()


func _face_motion(horizontal_velocity: Vector3) -> void:
    if horizontal_velocity.length_squared() < 0.01:
        return
    visual_pivot.look_at(global_position + horizontal_velocity.normalized(), Vector3.UP)


func _make_fallback_visual() -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = CapsuleMesh.new()
    return mesh_instance
