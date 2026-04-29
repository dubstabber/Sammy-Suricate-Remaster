extends Node
class_name WaspInventory

const WASP_TYPE_SCRIPT := preload("res://src/resources/wasp_type.gd")

signal active_wasps_ejected(replaced_type: Resource)

var _current_type: Resource = null
var _ammo: int = 0


func has_ammo() -> bool:
	return _current_type != null and _ammo > 0


func consume_ammo(count: int = 1) -> bool:
	if count <= 0 or _ammo < count:
		return false
	_ammo -= count
	if _ammo <= 0:
		_ammo = 0
		_current_type = null
	return true


func add_ammo(wasp_type: Resource, amount: int) -> void:
	if wasp_type == null or amount <= 0:
		return

	if _current_type != null and _current_type != wasp_type:
		var replaced := _current_type
		_current_type = null
		_ammo = 0
		eject_active_wasps(replaced)

	_current_type = wasp_type
	_ammo += amount


func eject_active_wasps(replaced_type: Resource) -> void:
	active_wasps_ejected.emit(replaced_type)


func get_current_type() -> Resource:
	return _current_type


func get_ammo_count() -> int:
	return _ammo
