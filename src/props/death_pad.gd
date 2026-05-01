extends Area3D
class_name DeathPad

const TILE_DEATH_PARTICLES_SCRIPT := preload("res://src/effects/tile_death_particles.gd")
const CHARACTER_LAYER := 2
const PICKUP_SENSOR_LAYER := 4

@export var model_asset_id: String = "model.death_pad.tile"
@export var require_grounded: bool = true
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
	_spawn_visual()
	_spawn_idle_particles()


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


func _on_body_entered(body: Node3D) -> void:
	try_trigger_body(body)


func _can_trigger_body(body: Node) -> bool:
	if body == null or not body.is_in_group("player"):
		return false
	if require_grounded and body is CharacterBody3D and not (body as CharacterBody3D).is_on_floor():
		return false
	return true


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
