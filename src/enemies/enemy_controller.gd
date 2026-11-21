extends CharacterBody3D
class_name SammyEnemyController

const ACKNEX_TO_GODOT_SCALE := 0.01
const ACKNEX_TICKS_PER_SECOND := 16.0
const PLAYER_BOUNCE_TICKS_PER_SECOND := ACKNEX_TICKS_PER_SECOND * 1.5
const WDL_SPEED_UNITS_TO_METERS_PER_SECOND := ACKNEX_TO_GODOT_SCALE * ACKNEX_TICKS_PER_SECOND
const MINIMUM_ANIMATION_SPEED_SCALE := 0.001
const DEFAULT_HIT_ANIMATION_RESISTANCE_MULTIPLIER := 0.3
const DEFAULT_MIN_HIT_ANIMATION_SPEED_SCALE := 5.0
const DEFAULT_MAX_HIT_ANIMATION_SPEED_SCALE := 10.0
const DEFAULT_ATTACK_CONTACT_MARGIN := 0.04
const ENEMY_ENTITY_SOUND_WDL_RANGE_UNITS := 1000.0
## anims.wdl LionEtat 11 end: one of LionHit1, LionHit2 or Tigre at random.
const LION_HIT_SOUND_IDS: Array[String] = ["sfx.lion_hit_1", "sfx.lion_hit_2", "sfx.lion_roar"]
const LION_ROAR_SOUND_ID := "sfx.lion_roar"
const LION_ATTACK_SOUND_ID := "sfx.lion_attack"
## skills.wdl LionRandomAttack: the charge cry plays when random(100) beats it.
const LION_RANDOM_ATTACK := 50.0
## lion.wdl stuck friend-call roar: Tigre at 2000 quants and LionAttack1 at 1500.
const LION_CALL_ROAR_RANGE_UNITS := 2000.0
const LION_CALL_ATTACK_RANGE_UNITS := 1500.0
## IdEnnemySpec of the standard lions (scorpions are 3).
const LION_FAMILY_ID := 1.0
const ENEMY_VISIBILITY_RANGE_SCRIPT := preload("res://src/effects/enemy_visibility_range.gd")

# WDL lion.wdl LionEtat parity. Numeric values match the original states so
# parity-driven tuning can refer back to the script directly.
enum EnemyState {
	WAIT = 0,
	WALK = 1,
	CHASE = 2,
	ROAR = 3,
	ALT_STAND = 4,
	DYING = 6,
	DEAD = 7,
	ATTACK_SWING = 10,
	HIT_RECOIL = 11,
	FLEE = 12,
	RANDOM_RUN = 13,
}

@export var asset_id: String = ""
@export var visual_path: NodePath = ^"Visual"
@export var animation_controller_path: NodePath = ^"ModelAnimationController"
@export var affected_by_gravity: bool = true
# WDL InitLvl/lion: ground enemies start at graviteEnnemy -4 and accelerate by AccgraviteEnnemy 3.
@export var original_gravity_velocity: float = -4.0
@export var original_gravity_acceleration: float = 3.0
@export var terminal_fall_speed: float = -40.0
@export var max_health: float = 4.0
@export var enemy_resistance: float = 0.0
@export var enemy_weight_force: float = 0.62
@export var enemy_family_id: float = 1.0

# Generic enemies use this as their immediate chase radius. Enemies that need
# the original LionReactRange/LionAttackRange split can set chase_start_range.
@export var react_range: float = 5.0
@export var chase_start_range: float = 0.0
@export var chase_disengage_range: float = 0.0
@export var chase_start_scan_interval_seconds: float = 0.0
@export_range(0.0, 1.0, 0.01) var chase_start_chance: float = 1.0
@export var attack_range: float = 1.1
@export var visibility_range_enabled: bool = true
@export var move_speed: float = 1.2
@export var run_speed: float = 1.8
@export var turn_rate_deg_per_sec: float = 220.0
# WDL line 1076: forward motion only when |BallDeltaPan| < 10 in walk.
@export var move_yaw_threshold_deg: float = 10.0
# WDL HandleSpeedLion keeps LionEtat 2 moving while it turns toward the player.
@export var chase_yaw_threshold_deg: float = 30.0
@export var attack_yaw_threshold_deg: float = 25.0
@export var wait_min: float = 1.5
@export var wait_max: float = 4.0
@export var alt_stand_chance: float = 0.35
@export var contact_damage: float = 1.0
@export var hargne_enemy: float = 2.0
@export var contact_damage_multiplier: float = 0.25
@export var attack_strike_ratio: float = 0.6
@export var attack_contact_margin: float = DEFAULT_ATTACK_CONTACT_MARGIN
# WDL lion.wdl:135-136: My.BounceForce = Frc(SpeedEnnemy)*100, fallback LionForce = 1.5.
# LionEtat 10 advances at 1.5x SpeedEnnemy.
@export var push_bounce_force: float = 1.5
@export var attack_push_speed_multiplier: float = 1.5
@export var attack_hit_push_source_speed: float = 2.7
@export var death_despawn_seconds: float = 0.4
# WDL mm1/anims/lion: generated walk/run clips encode LionAnimSpeedWalk/Run.
# Runtime playback scale supplies SpeedEnnemy or SpeedEnnemy * LionAccelattack,
# converted back from the Godot movement speed used by this controller.
@export var movement_animation_units_per_meter: float = 1.0 / WDL_SPEED_UNITS_TO_METERS_PER_SECOND
@export var walk_animation_speed_multiplier: float = 1.0
@export var chase_animation_speed_multiplier: float = 1.0
# Optional visual safety cap for special enemies with extra animation multipliers.
# Keep this disabled by default so inspector speed values stay authoritative.
@export var max_movement_animation_speed_scale: float = 0.0
@export var attack_animation_speed: float = 1.2
# WDL lion.wdl:470-472 computes hit speed as LionAnimSpeedHit *
# current EnnemyResistance * 0.3. The generated clip already
# encodes base LionAnimSpeedHit, so runtime playback uses a relative scale.
@export var hit_animation_speed: float = 10.0
@export var hit_animation_resistance_multiplier: float = DEFAULT_HIT_ANIMATION_RESISTANCE_MULTIPLIER
@export var min_hit_animation_speed_scale: float = DEFAULT_MIN_HIT_ANIMATION_SPEED_SCALE
@export var max_hit_animation_speed_scale: float = DEFAULT_MAX_HIT_ANIMATION_SPEED_SCALE
@export var hit_animation_blend_seconds: float = 0.0
@export var roar_animation_speed: float = 1.0
@export var death_animation_speed: float = 1.0
@export var perception_eye_height: float = 1.0
@export var target_eye_height: float = 0.7
@export var line_of_sight_mask: int = 1
@export var disengage_range_factor: float = 1.4
@export var roar_calls_friends: bool = true
@export var hurt_roar_health_ratio: float = 0.75
@export var hurt_flee_health_ratio: float = 0.5
@export var flee_speed_multiplier: float = 1.2
@export var enemy_frightened_seconds: float = 1.5
@export var attack_call_seconds: float = 8.0
@export var attack_call_range: float = 100.0
@export var attack_call_min_distance: float = 1.28
@export var hit_recoil_health_ratio: float = 0.95
# WDL anims.wdl:276-277 expands LionAttackRange/LionReactRange after LionEtat 11.
@export var post_hit_range_multiplier: float = 1.5
# WDL lion.wdl:319-372 Lion_Hit: when GuardStuckBalle accumulates past 10 while
# chasing/fleeing, the lion stops to roar (LionEtat=3) before resuming.
@export var blocked_roar_seconds: float = 0.6
# WDL lion.wdl:362 LionRandomTime = TimeForNothing*2 after a stuck-roar so the
# enemy cannot re-roar back-to-back.
@export var roar_cooldown_seconds: float = 4.0
# WDL lion.wdl: idle wait can pick LionEtat=13 (random run) instead of walking.
@export var random_run_chance: float = 0.1
@export var can_player_top_bounce: bool = false
@export var player_top_bounce_height: float = 0.55
@export var player_top_bounce_velocity: float = 30.0 * ACKNEX_TO_GODOT_SCALE * PLAYER_BOUNCE_TICKS_PER_SECOND
@export var attack_sound_asset_id: String = ""
@export var walk_sound_asset_id: String = ""
@export var attack_hit_sound_asset_ids: PackedStringArray = PackedStringArray(["sfx.enemy_hit_1", "sfx.enemy_hit_2", "sfx.enemy_hit_3"])
@export var attack_hit_sound_wdl_range_units: float = 2000.0
@export var attack_cycle_hit_sound_asset_ids: PackedStringArray = PackedStringArray(["sfx.enemy_hit_1", "sfx.enemy_hit_2", "sfx.enemy_hit_3"])
@export var attack_cycle_hit_sound_wdl_range_units: float = 1000.0
@export var attack_cycle_hit_sound_family_id: float = 1.0

signal damaged(amount: float, source: Node)
signal died(source: Node)
signal warning_attack(target: Node)
signal roar_started()
signal attack_call_started()
signal attack_landed(target: Node, amount: float)

static var _shared_attack_call_remaining: float = 0.0
static var _shared_attack_call_family_id: float = 0.0
static var _shared_attack_call_weight_force: float = 0.0
static var _shared_attack_call_last_frame: int = -1

var _fall_velocity_y: float = 0.0
var _health: float = 0.0
var _enemy_resistance_org: float = 0.0
var _is_dead: bool = false
var _state: int = EnemyState.WAIT
var _animation_controller: Node = null
var _animation_player: AnimationPlayer = null
var _target: Node3D = null
var _wait_remaining: float = 0.0
var _roar_remaining: float = 0.0
var _flee_remaining: float = 0.0
var _hit_resolved_this_swing: bool = false
var _contact_resolved_this_swing: bool = false
var _death_timer: float = 0.0
var _wander_target: Vector3 = Vector3.ZERO
var _has_wander_target: bool = false
var _last_target_push_frame: int = -1
var _attack_target: Node3D = null
var _attack_push_direction: Vector3 = Vector3.ZERO
var _attack_started_in_range: bool = false
var _blocked_time_accumulator: float = 0.0
var _roar_cooldown_remaining: float = 0.0
var _chase_start_scan_remaining: float = 0.0
var _visibility_range: Node = null
var _hit_recoil_should_chase: bool = false
var _attack_started_from_contact: bool = false
var _attack_reentry_finish_guard_frame: int = -1
var _post_hit_range_multiplier: float = 1.0


func _ready() -> void:
	add_to_group("enemy")
	_initialize_original_resistance()
	_apply_asset_catalog_settings()
	_ensure_visibility_range()
	_animation_controller = get_node_or_null(animation_controller_path)
	if _animation_controller != null:
		_animation_player = _animation_controller.get("animation_player") as AnimationPlayer
		if _animation_player != null and not _animation_player.animation_finished.is_connected(_on_animation_finished):
			_animation_player.animation_finished.connect(_on_animation_finished)
	_enter_state(EnemyState.WAIT)


func take_damage(amount: float, source: Node = null) -> void:
	if _is_dead or amount <= 0.0:
		return
	_health -= amount
	damaged.emit(amount, source)
	if _health <= 0.0:
		_health = 0.0
		_is_dead = true
		died.emit(source)
		_enter_state(EnemyState.DYING)
	elif _state != EnemyState.DYING and _state != EnemyState.DEAD:
		_refresh_target()
		if _should_start_hit_recoil():
			_hit_recoil_should_chase = _is_attackable_target(_target)
			_enter_state(EnemyState.HIT_RECOIL)


func get_health() -> float:
	return _health


func get_enemy_resistance() -> float:
	return _health


func get_enemy_resistance_org() -> float:
	return _enemy_resistance_org


func get_contact_damage_amount() -> float:
	if _health > 0.0:
		return _health * maxf(contact_damage_multiplier, 0.0)
	return maxf(contact_damage, 0.0)


func get_attack_damage_amount() -> float:
	return maxf(_health, 0.0) * maxf(hargne_enemy, 0.0)


func get_friend_call_key() -> float:
	# Kept for backward compatibility / parity tracing. WDL lion.wdl:1004 packs
	# IdEnnemySpec + weightForce into a single FriendCall scalar; matching now
	# uses the structural family-id + weight-force compare in _matches_attack_call.
	return enemy_family_id + enemy_weight_force


func _matches_attack_call() -> bool:
	return (
			is_equal_approx(_shared_attack_call_family_id, enemy_family_id)
			and is_equal_approx(_shared_attack_call_weight_force, enemy_weight_force)
	)


## player.wdl RestartSammy: AttackCall = 0.
static func clear_attack_call() -> void:
	_shared_attack_call_remaining = 0.0


func reset_attack_call() -> void:
	clear_attack_call()


func is_attack_call_active() -> bool:
	return _shared_attack_call_remaining > 0.0


func is_dead() -> bool:
	return _is_dead


func get_state() -> int:
	return _state


func get_target() -> Node3D:
	return _target


func get_visibility_range_node() -> Node:
	return _visibility_range


func is_visibility_range_visible() -> bool:
	return (
			_visibility_range != null
			and _visibility_range.has_method("is_range_visible")
			and bool(_visibility_range.call("is_range_visible"))
	)


func get_visibility_range_display_radius() -> float:
	if _visibility_range == null or not _visibility_range.has_method("get_display_radius"):
		return 0.0
	return float(_visibility_range.call("get_display_radius"))


func get_visibility_range_skin_number() -> int:
	if _visibility_range == null or not _visibility_range.has_method("get_current_skin_number"):
		return 0
	return int(_visibility_range.call("get_current_skin_number"))


func get_visibility_range_original_frame() -> int:
	if _visibility_range == null or not _visibility_range.has_method("get_current_original_frame"):
		return -1
	return int(_visibility_range.call("get_current_original_frame"))


func allows_player_top_bounce() -> bool:
	return can_player_top_bounce and not _is_dead and _state != EnemyState.DYING and _state != EnemyState.DEAD


func get_player_top_bounce_height() -> float:
	return maxf(player_top_bounce_height, 0.0)


func get_player_top_bounce_velocity() -> float:
	return maxf(player_top_bounce_velocity, 0.0)


func get_chase_start_range() -> float:
	var range_multiplier := maxf(_post_hit_range_multiplier, 1.0)
	if chase_start_range > 0.0:
		return chase_start_range * range_multiplier
	return maxf(react_range, 0.0) * range_multiplier


func get_chase_disengage_range() -> float:
	var range_multiplier := maxf(_post_hit_range_multiplier, 1.0)
	if chase_disengage_range > 0.0:
		return chase_disengage_range * range_multiplier
	return get_chase_start_range() * maxf(disengage_range_factor, 0.0)


func get_attack_range() -> float:
	return maxf(attack_range, 0.0) * maxf(_post_hit_range_multiplier, 1.0)


func get_attack_trigger_range(target: Node3D = null) -> float:
	var configured_range := maxf(attack_range, 0.0)
	if configured_range <= 0.0:
		return 0.0
	var body_contact_range := _combined_horizontal_collision_radius(target) + maxf(attack_contact_margin, 0.0)
	if body_contact_range <= 0.0:
		return configured_range
	return minf(configured_range, body_contact_range)


func _physics_process(delta: float) -> void:
	_update_shared_attack_call(delta)
	_roar_cooldown_remaining = maxf(0.0, _roar_cooldown_remaining - maxf(delta, 0.0))
	_chase_start_scan_remaining = maxf(0.0, _chase_start_scan_remaining - maxf(delta, 0.0))
	var horizontal := _update_ai(delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_refresh_movement_animation_speed()
	_apply_gravity(delta)
	move_and_slide()
	_try_begin_attack_from_chase_contact()
	_try_resolve_attack_hit_from_current_contact()
	if affected_by_gravity and is_on_floor() and velocity.y <= 0.0:
		_fall_velocity_y = 0.0
		velocity.y = 0.0
	_update_blocked_roar(delta)
	_refresh_visibility_range()


func get_animation_speed_units_for_horizontal_speed(horizontal_speed: float) -> float:
	var units_per_meter := maxf(movement_animation_units_per_meter, 0.0)
	return maxf(maxf(horizontal_speed, 0.0) * units_per_meter, MINIMUM_ANIMATION_SPEED_SCALE)


func get_capped_animation_speed_scale(speed_scale: float) -> float:
	var scale := maxf(speed_scale, MINIMUM_ANIMATION_SPEED_SCALE)
	if max_movement_animation_speed_scale <= 0.0:
		return scale
	return minf(scale, maxf(max_movement_animation_speed_scale, MINIMUM_ANIMATION_SPEED_SCALE))


func get_walk_movement_speed() -> float:
	return maxf(move_speed, 0.0)


func get_walk_animation_speed_scale() -> float:
	return get_capped_animation_speed_scale(
			get_animation_speed_units_for_horizontal_speed(move_speed) * maxf(walk_animation_speed_multiplier, 0.0)
	)


func get_chase_animation_action() -> StringName:
	return &"run"


func get_chase_movement_speed() -> float:
	return maxf(run_speed, 0.0)


func get_chase_animation_speed_scale() -> float:
	return get_capped_animation_speed_scale(
			get_animation_speed_units_for_horizontal_speed(run_speed) * maxf(chase_animation_speed_multiplier, 0.0)
	)


func get_attack_movement_speed() -> float:
	return maxf(run_speed, 0.0) * maxf(attack_push_speed_multiplier, 0.0)


func get_flee_movement_speed() -> float:
	return maxf(run_speed, 0.0) * maxf(flee_speed_multiplier, 0.0)


func get_hit_animation_speed_scale() -> float:
	var min_speed := maxf(min_hit_animation_speed_scale, MINIMUM_ANIMATION_SPEED_SCALE)
	var max_speed := maxf(max_hit_animation_speed_scale, min_speed)
	var base_step_speed := maxf(hit_animation_speed, MINIMUM_ANIMATION_SPEED_SCALE)
	var scaled_step_speed := base_step_speed * maxf(_health, 0.0) * maxf(hit_animation_resistance_multiplier, 0.0)
	return clampf(scaled_step_speed, min_speed, max_speed) / base_step_speed


func get_hit_animation_blend_seconds() -> float:
	return maxf(hit_animation_blend_seconds, 0.0)


func get_attack_push_source_velocity() -> Vector3:
	return _forward_velocity(maxf(run_speed, 0.0) * maxf(attack_push_speed_multiplier, 0.0))


func get_contact_push_source_velocity() -> Vector3:
	return _forward_velocity(run_speed)


func get_attack_hit_push_source_velocity() -> Vector3:
	var lunge := get_attack_push_source_velocity()
	if lunge.length_squared() > 0.0:
		return lunge
	var direction := _attack_push_direction
	if direction.length_squared() <= 0.0:
		return Vector3.ZERO
	return direction.normalized() * maxf(attack_hit_push_source_speed, 0.0)


func get_initial_fall_velocity() -> float:
	return original_gravity_velocity * ACKNEX_TICKS_PER_SECOND * ACKNEX_TO_GODOT_SCALE


func get_gravity_acceleration() -> float:
	return original_gravity_acceleration * ACKNEX_TICKS_PER_SECOND * ACKNEX_TICKS_PER_SECOND * ACKNEX_TO_GODOT_SCALE


func get_fall_velocity() -> float:
	return _fall_velocity_y


func reset_vertical_motion() -> void:
	_fall_velocity_y = 0.0
	velocity.y = 0.0


func _initialize_original_resistance() -> void:
	if enemy_resistance > 0.0:
		max_health = enemy_resistance
	else:
		enemy_resistance = max_health
	max_health = maxf(max_health, 0.0)
	enemy_resistance = maxf(enemy_resistance, 0.0)
	_health = max_health
	_enemy_resistance_org = max_health


func _update_shared_attack_call(delta: float) -> void:
	var current_frame := Engine.get_physics_frames()
	if _shared_attack_call_last_frame == current_frame:
		return
	_shared_attack_call_last_frame = current_frame
	_shared_attack_call_remaining = maxf(0.0, _shared_attack_call_remaining - maxf(delta, 0.0))
	if _shared_attack_call_remaining <= 0.0:
		_shared_attack_call_family_id = 0.0
		_shared_attack_call_weight_force = 0.0


func _start_attack_call() -> void:
	if _shared_attack_call_remaining > 0.0:
		return
	_shared_attack_call_remaining = maxf(attack_call_seconds, 0.0)
	_shared_attack_call_family_id = enemy_family_id
	_shared_attack_call_weight_force = enemy_weight_force
	attack_call_started.emit()


func _apply_gravity(delta: float) -> void:
	if not affected_by_gravity:
		_fall_velocity_y = 0.0
		velocity.y = 0.0
		return
	if is_on_floor():
		_fall_velocity_y = 0.0
	else:
		if is_zero_approx(_fall_velocity_y):
			_fall_velocity_y = get_initial_fall_velocity()
		_fall_velocity_y = maxf(
				_fall_velocity_y - get_gravity_acceleration() * delta,
				terminal_fall_speed
		)
	velocity.y = _fall_velocity_y


func _update_ai(delta: float) -> Vector3:
	if _state == EnemyState.DEAD:
		return Vector3.ZERO
	_refresh_target()
	match _state:
		EnemyState.WAIT, EnemyState.ALT_STAND:
			return _tick_wait(delta)
		EnemyState.WALK:
			return _tick_walk(delta)
		EnemyState.CHASE:
			return _tick_chase(delta)
		EnemyState.ROAR:
			return _tick_roar(delta)
		EnemyState.ATTACK_SWING:
			return _tick_attack_swing(delta)
		EnemyState.HIT_RECOIL:
			return Vector3.ZERO
		EnemyState.FLEE:
			return _tick_flee(delta)
		EnemyState.RANDOM_RUN:
			return _tick_random_run(delta)
		EnemyState.DYING:
			return _tick_dying(delta)
	return Vector3.ZERO


func _tick_wait(delta: float) -> Vector3:
	_wait_remaining = maxf(0.0, _wait_remaining - delta)
	if _should_answer_attack_call():
		_enter_state(EnemyState.CHASE)
		return Vector3.ZERO
	if _should_begin_chase():
		_play_charge_cry()
		_enter_state(EnemyState.CHASE)
		return Vector3.ZERO
	if _wait_remaining <= 0.0:
		if _state == EnemyState.ALT_STAND or randf() > alt_stand_chance:
			if randf() < clampf(random_run_chance, 0.0, 1.0):
				_enter_state(EnemyState.RANDOM_RUN)
			else:
				_enter_state(EnemyState.WALK)
		else:
			_enter_state(EnemyState.ALT_STAND)
	return Vector3.ZERO


func _tick_walk(delta: float) -> Vector3:
	if _should_answer_attack_call():
		_enter_state(EnemyState.CHASE)
		return Vector3.ZERO
	if _should_begin_chase():
		_play_charge_cry()
		_enter_state(EnemyState.CHASE)
		return Vector3.ZERO
	if not _has_wander_target:
		_enter_state(EnemyState.WAIT)
		return Vector3.ZERO
	var to_target := _wander_target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.2:
		_enter_state(EnemyState.WAIT)
		return Vector3.ZERO
	_turn_toward(to_target, delta)
	if absf(_yaw_delta_to(to_target)) > deg_to_rad(move_yaw_threshold_deg):
		return Vector3.ZERO
	return _forward_velocity(get_walk_movement_speed())


func _tick_chase(delta: float) -> Vector3:
	if _target == null:
		_enter_state(EnemyState.WAIT)
		return Vector3.ZERO
	var to_target := _target_horizontal_offset()
	var dist := to_target.length()
	_turn_toward(to_target, delta)
	var yaw_delta := _yaw_delta_to(to_target)
	if dist <= get_attack_trigger_range(_target) and absf(yaw_delta) <= deg_to_rad(attack_yaw_threshold_deg):
		_enter_state(EnemyState.ATTACK_SWING)
		return _attack_lunge_velocity()
	if dist > get_chase_disengage_range():
		_enter_state(EnemyState.WAIT)
		return Vector3.ZERO
	return _forward_velocity(get_chase_movement_speed())


func _tick_roar(delta: float) -> Vector3:
	if _target != null:
		_turn_toward(_target_horizontal_offset(), delta)
	_roar_remaining = maxf(0.0, _roar_remaining - delta)
	if _roar_remaining <= 0.0:
		_finish_roar()
	return Vector3.ZERO


func _tick_attack_swing(delta: float) -> Vector3:
	if not _is_attackable_target(_attack_target) and not _is_attackable_target(_target):
		_enter_state(EnemyState.WAIT)
		return Vector3.ZERO
	if _target != null:
		_turn_toward(_target_horizontal_offset(), delta)
	return _attack_lunge_velocity()


func _tick_flee(delta: float) -> Vector3:
	_flee_remaining = maxf(0.0, _flee_remaining - delta)
	if _flee_remaining <= 0.0:
		_enter_state(EnemyState.WALK if _target != null else EnemyState.WAIT)
		return Vector3.ZERO
	var away := Vector3.ZERO
	if _target != null:
		away = global_position - _target.global_position
		away.y = 0.0
	if away.length_squared() <= 0.0:
		away = -_forward_velocity(1.0)
	_turn_toward(away, delta)
	return _forward_velocity(get_flee_movement_speed())


func _tick_random_run(delta: float) -> Vector3:
	_wait_remaining = maxf(0.0, _wait_remaining - delta)
	if _wait_remaining <= 0.0:
		_enter_state(EnemyState.WALK)
		return Vector3.ZERO
	if _has_wander_target:
		_turn_toward(_wander_target - global_position, delta)
	return _forward_velocity(get_chase_movement_speed())


func _tick_dying(delta: float) -> Vector3:
	_death_timer = maxf(0.0, _death_timer - delta)
	if _death_timer <= 0.0:
		_state = EnemyState.DEAD
		queue_free()
	return Vector3.ZERO


func _enter_state(new_state: int) -> void:
	# WAIT/ROAR/ATTACK_SWING are re-entrant: WAIT picks a fresh idle timer, and
	# the action states need to restart their non-looping clip so
	# animation_finished fires again and drives the next transition. WDL only
	# enters LionEtat 11 when the enemy is not already in that hit state, so
	# repeated wasp damage must not restart the hit clip.
	var allow_reenter := (
			new_state == EnemyState.WAIT
			or new_state == EnemyState.ROAR
			or new_state == EnemyState.ATTACK_SWING
	)
	if _state == new_state and not allow_reenter:
		return
	var old_state := _state
	_state = new_state
	var blend_after_hit := 0.0 if old_state == EnemyState.HIT_RECOIL else -1.0
	_attack_reentry_finish_guard_frame = Engine.get_physics_frames() if old_state == EnemyState.ATTACK_SWING and new_state == EnemyState.ATTACK_SWING else -1
	_hit_resolved_this_swing = false
	_contact_resolved_this_swing = false
	_blocked_time_accumulator = 0.0
	match new_state:
		EnemyState.WAIT:
			_wait_remaining = randf_range(wait_min, wait_max)
			_has_wander_target = false
			_play_action(&"stand", 1.0)
		EnemyState.ALT_STAND:
			_wait_remaining = randf_range(wait_min, wait_max)
			_has_wander_target = false
			if _animation_controller_has_action(&"AltStand"):
				_play_action(&"AltStand", 1.0)
			else:
				_play_action(&"stand", 1.0)
		EnemyState.WALK:
			var angle := randf() * TAU
			var distance := randf_range(0.6, 1.6)
			_wander_target = global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
			_has_wander_target = true
			if old_state == EnemyState.CHASE or old_state == EnemyState.ATTACK_SWING:
				_play_sfx(walk_sound_asset_id)
			_play_action(&"walk", get_walk_animation_speed_scale())
		EnemyState.CHASE:
			# WDL calls Warning_Attack on LionEtat 1->2 only; the 10->2 return
			# after every swing (anims.wdl:253) is not a fresh warning.
			if old_state != EnemyState.CHASE and old_state != EnemyState.ATTACK_SWING:
				_begin_warning_attack()
			_play_action(get_chase_animation_action(), get_chase_animation_speed_scale(), false, blend_after_hit)
		EnemyState.ROAR:
			_begin_roar(blend_after_hit)
		EnemyState.ATTACK_SWING:
			_begin_attack_swing()
			_play_action(&"attack", attack_animation_speed, true)
		EnemyState.HIT_RECOIL:
			_play_action(&"hit", get_hit_animation_speed_scale(), true, get_hit_animation_blend_seconds())
		EnemyState.FLEE:
			_begin_flee(blend_after_hit)
		EnemyState.RANDOM_RUN:
			_begin_random_run()
		EnemyState.DYING:
			var death_duration := _resolve_action_duration(&"death", death_animation_speed)
			_death_timer = death_duration + maxf(death_despawn_seconds, 0.0)
			_play_action(&"death", death_animation_speed, true)
		EnemyState.DEAD:
			pass


func _refresh_movement_animation_speed() -> void:
	match _state:
		EnemyState.WALK:
			_play_action(&"walk", get_walk_animation_speed_scale())
		EnemyState.CHASE, EnemyState.FLEE, EnemyState.RANDOM_RUN:
			_play_action(get_chase_animation_action(), get_chase_animation_speed_scale())


func _begin_attack_swing() -> void:
	_play_sfx(attack_sound_asset_id)
	_attack_target = _target
	_attack_started_in_range = _attack_started_from_contact or (
			_target != null and _target_horizontal_offset().length() <= get_attack_trigger_range(_target)
	)
	_attack_started_from_contact = false
	_attack_push_direction = Vector3.ZERO
	if _target != null:
		_attack_push_direction = _target_horizontal_offset()
	if _attack_push_direction.length_squared() <= 0.0:
		_attack_push_direction = _forward_velocity(1.0)
	if _attack_push_direction.length_squared() > 0.0:
		_attack_push_direction = _attack_push_direction.normalized()
	if _attack_started_in_range and _attack_target != null and is_instance_valid(_attack_target):
		_resolve_attack_contact(_attack_target)


func _begin_warning_attack() -> void:
	if _target != null:
		warning_attack.emit(_target)


func _begin_roar(blend: float = -1.0) -> void:
	var duration := _resolve_action_duration(&"rugit", roar_animation_speed)
	_roar_remaining = duration if duration > 0.0 else 0.75
	_roar_cooldown_remaining = maxf(roar_cooldown_seconds, 0.0)
	_play_action(&"rugit", roar_animation_speed, true, blend)
	roar_started.emit()
	if roar_calls_friends:
		_start_attack_call()


func _update_blocked_roar(delta: float) -> void:
	if _roar_cooldown_remaining > 0.0:
		_blocked_time_accumulator = 0.0
		return
	if not _state_eligible_for_blocked_roar():
		_blocked_time_accumulator = 0.0
		return
	if not _is_blocked_against_world():
		_blocked_time_accumulator = 0.0
		return
	_blocked_time_accumulator += maxf(delta, 0.0)
	if _blocked_time_accumulator < maxf(blocked_roar_seconds, 0.0):
		return
	if _target != null and not _has_line_of_sight_to(_target):
		return
	_blocked_time_accumulator = 0.0
	_play_stuck_roar()
	_enter_state(EnemyState.ROAR)


func _state_eligible_for_blocked_roar() -> bool:
	return (
			_state == EnemyState.CHASE
			or _state == EnemyState.FLEE
			or _state == EnemyState.RANDOM_RUN
	)


func _is_blocked_against_world() -> bool:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision == null:
			continue
		var collider := collision.get_collider()
		if collider == null:
			continue
		if collider == _target:
			continue
		if collider is Node and (collider as Node).is_in_group("player"):
			continue
		return true
	return false


func _finish_roar() -> void:
	if _should_engage_target() or _should_answer_attack_call():
		_enter_state(EnemyState.CHASE)
	else:
		_enter_state(EnemyState.WAIT)


func _begin_flee(blend: float = -1.0) -> void:
	_flee_remaining = maxf(enemy_frightened_seconds, 0.0)
	_play_action(get_chase_animation_action(), get_chase_animation_speed_scale(), true, blend)


func _begin_random_run() -> void:
	_wait_remaining = randf_range(wait_min, wait_max)
	var angle := randf() * TAU
	_wander_target = global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(1.0, 2.0)
	_has_wander_target = true
	_play_action(get_chase_animation_action(), get_chase_animation_speed_scale(), true)


func _on_animation_finished(anim_name: StringName) -> void:
	match _state:
		EnemyState.ROAR:
			if not _is_finished_action(anim_name, &"rugit"):
				return
			_finish_roar()
		EnemyState.ATTACK_SWING:
			if not _is_finished_action(anim_name, &"attack"):
				return
			if _is_stale_animation_finish(anim_name):
				return
			_play_attack_cycle_hit_sfx()
			# WDL anims.wdl:253 always returns LionEtat 10 to 2; the next swing
			# starts from chase contact again instead of re-swinging at a gap.
			if _is_attackable_target(_target) and _target_horizontal_offset().length() <= get_chase_disengage_range():
				_enter_state(EnemyState.CHASE)
			else:
				_enter_state(EnemyState.WAIT)
		EnemyState.HIT_RECOIL:
			if not _is_finished_action(anim_name, &"hit"):
				return
			_finish_hit_recoil()
		EnemyState.DYING:
			pass


func _finish_hit_recoil() -> void:
	_play_lion_voice(LION_HIT_SOUND_IDS.pick_random())
	var should_chase_after_hit := _hit_recoil_should_chase
	_hit_recoil_should_chase = false
	_apply_post_hit_range_boost()
	if _should_roar_after_hit():
		_enter_state(EnemyState.ROAR)
	elif _should_flee_after_hit():
		_enter_state(EnemyState.FLEE)
	elif should_chase_after_hit and _is_attackable_target(_target):
		_enter_state(EnemyState.CHASE)
	elif _should_engage_target():
		_enter_state(EnemyState.CHASE)
	else:
		_enter_state(EnemyState.WAIT)


func _refresh_target() -> void:
	if _is_attackable_target(_target):
		return
	_target = null
	var tree := get_tree()
	if tree == null:
		return
	for candidate in tree.get_nodes_in_group("player"):
		if _is_attackable_target(candidate):
			_target = candidate as Node3D
			return


func _should_engage_target() -> bool:
	if not _is_attackable_target(_target):
		return false
	var to_target := _target_horizontal_offset()
	if to_target.length() > get_chase_start_range():
		return false
	return _has_line_of_sight_to(_target)


func _should_begin_chase() -> bool:
	if not _is_attackable_target(_target):
		return false
	var to_target := _target_horizontal_offset()
	if to_target.length() > get_chase_start_range():
		return false
	var scan_interval := maxf(chase_start_scan_interval_seconds, 0.0)
	if scan_interval > 0.0:
		if _chase_start_scan_remaining > 0.0:
			return false
		_chase_start_scan_remaining = scan_interval
	var chance := clampf(chase_start_chance, 0.0, 1.0)
	if chance <= 0.0:
		return false
	if chance < 1.0 and randf() > chance:
		return false
	return _has_line_of_sight_to(_target)


func _should_answer_attack_call() -> bool:
	if not is_attack_call_active() or not _is_attackable_target(_target):
		return false
	if not _matches_attack_call():
		return false
	var distance := _target_horizontal_offset().length()
	return distance < attack_call_range and distance > attack_call_min_distance


func _should_roar_after_hit() -> bool:
	if not roar_calls_friends or _enemy_resistance_org <= 0.0:
		return false
	return _health <= _enemy_resistance_org * clampf(hurt_roar_health_ratio, 0.0, 1.0)


func _should_flee_after_hit() -> bool:
	if _enemy_resistance_org <= 0.0:
		return false
	return _health <= _enemy_resistance_org * clampf(hurt_flee_health_ratio, 0.0, 1.0)


func _should_start_hit_recoil() -> bool:
	if _state == EnemyState.HIT_RECOIL:
		return false
	if _enemy_resistance_org <= 0.0:
		return true
	return _health < _enemy_resistance_org * clampf(hit_recoil_health_ratio, 0.0, 1.0)


func _target_horizontal_offset() -> Vector3:
	if _target == null:
		return Vector3.ZERO
	return _horizontal_offset_to(_target)


func _horizontal_offset_to(target: Node3D) -> Vector3:
	if target == null:
		return Vector3.ZERO
	var offset := target.global_position - global_position
	offset.y = 0.0
	return offset


func _yaw_delta_to(direction: Vector3) -> float:
	if direction.length_squared() <= 0.0:
		return 0.0
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0:
		return 0.0
	return forward.signed_angle_to(direction.normalized(), Vector3.UP)


func _turn_toward(direction: Vector3, delta: float) -> void:
	var yaw := _yaw_delta_to(direction)
	if absf(yaw) <= 0.0001:
		return
	var step := deg_to_rad(turn_rate_deg_per_sec) * delta
	var clamped := clampf(yaw, -step, step)
	rotation.y = wrapf(rotation.y + clamped, -PI, PI)


func _forward_velocity(speed: float) -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0:
		return Vector3.ZERO
	return forward.normalized() * speed


func _attack_lunge_velocity() -> Vector3:
	return _forward_velocity(get_attack_movement_speed())


func _has_line_of_sight_to(target: Node3D) -> bool:
	if target == null:
		return true
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var from := global_position + Vector3(0.0, perception_eye_height, 0.0)
	var to := target.global_position + Vector3(0.0, target_eye_height, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, line_of_sight_mask)
	query.exclude = [self, target]
	var hit := space.intersect_ray(query)
	return hit.is_empty()


# WDL lion.wdl:507-521 Lion_Hit EVENT_ENTITY: a LionEtat 2 enemy whose own move
# runs into the player switches to LionEtat 10 at once, whatever its heading.
# Without this a fast chaser that brushes the player's flank keeps orbiting.
func _try_begin_attack_from_chase_contact() -> void:
	if _state != EnemyState.CHASE:
		return
	if not _is_attackable_target(_target):
		return
	if not _has_current_side_contact_with(_target):
		return
	_attack_started_from_contact = true
	_enter_state(EnemyState.ATTACK_SWING)


func _has_current_side_contact_with(target: Node3D) -> bool:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision == null or collision.get_collider() != target:
			continue
		# Ignore a player standing on or bouncing off the enemy's head.
		if absf(collision.get_normal().y) < 0.7:
			return true
	return false


func _try_resolve_attack_hit_from_current_contact() -> void:
	if _state != EnemyState.ATTACK_SWING or _hit_resolved_this_swing:
		return
	if not _is_attack_hit_window_open():
		return
	var hit_target := _current_attack_hit_target()
	if not _is_attackable_target(hit_target):
		return
	if not _has_current_slide_contact_with(hit_target):
		return
	if _resolve_attack_hit():
		_play_random_sfx_at_node(attack_hit_sound_asset_ids, hit_target, attack_hit_sound_wdl_range_units)


func _is_attack_hit_window_open() -> bool:
	if _animation_player == null or not _animation_player.is_playing():
		return false
	var length := _animation_player.current_animation_length
	if length <= 0.0:
		return false
	var ratio := _animation_player.current_animation_position / length
	return ratio >= attack_strike_ratio


func _current_attack_hit_target() -> Node3D:
	var hit_target := _attack_target if _attack_target != null and is_instance_valid(_attack_target) else _target
	return hit_target


func _has_current_slide_contact_with(hit_target: Node3D) -> bool:
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision != null and collision.get_collider() == hit_target:
			return true
	return false


func _resolve_attack_hit() -> bool:
	var hit_target := _current_attack_hit_target()
	if not _is_attackable_target(hit_target):
		return false
	if not _attack_started_in_range and _horizontal_offset_to(hit_target).length() > get_attack_trigger_range(hit_target):
		return false
	if not hit_target.has_method("take_damage"):
		return false
	var damage := get_attack_damage_amount()
	var damage_result: Variant = hit_target.call("take_damage", damage, self)
	if damage_result is bool and not damage_result:
		return false
	_hit_resolved_this_swing = true
	_apply_attack_push_to_target(hit_target)
	attack_landed.emit(hit_target, damage)
	return true


func _resolve_attack_contact(hit_target: Node3D) -> void:
	if _contact_resolved_this_swing:
		return
	if not _is_attackable_target(hit_target):
		return
	_contact_resolved_this_swing = true
	if not hit_target.has_method("take_damage"):
		return
	var damage := get_contact_damage_amount()
	hit_target.call("take_damage", damage, self)
	_apply_push_to_target(hit_target, get_contact_push_source_velocity())
	attack_landed.emit(hit_target, damage)


func _apply_attack_push_to_target(target: Node3D) -> void:
	_apply_push_to_target(target, get_attack_hit_push_source_velocity())


func _apply_push_to_target(target: Node3D, source_velocity: Vector3) -> void:
	if not _is_attackable_target(target):
		return
	if not target.has_method("apply_enemy_push"):
		return
	var current_frame := Engine.get_physics_frames()
	if _last_target_push_frame == current_frame:
		return
	_last_target_push_frame = current_frame
	target.call("apply_enemy_push", source_velocity, push_bounce_force, self)


func _apply_post_hit_range_boost() -> void:
	_post_hit_range_multiplier *= maxf(post_hit_range_multiplier, 1.0)


func _combined_horizontal_collision_radius(target: Node3D) -> float:
	if target == null:
		return 0.0
	var own_radius := _horizontal_collision_radius(self)
	var target_radius := _horizontal_collision_radius(target)
	if own_radius <= 0.0 or target_radius <= 0.0:
		return 0.0
	return own_radius + target_radius


func _horizontal_collision_radius(node: Node3D) -> float:
	if node == null:
		return 0.0
	var radius := 0.0
	for child in node.get_children():
		var collision_shape := child as CollisionShape3D
		if collision_shape == null or collision_shape.disabled or collision_shape.shape == null:
			continue
		radius = maxf(radius, _shape_horizontal_radius(collision_shape))
	return radius


func _shape_horizontal_radius(collision_shape: CollisionShape3D) -> float:
	var shape := collision_shape.shape
	var scale_x := collision_shape.global_transform.basis.x.length()
	var scale_z := collision_shape.global_transform.basis.z.length()
	var horizontal_scale := maxf(scale_x, scale_z)
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).radius * horizontal_scale
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).radius * horizontal_scale
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius * horizontal_scale
	if shape is BoxShape3D:
		var box := shape as BoxShape3D
		return maxf(box.size.x * scale_x, box.size.z * scale_z) * 0.5
	return 0.0


func _is_attackable_target(candidate: Node) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	if not (candidate is Node3D):
		return false
	if candidate.has_method("is_game_over") and bool(candidate.call("is_game_over")):
		return false
	if candidate.has_method("is_dead") and bool(candidate.call("is_dead")):
		return false
	return true


func _play_action(action: StringName, custom_speed: float = 1.0, restart: bool = false, blend: float = -1.0) -> bool:
	if _animation_controller == null:
		return false
	if not _animation_controller_has_action(action):
		return false
	return bool(_animation_controller.call("play_action", action, blend, custom_speed, false, restart))


func _animation_controller_has_action(action: StringName) -> bool:
	if _animation_controller == null:
		return false
	return bool(_animation_controller.call("has_action", action))


func _is_finished_action(anim_name: StringName, action: StringName) -> bool:
	return anim_name == StringName("actions/%s" % String(action))


func _is_stale_animation_finish(anim_name: StringName) -> bool:
	if _state != EnemyState.ATTACK_SWING:
		return false
	if not _is_finished_action(anim_name, &"attack"):
		return false
	if _attack_reentry_finish_guard_frame < 0:
		return false
	if Engine.get_physics_frames() > _attack_reentry_finish_guard_frame + 1:
		return false
	if _animation_player == null:
		return false
	if _animation_player.current_animation != anim_name:
		return false
	if not _animation_player.is_playing():
		return false
	var length := _animation_player.current_animation_length
	if length <= 0.0:
		return false
	return _animation_player.current_animation_position < length * 0.95


func _resolve_action_duration(action: StringName, speed: float) -> float:
	if _animation_player == null or speed <= 0.0:
		return 0.0
	var qualified := StringName("actions/%s" % String(action))
	if not _animation_player.has_animation(qualified):
		return 0.0
	var anim := _animation_player.get_animation(qualified)
	if anim == null:
		return 0.0
	return anim.length / speed


func _ensure_visibility_range() -> void:
	if not visibility_range_enabled:
		return
	if _visibility_range != null and is_instance_valid(_visibility_range):
		return
	_visibility_range = ENEMY_VISIBILITY_RANGE_SCRIPT.new()
	_visibility_range.name = "VisibilityRange"
	add_child(_visibility_range)
	if _visibility_range.has_method("configure"):
		_visibility_range.call("configure", self)


func _refresh_visibility_range() -> void:
	if _visibility_range == null or not _visibility_range.has_method("refresh_from_enemy"):
		return
	_visibility_range.call("refresh_from_enemy")


func _apply_asset_catalog_settings() -> void:
	if asset_id.is_empty():
		return
	var visual := get_node_or_null(visual_path) as Node3D
	if visual == null:
		return
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return

	visual.scale = assets.get_model_scale(asset_id)
	visual.rotation_degrees = assets.get_model_rotation_degrees(asset_id)
	if assets.should_ground_model(asset_id):
		assets.align_model_instance_to_ground(visual, global_position.y)


func _play_attack_cycle_hit_sfx() -> void:
	if not is_equal_approx(enemy_family_id, attack_cycle_hit_sound_family_id):
		return
	_play_random_sfx_at_node(attack_cycle_hit_sound_asset_ids, self, attack_cycle_hit_sound_wdl_range_units)


func _play_random_sfx_at_node(asset_ids: PackedStringArray, source: Node3D, wdl_range_units: float) -> void:
	if asset_ids.is_empty():
		return
	var start_index := randi() % asset_ids.size()
	for offset in asset_ids.size():
		var asset_id := asset_ids[(start_index + offset) % asset_ids.size()]
		if not asset_id.is_empty():
			_play_sfx_at_node(asset_id, source, wdl_range_units)
			return


## lion.wdl / anims.wdl lion voices: `play_sound snd,100` then `Tune_Sound`
## with volume 30000 / DistLionPlayer and frequency 200 * WeightForce +-25 %.
func _play_lion_voice(asset_id: String) -> int:
	var audio := get_node_or_null("/root/Audio")
	if audio == null or not audio.has_method("play_sfx_tuned"):
		return 0
	var distance_units := maxf(_distance_to_player_units(), 1.0)
	var volume := 30000.0 / distance_units
	var frequency := 200.0 * enemy_weight_force + randf() * 50.0 - 25.0
	return int(audio.call("play_sfx_tuned", asset_id, volume, frequency))


## lion.wdl LionEtat 1 -> 2: standard lions cry LionAttack1 when random(100) > LionRandomAttack.
func _play_charge_cry() -> void:
	if not is_equal_approx(enemy_family_id, LION_FAMILY_ID):
		return
	if randf() * 100.0 > LION_RANDOM_ATTACK:
		_play_lion_voice(LION_ATTACK_SOUND_ID)


## lion.wdl GuardStuckBalle: a Flag7 lion with no call running roars for help,
## other lions growl Tigre; scorpions play their attack sound.
func _play_stuck_roar() -> void:
	if is_equal_approx(enemy_family_id, LION_FAMILY_ID):
		if roar_calls_friends and not is_attack_call_active():
			_play_sfx(LION_ROAR_SOUND_ID, LION_CALL_ROAR_RANGE_UNITS)
			_play_sfx(LION_ATTACK_SOUND_ID, LION_CALL_ATTACK_RANGE_UNITS)
		else:
			_play_lion_voice(LION_ROAR_SOUND_ID)
	elif not attack_sound_asset_id.is_empty():
		_play_sfx(attack_sound_asset_id)


## DistLionPlayer.Z: 3D distance to the player in quants.
func _distance_to_player_units() -> float:
	var player: Node3D = _target
	if player == null and is_inside_tree():
		player = get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return 1000.0
	return global_position.distance_to(player.global_position) / ACKNEX_TO_GODOT_SCALE


func _play_sfx(asset_id: String, wdl_range_units: float = ENEMY_ENTITY_SOUND_WDL_RANGE_UNITS) -> void:
	_play_sfx_at_node(asset_id, self, wdl_range_units)


func _play_sfx_at_node(asset_id: String, source: Node3D, wdl_range_units: float = ENEMY_ENTITY_SOUND_WDL_RANGE_UNITS) -> void:
	if asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_spatial_sfx"):
		audio.call("play_spatial_sfx", asset_id, source, wdl_range_units)
	elif audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", asset_id)
