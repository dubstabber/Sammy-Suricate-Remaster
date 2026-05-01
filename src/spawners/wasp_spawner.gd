extends Area3D
class_name WaspSpawner

signal wasp_emitted(wasp: Node)

const LAUNCHED_WASP_PICKUP_SCENE := preload("res://scenes/pickups/launched_wasp_pickup.tscn")
const ACKNEX_TIME_UNITS_PER_SECOND := 16.0
const ACKNEX_TO_GODOT_SCALE := 0.01
const DEFAULT_WDL_TEMPORARY_LIFETIME_TICKS := 60.0
const WASP_PROJECTILE_IDPLAYER := 9999
const RANDOM_WASP_TYPE_ID := 999

const SOURCE_WMB_MODEL_ASSET_IDS := {
	"hiveblue.wmb": "model.wasp_spawner.hiveblue",
	"hivegree.wmb": "model.wasp_spawner.hivegree",
	"hivemult.wmb": "model.wasp_spawner.hivemult",
	"hivestri.wmb": "model.wasp_spawner.hivestri",
}

const ORIGINAL_PRESETS := {
	"auto_green_hive": {
		"source": "hivegree.wmb",
		"lifetime": 60.0,
		"vertical_speed": 20.0,
		"required_impactor": 0,
		"wasp_type": 4,
		"horizontal_speed": 20.0,
		"auto_interval": 48.0,
	},
	"auto_blue_hive": {
		"source": "hiveblue.wmb",
		"lifetime": 60.0,
		"vertical_speed": 20.0,
		"required_impactor": 0,
		"wasp_type": 3,
		"horizontal_speed": 20.0,
		"auto_interval": 48.0,
	},
	"auto_multi_hive": {
		"source": "hivemult.wmb",
		"lifetime": 60.0,
		"vertical_speed": 20.0,
		"required_impactor": 0,
		"wasp_type": RANDOM_WASP_TYPE_ID,
		"horizontal_speed": 20.0,
		"auto_interval": 48.0,
	},
	"impact_striped_hive": {
		"source": "hivestri.wmb",
		"lifetime": 96.0,
		"vertical_speed": 20.0,
		"required_impactor": WASP_PROJECTILE_IDPLAYER,
		"wasp_type": 1,
		"horizontal_speed": 10.0,
		"auto_interval": 0.0,
	},
}

@export var wasp_type: Resource = null
@export var wdl_wasp_type_id: int = 2
@export var ammo_amount: int = 1
@export var wdl_lifetime_ticks: float = DEFAULT_WDL_TEMPORARY_LIFETIME_TICKS
@export var wdl_vertical_speed_units: float = 20.0
@export var wdl_horizontal_speed_units: float = 20.0
@export var wdl_random_pan_degrees: float = 0.0
@export var wdl_random_horizontal_bonus_units: float = 5.0
@export var wdl_random_vertical_bonus_units: float = 4.0
@export var wdl_required_impactor_id: int = 0
@export var wdl_flag2_disable_impact: bool = false
@export var wdl_auto_interval_ticks: float = 0.0
@export var wdl_slot_limit: int = 10
@export var auto_emit_on_ready: bool = false
@export var auto_initial_delay_ticks: float = 32.0
@export var max_auto_emissions: int = 0
@export var spawn_offset: Vector3 = Vector3(0.0, 1.0, 0.0)
@export var spawn_parent_path: NodePath
@export var player_slot_source_path: NodePath
@export var required_impactor_group: StringName = &""
@export var default_ground_y: float = 0.0
@export var collectable_after_bounces: int = 1
@export var source_wmb_name: String = "hivegree.wmb"
@export var show_source_visual: bool = true

var _auto_delay_remaining_ticks := 0.0
var _auto_interval_remaining_ticks := 0.0
var _auto_emission_count := 0
var _waiting_for_player_slot := false
var _spawned_wasps: Array[Node] = []
var _visual_root: Node3D = null
var _solid_body: StaticBody3D = null
var _visual_source_path := ""
var _model_instance: Node3D = null


func _ready() -> void:
	add_to_group("wasp_spawner")
	body_entered.connect(_on_body_entered)
	_ensure_visual_root()
	_ensure_solid_body()
	_spawn_visual()
	_auto_delay_remaining_ticks = maxf(auto_initial_delay_ticks, 0.0)
	_auto_interval_remaining_ticks = maxf(wdl_auto_interval_ticks, 0.0)


func _process(delta: float) -> void:
	if not auto_emit_on_ready or wdl_auto_interval_ticks <= 0.0:
		return
	if max_auto_emissions > 0 and _auto_emission_count >= max_auto_emissions:
		return
	var elapsed_ticks := maxf(delta, 0.0) * ACKNEX_TIME_UNITS_PER_SECOND
	if _auto_delay_remaining_ticks > 0.0:
		var consumed_delay_ticks := minf(_auto_delay_remaining_ticks, elapsed_ticks)
		_auto_delay_remaining_ticks -= consumed_delay_ticks
		elapsed_ticks -= consumed_delay_ticks
		if elapsed_ticks <= 0.0:
			return
	_auto_interval_remaining_ticks -= elapsed_ticks
	if _auto_interval_remaining_ticks > 0.0:
		return
	_auto_interval_remaining_ticks = maxf(wdl_auto_interval_ticks, 0.0)
	var resolved_wasp_type := _resolve_wasp_type()
	if not _player_slot_allows_auto_emit(resolved_wasp_type):
		_waiting_for_player_slot = true
		return
	_waiting_for_player_slot = false
	var launched_wasp := _emit_wasp_at(global_position + spawn_offset, global_rotation.y, null, resolved_wasp_type)
	if launched_wasp != null:
		_auto_emission_count += 1


func emit_wasp() -> Node:
	return _emit_wasp_at(global_position + spawn_offset, global_rotation.y)


func emit_from_impactor(impactor: Node) -> Node:
	if wdl_flag2_disable_impact:
		return null
	if not _accepts_impactor(impactor):
		return null
	var spawn_position := global_position + spawn_offset
	var yaw := global_rotation.y
	var impactor_node := impactor as Node3D
	if impactor_node != null:
		spawn_position = impactor_node.global_position
		yaw = _yaw_from_impactor(impactor_node)
	return _emit_wasp_at(spawn_position, yaw, impactor)


func hit_by_wasp(projectile: Node) -> bool:
	return emit_from_impactor(projectile) != null


func get_spawned_wasps() -> Array[Node]:
	return _spawned_wasps.duplicate()


func get_spawned_count() -> int:
	return _spawned_wasps.size()


func is_waiting_for_player_slot() -> bool:
	return _waiting_for_player_slot


func get_random_angle_span_degrees() -> float:
	return maxf(wdl_random_pan_degrees, 0.0)


func get_effective_source_wmb_name() -> String:
	return source_wmb_name.get_file().to_lower()


func get_visual_source_path() -> String:
	return _visual_source_path


func get_visual_root() -> Node3D:
	return _visual_root


func has_original_visual_model() -> bool:
	return not _visual_source_path.is_empty()


func get_solid_body() -> StaticBody3D:
	return _solid_body


func get_solid_collision_shape() -> CollisionShape3D:
	if _solid_body == null:
		return null
	return _solid_body.get_node_or_null("CollisionShape3D") as CollisionShape3D


func requires_wasp_projectile() -> bool:
	return wdl_required_impactor_id == WASP_PROJECTILE_IDPLAYER


func apply_original_preset(preset_name: StringName) -> bool:
	var preset: Dictionary = ORIGINAL_PRESETS.get(String(preset_name), {})
	if preset.is_empty():
		return false
	source_wmb_name = String(preset["source"])
	wdl_lifetime_ticks = float(preset["lifetime"])
	wdl_vertical_speed_units = float(preset["vertical_speed"])
	wdl_required_impactor_id = int(preset["required_impactor"])
	wdl_wasp_type_id = int(preset["wasp_type"])
	wdl_horizontal_speed_units = float(preset["horizontal_speed"])
	wdl_auto_interval_ticks = float(preset["auto_interval"])
	wdl_slot_limit = 10
	auto_emit_on_ready = wdl_auto_interval_ticks > 0.0
	auto_initial_delay_ticks = 32.0 if auto_emit_on_ready else 0.0
	_auto_delay_remaining_ticks = maxf(auto_initial_delay_ticks, 0.0)
	_auto_interval_remaining_ticks = maxf(wdl_auto_interval_ticks, 0.0)
	if is_inside_tree():
		_spawn_visual()
	return true


func _on_body_entered(body: Node3D) -> void:
	emit_from_impactor(body)


func _accepts_impactor(impactor: Node) -> bool:
	if impactor == null:
		return false
	if not String(required_impactor_group).is_empty() and not impactor.is_in_group(required_impactor_group):
		return false
	if wdl_required_impactor_id == 0:
		return true
	if impactor.has_method("get_idplayer"):
		return int(impactor.call("get_idplayer")) == wdl_required_impactor_id
	return false


func _emit_wasp_at(spawn_position: Vector3, yaw: float, source: Node = null, forced_wasp_type: Resource = null) -> Node:
	var resolved_wasp_type := forced_wasp_type if forced_wasp_type != null else _resolve_wasp_type()
	if resolved_wasp_type == null:
		return null
	var launched_wasp := LAUNCHED_WASP_PICKUP_SCENE.instantiate() as Area3D
	if launched_wasp == null:
		return null

	launched_wasp.set("wasp_type", resolved_wasp_type)
	launched_wasp.set("ammo_amount", maxi(ammo_amount, 1))
	var parent := _resolve_spawn_parent()
	parent.add_child(launched_wasp)
	launched_wasp.global_position = spawn_position
	launched_wasp.set("ground_y", default_ground_y)
	var configured := bool(launched_wasp.call(
		"configure_launch",
		resolved_wasp_type,
		maxi(ammo_amount, 1),
		wdl_lifetime_ticks,
		_make_launch_velocity(yaw),
		collectable_after_bounces,
		source if source != null else self
	))
	if not configured:
		launched_wasp.queue_free()
		return null
	_spawned_wasps.append(launched_wasp)
	wasp_emitted.emit(launched_wasp)
	return launched_wasp


func _resolve_spawn_parent() -> Node:
	if not spawn_parent_path.is_empty():
		var configured_parent := get_node_or_null(spawn_parent_path)
		if configured_parent != null:
			return configured_parent
	var parent := get_parent()
	return parent if parent != null else self


func _resolve_wasp_type() -> Resource:
	if wasp_type != null:
		return wasp_type
	var type_id := wdl_wasp_type_id
	if type_id == RANDOM_WASP_TYPE_ID:
		type_id = randi_range(1, 6)
	if type_id < 1 or type_id > 7:
		return null
	return load("res://assets/wasps/type_%d.tres" % type_id) as Resource


func _player_slot_allows_auto_emit(resolved_wasp_type: Resource) -> bool:
	if resolved_wasp_type == null:
		return false
	if wdl_slot_limit <= 0:
		return true
	if wdl_wasp_type_id == RANDOM_WASP_TYPE_ID:
		return true
	var inventory := _resolve_player_wasp_inventory()
	if inventory == null:
		return true
	if not inventory.has_method("get_current_type") or not inventory.has_method("get_ammo_count"):
		return true
	var current_type: Resource = inventory.call("get_current_type")
	if current_type != resolved_wasp_type:
		return true
	return int(inventory.call("get_ammo_count")) < wdl_slot_limit


func _resolve_player_wasp_inventory() -> Node:
	if not player_slot_source_path.is_empty():
		var configured_player := get_node_or_null(player_slot_source_path)
		if configured_player != null and configured_player.has_method("get_wasp_inventory"):
			return configured_player.call("get_wasp_inventory") as Node
	for candidate in get_tree().get_nodes_in_group("player"):
		if candidate != null and candidate.has_method("get_wasp_inventory"):
			return candidate.call("get_wasp_inventory") as Node
	return null


func _make_launch_velocity(yaw: float) -> Vector3:
	var span := get_random_angle_span_degrees()
	if span > 0.0:
		yaw += deg_to_rad(randf_range(-span * 0.5, span * 0.5))
	var direction := Vector3(sin(yaw), 0.0, -cos(yaw)).normalized()
	var horizontal_units := maxf(wdl_horizontal_speed_units + randf_range(0.0, maxf(wdl_random_horizontal_bonus_units, 0.0)), 0.0)
	var vertical_units := wdl_vertical_speed_units + randf_range(0.0, maxf(wdl_random_vertical_bonus_units, 0.0))
	var horizontal_speed := maxf(horizontal_units, 0.0) * ACKNEX_TO_GODOT_SCALE * ACKNEX_TIME_UNITS_PER_SECOND
	var vertical_speed := vertical_units * ACKNEX_TO_GODOT_SCALE * ACKNEX_TIME_UNITS_PER_SECOND
	return direction * horizontal_speed + Vector3.UP * vertical_speed


func _yaw_from_impactor(impactor: Node3D) -> float:
	if impactor.has_method("get_velocity"):
		var velocity := impactor.call("get_velocity") as Vector3
		var horizontal := Vector3(velocity.x, 0.0, velocity.z)
		if horizontal.length() > 0.001:
			var direction := horizontal.normalized()
			return atan2(direction.x, -direction.z) + PI
	return impactor.global_rotation.y + PI


func _ensure_visual_root() -> void:
	_visual_root = get_node_or_null("VisualRoot") as Node3D
	if _visual_root != null:
		return
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)


func _ensure_solid_body() -> void:
	_solid_body = get_node_or_null("SolidBody") as StaticBody3D
	if _solid_body != null:
		return
	_solid_body = StaticBody3D.new()
	_solid_body.name = "SolidBody"
	_solid_body.collision_layer = 1
	_solid_body.collision_mask = 0
	add_child(_solid_body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.position = Vector3(0.0, 0.6, 0.0)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	shape.shape = sphere
	_solid_body.add_child(shape)


func _spawn_visual() -> void:
	if not show_source_visual:
		return
	_ensure_visual_root()
	if _visual_root == null:
		return
	for child in _visual_root.get_children():
		child.queue_free()
	_model_instance = null
	_visual_source_path = ""
	var source := get_effective_source_wmb_name()
	var asset_id := String(SOURCE_WMB_MODEL_ASSET_IDS.get(source, ""))
	if asset_id.is_empty():
		_spawn_fallback_visual()
		return
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		_spawn_fallback_visual()
		return
	var packed_scene := assets.load_asset(asset_id) as PackedScene
	if packed_scene == null:
		_spawn_fallback_visual()
		return
	var model := packed_scene.instantiate() as Node3D
	if model == null:
		_spawn_fallback_visual()
		return
	model.name = "WaspSpawnerSourceModel"
	_visual_root.add_child(model)
	_model_instance = model
	_visual_source_path = assets.get_asset_path(asset_id)


func _spawn_fallback_visual() -> void:
	_ensure_visual_root()
	if _visual_root == null:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "WaspSpawnerFallback"
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.4
	_visual_root.add_child(mesh_instance)
	_model_instance = mesh_instance
