extends "res://src/prototype/prototype_world.gd"

## Root script for levels baked from original WMB files by
## `tools/build_level_scenes.gd`. Shares pause, score-goal, debug overlay and
## music wiring with the prototype world.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const WDL_FLAG1_MASK := 1

@export var level_stem: String = ""
@export var level_number: int = 0
@export var source_wmb: String = ""
## WDL InitMarche spawn. The player is instanced here at runtime (not baked
## into the level) so player.tscn changes always reach every level.
@export var player_start_path: NodePath = ^"PlayerStart"
## Parent of the WDL InitSkyMenu sky models (mm1.wdl): each one without Flag1
## tracks the camera horizontally and keeps its initial height offset from the
## player; Flag1 skies stay where they were placed.
@export var sky_path: NodePath
@export var sky_follow_camera: bool = true

var _skies: Array[Node3D] = []
var _sky_height_offsets: Array[float] = []


func _enter_tree() -> void:
	# Before children are ready, so overlays and the camera find the player.
	_spawn_player()


func _ready() -> void:
	super._ready()
	_resolve_sky()


func _process(_delta: float) -> void:
	if not sky_follow_camera or camera == null:
		return
	var camera_position := camera.global_position
	for index in _skies.size():
		var sky := _skies[index]
		if is_instance_valid(sky):
			sky.global_position = Vector3(camera_position.x, camera_position.y + _sky_height_offsets[index], camera_position.z)


func get_sky() -> Node3D:
	return _skies[0] if not _skies.is_empty() else null


func get_following_skies() -> Array[Node3D]:
	return _skies.duplicate()


func get_player_start() -> Node3D:
	return get_node_or_null(player_start_path) as Node3D


func _spawn_player() -> void:
	if player_path.is_empty() or get_node_or_null(player_path) != null:
		return
	var spawned := PLAYER_SCENE.instantiate() as Node3D
	spawned.name = String(player_path)
	var start := get_player_start()
	if start != null:
		spawned.transform = start.transform
	add_child(spawned)


func _resolve_sky() -> void:
	_skies.clear()
	_sky_height_offsets.clear()
	var sky_root := get_node_or_null(sky_path) as Node3D if not sky_path.is_empty() else null
	if sky_root == null:
		return
	var reference_y := player.global_position.y if player != null else 0.0
	for child in sky_root.get_children():
		var sky := child as Node3D
		if sky == null or (int(sky.get_meta("wmb_flags", 0)) & WDL_FLAG1_MASK) != 0:
			continue
		_skies.append(sky)
		_sky_height_offsets.append(sky.global_position.y - reference_y)


func _on_pause_restart_requested() -> void:
	close_pause_menu()
	_route_via_game(&"reload_current_level")
