extends CharacterBody3D
class_name SammyPlayerController

const PLAYER_MOVEMENT_CONFIG_SCRIPT := preload("res://src/resources/player_movement_config.gd")
const MODEL_ANIMATION_CONTROLLER_SCRIPT := preload("res://src/animation/model_animation_controller.gd")
const WASP_INVENTORY_SCRIPT := preload("res://src/weapons/wasp_inventory.gd")
const WASP_PROJECTILE_SCENE := preload("res://scenes/weapons/wasp_projectile.tscn")
const KEY_DIAMOND_RULES_SCRIPT := preload("res://src/resources/key_diamond_rules.gd")
const KEY_DIAMOND_PICKUP_SCENE := preload("res://scenes/pickups/key_diamond_pickup.tscn")
const KEY_MIX_EFFECT_SCRIPT := preload("res://src/effects/key_mix_effect.gd")
const ACKNEX_TIME_UNITS_PER_SECOND := 16.0
const GODOT_PLAYBACK_SPEED_CORRECTION := 1.12
const WASP_FIRE_STEP_RANGE := 100.0
const WASP_FIRE_END_START_STEP := 10.0
const WASP_FIRE_START_STEP_SPEED := 20.0
const WASP_FIRE_END_STEP_SPEED := 20.0
const WASP_POST_SPAWN_WAIT_TICKS := 1.0
const PLAYER_LANDING_END_STEP_RANGE := 90.0
const PLAYER_LANDING_END_STEP_SPEED := 14.0
const PLAYER_LANDING_TURN_STEP_SPEED := 18.0
const PLAYER_LANDING_INPUT_STEP_SPEED := 36.0
const PLAYER_DEATH_STEP_RANGE := 100.0
const PLAYER_DEATH_STEP_SPEED := 3.0
const ACKNEX_TO_GODOT_SCALE := 0.01
const PLAYER_BOUNCE_TICKS_PER_SECOND := ACKNEX_TIME_UNITS_PER_SECOND * 1.5
const CHARACTER_COLLISION_MASK := 1 << 1

@export var movement_config: Resource = PLAYER_MOVEMENT_CONFIG_SCRIPT.new()
@export var model_asset_id: String = "model.sammy.animated"
@export var quick_turn_sound_asset_id: String = "sfx.quick_turn"
@export var fire_sound_asset_id: String = "sfx.wasp"
@export var no_wasp_sound_asset_id: String = "sfx.error"
@export var key_mix_sound_asset_id: String = "sfx.key_mix"
@export var key_mix_end_sound_asset_id: String = "sfx.key_mix_end"
@export var wasp_muzzle_offset: Vector3 = Vector3(0.0, 0.6, -0.4)
@export var max_health: float = 48.0
@export var damage_invulnerability_seconds: float = 0.0
@export var starting_lives: int = 3
@export var max_lives: int = 19
# WDL InitLvl/player: WindowHeartsOrg = 48, PoidPlayer1 = 0.8,
# IntensiteBlobBounce = 30, AmortiBouncePlayer = 10.
@export var enemy_push_weight_force: float = 0.8
@export var enemy_push_damping_per_second: float = 10.0
@export var enemy_push_max_source_speed: float = 2.7
@export var enemy_push_collision_normal_speed: float = 30.0 * ACKNEX_TO_GODOT_SCALE * PLAYER_BOUNCE_TICKS_PER_SECOND
@export var enemy_push_immediate_seconds: float = 0.04

signal damaged(amount: float, source: Node)
signal death_started(source: Node)
signal life_lost(lives_remaining: int)
signal respawned()
signal game_over()
signal key_diamond_changed(current_key_id: int, previous_key_id: int)
signal key_diamond_mixed(first_key_id: int, second_key_id: int, mixed_key_id: int)
signal key_diamond_ejected(key_id: int, pickup: Node)

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
var _wasp_inventory: Node = null
var _wasp_fire_active: bool = false
var _pending_wasp_type: Resource = null
var _wasp_projectile_spawned: bool = false
var _pending_wasp_shot_yaws: Array[float] = []
var _pending_wasp_shot_index: int = 0
var _wasp_spawn_delay_remaining: float = 0.0
var _wasp_recovery_remaining: float = 0.0
var _jump_fire_blocked: bool = false
var _landing_movement_lock_remaining: float = 0.0
var _health: float = 0.0
var _lives: int = 0
var _last_damage_time_msec: int = -1_000_000
var _enemy_push_velocity: Vector3 = Vector3.ZERO
var _input_horizontal_velocity: Vector3 = Vector3.ZERO
var _dead: bool = false
var _game_over: bool = false
var _death_timer: float = 0.0
var _respawn_transform: Transform3D
var _has_respawn_transform: bool = false
var _current_key_id: int = KEY_DIAMOND_RULES_SCRIPT.KEY_NONE
var _last_ejected_key: Node = null


func _ready() -> void:
    add_to_group("player")
    _health = maxf(max_health, 0.0)
    _lives = clampi(starting_lives, 0, _life_limit())
    _respawn_transform = global_transform
    _has_respawn_transform = true
    _boost_capacity = clampf(movement_config.boost_initial_capacity, 0.0, movement_config.boost_capacity_max)
    _ensure_wasp_inventory()
    _spawn_model()


func take_damage(amount: float, source: Node = null) -> bool:
    if amount <= 0.0 or _health <= 0.0 or _dead or _game_over:
        return false
    if is_in_invulnerability_window():
        return false
    _health = maxf(0.0, _health - amount)
    _last_damage_time_msec = Time.get_ticks_msec()
    damaged.emit(amount, source)
    if _health <= 0.0:
        _begin_death(source)
    return true


func get_health() -> float:
    return _health


func get_max_health() -> float:
    return max_health


func get_window_hearts() -> float:
    return _health


func get_window_hearts_max() -> float:
    return max_health


func get_lives() -> int:
    return _lives


func get_max_lives() -> int:
    return _life_limit()


func set_lives(count: int) -> void:
    _lives = clampi(count, 0, _life_limit())


func add_lives(amount: int) -> int:
    if amount <= 0:
        return 0
    var previous_lives := _lives
    set_lives(_lives + amount)
    return _lives - previous_lives


func is_dead() -> bool:
    return _dead


func is_game_over() -> bool:
    return _game_over


func set_respawn_transform(respawn_transform: Transform3D) -> void:
    _respawn_transform = respawn_transform
    _has_respawn_transform = true


func is_in_invulnerability_window() -> bool:
    if damage_invulnerability_seconds <= 0.0:
        return false
    var elapsed_msec := Time.get_ticks_msec() - _last_damage_time_msec
    return elapsed_msec < int(damage_invulnerability_seconds * 1000.0)


func apply_enemy_push(source_velocity: Vector3, source_bounce_force: float = 1.0, _source: Node = null) -> void:
    if _dead or _game_over:
        return

    var horizontal_source := source_velocity
    horizontal_source.y = 0.0
    var push_direction := _resolve_enemy_push_direction(horizontal_source, _source)
    if push_direction.length_squared() <= 0.0:
        _enemy_push_velocity = Vector3.ZERO
        return

    var push_speed := maxf(enemy_push_collision_normal_speed, 0.0) if _source is Node3D else 0.0
    if not (_source is Node3D):
        var max_source_speed := maxf(enemy_push_max_source_speed, 0.0)
        if max_source_speed > 0.0 and horizontal_source.length() > max_source_speed:
            horizontal_source = horizontal_source.normalized() * max_source_speed
        push_speed = horizontal_source.length() * maxf(enemy_push_weight_force, 0.0) * maxf(source_bounce_force, 0.0)
    if push_speed <= 0.0:
        _enemy_push_velocity = Vector3.ZERO
        return

    _enemy_push_velocity = push_direction * push_speed
    _apply_enemy_push_immediate_displacement(_enemy_push_velocity * maxf(enemy_push_immediate_seconds, 0.0))


func get_enemy_push_velocity() -> Vector3:
    return _enemy_push_velocity


func _ensure_wasp_inventory() -> void:
    _wasp_inventory = get_node_or_null("WaspInventory")
    if _wasp_inventory != null:
        return
    _wasp_inventory = WASP_INVENTORY_SCRIPT.new()
    _wasp_inventory.name = "WaspInventory"
    add_child(_wasp_inventory)


func get_wasp_inventory() -> Node:
    return _wasp_inventory


func collect_key_diamond(key_type: Resource, _source: Node = null) -> bool:
    if key_type == null:
        return false
    var incoming_key_id := int(key_type.get("key_id"))
    if not KEY_DIAMOND_RULES_SCRIPT.is_valid_key_id(incoming_key_id):
        return false

    var previous_key_id := _current_key_id
    var mixed_key_id := KEY_DIAMOND_RULES_SCRIPT.mix_keys(previous_key_id, incoming_key_id)
    if previous_key_id == KEY_DIAMOND_RULES_SCRIPT.KEY_NONE:
        _set_current_key_id(incoming_key_id)
    elif mixed_key_id != KEY_DIAMOND_RULES_SCRIPT.KEY_NONE:
        _set_current_key_id(mixed_key_id)
        _spawn_key_mix_effect(previous_key_id, incoming_key_id, mixed_key_id)
        key_diamond_mixed.emit(previous_key_id, incoming_key_id, mixed_key_id)
    else:
        _set_current_key_id(incoming_key_id)
        _spawn_ejected_key(previous_key_id)
    return true


func set_current_key_id(key_id: int) -> bool:
    if key_id != KEY_DIAMOND_RULES_SCRIPT.KEY_NONE and not KEY_DIAMOND_RULES_SCRIPT.is_valid_key_id(key_id):
        return false
    _set_current_key_id(key_id)
    return true


func clear_current_key() -> void:
    _set_current_key_id(KEY_DIAMOND_RULES_SCRIPT.KEY_NONE)


func get_current_key_id() -> int:
    return _current_key_id


func get_current_key_name() -> String:
    return KEY_DIAMOND_RULES_SCRIPT.key_name(_current_key_id)


func get_last_ejected_key() -> Node:
    return _last_ejected_key


func can_open_key_gate(required_key_id: int, strict_match: bool = false) -> bool:
    return KEY_DIAMOND_RULES_SCRIPT.can_open_gate(_current_key_id, required_key_id, strict_match)


func consume_key_for_gate(required_key_id: int, strict_match: bool = false) -> int:
    if not can_open_key_gate(required_key_id, strict_match):
        return KEY_DIAMOND_RULES_SCRIPT.KEY_NONE
    var consumed_key_id := _current_key_id
    if consumed_key_id != KEY_DIAMOND_RULES_SCRIPT.KEY_ALL:
        _set_current_key_id(KEY_DIAMOND_RULES_SCRIPT.KEY_NONE)
    return consumed_key_id


func _physics_process(delta: float) -> void:
    if _dead or _game_over:
        _update_death_state(delta)
        return

    var was_on_floor := is_on_floor()
    var forward_input: float = Input.get_axis("move_back", "move_forward")
    var turn_input: float = Input.get_axis("turn_left", "turn_right")

    _update_wasp_fire_timing(delta)
    var landing_locked_at_frame_start := is_landing_movement_locked()

    if Input.is_action_just_pressed("quick_turn") and is_on_floor() and not _is_movement_locked():
        apply_quick_turn()

    if _quick_turn_active:
        _process_quick_turn(delta, was_on_floor)
        return

    if Input.is_action_just_pressed("fire"):
        fire_wasp()

    var movement_locked := _is_movement_locked()
    if movement_locked:
        forward_input = 0.0
        turn_input = 0.0

    _update_boost_state(delta, forward_input)
    if not movement_locked:
        _apply_turn(delta, forward_input, turn_input)

    var target_velocity: Vector3 = get_facing_direction() * forward_input * _current_walk_speed(_boosting)
    var rate: float = movement_config.acceleration if absf(forward_input) > 0.0 else movement_config.deceleration
    _input_horizontal_velocity = _input_horizontal_velocity.move_toward(target_velocity, rate * delta)

    _set_horizontal_velocity(_input_horizontal_velocity)
    var applied_push_velocity := _enemy_push_velocity
    var horizontal_velocity := _input_horizontal_velocity

    var jumped := false
    if is_on_floor():
        if not movement_locked and Input.is_action_just_pressed("jump"):
            velocity.y = movement_config.jump_velocity
            jumped = true
            _jump_fire_blocked = true
    else:
        velocity.y -= movement_config.gravity * delta

    move_and_slide()
    _apply_enemy_push_frame_displacement(applied_push_velocity, delta)
    _decay_enemy_push(delta)
    var on_floor := is_on_floor()
    if not was_on_floor and on_floor:
        _begin_landing_movement_lock(forward_input, turn_input, Input.is_action_pressed("jump"))
    if landing_locked_at_frame_start:
        _update_landing_movement_lock(delta)
    if is_on_floor() and not jumped:
        _jump_fire_blocked = false
    _update_model_animation(forward_input, turn_input, jumped, was_on_floor, on_floor, horizontal_velocity.length())


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


func is_jump_fire_blocked() -> bool:
    return _jump_fire_blocked


func is_landing_movement_locked() -> bool:
    return _landing_movement_lock_remaining > 0.0


func apply_quick_turn() -> void:
    if _quick_turn_active or _is_movement_locked():
        return

    _quick_turn_active = true
    _quick_turn_start_yaw = rotation.y
    _quick_turn_remaining_degrees = rad_to_deg(PI)
    _quick_turn_speed_degrees = rad_to_deg(PI) * float(movement_config.quick_turn_initial_speed_factor)
    _clear_animation_sequence()
    _play_animation_action(&"turn", movement_config.quick_turn_animation_speed_multiplier, false, true, 0.0)
    _play_quick_turn_sound()


func fire_wasp() -> bool:
    if _is_movement_locked() or _jump_fire_blocked:
        return false
    if _wasp_inventory == null or not _wasp_inventory.has_method("has_ammo"):
        _play_no_wasp_sound()
        return false
    if not bool(_wasp_inventory.call("has_ammo")):
        _play_no_wasp_sound()
        return false
    var wasp_type: Resource = _wasp_inventory.call("get_current_type")
    if wasp_type == null:
        _play_no_wasp_sound()
        return false
    _fire_requests += 1
    _start_animation_sequence([&"tirA", &"tirB"], _get_wasp_fire_animation_speed(wasp_type))
    _begin_wasp_fire(wasp_type)
    return true


func is_wasp_fire_locked() -> bool:
    return _wasp_fire_active


func _begin_wasp_fire(wasp_type: Resource) -> void:
    _wasp_fire_active = true
    _pending_wasp_type = wasp_type
    _wasp_projectile_spawned = false
    _pending_wasp_shot_yaws = _build_wasp_fire_yaw_offsets(wasp_type)
    _pending_wasp_shot_index = 0
    _wasp_spawn_delay_remaining = _get_wasp_fire_spawn_delay_seconds(wasp_type)
    _wasp_recovery_remaining = 0.0


func _update_wasp_fire_timing(delta: float) -> void:
    if not _wasp_fire_active:
        return

    var remaining_delta: float = maxf(delta, 0.0)
    while _wasp_fire_active:
        if _pending_wasp_type != null:
            if _wasp_spawn_delay_remaining > remaining_delta:
                _wasp_spawn_delay_remaining -= remaining_delta
                return

            remaining_delta -= _wasp_spawn_delay_remaining
            _wasp_spawn_delay_remaining = 0.0
            if not _release_next_pending_wasp_projectile():
                if _wasp_projectile_spawned:
                    _begin_wasp_recovery()
                else:
                    _clear_wasp_fire()
                return

            _wasp_projectile_spawned = true
            if _pending_wasp_shot_index < _pending_wasp_shot_yaws.size() and _inventory_has_wasp_ammo():
                _wasp_spawn_delay_remaining = _get_wasp_multi_shot_interval_seconds(_pending_wasp_type)
                continue

            _begin_wasp_recovery()
            continue

        if _wasp_recovery_remaining > remaining_delta:
            _wasp_recovery_remaining -= remaining_delta
            return

        _clear_wasp_fire()
        return


func _release_next_pending_wasp_projectile() -> bool:
    var wasp_type := _pending_wasp_type
    if wasp_type == null:
        return false
    if _pending_wasp_shot_index >= _pending_wasp_shot_yaws.size():
        return false
    if _wasp_inventory == null or not _wasp_inventory.has_method("consume_ammo"):
        return false
    if not bool(_wasp_inventory.call("consume_ammo", 1)):
        return false
    var yaw_offset := _pending_wasp_shot_yaws[_pending_wasp_shot_index]
    if not _spawn_wasp_projectile(wasp_type, yaw_offset):
        return false
    _pending_wasp_shot_index += 1
    _play_fire_sound()
    return true


func _begin_wasp_recovery() -> void:
    _pending_wasp_type = null
    _pending_wasp_shot_yaws.clear()
    _pending_wasp_shot_index = 0
    _wasp_spawn_delay_remaining = 0.0
    _wasp_recovery_remaining = _get_wasp_fire_recovery_seconds()


func _clear_wasp_fire() -> void:
    _wasp_fire_active = false
    _pending_wasp_type = null
    _wasp_projectile_spawned = false
    _pending_wasp_shot_yaws.clear()
    _pending_wasp_shot_index = 0
    _wasp_spawn_delay_remaining = 0.0
    _wasp_recovery_remaining = 0.0


func _is_movement_locked() -> bool:
    return _dead or _game_over or _wasp_fire_active or is_landing_movement_locked()


func _begin_landing_movement_lock(forward_input: float = 0.0, turn_input: float = 0.0, jump_pressed: bool = false) -> void:
    _landing_movement_lock_remaining = maxf(_landing_movement_lock_remaining, _get_landing_movement_lock_seconds(forward_input, turn_input, jump_pressed))


func _update_landing_movement_lock(delta: float) -> void:
    _landing_movement_lock_remaining = maxf(0.0, _landing_movement_lock_remaining - maxf(delta, 0.0))


func _get_landing_movement_lock_seconds(forward_input: float = 0.0, turn_input: float = 0.0, jump_pressed: bool = false) -> float:
    var step_speed := PLAYER_LANDING_END_STEP_SPEED
    if not is_zero_approx(turn_input):
        step_speed = PLAYER_LANDING_TURN_STEP_SPEED
    if not is_zero_approx(forward_input) or jump_pressed:
        step_speed = PLAYER_LANDING_INPUT_STEP_SPEED
    return _seconds_for_wdl_animation_steps(PLAYER_LANDING_END_STEP_RANGE, step_speed)


func _spawn_wasp_projectile(wasp_type: Resource, yaw_offset_degrees: float = 0.0) -> bool:
    var parent: Node = get_parent()
    if parent == null:
        return false
    var projectile: Node = WASP_PROJECTILE_SCENE.instantiate()
    if projectile == null:
        return false
    parent.add_child(projectile)
    var spawn_transform := global_transform
    if not is_zero_approx(yaw_offset_degrees):
        spawn_transform.basis = Basis(Vector3.UP, deg_to_rad(yaw_offset_degrees)) * spawn_transform.basis
    spawn_transform.origin += global_transform.basis * wasp_muzzle_offset
    projectile.call("configure", wasp_type, self, spawn_transform)
    return true


func _play_fire_sound() -> void:
    if fire_sound_asset_id.is_empty():
        return
    var audio := get_node_or_null("/root/Audio")
    if audio != null and audio.has_method("play_sfx"):
        audio.call("play_sfx", fire_sound_asset_id)


func _play_no_wasp_sound() -> void:
    if no_wasp_sound_asset_id.is_empty():
        return
    var audio := get_node_or_null("/root/Audio")
    if audio != null and audio.has_method("play_sfx"):
        audio.call("play_sfx", no_wasp_sound_asset_id)


func _get_wasp_fire_animation_speed(wasp_type: Resource) -> float:
    if wasp_type == null:
        return 1.0
    var raw_fire_animation_speed = wasp_type.get("fire_animation_speed")
    if raw_fire_animation_speed == null:
        return 1.0
    return float(raw_fire_animation_speed)


func _build_wasp_fire_yaw_offsets(wasp_type: Resource) -> Array[float]:
    var count := _get_wasp_int(wasp_type, "multi_shot_count", 1)
    if count <= 1:
        return [0.0]

    var spread := _get_wasp_float(wasp_type, "multi_shot_spread_degrees", 0.0)
    if spread <= 0.0:
        var centered: Array[float] = []
        for _shot_index in count:
            centered.append(0.0)
        return centered

    var yaw_offsets: Array[float] = []
    for shot_index in count:
        var step := 0.0
        if count > 1:
            step = float(shot_index) / float(count - 1)
        yaw_offsets.append(lerpf(-spread * 0.5, spread * 0.5, step))
    return yaw_offsets


func _get_wasp_fire_spawn_delay_seconds(wasp_type: Resource) -> float:
    return _seconds_for_wdl_animation_steps(WASP_FIRE_STEP_RANGE, WASP_FIRE_START_STEP_SPEED * _get_wasp_fire_animation_speed(wasp_type))


func _get_wasp_multi_shot_interval_seconds(wasp_type: Resource) -> float:
    return maxf(0.0, _get_wasp_float(wasp_type, "multi_shot_interval_seconds", 0.0))


func _get_wasp_fire_recovery_seconds() -> float:
    var recovery_steps := maxf(0.0, WASP_FIRE_STEP_RANGE - WASP_FIRE_END_START_STEP)
    return (WASP_POST_SPAWN_WAIT_TICKS / ACKNEX_TIME_UNITS_PER_SECOND) + _seconds_for_wdl_animation_steps(recovery_steps, WASP_FIRE_END_STEP_SPEED)


func _seconds_for_wdl_animation_steps(step_count: float, step_speed: float) -> float:
    if step_count <= 0.0 or step_speed <= 0.0:
        return 0.0
    return step_count / (step_speed * ACKNEX_TIME_UNITS_PER_SECOND * GODOT_PLAYBACK_SPEED_CORRECTION)


func _inventory_has_wasp_ammo() -> bool:
    return _wasp_inventory != null and _wasp_inventory.has_method("has_ammo") and bool(_wasp_inventory.call("has_ammo"))


func _get_wasp_float(wasp_type: Resource, property_name: StringName, fallback: float) -> float:
    if wasp_type == null:
        return fallback
    var raw_value = wasp_type.get(property_name)
    if raw_value == null:
        return fallback
    return float(raw_value)


func _get_wasp_int(wasp_type: Resource, property_name: StringName, fallback: int) -> int:
    if wasp_type == null:
        return fallback
    var raw_value = wasp_type.get(property_name)
    if raw_value == null:
        return fallback
    return int(raw_value)


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

    _input_horizontal_velocity = _input_horizontal_velocity.move_toward(Vector3.ZERO, movement_config.deceleration * delta)
    _set_horizontal_velocity(_input_horizontal_velocity)
    var applied_push_velocity := _enemy_push_velocity
    if not is_on_floor():
        velocity.y -= movement_config.gravity * delta

    move_and_slide()
    _apply_enemy_push_frame_displacement(applied_push_velocity, delta)
    _decay_enemy_push(delta)
    _update_model_animation(0.0, 0.0, false, was_on_floor, is_on_floor(), _input_horizontal_velocity.length())


func _set_horizontal_velocity(horizontal_velocity: Vector3) -> void:
    velocity.x = horizontal_velocity.x
    velocity.z = horizontal_velocity.z


func _resolve_enemy_push_direction(horizontal_source: Vector3, source: Node) -> Vector3:
    if source is Node3D:
        var away_from_source := global_position - (source as Node3D).global_position
        away_from_source.y = 0.0
        if away_from_source.length_squared() > 0.0:
            return away_from_source.normalized()
    if horizontal_source.length_squared() > 0.0:
        return horizontal_source.normalized()
    return Vector3.ZERO


func _apply_enemy_push_frame_displacement(applied_push_velocity: Vector3, delta: float) -> void:
    if applied_push_velocity.length_squared() <= 0.0 or delta <= 0.0:
        return
    _apply_enemy_push_immediate_displacement(applied_push_velocity * delta)


func _apply_enemy_push_immediate_displacement(displacement: Vector3) -> void:
    if displacement.length_squared() <= 0.0:
        return
    var saved_collision_mask := collision_mask
    collision_mask = saved_collision_mask & ~CHARACTER_COLLISION_MASK
    move_and_collide(displacement)
    collision_mask = saved_collision_mask


func _decay_enemy_push(delta: float) -> void:
    if _enemy_push_velocity.length_squared() <= 0.0:
        return
    _enemy_push_velocity = _enemy_push_velocity.move_toward(Vector3.ZERO, maxf(enemy_push_damping_per_second, 0.0) * maxf(delta, 0.0))


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


func _play_quick_turn_sound() -> void:
    if quick_turn_sound_asset_id.is_empty():
        return

    var audio := get_node_or_null("/root/Audio")
    if audio != null and audio.has_method("play_sfx"):
        audio.call("play_sfx", quick_turn_sound_asset_id)


func _set_current_key_id(key_id: int) -> void:
    if _current_key_id == key_id:
        return
    var previous_key_id := _current_key_id
    _current_key_id = key_id
    key_diamond_changed.emit(_current_key_id, previous_key_id)


func _spawn_ejected_key(key_id: int) -> Node:
    var parent := get_parent()
    if parent == null or key_id == KEY_DIAMOND_RULES_SCRIPT.KEY_NONE:
        return null
    var pickup := KEY_DIAMOND_PICKUP_SCENE.instantiate() as Node3D
    if pickup == null:
        return null
    if pickup.has_method("configure_for_key_id"):
        pickup.call("configure_for_key_id", key_id)
    parent.add_child(pickup)
    pickup.global_position = global_position - get_facing_direction() * 1.15 + Vector3(0.0, 0.02, 0.0)
    _last_ejected_key = pickup
    key_diamond_ejected.emit(key_id, pickup)
    return pickup


func _spawn_key_mix_effect(first_key_id: int, second_key_id: int, _mixed_key_id: int) -> void:
    var parent := get_parent()
    if parent == null:
        return
    _play_key_sfx(key_mix_sound_asset_id)
    var effect := KEY_MIX_EFFECT_SCRIPT.new() as Node3D
    effect.name = "KeyMixEffect"
    parent.add_child(effect)
    effect.call("configure", self, first_key_id, second_key_id, key_mix_end_sound_asset_id)


func _play_key_sfx(asset_id: String) -> void:
    if asset_id.is_empty():
        return
    var audio := get_node_or_null("/root/Audio")
    if audio != null and audio.has_method("play_sfx"):
        audio.call("play_sfx", asset_id)


func _update_boost_state(delta: float, forward_input: float) -> void:
    _update_boost_state_from_input(delta, forward_input, Input.is_action_pressed("boost"))


func _update_boost_state_from_input(delta: float, forward_input: float, boost_pressed: bool) -> void:
    if _dead or _game_over:
        _boosting = false
        return

    _boosting = not is_zero_approx(forward_input) and boost_pressed and _boost_capacity > 0.0
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
    if _dead or _game_over:
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


func _start_animation_sequence(actions: Array[StringName], initial_speed: float = 1.0) -> void:
    if _animation_controller == null or actions.is_empty():
        return

    _animation_sequence = actions.duplicate()
    _animation_sequence_index = 0
    if not _play_animation_action(_animation_sequence[_animation_sequence_index], initial_speed, false, true):
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


func _life_limit() -> int:
    return max(0, max_lives)


func _begin_death(source: Node = null) -> void:
    if _dead or _game_over:
        return

    _dead = true
    _death_timer = _get_death_duration_seconds()
    _clear_action_state_for_death()
    _play_animation_action(&"kaputt", 1.0, false, true, 0.0)
    death_started.emit(source)


func _clear_action_state_for_death() -> void:
    _clear_wasp_fire()
    _clear_animation_sequence()
    _quick_turn_active = false
    _quick_turn_remaining_degrees = 0.0
    _quick_turn_speed_degrees = 0.0
    _boosting = false
    _jump_fire_blocked = false
    _landing_movement_lock_remaining = 0.0
    _enemy_push_velocity = Vector3.ZERO
    _input_horizontal_velocity = Vector3.ZERO
    velocity = Vector3.ZERO


func _update_death_state(delta: float) -> void:
    if not _dead or _game_over:
        return

    _death_timer = maxf(0.0, _death_timer - maxf(delta, 0.0))
    if _death_timer > 0.0:
        return

    _finish_death_sequence()


func _finish_death_sequence() -> void:
    if not _dead or _game_over:
        return

    _lives = maxi(0, _lives - 1)
    life_lost.emit(_lives)
    if _lives <= 0:
        _enter_game_over()
        return

    _respawn_after_death()


func _respawn_after_death() -> void:
    if _has_respawn_transform:
        global_transform = _respawn_transform
    _health = maxf(max_health, 0.0)
    velocity = Vector3.ZERO
    _enemy_push_velocity = Vector3.ZERO
    _input_horizontal_velocity = Vector3.ZERO
    _death_timer = 0.0
    _dead = false
    _game_over = false
    _clear_animation_sequence()
    _play_animation_action(&"stand", 1.0, false, true, 0.0)
    respawned.emit()


func _enter_game_over() -> void:
    _game_over = true
    _dead = true
    _death_timer = 0.0
    _clear_animation_sequence()
    _play_animation_action(&"finkaputt", 1.0, false, true, 0.0)
    game_over.emit()


func _get_death_duration_seconds() -> float:
    var action_duration := _resolve_animation_action_duration(&"kaputt", 1.0)
    if action_duration > 0.0:
        return action_duration
    return _seconds_for_wdl_animation_steps(PLAYER_DEATH_STEP_RANGE, PLAYER_DEATH_STEP_SPEED)


func _resolve_animation_action_duration(action: StringName, speed: float = 1.0) -> float:
    if _animation_controller == null or speed <= 0.0:
        return 0.0
    var animation_player := _animation_controller.get("animation_player") as AnimationPlayer
    if animation_player == null:
        return 0.0
    var animation_name := StringName("actions/%s" % String(action))
    if not animation_player.has_animation(animation_name):
        return 0.0
    var animation := animation_player.get_animation(animation_name)
    if animation == null:
        return 0.0
    return animation.length / speed


func _make_fallback_visual() -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.mesh = CapsuleMesh.new()
    return mesh_instance
