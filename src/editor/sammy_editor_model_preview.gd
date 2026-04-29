@tool
extends Node3D
class_name SammyEditorModelPreview

const ASSETS_SCRIPT := preload("res://src/core/assets.gd")
const PREVIEW_SETTLE_FRAMES := 4

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
@export var force_double_sided: bool = true:
	set(value):
		force_double_sided = value
		_request_preview_refresh()
@export var static_pose_action: String = "":
	set(value):
		static_pose_action = value
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
var _settle_frames_remaining := 0


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	set_process(true)
	call_deferred("_rebuild_preview")


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _preview_instance == null or not is_instance_valid(_preview_instance) or _preview_instance.get_parent() != self or not _preview_instance.is_inside_tree():
		_rebuild_preview()
		return
	var resolved_wasp_type := _resolve_wasp_type()
	if resolved_wasp_type != _last_resolved_wasp_type:
		_rebuild_preview()
		return
	if _settle_frames_remaining <= 0:
		return
	_settle_frames_remaining -= 1
	var assets := _get_assets()
	if assets != null:
		_enforce_preview_state(assets)


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
	_settle_frames_remaining = PREVIEW_SETTLE_FRAMES
	_enforce_preview_state(assets)


func _enforce_preview_state(assets: Node) -> void:
	if _preview_instance == null:
		return
	_disable_runtime_effects(_preview_instance)
	if force_double_sided:
		_force_preview_materials_double_sided(_preview_instance)
	_apply_static_animation_pose(assets)
	_align_preview_to_ground(assets)


func _clear_preview() -> void:
	if _preview_instance == null:
		return
	if is_instance_valid(_preview_instance):
		var parent := _preview_instance.get_parent()
		if parent != null:
			parent.remove_child(_preview_instance)
		_preview_instance.free()
	_preview_instance = null
	_settle_frames_remaining = 0


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


func _force_preview_materials_double_sided(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index) as BaseMaterial3D
			if material == null:
				continue
			if material.cull_mode == BaseMaterial3D.CULL_DISABLED and material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
				continue
			var preview_material := material.duplicate() as BaseMaterial3D
			preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			if preview_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
				preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			mesh_instance.set_surface_override_material(surface_index, preview_material)

	for child in node.get_children():
		_force_preview_materials_double_sided(child)


func _apply_static_animation_pose(assets: Node) -> void:
	if _preview_instance == null or assets == null:
		return
	if not assets.has_method("get_model_animation_library_path") or not assets.has_method("get_model_default_animation"):
		return

	var library_path: String = assets.call("get_model_animation_library_path", asset_id)
	if library_path.is_empty():
		return
	var action := static_pose_action
	if action.is_empty():
		action = assets.call("get_model_default_animation", asset_id)
	if action.is_empty():
		return

	var library := load(library_path) as AnimationLibrary
	if library == null or not library.has_animation(action):
		return

	var animation := library.get_animation(action)
	_reset_blend_shapes(_preview_instance)
	for track_index in animation.get_track_count():
		if animation.track_get_type(track_index) != Animation.TYPE_BLEND_SHAPE:
			continue
		if animation.track_get_key_count(track_index) <= 0:
			continue
		var track_path := String(animation.track_get_path(track_index))
		var colon_index := track_path.rfind(":")
		if colon_index < 0:
			continue
		var mesh_path := track_path.substr(0, colon_index)
		var shape_name := track_path.substr(colon_index + 1)
		var mesh_instance := _resolve_pose_mesh(mesh_path, shape_name)
		if mesh_instance == null:
			continue
		var shape_index := mesh_instance.find_blend_shape_by_name(shape_name)
		if shape_index < 0:
			continue
		mesh_instance.set_blend_shape_value(shape_index, float(animation.track_get_key_value(track_index, 0)))


func _reset_blend_shapes(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null:
		for shape_index in mesh_instance.get_blend_shape_count():
			mesh_instance.set_blend_shape_value(shape_index, 0.0)

	for child in node.get_children():
		_reset_blend_shapes(child)


func _resolve_pose_mesh(mesh_path: String, shape_name: String) -> MeshInstance3D:
	var target := _preview_instance.get_node_or_null(NodePath(mesh_path)) as MeshInstance3D
	if target != null:
		return target
	if _preview_instance.name == mesh_path and _preview_instance is MeshInstance3D:
		return _preview_instance as MeshInstance3D
	return _find_mesh_with_blend_shape(_preview_instance, shape_name)


func _find_mesh_with_blend_shape(node: Node, shape_name: String) -> MeshInstance3D:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.find_blend_shape_by_name(shape_name) >= 0:
		return mesh_instance

	for child in node.get_children():
		var found := _find_mesh_with_blend_shape(child, shape_name)
		if found != null:
			return found
	return null


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
