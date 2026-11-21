extends RefCounted
class_name LevelPathNetwork

## lion.wdl InitPath / PathScanned: the breadcrumb markers patrol lions follow.
## Each marker has Skill1 = path id, Skill2 = next path id (rewrites the lion's
## LionIdPath when scanned) and a pan/tilt heading the lion adopts near it.
##
## A WDL `SCAN pos, angle, (pan_width, tilt_width, range)` reaches markers in
## a cone; PathScanned keeps the first marker (in entity order) with a clear
## trace to the lion, skipping the lion's current target. If none is clear the
## last scanned one stays the target without being "found".

const AcknexCoordsScript := preload("res://src/levels/acknex_coords.gd")
const QUANT := 0.01
const WORLD_LAYER := 1
const SCAN_TILT_WIDTH_DEGREES := 120.0

var _markers: Array[Dictionary] = []
var _ids: Dictionary = {}


## Builds the network from baked LevelEntityMarker nodes (action "initpath").
static func from_config(config: Node) -> LevelPathNetwork:
	var network := LevelPathNetwork.new()
	if config == null:
		return network
	for child in config.get_children():
		if String(child.get("action")) != "initpath":
			continue
		var angles: Vector3 = child.get("acknex_angles")
		network.add_marker(
				int(child.call("get_skill", 1)),
				int(child.call("get_skill", 2)),
				(child as Node3D).global_position if child.is_inside_tree() else (child as Node3D).position,
				angles.x,
				angles.y,
				int(child.get("source_index")))
	return network


func add_marker(path_id: int, next_path_id: int, position: Vector3, pan_degrees: float, tilt_degrees: float, order: int = -1) -> void:
	_markers.append({
		"id": path_id,
		"next": next_path_id,
		"position": position,
		"pan": pan_degrees,
		"tilt": tilt_degrees,
		"order": order if order >= 0 else _markers.size(),
	})
	_markers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	_ids[path_id] = int(_ids.get(path_id, 0)) + 1


func has_path(path_id: int) -> bool:
	return _ids.has(path_id)


func marker_count(path_id: int = -1) -> int:
	if path_id < 0:
		return _markers.size()
	return int(_ids.get(path_id, 0))


## WDL SCAN for `path_id` from `origin` facing Acknex `heading_pan` with a
## horizontal cone `cone_width_degrees` wide and `range_m` deep.
## Returns {} when nothing was scanned, else {"position", "pan", "tilt",
## "found" (clear trace to `lion_position`), "path_id" (after Skill2 rewrites)}.
func scan(path_id: int, origin: Vector3, heading_pan: float, cone_width_degrees: float, range_m: float,
		lion_position: Vector3, skip_position: Variant = null, space: PhysicsDirectSpaceState3D = null,
		exclude: Array[RID] = []) -> Dictionary:
	var result := {}
	var current_id := path_id
	var half_pan := cone_width_degrees * 0.5
	var half_tilt := SCAN_TILT_WIDTH_DEGREES * 0.5
	var heading := AcknexCoordsScript.pan_direction(heading_pan)
	for marker in _markers:
		if int(marker["id"]) != current_id:
			continue
		var position: Vector3 = marker["position"]
		var offset := position - origin
		var distance := offset.length()
		if distance > range_m:
			continue
		if distance > 0.0001:
			var flat := Vector3(offset.x, 0.0, offset.z)
			if flat.length() > 0.0001 and rad_to_deg(heading.angle_to(flat.normalized())) > half_pan:
				continue
			if rad_to_deg(asin(clampf(offset.y / distance, -1.0, 1.0))) > half_tilt:
				continue
		if int(marker["next"]) != 0:
			current_id = int(marker["next"])
		if skip_position is Vector3 and position.is_equal_approx(skip_position as Vector3):
			continue
		result = {
			"position": position,
			"pan": float(marker["pan"]),
			"tilt": float(marker["tilt"]),
			"found": _clear_trace(space, position, lion_position, exclude),
			"path_id": current_id,
		}
		if bool(result["found"]):
			return result
	if not result.is_empty():
		result["path_id"] = current_id
	return result


func _clear_trace(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID]) -> bool:
	if space == null:
		return true
	var lift := Vector3.UP * 0.3
	var query := PhysicsRayQueryParameters3D.create(from + lift, to + lift, WORLD_LAYER)
	query.exclude = exclude
	return space.intersect_ray(query).is_empty()

