extends Node3D
class_name BoostPickupEffect

const DEFAULT_TEXTURE_ASSET_ID := "texture.particle.small_star_1a"
const DEFAULT_MODEL_SCALE := Vector3.ONE * 0.01
# WDL ent_vertex uses MDL source vertices; the GLTF mesh duplicates them for UV seams.
const BOOST_WDL_VERTEX_IDS := [3, 11]
const BOOST_EXPORTED_VERTEX_INDICES := [2, 38]
const PARTICLES_PER_EMITTER := 12
const EMIT_INTERVAL_SECONDS := 0.06
const PARTICLE_LIFETIME_SECONDS := 0.75
const PARTICLE_QUAD_SIZE := Vector2(0.1, 0.1)
const PARTICLE_SCALE_START := 1.0
const PARTICLE_SCALE_MID := 0.62
const PARTICLE_SCALE_END := 0.14

class SparkleParticle:
	var node: MeshInstance3D
	var mesh: QuadMesh
	var velocity: Vector3 = Vector3.ZERO
	var age: float = 0.0
	var lifetime: float = 1.0
	var start_scale: float = 1.0
	var emitter_index: int = 0

@export var texture_asset_id: String = DEFAULT_TEXTURE_ASSET_ID

var _texture: Texture2D
var _anchors: Array[Vector3] = []
var _emitters: Array[Node3D] = []
var _emit_accumulators: Array[float] = []
var _particles: Array[SparkleParticle] = []
var _emitting := true
var _model_root: Node3D
var _mesh_instance: MeshInstance3D
var _base_vertices: PackedVector3Array
var _blend_vertices: Array[PackedVector3Array] = []
var _blend_shape_mode := Mesh.BLEND_SHAPE_MODE_NORMALIZED
var _particle_material: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0x51A7A
	if _anchors.is_empty():
		configure_model_scale(DEFAULT_MODEL_SCALE)
	if _texture == null:
		_load_texture_from_assets()
	_rebuild_emitters()


func configure(texture: Texture2D, model_scale: Vector3, model_root: Node3D = null) -> void:
	_texture = texture
	configure_model_scale(model_scale)
	if model_root != null:
		_model_root = model_root
		_load_model_vertex_tracks(model_root)
	if is_inside_tree():
		_rebuild_emitters()


func configure_model_scale(model_scale: Vector3) -> void:
	_anchors.clear()
	_anchors.append(Vector3(0.000132, 0.011253, 0.416305))
	_anchors.append(Vector3(-0.387037, 0.00476, 0.125372))
	for index in _anchors.size():
		_anchors[index] = Vector3(
				_anchors[index].x * model_scale.x / DEFAULT_MODEL_SCALE.x,
				_anchors[index].y * model_scale.y / DEFAULT_MODEL_SCALE.y,
				_anchors[index].z * model_scale.z / DEFAULT_MODEL_SCALE.z
		)


func stop_emission() -> void:
	_emitting = false


func is_emitting_effect() -> bool:
	return _emitting


func get_anchor_count() -> int:
	return _anchors.size()


func get_emitter_count() -> int:
	return _emitters.size()


func get_particle_amount_per_emitter() -> int:
	return PARTICLES_PER_EMITTER


func get_particle_quad_size() -> Vector2:
	return PARTICLE_QUAD_SIZE


func restart_emitters() -> int:
	_clear_particles()
	_prewarm_particles()
	return _emitters.size()


func follows_model_vertices() -> bool:
	return _mesh_instance != null and not _base_vertices.is_empty() and _blend_vertices.size() > 0


func get_tracked_vertex_indices() -> PackedInt32Array:
	return PackedInt32Array(BOOST_WDL_VERTEX_IDS)


func get_exported_vertex_indices() -> PackedInt32Array:
	return PackedInt32Array(BOOST_EXPORTED_VERTEX_INDICES)


func get_particle_scale_curve_samples() -> PackedFloat32Array:
	return PackedFloat32Array([PARTICLE_SCALE_START, PARTICLE_SCALE_MID, PARTICLE_SCALE_END])


func get_particle_scale_at_lifetime_ratio(lifetime_ratio: float) -> float:
	return _sample_particle_scale(clampf(lifetime_ratio, 0.0, 1.0))


func get_active_particle_count() -> int:
	return _particles.size()


func get_first_particle_visual_scale() -> float:
	if _particles.is_empty() or _particles[0].mesh == null:
		return 0.0
	return _particles[0].mesh.size.x / PARTICLE_QUAD_SIZE.x


func get_first_particle_quad_size() -> Vector2:
	if _particles.is_empty() or _particles[0].mesh == null:
		return Vector2.ZERO
	return _particles[0].mesh.size


func get_emitter_local_position(index: int) -> Vector3:
	if index < 0 or index >= _emitters.size():
		return Vector3.ZERO
	return _emitters[index].position


func _load_texture_from_assets() -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return

	_texture = assets.load_asset(texture_asset_id) as Texture2D


func _rebuild_emitters() -> void:
	_clear_particles()
	for emitter: Node3D in _emitters:
		emitter.queue_free()
	_emitters.clear()
	_emit_accumulators.clear()

	if _texture == null:
		return

	_particle_material = _create_particle_material(_texture)
	for index in _anchors.size():
		var emitter := Node3D.new()
		emitter.name = "BoostEmitter%d" % index
		emitter.position = _anchors[index]
		add_child(emitter)
		_emitters.append(emitter)
		_emit_accumulators.append(float(index) * EMIT_INTERVAL_SECONDS * 0.5)
	_update_emitter_positions()
	_prewarm_particles()


func _process(delta: float) -> void:
	_update_emitter_positions()
	_emit_particles(delta)
	_update_particles(delta)


func _load_model_vertex_tracks(model_root: Node3D) -> void:
	_mesh_instance = _find_mesh_instance(model_root)
	_base_vertices = PackedVector3Array()
	_blend_vertices.clear()
	if _mesh_instance == null or _mesh_instance.mesh == null:
		return

	var mesh := _mesh_instance.mesh
	_blend_shape_mode = mesh.blend_shape_mode
	if mesh.get_surface_count() <= 0:
		return

	var arrays := mesh.surface_get_arrays(0)
	_base_vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if not mesh.has_method("surface_get_blend_shape_arrays"):
		return

	var blend_shape_arrays: Array = mesh.call("surface_get_blend_shape_arrays", 0)
	for blend_shape_array in blend_shape_arrays:
		var shape_arrays := blend_shape_array as Array
		_blend_vertices.append(shape_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null:
		return mesh_instance

	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found
	return null


func _update_emitter_positions() -> void:
	if _emitters.is_empty():
		return

	for index in min(_emitters.size(), BOOST_EXPORTED_VERTEX_INDICES.size()):
		_emitters[index].position = _sample_vertex_position(BOOST_EXPORTED_VERTEX_INDICES[index], index)


func _sample_vertex_position(vertex_index: int, fallback_index: int) -> Vector3:
	if _mesh_instance == null or _base_vertices.is_empty() or vertex_index >= _base_vertices.size():
		return _anchors[fallback_index]

	var position := _base_vertices[vertex_index]
	if _blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED:
		var weighted_position := Vector3.ZERO
		var weight_sum := 0.0
		for index in min(_blend_vertices.size(), _mesh_instance.get_blend_shape_count()):
			var weight := _mesh_instance.get_blend_shape_value(index)
			if is_zero_approx(weight) or vertex_index >= _blend_vertices[index].size():
				continue
			weighted_position += _blend_vertices[index][vertex_index] * weight
			weight_sum += weight
		position = position * maxf(0.0, 1.0 - weight_sum) + weighted_position
	else:
		for index in min(_blend_vertices.size(), _mesh_instance.get_blend_shape_count()):
			var weight := _mesh_instance.get_blend_shape_value(index)
			if is_zero_approx(weight) or vertex_index >= _blend_vertices[index].size():
				continue
			position += _blend_vertices[index][vertex_index] * weight

	return to_local(_mesh_instance.to_global(position))


func _create_particle_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _prewarm_particles() -> void:
	for emitter_index in _emitters.size():
		for particle_index in range(PARTICLES_PER_EMITTER):
			var age_ratio := float(particle_index) / float(PARTICLES_PER_EMITTER)
			_spawn_particle(emitter_index, PARTICLE_LIFETIME_SECONDS * age_ratio)


func _emit_particles(delta: float) -> void:
	if not _emitting or _particle_material == null:
		return

	for emitter_index in _emitters.size():
		_emit_accumulators[emitter_index] += delta
		while _emit_accumulators[emitter_index] >= EMIT_INTERVAL_SECONDS:
			_emit_accumulators[emitter_index] -= EMIT_INTERVAL_SECONDS
			if _get_particle_count_for_emitter(emitter_index) < PARTICLES_PER_EMITTER:
				_spawn_particle(emitter_index)


func _spawn_particle(emitter_index: int, initial_age: float = 0.0) -> void:
	if emitter_index < 0 or emitter_index >= _emitters.size() or _particle_material == null:
		return

	var mesh := QuadMesh.new()
	mesh.material = _particle_material
	mesh.size = PARTICLE_QUAD_SIZE

	var node := MeshInstance3D.new()
	node.name = "BoostSparkle"
	node.mesh = mesh
	node.position = _emitters[emitter_index].position
	add_child(node)

	var particle := SparkleParticle.new()
	particle.node = node
	particle.mesh = mesh
	particle.velocity = _random_particle_velocity()
	particle.lifetime = PARTICLE_LIFETIME_SECONDS
	particle.start_scale = _rng.randf_range(1.0, 1.25)
	particle.emitter_index = emitter_index
	_apply_particle_visual_size(particle, 0.0)
	_particles.append(particle)
	if initial_age > 0.0:
		_advance_particle(particle, initial_age)


func _update_particles(delta: float) -> void:
	for index in range(_particles.size() - 1, -1, -1):
		var particle := _particles[index]
		if particle.node == null or not is_instance_valid(particle.node):
			_particles.remove_at(index)
			continue
		_advance_particle(particle, delta)
		if particle.age >= particle.lifetime:
			particle.node.queue_free()
			_particles.remove_at(index)


func _advance_particle(particle: SparkleParticle, delta: float) -> void:
	particle.age += delta
	var lifetime_ratio := clampf(particle.age / particle.lifetime, 0.0, 1.0)
	particle.node.position += particle.velocity * delta
	_apply_particle_visual_size(particle, lifetime_ratio)


func _apply_particle_visual_size(particle: SparkleParticle, lifetime_ratio: float) -> void:
	if particle.mesh == null:
		return
	var visual_scale := particle.start_scale * _sample_particle_scale(lifetime_ratio)
	particle.mesh.size = PARTICLE_QUAD_SIZE * visual_scale
	particle.node.scale = Vector3.ONE


func _sample_particle_scale(lifetime_ratio: float) -> float:
	if lifetime_ratio <= 0.5:
		return lerpf(PARTICLE_SCALE_START, PARTICLE_SCALE_MID, lifetime_ratio / 0.5)
	return lerpf(PARTICLE_SCALE_MID, PARTICLE_SCALE_END, (lifetime_ratio - 0.5) / 0.5)


func _random_particle_velocity() -> Vector3:
	var horizontal := Vector2(_rng.randf_range(-0.32, 0.32), _rng.randf_range(-0.32, 0.32))
	return Vector3(horizontal.x, _rng.randf_range(0.55, 1.1), horizontal.y)


func _get_particle_count_for_emitter(emitter_index: int) -> int:
	if emitter_index < 0 or emitter_index >= _emitters.size():
		return 0

	var count := 0
	for particle: SparkleParticle in _particles:
		if particle.emitter_index == emitter_index:
			count += 1
	return count


func _clear_particles() -> void:
	for particle: SparkleParticle in _particles:
		if particle.node != null and is_instance_valid(particle.node):
			particle.node.queue_free()
	_particles.clear()
