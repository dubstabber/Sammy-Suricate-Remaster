extends StaticBody3D
class_name LevelStaticProp

## Solid level object placed from an original WMB entity: an action-less brush
## WMB (barrier, border, big rock, ...) or an InitMDL model.
##
## Collision is generated from the visual when the prop enters the tree:
## brush WMBs collide with their polygons, MDL models with their bounding box
## (Acknex model collision). Shapes are built in body space so the body itself
## is never scaled, even when the entity uses non-uniform WDL scale skills.

enum CollisionMode { NONE, BOX, TRIMESH }

const GENERATED_SHAPE_PREFIX := "GeneratedCollision"

@export var collision_mode: CollisionMode = CollisionMode.TRIMESH
@export var visual_path: NodePath = ^"Visual"
## WDL `overlay` (InitMDL Flag1): black texels are transparent. Set to the
## black-keyed skin written by tools/make_overlay_skins.py.
@export var overlay_texture: Texture2D


func _ready() -> void:
	_apply_overlay_material()
	rebuild_collision()


func rebuild_collision() -> void:
	for child in get_children():
		if String(child.name).begins_with(GENERATED_SHAPE_PREFIX):
			remove_child(child)
			child.queue_free()
	if collision_mode == CollisionMode.NONE:
		return
	var visual := get_node_or_null(visual_path) as Node3D
	if visual == null:
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(visual, meshes)
	if meshes.is_empty():
		return
	if collision_mode == CollisionMode.TRIMESH:
		_build_trimesh(meshes)
	else:
		_build_box(meshes)


func get_generated_shape_count() -> int:
	var count := 0
	for child in get_children():
		if child is CollisionShape3D and String(child.name).begins_with(GENERATED_SHAPE_PREFIX):
			count += 1
	return count


func _apply_overlay_material() -> void:
	if overlay_texture == null:
		return
	var visual := get_node_or_null(visual_path) as Node3D
	if visual == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_texture = overlay_texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(visual, meshes)
	for mesh_instance in meshes:
		mesh_instance.material_override = material


func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, meshes)


func _body_from_mesh(mesh_instance: MeshInstance3D) -> Transform3D:
	return global_transform.affine_inverse() * mesh_instance.global_transform


func _build_trimesh(meshes: Array[MeshInstance3D]) -> void:
	var faces := PackedVector3Array()
	for mesh_instance in meshes:
		var body_from_mesh := _body_from_mesh(mesh_instance)
		for vertex in mesh_instance.mesh.get_faces():
			faces.append(body_from_mesh * vertex)
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	_add_shape(shape, Transform3D.IDENTITY)


func _build_box(meshes: Array[MeshInstance3D]) -> void:
	var has_bounds := false
	var bounds := AABB()
	for mesh_instance in meshes:
		var local_bounds := mesh_instance.get_aabb()
		var body_from_mesh := _body_from_mesh(mesh_instance)
		for corner_index in 8:
			var corner := body_from_mesh * local_bounds.get_endpoint(corner_index)
			if not has_bounds:
				bounds = AABB(corner, Vector3.ZERO)
				has_bounds = true
			else:
				bounds = bounds.expand(corner)
	if not has_bounds or bounds.size.is_zero_approx():
		return
	var shape := BoxShape3D.new()
	shape.size = bounds.size
	_add_shape(shape, Transform3D(Basis.IDENTITY, bounds.get_center()))


func _add_shape(shape: Shape3D, shape_transform: Transform3D) -> void:
	var collision := CollisionShape3D.new()
	collision.name = GENERATED_SHAPE_PREFIX
	collision.shape = shape
	collision.transform = shape_transform
	add_child(collision)
