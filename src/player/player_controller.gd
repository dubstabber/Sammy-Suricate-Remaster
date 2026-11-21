extends CharacterBody3D
class_name SammyPlayerController

const PLAYER_MOVEMENT_CONFIG_SCRIPT := preload("res://src/resources/player_movement_config.gd")
const MODEL_ANIMATION_CONTROLLER_SCRIPT := preload("res://src/animation/model_animation_controller.gd")
const WASP_INVENTORY_SCRIPT := preload("res://src/weapons/wasp_inventory.gd")
const WASP_PROJECTILE_SCENE := preload("res://scenes/weapons/wasp_projectile.tscn")
const KEY_DIAMOND_RULES_SCRIPT := preload("res://src/resources/key_diamond_rules.gd")
const LAUNCHED_KEY_GEM_SCENE := preload("res://scenes/pickups/launched_key_gem.tscn")
const DEATH_KEY_LAUNCH_HEIGHT := 30.0 * 0.01
const KAPUTT_STARS_SCRIPT := preload("res://src/effects/kaputt_stars.gd")
const FLYING_HEART_SCRIPT := preload("res://src/effects/flying_heart.gd")
const ACKNEX_ENGINE_TIMING_SCRIPT := preload("res://src/core/acknex_engine_timing.gd")
const DEATH_PHASE_ANIMATION := 0
const DEATH_PHASE_BLINK := 1
const DEATH_PHASE_FADE_IN := 2
## player.wdl Player_Kaputt: the death loop ends with the animation or after
## tempo2 reaches 64 ticks; Kaputt_son plays once int(tempo2) == 8.
const DEATH_ANIMATION_MAX_TICKS := 64.0
const KAPUTT_SOUND_TICK := 8.0
const KAPUTT_SOUND_WDL_RANGE_UNITS := 2000.0
## Player_Kaputt blink before RestartSammy: invisible/visible toggles (starting
## invisible) separated by these `waitt` ticks.
const DEATH_BLINK_WAITT_TICKS: Array[float] = [4.0, 4.0, 4.0, 3.0, 3.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 1.0, 1.0, 2.0, 2.0, 1.0, 1.0]
## RestartSammy: My.Alpha += 10 * time from 0 to 100 before control returns.
const RESTART_FADE_IN_TICKS := 10.0
const DEATH_KEY_HORIZONTAL_SPEED_UNITS := 25.0
const DEATH_KEY_VERTICAL_SPEED_UNITS := 40.0
const KEY_MIX_EFFECT_SCRIPT := preload("res://src/effects/key_mix_effect.gd")
const TELEPORT_PARTICLES_SCRIPT := preload("res://src/effects/teleport_star_particles.gd")
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
const WORLD_COLLISION_MASK := 1
const CENTER_FLOOR_RAY_START_HEIGHT := 0.2
# handlePente: the slope sonar counts when the floor is within 32 quants of the feet.
const SLOPE_FLOOR_MAX_DISTANCE := 0.32
const SLOPE_STOP_SPEED := 0.05
const SLOPE_DOWNHILL_TURN_RATE := 0.05
# Per-frame WDL statements (no `*time`) run once per engine frame.
const ORIGINAL_FRAMES_PER_TICK := AcknexEngineTiming.FRAMES_PER_TICK
const SLOPE_STATE_NONE := 0
const SLOPE_STATE_MEDIUM := 1
const SLOPE_STATE_BIG := 2
const TELEPORT_PHASE_PRE_FADE := 0
const TELEPORT_PHASE_FADE_OUT := 1
const TELEPORT_PHASE_FADE_IN := 2
const DEATH_PAD_PHASE_FADE_OUT := 0
const DEATH_PAD_PHASE_FADE_IN := 1
const PLAYER_ENTITY_SOUND_WDL_RANGE_UNITS := 1000.0
const KEY_MIX_SOUND_WDL_RANGE_UNITS := 2000.0

@export var movement_config: Resource = PLAYER_MOVEMENT_CONFIG_SCRIPT.new()
@export var model_asset_id: String = "model.sammy.animated"
@export var quick_turn_sound_asset_id: String = "sfx.quick_turn"
@export var kaputt_sound_asset_id: String = "sfx.player_kaputt"
@export var fire_sound_asset_id: String = "sfx.wasp"
@export var no_wasp_sound_asset_id: String = "sfx.error"
@export var enemy_top_bounce_sound_asset_id: String = "sfx.quick_turn"
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
@export var teleport_pre_fade_seconds: float = 4.0 / ACKNEX_TIME_UNITS_PER_SECOND
@export var teleport_fade_out_seconds: float = 10.0 / ACKNEX_TIME_UNITS_PER_SECOND
@export var teleport_fade_in_seconds: float = 10.0 / ACKNEX_TIME_UNITS_PER_SECOND
@export var death_pad_fade_out_seconds: float = 100.0 / (2.0 * ACKNEX_TIME_UNITS_PER_SECOND)
@export var death_pad_fade_in_seconds: float = 100.0 / (10.0 * ACKNEX_TIME_UNITS_PER_SECOND)
@export var exit_pad_victory_spin_degrees_per_second: float = 12.0 * ACKNEX_TIME_UNITS_PER_SECOND
@export var exit_pad_victory_animation_speed_scale: float = 1.0 / GODOT_PLAYBACK_SPEED_CORRECTION
@export var exit_pad_victory_animation_delay_seconds: float = 8.0 / ACKNEX_TIME_UNITS_PER_SECOND

signal damaged(amount: float, source: Node)
signal death_started(source: Node)
signal life_lost(lives_remaining: int)
signal respawned()
signal game_over()
signal key_diamond_changed(current_key_id: int, previous_key_id: int)
signal key_diamond_mixed(first_key_id: int, second_key_id: int, mixed_key_id: int)
signal key_diamond_ejected(key_id: int, pickup: Node)
signal teleport_started(source: Node)
signal teleport_finished(source: Node)

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
var _slope_velocity := Vector2.ZERO
var _slope_state := SLOPE_STATE_NONE
var _has_respawn_transform: bool = false
var _current_key_id: int = KEY_DIAMOND_RULES_SCRIPT.KEY_NONE
var _current_key_is_infinite := false
var _last_ejected_key: Node = null
var _last_death_key: Node = null
var _death_phase := DEATH_PHASE_ANIMATION
var _death_blink_index := 0
var _death_elapsed := 0.0
var _death_animation_seconds := 0.0
var _kaputt_sound_played := false
var _kaputt_stars: Node3D = null
var _last_flying_heart: Node3D = null
var _teleporting := false
var _teleport_phase := TELEPORT_PHASE_PRE_FADE
var _teleport_phase_remaining := 0.0
var _teleport_destination_transform := Transform3D.IDENTITY
var _teleport_source: Node = null
var _teleport_alpha := 1.0
var _teleport_particle_emit_remaining := 0.0
var _death_pad_respawning := false
var _death_pad_phase := DEATH_PAD_PHASE_FADE_OUT
var _death_pad_phase_remaining := 0.0
var _exit_pad_victory_active := false
var _exit_pad_victory_animation_started := false
var _exit_pad_victory_animation_delay_remaining := 0.0
var _saved_collision_layer := 0
var _saved_collision_mask := 0
var _has_saved_collision_state := false


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
    if amount <= 0.0 or _health <= 0.0 or _dead or _game_over or _teleporting or _death_pad_respawning or _exit_pad_victory_active:
        return false
    if is_in_invulnerability_window():
        return false
    _health = maxf(0.0, _health - amount)
    _last_damage_time_msec = Time.get_ticks_msec()
    damaged.emit(amount, source)
    if _health <= 0.0:
        _begin_death(source)
    return true


func add_health(amount: float) -> float:
    if amount <= 0.0 or _dead or _game_over:
        return 0.0
    var previous_health := _health
    _health = clampf(_health + amount, 0.0, maxf(max_health, 0.0))
    return _health - previous_health


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


func has_respawn_transform() -> bool:
    return _has_respawn_transform


func get_respawn_transform() -> Transform3D:
    return _respawn_transform


func is_in_invulnerability_window() -> bool:
    if damage_invulnerability_seconds <= 0.0:
        return false
    var elapsed_msec := Time.get_ticks_msec() - _last_damage_time_msec
    return elapsed_msec < int(damage_invulnerability_seconds * 1000.0)


func begin_teleport(destination_transform: Transform3D, source: Node = null) -> bool:
    if _dead or _game_over or _teleporting or _death_pad_respawning or _exit_pad_victory_active:
        return false

    _teleporting = true
    _teleport_phase = TELEPORT_PHASE_PRE_FADE
    _teleport_phase_remaining = maxf(teleport_pre_fade_seconds, 0.0)
    _teleport_destination_transform = destination_transform
    _teleport_source = source
    _teleport_particle_emit_remaining = 0.0
    _saved_collision_layer = collision_layer
    _saved_collision_mask = collision_mask
    _has_saved_collision_state = true
    collision_layer = 0
    collision_mask = 0
    _clear_motion_for_teleport()
    _set_teleport_alpha(1.0)
    _spawn_teleport_particles(global_position, 5)
    teleport_started.emit(source)
    return true


func is_teleporting() -> bool:
    return _teleporting


func get_teleport_alpha() -> float:
    return _teleport_alpha


func begin_death_pad_respawn(_source: Node = null) -> bool:
    if _dead or _game_over or _teleporting or _death_pad_respawning or _exit_pad_victory_active:
        return false

    _reset_sammy_key()
    _spawn_flying_heart()
    _lives = maxi(0, _lives - 1)
    life_lost.emit(_lives)
    _clear_action_state_for_death()
    if _lives <= 0:
        _health = 0.0
        _enter_game_over()
        return true

    _death_pad_respawning = true
    _death_pad_phase = DEATH_PAD_PHASE_FADE_OUT
    _death_pad_phase_remaining = maxf(death_pad_fade_out_seconds, 0.001)
    _saved_collision_layer = collision_layer
    _saved_collision_mask = collision_mask
    _has_saved_collision_state = true
    collision_layer = 0
    collision_mask = 0
    _set_teleport_alpha(1.0)
    _play_animation_action(&"stand", 1.0, false, true, 0.0)
    return true


func is_death_pad_respawning() -> bool:
    return _death_pad_respawning


func get_death_pad_respawn_alpha() -> float:
    return _teleport_alpha


func begin_exit_pad_victory(_source: Node = null) -> bool:
    if _dead or _game_over or _teleporting or _death_pad_respawning or _exit_pad_victory_active:
        return false

    _exit_pad_victory_active = true
    _exit_pad_victory_animation_started = false
    _exit_pad_victory_animation_delay_remaining = maxf(exit_pad_victory_animation_delay_seconds, 0.0)
    _clear_action_state_for_victory()
    _play_animation_action(&"stand", 1.0, false, false, 0.0)
    return true


func is_exit_pad_victory_active() -> bool:
    return _exit_pad_victory_active


func apply_enemy_push(source_velocity: Vector3, source_bounce_force: float = 1.0, _source: Node = null) -> void:
    if _dead or _game_over or _death_pad_respawning or _exit_pad_victory_active:
        return

    _slope_velocity = Vector2.ZERO
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
    if _current_key_is_infinite:
        return false
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


func grant_score_goal_key() -> bool:
    _set_current_key_id(KEY_DIAMOND_RULES_SCRIPT.KEY_ALL, true)
    return true


func clear_current_key() -> void:
    _set_current_key_id(KEY_DIAMOND_RULES_SCRIPT.KEY_NONE)


func get_current_key_id() -> int:
    return _current_key_id


func is_current_key_infinite() -> bool:
    return _current_key_is_infinite


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
    if not _current_key_is_infinite:
        _set_current_key_id(KEY_DIAMOND_RULES_SCRIPT.KEY_NONE)
    return consumed_key_id


func _physics_process(delta: float) -> void:
    if _dead or _game_over:
        _update_death_state(delta)
        return
    if _death_pad_respawning:
        _update_death_pad_respawn_state(delta)
        return
    if _teleporting:
        _update_teleport_state(delta)
        return
    if _exit_pad_victory_active:
        _update_exit_pad_victory_state(delta)
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
    _update_slope_slide(delta)
    if not movement_locked:
        _apply_turn(delta, forward_input, turn_input * _slope_turn_multiplier())
        _apply_slope_downhill_turn(delta)

    var jump_air_control_active := _is_jump_air_control_active()
    var target_velocity: Vector3 = _make_horizontal_target_velocity(forward_input, _boosting, jump_air_control_active)
    if not jump_air_control_active:
        target_velocity = _apply_slope_walk_modifiers(target_velocity, turn_input)
    var rate: float = movement_config.acceleration if absf(forward_input) > 0.0 or jump_air_control_active else movement_config.deceleration
    _input_horizontal_velocity = _input_horizontal_velocity.move_toward(target_velocity, rate * delta)

    _set_horizontal_velocity(_input_horizontal_velocity)
    var applied_push_velocity := _enemy_push_velocity
    var horizontal_velocity := _input_horizontal_velocity

    var jumped := false
    if is_on_floor():
        if not movement_locked and Input.is_action_just_pressed("jump"):
            jumped = _begin_jump(forward_input, _boosting, delta)
            if jumped:
                horizontal_velocity = _input_horizontal_velocity
                # player.wdl decelerates BlobVspeed before the first move.
                velocity.y -= movement_config.gravity * delta
    else:
        _apply_airborne_gravity(delta, was_on_floor)
    if not _slope_velocity.is_zero_approx():
        var slide_velocity := get_slope_slide_velocity()
        velocity.x += slide_velocity.x
        velocity.z += slide_velocity.z

    var pre_move_transform := global_transform
    var horizontal_motion := Vector3(horizontal_velocity.x, 0.0, horizontal_velocity.z) * delta
    var vertical_velocity_before_move := velocity.y
    move_and_slide()
    _try_step_up_from_low_obstacle(pre_move_transform, horizontal_motion, was_on_floor, jumped)
    var enemy_top_bounced := _try_apply_enemy_top_bounce(vertical_velocity_before_move)
    if enemy_top_bounced:
        jumped = true
    _apply_enemy_push_frame_displacement(applied_push_velocity, delta)
    _decay_enemy_push(delta)
    var on_floor := is_on_floor()
    if enemy_top_bounced:
        on_floor = false
    if not was_on_floor and on_floor and not enemy_top_bounced:
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
        if assets.has_method("should_align_model_origin_to_ground") and bool(assets.call("should_align_model_origin_to_ground", model_asset_id)):
            assets.call("align_model_origin_to_ground", _model_instance, global_position, global_position.y, float(assets.call("get_model_origin_ground_height", model_asset_id)))
        else:
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


func consume_platform_boost(delta: float) -> bool:
    return consume_platform_boost_from_input(delta, Input.is_action_pressed("boost"))


func consume_platform_boost_from_input(delta: float, boost_pressed: bool) -> bool:
    if _dead or _game_over or delta <= 0.0:
        return false
    if not boost_pressed or _boost_capacity <= 0.0:
        _boosting = false
        return false
    _boosting = true
    _boost_capacity = maxf(0.0, _boost_capacity - movement_config.boost_consumption_per_second * delta)
    if is_zero_approx(_boost_capacity):
        _boosting = false
    return true


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
    return _dead or _game_over or _teleporting or _death_pad_respawning or _exit_pad_victory_active or _wasp_fire_active or is_landing_movement_locked()


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


func _update_teleport_state(delta: float) -> void:
    var safe_delta := maxf(delta, 0.0)
    _clear_motion_for_teleport()
    _clear_animation_sequence()
    _play_animation_action(&"stand", 1.0, false, false, 0.0)

    match _teleport_phase:
        TELEPORT_PHASE_PRE_FADE:
            _teleport_phase_remaining -= safe_delta
            if _teleport_phase_remaining <= 0.0:
                _teleport_phase = TELEPORT_PHASE_FADE_OUT
                _teleport_phase_remaining = maxf(teleport_fade_out_seconds, 0.001)
                _teleport_particle_emit_remaining = 0.0
        TELEPORT_PHASE_FADE_OUT:
            _emit_teleport_transition_particles(safe_delta, 3)
            _teleport_phase_remaining -= safe_delta
            var fade_out_duration := maxf(teleport_fade_out_seconds, 0.001)
            _set_teleport_alpha(clampf(_teleport_phase_remaining / fade_out_duration, 0.0, 1.0))
            if _teleport_phase_remaining <= 0.0:
                _move_to_teleport_destination()
        TELEPORT_PHASE_FADE_IN:
            _emit_teleport_transition_particles(safe_delta, 2)
            _teleport_phase_remaining -= safe_delta
            var fade_in_duration := maxf(teleport_fade_in_seconds, 0.001)
            _set_teleport_alpha(clampf(1.0 - (_teleport_phase_remaining / fade_in_duration), 0.0, 1.0))
            if _teleport_phase_remaining <= 0.0:
                _finish_teleport()


func _update_death_pad_respawn_state(delta: float) -> void:
    var safe_delta := maxf(delta, 0.0)
    _clear_motion_for_teleport()
    _clear_animation_sequence()
    _play_animation_action(&"stand", 1.0, false, false, 0.0)

    match _death_pad_phase:
        DEATH_PAD_PHASE_FADE_OUT:
            _death_pad_phase_remaining -= safe_delta
            var fade_out_duration := maxf(death_pad_fade_out_seconds, 0.001)
            _set_teleport_alpha(clampf(_death_pad_phase_remaining / fade_out_duration, 0.0, 1.0))
            if _death_pad_phase_remaining <= 0.0:
                _move_to_death_pad_respawn()
        DEATH_PAD_PHASE_FADE_IN:
            _death_pad_phase_remaining -= safe_delta
            var fade_in_duration := maxf(death_pad_fade_in_seconds, 0.001)
            _set_teleport_alpha(clampf(1.0 - (_death_pad_phase_remaining / fade_in_duration), 0.0, 1.0))
            if _death_pad_phase_remaining <= 0.0:
                _finish_death_pad_respawn()


func _update_exit_pad_victory_state(delta: float) -> void:
    var safe_delta := maxf(delta, 0.0)
    velocity.x = 0.0
    velocity.z = 0.0
    _input_horizontal_velocity = Vector3.ZERO
    _enemy_push_velocity = Vector3.ZERO
    _boosting = false
    _quick_turn_active = false
    _quick_turn_remaining_degrees = 0.0
    _quick_turn_speed_degrees = 0.0
    if not is_on_floor():
        velocity.y -= movement_config.gravity * safe_delta
    else:
        velocity.y = 0.0
    _update_exit_pad_victory_animation_delay(safe_delta)
    if not _exit_pad_victory_animation_started:
        move_and_slide()
        return
    if safe_delta > 0.0:
        rotation.y = wrapf(rotation.y + deg_to_rad(exit_pad_victory_spin_degrees_per_second) * safe_delta, -PI, PI)
    move_and_slide()
    if _current_animation_action() != &"Iwin":
        _play_animation_action(&"Iwin", exit_pad_victory_animation_speed_scale, false, true, 0.0)


func _update_exit_pad_victory_animation_delay(delta: float) -> void:
    if _exit_pad_victory_animation_started:
        return
    _exit_pad_victory_animation_delay_remaining = maxf(0.0, _exit_pad_victory_animation_delay_remaining - delta)
    if _exit_pad_victory_animation_delay_remaining > 0.0:
        if _current_animation_action() != &"stand":
            _play_animation_action(&"stand", 1.0, false, false, 0.0)
        return
    _exit_pad_victory_animation_started = true
    _play_animation_action(&"Iwin", exit_pad_victory_animation_speed_scale, false, true, 0.0)


func _clear_action_state_for_victory() -> void:
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
    _slope_velocity = Vector2.ZERO
    velocity = Vector3.ZERO


func _clear_motion_for_teleport() -> void:
    velocity = Vector3.ZERO
    _input_horizontal_velocity = Vector3.ZERO
    _slope_velocity = Vector2.ZERO
    _enemy_push_velocity = Vector3.ZERO
    _boosting = false
    _quick_turn_active = false
    _quick_turn_remaining_degrees = 0.0
    _quick_turn_speed_degrees = 0.0
    _landing_movement_lock_remaining = 0.0
    _jump_fire_blocked = false
    _clear_wasp_fire()


func _emit_teleport_transition_particles(delta: float, count: int) -> void:
    _teleport_particle_emit_remaining -= delta
    while _teleport_particle_emit_remaining <= 0.0:
        _spawn_teleport_particles(global_position, count)
        _teleport_particle_emit_remaining += 1.0 / ACKNEX_TIME_UNITS_PER_SECOND


func _move_to_teleport_destination() -> void:
    _set_teleport_alpha(0.0)
    global_transform = _teleport_destination_transform
    velocity = Vector3.ZERO
    _input_horizontal_velocity = Vector3.ZERO
    _enemy_push_velocity = Vector3.ZERO
    _reset_follow_cameras_after_teleport()
    _spawn_teleport_particles(global_position, 5)
    _teleport_phase = TELEPORT_PHASE_FADE_IN
    _teleport_phase_remaining = maxf(teleport_fade_in_seconds, 0.001)
    _teleport_particle_emit_remaining = 0.0


func _finish_teleport() -> void:
    _set_teleport_alpha(1.0)
    if _has_saved_collision_state:
        collision_layer = _saved_collision_layer
        collision_mask = _saved_collision_mask
        _has_saved_collision_state = false
    _clear_motion_for_teleport()
    _teleporting = false
    var source := _teleport_source
    _teleport_source = null
    teleport_finished.emit(source)


func _move_to_death_pad_respawn() -> void:
    _set_teleport_alpha(0.0)
    if _has_respawn_transform:
        global_transform = _respawn_transform
    _health = maxf(max_health, 0.0)
    velocity = Vector3.ZERO
    _input_horizontal_velocity = Vector3.ZERO
    _slope_velocity = Vector2.ZERO
    _enemy_push_velocity = Vector3.ZERO
    _reset_follow_cameras_after_teleport()
    _play_animation_action(&"stand", 1.0, false, true, 0.0)
    _restart_sammy_world()
    _death_pad_phase = DEATH_PAD_PHASE_FADE_IN
    _death_pad_phase_remaining = maxf(death_pad_fade_in_seconds, 0.001)


func _finish_death_pad_respawn() -> void:
    _set_teleport_alpha(1.0)
    if _has_saved_collision_state:
        collision_layer = _saved_collision_layer
        collision_mask = _saved_collision_mask
        _has_saved_collision_state = false
    _clear_motion_for_teleport()
    _death_pad_respawning = false
    _death_pad_phase_remaining = 0.0
    _play_animation_action(&"stand", 1.0, false, true, 0.0)
    respawned.emit()


func _set_teleport_alpha(alpha: float) -> void:
    _teleport_alpha = clampf(alpha, 0.0, 1.0)
    if visual_pivot != null:
        _set_geometry_transparency(visual_pivot, 1.0 - _teleport_alpha)


func _set_geometry_transparency(node: Node, transparency: float) -> void:
    if node is GeometryInstance3D:
        (node as GeometryInstance3D).transparency = clampf(transparency, 0.0, 1.0)
    for child in node.get_children():
        _set_geometry_transparency(child, transparency)


func _spawn_teleport_particles(world_position: Vector3, count: int) -> void:
    var parent := get_parent()
    if parent == null:
        parent = self
    var emitter := TELEPORT_PARTICLES_SCRIPT.new()
    emitter.name = "PlayerTeleportParticles"
    emitter.set("idle_enabled", false)
    emitter.set("auto_free_when_empty", true)
    parent.add_child(emitter)
    emitter.global_position = world_position
    emitter.call("emit_burst", count)


func _reset_follow_cameras_after_teleport() -> void:
    var scene_tree := get_tree()
    if scene_tree == null:
        return
    _reset_follow_cameras_in_node(scene_tree.root)


func _reset_follow_cameras_in_node(node: Node) -> void:
    if node is Camera3D and node.has_method("reset_to_target"):
        node.call("reset_to_target")
    for child in node.get_children():
        _reset_follow_cameras_in_node(child)


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
    if audio != null and audio.has_method("play_spatial_sfx"):
        audio.call("play_spatial_sfx", fire_sound_asset_id, self, PLAYER_ENTITY_SOUND_WDL_RANGE_UNITS)
    elif audio != null and audio.has_method("play_sfx"):
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


## Level worlds pass the original per-level physics (WDL units: jump speed and
## deceleration from InitGame3 S1/S2, ledge fall start/acceleration S5/S6,
## InitGame5/6 slope parameters). One tick = 1/16 s, one quant = 0.01 m.
func apply_wdl_level_physics(settings: Dictionary) -> void:
    var config: Resource = movement_config.duplicate()
    var speed_scale := ACKNEX_TO_GODOT_SCALE * ACKNEX_TIME_UNITS_PER_SECOND
    var acceleration_scale := speed_scale * ACKNEX_TIME_UNITS_PER_SECOND
    config.set("jump_velocity", float(settings.get("jump_speed", 30.0)) * speed_scale)
    config.set("gravity", float(settings.get("jump_friction", 3.0)) * acceleration_scale)
    config.set("fall_start_velocity", float(settings.get("fall_speed", -2.0)) * speed_scale)
    config.set("fall_gravity", float(settings.get("fall_acceleration", 1.5)) * acceleration_scale)
    config.set("slope_sliding_enabled", true)
    config.set("slope_normal_max_y", float(settings.get("slope_angle_min", 0.92)))
    config.set("slope_acceleration", float(settings.get("slope_acceleration", 1.5)))
    config.set("slope_force", float(settings.get("slope_force", 100.0)))
    config.set("slope_end_damping", float(settings.get("slope_end_damping", 0.3)))
    config.set("slope_big", float(settings.get("big_slope", 10.0)))
    config.set("slope_medium", float(settings.get("medium_slope", 2.0)))
    config.set("jump_requires_center_floor", true)
    movement_config = config
    _slope_velocity = Vector2.ZERO


## Current handlePente slide (m/s, horizontal).
func get_slope_slide_velocity() -> Vector3:
    var scale := ACKNEX_TO_GODOT_SCALE * ACKNEX_TIME_UNITS_PER_SECOND
    return Vector3(_slope_velocity.x * scale, 0.0, _slope_velocity.y * scale)


func is_on_big_slope() -> bool:
    return _slope_state == SLOPE_STATE_BIG


## player.wdl: walking off a ledge starts the fall at Gravite and accelerates
## by AccGravite; a jump keeps decelerating by its own friction until landing.
func _apply_airborne_gravity(delta: float, was_on_floor: bool) -> void:
    if _jump_fire_blocked:
        velocity.y -= movement_config.gravity * delta
        return
    var fall_start := float(movement_config.fall_start_velocity)
    if was_on_floor and fall_start < 0.0 and velocity.y > fall_start:
        velocity.y = fall_start
    var fall_gravity := float(movement_config.fall_gravity)
    velocity.y -= (fall_gravity if fall_gravity > 0.0 else movement_config.gravity) * delta


func _center_floor_hit(max_distance_below_feet: float) -> Dictionary:
    var world := get_world_3d()
    if world == null:
        return {}
    var query := PhysicsRayQueryParameters3D.create(
            global_position + Vector3.UP * CENTER_FLOOR_RAY_START_HEIGHT,
            global_position + Vector3.DOWN * maxf(max_distance_below_feet, 0.0),
            WORLD_COLLISION_MASK
    )
    query.exclude = [get_rid()]
    return world.direct_space_state.intersect_ray(query)


## player.wdl handlePente: on a floor whose normal is steeper than
## SlopeAngleMin (within 32 quants under the feet) the slide builds up by
## Accpente * (1 - normal.z) per frame (not scaled by time) towards
## normal.xy * ForcePente; off the slope it decays with per-frame `accel`
## AmortiPenteEnd friction.
func _update_slope_slide(delta: float) -> void:
    _slope_state = SLOPE_STATE_NONE
    if not bool(movement_config.slope_sliding_enabled):
        _slope_velocity = Vector2.ZERO
        return
    var ticks := maxf(delta, 0.0) * ACKNEX_TIME_UNITS_PER_SECOND
    var hit := _center_floor_hit(SLOPE_FLOOR_MAX_DISTANCE)
    var normal: Vector3 = hit.get("normal", Vector3.UP)
    if not hit.is_empty() and normal.y > 0.0 and normal.y <= float(movement_config.slope_normal_max_y):
        var force := Vector2(normal.x, normal.z) * float(movement_config.slope_force)
        var gain := float(movement_config.slope_acceleration) * (1.0 - normal.y) * ticks * ORIGINAL_FRAMES_PER_TICK
        _slope_velocity.x = _step_slope_axis(_slope_velocity.x, force.x, gain)
        _slope_velocity.y = _step_slope_axis(_slope_velocity.y, force.y, gain)
    else:
        # `Accel Pente,nullskill,AmortiPenteEnd`: accel friction applies per frame.
        _slope_velocity *= AcknexEngineTiming.frame_factor(1.0 - float(movement_config.slope_end_damping), delta)
        if _slope_velocity.length() < SLOPE_STOP_SPEED:
            _slope_velocity = Vector2.ZERO
    var big := float(movement_config.slope_big)
    var medium := float(movement_config.slope_medium)
    if absf(_slope_velocity.x) > big or absf(_slope_velocity.y) > big:
        _slope_state = SLOPE_STATE_BIG
    elif absf(_slope_velocity.x) > medium or absf(_slope_velocity.y) > medium:
        _slope_state = SLOPE_STATE_MEDIUM


func _step_slope_axis(current: float, force: float, gain: float) -> float:
    var next := current + gain * signf(force)
    return force if absf(next) > absf(force) else next


## PlayerJump: no jump from a big slope unless facing within 45 degrees of downhill.
func _can_jump_on_slope() -> bool:
    if _slope_state != SLOPE_STATE_BIG or _slope_velocity.is_zero_approx():
        return true
    var downhill := Vector3(_slope_velocity.x, 0.0, _slope_velocity.y).normalized()
    return get_facing_direction().dot(downhill) >= cos(deg_to_rad(45.0))


func _slope_turn_multiplier() -> float:
    match _slope_state:
        SLOPE_STATE_BIG:
            return 0.0
        SLOPE_STATE_MEDIUM:
            return 0.25
    return 1.0


## BigSlope: forward speed x0.75 and turning becomes strafing; MediumSlope:
## speed x0.9 with half-speed strafing.
func _apply_slope_walk_modifiers(target_velocity: Vector3, turn_input: float) -> Vector3:
    if _slope_state == SLOPE_STATE_NONE:
        return target_velocity
    var forward_scale := 0.75 if _slope_state == SLOPE_STATE_BIG else 0.9
    var strafe_scale := 0.75 if _slope_state == SLOPE_STATE_BIG else 0.5
    var right := get_facing_direction().cross(Vector3.UP)
    return target_velocity * forward_scale + right * turn_input * movement_config.walk_speed * strafe_scale


## BigSlope: Sammy turns to face downhill (SpeedRotationPente 0.05 per tick).
func _apply_slope_downhill_turn(delta: float) -> void:
    if _slope_state != SLOPE_STATE_BIG or _slope_velocity.is_zero_approx():
        return
    var downhill := Vector3(_slope_velocity.x, 0.0, _slope_velocity.y).normalized()
    var target_yaw := atan2(-downhill.x, -downhill.z)
    var blend := 1.0 - pow(1.0 - SLOPE_DOWNHILL_TURN_RATE, maxf(delta, 0.0) * ACKNEX_TIME_UNITS_PER_SECOND)
    rotation.y += wrapf(target_yaw - rotation.y, -PI, PI) * blend


func _set_horizontal_velocity(horizontal_velocity: Vector3) -> void:
    velocity.x = horizontal_velocity.x
    velocity.z = horizontal_velocity.z


func _begin_jump(forward_input: float, boosting: bool, delta: float) -> bool:
    if not is_on_floor():
        return false
    if bool(movement_config.jump_requires_center_floor) and _center_floor_hit(float(movement_config.jump_center_floor_max_distance)).is_empty():
        return false
    if not _can_jump_on_slope():
        return false
    velocity.y = movement_config.jump_velocity
    _jump_fire_blocked = true
    _apply_jump_forward_velocity(forward_input, boosting, delta)
    _set_horizontal_velocity(_input_horizontal_velocity)
    return true


func _is_jump_air_control_active() -> bool:
    return _jump_fire_blocked and not is_on_floor()


func _make_horizontal_target_velocity(forward_input: float, boosting: bool, jump_air_control_active: bool) -> Vector3:
    if jump_air_control_active:
        return _make_jump_horizontal_target_velocity(forward_input, boosting)
    return get_facing_direction() * forward_input * _current_walk_speed(boosting)


func _make_jump_horizontal_target_velocity(forward_input: float, boosting: bool) -> Vector3:
    var jump_forward_speed := maxf(float(movement_config.jump_forward_speed), 0.0)
    var input_speed := forward_input * _current_walk_speed(boosting) * maxf(float(movement_config.jump_air_control_multiplier), 0.0)
    return get_facing_direction() * (jump_forward_speed + input_speed)


func _apply_jump_forward_velocity(forward_input: float, boosting: bool, delta: float) -> void:
    var jump_target_velocity := _make_jump_horizontal_target_velocity(forward_input, boosting)
    _input_horizontal_velocity = _input_horizontal_velocity.move_toward(jump_target_velocity, movement_config.acceleration * maxf(delta, 0.0))


func _try_step_up_from_low_obstacle(pre_move_transform: Transform3D, horizontal_motion: Vector3, was_on_floor: bool, jumped: bool) -> bool:
    if jumped or not was_on_floor:
        return false
    horizontal_motion.y = 0.0
    var desired_distance := horizontal_motion.length()
    if desired_distance <= 0.001:
        return false
    var move_direction := horizontal_motion / desired_distance
    var actual_horizontal_motion := global_position - pre_move_transform.origin
    actual_horizontal_motion.y = 0.0
    if actual_horizontal_motion.dot(move_direction) >= desired_distance * 0.5:
        return false
    var step_height := maxf(float(movement_config.low_step_height), 0.0)
    if step_height <= 0.0:
        return false
    if test_move(pre_move_transform, Vector3.UP * step_height):
        return false

    var raised_transform := pre_move_transform
    raised_transform.origin += Vector3.UP * step_height
    if test_move(raised_transform, horizontal_motion):
        return false

    var moved_transform := raised_transform
    moved_transform.origin += horizontal_motion
    var down_collision := KinematicCollision3D.new()
    if not test_move(moved_transform, Vector3.DOWN * (step_height + 0.05), down_collision):
        return false
    if down_collision.get_normal().dot(Vector3.UP) < 0.7:
        return false
    var landed_transform := moved_transform
    landed_transform.origin += down_collision.get_travel()
    var vertical_gain := landed_transform.origin.y - pre_move_transform.origin.y
    if vertical_gain < 0.01 or vertical_gain > step_height + 0.01:
        return false
    global_transform = landed_transform
    velocity.y = 0.0
    return true


func _resolve_enemy_push_direction(horizontal_source: Vector3, source: Node) -> Vector3:
    if source is Node3D:
        var away_from_source := global_position - (source as Node3D).global_position
        away_from_source.y = 0.0
        if away_from_source.length_squared() > 0.0:
            return away_from_source.normalized()
    if horizontal_source.length_squared() > 0.0:
        return horizontal_source.normalized()
    return Vector3.ZERO


func _try_apply_enemy_top_bounce(vertical_velocity_before_move: float) -> bool:
    if vertical_velocity_before_move > 0.0:
        return false

    for index in get_slide_collision_count():
        var collision := get_slide_collision(index)
        if collision == null:
            continue
        var collider := collision.get_collider() as Node
        if _apply_enemy_top_bounce(collider):
            return true
    return false


func _apply_enemy_top_bounce(source: Node) -> bool:
    if _dead or _game_over or _death_pad_respawning:
        return false
    if source == null or not source.has_method("allows_player_top_bounce"):
        return false
    if not bool(source.call("allows_player_top_bounce")):
        return false

    var enemy := source as Node3D
    if enemy == null or not _is_above_enemy_top(enemy):
        return false

    var bounce_velocity: float = movement_config.jump_velocity
    if source.has_method("get_player_top_bounce_velocity"):
        bounce_velocity = float(source.call("get_player_top_bounce_velocity"))
    if bounce_velocity <= 0.0:
        return false

    velocity.y = bounce_velocity
    _jump_fire_blocked = true
    _landing_movement_lock_remaining = 0.0
    _play_sfx(enemy_top_bounce_sound_asset_id)
    return true


func _is_above_enemy_top(enemy: Node3D) -> bool:
    var top_height := 0.0
    if enemy.has_method("get_player_top_bounce_height"):
        top_height = float(enemy.call("get_player_top_bounce_height"))
    return global_position.y >= enemy.global_position.y + top_height - 0.08


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
    if audio != null and audio.has_method("play_spatial_sfx"):
        audio.call("play_spatial_sfx", quick_turn_sound_asset_id, self, PLAYER_ENTITY_SOUND_WDL_RANGE_UNITS)
    elif audio != null and audio.has_method("play_sfx"):
        audio.call("play_sfx", quick_turn_sound_asset_id)


func _set_current_key_id(key_id: int, infinite: bool = false) -> void:
    var safe_infinite := infinite and key_id == KEY_DIAMOND_RULES_SCRIPT.KEY_ALL
    if _current_key_id == key_id and _current_key_is_infinite == safe_infinite:
        return
    var previous_key_id := _current_key_id
    _current_key_id = key_id
    _current_key_is_infinite = safe_infinite
    key_diamond_changed.emit(_current_key_id, previous_key_id)


func _spawn_ejected_key(key_id: int) -> Node:
    var parent := get_parent()
    if parent == null or key_id == KEY_DIAMOND_RULES_SCRIPT.KEY_NONE:
        return null
    var pickup := LAUNCHED_KEY_GEM_SCENE.instantiate() as Node3D
    if pickup == null:
        return null
    parent.add_child(pickup)
    pickup.global_position = global_position - get_facing_direction() * 1.15 + Vector3(0.0, 0.02, 0.0)
    if pickup.has_method("configure_launch"):
        var launch_velocity := -get_facing_direction() * 1.6 + Vector3.UP * 1.6
        pickup.call("configure_launch", key_id, 1001.0, launch_velocity, 5, self)
    elif pickup.has_method("configure_for_key_id"):
        pickup.call("configure_for_key_id", key_id)
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
    _play_sfx(asset_id, KEY_MIX_SOUND_WDL_RANGE_UNITS)


func _play_sfx(asset_id: String, wdl_range_units: float = PLAYER_ENTITY_SOUND_WDL_RANGE_UNITS) -> void:
    if asset_id.is_empty():
        return
    var audio := get_node_or_null("/root/Audio")
    if audio != null and audio.has_method("play_spatial_sfx"):
        audio.call("play_spatial_sfx", asset_id, self, wdl_range_units)
    elif audio != null and audio.has_method("play_sfx"):
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
    if _dead or _game_over or _exit_pad_victory_active:
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
    _death_phase = DEATH_PHASE_ANIMATION
    _death_elapsed = 0.0
    _death_animation_seconds = _get_death_duration_seconds()
    _death_timer = _death_animation_seconds
    _kaputt_sound_played = false
    _clear_action_state_for_death()
    _spawn_flying_heart()
    _reset_sammy_key()
    _play_animation_action(&"kaputt", 1.0, false, true, 0.0)
    _spawn_kaputt_stars()
    death_started.emit(source)


func _clear_action_state_for_death() -> void:
    _exit_pad_victory_active = false
    _exit_pad_victory_animation_started = false
    _exit_pad_victory_animation_delay_remaining = 0.0
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
    var budget := maxf(delta, 0.0)
    while _dead and not _game_over:
        var step := minf(budget, maxf(_death_timer, 0.0))
        _death_timer -= step
        budget -= step
        _advance_death_effects(step)
        if _death_timer > 0.0:
            return
        _advance_death_phase()


func _advance_death_effects(step: float) -> void:
    match _death_phase:
        DEATH_PHASE_ANIMATION:
            _death_elapsed += step
            if not _kaputt_sound_played and _death_elapsed * ACKNEX_TIME_UNITS_PER_SECOND >= KAPUTT_SOUND_TICK:
                _kaputt_sound_played = true
                _play_player_sound(kaputt_sound_asset_id, KAPUTT_SOUND_WDL_RANGE_UNITS)
        DEATH_PHASE_FADE_IN:
            _set_teleport_alpha(1.0 - maxf(_death_timer, 0.0) / _restart_fade_in_seconds())


func _advance_death_phase() -> void:
    match _death_phase:
        DEATH_PHASE_ANIMATION:
            _finish_death_sequence()
        DEATH_PHASE_BLINK:
            _death_blink_index += 1
            if _death_blink_index < DEATH_BLINK_WAITT_TICKS.size():
                _set_death_blink_visible(_death_blink_index % 2 == 1)
                _death_timer = ACKNEX_ENGINE_TIMING_SCRIPT.waitt_interval(DEATH_BLINK_WAITT_TICKS[_death_blink_index])
            else:
                _set_death_blink_visible(true)
                _begin_restart_fade_in()
        DEATH_PHASE_FADE_IN:
            _respawn_after_death()


func _finish_death_sequence() -> void:
    if not _dead or _game_over:
        return

    _lives = maxi(0, _lives - 1)
    life_lost.emit(_lives)
    if _lives <= 0:
        _enter_game_over()
        return

    _death_phase = DEATH_PHASE_BLINK
    _death_blink_index = 0
    _set_death_blink_visible(false)
    _death_timer = ACKNEX_ENGINE_TIMING_SCRIPT.waitt_interval(DEATH_BLINK_WAITT_TICKS[0])


## RestartSammy: stars gone, restart scan, hearts restored, Sammy back at the
## restart point and faded in from alpha 0.
func _begin_restart_fade_in() -> void:
    _remove_kaputt_stars()
    _restart_sammy_world()
    if _has_respawn_transform:
        global_transform = _respawn_transform
    _health = maxf(max_health, 0.0)
    velocity = Vector3.ZERO
    _enemy_push_velocity = Vector3.ZERO
    _input_horizontal_velocity = Vector3.ZERO
    _slope_velocity = Vector2.ZERO
    _clear_animation_sequence()
    _play_animation_action(&"stand", 1.0, false, true, 0.0)
    _set_teleport_alpha(0.0)
    _death_phase = DEATH_PHASE_FADE_IN
    _death_timer = _restart_fade_in_seconds()


func _respawn_after_death() -> void:
    _set_teleport_alpha(1.0)
    _set_death_blink_visible(true)
    _death_timer = 0.0
    _death_phase = DEATH_PHASE_ANIMATION
    _dead = false
    _game_over = false
    respawned.emit()


func _restart_fade_in_seconds() -> float:
    return RESTART_FADE_IN_TICKS / ACKNEX_TIME_UNITS_PER_SECOND


func _set_death_blink_visible(is_visible: bool) -> void:
    if visual_pivot != null:
        visual_pivot.visible = is_visible


## Seconds from a lethal hit until Sammy can move again (animation, blink,
## fade-in) when lives remain.
func get_death_sequence_seconds() -> float:
    var total := _get_death_duration_seconds() + _restart_fade_in_seconds()
    for wait_ticks in DEATH_BLINK_WAITT_TICKS:
        total += ACKNEX_ENGINE_TIMING_SCRIPT.waitt_interval(wait_ticks)
    return total


## Kaputt animation progress 0..1 (1 once the blink starts).
func get_death_animation_progress() -> float:
    if not _dead or _death_phase != DEATH_PHASE_ANIMATION or _death_animation_seconds <= 0.0:
        return 1.0
    return clampf(_death_elapsed / _death_animation_seconds, 0.0, 1.0)


func get_death_phase() -> int:
    return _death_phase


func get_kaputt_stars() -> Node3D:
    return _kaputt_stars if _kaputt_stars != null and is_instance_valid(_kaputt_stars) else null


func get_last_flying_heart() -> Node3D:
    return _last_flying_heart if _last_flying_heart != null and is_instance_valid(_last_flying_heart) else null


func _spawn_kaputt_stars() -> void:
    _remove_kaputt_stars()
    var parent := get_parent()
    if parent == null:
        return
    var stars := KAPUTT_STARS_SCRIPT.new() as Node3D
    stars.name = "KaputtStars"
    stars.call("setup", self)
    parent.add_child(stars)
    _kaputt_stars = stars


func _remove_kaputt_stars() -> void:
    if _kaputt_stars != null and is_instance_valid(_kaputt_stars):
        _kaputt_stars.queue_free()
    _kaputt_stars = null


## player.wdl Animmoins1life: a lifeA heart flies back towards the camera.
func _spawn_flying_heart() -> void:
    var parent := get_parent()
    if parent == null:
        return
    var heart := FLYING_HEART_SCRIPT.new() as Node3D
    heart.name = "FlyingHeart"
    parent.add_child(heart)
    heart.global_position = global_position
    var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
    var to_camera := -get_facing_direction()
    var distance_units := 400.0
    if camera != null:
        to_camera = camera.global_position - global_position
        distance_units = to_camera.length() / ACKNEX_TO_GODOT_SCALE
    heart.call("launch", to_camera, distance_units)
    _last_flying_heart = heart


func _play_player_sound(asset_id: String, wdl_range_units: float) -> void:
    if asset_id.is_empty():
        return
    var audio := get_node_or_null("/root/Audio")
    if audio != null and audio.has_method("play_spatial_sfx"):
        audio.call("play_spatial_sfx", asset_id, self, wdl_range_units)


## player.wdl ResetSammy (death and death pad): while the score goal is not
## reached, the carried key flies off as a decorative gem and is lost.
func _reset_sammy_key() -> void:
    if _current_key_id == KEY_DIAMOND_RULES_SCRIPT.KEY_NONE:
        return
    var game := get_node_or_null("/root/Game")
    if game != null and game.has_method("is_score_goal_reached") and bool(game.call("is_score_goal_reached")):
        return
    if KEY_DIAMOND_RULES_SCRIPT.is_valid_key_id(_current_key_id) and _current_key_id != KEY_DIAMOND_RULES_SCRIPT.KEY_ALL:
        _spawn_death_key(_current_key_id)
    clear_current_key()


## gems.wdl EjectNewKey with PlayerOldKey 0: a decorative gem launched 30
## quants above Sammy at PlayerSpeedZ 40 and at least 25 quants per tick.
func _spawn_death_key(key_id: int) -> Node:
    var parent := get_parent()
    if parent == null:
        return null
    var pickup := LAUNCHED_KEY_GEM_SCENE.instantiate() as Node3D
    if pickup == null:
        return null
    parent.add_child(pickup)
    pickup.global_position = global_position + Vector3.UP * DEATH_KEY_LAUNCH_HEIGHT
    var facing := get_facing_direction()
    var yaw_degrees := rad_to_deg(atan2(facing.x, -facing.z))
    if pickup.has_method("configure_wdl"):
        pickup.call("configure_wdl", key_id, 0.0, yaw_degrees, DEATH_KEY_HORIZONTAL_SPEED_UNITS, DEATH_KEY_VERTICAL_SPEED_UNITS, self)
    _last_death_key = pickup
    return pickup


func get_last_death_key() -> Node:
    return _last_death_key


## player.wdl RestartSammy: the ScanIdentite 1000 scan brings collected level
## key gems back (gems.wdl GemWaitForNewStart), removes gems spawned during
## play, and AttackCall = 0 stops the lions' call for help.
func _restart_sammy_world() -> void:
    if not is_inside_tree():
        return
    get_tree().call_group("key_diamond", "reset_for_player_restart", _current_key_id)
    get_tree().call_group("enemy", "reset_attack_call")


func _enter_game_over() -> void:
    _game_over = true
    _dead = true
    _death_timer = 0.0
    _clear_animation_sequence()
    _play_animation_action(&"finkaputt", 1.0, false, true, 0.0)
    game_over.emit()


func _get_death_duration_seconds() -> float:
    var max_seconds := DEATH_ANIMATION_MAX_TICKS / ACKNEX_TIME_UNITS_PER_SECOND
    var action_duration := _resolve_animation_action_duration(&"kaputt", 1.0)
    if action_duration > 0.0:
        return minf(action_duration, max_seconds)
    return minf(_seconds_for_wdl_animation_steps(PLAYER_DEATH_STEP_RANGE, PLAYER_DEATH_STEP_SPEED), max_seconds)


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
