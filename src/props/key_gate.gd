extends StaticBody3D
class_name KeyGate

const KEY_RULES := preload("res://src/resources/key_diamond_rules.gd")
const GATE_KEY_FLIGHT_EFFECT_SCRIPT := preload("res://src/effects/gate_key_flight_effect.gd")
const WORLD_LAYER := 1

const MATCH_USE_STRICT_PROPERTY := 0
const MATCH_COMPONENT_OR_EXACT := 1
const MATCH_EXACT_ONLY := 2
const MATCH_UNLOCKED := 3
const MATCH_NEVER := 4
const MATCH_ANY_KEY := 5

const CLOSE_STAY_OPEN := 0
const CLOSE_AUTO := 1
const CLOSE_PERMANENT_CONSUME := 2

const STATE_CLOSED := 0
const STATE_OPENING := 1
const STATE_OPEN := 2
const STATE_CLOSING := 3
const STATE_LOCKED_OPEN := 4

const DOOR_PATTERN_KEYED := 0
const DOOR_PATTERN_MIXED := 1
const DOOR_PATTERN_EXIT := 2
const DOOR_PATTERN_DARK := 3
const DOOR_PATTERN_WEAK := 4
const DOOR_PATTERN_ALL := 5
const DOOR_MODEL_ROOT_NAME := "DoorModelRoot"
const ORIGINAL_GATE_MODEL_ROOT := "res://assets/models/gates"
const PERMANENT_LOCKED_OPEN_WMB_NAME := "doordark.wmb"
const SOURCE_MODEL_AUTO_CLOSE_DELAY_SECONDS := 1.0
const SOURCE_MODEL_CLOSE_SPEED := 80.0

# InitLvl.wdl sets SpeedGemKey = 12. Converted to Godot meters/sec
# through the existing 0.01 Acknex-to-Godot scale and 16 ticks/sec.
const DEFAULT_KEY_FLIGHT_SPEED := 12.0 * 0.01 * 16.0
const WASP_PROJECTILE_IDPLAYER := 9999
const ACKNEX_TO_GODOT_SCALE := 0.01
const DOOR_SOUND_WDL_RANGE_UNITS := 1000.0
const WEAK_DEBRIS_LIFETIME_SECONDS := 1.0
const WEAK_DEBRIS_LAUNCH_SECONDS := 0.55
const WEAK_DEBRIS_MODEL_ASSET_IDS := [
	"model.weak_gate.plank1",
	"model.weak_gate.plank2",
	"model.weak_gate.plank3",
	"model.weak_gate.plank1",
	"model.weak_gate.plank2",
	"model.weak_gate.plank3"
]
const WEAK_DEBRIS_OFFSETS := [
	Vector3(-0.42, 0.15, -0.08),
	Vector3(0.18, 0.4, 0.1),
	Vector3(0.38, 0.72, -0.12),
	Vector3(-0.15, 0.95, 0.14),
	Vector3(0.44, 1.18, 0.0),
	Vector3(-0.36, 1.45, 0.12)
]
const WEAK_DEBRIS_LAUNCHES := [
	Vector3(-0.65, 0.85, -0.18),
	Vector3(0.2, 1.05, 0.28),
	Vector3(0.72, 1.2, -0.24),
	Vector3(-0.3, 1.1, 0.18),
	Vector3(0.58, 0.95, 0.1),
	Vector3(-0.55, 1.25, 0.24)
]
const WEAK_DEBRIS_ROTATIONS := [
	Vector3(72.0, 30.0, -42.0),
	Vector3(-50.0, 115.0, 38.0),
	Vector3(66.0, -76.0, 55.0),
	Vector3(-82.0, 44.0, -20.0),
	Vector3(45.0, -130.0, 72.0),
	Vector3(-35.0, 90.0, -65.0)
]

@export var required_key_id: int = 3
@export var strict_match: bool = true
@export_enum("Use strict_match property", "Component or Exact", "Exact Only", "Unlocked", "Never", "Any Key") var match_mode: int = MATCH_USE_STRICT_PROPERTY
@export_enum("Stay Open", "Auto Close", "Permanent Consume") var close_mode: int = CLOSE_STAY_OPEN
@export var use_wdl_door_fields: bool = false
@export var use_source_wmb_behavior: bool = false
@export var wdl_skill6_required_key: int = KEY_RULES.KEY_NONE
@export var wdl_skill5_close_speed: float = 0.0
@export var wdl_skill8_hold_units: float = 4.0
@export var wdl_flag5_permanent: bool = false
@export var wdl_flag6_unlocked: bool = false
@export var wdl_flag7_exact_match: bool = false
@export var open_sound_asset_id: String = "sfx.door_open"
@export var close_sound_asset_id: String = "sfx.door_close"
@export var open_height: float = 2.2
@export var open_speed: float = 5.0
@export var close_speed: float = 8.0
@export var auto_close_delay_seconds: float = 1.0
@export var key_flight_speed: float = DEFAULT_KEY_FLIGHT_SPEED
@export var key_flight_height_offset: float = 0.55
# Empty means infer the original door WMB from required_key_id. Set this when a
# level uses a special source model such as doorexit.wmb, doordark.wmb, or doorwk4.wmb.
@export var source_wmb_name: String = ""
@export var destructible_by_wasps: bool = false
@export_range(0, 16, 1) var weak_door_resistance: int = 0
@export var weak_hit_sound_asset_id: String = "sfx.plank1"
@export var spawn_weak_debris: bool = true

var _open := false
var _state := STATE_CLOSED
var _open_hold_remaining := 0.0
var _permanent_key_flight_active := false
var _consumed_key_id := KEY_RULES.KEY_NONE
var _closed_collision_layer := WORLD_LAYER
var _closed_collision_mask := 0
var _closed_visual_position := Vector3.ZERO
var _visual_signature := ""
var _visual_source_path := ""
var _weak_door_strength := 0
var _destroyed := false
var _weak_debris_spawned_count := 0

@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _visual: MeshInstance3D = $GateVisual
@onready var _trigger: Area3D = $OpenTrigger
@onready var _trigger_shape: CollisionShape3D = $OpenTrigger/CollisionShape3D


func _ready() -> void:
	add_to_group("key_gate")
	_closed_collision_layer = collision_layer
	_closed_collision_mask = collision_mask
	_closed_visual_position = _visual.position if _visual != null else Vector3.ZERO
	if _trigger != null:
		_trigger.body_entered.connect(_on_trigger_body_entered)
	_initialize_weak_door_state()
	_apply_key_color()
	_rebuild_door_visual_model()


func _process(delta: float) -> void:
	if _destroyed:
		return
	var safe_delta := maxf(delta, 0.0)
	_update_open_hold(safe_delta)
	if _visual == null:
		return
	var target := _target_visual_position()
	var speed := _effective_close_speed() if _state == STATE_CLOSING else open_speed
	_visual.position = _visual.position.move_toward(target, maxf(speed, 0.0) * safe_delta)
	if _visual.position.is_equal_approx(target):
		_on_visual_reached_target()


func try_open(player: Node) -> bool:
	if _destroyed:
		return true
	if _state == STATE_LOCKED_OPEN:
		return true
	if _open:
		if _effective_close_mode() == CLOSE_AUTO:
			_state = STATE_OPEN
			_open_hold_remaining = _effective_auto_close_delay_seconds()
		return true
	if not can_player_open(player):
		return false

	var consumed_key_id := KEY_RULES.KEY_NONE
	if _effective_close_mode() == CLOSE_PERMANENT_CONSUME and _effective_match_mode() != MATCH_UNLOCKED:
		consumed_key_id = _consume_player_key(player)
		if consumed_key_id == KEY_RULES.KEY_NONE:
			return false
		_consumed_key_id = consumed_key_id

	_begin_open()
	_play_sfx(open_sound_asset_id)
	if _effective_close_mode() == CLOSE_PERMANENT_CONSUME and consumed_key_id != KEY_RULES.KEY_NONE:
		_spawn_key_flight(player as Node3D, consumed_key_id)
	return true


func can_player_open(player: Node) -> bool:
	if _destroyed:
		return true
	if player == null:
		return false
	if player.has_method("get_current_key_id"):
		return _can_key_open(int(player.call("get_current_key_id")))
	if player.has_method("can_open_key_gate"):
		if _effective_match_mode() == MATCH_NEVER:
			return false
		if _effective_match_mode() == MATCH_UNLOCKED:
			return true
		if _effective_match_mode() == MATCH_ANY_KEY:
			return false
		return bool(player.call("can_open_key_gate", _effective_required_key_id(), _effective_strict_match()))
	return false


func is_open() -> bool:
	return _open


func get_required_key_id() -> int:
	return _effective_required_key_id()


func is_strict_match() -> bool:
	return _effective_strict_match()


func get_match_mode() -> int:
	return match_mode


func get_effective_match_mode() -> int:
	return _effective_match_mode()


func get_close_mode() -> int:
	return _effective_close_mode()


func is_permanently_open() -> bool:
	return _state == STATE_LOCKED_OPEN


func is_destroyed() -> bool:
	return _destroyed


func is_destructible_by_wasps() -> bool:
	return _is_wasp_destructible()


func get_weak_door_strength() -> int:
	return _weak_door_strength


func get_weak_debris_spawned_count() -> int:
	return _weak_debris_spawned_count


func is_permanent_key_flight_active() -> bool:
	return _permanent_key_flight_active


func get_consumed_key_id() -> int:
	return _consumed_key_id


func get_source_wmb_name() -> String:
	return source_wmb_name


func get_effective_source_wmb_name() -> String:
	return _normalized_source_wmb_name()


func get_visual_signature() -> String:
	return _visual_signature


func get_visual_source_path() -> String:
	return _visual_source_path


func has_original_visual_model() -> bool:
	return not _visual_source_path.is_empty()


func get_visual_part_count() -> int:
	var root := get_visual_model_root()
	return _count_mesh_instances(root) if root != null else 0


func get_visual_model_bounds_size() -> Vector3:
	var root := get_visual_model_root()
	if root == null:
		return Vector3.ZERO
	var bounds_state: Array = [false, AABB()]
	_accumulate_mesh_bounds(root, root, bounds_state)
	if not bool(bounds_state[0]):
		return Vector3.ZERO
	var bounds: AABB = bounds_state[1]
	return bounds.size


func get_visual_model_root() -> Node3D:
	if _visual == null:
		return null
	return _visual.get_node_or_null(DOOR_MODEL_ROOT_NAME) as Node3D


func hit_by_wasp(projectile: Node) -> bool:
	if _destroyed or not _is_wasp_destructible():
		return false
	if not _is_original_wasp_projectile(projectile):
		return false

	var damage := _get_wasp_damage(projectile)
	if damage <= 0:
		return false
	if _weak_door_strength <= 0:
		_weak_door_strength = maxi(_initial_weak_door_strength(), 1)
	_weak_door_strength = maxi(_weak_door_strength - damage, 0)
	_play_sfx(weak_hit_sound_asset_id)

	if _weak_door_strength <= 0:
		_destroy_weak_door(projectile)
	else:
		source_wmb_name = _source_wmb_name_for_weak_strength(_weak_door_strength)
		_rebuild_door_visual_model()
	return true


func is_close_blocked() -> bool:
	if _trigger_shape != null and _trigger_shape.shape != null and is_inside_tree():
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = _trigger_shape.shape
		query.transform = _trigger_shape.global_transform
		query.collision_mask = _trigger.collision_mask if _trigger != null else 0xFFFFFFFF
		query.exclude = [get_rid()]
		for result in get_world_3d().direct_space_state.intersect_shape(query, 16):
			var collider = result.get("collider")
			if collider != null and collider != self:
				return true
	if _trigger == null:
		return false
	for body in _trigger.get_overlapping_bodies():
		if body != null and body != self:
			return true
	return false


func _on_trigger_body_entered(body: Node3D) -> void:
	try_open(body)


func _apply_key_color() -> void:
	if _visual == null:
		return
	var material := StandardMaterial3D.new()
	var color_key_id := _effective_required_key_id()
	if _effective_match_mode() == MATCH_UNLOCKED or color_key_id == KEY_RULES.KEY_NONE:
		color_key_id = KEY_RULES.KEY_ALL
	material.albedo_color = KEY_RULES.key_color(color_key_id)
	material.roughness = 0.75
	_visual.material_override = material


func _rebuild_door_visual_model() -> void:
	if _visual == null:
		return
	_visual.visible = true
	var existing_root := get_visual_model_root()
	if existing_root != null:
		_visual.remove_child(existing_root)
		existing_root.free()
	_visual_source_path = ""

	if _build_original_door_visual_model():
		return

	var style := _door_visual_style()
	_visual_signature = "%s:%d:%d" % [
		_normalized_source_wmb_name(),
		int(style.get("pattern", DOOR_PATTERN_KEYED)),
		int(style.get("key_id", _effective_required_key_id()))
	]

	var main_mesh := BoxMesh.new()
	main_mesh.size = style.get("panel_size", Vector3(1.72, 1.42, 0.18))
	_visual.mesh = main_mesh
	_visual.material_override = _make_door_material(style.get("panel_color", KEY_RULES.key_color(_effective_required_key_id())), 0.08)

	var root := Node3D.new()
	root.name = DOOR_MODEL_ROOT_NAME
	_visual.add_child(root)

	_add_box_part(root, "DoorFrameLeft", Vector3(-1.04, 0.0, 0.0), Vector3(0.18, 1.78, 0.42), style.get("trim_color", Color(0.2, 0.19, 0.17)))
	_add_box_part(root, "DoorFrameRight", Vector3(1.04, 0.0, 0.0), Vector3(0.18, 1.78, 0.42), style.get("trim_color", Color(0.2, 0.19, 0.17)))
	_add_box_part(root, "DoorFrameTop", Vector3(0.0, 0.84, 0.0), Vector3(2.22, 0.18, 0.44), style.get("trim_color", Color(0.2, 0.19, 0.17)))
	_add_box_part(root, "DoorFrameBottom", Vector3(0.0, -0.84, 0.0), Vector3(2.22, 0.14, 0.44), style.get("trim_color", Color(0.2, 0.19, 0.17)))

	match int(style.get("pattern", DOOR_PATTERN_KEYED)):
		DOOR_PATTERN_MIXED:
			_add_mixed_key_pattern(root, int(style.get("key_id", _effective_required_key_id())))
		DOOR_PATTERN_EXIT:
			_add_exit_pattern(root)
		DOOR_PATTERN_DARK:
			_add_dark_pattern(root)
		DOOR_PATTERN_WEAK:
			_add_weak_pattern(root, int(style.get("weak_level", 1)))
		DOOR_PATTERN_ALL:
			_add_all_key_pattern(root)
		_:
			_add_keyed_pattern(root, int(style.get("key_id", _effective_required_key_id())))


func _build_original_door_visual_model() -> bool:
	var source := _normalized_source_wmb_name()
	var scene_path := _converted_door_scene_path(source)
	if scene_path.is_empty():
		return false
	var packed_scene := load(scene_path) as PackedScene
	if packed_scene == null:
		push_warning("Unable to load converted gate model for %s at %s" % [source, scene_path])
		return false
	var root := packed_scene.instantiate() as Node3D
	if root == null:
		push_warning("Converted gate model root is not Node3D for %s at %s" % [source, scene_path])
		return false

	_visual.mesh = null
	_visual.material_override = null
	root.name = DOOR_MODEL_ROOT_NAME
	_visual.add_child(root)
	_visual_source_path = scene_path
	_visual_signature = "%s:%s" % [source, scene_path]
	return true


func _converted_door_scene_path(source: String) -> String:
	var stem := _source_wmb_stem(source)
	if stem.is_empty():
		return ""
	var scene_path := "%s/%s/%s.gltf" % [ORIGINAL_GATE_MODEL_ROOT, stem, stem]
	return scene_path if ResourceLoader.exists(scene_path) else ""


func _source_wmb_stem(source: String) -> String:
	var source_file := source.get_file().to_lower()
	if source_file.ends_with(".wmb"):
		source_file = source_file.left(source_file.length() - 4)
	var cleaned := ""
	for index in range(source_file.length()):
		var character := source_file.substr(index, 1)
		if (character >= "a" and character <= "z") or (character >= "0" and character <= "9"):
			cleaned += character
		else:
			cleaned += "_"
	return cleaned


func _count_mesh_instances(node: Node) -> int:
	if node == null:
		return 0
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_mesh_instances(child)
	return count


func _accumulate_mesh_bounds(root: Node3D, node: Node, bounds_state: Array) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var local_bounds := mesh_instance.get_aabb()
		var root_from_mesh := root.global_transform.affine_inverse() * mesh_instance.global_transform
		for corner_index in 8:
			var corner := local_bounds.position + Vector3(
				local_bounds.size.x if (corner_index & 1) != 0 else 0.0,
				local_bounds.size.y if (corner_index & 2) != 0 else 0.0,
				local_bounds.size.z if (corner_index & 4) != 0 else 0.0
			)
			var transformed_corner := root_from_mesh * corner
			if not bool(bounds_state[0]):
				bounds_state[1] = AABB(transformed_corner, Vector3.ZERO)
				bounds_state[0] = true
			else:
				var bounds: AABB = bounds_state[1]
				bounds = bounds.expand(transformed_corner)
				bounds_state[1] = bounds
	for child in node.get_children():
		_accumulate_mesh_bounds(root, child, bounds_state)


func _begin_open() -> void:
	_open = true
	_state = STATE_OPENING
	_open_hold_remaining = _effective_auto_close_delay_seconds()
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)
	set_deferred("collision_layer", 0)


func _begin_close() -> void:
	if _state == STATE_LOCKED_OPEN or is_close_blocked():
		return
	_open = false
	_state = STATE_CLOSING
	_play_sfx(close_sound_asset_id)


func _complete_close() -> void:
	_state = STATE_CLOSED
	_open = false
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", false)
	set_deferred("collision_layer", _closed_collision_layer)
	set_deferred("collision_mask", _closed_collision_mask)


func _lock_open_permanently() -> void:
	_state = STATE_LOCKED_OPEN
	_open = true
	_open_hold_remaining = 0.0
	_permanent_key_flight_active = false
	_apply_locked_open_visual_model()
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)
	set_deferred("collision_layer", 0)


func _initialize_weak_door_state() -> void:
	_weak_door_strength = _initial_weak_door_strength()


func _initial_weak_door_strength() -> int:
	if weak_door_resistance > 0:
		return weak_door_resistance
	var inferred_strength := _infer_weak_door_strength(_normalized_source_wmb_name())
	if inferred_strength > 0:
		return inferred_strength
	return 1 if destructible_by_wasps else 0


func _is_wasp_destructible() -> bool:
	return destructible_by_wasps or _is_weak_door_source(_normalized_source_wmb_name())


func _is_weak_door_source(source: String) -> bool:
	return source.get_file().to_lower().begins_with("doorwk")


func _infer_weak_door_strength(source: String) -> int:
	if not _is_weak_door_source(source):
		return 0
	var weak_level := _weak_level_from_source_wmb(source)
	return maxi(5 - weak_level, 1)


func _source_wmb_name_for_weak_strength(strength: int) -> String:
	if strength >= 4:
		return "doorwk1.wmb"
	if strength == 3:
		return "doorwk2.wmb"
	if strength == 2:
		return "doorwk3.wmb"
	return "doorwk4.wmb"


func _is_original_wasp_projectile(projectile: Node) -> bool:
	if projectile == null or not projectile.has_method("get_idplayer"):
		return false
	return int(projectile.call("get_idplayer")) == WASP_PROJECTILE_IDPLAYER


func _get_wasp_damage(projectile: Node) -> int:
	if projectile == null or not projectile.has_method("get_wasp_type"):
		return 1
	var wasp_type := projectile.call("get_wasp_type") as Resource
	if wasp_type == null:
		return 1
	var raw_damage = wasp_type.get("damage")
	if raw_damage == null:
		return 1
	return maxi(int(raw_damage), 0)


func _destroy_weak_door(projectile: Node) -> void:
	_destroyed = true
	_weak_door_strength = 0
	_open = true
	_state = STATE_LOCKED_OPEN
	_open_hold_remaining = 0.0
	_permanent_key_flight_active = false
	_visual_signature = "%s:destroyed" % _normalized_source_wmb_name()
	_visual_source_path = ""
	if _visual != null:
		_visual.visible = false
	if _collision_shape != null:
		_collision_shape.set_deferred("disabled", true)
	if _trigger_shape != null:
		_trigger_shape.set_deferred("disabled", true)
	if _trigger != null:
		_trigger.set_deferred("monitoring", false)
		_trigger.set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if spawn_weak_debris:
		_spawn_weak_gate_debris(projectile)


func _spawn_weak_gate_debris(projectile: Node) -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	var parent := get_parent()
	if parent == null:
		parent = self
	var impact_offset := Vector3.ZERO
	var projectile_node := projectile as Node3D
	if projectile_node != null:
		var horizontal := Vector3(global_position.x - projectile_node.global_position.x, 0.0, global_position.z - projectile_node.global_position.z)
		if horizontal.length_squared() > 0.0001:
			impact_offset = horizontal.normalized() * 0.15
	for index in WEAK_DEBRIS_MODEL_ASSET_IDS.size():
		var asset_id := String(WEAK_DEBRIS_MODEL_ASSET_IDS[index])
		if not assets.has_method("load_asset"):
			continue
		var packed_scene := assets.call("load_asset", asset_id) as PackedScene
		if packed_scene == null:
			continue
		var piece := packed_scene.instantiate() as Node3D
		if piece == null:
			continue
		piece.name = "WeakGateDebris%d" % index
		parent.add_child(piece)
		var debris_offset: Vector3 = WEAK_DEBRIS_OFFSETS[index]
		var debris_launch: Vector3 = WEAK_DEBRIS_LAUNCHES[index]
		var debris_rotation: Vector3 = WEAK_DEBRIS_ROTATIONS[index]
		var model_scale := Vector3.ONE * ACKNEX_TO_GODOT_SCALE
		if assets.has_method("get_model_scale"):
			model_scale = assets.call("get_model_scale", asset_id)
		piece.scale = model_scale
		piece.global_position = global_position + Vector3.UP * 0.55 + debris_offset + impact_offset
		piece.rotation_degrees = debris_rotation * 0.2
		_weak_debris_spawned_count += 1
		var target_position: Vector3 = piece.global_position + debris_launch + impact_offset
		var motion_tween := piece.create_tween()
		motion_tween.set_parallel(true)
		motion_tween.tween_property(piece, "global_position", target_position, WEAK_DEBRIS_LAUNCH_SECONDS)
		motion_tween.tween_property(piece, "rotation_degrees", debris_rotation, WEAK_DEBRIS_LAUNCH_SECONDS)
		var cleanup_tween := piece.create_tween()
		cleanup_tween.tween_interval(WEAK_DEBRIS_LIFETIME_SECONDS)
		cleanup_tween.tween_callback(Callable(piece, "queue_free"))


func _update_open_hold(delta: float) -> void:
	if _state != STATE_OPEN or _effective_close_mode() != CLOSE_AUTO:
		return
	if _open_hold_remaining > 0.0:
		_open_hold_remaining = maxf(0.0, _open_hold_remaining - delta)
	if _open_hold_remaining <= 0.0:
		_begin_close()


func _target_visual_position() -> Vector3:
	var target := _closed_visual_position
	if _state == STATE_OPENING or _state == STATE_OPEN or _state == STATE_LOCKED_OPEN:
		target.y += open_height
	return target


func _on_visual_reached_target() -> void:
	if _state == STATE_OPENING:
		if _effective_close_mode() == CLOSE_PERMANENT_CONSUME and not _permanent_key_flight_active:
			_lock_open_permanently()
		else:
			_state = STATE_OPEN
	elif _state == STATE_CLOSING:
		_complete_close()


func _effective_match_mode() -> int:
	if use_wdl_door_fields:
		if wdl_flag6_unlocked:
			return MATCH_UNLOCKED
		if wdl_skill6_required_key == KEY_RULES.KEY_NONE:
			return MATCH_NEVER
		if wdl_flag7_exact_match:
			return MATCH_EXACT_ONLY
		return MATCH_COMPONENT_OR_EXACT
	var source_behavior := _source_wmb_behavior()
	if not source_behavior.is_empty():
		return int(source_behavior["match_mode"])
	if match_mode == MATCH_USE_STRICT_PROPERTY:
		return MATCH_EXACT_ONLY if strict_match else MATCH_COMPONENT_OR_EXACT
	return match_mode


func _effective_close_mode() -> int:
	if use_wdl_door_fields:
		if wdl_flag5_permanent:
			return CLOSE_PERMANENT_CONSUME
		if not is_zero_approx(wdl_skill5_close_speed):
			return CLOSE_AUTO
		return CLOSE_STAY_OPEN
	var source_behavior := _source_wmb_behavior()
	if not source_behavior.is_empty():
		return int(source_behavior["close_mode"])
	return close_mode


func _effective_required_key_id() -> int:
	if use_wdl_door_fields:
		return wdl_skill6_required_key
	var source_behavior := _source_wmb_behavior()
	if not source_behavior.is_empty():
		return int(source_behavior["required_key_id"])
	return required_key_id


func _effective_auto_close_delay_seconds() -> float:
	if use_wdl_door_fields:
		var hold_units := wdl_skill8_hold_units
		if is_zero_approx(hold_units):
			hold_units = 4.0
		return maxf(hold_units, 0.0) / 4.0
	var source_behavior := _source_wmb_behavior()
	if not source_behavior.is_empty():
		return float(source_behavior["auto_close_delay_seconds"])
	return maxf(auto_close_delay_seconds, 0.0)


func _effective_close_speed() -> float:
	if use_wdl_door_fields and not is_zero_approx(wdl_skill5_close_speed):
		return absf(wdl_skill5_close_speed)
	var source_behavior := _source_wmb_behavior()
	if not source_behavior.is_empty():
		return float(source_behavior["close_speed"])
	return close_speed


func _effective_strict_match() -> bool:
	return _effective_match_mode() == MATCH_EXACT_ONLY


func _source_wmb_behavior() -> Dictionary:
	if not use_source_wmb_behavior:
		return {}
	var source := _explicit_source_wmb_name()
	if source.is_empty():
		return {}
	if source == "dfixall.wmb":
		return _make_source_wmb_behavior(KEY_RULES.KEY_ALL, MATCH_ANY_KEY, CLOSE_PERMANENT_CONSUME)
	if source == "doorexit.wmb" or source == "doordark.wmb" or source.begins_with("doorwk"):
		return {}
	var key_id := _key_id_from_source_wmb(source)
	if key_id == KEY_RULES.KEY_NONE:
		return {}
	if source.begins_with("dfix"):
		return _make_source_wmb_behavior(key_id, MATCH_EXACT_ONLY, CLOSE_PERMANENT_CONSUME)
	if source.begins_with("done"):
		return _make_source_wmb_behavior(key_id, MATCH_EXACT_ONLY, CLOSE_STAY_OPEN)
	if source.begins_with("door"):
		return _make_source_wmb_behavior(key_id, MATCH_EXACT_ONLY, CLOSE_AUTO)
	return {}


func _make_source_wmb_behavior(key_id: int, source_match_mode: int, source_close_mode: int) -> Dictionary:
	return {
		"required_key_id": key_id,
		"match_mode": source_match_mode,
		"close_mode": source_close_mode,
		"auto_close_delay_seconds": SOURCE_MODEL_AUTO_CLOSE_DELAY_SECONDS,
		"close_speed": SOURCE_MODEL_CLOSE_SPEED
	}


func _can_key_open(key_id: int) -> bool:
	match _effective_match_mode():
		MATCH_UNLOCKED:
			return true
		MATCH_NEVER:
			return false
		MATCH_ANY_KEY:
			return key_id != KEY_RULES.KEY_NONE
		MATCH_EXACT_ONLY:
			return KEY_RULES.can_open_gate(key_id, _effective_required_key_id(), true)
		MATCH_COMPONENT_OR_EXACT:
			return KEY_RULES.can_open_gate(key_id, _effective_required_key_id(), false)
	return KEY_RULES.can_open_gate(key_id, _effective_required_key_id(), strict_match)


func _consume_player_key(player: Node) -> int:
	if player == null:
		return KEY_RULES.KEY_NONE
	if player.has_method("get_current_key_id"):
		var current_key_id := int(player.call("get_current_key_id"))
		if current_key_id == KEY_RULES.KEY_NONE or not _can_key_open(current_key_id):
			return KEY_RULES.KEY_NONE
		var keep_infinite_key := current_key_id == KEY_RULES.KEY_ALL and player.has_method("is_current_key_infinite") and bool(player.call("is_current_key_infinite"))
		if not keep_infinite_key and player.has_method("set_current_key_id"):
			player.call("set_current_key_id", KEY_RULES.KEY_NONE)
		return current_key_id
	if player.has_method("consume_key_for_gate"):
		return int(player.call("consume_key_for_gate", _effective_required_key_id(), _effective_strict_match()))
	if player.has_method("get_current_key_id") and _can_key_open(int(player.call("get_current_key_id"))):
		return int(player.call("get_current_key_id"))
	return KEY_RULES.KEY_NONE


func _spawn_key_flight(source: Node3D, key_id: int) -> void:
	if get_tree() == null:
		_lock_open_permanently()
		return
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		_lock_open_permanently()
		return
	var effect := GATE_KEY_FLIGHT_EFFECT_SCRIPT.new()
	effect.name = "GateKeyFlightEffect"
	parent.add_child(effect)
	_permanent_key_flight_active = true
	effect.flight_finished.connect(_on_key_flight_finished)
	effect.configure(source, self, key_id, key_flight_speed, key_flight_height_offset)


func _on_key_flight_finished(_key_id: int) -> void:
	_lock_open_permanently()


func _play_sfx(asset_id: String) -> void:
	if asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_spatial_sfx"):
		audio.call("play_spatial_sfx", asset_id, self, DOOR_SOUND_WDL_RANGE_UNITS)
	elif audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", asset_id)


func _door_visual_style() -> Dictionary:
	var source := _normalized_source_wmb_name()
	var key_id := _key_id_from_source_wmb(source)
	if key_id == KEY_RULES.KEY_NONE and _effective_required_key_id() != KEY_RULES.KEY_NONE:
		key_id = _effective_required_key_id()
	var pattern := DOOR_PATTERN_KEYED
	var panel_color := KEY_RULES.key_color(key_id)
	var trim_color := Color(0.22, 0.2, 0.17, 1.0)
	var weak_level := 0

	if source.begins_with("doorwk"):
		pattern = DOOR_PATTERN_WEAK
		weak_level = _weak_level_from_source_wmb(source)
		panel_color = Color(0.36, 0.25, 0.14, 1.0)
		trim_color = Color(0.16, 0.11, 0.08, 1.0)
	elif source == "doordark.wmb":
		pattern = DOOR_PATTERN_DARK
		key_id = KEY_RULES.KEY_NONE
		panel_color = Color(0.05, 0.055, 0.07, 1.0)
		trim_color = Color(0.1, 0.1, 0.12, 1.0)
	elif source == "doorexit.wmb":
		pattern = DOOR_PATTERN_EXIT
		key_id = KEY_RULES.KEY_ALL
		panel_color = Color(0.78, 0.75, 0.6, 1.0)
		trim_color = Color(0.55, 0.42, 0.14, 1.0)
	elif key_id == KEY_RULES.KEY_ALL:
		pattern = DOOR_PATTERN_ALL
	elif key_id == KEY_RULES.KEY_ORANGE or key_id == KEY_RULES.KEY_MAGENTA or key_id == KEY_RULES.KEY_GREEN:
		pattern = DOOR_PATTERN_MIXED

	return {
		"key_id": key_id,
		"pattern": pattern,
		"panel_color": panel_color,
		"trim_color": trim_color,
		"weak_level": weak_level,
		"panel_size": Vector3(1.72, 1.42, 0.18)
	}


func _normalized_source_wmb_name() -> String:
	var source := _explicit_source_wmb_name()
	return source if not source.is_empty() else _default_source_wmb_name_for_key(_effective_required_key_id())


func _explicit_source_wmb_name() -> String:
	return source_wmb_name.get_file().to_lower()


func _default_source_wmb_name_for_key(key_id: int) -> String:
	match key_id:
		KEY_RULES.KEY_RED:
			return "doorred.wmb"
		KEY_RULES.KEY_YELLOW:
			return "dooryell.wmb"
		KEY_RULES.KEY_ORANGE:
			return "doororan.wmb"
		KEY_RULES.KEY_BLUE:
			return "doorblue.wmb"
		KEY_RULES.KEY_MAGENTA:
			return "doormage.wmb"
		KEY_RULES.KEY_GREEN:
			return "doorgree.wmb"
		KEY_RULES.KEY_ALL:
			return "dfixall.wmb"
	return PERMANENT_LOCKED_OPEN_WMB_NAME


func _apply_locked_open_visual_model() -> void:
	if _normalized_source_wmb_name() == PERMANENT_LOCKED_OPEN_WMB_NAME:
		return
	source_wmb_name = PERMANENT_LOCKED_OPEN_WMB_NAME
	_rebuild_door_visual_model()


func _key_id_from_source_wmb(source: String) -> int:
	match source:
		"doorred.wmb", "dfixred.wmb", "donered.wmb":
			return KEY_RULES.KEY_RED
		"dooryell.wmb", "dfixyell.wmb", "doneyell.wmb":
			return KEY_RULES.KEY_YELLOW
		"doorblue.wmb", "dfixblue.wmb", "doneblue.wmb":
			return KEY_RULES.KEY_BLUE
		"doororan.wmb", "dfixoran.wmb", "doneoran.wmb":
			return KEY_RULES.KEY_ORANGE
		"doormag.wmb", "doormage.wmb", "dfixmag.wmb", "donemage.wmb":
			return KEY_RULES.KEY_MAGENTA
		"doorgree.wmb", "dfixgree.wmb", "donegree.wmb":
			return KEY_RULES.KEY_GREEN
		"dfixall.wmb":
			return KEY_RULES.KEY_ALL
	return KEY_RULES.KEY_NONE


func _weak_level_from_source_wmb(source: String) -> int:
	if source.ends_with("4.wmb"):
		return 4
	if source.ends_with("3.wmb"):
		return 3
	if source.ends_with("2.wmb"):
		return 2
	return 1


func _add_keyed_pattern(root: Node3D, key_id: int) -> void:
	var accent := KEY_RULES.key_color(key_id)
	_add_box_part(root, "DoorInset", Vector3(0.0, 0.0, -0.18), Vector3(1.32, 1.08, 0.08), accent.darkened(0.45), 0.05)
	for index in 3:
		var x := -0.42 + float(index) * 0.42
		_add_box_part(root, "DoorKeyStripe%d" % index, Vector3(x, -0.08, -0.28), Vector3(0.13, 1.06, 0.08), accent, 0.18)
	_add_key_badge(root, key_id, Vector3(0.0, 0.43, -0.34))


func _add_mixed_key_pattern(root: Node3D, key_id: int) -> void:
	var colors := _component_colors_for_key(key_id)
	var accent := KEY_RULES.key_color(key_id)
	_add_box_part(root, "DoorMixedInset", Vector3(0.0, 0.0, -0.18), Vector3(1.32, 1.08, 0.08), accent.darkened(0.5), 0.05)
	_add_box_part(root, "DoorMixedLeftComponent", Vector3(-0.42, -0.05, -0.28), Vector3(0.22, 1.04, 0.08), colors[0], 0.14)
	_add_box_part(root, "DoorMixedRightComponent", Vector3(0.42, -0.05, -0.28), Vector3(0.22, 1.04, 0.08), colors[1], 0.14)
	_add_box_part(root, "DoorMixedCenterLock", Vector3(0.0, -0.05, -0.31), Vector3(0.34, 0.72, 0.1), accent, 0.18)
	_add_box_part(root, "DoorMixedTopBand", Vector3(0.0, 0.52, -0.29), Vector3(1.14, 0.12, 0.08), accent.lightened(0.12), 0.12)
	_add_key_badge(root, key_id, Vector3(0.0, 0.42, -0.36))


func _add_all_key_pattern(root: Node3D) -> void:
	var key_ids := [
		KEY_RULES.KEY_RED,
		KEY_RULES.KEY_YELLOW,
		KEY_RULES.KEY_ORANGE,
		KEY_RULES.KEY_BLUE,
		KEY_RULES.KEY_MAGENTA,
		KEY_RULES.KEY_GREEN
	]
	_add_box_part(root, "DoorAllInset", Vector3(0.0, 0.0, -0.18), Vector3(1.38, 1.1, 0.08), Color(0.72, 0.72, 0.68, 1.0), 0.03)
	for index in key_ids.size():
		var x := -0.5 + float(index % 3) * 0.5
		var y := 0.16 - float(index / 3) * 0.48
		_add_box_part(root, "DoorAllColor%d" % index, Vector3(x, y, -0.3), Vector3(0.32, 0.32, 0.08), KEY_RULES.key_color(key_ids[index]), 0.16)
	_add_key_badge(root, KEY_RULES.KEY_ALL, Vector3(0.0, 0.54, -0.36))


func _add_exit_pattern(root: Node3D) -> void:
	var gold := Color(0.95, 0.72, 0.18, 1.0)
	var pale := Color(0.86, 0.84, 0.68, 1.0)
	_add_box_part(root, "DoorExitInset", Vector3(0.0, -0.08, -0.18), Vector3(1.28, 1.18, 0.08), pale, 0.05)
	_add_box_part(root, "DoorExitArchTop", Vector3(0.0, 0.52, -0.29), Vector3(1.14, 0.24, 0.1), gold, 0.15)
	_add_box_part(root, "DoorExitArchLeft", Vector3(-0.5, -0.08, -0.29), Vector3(0.18, 0.98, 0.1), gold.darkened(0.12), 0.1)
	_add_box_part(root, "DoorExitArchRight", Vector3(0.5, -0.08, -0.29), Vector3(0.18, 0.98, 0.1), gold.darkened(0.12), 0.1)
	_add_box_part(root, "DoorExitCenterLight", Vector3(0.0, -0.08, -0.32), Vector3(0.42, 0.72, 0.08), Color(0.96, 0.95, 0.78, 1.0), 0.08)
	_add_key_badge(root, KEY_RULES.KEY_ALL, Vector3(0.0, 0.18, -0.38))


func _add_dark_pattern(root: Node3D) -> void:
	var dark := Color(0.02, 0.025, 0.035, 1.0)
	var edge := Color(0.14, 0.11, 0.22, 1.0)
	_add_box_part(root, "DoorDarkInset", Vector3(0.0, 0.0, -0.18), Vector3(1.32, 1.08, 0.08), dark, 0.0)
	_add_box_part(root, "DoorDarkScanner", Vector3(0.0, 0.36, -0.31), Vector3(0.72, 0.12, 0.08), edge, 0.05)
	for index in 4:
		var y := 0.06 - float(index) * 0.24
		_add_box_part(root, "DoorDarkSlot%d" % index, Vector3(0.0, y, -0.29), Vector3(1.0, 0.06, 0.08), edge.darkened(0.3), 0.02)


func _add_weak_pattern(root: Node3D, weak_level: int) -> void:
	var wood := Color(0.43, 0.29, 0.16, 1.0)
	var metal := Color(0.18, 0.17, 0.15, 1.0)
	_add_box_part(root, "DoorWeakInset", Vector3(0.0, 0.0, -0.18), Vector3(1.34, 1.1, 0.08), wood.darkened(0.18), 0.03)
	for index in max(weak_level, 1):
		var y := 0.36 - float(index) * 0.28
		_add_box_part(root, "DoorWeakPlank%d" % index, Vector3(0.0, y, -0.29), Vector3(1.16, 0.14, 0.08), wood.lightened(float(index) * 0.04), 0.04)
	_add_box_part(root, "DoorWeakBraceA", Vector3(-0.34, 0.0, -0.32), Vector3(0.12, 1.16, 0.1), metal, 0.02)
	_add_box_part(root, "DoorWeakBraceB", Vector3(0.34, 0.0, -0.32), Vector3(0.12, 1.16, 0.1), metal, 0.02)


func _add_box_part(root: Node3D, part_name: String, local_position: Vector3, size: Vector3, color: Color, emission_strength: float = 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var part := MeshInstance3D.new()
	part.name = part_name
	part.position = local_position
	part.mesh = mesh
	part.material_override = _make_door_material(color, emission_strength)
	root.add_child(part)
	return part


func _add_key_badge(root: Node3D, key_id: int, local_position: Vector3) -> void:
	var texture := _load_key_texture(key_id)
	if texture == null:
		_add_box_part(root, "DoorKeyBadgeFallback", local_position, Vector3(0.36, 0.36, 0.08), KEY_RULES.key_color(key_id), 0.12)
		return
	var sprite := Sprite3D.new()
	sprite.name = "DoorKeyBadge"
	sprite.position = local_position
	sprite.texture = texture
	sprite.hframes = KEY_RULES.VISUAL_FRAME_COUNT
	sprite.vframes = 1
	sprite.frame = 0
	sprite.pixel_size = 0.012
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	root.add_child(sprite)


func _load_key_texture(key_id: int) -> Texture2D:
	var asset_id := KEY_RULES.key_texture_asset_id(key_id)
	if not asset_id.is_empty():
		var assets := get_node_or_null("/root/Assets")
		if assets != null and assets.has_method("load_asset"):
			var texture := assets.call("load_asset", asset_id) as Texture2D
			if texture != null:
				return texture
	var texture_path := _key_texture_path(key_id)
	return load(texture_path) as Texture2D if not texture_path.is_empty() else null


func _key_texture_path(key_id: int) -> String:
	match key_id:
		KEY_RULES.KEY_RED:
			return "res://assets/textures/key_diamonds/gemre+17.png"
		KEY_RULES.KEY_YELLOW:
			return "res://assets/textures/key_diamonds/gemye+17.png"
		KEY_RULES.KEY_ORANGE:
			return "res://assets/textures/key_diamonds/gemor+17.png"
		KEY_RULES.KEY_BLUE:
			return "res://assets/textures/key_diamonds/gembl+17.png"
		KEY_RULES.KEY_MAGENTA:
			return "res://assets/textures/key_diamonds/gemma+17.png"
		KEY_RULES.KEY_GREEN:
			return "res://assets/textures/key_diamonds/gemve+17.png"
		KEY_RULES.KEY_ALL:
			return "res://assets/textures/key_diamonds/gemmu+17.png"
	return ""


func _component_colors_for_key(key_id: int) -> Array[Color]:
	match key_id:
		KEY_RULES.KEY_ORANGE:
			return [KEY_RULES.key_color(KEY_RULES.KEY_RED), KEY_RULES.key_color(KEY_RULES.KEY_YELLOW)]
		KEY_RULES.KEY_MAGENTA:
			return [KEY_RULES.key_color(KEY_RULES.KEY_RED), KEY_RULES.key_color(KEY_RULES.KEY_BLUE)]
		KEY_RULES.KEY_GREEN:
			return [KEY_RULES.key_color(KEY_RULES.KEY_YELLOW), KEY_RULES.key_color(KEY_RULES.KEY_BLUE)]
	return [KEY_RULES.key_color(key_id), KEY_RULES.key_color(key_id)]


func _make_door_material(color: Color, emission_strength: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.metallic = 0.0
	if emission_strength > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_strength
	return material
