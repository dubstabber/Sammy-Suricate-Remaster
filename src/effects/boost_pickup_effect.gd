extends Node3D
class_name BoostPickupEffect

const DEFAULT_TEXTURE_ASSET_ID := "texture.particle.small_star_1a"
const DEFAULT_MODEL_SCALE := Vector3.ONE * 0.01
# WDL ent_vertex uses MDL source vertices; the GLTF mesh duplicates them for UV seams.
const BOOST_WDL_VERTEX_IDS := [3, 11]
const BOOST_EXPORTED_VERTEX_INDICES := [2, 38]
const PARTICLES_PER_EMITTER := 12
const PARTICLE_LIFETIME_SECONDS := 0.75
const PARTICLE_QUAD_SIZE := Vector2(0.1, 0.1)
const PARTICLE_SCALE_START := 1.0
const PARTICLE_SCALE_MID := 0.62
const PARTICLE_SCALE_END := 0.14
const PARTICLE_INITIAL_VELOCITY_MIN := 0.55
const PARTICLE_INITIAL_VELOCITY_MAX := 1.1
const PARTICLE_SPREAD_DEGREES := 32.0

@export var texture_asset_id: String = DEFAULT_TEXTURE_ASSET_ID

var _texture: Texture2D
var _anchors: Array[Vector3] = []
var _emitters: Array[GPUParticles3D] = []
var _emitting := true
var _model_root: Node3D
var _mesh_instance: MeshInstance3D
var _base_vertices: PackedVector3Array
var _blend_vertices: Array[PackedVector3Array] = []
var _blend_shape_mode := Mesh.BLEND_SHAPE_MODE_NORMALIZED
var _particle_material: StandardMaterial3D
var _particle_mesh: QuadMesh
var _particle_process_material: ParticleProcessMaterial


func _ready() -> void:
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
	for emitter: GPUParticles3D in _emitters:
		emitter.emitting = false


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
	for emitter: GPUParticles3D in _emitters:
		emitter.emitting = _emitting
		emitter.restart(true)
		if _emitting:
			emitter.request_particles_process(PARTICLE_LIFETIME_SECONDS)
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


func get_particle_capacity() -> int:
	return _emitters.size() * PARTICLES_PER_EMITTER


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
	_clear_emitters()

	if _texture == null:
		return

	_particle_material = _create_particle_material(_texture)
	_particle_mesh = _create_particle_mesh(_particle_material)
	_particle_process_material = _create_particle_process_material()
	for index in _anchors.size():
		var emitter := _create_gpu_emitter(index)
		add_child(emitter)
		_emitters.append(emitter)
	_update_emitter_positions()
	restart_emitters()


func _process(_delta: float) -> void:
	_update_emitter_positions()


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

	var vertex_position := _base_vertices[vertex_index]
	if _blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED:
		var weighted_position := Vector3.ZERO
		var weight_sum := 0.0
		for index in min(_blend_vertices.size(), _mesh_instance.get_blend_shape_count()):
			var weight := _mesh_instance.get_blend_shape_value(index)
			if is_zero_approx(weight) or vertex_index >= _blend_vertices[index].size():
				continue
			weighted_position += _blend_vertices[index][vertex_index] * weight
			weight_sum += weight
		vertex_position = vertex_position * maxf(0.0, 1.0 - weight_sum) + weighted_position
	else:
		for index in min(_blend_vertices.size(), _mesh_instance.get_blend_shape_count()):
			var weight := _mesh_instance.get_blend_shape_value(index)
			if is_zero_approx(weight) or vertex_index >= _blend_vertices[index].size():
				continue
			vertex_position += _blend_vertices[index][vertex_index] * weight

	return to_local(_mesh_instance.to_global(vertex_position))


func _create_particle_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	# particle_Boost1 is My_Flare: alpha-blended at vertex alpha 250, not additive.
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.albedo_color = Color(1.0, 1.0, 1.0, 250.0 / 255.0)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _create_particle_mesh(material: StandardMaterial3D) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.material = material
	mesh.size = PARTICLE_QUAD_SIZE
	return mesh


func _create_particle_process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	material.direction = Vector3.UP
	material.spread = PARTICLE_SPREAD_DEGREES
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = PARTICLE_INITIAL_VELOCITY_MIN
	material.initial_velocity_max = PARTICLE_INITIAL_VELOCITY_MAX
	material.scale_min = 1.0
	material.scale_max = 1.25
	material.scale_curve = _create_particle_scale_curve_texture()
	return material


func _create_particle_scale_curve_texture() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, PARTICLE_SCALE_START), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	curve.add_point(Vector2(0.5, PARTICLE_SCALE_MID), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	curve.add_point(Vector2(1.0, PARTICLE_SCALE_END), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)

	var texture := CurveTexture.new()
	texture.width = 64
	texture.curve = curve
	return texture


func _create_gpu_emitter(index: int) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.name = "BoostEmitter%d" % index
	emitter.position = _anchors[index]
	emitter.amount = PARTICLES_PER_EMITTER
	emitter.lifetime = PARTICLE_LIFETIME_SECONDS
	emitter.preprocess = PARTICLE_LIFETIME_SECONDS
	emitter.explosiveness = 0.0
	emitter.randomness = 1.0
	emitter.local_coords = false
	emitter.use_fixed_seed = true
	emitter.seed = 0x51A7A + index
	emitter.draw_order = GPUParticles3D.DRAW_ORDER_LIFETIME
	emitter.draw_passes = 1
	emitter.process_material = _particle_process_material
	emitter.set_draw_pass_mesh(0, _particle_mesh)
	emitter.visibility_aabb = AABB(Vector3(-0.75, -0.25, -0.75), Vector3(1.5, 2.0, 1.5))
	emitter.emitting = _emitting
	return emitter


func _sample_particle_scale(lifetime_ratio: float) -> float:
	if lifetime_ratio <= 0.5:
		return lerpf(PARTICLE_SCALE_START, PARTICLE_SCALE_MID, lifetime_ratio / 0.5)
	return lerpf(PARTICLE_SCALE_MID, PARTICLE_SCALE_END, (lifetime_ratio - 0.5) / 0.5)


func _clear_emitters() -> void:
	for emitter: GPUParticles3D in _emitters:
		if emitter != null and is_instance_valid(emitter):
			emitter.queue_free()
	_emitters.clear()
