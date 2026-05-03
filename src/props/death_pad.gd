extends Area3D
class_name DeathPad

const TILE_DEATH_PARTICLES_SCRIPT := preload("res://src/effects/tile_death_particles.gd")
const WORLD_LAYER := 1
const CHARACTER_LAYER := 2
const PICKUP_SENSOR_LAYER := 4

@export var model_asset_id: String = "model.death_pad.tile"
@export var require_grounded: bool = true
@export var require_top_contact: bool = true
@export var solid_top_height: float = 0.32
@export var top_contact_y_tolerance: float = 0.12
@export var top_trigger_radius: float = 0.72
@export var idle_particles_enabled: bool = true

var _visual_source_path := ""
var _model_instance: Node3D = null
var _idle_particle_emitter: Node = null

@onready var _visual_root: Node3D = $VisualRoot


func _ready() -> void:
	add_to_group("death_pad")
	collision_layer = PICKUP_SENSOR_LAYER
	collision_mask = CHARACTER_LAYER
	body_entered.connect(_on_body_entered)
	_configure_solid_body()
	_spawn_visual()
	_spawn_idle_particles()


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if try_trigger_body(body):
			return


func try_trigger_body(body: Node) -> bool:
	if not _can_trigger_body(body):
		return false
	if not body.has_method("begin_death_pad_respawn"):
		return false
	return bool(body.call("begin_death_pad_respawn", self))


func get_visual_source_path() -> String:
	return _visual_source_path


func has_original_visual_model() -> bool:
	return not _visual_source_path.is_empty()


func get_visual_model_root() -> Node3D:
	return _visual_root


func get_idle_particle_emitter() -> Node:
	return _idle_particle_emitter


func get_solid_top_height() -> float:
	return solid_top_height


func get_top_trigger_radius() -> float:
	return top_trigger_radius


func _on_body_entered(body: Node3D) -> void:
	try_trigger_body(body)


func _can_trigger_body(body: Node) -> bool:
	if body == null or not body.is_in_group("player"):
		return false
	if require_grounded and body is CharacterBody3D and not (body as CharacterBody3D).is_on_floor():
		return false
	if require_top_contact and not _is_body_on_trigger_top(body):
		return false
	if _body_method_is_true(body, &"is_dead"):
		return false
	if _body_method_is_true(body, &"is_game_over"):
		return false
	if _body_method_is_true(body, &"is_teleporting"):
		return false
	if _body_method_is_true(body, &"is_death_pad_respawning"):
		return false
	if _body_method_is_true(body, &"is_exit_pad_victory_active"):
		return false
	return true


func _is_body_on_trigger_top(body: Node) -> bool:
	var body_3d := body as Node3D
	if body_3d == null:
		return false
	var local_position := global_transform.affine_inverse() * body_3d.global_position
	var top_y := maxf(solid_top_height, 0.0)
	if local_position.y < top_y - top_contact_y_tolerance:
		return false
	if local_position.y > top_y + top_contact_y_tolerance:
		return false
	return Vector2(local_position.x, local_position.z).length() <= top_trigger_radius


func _body_method_is_true(body: Node, method_name: StringName) -> bool:
	return body.has_method(method_name) and bool(body.call(method_name))


func _configure_solid_body() -> void:
	var solid_body := get_node_or_null("SolidBody") as StaticBody3D
	if solid_body == null:
		return
	solid_body.collision_layer = WORLD_LAYER
	solid_body.collision_mask = CHARACTER_LAYER


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
	_model_instance.name = "DeathPadModel"
	_visual_root.add_child(_model_instance)
	_visual_source_path = assets.get_asset_path(model_asset_id)


func _spawn_fallback_visual() -> void:
	if _visual_root == null:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DeathPadFallback"
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


func _spawn_idle_particles() -> void:
	if not idle_particles_enabled:
		return
	var emitter := TILE_DEATH_PARTICLES_SCRIPT.new()
	emitter.name = "TileDeathIdleParticles"
	emitter.set("idle_enabled", true)
	add_child(emitter)
	_idle_particle_emitter = emitter
