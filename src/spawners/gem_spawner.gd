extends Area3D
class_name GemSpawner

signal gem_emitted(gem: Node)

const KEY_RULES := preload("res://src/resources/key_diamond_rules.gd")
const LAUNCHED_KEY_GEM_SCENE := preload("res://scenes/pickups/launched_key_gem.tscn")
const ACKNEX_TIME_UNITS_PER_SECOND := 16.0
const ACKNEX_TO_GODOT_SCALE := 0.01
const DEFAULT_WDL_TEMPORARY_LIFETIME_TICKS := 60.0
const WASP_PROJECTILE_IDPLAYER := 9999

const SOURCE_WMB_MODEL_ASSET_IDS := {
	"boulder3.wmb": "model.gem_spawner.boulder3",
	"boulder4.wmb": "model.gem_spawner.boulder4",
	"boulder5.wmb": "model.gem_spawner.boulder5",
}

const ORIGINAL_PRESETS := {
	"auto_random_boulder3": {
		"source": "boulder3.wmb",
		"lifetime": 60.0,
		"vertical_speed": 20.0,
		"required_impactor": 0,
		"key_id": 999,
		"horizontal_speed": 10.0,
		"auto_interval": 48.0,
	},
	"auto_red_boulder4": {
		"source": "boulder4.wmb",
		"lifetime": 4.0,
		"vertical_speed": 30.0,
		"required_impactor": 0,
		"key_id": KEY_RULES.KEY_RED,
		"horizontal_speed": 10.0,
		"auto_interval": 64.0,
	},
	"impact_red_boulder5_short": {
		"source": "boulder5.wmb",
		"lifetime": 96.0,
		"vertical_speed": 30.0,
		"required_impactor": 9999,
		"key_id": KEY_RULES.KEY_RED,
		"horizontal_speed": 0.15,
		"auto_interval": 0.0,
	},
	"impact_red_boulder5_long": {
		"source": "boulder5.wmb",
		"lifetime": 480.0,
		"vertical_speed": 30.0,
		"required_impactor": 9999,
		"key_id": KEY_RULES.KEY_RED,
		"horizontal_speed": 0.2,
		"auto_interval": 0.0,
	},
	"auto_random_small_short": {
		"source": "small.pcx",
		"lifetime": 16.0,
		"vertical_speed": 30.0,
		"required_impactor": 0,
		"key_id": 999,
		"horizontal_speed": 20.0,
		"auto_interval": 48.0,
	},
	"auto_random_small_medium": {
		"source": "small.pcx",
		"lifetime": 64.0,
		"vertical_speed": 20.0,
		"required_impactor": 0,
		"key_id": 999,
		"horizontal_speed": 30.0,
		"auto_interval": 64.0,
	},
	"auto_random_small_long": {
		"source": "small.pcx",
		"lifetime": 80.0,
		"vertical_speed": 20.0,
		"required_impactor": 0,
		"key_id": 999,
		"horizontal_speed": 25.0,
		"auto_interval": 48.0,
	},
}

@export var wdl_lifetime_ticks: float = DEFAULT_WDL_TEMPORARY_LIFETIME_TICKS
@export var wdl_bounce_force: float = 10.0
@export var wdl_vertical_speed_units: float = 10.0
@export var wdl_required_impactor_id: int = 0
@export var wdl_key_id: int = KEY_RULES.KEY_RED
@export var wdl_horizontal_speed_units: float = 25.0
@export var wdl_auto_interval_ticks: float = 0.0
@export var wdl_flag2_disable_impact: bool = false
@export var wdl_flag3_random_20: bool = false
@export var wdl_flag4_random_45: bool = false
@export var wdl_flag5_random_90: bool = false
@export var wdl_flag6_random_180: bool = false
@export var auto_emit_on_ready: bool = false
@export var auto_initial_delay_ticks: float = 48.0
@export var max_auto_emissions: int = 0
@export var spawn_offset: Vector3 = Vector3(0.0, 1.5, 0.0)
@export var spawn_parent_path: NodePath
@export var required_impactor_group: StringName = &""
@export var default_ground_y: float = 0.0
@export var collectable_after_bounces: int = 5
@export var source_wmb_name: String = "boulder4.wmb"
@export var show_source_visual: bool = true
@export var small_visual_pixel_size: float = 0.01

var _auto_delay_remaining_ticks := 0.0
var _auto_interval_remaining_ticks := 0.0
var _auto_emission_count := 0
var _spawned_gems: Array[Node] = []
var _visual_root: Node3D = null
var _solid_body: StaticBody3D = null
var _visual_source_path := ""
var _model_instance: Node3D = null


func _ready() -> void:
	add_to_group("gem_spawner")
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
	var gem := emit_gem()
	if gem != null:
		_auto_emission_count += 1


func emit_gem() -> Node:
	return _emit_gem_at(global_position + spawn_offset, global_rotation.y)


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
		yaw = impactor_node.global_rotation.y + PI
	return _emit_gem_at(spawn_position, yaw, impactor)


func get_spawned_gems() -> Array[Node]:
	return _spawned_gems.duplicate()


func get_spawned_count() -> int:
	return _spawned_gems.size()


func get_random_angle_span_degrees() -> float:
	var span := 0.0
	if wdl_flag3_random_20:
		span += 20.0
	if wdl_flag4_random_45:
		span += 45.0
	if wdl_flag5_random_90:
		span += 90.0
	if wdl_flag6_random_180:
		span += 180.0
	return span


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
	wdl_key_id = int(preset["key_id"])
	wdl_horizontal_speed_units = float(preset["horizontal_speed"])
	wdl_auto_interval_ticks = float(preset["auto_interval"])
	auto_emit_on_ready = wdl_auto_interval_ticks > 0.0
	auto_initial_delay_ticks = 48.0 if auto_emit_on_ready else 0.0
	_auto_delay_remaining_ticks = maxf(auto_initial_delay_ticks, 0.0)
	_auto_interval_remaining_ticks = maxf(wdl_auto_interval_ticks, 0.0)
	if is_inside_tree():
		_spawn_visual()
	return true


func _on_body_entered(body: Node3D) -> void:
	emit_from_impactor(body)


func hit_by_wasp(projectile: Node) -> bool:
	return emit_from_impactor(projectile) != null


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


func _emit_gem_at(spawn_position: Vector3, yaw: float, source: Node = null) -> Node:
	var key_id := _resolve_key_id()
	if not KEY_RULES.is_valid_key_id(key_id) or key_id == KEY_RULES.KEY_ALL:
		return null
	var gem := LAUNCHED_KEY_GEM_SCENE.instantiate() as Area3D
	if gem == null:
		return null

	var parent := _resolve_spawn_parent()
	parent.add_child(gem)
	gem.global_position = spawn_position
	gem.set("ground_y", default_ground_y)
	gem.call("configure_launch", key_id, wdl_lifetime_ticks, _make_launch_velocity(yaw), collectable_after_bounces, source if source != null else self)
	_spawned_gems.append(gem)
	gem_emitted.emit(gem)
	return gem


func _resolve_spawn_parent() -> Node:
	if not spawn_parent_path.is_empty():
		var configured_parent := get_node_or_null(spawn_parent_path)
		if configured_parent != null:
			return configured_parent
	var parent := get_parent()
	return parent if parent != null else self


func _resolve_key_id() -> int:
	if wdl_key_id == 999:
		return randi_range(KEY_RULES.KEY_RED, KEY_RULES.KEY_GREEN)
	return wdl_key_id


func _make_launch_velocity(yaw: float) -> Vector3:
	var span := get_random_angle_span_degrees()
	if span > 0.0:
		yaw += deg_to_rad(randf_range(-span * 0.5, span * 0.5))
	var direction := Vector3(sin(yaw), 0.0, -cos(yaw)).normalized()
	var horizontal_speed := maxf(wdl_horizontal_speed_units, 0.0) * ACKNEX_TO_GODOT_SCALE * ACKNEX_TIME_UNITS_PER_SECOND
	var vertical_speed := wdl_vertical_speed_units * ACKNEX_TO_GODOT_SCALE * ACKNEX_TIME_UNITS_PER_SECOND
	return direction * horizontal_speed + Vector3.UP * vertical_speed


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
	shape.position = Vector3(0.0, 0.5, 0.0)
	var sphere := SphereShape3D.new()
	sphere.radius = 0.55
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
	if source == "small.pcx":
		_spawn_small_sprite_visual()
		return
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
	model.name = "GemSpawnerSourceModel"
	_visual_root.add_child(model)
	_model_instance = model
	_visual_source_path = assets.get_asset_path(asset_id)


func _spawn_small_sprite_visual() -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		_spawn_fallback_visual()
		return
	var texture := assets.load_asset("texture.gem_spawner.small") as Texture2D
	if texture == null:
		_spawn_fallback_visual()
		return
	var sprite := Sprite3D.new()
	sprite.name = "GemSpawnerSmallSprite"
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = small_visual_pixel_size
	sprite.position.y = 0.5
	_visual_root.add_child(sprite)
	_model_instance = sprite
	_visual_source_path = assets.get_asset_path("texture.gem_spawner.small")


func _spawn_fallback_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "GemSpawnerFallback"
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.3
	_visual_root.add_child(mesh_instance)
	_model_instance = mesh_instance
