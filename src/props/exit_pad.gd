extends Area3D
class_name ExitPad

const CHARACTER_LAYER := 2
const PICKUP_SENSOR_LAYER := 4
const ACKNEX_TICKS_PER_SECOND := 16.0

@export var model_asset_id: String = "model.exit_pad.tile"
@export var win_sound_asset_id: String = "sfx.win"
@export var win_visual_asset_id: String = "model.win.title"
@export var win_visual_camera_offset: Vector3 = Vector3(0.0, -0.15, -2.4)
@export var win_visual_rotation_degrees: Vector3 = Vector3(0.0, -90.0, 0.0)
@export var require_grounded: bool = true
@export var completion_delay_seconds: float = 8.0 / ACKNEX_TICKS_PER_SECOND

var _visual_source_path := ""
var _model_instance: Node3D = null
var _win_visual_source_path := ""
var _win_visual_root: Node3D = null
var _win_visual_instance: Node3D = null
var _activated := false
var _completed := false
var _continue_requested := false
var _completion_delay_remaining := 0.0

@onready var _visual_root: Node3D = $VisualRoot


func _ready() -> void:
	add_to_group("exit_pad")
	collision_layer = PICKUP_SENSOR_LAYER
	collision_mask = CHARACTER_LAYER
	body_entered.connect(_on_body_entered)
	set_process_unhandled_input(false)
	_spawn_visual()


func _process(delta: float) -> void:
	if not _activated or _completed:
		return
	if _completion_delay_remaining > 0.0:
		_completion_delay_remaining = maxf(0.0, _completion_delay_remaining - maxf(delta, 0.0))
	if _continue_requested and _completion_delay_remaining <= 0.0:
		_complete_level()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_continue_input_event(event):
		return
	var viewport := get_viewport()
	if continue_after_win_input():
		if viewport != null:
			viewport.set_input_as_handled()


func _exit_tree() -> void:
	if is_instance_valid(_win_visual_root):
		_win_visual_root.queue_free()


func try_trigger_body(body: Node) -> bool:
	if _activated:
		return false
	if not _can_trigger_body(body):
		return false
	if body.has_method("begin_exit_pad_victory") and not bool(body.call("begin_exit_pad_victory", self)):
		return false

	_activated = true
	_completion_delay_remaining = maxf(completion_delay_seconds, 0.0)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_process_unhandled_input(true)
	_play_win_sound()
	_spawn_win_visual()
	return true


func continue_after_win_input() -> bool:
	if not _activated or _completed:
		return false
	_continue_requested = true
	if _completion_delay_remaining > 0.0:
		return false
	_complete_level()
	return true


func is_activated() -> bool:
	return _activated


func has_completed() -> bool:
	return _completed


func get_completion_delay_remaining() -> float:
	return _completion_delay_remaining


func get_visual_source_path() -> String:
	return _visual_source_path


func has_original_visual_model() -> bool:
	return not _visual_source_path.is_empty()


func get_visual_model_root() -> Node3D:
	return _visual_root


func has_win_visual() -> bool:
	return is_instance_valid(_win_visual_root)


func get_win_visual_root() -> Node3D:
	return _win_visual_root


func get_win_visual_source_path() -> String:
	return _win_visual_source_path


func _on_body_entered(body: Node3D) -> void:
	try_trigger_body(body)


func _can_trigger_body(body: Node) -> bool:
	if body == null or not body.is_in_group("player"):
		return false
	if require_grounded and body is CharacterBody3D and not (body as CharacterBody3D).is_on_floor():
		return false
	if _body_method_is_true(body, "is_dead"):
		return false
	if _body_method_is_true(body, "is_game_over"):
		return false
	if _body_method_is_true(body, "is_teleporting"):
		return false
	if _body_method_is_true(body, "is_death_pad_respawning"):
		return false
	if _body_method_is_true(body, "is_exit_pad_victory_active"):
		return false
	return true


func _body_method_is_true(body: Node, method_name: StringName) -> bool:
	return body.has_method(method_name) and bool(body.call(method_name))


func _is_continue_input_event(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	if key_event != null:
		return key_event.pressed and not key_event.echo
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null:
		return mouse_event.pressed
	var joy_event := event as InputEventJoypadButton
	if joy_event != null:
		return joy_event.pressed
	return false


func _complete_level() -> void:
	if _completed:
		return
	_completed = true
	set_process_unhandled_input(false)
	var game := get_node_or_null("/root/Game")
	if game == null or not game.has_method("show_main_menu"):
		return
	var err := int(game.call("show_main_menu"))
	if err != OK:
		push_warning("Exit pad could not return to the main menu: %s" % error_string(err))


func _play_win_sound() -> void:
	if win_sound_asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", win_sound_asset_id)


func _spawn_win_visual() -> void:
	if is_instance_valid(_win_visual_root) or win_visual_asset_id.is_empty():
		return
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	var packed_scene := assets.load_asset(win_visual_asset_id) as PackedScene
	if packed_scene == null:
		return

	var viewport := get_viewport()
	var parent: Node = viewport.get_camera_3d() if viewport != null else null
	if parent == null:
		parent = get_parent()
	if parent == null:
		parent = self

	_win_visual_root = Node3D.new()
	_win_visual_root.name = "ExitPadWinTitle"
	parent.add_child(_win_visual_root)
	if parent is Camera3D:
		_win_visual_root.position = win_visual_camera_offset
	else:
		_win_visual_root.global_position = global_position + Vector3.UP * 2.0

	_win_visual_instance = packed_scene.instantiate() as Node3D
	if _win_visual_instance == null:
		_win_visual_root.queue_free()
		_win_visual_root = null
		return
	_win_visual_instance.name = "WinTitleModel"
	_win_visual_instance.scale = assets.get_model_scale(win_visual_asset_id)
	_win_visual_instance.rotation_degrees = win_visual_rotation_degrees
	_win_visual_root.add_child(_win_visual_instance)
	_win_visual_source_path = assets.get_asset_path(win_visual_asset_id)
	_center_win_visual(assets)


func _center_win_visual(assets: Node) -> void:
	if _win_visual_root == null or _win_visual_instance == null:
		return
	if not assets.has_method("get_model_global_bounds"):
		return
	var bounds := assets.call("get_model_global_bounds", _win_visual_instance) as AABB
	if bounds.size == Vector3.ZERO:
		return
	_win_visual_instance.global_position += _win_visual_root.global_position - bounds.get_center()


func _spawn_visual() -> void:
	if _visual_root == null:
		return
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		_spawn_fallback_visual()
		return
	var packed_scene := assets.load_asset(model_asset_id) as PackedScene
	if packed_scene == null:
		_spawn_fallback_visual()
		return
	_model_instance = packed_scene.instantiate() as Node3D
	if _model_instance == null:
		_spawn_fallback_visual()
		return
	_model_instance.name = "ExitPadModel"
	_visual_root.add_child(_model_instance)
	_visual_source_path = assets.get_asset_path(model_asset_id)


func _spawn_fallback_visual() -> void:
	if _visual_root == null:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "ExitPadFallback"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.75
	mesh.bottom_radius = 0.75
	mesh.height = 0.08
	mesh.radial_segments = 32
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.04
	_visual_root.add_child(mesh_instance)
	_model_instance = mesh_instance
	_visual_source_path = ""
