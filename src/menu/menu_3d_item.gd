extends Area3D

signal selected(item: Area3D, action_id: int, action_key: StringName)

@export var action_id: int = 0
@export var action_key: StringName = &""
@export var original_source_name: String = ""
@export var source_position := Vector3.ZERO
@export var model_scene: PackedScene
@export var model_root_path: NodePath = ^"Model"
@export var hover_light_path: NodePath = ^"HoverLight"
@export var hover_lift: float = 0.0
@export var hover_scale: float = 1.0
@export var hover_sound_asset_id: String = "sfx.menu_hover"
@export var click_sound_asset_id: String = "sfx.menu_select"
@export var animated: bool = false
@export var source_skill2: float = 0.0
@export var source_skill3: float = 0.0
@export var source_skill4: float = 0.0
@export var source_skill7: float = 0.0
@export var animation_phase_offset: float = 0.0
@export var animation_rotation_scale: float = 18.0
@export var disabled: bool = false

var _model_root: Node3D
var _hover_light: Light3D
var _base_position := Vector3.ZERO
var _base_rotation_degrees := Vector3.ZERO
var _base_scale := Vector3.ONE
var _hovered := false
var _animation_time := 0.0


func _ready() -> void:
	input_ray_pickable = not disabled
	_ensure_model_instance()
	_model_root = get_node_or_null(model_root_path) as Node3D
	_hover_light = get_node_or_null(hover_light_path) as Light3D
	_base_position = position
	_base_rotation_degrees = rotation_degrees
	_base_scale = scale
	if _hover_light != null:
		_hover_light.visible = false
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	_apply_visual_motion()


func _process(delta: float) -> void:
	if not animated:
		return
	_animation_time += delta
	_apply_visual_motion()


func is_hovered() -> bool:
	return _hovered


func get_original_source_name() -> String:
	return original_source_name


func get_source_position() -> Vector3:
	return source_position


func is_animation_enabled() -> bool:
	return animated


func set_disabled(value: bool) -> void:
	disabled = value
	input_ray_pickable = not disabled
	if disabled:
		_set_hovered(false)


func select() -> void:
	if disabled:
		return
	_play_click_sound()
	selected.emit(self, action_id, action_key)


func _on_mouse_entered() -> void:
	if disabled:
		return
	_set_hovered(true)


func _on_mouse_exited() -> void:
	_set_hovered(false)


func _on_input_event(
		_camera: Node,
		event: InputEvent,
		_event_position: Vector3,
		_normal: Vector3,
		_shape_idx: int
) -> void:
	if disabled:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			select()


func _set_hovered(enabled: bool) -> void:
	if _hovered == enabled:
		return
	_hovered = enabled
	_apply_visual_motion()
	if _hover_light != null:
		_hover_light.visible = _hovered
	if _hovered:
		_play_hover_sound()


func _apply_visual_motion() -> void:
	var bob_offset := Vector3.ZERO
	var rotation_offset := Vector3.ZERO
	if animated:
		var bob_height := floorf(source_skill7) * 0.01
		if bob_height > 0.0:
			var bob_speed := maxf(0.35, 0.35 + fmod(source_skill7, 1.0) * 18.0)
			bob_offset.y = sin((_animation_time + animation_phase_offset) * TAU * bob_speed) * bob_height
		var rotation_time := _animation_time + animation_phase_offset
		rotation_offset = _source_rotation_offset(rotation_time)
	position = _base_position + bob_offset
	rotation_degrees = _base_rotation_degrees + rotation_offset
	scale = _base_scale


func _source_rotation_offset(rotation_time: float) -> Vector3:
	var degrees_per_source_unit := animation_rotation_scale * rotation_time
	# WMB vertices are converted as (x, y, z) -> (x, z, -y). Acknex Pan/Tilt/Roll
	# therefore map to Godot Y/-Z/X; the central Play roll piece depends on this.
	return Vector3(
			source_skill4 * degrees_per_source_unit,
			source_skill2 * degrees_per_source_unit,
			-source_skill3 * degrees_per_source_unit
	)


func _ensure_model_instance() -> void:
	if model_scene == null or get_node_or_null(model_root_path) != null:
		return
	var instance := model_scene.instantiate() as Node3D
	if instance == null:
		return
	instance.name = model_root_path.get_name(0) if model_root_path.get_name_count() > 0 else "Model"
	add_child(instance)


func _play_hover_sound() -> void:
	_play_sound(hover_sound_asset_id)


func _play_click_sound() -> void:
	_play_sound(click_sound_asset_id)


func _play_sound(asset_id: String) -> void:
	if asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", asset_id)
