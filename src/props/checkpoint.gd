extends Area3D
class_name Checkpoint

const CHECKPOINT_PARTICLES_SCRIPT := preload("res://src/effects/checkpoint_particles.gd")
const CHARACTER_LAYER := 2
const PICKUP_SENSOR_LAYER := 4
const ACKNEX_TICKS_PER_SECOND := 16.0

@export var model_asset_id: String = "model.checkpoint.restart"
@export var activation_sound_asset_id: String = "sfx.checkpoint_restart"
@export var respawn_marker_path: NodePath = ^"RespawnMarker"
@export var require_grounded: bool = true
@export var idle_particles_enabled: bool = true
@export var activation_particles_enabled: bool = true
@export var reactivation_delay_seconds: float = 4.0 / ACKNEX_TICKS_PER_SECOND

var _visual_source_path := ""
var _model_instance: Node3D = null
var _idle_particle_emitter: Node = null
var _active := true
var _reactivation_delay_remaining := 0.0

@onready var _visual_root: Node3D = $VisualRoot


func _ready() -> void:
	add_to_group("checkpoint")
	collision_layer = PICKUP_SENSOR_LAYER
	collision_mask = CHARACTER_LAYER
	body_entered.connect(_on_body_entered)
	_spawn_visual()
	_spawn_idle_particles()
	_set_active(true)


func _process(delta: float) -> void:
	if _reactivation_delay_remaining <= 0.0:
		return
	_reactivation_delay_remaining = maxf(0.0, _reactivation_delay_remaining - maxf(delta, 0.0))
	if _reactivation_delay_remaining <= 0.0:
		_set_active(true)


func try_activate_body(body: Node) -> bool:
	if not _active:
		return false
	if not _can_activate_body(body):
		return false
	if not body.has_method("set_respawn_transform"):
		return false

	var respawn_marker := _resolve_respawn_marker()
	body.call("set_respawn_transform", respawn_marker.global_transform)
	_set_active(false)
	_play_activation_sound()
	_emit_activation_particles()
	_connect_respawn_reactivation(body)
	return true


func is_active() -> bool:
	return _active


func get_visual_source_path() -> String:
	return _visual_source_path


func has_original_visual_model() -> bool:
	return not _visual_source_path.is_empty()


func get_visual_model_root() -> Node3D:
	return _visual_root


func get_idle_particle_emitter() -> Node:
	return _idle_particle_emitter


func _on_body_entered(body: Node3D) -> void:
	try_activate_body(body)


func _can_activate_body(body: Node) -> bool:
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
	return true


func _body_method_is_true(body: Node, method_name: StringName) -> bool:
	return body.has_method(method_name) and bool(body.call(method_name))


func _resolve_respawn_marker() -> Node3D:
	if not respawn_marker_path.is_empty():
		var marker := get_node_or_null(respawn_marker_path) as Node3D
		if marker != null:
			return marker
	var default_marker := get_node_or_null("RespawnMarker") as Node3D
	if default_marker != null:
		return default_marker
	return self


func _connect_respawn_reactivation(body: Node) -> void:
	if not body.has_signal("respawned"):
		return
	var callback := Callable(self, "_on_player_respawned")
	if body.is_connected("respawned", callback):
		return
	body.connect("respawned", callback, CONNECT_ONE_SHOT)


func _on_player_respawned() -> void:
	_reactivation_delay_remaining = maxf(reactivation_delay_seconds, 0.0)
	if _reactivation_delay_remaining <= 0.0:
		_set_active(true)


func _set_active(active: bool) -> void:
	_active = active
	monitoring = active
	monitorable = active
	if _visual_root != null:
		_visual_root.visible = active
	if _idle_particle_emitter != null and _idle_particle_emitter.has_method("set_idle_enabled"):
		_idle_particle_emitter.call("set_idle_enabled", active and idle_particles_enabled)


func _play_activation_sound() -> void:
	if activation_sound_asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", activation_sound_asset_id)


func _emit_activation_particles() -> void:
	if not activation_particles_enabled:
		return
	if _idle_particle_emitter == null:
		return
	if _idle_particle_emitter.has_method("emit_activation_sequence"):
		_idle_particle_emitter.call("emit_activation_sequence", Vector3.ZERO)
	elif _idle_particle_emitter.has_method("emit_burst"):
		_idle_particle_emitter.call("emit_burst", 25, Vector3.ZERO)


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
	_model_instance.name = "CheckpointModel"
	_visual_root.add_child(_model_instance)
	_visual_source_path = assets.get_asset_path(model_asset_id)


func _spawn_fallback_visual() -> void:
	if _visual_root == null:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "CheckpointFallback"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 1.2
	mesh.radial_segments = 16
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.6
	_visual_root.add_child(mesh_instance)
	_model_instance = mesh_instance
	_visual_source_path = ""


func _spawn_idle_particles() -> void:
	var emitter := CHECKPOINT_PARTICLES_SCRIPT.new()
	emitter.name = "CheckpointIdleParticles"
	emitter.set("idle_enabled", idle_particles_enabled)
	add_child(emitter)
	_idle_particle_emitter = emitter
