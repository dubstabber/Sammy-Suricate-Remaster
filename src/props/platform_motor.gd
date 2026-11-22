extends Node3D
class_name PlatformMotor

## mm1.wdl InitEnginePlatForm: an invisible "motor" that drives every
## InitPlatForm sharing its Skill1 (SetLinkMoteur keeps each platform at its
## original offset from the motor, LoopPlatForm copies the motion each frame).
##
## The motor moves Skill2 quants per tick along its pan/tilt (`Move My,
## TempSpeed` with TempSpeed.x = Skill2 * MinTime, once per frame). On any
## collision moteurBonus_Hit turns it by Skill4 (pan) / Skill5 (tilt) and it
## pauses Skill3 ticks before moving on. Skill6 locks it until the player stands
## on a linked platform holding a matching key (PlatForm_Hit; Flag7 = exact).
##
## Collision is swept as a point against front faces only: a motor placed
## inside a brush (several shipped motors start a few quants inside one) moves
## out of it freely and stops when it next enters solid geometry, like a BSP
## point trace.

const KEY_RULES := preload("res://src/resources/key_diamond_rules.gd")
const AcknexCoordsScript := preload("res://src/levels/acknex_coords.gd")
const AcknexEngineTimingScript := preload("res://src/core/acknex_engine_timing.gd")

const DEFAULT_LINK_ID := 8465
const WORLD_LAYER := 1
## InitEnginePlatForm `waitt 2` before scanning for its platforms.
const START_DELAY_TICKS := 2.0
## `While (My.flag5 == 0) {waitt 4;}` lock poll.
const LOCK_POLL_TICKS := 4.0
const BOOST_SPEED_MULTIPLIER := 3.0
## Keeps the swept point just outside the surface it stopped on.
const CONTACT_SKIN := 0.001

enum UnlockResult { REJECTED, ALREADY_OPEN, UNLOCKED, UNLOCKED_SILENT }

@export var link_id: int = DEFAULT_LINK_ID
## Skill2: quants per tick.
@export var speed_units: float = 0.0
## Skill3: pause after each collision, in ticks.
@export var pause_ticks: float = 0.0
## Skill4 / Skill5: pan / tilt added on each collision.
@export var pan_step_degrees: float = 0.0
@export var tilt_step_degrees: float = 0.0
## Skill6: required player key (0 = unlocked).
@export var lock_key_id: int = KEY_RULES.KEY_NONE
## Flag7: the key must match exactly instead of the mixed-key rule.
@export var exact_key: bool = false
## Acknex pan / tilt of the motor (tilt 90 points straight up).
@export var pan_degrees: float = 0.0
@export var tilt_degrees: float = 0.0
@export_flags_3d_physics var sweep_mask: int = WORLD_LAYER
## The motor starts inside solid BSP space (converter `start_in_solid`): A5
## blocks every move from there, so it only turns and pauses (verified live on
## the 178d_t lift, whose motor sits inside a hill).
@export var start_in_solid: bool = false

var _platforms: Array[Node3D] = []
var _offsets: Array[Vector3] = []
var _start_remaining := 0.0
var _pause_remaining := 0.0
var _lock_poll_remaining := 0.0
var _unlock_requested := false
var _unlocked := true
var _last_displacement := Vector3.ZERO
var _hit_count := 0


func _ready() -> void:
	add_to_group("platform_motor")
	_start_remaining = AcknexEngineTimingScript.waitt_interval(START_DELAY_TICKS)
	_unlocked = lock_key_id == KEY_RULES.KEY_NONE


## SetLinkMoteur: remember the platform's offset from the motor's start.
func link_platform(platform: Node3D) -> void:
	if platform == null or _platforms.has(platform):
		return
	_platforms.append(platform)
	_offsets.append(platform.global_position - global_position)


func get_linked_platforms() -> Array[Node3D]:
	return _platforms.duplicate()


func get_platform_offset(platform: Node3D) -> Vector3:
	var index := _platforms.find(platform)
	return _offsets[index] if index >= 0 else Vector3.ZERO


func get_speed() -> float:
	return maxf(speed_units, 0.0) * AcknexCoordsScript.SCALE * AcknexEngineTimingScript.TICKS_PER_SECOND


func get_direction() -> Vector3:
	return AcknexCoordsScript.angle_direction(pan_degrees, tilt_degrees)


func get_pause_seconds() -> float:
	return AcknexEngineTimingScript.waitt_interval(pause_ticks) if pause_ticks > 0.0 else 0.0


func get_last_displacement() -> Vector3:
	return _last_displacement


func get_hit_count() -> int:
	return _hit_count


func is_locked() -> bool:
	return not _unlocked and not _unlock_requested


func is_moving() -> bool:
	return _unlocked and _start_remaining <= 0.0 and _pause_remaining <= 0.0


## PlatForm_Hit: a player standing on a linked platform with `player_key_id`.
func try_unlock(player_key_id: int) -> UnlockResult:
	if not is_locked():
		return UnlockResult.ALREADY_OPEN
	if player_key_id == KEY_RULES.KEY_ALL:
		_request_unlock()
		return UnlockResult.UNLOCKED_SILENT
	if not KEY_RULES.can_open_gate(player_key_id, lock_key_id, exact_key):
		return UnlockResult.REJECTED
	_request_unlock()
	return UnlockResult.UNLOCKED


func _request_unlock() -> void:
	_unlock_requested = true
	# The lock loop notices flag5 on its next `waitt 4` poll.
	if _lock_poll_remaining <= 0.0:
		_lock_poll_remaining = AcknexEngineTimingScript.waitt_interval(LOCK_POLL_TICKS)


func _physics_process(delta: float) -> void:
	advance(delta)


## One frame of InitEnginePlatForm's loop; exposed so tests can step it.
func advance(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	_last_displacement = Vector3.ZERO
	if _start_remaining > 0.0:
		_start_remaining -= safe_delta
		return
	if not _unlocked:
		if _unlock_requested:
			_lock_poll_remaining -= safe_delta
			if _lock_poll_remaining <= 0.0:
				_unlocked = true
		return
	if _pause_remaining > 0.0:
		_pause_remaining -= safe_delta
		return
	var previous := global_position
	_move(get_direction() * get_speed() * _speed_multiplier(safe_delta) * safe_delta)
	_last_displacement = global_position - previous
	_drive_platforms()


func _move(step: Vector3) -> void:
	if step.is_zero_approx():
		return
	if start_in_solid:
		_on_blocked()
		return
	var direction := step.normalized()
	var hit := _sweep(global_position, global_position + step + direction * CONTACT_SKIN)
	if hit.is_empty():
		global_position += step
		return
	global_position = (hit["position"] as Vector3) - direction * CONTACT_SKIN
	_on_blocked()


## moteurBonus_Hit: turn by Skill4/Skill5, then pause Skill3 ticks.
func _on_blocked() -> void:
	_hit_count += 1
	pan_degrees = fposmod(pan_degrees + pan_step_degrees, 360.0)
	tilt_degrees = fposmod(tilt_degrees + tilt_step_degrees, 360.0)
	_pause_remaining = get_pause_seconds()


func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, sweep_mask)
	var exclude: Array[RID] = []
	for platform in _platforms:
		if platform is CollisionObject3D:
			exclude.append((platform as CollisionObject3D).get_rid())
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(query)


## mm1.wdl InitEnginePlatForm: Shift triples the speed while the player stands
## on one of this motor's platforms (IdPlatform) and boost remains. The boost
## is drained by the player's own boost handling, or here when it is idle.
func _speed_multiplier(delta: float) -> float:
	var rider := _standing_rider()
	if rider == null:
		return 1.0
	if rider.has_method("is_boosting") and bool(rider.call("is_boosting")):
		return BOOST_SPEED_MULTIPLIER
	if rider.has_method("consume_platform_boost") and bool(rider.call("consume_platform_boost", delta)):
		return BOOST_SPEED_MULTIPLIER
	return 1.0


func _standing_rider() -> Node:
	for platform in _platforms:
		if is_instance_valid(platform) and platform.has_method("get_standing_rider"):
			var rider: Node = platform.call("get_standing_rider")
			if rider != null:
				return rider
	return null


func _drive_platforms() -> void:
	for index in _platforms.size():
		var platform := _platforms[index]
		if is_instance_valid(platform) and platform.has_method("follow_motor"):
			platform.call("follow_motor", global_position + _offsets[index])
