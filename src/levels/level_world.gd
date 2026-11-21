extends "res://src/prototype/prototype_world.gd"

## Root script for levels baked from original WMB files by
## `tools/build_level_scenes.gd`. Shares pause, score-goal, debug overlay and
## music wiring with the prototype world, and owns the level outcome flow
## (mm1.wdl main loop: PartieGagnee / BallesJoueur1 <= 0).

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const WDL_FLAG1_MASK := 1
const ACKNEX_TICKS_PER_SECOND := 16.0
const LOSE_TITLE_ASSET_ID := "model.lose.title"

@export var level_stem: String = ""
@export var level_number: int = 0
@export var source_wmb: String = ""
## WDL InitMarche spawn. The player is instanced here at runtime (not baked
## into the level) so player.tscn changes always reach every level.
@export var player_start_path: NodePath = ^"PlayerStart"
## Loads.wdl InitLevelN: BallesJoueur1 = NbrBallesStart (InitGame2 Skill1);
## level 10 is hard-coded to 4. 0 keeps the player scene default.
@export var level_starting_lives: int = 0
## Parent of the WDL InitSkyMenu sky models (mm1.wdl): each one without Flag1
## tracks the camera horizontally and keeps its initial height offset from the
## player; Flag1 skies stay where they were placed.
@export var sky_path: NodePath
@export var sky_follow_camera: bool = true
## mm1.wdl lost level: Lose.mdl title (InitTItleLoose, scale 0.32) in front of
## the camera, then a key press or 320 ticks before the level reloads.
@export var lose_title_camera_offset: Vector3 = Vector3(0.0, -0.15, -2.4)
@export var lose_title_rotation_degrees: Vector3 = Vector3(0.0, -90.0, 0.0)
@export var lose_continue_delay_seconds: float = 8.0 / ACKNEX_TICKS_PER_SECOND
@export var lose_auto_continue_seconds: float = 320.0 / ACKNEX_TICKS_PER_SECOND

var _skies: Array[Node3D] = []
var _sky_height_offsets: Array[float] = []
var _level_lost := false
var _level_lost_routed := false
var _lose_continue_delay_remaining := 0.0
var _lose_auto_continue_remaining := 0.0
var _lose_title_root: Node3D


func _enter_tree() -> void:
	# Before children are ready, so overlays and the camera find the player.
	_spawn_player()


func _ready() -> void:
	super._ready()
	_resolve_sky()
	_connect_player_outcome()


func _process(delta: float) -> void:
	_update_skies()
	if _level_lost:
		_update_level_lost(delta)


func _unhandled_input(event: InputEvent) -> void:
	# Captured first: continuing or restarting can route away and free this level.
	var viewport := get_viewport()
	if _level_lost:
		if _is_continue_press(event) and continue_after_level_lost() and viewport != null:
			viewport.set_input_as_handled()
		return
	if event.is_action_pressed("restart_level") and not is_pause_menu_visible():
		_on_restart_key()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	super._unhandled_input(event)


func get_sky() -> Node3D:
	return _skies[0] if not _skies.is_empty() else null


func get_following_skies() -> Array[Node3D]:
	return _skies.duplicate()


func get_player_start() -> Node3D:
	return get_node_or_null(player_start_path) as Node3D


func is_level_lost() -> bool:
	return _level_lost


func get_lose_title() -> Node3D:
	return _lose_title_root


## Starts the lost-level sequence (game over, R key, or pause Restart).
func begin_level_lost() -> void:
	if _level_lost:
		return
	_level_lost = true
	_lose_continue_delay_remaining = maxf(lose_continue_delay_seconds, 0.0)
	_lose_auto_continue_remaining = maxf(lose_auto_continue_seconds, 0.0)
	if player != null and not (player.has_method("is_game_over") and bool(player.call("is_game_over"))):
		# R / Restart end the loop with Sammy alive: freeze him in place.
		player.process_mode = Node.PROCESS_MODE_DISABLED
	_spawn_lose_title()


func continue_after_level_lost() -> bool:
	if not _level_lost or _level_lost_routed or _lose_continue_delay_remaining > 0.0:
		return false
	_finish_level_lost()
	return true


func _spawn_player() -> void:
	if player_path.is_empty() or get_node_or_null(player_path) != null:
		return
	var spawned := PLAYER_SCENE.instantiate() as Node3D
	spawned.name = String(player_path)
	if level_starting_lives > 0:
		spawned.set("starting_lives", level_starting_lives)
	var start := get_player_start()
	if start != null:
		spawned.transform = start.transform
	add_child(spawned)


func _connect_player_outcome() -> void:
	if player != null and player.has_signal("game_over") and not player.is_connected("game_over", _on_player_game_over):
		player.connect("game_over", _on_player_game_over)


func _on_player_game_over() -> void:
	begin_level_lost()


## mm1.wdl RecommencePartie: R sets the lives to 0 (a lost level); Shift+X+R is
## the original debug win (ScoreGoal 0, PartieGagnee 1).
func _on_restart_key() -> void:
	if Input.is_physical_key_pressed(KEY_SHIFT) and Input.is_physical_key_pressed(KEY_X):
		_route_via_game(&"complete_current_level")
		return
	begin_level_lost()


## options.wdl OuiRestartLevel sets BallesJoueur1 to 0, exactly like a game over.
func _on_pause_restart_requested() -> void:
	close_pause_menu()
	begin_level_lost()


func _update_level_lost(delta: float) -> void:
	_lose_continue_delay_remaining = maxf(0.0, _lose_continue_delay_remaining - maxf(delta, 0.0))
	if lose_auto_continue_seconds <= 0.0:
		return
	_lose_auto_continue_remaining = maxf(0.0, _lose_auto_continue_remaining - maxf(delta, 0.0))
	if _lose_auto_continue_remaining <= 0.0:
		_finish_level_lost()


func _finish_level_lost() -> void:
	if _level_lost_routed:
		return
	_level_lost_routed = true
	_route_via_game(&"fail_current_level")


func _is_continue_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if event is InputEventMouseButton or event is InputEventJoypadButton:
		return event.is_pressed()
	return false


func _spawn_lose_title() -> void:
	if is_instance_valid(_lose_title_root):
		return
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	var packed_scene := assets.load_asset(LOSE_TITLE_ASSET_ID) as PackedScene
	if packed_scene == null:
		return
	var view_camera := get_viewport().get_camera_3d()
	_lose_title_root = Node3D.new()
	_lose_title_root.name = "LoseTitle"
	if view_camera != null:
		view_camera.add_child(_lose_title_root)
		_lose_title_root.position = lose_title_camera_offset
	else:
		add_child(_lose_title_root)
		if player != null:
			_lose_title_root.global_position = player.global_position + Vector3.UP * 2.0
	var model := packed_scene.instantiate() as Node3D
	if model == null:
		return
	model.name = "LoseTitleModel"
	model.scale = assets.get_model_scale(LOSE_TITLE_ASSET_ID)
	model.rotation_degrees = lose_title_rotation_degrees
	_lose_title_root.add_child(model)
	var bounds := assets.call("get_model_global_bounds", model) as AABB
	if bounds.size != Vector3.ZERO:
		model.global_position += _lose_title_root.global_position - bounds.get_center()


## mm1.wdl PlayCurrentmusique: the level's MusicOrder track, on every (re)start.
func _start_music() -> void:
	if bool(ProjectSettings.get_setting("sammy/test/skip_music", false)) or DisplayServer.get_name() == "headless":
		return
	var game := get_node_or_null("/root/Game")
	var audio := get_node_or_null("/root/Audio")
	if game == null or audio == null or not game.has_method("get_music_asset_id_for_level"):
		return
	audio.call("play_music", String(game.call("get_music_asset_id_for_level", level_number)))


func _update_skies() -> void:
	if not sky_follow_camera or camera == null:
		return
	var camera_position := camera.global_position
	for index in _skies.size():
		var sky := _skies[index]
		if is_instance_valid(sky):
			sky.global_position = Vector3(camera_position.x, camera_position.y + _sky_height_offsets[index], camera_position.z)


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
