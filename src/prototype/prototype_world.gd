extends Node3D

const PauseMenuOverlayScript := preload("res://src/ui/pause_menu_overlay.gd")
const WMB_MANIFEST_SCRIPT := preload("res://src/levels/wmb_manifest.gd")
const WMB_MANIFEST_PATH := "res://assets/metadata/wmb_manifest.json"

@export var player_path: NodePath = ^"Player"
@export var camera_path: NodePath = ^"PrototypeCamera"
@export var debug_overlay_path: NodePath = ^"DebugOverlay"
@export var pause_overlay_path: NodePath = ^"PauseMenuOverlay"
@export var score_goal_points: int = 150
@export var score_start_points: int = 0

var player: CharacterBody3D
var camera: Camera3D
var _pause_overlay: CanvasLayer


func _ready() -> void:
	_resolve_scene_nodes()
	_configure_score_goal()
	_configure_camera()
	_configure_debug_overlay()
	_ensure_pause_overlay()
	_load_level_manifest()
	_start_music()


func _exit_tree() -> void:
	if get_tree() != null and get_tree().paused and is_pause_menu_visible():
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_cancel") and not is_pause_menu_visible():
		open_pause_menu()
		get_viewport().set_input_as_handled()


func open_pause_menu() -> void:
	_ensure_pause_overlay()
	if _pause_overlay == null or is_pause_menu_visible():
		return
	if _pause_overlay.has_method("show_pause_menu"):
		_pause_overlay.call("show_pause_menu")
	get_tree().paused = true


func close_pause_menu() -> void:
	if _pause_overlay != null and _pause_overlay.has_method("hide_pause_menu"):
		_pause_overlay.call("hide_pause_menu")
	get_tree().paused = false


func is_pause_menu_visible() -> bool:
	return _pause_overlay != null and _pause_overlay.has_method("is_pause_menu_visible") and bool(_pause_overlay.call("is_pause_menu_visible"))


func is_pause_confirm_visible() -> bool:
	return _pause_overlay != null and _pause_overlay.has_method("is_confirm_visible") and bool(_pause_overlay.call("is_confirm_visible"))


func _resolve_scene_nodes() -> void:
	player = get_node_or_null(player_path) as CharacterBody3D
	if player == null:
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	camera = get_node_or_null(camera_path) as Camera3D


func _configure_camera() -> void:
	if camera == null or player == null:
		return
	camera.set("target_path", camera.get_path_to(player))
	if camera.has_method("reset_to_target"):
		camera.call("reset_to_target")


func _configure_score_goal() -> void:
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_method("configure_score_goal"):
		game.call("configure_score_goal", score_goal_points, score_start_points)


func _configure_debug_overlay() -> void:
	if player == null:
		return
	var overlay := get_node_or_null(debug_overlay_path)
	if overlay != null:
		overlay.set("player_path", overlay.get_path_to(player))


func _ensure_pause_overlay() -> void:
	_pause_overlay = get_node_or_null(pause_overlay_path) as CanvasLayer
	if _pause_overlay == null:
		_pause_overlay = PauseMenuOverlayScript.new()
		_pause_overlay.name = String(pause_overlay_path)
		add_child(_pause_overlay)
	_wire_pause_overlay()


func _wire_pause_overlay() -> void:
	if _pause_overlay == null:
		return
	if _pause_overlay.has_signal("resume_requested") and not _pause_overlay.is_connected("resume_requested", close_pause_menu):
		_pause_overlay.connect("resume_requested", close_pause_menu)
	if _pause_overlay.has_signal("restart_requested") and not _pause_overlay.is_connected("restart_requested", _on_pause_restart_requested):
		_pause_overlay.connect("restart_requested", _on_pause_restart_requested)
	if _pause_overlay.has_signal("main_menu_requested") and not _pause_overlay.is_connected("main_menu_requested", _on_pause_main_menu_requested):
		_pause_overlay.connect("main_menu_requested", _on_pause_main_menu_requested)
	if _pause_overlay.has_signal("quit_requested") and not _pause_overlay.is_connected("quit_requested", _on_pause_quit_requested):
		_pause_overlay.connect("quit_requested", _on_pause_quit_requested)


func _on_pause_restart_requested() -> void:
	close_pause_menu()
	_route_via_game(&"reload_prototype")


func _on_pause_main_menu_requested() -> void:
	close_pause_menu()
	_route_via_game(&"show_main_menu")


func _on_pause_quit_requested() -> void:
	if bool(ProjectSettings.get_setting("sammy/test/skip_quit", false)):
		return
	close_pause_menu()
	get_tree().quit()


func _route_via_game(method_name: StringName) -> void:
	var game := get_node_or_null("/root/Game")
	if game == null or not game.has_method(method_name):
		return
	var err := int(game.call(method_name))
	if err != OK:
		push_warning("Pause submenu route %s failed: %s" % [method_name, error_string(err)])


func _load_level_manifest() -> void:
	var manifest = WMB_MANIFEST_SCRIPT.new()
	var err: Error = manifest.load_file(WMB_MANIFEST_PATH)
	if err != OK:
		push_warning("Unable to read WMB manifest: %s" % error_string(err))
		return
	set_meta("wmb_manifest_counts", manifest.get_counts())


func _start_music() -> void:
	if bool(ProjectSettings.get_setting("sammy/test/skip_music", false)):
		return
	if not bool(ProjectSettings.get_setting("sammy/runtime/autoplay_music", false)):
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null:
		audio.play_music("music.sammy01")
