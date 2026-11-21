extends Area3D
class_name SmallHeartPickup

const WdlParticlesScript := preload("res://src/effects/wdl_particles.gd")
const ACKNEX_TIME_UNITS_PER_SECOND := 16.0
## particul.wdl particle_SmallHeart: speed normalised to 10 quants/tick, size
## 400 + random(400) shrinking 30/tick down to 50, 12-tick life, My_Flare.
const PARTICLE_SPEED := 10.0
const PARTICLE_BASE_SIZE := 400.0
const PARTICLE_SIZE_RANDOM := 400.0
const PARTICLE_MIN_SIZE := 50.0
const PARTICLE_SIZE_DECAY_PER_TICK := 30.0
const PARTICLE_LIFE_TICKS := 12.0
const DEFAULT_FRAME_ADVANCE_PER_TIME_UNIT := 1.0
const DEFAULT_HEALTH_AMOUNT := 12.0
const DEFAULT_HEIGHT_GEM := 25.0 * 0.01
const REJECT_NONE := 0
const REJECT_SHRINK := 1
const REJECT_HIDDEN := 2
const REJECT_GROW := 3
const COLLECT_SOUND_WDL_RANGE_UNITS := 1500.0
const SECONDARY_COLLECT_SOUND_WDL_RANGE_UNITS := 500.0

@export var health_amount: float = DEFAULT_HEALTH_AMOUNT
@export var texture_asset_id: String = "texture.small_heart"
@export var collect_sound_asset_id: String = "sfx.gagne1"
@export var secondary_collect_sound_asset_id: String = "sfx.boost_pickup"
@export var particle_texture_asset_id: String = "texture.particle.heart_1"
@export var visual_frame_count: int = 11
@export var visual_frames_per_second: float = DEFAULT_FRAME_ADVANCE_PER_TIME_UNIT * ACKNEX_TIME_UNITS_PER_SECOND
@export var visual_pixel_size: float = 0.01
@export var visual_ground_clearance: float = DEFAULT_HEIGHT_GEM
@export var particle_count: int = 30
@export var reject_hidden_seconds: float = 48.0 / ACKNEX_TIME_UNITS_PER_SECOND

var _collected := false
var _visual_sprite: Sprite3D = null
var _visual_frame_accumulator := 0.0
var _is_shrinking := false
var _reject_state := REJECT_NONE
var _reject_remaining_seconds := 0.0
var _original_visual_scale := Vector3.ONE
var _particle_texture: Texture2D = null
var _particles: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("pickup")
	body_entered.connect(_on_body_entered)
	_spawn_visual()
	_load_particle_texture()


func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if not _collected and _reject_state == REJECT_NONE:
		_update_idle_animation(safe_delta)
	elif _is_shrinking:
		_update_collection_shrink(safe_delta)
	_update_reject_animation(safe_delta)
	_update_particles(safe_delta)


func collect(player: Node) -> bool:
	return _collect_from(player)


func was_collected() -> bool:
	return _collected


func get_health_amount() -> float:
	return health_amount


func get_visual_sprite() -> Sprite3D:
	return _visual_sprite


func get_visual_frame_count() -> int:
	return visual_frame_count


func get_live_particle_count() -> int:
	return _particles.size()


func is_rejecting_full_health_collection() -> bool:
	return _reject_state != REJECT_NONE


func _on_body_entered(body: Node3D) -> void:
	_collect_from(body)


func _collect_from(player: Node) -> bool:
	if _collected or _reject_state != REJECT_NONE or player == null or not player.has_method("add_health"):
		return false

	var added := float(player.call("add_health", health_amount))
	if added <= 0.0:
		if _is_player_at_full_health(player):
			_start_full_health_reject()
		return false

	_collected = true
	_is_shrinking = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_emit_heart_burst()
	_play_collect_sounds()
	return true


func _is_player_at_full_health(player: Node) -> bool:
	if player == null or not player.has_method("get_health") or not player.has_method("get_max_health"):
		return false
	var max_health := float(player.call("get_max_health"))
	return max_health > 0.0 and float(player.call("get_health")) >= max_health


func _spawn_visual() -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	var texture := assets.load_asset(texture_asset_id) as Texture2D
	if texture == null:
		return

	_visual_sprite = Sprite3D.new()
	_visual_sprite.name = "SmallHeartVisual"
	_visual_sprite.texture = texture
	_visual_sprite.hframes = maxi(visual_frame_count, 1)
	_visual_sprite.vframes = 1
	_visual_sprite.frame = randi_range(0, _visual_sprite.hframes - 1)
	_visual_sprite.pixel_size = visual_pixel_size
	_visual_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_visual_sprite.position.y = visual_ground_clearance
	add_child(_visual_sprite)
	_original_visual_scale = _visual_sprite.scale


func _load_particle_texture() -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	_particle_texture = assets.load_asset(particle_texture_asset_id) as Texture2D


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
		return
	var shrink_factor := pow(0.8, ACKNEX_TIME_UNITS_PER_SECOND * delta)
	_visual_sprite.scale *= shrink_factor
	if _visual_sprite.scale.x <= 0.1:
		_visual_sprite.visible = false
		_is_shrinking = false


func _start_full_health_reject() -> void:
	if _visual_sprite == null:
		return
	_reject_state = REJECT_SHRINK
	_reject_remaining_seconds = 0.0
	_visual_sprite.visible = true


func _update_reject_animation(delta: float) -> void:
	if _visual_sprite == null or _reject_state == REJECT_NONE:
		return
	match _reject_state:
		REJECT_SHRINK:
			_visual_sprite.scale *= pow(0.8, ACKNEX_TIME_UNITS_PER_SECOND * delta)
			if _visual_sprite.scale.x <= _original_visual_scale.x * 0.1:
				_visual_sprite.scale = _original_visual_scale * 0.1
				_visual_sprite.visible = false
				_reject_remaining_seconds = maxf(reject_hidden_seconds, 0.0)
				_reject_state = REJECT_HIDDEN
		REJECT_HIDDEN:
			_reject_remaining_seconds -= delta
			if _reject_remaining_seconds <= 0.0:
				_visual_sprite.visible = true
				_reject_state = REJECT_GROW
		REJECT_GROW:
			_visual_sprite.scale *= pow(1.5, ACKNEX_TIME_UNITS_PER_SECOND * delta)
			if _visual_sprite.scale.x >= _original_visual_scale.x:
				_visual_sprite.scale = _original_visual_scale
				_reject_state = REJECT_NONE


func _emit_heart_burst() -> void:
	if _particle_texture == null:
		return
	for _index in maxi(particle_count, 0):
		# MY_COLOR (250, 0, 0) does not tint bitmap particles; Parthearth1 is red.
		var sprite := WdlParticlesScript.make_sprite("SmallHeartParticle", _particle_texture, true)
		var size := PARTICLE_BASE_SIZE + WdlParticlesScript.wdl_random(PARTICLE_SIZE_RANDOM)
		WdlParticlesScript.set_sprite_size(sprite, size)
		add_child(sprite)
		var direction := Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
		if direction.length_squared() <= 0.0:
			direction = Vector3.UP
		_particles.append({
			"sprite": sprite,
			"velocity": direction.normalized() * WdlParticlesScript.speed(PARTICLE_SPEED),
			"size": size,
			"age": 0.0,
		})


func _update_particles(delta: float) -> void:
	if delta <= 0.0:
		return
	var ticks := delta * ACKNEX_TIME_UNITS_PER_SECOND
	for index in range(_particles.size() - 1, -1, -1):
		var particle := _particles[index]
		var sprite := particle["sprite"] as Sprite3D
		if sprite == null or not is_instance_valid(sprite):
			_particles.remove_at(index)
			continue
		var age := float(particle["age"]) + ticks
		if age >= PARTICLE_LIFE_TICKS:
			sprite.queue_free()
			_particles.remove_at(index)
			continue
		sprite.position += (particle["velocity"] as Vector3) * delta
		var size := float(particle["size"])
		if size > PARTICLE_MIN_SIZE:
			size = maxf(size - PARTICLE_SIZE_DECAY_PER_TICK * ticks, PARTICLE_MIN_SIZE)
			particle["size"] = size
			WdlParticlesScript.set_sprite_size(sprite, size)
		particle["age"] = age


func _play_collect_sounds() -> void:
	_play_sound(collect_sound_asset_id, COLLECT_SOUND_WDL_RANGE_UNITS)
	_play_sound(secondary_collect_sound_asset_id, SECONDARY_COLLECT_SOUND_WDL_RANGE_UNITS)


func _play_sound(asset_id: String, wdl_range_units: float) -> void:
	if asset_id.is_empty():
		return
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_spatial_sfx"):
		audio.call("play_spatial_sfx", asset_id, self, wdl_range_units)
	elif audio != null and audio.has_method("play_sfx"):
		audio.call("play_sfx", asset_id)
