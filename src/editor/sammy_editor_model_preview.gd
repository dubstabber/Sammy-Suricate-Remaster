@tool
extends Node3D
class_name SammyEditorModelPreview

const ASSETS_SCRIPT := preload("res://src/core/assets.gd")

@export var asset_id: String = "":
	set(value):
		asset_id = value
		_request_preview_refresh()
@export var visual_scale_multiplier: float = 1.0:
	set(value):
		visual_scale_multiplier = value
		_request_preview_refresh()
@export var visual_ground_clearance: float = 0.0:
	set(value):
		visual_ground_clearance = value
		_request_preview_refresh()
@export var wasp_type: Resource = null:
	set(value):
		wasp_type = value
		_request_preview_refresh()
@export var wasp_type_source_path: NodePath:
	set(value):
		wasp_type_source_path = value
		_request_preview_refresh()

var _assets: Node = null
var _preview_instance: Node3D = null
var _last_resolved_wasp_type: Resource = null


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	set_process(true)
	call_deferred("_rebuild_preview")


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _preview_instance == null or not is_instance_valid(_preview_instance):
		_rebuild_preview()
		return
	var resolved_wasp_type := _resolve_wasp_type()
	if resolved_wasp_type != _last_resolved_wasp_type:
		_rebuild_preview()


func _request_preview_refresh() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	call_deferred("_rebuild_preview")


func _rebuild_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_clear_preview()
	if asset_id.is_empty():
		return

	var assets := _get_assets()
	if assets == null or not assets.has_method("load_asset"):
		return
	var packed_scene := assets.call("load_asset", asset_id) as PackedScene
	if packed_scene == null:
		return

	_preview_instance = packed_scene.instantiate() as Node3D
	if _preview_instance == null:
		return
	_preview_instance.name = "PreviewVisual"
	_preview_instance.scale = (assets.call("get_model_scale", asset_id) as Vector3) * visual_scale_multiplier
	_preview_instance.rotation_degrees = assets.call("get_model_rotation_degrees", asset_id) as Vector3
	add_child(_preview_instance, false, Node.INTERNAL_MODE_FRONT)

	_last_resolved_wasp_type = _resolve_wasp_type()
	_apply_wasp_skin(assets, _last_resolved_wasp_type)
	_disable_runtime_effects(_preview_instance)
	_align_preview_to_ground(assets)


func _clear_preview() -> void:
	if _preview_instance == null:
		return
	if is_instance_valid(_preview_instance):
		remove_child(_preview_instance)
		_preview_instance.free()
	_preview_instance = null


func _get_assets() -> Node:
	var root_assets := get_node_or_null("/root/Assets")
	if root_assets != null and root_assets.has_method("load_asset"):
		return root_assets
	if _assets == null or not is_instance_valid(_assets):
		_assets = ASSETS_SCRIPT.new()
		_assets.name = "EditorPreviewAssets"
		_assets.call("rebuild")
		if is_inside_tree():
			add_child(_assets, false, Node.INTERNAL_MODE_BACK)
	return _assets


func _resolve_wasp_type() -> Resource:
	if not wasp_type_source_path.is_empty():
		var source := get_node_or_null(wasp_type_source_path)
		if source != null:
			var source_type := source.get("wasp_type") as Resource
			if source_type != null:
				return source_type
	return wasp_type


func _apply_wasp_skin(assets: Node, resolved_wasp_type: Resource) -> void:
	if _preview_instance == null or resolved_wasp_type == null or not assets.has_method("apply_wasp_skin"):
		return
	var raw_skin_index = resolved_wasp_type.get("skin_index")
	if raw_skin_index == null:
		return
	assets.call("apply_wasp_skin", _preview_instance, int(raw_skin_index))


func _disable_runtime_effects(node: Node) -> void:
	var animation_player := node as AnimationPlayer
	if animation_player != null:
		animation_player.stop()
		animation_player.speed_scale = 0.0
		animation_player.process_mode = Node.PROCESS_MODE_DISABLED

	var gpu_particles := node as GPUParticles3D
	if gpu_particles != null:
		gpu_particles.emitting = false
		gpu_particles.process_mode = Node.PROCESS_MODE_DISABLED

	var cpu_particles := node as CPUParticles3D
	if cpu_particles != null:
		cpu_particles.emitting = false
		cpu_particles.process_mode = Node.PROCESS_MODE_DISABLED

	for child in node.get_children():
		_disable_runtime_effects(child)


func _align_preview_to_ground(assets: Node) -> void:
	if _preview_instance == null or not assets.has_method("get_model_global_bounds"):
		return

	var should_ground := false
	if assets.has_method("should_ground_model"):
		should_ground = bool(assets.call("should_ground_model", asset_id))
	if not should_ground and visual_ground_clearance <= 0.0:
		return

	var bounds := assets.call("get_model_global_bounds", _preview_instance) as AABB
	if bounds.size == Vector3.ZERO:
		return
	var lift := (global_position.y + visual_ground_clearance) - bounds.position.y
	if not is_zero_approx(lift):
		_preview_instance.global_position.y += lift
