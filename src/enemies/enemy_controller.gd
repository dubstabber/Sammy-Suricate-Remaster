extends CharacterBody3D
class_name SammyEnemyController

const ACKNEX_TO_GODOT_SCALE := 0.01
const ACKNEX_TICKS_PER_SECOND := 16.0

# WDL lion.wdl LionEtat parity. Numeric values match the original states so
# parity-driven tuning can refer back to the script directly.
enum EnemyState {
	WAIT = 0,
	WALK = 1,
	CHASE = 2,
	ALT_STAND = 4,
	DYING = 6,
	DEAD = 7,
	ATTACK_SWING = 10,
	HIT_RECOIL = 11,
}

@export var asset_id: String = ""
@export var visual_path: NodePath = ^"Visual"
@export var animation_controller_path: NodePath = ^"ModelAnimationController"
@export var affected_by_gravity: bool = true
# WDL InitLvl/lion: ground enemies start at graviteEnnemy -4 and accelerate by AccgraviteEnnemy 3.
@export var original_gravity_velocity: float = -4.0
@export var original_gravity_acceleration: float = 3.0
@export var terminal_fall_speed: float = -40.0
@export var max_health: int = 3

# WDL LionAttackRange = 500 acknex units; 500 * 0.01 = 5 m engage radius.
@export var react_range: float = 5.0
@export var attack_range: float = 1.1
@export var move_speed: float = 1.2
@export var run_speed: float = 1.8
@export var turn_rate_deg_per_sec: float = 220.0
# WDL line 1076: forward motion only when |BallDeltaPan| < 10 in walk.
@export var move_yaw_threshold_deg: float = 10.0
# WDL line 1082: chase/attack uses a wider gate (~30) before stepping forward.
@export var chase_yaw_threshold_deg: float = 30.0
@export var attack_yaw_threshold_deg: float = 25.0
@export var wait_min: float = 1.5
@export var wait_max: float = 4.0
@export var alt_stand_chance: float = 0.35
@export var contact_damage: int = 1
@export var attack_strike_ratio: float = 0.45
@export var death_despawn_seconds: float = 0.4
@export var walk_animation_speed: float = 1.0
@export var run_animation_speed: float = 1.4
@export var attack_animation_speed: float = 1.2
@export var hit_animation_speed: float = 1.5
@export var death_animation_speed: float = 1.0
@export var perception_eye_height: float = 1.0
@export var target_eye_height: float = 0.7
@export var line_of_sight_mask: int = 1
@export var disengage_range_factor: float = 1.4

signal damaged(amount: int, source: Node)
signal died(source: Node)
signal attack_landed(target: Node, amount: int)

var _fall_velocity_y: float = 0.0
var _health: int = 0
var _is_dead: bool = false
var _state: int = EnemyState.WAIT
var _animation_controller: Node = null
var _animation_player: AnimationPlayer = null
var _target: Node3D = null
var _wait_remaining: float = 0.0
var _hit_resolved_this_swing: bool = false
var _death_timer: float = 0.0
var _wander_target: Vector3 = Vector3.ZERO
var _has_wander_target: bool = false


func _ready() -> void:
	add_to_group("enemy")
	_health = max_health
	_apply_asset_catalog_settings()
	_animation_controller = get_node_or_null(animation_controller_path)
	if _animation_controller != null:
		_animation_player = _animation_controller.get("animation_player") as AnimationPlayer
		if _animation_player != null and not _animation_player.animation_finished.is_connected(_on_animation_finished):
			_animation_player.animation_finished.connect(_on_animation_finished)
	_enter_state(EnemyState.WAIT)


func take_damage(amount: int, source: Node = null) -> void:
	if _is_dead or amount <= 0:
		return
	_health -= amount
	damaged.emit(amount, source)
	if _health <= 0:
		_health = 0
		_is_dead = true
		died.emit(source)
		_enter_state(EnemyState.DYING)
	elif _state != EnemyState.DYING and _state != EnemyState.DEAD:
		_enter_state(EnemyState.HIT_RECOIL)


func get_health() -> int:
	return _health


func is_dead() -> bool:
	return _is_dead


func get_state() -> int:
	return _state


func get_target() -> Node3D:
	return _target


func _physics_process(delta: float) -> void:
	var horizontal := _update_ai(delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	_apply_gravity(delta)
	move_and_slide()
	if affected_by_gravity and is_on_floor() and velocity.y <= 0.0:
		_fall_velocity_y = 0.0
		velocity.y = 0.0


func get_initial_fall_velocity() -> float:
	return original_gravity_velocity * ACKNEX_TICKS_PER_SECOND * ACKNEX_TO_GODOT_SCALE


func get_gravity_acceleration() -> float:
	return original_gravity_acceleration * ACKNEX_TICKS_PER_SECOND * ACKNEX_TICKS_PER_SECOND * ACKNEX_TO_GODOT_SCALE


func get_fall_velocity() -> float:
	return _fall_velocity_y


func reset_vertical_motion() -> void:
	_fall_velocity_y = 0.0
	velocity.y = 0.0


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
		EnemyState.ATTACK_SWING:
			return _tick_attack_swing(delta)
		EnemyState.HIT_RECOIL:
			return Vector3.ZERO
		EnemyState.DYING:
			return _tick_dying(delta)
	return Vector3.ZERO


func _tick_wait(delta: float) -> Vector3:
	_wait_remaining = maxf(0.0, _wait_remaining - delta)
	if _should_engage_target():
		_enter_state(EnemyState.CHASE)
		return Vector3.ZERO
	if _wait_remaining <= 0.0:
		if _state == EnemyState.ALT_STAND or randf() > alt_stand_chance:
			_enter_state(EnemyState.WALK)
		else:
			_enter_state(EnemyState.ALT_STAND)
	return Vector3.ZERO


func _tick_walk(delta: float) -> Vector3:
	if _should_engage_target():
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
	return _forward_velocity(move_speed)


func _tick_chase(delta: float) -> Vector3:
	if _target == null:
		_enter_state(EnemyState.WAIT)
		return Vector3.ZERO
	var to_target := _target_horizontal_offset()
	var dist := to_target.length()
	_turn_toward(to_target, delta)
	var yaw_delta := _yaw_delta_to(to_target)
	if dist <= attack_range and absf(yaw_delta) <= deg_to_rad(attack_yaw_threshold_deg):
		_enter_state(EnemyState.ATTACK_SWING)
		return Vector3.ZERO
	if dist > react_range * disengage_range_factor or not _has_line_of_sight_to(_target):
		_enter_state(EnemyState.WAIT)
		return Vector3.ZERO
	if absf(yaw_delta) > deg_to_rad(chase_yaw_threshold_deg):
		return Vector3.ZERO
	return _forward_velocity(run_speed)


func _tick_attack_swing(delta: float) -> Vector3:
	if _target != null:
		_turn_toward(_target_horizontal_offset(), delta)
	if not _hit_resolved_this_swing and _animation_player != null and _animation_player.is_playing():
		var length := _animation_player.current_animation_length
		if length > 0.0:
			var ratio := _animation_player.current_animation_position / length
			if ratio >= attack_strike_ratio:
				_resolve_attack_hit()
	return Vector3.ZERO


func _tick_dying(delta: float) -> Vector3:
	_death_timer = maxf(0.0, _death_timer - delta)
	if _death_timer <= 0.0:
		_state = EnemyState.DEAD
		queue_free()
	return Vector3.ZERO


func _enter_state(new_state: int) -> void:
	# WAIT/ATTACK_SWING/HIT_RECOIL are re-entrant: WAIT picks a fresh idle timer,
	# the action states need to restart their non-looping clip so animation_finished
	# fires again and drives the next transition.
	var allow_reenter := (
			new_state == EnemyState.WAIT
			or new_state == EnemyState.ATTACK_SWING
			or new_state == EnemyState.HIT_RECOIL
	)
	if _state == new_state and not allow_reenter:
		return
	_state = new_state
	_hit_resolved_this_swing = false
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
			_play_action(&"walk", walk_animation_speed)
		EnemyState.CHASE:
			_play_action(&"run", run_animation_speed)
		EnemyState.ATTACK_SWING:
			_play_action(&"attack", attack_animation_speed, true)
		EnemyState.HIT_RECOIL:
			_play_action(&"hit", hit_animation_speed, true)
		EnemyState.DYING:
			var death_duration := _resolve_action_duration(&"death", death_animation_speed)
			_death_timer = death_duration + maxf(death_despawn_seconds, 0.0)
			_play_action(&"death", death_animation_speed, true)
		EnemyState.DEAD:
			pass


func _on_animation_finished(_anim_name: StringName) -> void:
	match _state:
		EnemyState.ATTACK_SWING:
			if not _hit_resolved_this_swing:
				_resolve_attack_hit()
			if _should_engage_target():
				var dist := _target_horizontal_offset().length()
				if dist <= attack_range:
					_enter_state(EnemyState.ATTACK_SWING)
				else:
					_enter_state(EnemyState.CHASE)
			else:
				_enter_state(EnemyState.WAIT)
		EnemyState.HIT_RECOIL:
			if _should_engage_target():
				_enter_state(EnemyState.CHASE)
			else:
				_enter_state(EnemyState.WAIT)
		EnemyState.DYING:
			pass


func _refresh_target() -> void:
	if _target != null and is_instance_valid(_target):
		return
	_target = null
	var tree := get_tree()
	if tree == null:
		return
	var candidate := tree.get_first_node_in_group("player")
	if candidate is Node3D:
		_target = candidate


func _should_engage_target() -> bool:
	if _target == null:
		return false
	var to_target := _target_horizontal_offset()
	if to_target.length() > react_range:
		return false
	return _has_line_of_sight_to(_target)


func _target_horizontal_offset() -> Vector3:
	if _target == null:
		return Vector3.ZERO
	var offset := _target.global_position - global_position
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


func _resolve_attack_hit() -> void:
	_hit_resolved_this_swing = true
	if _target == null or not is_instance_valid(_target):
		return
	if _target_horizontal_offset().length() > attack_range * 1.2:
		return
	if not _target.has_method("take_damage"):
		return
	_target.call("take_damage", contact_damage, self)
	attack_landed.emit(_target, contact_damage)


func _play_action(action: StringName, custom_speed: float = 1.0, restart: bool = false) -> bool:
	if _animation_controller == null:
		return false
	if not _animation_controller_has_action(action):
		return false
	return bool(_animation_controller.call("play_action", action, -1.0, custom_speed, false, restart))


func _animation_controller_has_action(action: StringName) -> bool:
	if _animation_controller == null:
		return false
	return bool(_animation_controller.call("has_action", action))


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
