extends AnimatableBody3D
class_name MovingPlatform

const KEY_RULES := preload("res://src/resources/key_diamond_rules.gd")

const ACKNEX_TO_GODOT_SCALE := 0.01
const ACKNEX_TICKS_PER_SECOND := 16.0
const WORLD_LAYER := 1
const CHARACTER_LAYER := 2
const PLATFORM_MODEL_ROOT := "res://assets/models/platforms"
const VISUAL_MODEL_ROOT_NAME := "PlatformModelRoot"
const ACTIVATION_SOUND_WDL_RANGE_UNITS := 1000.0

const MATCH_COMPONENT_OR_EXACT := 0
const MATCH_EXACT_ONLY := 1

const VARIANT_CUSTOM := 0
const VARIANT_UNLOCKED_ACTIVE := 1
const VARIANT_UNLOCKED_COLUMN := 2
const VARIANT_UNLOCKED_COLUMN_ALT := 3
const VARIANT_RED_KEY := 4
const VARIANT_YELLOW_KEY := 5
const VARIANT_BLUE_KEY := 6
const VARIANT_ORANGE_MIXED_KEY := 7
const VARIANT_MAGENTA_MIXED_KEY := 8
const VARIANT_GREEN_MIXED_KEY := 9
const VARIANT_INVISIBLE_RED_KEY := 10

@export var platform_id: int = 8465
@export_enum(
        "Custom",
        "Unlocked Active",
        "Unlocked Column",
        "Unlocked Column Alt",
        "Red Key",
        "Yellow Key",
        "Blue Key",
        "Orange Mixed Key",
        "Magenta Mixed Key",
        "Green Mixed Key",
        "Invisible Red Key")
var platform_variant: int = VARIANT_CUSTOM:
    set(value):
        platform_variant = value
        _apply_platform_variant(value)
@export var source_wmb_name: String = "platfor2.wmb":
    set(value):
        source_wmb_name = value
        if is_inside_tree():
            _rebuild_visual()
@export var active_wmb_name: String = "platfor1.wmb"
@export var end_offset: Vector3 = Vector3(4.0, 0.0, 0.0)
@export var wdl_speed_units: float = 20.0
@export var endpoint_wait_ticks: float = 16.0
@export var required_key_id: int = KEY_RULES.KEY_NONE
@export_enum("Component or Exact", "Exact Only") var key_match_mode: int = MATCH_COMPONENT_OR_EXACT
@export var invisible_until_active: bool = false
@export var morph_to_active_visual: bool = true
@export var activation_sound_asset_id: String = "sfx.platform_activate"
@export var allow_player_boost_speedup: bool = true
@export var boost_speed_multiplier: float = 3.0
@export var turnaround_yaw_degrees: float = 0.0

var _start_position := Vector3.ZERO
var _end_position := Vector3.ZERO
var _path_basis := Basis.IDENTITY
var _direction := 1
var _active := false
var _wait_remaining := 0.0
var _last_displacement := Vector3.ZERO
var _last_velocity := Vector3.ZERO
var _visual_source_path := ""
var _active_rider: Node = null

@onready var _visual_root: Node3D = $VisualRoot
@onready var _activation_sensor: Area3D = $ActivationSensor


func _ready() -> void:
    add_to_group("moving_platform")
    sync_to_physics = false
    _start_position = global_position
    _path_basis = global_transform.basis
    _end_position = _start_position + _path_basis * end_offset
    _active = required_key_id == KEY_RULES.KEY_NONE
    if _activation_sensor != null:
        _activation_sensor.body_entered.connect(_on_activation_body_entered)
        _activation_sensor.body_exited.connect(_on_activation_body_exited)
    _rebuild_visual()


func _physics_process(delta: float) -> void:
    var safe_delta := maxf(delta, 0.0)
    _last_displacement = Vector3.ZERO
    _last_velocity = Vector3.ZERO
    if not _active or safe_delta <= 0.0:
        return
    if _wait_remaining > 0.0:
        _wait_remaining = maxf(0.0, _wait_remaining - safe_delta)
        return

    var previous_position := global_position
    var target := _end_position if _direction > 0 else _start_position
    var next_position := previous_position.move_toward(target, _effective_speed(safe_delta) * safe_delta)
    _last_displacement = next_position - previous_position
    _last_velocity = _last_displacement / safe_delta
    global_position = next_position
    if next_position.is_equal_approx(target):
        _direction *= -1
        _wait_remaining = get_endpoint_wait_seconds()
        if not is_zero_approx(turnaround_yaw_degrees):
            rotate_y(deg_to_rad(turnaround_yaw_degrees))


func activate(player: Node = null) -> bool:
    if _active:
        return true
    if required_key_id != KEY_RULES.KEY_NONE and not _can_player_activate(player):
        return false
    _active = true
    if morph_to_active_visual:
        _rebuild_visual()
    _play_sfx(activation_sound_asset_id)
    return true


func is_active() -> bool:
    return _active


func get_platform_id() -> int:
    return platform_id


func get_base_speed() -> float:
    return absf(wdl_speed_units) * ACKNEX_TO_GODOT_SCALE * ACKNEX_TICKS_PER_SECOND


func get_endpoint_wait_seconds() -> float:
    return maxf(endpoint_wait_ticks, 0.0) / ACKNEX_TICKS_PER_SECOND


func get_last_platform_displacement() -> Vector3:
    return _last_displacement


func get_last_platform_velocity() -> Vector3:
    return _last_velocity


func get_visual_source_path() -> String:
    return _visual_source_path


func has_original_visual_model() -> bool:
    return not _visual_source_path.is_empty()


func get_visual_model_root() -> Node3D:
    if _visual_root == null:
        return null
    return _visual_root.get_node_or_null(VISUAL_MODEL_ROOT_NAME) as Node3D


func get_effective_source_wmb_name() -> String:
    if _active and morph_to_active_visual and not active_wmb_name.is_empty():
        return active_wmb_name.get_file().to_lower()
    return source_wmb_name.get_file().to_lower()


func _apply_platform_variant(variant: int) -> void:
    match variant:
        VARIANT_UNLOCKED_ACTIVE:
            _configure_platform_visual("platfor2.wmb", "platfor1.wmb", KEY_RULES.KEY_NONE, MATCH_COMPONENT_OR_EXACT, false, true)
        VARIANT_UNLOCKED_COLUMN:
            _configure_platform_visual("platfor2.wmb", "platfor2.wmb", KEY_RULES.KEY_NONE, MATCH_COMPONENT_OR_EXACT, false, false)
        VARIANT_UNLOCKED_COLUMN_ALT:
            _configure_platform_visual("platfor3.wmb", "platfor3.wmb", KEY_RULES.KEY_NONE, MATCH_COMPONENT_OR_EXACT, false, false)
        VARIANT_RED_KEY:
            _configure_platform_visual("platfred.wmb", "platfor1.wmb", KEY_RULES.KEY_RED, MATCH_EXACT_ONLY, false, true)
        VARIANT_YELLOW_KEY:
            _configure_platform_visual("platfyel.wmb", "platfor1.wmb", KEY_RULES.KEY_YELLOW, MATCH_EXACT_ONLY, false, true)
        VARIANT_BLUE_KEY:
            _configure_platform_visual("platfblu.wmb", "platfor1.wmb", KEY_RULES.KEY_BLUE, MATCH_EXACT_ONLY, false, true)
        VARIANT_ORANGE_MIXED_KEY:
            _configure_platform_visual("platfora.wmb", "platfor1.wmb", KEY_RULES.KEY_ORANGE, MATCH_COMPONENT_OR_EXACT, false, true)
        VARIANT_MAGENTA_MIXED_KEY:
            _configure_platform_visual("platfmag.wmb", "platfor1.wmb", KEY_RULES.KEY_MAGENTA, MATCH_COMPONENT_OR_EXACT, false, true)
        VARIANT_GREEN_MIXED_KEY:
            _configure_platform_visual("platgree.wmb", "platfor1.wmb", KEY_RULES.KEY_GREEN, MATCH_COMPONENT_OR_EXACT, false, true)
        VARIANT_INVISIBLE_RED_KEY:
            _configure_platform_visual("platfred.wmb", "platfor1.wmb", KEY_RULES.KEY_RED, MATCH_EXACT_ONLY, true, true)
        _:
            return


func _configure_platform_visual(
        source: String,
        active_source: String,
        required_key: int,
        match_mode: int,
        hide_until_active: bool,
        morph_on_activate: bool) -> void:
    source_wmb_name = source
    active_wmb_name = active_source
    required_key_id = required_key
    key_match_mode = match_mode
    invisible_until_active = hide_until_active
    morph_to_active_visual = morph_on_activate
    if is_inside_tree():
        _rebuild_visual()


func _effective_speed(delta: float) -> float:
    var speed := get_base_speed()
    if allow_player_boost_speedup and _active_rider != null and _active_rider.has_method("consume_platform_boost"):
        if bool(_active_rider.call("consume_platform_boost", delta)):
            speed *= maxf(boost_speed_multiplier, 0.0)
    return speed


func _on_activation_body_entered(body: Node) -> void:
    if not _is_player(body):
        return
    _active_rider = body
    if not _active:
        activate(body)


func _on_activation_body_exited(body: Node) -> void:
    if body == _active_rider:
        _active_rider = null


func _is_player(body: Node) -> bool:
    return body != null and (body.is_in_group("player") or body.has_method("get_current_key_id"))


func _can_player_activate(player: Node) -> bool:
    if required_key_id == KEY_RULES.KEY_NONE:
        return true
    if player == null:
        return false
    if player.has_method("can_open_key_gate"):
        return bool(player.call("can_open_key_gate", required_key_id, key_match_mode == MATCH_EXACT_ONLY))
    if player.has_method("get_current_key_id"):
        return KEY_RULES.can_open_gate(
                int(player.call("get_current_key_id")),
                required_key_id,
                key_match_mode == MATCH_EXACT_ONLY)
    return false


func _rebuild_visual() -> void:
    if _visual_root == null:
        return
    for child in _visual_root.get_children():
        _visual_root.remove_child(child)
        child.free()
    _visual_source_path = ""
    if invisible_until_active and not _active:
        _visual_root.visible = false
        return
    _visual_root.visible = true
    if _build_original_visual_model():
        return
    _build_fallback_visual()


func _build_original_visual_model() -> bool:
    var source := get_effective_source_wmb_name()
    var scene_path := _converted_platform_scene_path(source)
    if scene_path.is_empty():
        return false
    var packed_scene := load(scene_path) as PackedScene
    if packed_scene == null:
        push_warning("Unable to load converted platform model for %s at %s" % [source, scene_path])
        return false
    var root := packed_scene.instantiate() as Node3D
    if root == null:
        push_warning("Converted platform model root is not Node3D for %s at %s" % [source, scene_path])
        return false
    root.name = VISUAL_MODEL_ROOT_NAME
    _visual_root.add_child(root)
    _visual_source_path = scene_path
    return true


func _build_fallback_visual() -> void:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = VISUAL_MODEL_ROOT_NAME
    var mesh := BoxMesh.new()
    mesh.size = Vector3(2.0, 0.3, 2.0)
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.45, 0.42, 0.32, 1.0)
    material.roughness = 0.75
    mesh_instance.material_override = material
    mesh_instance.position.y = 0.15
    _visual_root.add_child(mesh_instance)


func _converted_platform_scene_path(source: String) -> String:
    var stem := _source_wmb_stem(source)
    if stem.is_empty():
        return ""
    var scene_path := "%s/%s/%s.gltf" % [PLATFORM_MODEL_ROOT, stem, stem]
    return scene_path if ResourceLoader.exists(scene_path) else ""


func _source_wmb_stem(source: String) -> String:
    var source_file := source.get_file().to_lower()
    if not source_file.ends_with(".wmb"):
        return ""
    return source_file.trim_suffix(".wmb")


func _play_sfx(asset_id: String) -> void:
    if asset_id.is_empty():
        return
    var audio := get_node_or_null("/root/Audio")
    if audio != null and audio.has_method("play_spatial_sfx"):
        audio.call("play_spatial_sfx", asset_id, self, ACTIVATION_SOUND_WDL_RANGE_UNITS)
    elif audio != null and audio.has_method("play_sfx"):
        audio.call("play_sfx", asset_id)
