@tool
extends Marker3D
class_name LevelEntityMarker

## Placeholder for an original WMB entity that has no Godot prefab yet
## (level config, cameras, paths, titles, ...). Keeps the decoded record so
## later milestones can read it from the baked scene.

@export var source_index: int = -1
@export var action: String = ""
@export var source_action: String = ""
@export var source_name: String = ""
@export var source_file: String = ""
@export var skills: PackedFloat32Array = PackedFloat32Array()
@export var flags: int = 0
@export var acknex_position: Vector3 = Vector3.ZERO
@export var acknex_angles: Vector3 = Vector3.ZERO
@export var acknex_scale: Vector3 = Vector3.ONE


func get_skill(skill_number: int) -> float:
	var index := skill_number - 1
	if index < 0 or index >= skills.size():
		return 0.0
	return skills[index]


## WDL FlagN is bit N-1 of the entity flags word.
func has_flag(flag_number: int) -> bool:
	return flag_number >= 1 and (flags & (1 << (flag_number - 1))) != 0
