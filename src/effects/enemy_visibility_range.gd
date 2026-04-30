extends Node3D
class_name EnemyVisibilityRange

const RANGE_MODEL_ASSET_ID := "model.enemy_visibility_range"
const ORIGINAL_MODEL_RADIUS := 1000.0
const ORIGINAL_ANIMATION_FPS := 10.0
const ORIGINAL_MAX_FRAME := 99
const ORIGINAL_IDLE_MIN_FRAME := 60
const ORIGINAL_CHASE_MIN_FRAME := 55
const CHASE_RANGE_EXTENSION := 1.28

const STATE_WAIT := 0
const STATE_WALK := 1
const STATE_CHASE := 2
const STATE_ROAR := 3
const STATE_ALT_STAND := 4
const STATE_DYING := 6
const STATE_DEAD := 7
const STATE_ATTACK_SWING := 10
const STATE_FLEE := 12
const STATE_RANDOM_RUN := 13

@export var enemy_path: NodePath = ^".."
@export var vertical_offset: float = 0.12

var _enemy: Node3D
var _range_model: Node3D
var _animation_player: AnimationPlayer
var _animation_name: StringName = &""
var _current_skin_number := 0
var _current_original_frame := -1
var _display_radius := 0.0


func _ready() -> void:
	_resolve_enemy()
	visible = false


func configure(enemy: Node3D) -> void:
	_enemy = enemy
	if _enemy != null:
		enemy_path = get_path_to(_enemy)


func refresh_from_enemy() -> void:
	_resolve_enemy()
	if _enemy == null:
		_set_range_visible(false)
		return
	if not _is_eye_of_truth_active() or _enemy_is_dead():
		_set_range_visible(false)
		return
	if _range_model == null:
		_spawn_range_model()
	if _range_model == null:
		_set_range_visible(false)
		return

	var base_radius := _enemy_float("react_range", 0.0)
	if base_radius <= 0.0:
		_set_range_visible(false)
		return

	var state := _enemy_state()
	var target := _enemy_target()
	var target_distance := _target_distance(target)
	var has_target_distance := target_distance >= 0.0
	var skin_number := 1
	var frame_minimum := ORIGINAL_IDLE_MIN_FRAME
	_display_radius = base_radius

	if _state_uses_chase_visual(state):
		skin_number = 2
		frame_minimum = ORIGINAL_CHASE_MIN_FRAME
		if has_target_distance:
			skin_number = 3
			if target_distance > base_radius:
				_display_radius = target_distance + CHASE_RANGE_EXTENSION
	elif has_target_distance:
		var attack_radius := _enemy_float("attack_range", 0.0)
		var alert_threshold := attack_radius + maxf(base_radius - attack_radius, 0.0) * 0.5
		if target_distance < alert_threshold:
			skin_number = 2

	var frame_distance := target_distance if has_target_distance else _display_radius
	var original_frame := _original_frame_for_distance(frame_distance, _display_radius, frame_minimum)
	_apply_visual_scale()
	_apply_skin_number(skin_number)
	_apply_original_frame(original_frame)
	_set_range_visible(true)


func is_range_visible() -> bool:
	return visible and _range_model != null and _range_model.visible


func get_display_radius() -> float:
	return _display_radius


func get_current_skin_number() -> int:
	return _current_skin_number


func get_current_original_frame() -> int:
	return _current_original_frame


func get_range_model() -> Node3D:
	return _range_model


func _resolve_enemy() -> void:
	if _enemy != null and is_instance_valid(_enemy):
		return
	if not enemy_path.is_empty():
		_enemy = get_node_or_null(enemy_path) as Node3D
	if _enemy == null:
		_enemy = get_parent() as Node3D


func _spawn_range_model() -> void:
	if _range_model != null and is_instance_valid(_range_model):
		return
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	var packed_scene: PackedScene = assets.load_asset(RANGE_MODEL_ASSET_ID)
	if packed_scene == null:
		return
	_range_model = packed_scene.instantiate() as Node3D
	if _range_model == null:
		return
	_range_model.name = "OriginalRangeCircle"
	_range_model.visible = false
	_animation_player = _find_animation_player(_range_model)
	_animation_name = _find_animation_name()
	_apply_skin_number(1)
	add_child(_range_model)


func _set_range_visible(should_show: bool) -> void:
	visible = should_show
	if _range_model != null:
		_range_model.visible = should_show


func _apply_visual_scale() -> void:
	position = Vector3(0.0, vertical_offset, 0.0)
	var scale_factor := _display_radius / ORIGINAL_MODEL_RADIUS
	_range_model.scale = Vector3.ONE * maxf(scale_factor, 0.0)


func _apply_skin_number(skin_number: int) -> void:
	var clamped_skin := clampi(skin_number, 1, 3)
	if clamped_skin == _current_skin_number:
		return
	var assets := get_node_or_null("/root/Assets")
	if assets == null or not assets.has_method("load_enemy_visibility_range_skin_texture"):
		return
	var texture := assets.call("load_enemy_visibility_range_skin_texture", clamped_skin) as Texture2D
	if texture == null:
		return
	_apply_range_texture(_range_model, texture)
	_current_skin_number = clamped_skin


func _apply_range_texture(node: Node, texture: Texture2D) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var base_material := mesh_instance.get_surface_override_material(surface_index) as StandardMaterial3D
			if base_material == null:
				base_material = mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
			var material: StandardMaterial3D = null
			if base_material != null:
				material = base_material.duplicate() as StandardMaterial3D
			else:
				material = StandardMaterial3D.new()
			material.albedo_texture = texture
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mesh_instance.set_surface_override_material(surface_index, material)

	for child in node.get_children():
		_apply_range_texture(child, texture)


func _apply_original_frame(original_frame: int) -> void:
	_current_original_frame = original_frame
	if _animation_player == null or _animation_name == &"":
		return
	if not _animation_player.has_animation(_animation_name):
		return
	var animation := _animation_player.get_animation(_animation_name)
	if animation == null:
		return
	var time := float(maxi(original_frame - 1, 0)) / ORIGINAL_ANIMATION_FPS
	time = clampf(time, 0.0, animation.length)
	if _animation_player.current_animation != _animation_name:
		_animation_player.play(_animation_name)
	_animation_player.seek(time, true)
	_animation_player.pause()


func _find_animation_player(node: Node) -> AnimationPlayer:
	var player := node as AnimationPlayer
	if player != null:
		return player
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


func _find_animation_name() -> StringName:
	if _animation_player == null:
		return &""
	for candidate in _animation_player.get_animation_list():
		var candidate_name := String(candidate)
		if candidate_name.contains("circl100") or candidate_name.contains("vertex_frames"):
			return candidate
	for candidate in _animation_player.get_animation_list():
		if String(candidate) != "RESET":
			return candidate
	return &""


func _original_frame_for_distance(distance: float, radius: float, minimum_frame: int) -> int:
	var safe_radius := maxf(radius, 0.001)
	var raw_frame := int(roundf(minf(100.0 * maxf(distance, 1.0) / safe_radius, float(ORIGINAL_MAX_FRAME))))
	return clampi(raw_frame, minimum_frame, ORIGINAL_MAX_FRAME)


func _is_eye_of_truth_active() -> bool:
	var game := get_node_or_null("/root/Game")
	return game != null and game.has_method("is_eye_of_truth_active") and bool(game.call("is_eye_of_truth_active"))


func _enemy_is_dead() -> bool:
	if _enemy == null:
		return true
	if _enemy.has_method("is_dead") and bool(_enemy.call("is_dead")):
		return true
	return _enemy_state() == STATE_DYING or _enemy_state() == STATE_DEAD


func _enemy_state() -> int:
	if _enemy != null and _enemy.has_method("get_state"):
		return int(_enemy.call("get_state"))
	return STATE_WAIT


func _enemy_target() -> Node3D:
	if _enemy != null and _enemy.has_method("get_target"):
		return _enemy.call("get_target") as Node3D
	return null


func _target_distance(target: Node3D) -> float:
	if target == null or _enemy == null or not is_instance_valid(target):
		return -1.0
	var offset := target.global_position - _enemy.global_position
	offset.y = 0.0
	return offset.length()


func _enemy_float(property_name: StringName, fallback: float) -> float:
	if _enemy == null:
		return fallback
	var value = _enemy.get(property_name)
	if value == null:
		return fallback
	return float(value)


func _state_uses_chase_visual(state: int) -> bool:
	return (
			state == STATE_CHASE
			or state == STATE_ROAR
			or state == STATE_ATTACK_SWING
			or state == STATE_FLEE
			or state == STATE_RANDOM_RUN
	)
