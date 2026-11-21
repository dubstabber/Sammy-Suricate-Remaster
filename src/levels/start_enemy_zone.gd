extends Node3D
class_name StartEnemyZone

## mm1.wdl InitStartEnnemy / StartEnnemy: every 8 ticks the zone scans Skill2
## quants around itself; the first enemy whose IdEnnemy matches Skill1 (8888
## for every lion and scorpion, 1111 for the unused elephant) is switched to
## LionEtat Skill3, with LionReactRange Skill5 and LionAttackRange Skill6 when
## non-zero. The zone then stops, or re-arms after Skill4 ticks.

const AcknexEngineTimingScript := preload("res://src/core/acknex_engine_timing.gd")
const QUANT := 0.01
const SCAN_WAIT_TICKS := 8.0
const LION_ID_ENNEMY := 8888
const ELEPHANT_ID_ENNEMY := 1111

@export var target_id_ennemy: int = LION_ID_ENNEMY
@export var scan_range_units: float = 300.0
@export var lion_state: int = 1
@export var rearm_ticks: float = 0.0
@export var react_range_units: float = 0.0
@export var attack_range_units: float = 0.0

var _scan_remaining := 0.0
var _rearm_remaining := 0.0
var _done := false
var _activated: Array[Node] = []


func configure_from_marker(marker: Node) -> void:
	target_id_ennemy = int(marker.call("get_skill", 1))
	scan_range_units = float(marker.call("get_skill", 2))
	lion_state = int(marker.call("get_skill", 3))
	rearm_ticks = float(marker.call("get_skill", 4))
	react_range_units = float(marker.call("get_skill", 5))
	attack_range_units = float(marker.call("get_skill", 6))


func is_done() -> bool:
	return _done


func get_activated_enemies() -> Array[Node]:
	return _activated.duplicate()


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if _done or not is_inside_tree():
		return
	var safe_delta := maxf(delta, 0.0)
	if _rearm_remaining > 0.0:
		_rearm_remaining -= safe_delta
		return
	_scan_remaining -= safe_delta
	if _scan_remaining > 0.0:
		return
	_scan_remaining = AcknexEngineTimingScript.waitt_interval(SCAN_WAIT_TICKS)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not (enemy is Node3D) or not _matches(enemy):
			continue
		if (enemy as Node3D).global_position.distance_to(global_position) > scan_range_units * QUANT:
			continue
		if enemy.has_method("apply_start_zone"):
			enemy.call("apply_start_zone", lion_state, react_range_units * QUANT, attack_range_units * QUANT)
		_activated.append(enemy)
		if rearm_ticks <= 0.0:
			_done = true
		else:
			_rearm_remaining = AcknexEngineTimingScript.waitt_interval(rearm_ticks)
		return


func _matches(enemy: Node) -> bool:
	if enemy.has_method("is_dead") and bool(enemy.call("is_dead")):
		return false
	var family := float(enemy.get("enemy_family_id")) if enemy.get("enemy_family_id") != null else 1.0
	# InitLion turns every lion / scorpion IdEnnemy into 8888, the elephant into 1111.
	var id_ennemy := ELEPHANT_ID_ENNEMY if is_equal_approx(family, 2.0) else LION_ID_ENNEMY
	return id_ennemy == target_id_ennemy
