extends WaspPickup
class_name LaunchedWaspPickup

const HIVE_TIME_UNITS_PER_SECOND := 16.0
const LIFETIME_DECORATIVE := 0.0
const LIFETIME_STAY := 1000.0
const BOUNCE_SOUND_WDL_RANGE_UNITS := 100.0

@export var lifetime_ticks: float = LIFETIME_STAY
@export var ground_y: float = 0.0
@export var launch_gravity: float = 4.0
@export var bounce_damping: float = 0.55
@export var horizontal_bounce_damping: float = 0.72
@export var min_bounce_velocity: float = 0.12
@export var min_horizontal_velocity: float = 0.04
@export var collectable_after_bounces: int = 1
@export var fade_last_ticks: float = 16.0
@export var bounce_sound_asset_id: String = "sfx.wasp_kaput"

var _expired := false
var _collectable := false
var _motion_active := false
var _velocity := Vector3.ZERO
var _bounce_count := 0
var _lifetime_remaining_ticks := 0.0
var _source: Node = null
var _visual_alpha_ratio := 1.0


func _ready() -> void:
	super._ready()
	_lifetime_remaining_ticks = lifetime_ticks
	if _velocity == Vector3.ZERO and not _collectable:
		_settle_if_ready()


func _physics_process(delta: float) -> void:
	if _expired or was_collected() or not _motion_active:
		return
	_update_motion(maxf(delta, 0.0))


func _process(delta: float) -> void:
	if _expired:
		return
	super._process(delta)
	if not was_collected():
		_update_lifetime(maxf(delta, 0.0))


func configure_launch(
	new_wasp_type: Resource,
	new_ammo_amount: int,
	new_lifetime_ticks: float,
	launch_velocity: Vector3,
	new_collectable_after_bounces: int,
	launch_source: Node = null
) -> bool:
	if new_wasp_type == null:
		return false

	wasp_type = new_wasp_type
	ammo_amount = maxi(new_ammo_amount, 1)
	lifetime_ticks = maxf(new_lifetime_ticks, 0.0)
	_lifetime_remaining_ticks = lifetime_ticks
	_velocity = launch_velocity
	_source = launch_source
	collectable_after_bounces = maxi(new_collectable_after_bounces, 0)
	_bounce_count = 0
	_expired = false
	_collectable = false
	_motion_active = _velocity.length() > 0.001 or global_position.y > ground_y
	_visual_alpha_ratio = 1.0
	visible = true
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	_refresh_configured_visual()
	if collectable_after_bounces == 0:
		_collectable = lifetime_ticks > LIFETIME_DECORATIVE
	if not _motion_active:
		_settle_if_ready()
	return true


func collect(player: Node) -> bool:
	return _collect_from(player)


func is_collectable() -> bool:
	return _collectable and not _expired and not was_collected()


func is_expired() -> bool:
	return _expired


func is_persistent_lifetime() -> bool:
	return lifetime_ticks >= LIFETIME_STAY


func get_bounce_count() -> int:
	return _bounce_count


func get_velocity() -> Vector3:
	return _velocity


func get_lifetime_remaining_ticks() -> float:
	return _lifetime_remaining_ticks


func get_source() -> Node:
	return _source


func get_visual_alpha_ratio() -> float:
	return _visual_alpha_ratio


func _on_body_entered(body: Node3D) -> void:
	_collect_from(body)


func _collect_from(player: Node) -> bool:
	if not is_collectable():
		return false
	var collected := super._collect_from(player)
	if collected:
		_motion_active = false
	return collected


func _update_motion(delta: float) -> void:
	_velocity.y -= launch_gravity * delta
	global_position += _velocity * delta
	if global_position.y > ground_y:
		return

	global_position.y = ground_y
	_bounce_count += 1
	if _bounce_count >= collectable_after_bounces and lifetime_ticks > LIFETIME_DECORATIVE:
		_collectable = true
	_play_bounce_sound()

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


func _settle_if_ready() -> void:
	if lifetime_ticks == LIFETIME_DECORATIVE:
		_expire()
		return
	if _bounce_count >= collectable_after_bounces or collectable_after_bounces == 0:
		_collectable = true


func _update_lifetime(delta: float) -> void:
	if _motion_active or _expired or is_persistent_lifetime():
		return
	if lifetime_ticks <= LIFETIME_DECORATIVE:
		_expire()
		return

	_lifetime_remaining_ticks -= delta * HIVE_TIME_UNITS_PER_SECOND
	_update_lifetime_fade()
	if _lifetime_remaining_ticks <= 0.0:
		_expire()


func _update_lifetime_fade() -> void:
	if fade_last_ticks <= 0.0:
		return
	var alpha := clampf(_lifetime_remaining_ticks / fade_last_ticks, 0.0, 1.0)
	_set_visual_alpha_ratio(alpha)


func _set_visual_alpha_ratio(alpha: float) -> void:
	_visual_alpha_ratio = clampf(alpha, 0.0, 1.0)
	if _model_instance == null:
		return
	_apply_visual_alpha(_model_instance, _visual_alpha_ratio)


func _apply_visual_alpha(node: Node, alpha: float) -> void:
	var geometry := node as GeometryInstance3D
	if geometry != null:
		geometry.transparency = 1.0 - alpha
	var sprite := node as Sprite3D
	if sprite != null:
		var color := sprite.modulate
		color.a = alpha
		sprite.modulate = color
	for child in node.get_children():
		_apply_visual_alpha(child, alpha)


func _expire() -> void:
	if _expired:
		return
	_expired = true
	_collectable = false
	_motion_active = false
	visible = false
	monitoring = false
	monitorable = false
	_set_visual_alpha_ratio(0.0)


func _refresh_configured_visual() -> void:
	if _model_instance == null:
		if is_inside_tree():
			_spawn_model()
		return
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	_apply_wasp_skin(assets)
	_lift_model_above_ground(assets)
	_set_visual_alpha_ratio(1.0)


func _play_bounce_sound() -> void:
	if bounce_sound_asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_spatial_sfx"):
		audio.call("play_spatial_sfx", bounce_sound_asset_id, self, BOUNCE_SOUND_WDL_RANGE_UNITS)
	elif audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", bounce_sound_asset_id)
