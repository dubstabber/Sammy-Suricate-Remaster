extends Node3D

const WMB_MANIFEST_SCRIPT := preload("res://src/levels/wmb_manifest.gd")
const WMB_MANIFEST_PATH := "res://assets/metadata/wmb_manifest.json"

@export var player_path: NodePath = ^"Player"
@export var camera_path: NodePath = ^"PrototypeCamera"
@export var debug_overlay_path: NodePath = ^"DebugOverlay"
@export var score_goal_points: int = 150
@export var score_start_points: int = 0

var player: CharacterBody3D
var camera: Camera3D


func _ready() -> void:
	_resolve_scene_nodes()
	_configure_score_goal()
	_configure_camera()
	_configure_debug_overlay()
	_load_level_manifest()
	_start_music()


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
