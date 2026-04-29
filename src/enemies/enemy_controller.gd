extends CharacterBody3D
class_name SammyEnemyController

const ACKNEX_TO_GODOT_SCALE := 0.01
const ACKNEX_TICKS_PER_SECOND := 16.0

@export var asset_id: String = ""
@export var visual_path: NodePath = ^"Visual"
@export var affected_by_gravity: bool = true
# WDL InitLvl/lion: ground enemies start at graviteEnnemy -4 and accelerate by AccgraviteEnnemy 3.
@export var original_gravity_velocity: float = -4.0
@export var original_gravity_acceleration: float = 3.0
@export var terminal_fall_speed: float = -40.0
@export var max_health: int = 3

signal damaged(amount: int, source: Node)
signal died(source: Node)

var _fall_velocity_y: float = 0.0
var _health: int = 0
var _is_dead: bool = false


func _ready() -> void:
	add_to_group("enemy")
	_health = max_health
	_apply_asset_catalog_settings()


func take_damage(amount: int, source: Node = null) -> void:
	if _is_dead or amount <= 0:
		return
	_health -= amount
	damaged.emit(amount, source)
	if _health <= 0:
		_health = 0
		_is_dead = true
		died.emit(source)
		queue_free()


func get_health() -> int:
	return _health


func is_dead() -> bool:
	return _is_dead


func _physics_process(delta: float) -> void:
	if not affected_by_gravity:
		_fall_velocity_y = 0.0
		velocity.y = 0.0
		move_and_slide()
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
	move_and_slide()
	if is_on_floor() and velocity.y <= 0.0:
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
