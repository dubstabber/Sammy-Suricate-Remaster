extends Area3D
class_name Teleporter

const TELEPORT_PARTICLES_SCRIPT := preload("res://src/effects/teleport_star_particles.gd")
const CHARACTER_LAYER := 2
const PICKUP_SENSOR_LAYER := 4
const COOLDOWN_META := &"sammy_teleport_cooldown_until_msec"

@export var destination_path: NodePath = ^"ExitMarker"
@export var model_asset_id: String = "model.teleport.pad"
@export var cooldown_seconds: float = 1.0
@export var require_grounded: bool = true
@export var idle_particles_enabled: bool = true
@export var transition_particles_enabled: bool = true
@export var visual_scale: Vector3 = Vector3(1.0, 0.5, 1.0)

var _visual_source_path := ""
var _model_instance: Node3D = null
var _idle_particle_emitter: Node = null

@onready var _visual_root: Node3D = $VisualRoot


func _ready() -> void:
	add_to_group("teleporter")
	collision_layer = PICKUP_SENSOR_LAYER
	collision_mask = CHARACTER_LAYER
	body_entered.connect(_on_body_entered)
	_spawn_visual()
	_spawn_idle_particles()


func try_teleport_body(body: Node) -> bool:
	if not _can_teleport_body(body):
		return false
	var destination := _resolve_destination()
	if destination == null:
		return false
	if not body.has_method("begin_teleport"):
		return false
	if not bool(body.call("begin_teleport", destination.global_transform, self)):
		return false
	_mark_body_cooldown(body)
	if transition_particles_enabled:
		_spawn_transition_particles(global_position, 5)
	return true


func get_visual_source_path() -> String:
	return _visual_source_path


func has_original_visual_model() -> bool:
	return not _visual_source_path.is_empty()


func get_visual_model_root() -> Node3D:
	return _visual_root


func get_idle_particle_emitter() -> Node:
	return _idle_particle_emitter


func _on_body_entered(body: Node3D) -> void:
	try_teleport_body(body)


func _can_teleport_body(body: Node) -> bool:
	if body == null or not body.is_in_group("player"):
		return false
	if _is_body_on_cooldown(body):
		return false
	if require_grounded and body is CharacterBody3D and not (body as CharacterBody3D).is_on_floor():
		return false
	return true


func _resolve_destination() -> Node3D:
	if not destination_path.is_empty():
		var destination := get_node_or_null(destination_path) as Node3D
		if destination != null:
			return destination
	return get_node_or_null("ExitMarker") as Node3D


func _mark_body_cooldown(body: Node) -> void:
	var cooldown_msec := maxi(0, int(cooldown_seconds * 1000.0))
	body.set_meta(COOLDOWN_META, Time.get_ticks_msec() + cooldown_msec)


func _is_body_on_cooldown(body: Node) -> bool:
	if not body.has_meta(COOLDOWN_META):
		return false
	var cooldown_until := int(body.get_meta(COOLDOWN_META))
	if Time.get_ticks_msec() < cooldown_until:
		return true
	body.remove_meta(COOLDOWN_META)
	return false


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
	_model_instance.name = "TeleportModel"
	_model_instance.scale = visual_scale
	_visual_root.add_child(_model_instance)
	_visual_source_path = assets.get_asset_path(model_asset_id)


func _spawn_fallback_visual() -> void:
	if _visual_root == null:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TeleportFallback"
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
	var emitter := TELEPORT_PARTICLES_SCRIPT.new()
	emitter.name = "TeleportIdleParticles"
	emitter.set("idle_enabled", true)
	add_child(emitter)
	_idle_particle_emitter = emitter


func _spawn_transition_particles(world_position: Vector3, count: int) -> void:
	var parent := get_parent()
	if parent == null:
		parent = self
	var emitter := TELEPORT_PARTICLES_SCRIPT.new()
	emitter.name = "TeleportTransitionParticles"
	emitter.set("idle_enabled", false)
	emitter.set("auto_free_when_empty", true)
	parent.add_child(emitter)
	emitter.global_position = world_position
	emitter.call("emit_burst", count)
