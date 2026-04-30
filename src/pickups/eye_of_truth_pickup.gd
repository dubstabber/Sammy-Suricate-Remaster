extends Area3D
class_name EyeOfTruthPickup

const DEFAULT_EFFECT_SECONDS := 256.0 / 16.0
const ACKNEX_TO_GODOT_SCALE := 0.01
const PANEL_TEXTURE_ASSET_ID := "texture.eye_truth.panel"
# Paneye.gltf is a flat billboard panel with Y height 19.125 and Z width 56.4505.
const EYE_VISUAL_SIZE := Vector2(56.450504 * ACKNEX_TO_GODOT_SCALE, 19.125001 * ACKNEX_TO_GODOT_SCALE)
const ORIGINAL_SUSTENTATION_REACHED_DISTANCE := 8.0 * ACKNEX_TO_GODOT_SCALE

@export var effect_duration_seconds: float = DEFAULT_EFFECT_SECONDS
@export var model_asset_id: String = "model.eye_of_truth"
@export var collect_sound_asset_id: String = "sfx.eye_truth"
@export var visual_scale_multiplier: float = 1.0
@export var visual_ground_clearance: float = 0.05
@export var original_sustentation_active: bool = true
@export var original_sustentation_height: float = 24.0 * ACKNEX_TO_GODOT_SCALE
@export var original_sustentation_lerp_per_second: float = 1.6
@export var original_rotation_active: bool = false
@export var original_pan_degrees_per_second: float = 0.0
@export var original_tilt_degrees_per_second: float = 0.0
@export var original_roll_degrees_per_second: float = 0.0
@export var original_rotation_accel_per_second: float = 1.6

var _collected := false
var _model_instance: Node3D = null
var _base_visual_y := 0.0
var _sustentation_direction := 1.0
var _rotation_acceleration := 0.0


func _ready() -> void:
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)
	_spawn_model()


func _process(delta: float) -> void:
	if _collected or _model_instance == null:
		return
	_update_original_idle_motion(delta)


func collect(player: Node) -> bool:
	return _collect_from(player)


func was_collected() -> bool:
	return _collected


func get_effect_duration_seconds() -> float:
	return effect_duration_seconds


func get_visual_model() -> Node3D:
	return _model_instance


func _on_body_entered(body: Node3D) -> void:
	_collect_from(body)


func _collect_from(player: Node) -> bool:
	if _collected or player == null:
		return false
	var game := get_node_or_null("/root/Game")
	if game == null or not game.has_method("activate_eye_of_truth"):
		return false

	game.call("activate_eye_of_truth", effect_duration_seconds)
	_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	visible = false
	_play_collect_sound()
	return true


func _spawn_model() -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return

	var texture := assets.load_asset(PANEL_TEXTURE_ASSET_ID) as Texture2D
	if texture == null:
		return

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "EyeOfTruthVisual"
	var quad := QuadMesh.new()
	quad.size = EYE_VISUAL_SIZE * visual_scale_multiplier
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	quad.material = material
	mesh_instance.mesh = quad
	mesh_instance.material_override = material
	_model_instance = mesh_instance
	add_child(_model_instance)
	_lift_model_above_ground(assets)
	_base_visual_y = _model_instance.position.y


func _lift_model_above_ground(assets: Node) -> void:
	if _model_instance == null:
		return
	var bounds: AABB = assets.get_model_global_bounds(_model_instance)
	if bounds.size == Vector3.ZERO:
		return
	var target_bottom_y := global_position.y + visual_ground_clearance
	var lift := target_bottom_y - bounds.position.y
	if lift > 0.0:
		_model_instance.global_position.y += lift


func _update_original_idle_motion(delta: float) -> void:
	if original_sustentation_active:
		var target_y := _base_visual_y + original_sustentation_height * _sustentation_direction
		var weight := clampf(maxf(original_sustentation_lerp_per_second, 0.0) * maxf(delta, 0.0), 0.0, 1.0)
		_model_instance.position.y = lerpf(_model_instance.position.y, target_y, weight)
		if absf(_model_instance.position.y - target_y) <= ORIGINAL_SUSTENTATION_REACHED_DISTANCE:
			_sustentation_direction *= -1.0

	if not original_rotation_active:
		return
	var rotation_weight := clampf(maxf(original_rotation_accel_per_second, 0.0) * maxf(delta, 0.0), 0.0, 1.0)
	_rotation_acceleration = lerpf(_rotation_acceleration, 1.0, rotation_weight)
	_model_instance.rotation_degrees.x += original_tilt_degrees_per_second * _rotation_acceleration * delta
	_model_instance.rotation_degrees.y += original_pan_degrees_per_second * _rotation_acceleration * delta
	_model_instance.rotation_degrees.z += original_roll_degrees_per_second * _rotation_acceleration * delta


func _play_collect_sound() -> void:
	if collect_sound_asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", collect_sound_asset_id)
