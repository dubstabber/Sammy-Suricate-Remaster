extends CharacterBody3D
class_name SammyPlayerController

const PLAYER_MOVEMENT_CONFIG_SCRIPT := preload("res://src/resources/player_movement_config.gd")

@export var movement_config: Resource = PLAYER_MOVEMENT_CONFIG_SCRIPT.new()
@export var model_asset_id: String = "model.sammy.animated"

@onready var visual_pivot: Node3D = $VisualPivot

var _model_instance: Node3D
var _fire_requests: int = 0


func _ready() -> void:
    add_to_group("player")
    _spawn_model()


func _physics_process(delta: float) -> void:
    _apply_turn(delta)

    var forward_input: float = Input.get_axis("move_back", "move_forward")
    var boosting: bool = forward_input > 0.0 and Input.is_action_pressed("boost")
    var target_velocity: Vector3 = get_facing_direction() * forward_input * _current_walk_speed(boosting)
    var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
    var rate: float = movement_config.acceleration if absf(forward_input) > 0.0 else movement_config.deceleration
    horizontal_velocity = horizontal_velocity.move_toward(target_velocity, rate * delta)

    velocity.x = horizontal_velocity.x
    velocity.z = horizontal_velocity.z

    if is_on_floor():
        if Input.is_action_just_pressed("jump"):
            velocity.y = movement_config.jump_velocity
    else:
        velocity.y -= movement_config.gravity * delta

    if Input.is_action_just_pressed("quick_turn") and is_on_floor():
        apply_quick_turn()

    if Input.is_action_just_pressed("fire"):
        fire_wasp()

    move_and_slide()


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


func get_facing_direction() -> Vector3:
    var forward := -global_transform.basis.z
    forward.y = 0.0
    return forward.normalized()


func get_fire_request_count() -> int:
    return _fire_requests


func apply_quick_turn() -> void:
    rotation.y = wrapf(rotation.y + PI, -PI, PI)


func fire_wasp() -> void:
    _fire_requests += 1


func _apply_turn(delta: float) -> void:
    var turn_input: float = Input.get_axis("turn_left", "turn_right")
    if is_zero_approx(turn_input):
        return

    var forward_input: float = Input.get_axis("move_back", "move_forward")
    var turn_speed: float = movement_config.turn_speed_degrees
    if absf(forward_input) > 0.0:
        turn_speed = movement_config.moving_turn_speed_degrees
    if Input.is_action_pressed("boost"):
        turn_speed *= movement_config.boost_turn_multiplier

    rotation.y -= deg_to_rad(turn_speed) * turn_input * delta


func _current_walk_speed(boosting: bool) -> float:
    var speed: float = movement_config.walk_speed
    if boosting:
        speed *= movement_config.boost_speed_multiplier
    return speed


func _make_fallback_visual() -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = CapsuleMesh.new()
    return mesh_instance
