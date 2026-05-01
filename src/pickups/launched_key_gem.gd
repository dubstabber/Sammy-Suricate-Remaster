extends Area3D
class_name LaunchedKeyGem

const KEY_RULES := preload("res://src/resources/key_diamond_rules.gd")
const GEM_PARTICLE_EFFECT_SCRIPT := preload("res://src/effects/gem_particle_effect.gd")
const ACKNEX_TIME_UNITS_PER_SECOND := 16.0
const ACKNEX_TO_GODOT_SCALE := 0.01
const DEFAULT_FRAME_ADVANCE_PER_TIME_UNIT := 3.0
const DEFAULT_HEIGHT_GEM := 25.0 * ACKNEX_TO_GODOT_SCALE
const LIFETIME_DECORATIVE := 0.0
const LIFETIME_STAY := 1000.0
const LIFETIME_PERSISTENT := 1001.0

@export var key_type: Resource = null
@export var collect_sound_asset_id: String = "sfx.colored_gem"
@export var blink_sound_asset_id: String = "sfx.gem_blink"
@export var expire_sound_asset_id: String = "sfx.gem_break"
@export var bounce_sound_asset_ids: PackedStringArray = PackedStringArray([
	"sfx.gem_bounce_high",
	"sfx.gem_bounce_mid",
	"sfx.gem_bounce_low",
	"sfx.gem_bounce_last"
])
@export var visual_frame_count: int = KEY_RULES.VISUAL_FRAME_COUNT
@export var visual_frames_per_second: float = DEFAULT_FRAME_ADVANCE_PER_TIME_UNIT * ACKNEX_TIME_UNITS_PER_SECOND
@export var visual_pixel_size: float = 0.01
@export var visual_ground_clearance: float = DEFAULT_HEIGHT_GEM
@export var collectable_after_bounces: int = 5
@export var lifetime_ticks: float = LIFETIME_STAY
@export var ground_y: float = 0.0
@export var launch_gravity: float = 4.0
@export var bounce_damping: float = 0.55
@export var horizontal_bounce_damping: float = 0.72
@export var min_bounce_velocity: float = 0.12
@export var min_horizontal_velocity: float = 0.04
@export var spawn_effect_enabled: bool = true
@export var trail_effect_enabled: bool = true
@export var collect_effect_enabled: bool = true
@export var expire_effect_enabled: bool = true
@export var trail_emit_interval_ticks: float = 3.0

var _collected := false
var _expired := false
var _collectable := false
var _motion_active := false
var _is_shrinking := false
var _visual_sprite: Sprite3D = null
var _visual_frame_accumulator := 0.0
var _velocity := Vector3.ZERO
var _bounce_count := 0
var _lifetime_remaining_ticks := 0.0
var _source: Node = null
var _particle_effect: Node = null
var _trail_emit_remaining_ticks := 0.0
var _spawn_effect_emitted := false


func _ready() -> void:
	add_to_group("pickup")
	add_to_group("key_diamond")
	add_to_group("launched_key_gem")
	body_entered.connect(_on_body_entered)
	_lifetime_remaining_ticks = lifetime_ticks
	_spawn_visual()
	if _velocity == Vector3.ZERO and not _collectable:
		_settle_if_ready()


func _physics_process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if _motion_active:
		_update_motion(safe_delta)
		_update_trail_effect(safe_delta)


func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if not _collected and not _expired:
		_update_idle_animation(safe_delta)
		_update_lifetime(safe_delta)
	elif _is_shrinking:
		_update_collection_shrink(safe_delta)


func configure_for_key_id(key_id: int) -> bool:
	var resource_path := KEY_RULES.key_resource_path(key_id)
	if resource_path.is_empty():
		return false
	var loaded_key_type := load(resource_path) as Resource
	if loaded_key_type == null:
		return false
	key_type = loaded_key_type
	_apply_visual_texture()
	return true


func configure_launch(key_id: int, new_lifetime_ticks: float = LIFETIME_STAY, launch_velocity: Vector3 = Vector3.ZERO, new_collectable_after_bounces: int = 5, launch_source: Node = null) -> bool:
	if not configure_for_key_id(key_id):
		return false
	lifetime_ticks = maxf(new_lifetime_ticks, 0.0)
	_lifetime_remaining_ticks = lifetime_ticks
	_velocity = launch_velocity
	_source = launch_source
	collectable_after_bounces = maxi(new_collectable_after_bounces, 0)
	_bounce_count = 0
	_collected = false
	_expired = false
	_collectable = false
	_spawn_effect_emitted = false
	_trail_emit_remaining_ticks = 0.0
	_motion_active = _velocity.length() > 0.001 or global_position.y > ground_y
	visible = true
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	_emit_spawn_effect_once()
	if not _motion_active:
		_settle_if_ready()
	return true


func configure_wdl(key_id: int, new_lifetime_ticks: float, pan_degrees: float, horizontal_speed_units: float, vertical_speed_units: float, launch_source: Node = null) -> bool:
	var yaw := deg_to_rad(pan_degrees)
	var direction := Vector3(sin(yaw), 0.0, -cos(yaw)).normalized()
	var horizontal_speed := maxf(horizontal_speed_units, 0.0) * ACKNEX_TO_GODOT_SCALE * ACKNEX_TIME_UNITS_PER_SECOND
	var vertical_speed := vertical_speed_units * ACKNEX_TO_GODOT_SCALE * ACKNEX_TIME_UNITS_PER_SECOND
	var launch_velocity := direction * horizontal_speed + Vector3.UP * vertical_speed
	return configure_launch(key_id, new_lifetime_ticks, launch_velocity, collectable_after_bounces, launch_source)


func collect(player: Node) -> bool:
	return _collect_from(player)


func was_collected() -> bool:
	return _collected


func is_expired() -> bool:
	return _expired


func is_collectable() -> bool:
	return _collectable and not _collected and not _expired


func is_persistent_lifetime() -> bool:
	return lifetime_ticks >= LIFETIME_STAY


func is_persistent_restart_lifetime() -> bool:
	return is_equal_approx(lifetime_ticks, LIFETIME_PERSISTENT)


func get_key_type() -> Resource:
	return key_type


func get_key_id() -> int:
	if key_type == null:
		return KEY_RULES.KEY_NONE
	return int(key_type.get("key_id"))


func get_bounce_count() -> int:
	return _bounce_count


func get_velocity() -> Vector3:
	return _velocity


func get_lifetime_remaining_ticks() -> float:
	return _lifetime_remaining_ticks


func get_visual_sprite() -> Sprite3D:
	return _visual_sprite


func get_source() -> Node:
	return _source


func get_particle_effect() -> Node:
	return _particle_effect


func _on_body_entered(body: Node3D) -> void:
	_collect_from(body)


func _collect_from(player: Node) -> bool:
	if not is_collectable() or not _is_player_collector(player) or key_type == null:
		return false
	if not player.has_method("collect_key_diamond"):
		return false
	if not bool(player.call("collect_key_diamond", key_type, self)):
		return false

	_collected = true
	_is_shrinking = true
	_motion_active = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_emit_collect_effect()
	_play_sfx(collect_sound_asset_id)
	return true


func _is_player_collector(body: Node) -> bool:
	return body != null and body.is_in_group("player")


func _spawn_visual() -> void:
	if _visual_sprite != null:
		return
	var texture := _load_key_texture()
	if texture == null:
		return

	_visual_sprite = Sprite3D.new()
	_visual_sprite.name = "LaunchedKeyGemVisual"
	_visual_sprite.hframes = maxi(visual_frame_count, 1)
	_visual_sprite.vframes = 1
	_visual_sprite.frame = randi_range(0, _visual_sprite.hframes - 1)
	_visual_sprite.pixel_size = visual_pixel_size
	_visual_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_visual_sprite.position.y = visual_ground_clearance
	add_child(_visual_sprite)
	_apply_visual_texture()


func _apply_visual_texture() -> void:
	if _visual_sprite == null:
		return
	var texture := _load_key_texture()
	if texture != null:
		_visual_sprite.texture = texture


func _load_key_texture() -> Texture2D:
	if key_type == null:
		return null
	var texture_asset_id := String(key_type.get("texture_asset_id"))
	if texture_asset_id.is_empty():
		texture_asset_id = KEY_RULES.key_texture_asset_id(get_key_id())
	if texture_asset_id.is_empty():
		return null
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return null
	return assets.load_asset(texture_asset_id) as Texture2D


func _update_motion(delta: float) -> void:
	_velocity.y -= launch_gravity * delta
	global_position += _velocity * delta
	if global_position.y > ground_y:
		return

	global_position.y = ground_y
	_bounce_count += 1
	_play_bounce_sound()
	if _bounce_count >= collectable_after_bounces and lifetime_ticks > LIFETIME_DECORATIVE:
		_collectable = true

	var horizontal := Vector3(_velocity.x, 0.0, _velocity.z) * horizontal_bounce_damping
	var next_vertical := absf(_velocity.y) * bounce_damping
	if next_vertical < min_bounce_velocity:
		next_vertical = 0.0
	if horizontal.length() < min_horizontal_velocity:
		horizontal = Vector3.ZERO
	_velocity = horizontal + Vector3.UP * next_vertical
	if _velocity == Vector3.ZERO:
		_motion_active = false
		_settle_if_ready()


func _update_trail_effect(delta: float) -> void:
	if not trail_effect_enabled or _expired or _collected:
		return
	_trail_emit_remaining_ticks -= delta * ACKNEX_TIME_UNITS_PER_SECOND
	if _trail_emit_remaining_ticks > 0.0:
		return
	_trail_emit_remaining_ticks = maxf(trail_emit_interval_ticks, 1.0)
	var effect := _ensure_particle_effect()
	if effect != null and effect.has_method("emit_trail"):
		effect.call("emit_trail", get_key_id(), _particle_origin(effect), 3)


func _settle_if_ready() -> void:
	if lifetime_ticks == LIFETIME_DECORATIVE:
		_expire()
		return
	if _bounce_count >= collectable_after_bounces or collectable_after_bounces == 0:
		_collectable = true


func _update_lifetime(delta: float) -> void:
	if _motion_active or _collected or _expired:
		return
	if lifetime_ticks <= LIFETIME_DECORATIVE or is_persistent_lifetime():
		return
	_lifetime_remaining_ticks -= delta * ACKNEX_TIME_UNITS_PER_SECOND
	_update_blink()
	if _lifetime_remaining_ticks <= 0.0:
		_expire()


func _update_blink() -> void:
	if _visual_sprite == null:
		return
	var phase := int(floorf(_lifetime_remaining_ticks)) % 18
	var large := phase < 9
	var target_scale := 1.5 if large else 0.75
	if not is_equal_approx(_visual_sprite.scale.x, target_scale):
		_visual_sprite.scale = Vector3.ONE * target_scale
		_play_sfx(blink_sound_asset_id)


func _update_idle_animation(delta: float) -> void:
	if _visual_sprite == null or _visual_sprite.hframes <= 1:
		return
	_visual_frame_accumulator += maxf(visual_frames_per_second, 0.0) * delta
	var whole_frames := int(floorf(_visual_frame_accumulator))
	if whole_frames <= 0:
		return
	_visual_frame_accumulator -= float(whole_frames)
	_visual_sprite.frame = (_visual_sprite.frame + whole_frames) % _visual_sprite.hframes


func _update_collection_shrink(delta: float) -> void:
	if _visual_sprite == null:
		_is_shrinking = false
		visible = false
		return
	var shrink_factor := pow(0.8, ACKNEX_TIME_UNITS_PER_SECOND * delta)
	_visual_sprite.scale *= shrink_factor
	if _visual_sprite.scale.x <= 0.05:
		_visual_sprite.visible = false
		_is_shrinking = false
		visible = false


func _expire() -> void:
	if _expired:
		return
	_emit_expire_effect()
	_expired = true
	_collectable = false
	_motion_active = false
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_play_sfx(expire_sound_asset_id)


func _emit_spawn_effect_once() -> void:
	if _spawn_effect_emitted or not spawn_effect_enabled:
		return
	if key_type == null:
		return
	_spawn_effect_emitted = true
	var effect := _ensure_particle_effect()
	if effect != null and effect.has_method("emit_spawn_burst"):
		effect.call("emit_spawn_burst", get_key_id(), _particle_origin(effect), 8)


func _emit_collect_effect() -> void:
	if not collect_effect_enabled:
		return
	var effect := _ensure_particle_effect()
	if effect != null and effect.has_method("emit_collect_burst"):
		effect.call("emit_collect_burst", get_key_id(), _particle_origin(effect), 15)


func _emit_expire_effect() -> void:
	if not expire_effect_enabled:
		return
	var effect := _ensure_particle_effect()
	if effect != null and effect.has_method("emit_explosion"):
		effect.call("emit_explosion", get_key_id(), _particle_origin(effect), 10)


func _ensure_particle_effect() -> Node:
	if _particle_effect != null and is_instance_valid(_particle_effect):
		return _particle_effect
	var parent := get_parent()
	if parent == null:
		return null
	var effect := GEM_PARTICLE_EFFECT_SCRIPT.new()
	effect.name = "GemParticleEffect"
	effect.set("auto_free_when_empty", true)
	parent.add_child(effect)
	_particle_effect = effect
	return _particle_effect


func _particle_origin(effect: Node) -> Vector3:
	var node_3d := effect as Node3D
	if node_3d == null:
		return global_position
	return node_3d.to_local(global_position)


func _play_bounce_sound() -> void:
	if bounce_sound_asset_ids.is_empty():
		return
	var index := mini(maxi(_bounce_count - 1, 0), bounce_sound_asset_ids.size() - 1)
	_play_sfx(bounce_sound_asset_ids[index])


func _play_sfx(asset_id: String) -> void:
	if asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", asset_id)
