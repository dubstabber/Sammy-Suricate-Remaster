extends CharacterBody3D
class_name SammyPlayerController

const PLAYER_MOVEMENT_CONFIG_SCRIPT := preload("res://src/resources/player_movement_config.gd")
const MODEL_ANIMATION_CONTROLLER_SCRIPT := preload("res://src/animation/model_animation_controller.gd")

@export var movement_config: Resource = PLAYER_MOVEMENT_CONFIG_SCRIPT.new()
@export var model_asset_id: String = "model.sammy.animated"

@onready var visual_pivot: Node3D = $VisualPivot

var _model_instance: Node3D
var _animation_controller: Node
var _animation_sequence: Array[StringName] = []
var _animation_sequence_index: int = -1
var _fire_requests: int = 0
var _boost_capacity: float = 0.0
var _boosting: bool = false
var _quick_turn_active: bool = false
var _quick_turn_start_yaw: float = 0.0
var _quick_turn_remaining_degrees: float = 0.0
var _quick_turn_speed_degrees: float = 0.0


func _ready() -> void:
    add_to_group("player")
    _boost_capacity = clampf(movement_config.boost_initial_capacity, 0.0, movement_config.boost_capacity_max)
    _spawn_model()


func _physics_process(delta: float) -> void:
    var was_on_floor := is_on_floor()
    var forward_input: float = Input.get_axis("move_back", "move_forward")
    var turn_input: float = Input.get_axis("turn_left", "turn_right")

    if Input.is_action_just_pressed("quick_turn") and is_on_floor():
        apply_quick_turn()

    if _quick_turn_active:
        _process_quick_turn(delta, was_on_floor)
        return

    _update_boost_state(delta, forward_input)
    _apply_turn(delta, forward_input, turn_input)

    var target_velocity: Vector3 = get_facing_direction() * forward_input * _current_walk_speed(_boosting)
    var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
    var rate: float = movement_config.acceleration if absf(forward_input) > 0.0 else movement_config.deceleration
    horizontal_velocity = horizontal_velocity.move_toward(target_velocity, rate * delta)

    velocity.x = horizontal_velocity.x
    velocity.z = horizontal_velocity.z

    var jumped := false
    if is_on_floor():
        if Input.is_action_just_pressed("jump"):
            velocity.y = movement_config.jump_velocity
            jumped = true
    else:
        velocity.y -= movement_config.gravity * delta

    if Input.is_action_just_pressed("fire"):
        fire_wasp()

    move_and_slide()
    _update_model_animation(forward_input, turn_input, jumped, was_on_floor, is_on_floor(), horizontal_velocity.length())


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
    if assets != null and assets.should_ground_model(model_asset_id):
        assets.align_model_instance_to_ground(_model_instance, global_position.y)
    _configure_model_animation(assets)


func get_facing_direction() -> Vector3:
    var forward := -global_transform.basis.z
    forward.y = 0.0
    return forward.normalized()


func get_fire_request_count() -> int:
    return _fire_requests


func get_animation_controller() -> Node:
    return _animation_controller


func get_walk_animation_speed_for_horizontal_speed(horizontal_speed: float) -> float:
    return _gameplay_walk_animation_speed(horizontal_speed)


func get_animation_blend_seconds_for_transition(from_action: StringName, to_action: StringName) -> float:
    return _animation_blend_seconds_for_transition(from_action, to_action)


func add_boost_capacity(amount: float) -> float:
    if amount <= 0.0:
        return 0.0
    var previous_capacity := _boost_capacity
    _boost_capacity = clampf(_boost_capacity + amount, 0.0, movement_config.boost_capacity_max)
    return _boost_capacity - previous_capacity


func get_boost_capacity() -> float:
    return _boost_capacity


func get_boost_capacity_max() -> float:
    return movement_config.boost_capacity_max


func get_boost_capacity_ratio() -> float:
    if movement_config.boost_capacity_max <= 0.0:
        return 0.0
    return clampf(_boost_capacity / movement_config.boost_capacity_max, 0.0, 1.0)


func is_boosting() -> bool:
    return _boosting


func is_quick_turning() -> bool:
    return _quick_turn_active


func apply_quick_turn() -> void:
    if _quick_turn_active:
        return

    _quick_turn_active = true
    _quick_turn_start_yaw = rotation.y
    _quick_turn_remaining_degrees = rad_to_deg(PI)
    _quick_turn_speed_degrees = rad_to_deg(PI) * float(movement_config.quick_turn_initial_speed_factor)
    _clear_animation_sequence()
    _play_animation_action(&"turn", movement_config.quick_turn_animation_speed_multiplier, false, true, 0.0)


func fire_wasp() -> void:
    _fire_requests += 1
    _start_animation_sequence([&"tirA", &"tirB"])


func _apply_turn(delta: float, forward_input: float, turn_input: float) -> void:
    if is_zero_approx(turn_input):
        return

    var turn_speed: float = movement_config.turn_speed_degrees
    if absf(forward_input) > 0.0:
        turn_speed = movement_config.moving_turn_speed_degrees
    if _boosting:
        turn_speed *= movement_config.boost_turn_multiplier

    rotation.y -= deg_to_rad(turn_speed) * turn_input * delta


func _process_quick_turn(delta: float, was_on_floor: bool) -> void:
    _boosting = false
    _advance_quick_turn(delta)

    var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
    horizontal_velocity = horizontal_velocity.move_toward(Vector3.ZERO, movement_config.deceleration * delta)
    velocity.x = horizontal_velocity.x
    velocity.z = horizontal_velocity.z
    if not is_on_floor():
        velocity.y -= movement_config.gravity * delta

    move_and_slide()
    _update_model_animation(0.0, 0.0, false, was_on_floor, is_on_floor(), horizontal_velocity.length())


func _advance_quick_turn(delta: float) -> void:
    if not _quick_turn_active:
        return

    if _quick_turn_remaining_degrees <= 0.0:
        _finish_quick_turn()
        return

    var step_degrees: float = _quick_turn_speed_degrees * float(movement_config.quick_turn_time_units_per_second) * delta
    if step_degrees <= 0.0:
        return

    step_degrees = minf(step_degrees, _quick_turn_remaining_degrees)
    rotation.y = wrapf(rotation.y + deg_to_rad(step_degrees), -PI, PI)
    _quick_turn_remaining_degrees -= step_degrees
    _quick_turn_speed_degrees = _quick_turn_remaining_degrees * float(movement_config.quick_turn_followup_speed_factor)

    if _quick_turn_remaining_degrees <= 0.0 or _quick_turn_speed_degrees <= float(movement_config.quick_turn_stop_speed_degrees):
        _finish_quick_turn()


func _finish_quick_turn() -> void:
    rotation.y = wrapf(_quick_turn_start_yaw + PI, -PI, PI)
    _quick_turn_active = false
    _quick_turn_remaining_degrees = 0.0
    _quick_turn_speed_degrees = 0.0


func _update_boost_state(delta: float, forward_input: float) -> void:
    _update_boost_state_from_input(delta, forward_input, Input.is_action_pressed("boost"))


func _update_boost_state_from_input(delta: float, forward_input: float, boost_pressed: bool) -> void:
    _boosting = forward_input > 0.0 and boost_pressed and _boost_capacity > 0.0
    if not _boosting:
        return

    _boost_capacity = maxf(0.0, _boost_capacity - movement_config.boost_consumption_per_second * delta)


func _current_walk_speed(boosting: bool) -> float:
    var speed: float = movement_config.walk_speed
    if boosting:
        speed *= movement_config.boost_speed_multiplier
    return speed


func _gameplay_walk_animation_speed(horizontal_speed: float) -> float:
    var speed_ratio := 1.0
    if movement_config.walk_speed > 0.0:
        speed_ratio = maxf(horizontal_speed / movement_config.walk_speed, movement_config.minimum_walk_animation_speed)
    return speed_ratio * movement_config.walk_animation_speed_multiplier


func _configure_model_animation(assets: Node) -> void:
    if assets == null:
        return

    var library_path: String = assets.get_model_animation_library_path(model_asset_id)
    if library_path.is_empty():
        return

    _animation_controller = MODEL_ANIMATION_CONTROLLER_SCRIPT.new()
    _animation_controller.name = "ModelAnimationController"
    _animation_controller.set("default_blend_seconds", movement_config.animation_blend_seconds)
    _model_instance.add_child(_animation_controller)
    var default_animation: String = assets.get_model_default_animation(model_asset_id)
    _animation_controller.call("configure", _model_instance, library_path, default_animation)


func _update_model_animation(forward_input: float, turn_input: float, jumped: bool, was_on_floor: bool, on_floor: bool, horizontal_speed: float) -> void:
    if _animation_controller == null:
        return

    if _quick_turn_active:
        _play_animation_action(&"turn", movement_config.quick_turn_animation_speed_multiplier, false, false, 0.0)
        return

    if jumped:
        _start_animation_sequence([&"sautA"])
    elif not was_on_floor and on_floor:
        _start_animation_sequence([&"sautC"])

    if _advance_animation_sequence():
        return

    if _animation_sequence_index >= 0:
        return

    var previous_action := _current_animation_action()
    if not on_floor:
        _play_animation_action(&"sautB", 1.0, false, false, _animation_blend_seconds_for_transition(previous_action, &"sautB"))
    elif absf(forward_input) > 0.01:
        var speed := _gameplay_walk_animation_speed(horizontal_speed)
        if forward_input < 0.0:
            speed *= -1.0
        _play_animation_action(&"walkB", speed, speed < 0.0, false, _animation_blend_seconds_for_transition(previous_action, &"walkB"))
    elif absf(turn_input) > 0.01:
        _play_animation_action(&"turn", 1.0, false, false, _animation_blend_seconds_for_transition(previous_action, &"turn"))
    else:
        _play_animation_action(&"stand", 1.0, false, false, _animation_blend_seconds_for_transition(previous_action, &"stand"))


func _start_animation_sequence(actions: Array[StringName]) -> void:
    if _animation_controller == null or actions.is_empty():
        return

    _animation_sequence = actions.duplicate()
    _animation_sequence_index = 0
    if not _play_animation_action(_animation_sequence[_animation_sequence_index], 1.0, false, true):
        _clear_animation_sequence()


func _advance_animation_sequence() -> bool:
    if _animation_sequence_index < 0:
        return false

    if bool(_animation_controller.call("is_playing")):
        return true

    _animation_sequence_index += 1
    if _animation_sequence_index >= _animation_sequence.size():
        _clear_animation_sequence()
        return false

    if not _play_animation_action(_animation_sequence[_animation_sequence_index]):
        _clear_animation_sequence()
        return false
    return true


func _play_animation_action(action: StringName, custom_speed: float = 1.0, from_end: bool = false, restart: bool = false, blend_seconds: float = -1.0) -> bool:
    if _animation_controller == null:
        return false
    return bool(_animation_controller.call("play_action", action, blend_seconds, custom_speed, from_end, restart))


func _current_animation_action() -> StringName:
    if _animation_controller == null:
        return &""
    return _animation_controller.call("get_current_action") as StringName


func _animation_blend_seconds_for_transition(from_action: StringName, to_action: StringName) -> float:
    if from_action == to_action or String(from_action).is_empty():
        return 0.0
    if from_action == &"walkB" and to_action == &"stand":
        return movement_config.walk_stop_blend_seconds
    return movement_config.animation_blend_seconds


func _clear_animation_sequence() -> void:
    _animation_sequence.clear()
    _animation_sequence_index = -1


func _make_fallback_visual() -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = CapsuleMesh.new()
    return mesh_instance
