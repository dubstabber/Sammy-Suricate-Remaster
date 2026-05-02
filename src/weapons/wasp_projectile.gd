extends Area3D
class_name WaspProjectile

const WASP_TYPE_SCRIPT := preload("res://src/resources/wasp_type.gd")
const MODEL_ANIMATION_CONTROLLER_SCRIPT := preload("res://src/animation/model_animation_controller.gd")
const WALK_ACTION := &"walk"
const DEATH_ACTION := &"death"
const ORIGINAL_IDPLAYER := 9999
const HIT_SOUND_WDL_RANGE_UNITS := 1500.0

@export var model_asset_id: String = "model.wasp1"
@export var hit_sound_asset_id: String = "sfx.wasp_kaput"

var _wasp_type: Resource = null
var _source_player: Node = null
var _velocity: Vector3 = Vector3.ZERO
var _lifetime_remaining: float = 0.0
var _model_instance: Node3D = null
var _animation_controller: Node = null
var _consumed: bool = false
var _forward_direction: Vector3 = Vector3.FORWARD
var _pitch_degrees: float = 0.0
var _dive_rise_remaining: float = 0.0
var _dive_hold_remaining: float = 0.0
var _dive_level_remaining: float = 0.0
var _dive_homing_unlocked: bool = true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func configure(wasp_type: Resource, source_player: Node, spawn_transform: Transform3D) -> void:
	_wasp_type = wasp_type
	_source_player = source_player
	global_transform = spawn_transform
	_lifetime_remaining = wasp_type.lifetime_seconds
	_forward_direction = _horizontal_direction(-global_transform.basis.z)
	_initialize_dive_arc()
	_refresh_velocity()
	_spawn_visual()
	_refresh_visual_orientation()


func _physics_process(delta: float) -> void:
	if _consumed:
		return

	_lifetime_remaining -= delta
	if _lifetime_remaining <= 0.0:
		_despawn(false)
		return

	_update_dive_arc(delta)
	if _can_home():
		_update_homing(delta)
	_refresh_velocity()
	_refresh_visual_orientation()
	global_position += _velocity * delta


func _on_body_entered(body: Node) -> void:
	if _consumed or body == null or body == _source_player:
		return

	_notify_wasp_hit(body)
	if body.has_method("take_damage") and _wasp_type != null:
		body.call("take_damage", int(_wasp_type.damage), self)

	_despawn(true)


func _spawn_visual() -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return

	var packed_scene: PackedScene = assets.load_asset(model_asset_id)
	if packed_scene == null:
		return

	_model_instance = packed_scene.instantiate() as Node3D
	if _model_instance == null:
		return

	_model_instance.name = "WaspVisual"
	var base_scale: Vector3 = assets.get_model_scale(model_asset_id)
	_model_instance.scale = base_scale * _get_wasp_visual_scale()
	_model_instance.rotation_degrees = assets.get_model_rotation_degrees(model_asset_id)
	add_child(_model_instance)
	_apply_wasp_skin(assets)
	_configure_model_animation(assets)


func _configure_model_animation(assets: Node) -> void:
	if _model_instance == null:
		return

	var library_path: String = assets.get_model_animation_library_path(model_asset_id)
	if library_path.is_empty():
		return

	_animation_controller = MODEL_ANIMATION_CONTROLLER_SCRIPT.new()
	_animation_controller.name = "ModelAnimationController"
	_model_instance.add_child(_animation_controller)
	_animation_controller.call("configure", _model_instance, library_path, String(WALK_ACTION), false)
	_play_visual_action(WALK_ACTION, _get_wasp_walk_animation_speed(), true)


func _get_wasp_visual_scale() -> float:
	if _wasp_type == null:
		return 1.0
	var raw_visual_scale = _wasp_type.get("visual_scale")
	if raw_visual_scale == null:
		return 1.0
	return float(raw_visual_scale)


func _apply_wasp_skin(assets: Node) -> void:
	if _wasp_type == null or not assets.has_method("apply_wasp_skin"):
		return
	var raw_skin_index = _wasp_type.get("skin_index")
	if raw_skin_index == null:
		return
	assets.call("apply_wasp_skin", _model_instance, int(raw_skin_index))


func _despawn(play_hit_sound: bool) -> void:
	if _consumed:
		return
	_consumed = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if play_hit_sound and not hit_sound_asset_id.is_empty():
		var audio := get_node_or_null("/root/Audio")
		if audio != null and audio.has_method("play_spatial_sfx"):
			audio.call("play_spatial_sfx", hit_sound_asset_id, self, HIT_SOUND_WDL_RANGE_UNITS)
		elif audio != null and audio.has_method("play_sfx"):
			audio.call("play_sfx", hit_sound_asset_id)
	var cleanup_delay := _play_visual_action(DEATH_ACTION, 1.0, true)
	_queue_cleanup_after_death(cleanup_delay)


func get_wasp_type() -> Resource:
	return _wasp_type


func get_idplayer() -> int:
	return ORIGINAL_IDPLAYER


func get_velocity() -> Vector3:
	return _velocity


func get_pitch_degrees() -> float:
	return _pitch_degrees


func is_dive_homing_unlocked() -> bool:
	return _dive_homing_unlocked


func is_consumed() -> bool:
	return _consumed


func get_animation_controller() -> Node:
	return _animation_controller


func is_death_animation_active() -> bool:
	return _consumed and _animation_controller != null


func _initialize_dive_arc() -> void:
	_pitch_degrees = 0.0
	_dive_rise_remaining = 0.0
	_dive_hold_remaining = 0.0
	_dive_level_remaining = 0.0
	_dive_homing_unlocked = true
	if _wasp_type == null or not _get_wasp_bool("dive_arc", false):
		return

	_dive_homing_unlocked = false
	_dive_rise_remaining = _get_wasp_float("dive_rise_seconds", 0.0)
	_dive_hold_remaining = _get_wasp_float("dive_hold_seconds", 0.0)
	_dive_level_remaining = _get_wasp_float("dive_level_seconds", 0.0)


func _update_dive_arc(delta: float) -> void:
	if _wasp_type == null or not _get_wasp_bool("dive_arc", false):
		return

	var remaining_delta := maxf(delta, 0.0)
	if _dive_rise_remaining > 0.0:
		var step := minf(_dive_rise_remaining, remaining_delta)
		_pitch_degrees = minf(65.0, _pitch_degrees + _get_wasp_float("dive_pitch_up_degrees_per_second", 0.0) * step)
		_dive_rise_remaining -= step
		remaining_delta -= step

	if remaining_delta > 0.0 and _dive_hold_remaining > 0.0:
		var step := minf(_dive_hold_remaining, remaining_delta)
		_dive_hold_remaining -= step
		remaining_delta -= step

	if remaining_delta > 0.0 and _dive_level_remaining > 0.0:
		var step := minf(_dive_level_remaining, remaining_delta)
		var level_rate := absf(_pitch_degrees) / maxf(_dive_level_remaining, step)
		_pitch_degrees = move_toward(_pitch_degrees, 0.0, level_rate * step)
		_dive_level_remaining -= step
		remaining_delta -= step

	if remaining_delta > 0.0:
		_dive_homing_unlocked = true
		_pitch_degrees = maxf(-65.0, _pitch_degrees - _get_wasp_float("dive_pitch_down_degrees_per_second", 0.0) * remaining_delta)
	elif _dive_rise_remaining <= 0.0 and _dive_hold_remaining <= 0.0 and _dive_level_remaining <= 0.0:
		_dive_homing_unlocked = true


func _can_home() -> bool:
	if _wasp_type == null or not _get_wasp_bool("homing", false):
		return false
	if _get_wasp_bool("dive_arc", false) and not _dive_homing_unlocked:
		return false
	return _get_wasp_float("homing_scan_range", 0.0) > 0.0


func _update_homing(delta: float) -> void:
	var target := _find_homing_target()
	if target == null:
		return

	var target_direction := (target.global_position + Vector3.UP * 0.5 - global_position).normalized()
	if target_direction == Vector3.ZERO:
		return

	var turn_speed := _get_wasp_float("homing_turn_speed_degrees", 0.0)
	if turn_speed <= 0.0:
		return

	if _get_wasp_bool("dive_arc", false):
		var target_horizontal := _horizontal_direction(target_direction)
		_forward_direction = _turn_direction_toward(_forward_direction, target_horizontal, turn_speed, delta)
		var desired_pitch := rad_to_deg(asin(clampf(target_direction.y, -1.0, 1.0)))
		var pitch_speed := maxf(_get_wasp_float("homing_pitch_speed_degrees", 0.0), absf(_get_wasp_float("dive_pitch_down_degrees_per_second", 0.0)))
		_pitch_degrees = move_toward(_pitch_degrees, desired_pitch, pitch_speed * delta)
	else:
		_forward_direction = _turn_direction_toward(_forward_direction, target_direction, turn_speed, delta)


func _find_homing_target() -> Node3D:
	var scan_range := _get_wasp_float("homing_scan_range", 0.0)
	if scan_range <= 0.0:
		return null

	var best_target: Node3D = null
	var best_distance := scan_range
	for candidate in get_tree().get_nodes_in_group("enemy"):
		if candidate == null or candidate == _source_player:
			continue
		if candidate.has_method("is_dead") and bool(candidate.call("is_dead")):
			continue
		var candidate_node := candidate as Node3D
		if candidate_node == null:
			continue
		var distance := global_position.distance_to(candidate_node.global_position)
		if distance <= best_distance:
			best_distance = distance
			best_target = candidate_node
	return best_target


func _notify_wasp_hit(body: Node) -> void:
	if body.has_method("hit_by_wasp"):
		body.call("hit_by_wasp", self)
		return
	var parent := body.get_parent()
	if parent != null and parent.has_method("hit_by_wasp"):
		parent.call("hit_by_wasp", self)


func _refresh_velocity() -> void:
	if _wasp_type == null:
		_velocity = Vector3.ZERO
		return
	var speed := _get_wasp_float("speed", 0.0)
	if _get_wasp_bool("dive_arc", false):
		_velocity = _direction_from_pitch() * speed
	else:
		_velocity = _forward_direction.normalized() * speed


func _refresh_visual_orientation() -> void:
	if _velocity.length_squared() <= 0.0001:
		return
	var transform := global_transform
	transform.basis = _basis_from_direction(_velocity)
	global_transform = transform


func _direction_from_pitch() -> Vector3:
	var horizontal := _horizontal_direction(_forward_direction)
	var pitch_radians := deg_to_rad(_pitch_degrees)
	var direction := horizontal * cos(pitch_radians) + Vector3.UP * sin(pitch_radians)
	if direction.length_squared() <= 0.0001:
		return horizontal
	return direction.normalized()


func _turn_direction_toward(current: Vector3, target: Vector3, turn_speed_degrees: float, delta: float) -> Vector3:
	var current_direction := current.normalized()
	var target_direction := target.normalized()
	if current_direction == Vector3.ZERO:
		return target_direction
	if target_direction == Vector3.ZERO:
		return current_direction

	var angle := current_direction.angle_to(target_direction)
	if angle <= 0.0001:
		return target_direction
	var max_turn := deg_to_rad(turn_speed_degrees) * maxf(delta, 0.0)
	var weight := clampf(max_turn / angle, 0.0, 1.0)
	return current_direction.slerp(target_direction, weight).normalized()


func _basis_from_direction(direction: Vector3) -> Basis:
	var forward := direction.normalized()
	if forward == Vector3.ZERO:
		return Basis()
	var up := Vector3.UP
	if absf(forward.dot(up)) > 0.98:
		up = Vector3.RIGHT
	var right := forward.cross(up).normalized()
	var corrected_up := right.cross(forward).normalized()
	return Basis(right, corrected_up, -forward)


func _horizontal_direction(direction: Vector3) -> Vector3:
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.length_squared() <= 0.0001:
		return Vector3.FORWARD
	return horizontal.normalized()


func _get_wasp_float(property_name: StringName, fallback: float) -> float:
	if _wasp_type == null:
		return fallback
	var raw_value = _wasp_type.get(property_name)
	if raw_value == null:
		return fallback
	return float(raw_value)


func _get_wasp_bool(property_name: StringName, fallback: bool) -> bool:
	if _wasp_type == null:
		return fallback
	var raw_value = _wasp_type.get(property_name)
	if raw_value == null:
		return fallback
	return bool(raw_value)


func _play_visual_action(action: StringName, custom_speed: float, restart: bool) -> float:
	if _animation_controller == null or not _animation_controller.has_method("play_action"):
		return 0.0
	if not bool(_animation_controller.call("play_action", action, 0.0, custom_speed, false, restart)):
		return 0.0
	return _get_visual_action_length_seconds(action, custom_speed)


func _get_visual_action_length_seconds(action: StringName, custom_speed: float) -> float:
	if _animation_controller == null:
		return 0.0
	var animation_player := _animation_controller.get("animation_player") as AnimationPlayer
	if animation_player == null:
		return 0.0
	var animation_name := StringName("actions/%s" % String(action))
	if not animation_player.has_animation(animation_name):
		return 0.0
	var speed := maxf(absf(custom_speed), 0.001)
	return animation_player.get_animation(animation_name).length / speed


func _get_wasp_walk_animation_speed() -> float:
	return maxf(_get_wasp_float("wdl_speed_units", 1.0), 0.001)


func _queue_cleanup_after_death(delay_seconds: float) -> void:
	if delay_seconds <= 0.0 or not is_inside_tree():
		queue_free()
		return
	var timer := get_tree().create_timer(delay_seconds)
	timer.timeout.connect(_on_death_animation_finished)


func _on_death_animation_finished() -> void:
	queue_free()
