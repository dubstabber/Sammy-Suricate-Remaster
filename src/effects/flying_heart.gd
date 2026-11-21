extends Node3D
class_name FlyingHeart

## player.wdl Animmoins1life / FlyingHearth: when Sammy loses a life a lifeA
## heart (x0.7) flies from him back towards the camera (InvDirCamera) tilted
## up 22 degrees (+-2 random), 15 quants per tick for DureeFlying =
## (camera distance / 20) * 4 ticks, spinning 30 degrees per tick and emitting
## one particle_life heart per tick. SonduCoeurAway plays Heart_Away 2 ticks in.

const WdlParticlesScript := preload("res://src/effects/wdl_particles.gd")

const SPEED_UNITS_PER_TICK := 15.0
const TILT_DEGREES := 22.0
const RANDOM_ANGLE_RANGE := 4.0
const SPIN_DEGREES_PER_TICK := 30.0
const MODEL_SCALE := 0.7
const SOUND_DELAY_TICKS := 2.0
const SOUND_ASSET_ID := "sfx.player"
const SOUND_WDL_RANGE_UNITS := 2000.0
const MODEL_ASSET_ID := "model.life_heart"
const TICKS_PER_SECOND := 16.0
const QUANT := 0.01
## particul.wdl particle_life: speed (random(4)-2, random(4)-2, -8), size
## random(500)+500, PartHearth frames by age, gone at age 10.
const PARTICLE_LIFETIME_TICKS := 10.0
const PARTICLE_FALL_SPEED := -8.0
const PARTICLE_SIZE_BASE := 500.0
const PARTICLE_SIZE_RANDOM := 500.0
const PARTICLE_FRAMES_BY_AGE := [1, 1, 2, 3, 4, 5, 6, 7, 4, 1]

var _velocity := Vector3.ZERO
var _remaining_ticks := 0.0
var _elapsed_ticks := 0.0
var _emit_accumulator := 0.0
var _sound_played := false
var _flying := true
var _particles: Array[Dictionary] = []
var _particle_textures: Array[Texture2D] = []
var _model: Node3D = null


## `toward_camera` is the horizontal direction from Sammy to the camera.
func launch(toward_camera: Vector3, camera_distance_units: float) -> void:
	var flat := Vector3(toward_camera.x, 0.0, toward_camera.z)
	if flat.length_squared() <= 0.0001:
		flat = Vector3.BACK
	var random_offset := WdlParticlesScript.wdl_random(RANDOM_ANGLE_RANGE) - RANDOM_ANGLE_RANGE * 0.5
	var direction := flat.normalized().rotated(Vector3.UP, deg_to_rad(random_offset))
	var tilt := deg_to_rad(TILT_DEGREES + random_offset)
	direction = (direction * cos(tilt) + Vector3.UP * sin(tilt)).normalized()
	_velocity = direction * WdlParticlesScript.speed(SPEED_UNITS_PER_TICK)
	_remaining_ticks = maxf(camera_distance_units / 20.0 * 4.0, 0.0)


func get_flight_ticks() -> float:
	return _remaining_ticks


func get_velocity() -> Vector3:
	return _velocity


func get_live_particle_count() -> int:
	return _particles.size()


func _ready() -> void:
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	var scene := assets.load_asset(MODEL_ASSET_ID) as PackedScene
	if scene != null:
		_model = scene.instantiate() as Node3D
		_model.scale = assets.get_model_scale(MODEL_ASSET_ID) * MODEL_SCALE
		add_child(_model)
	for frame in range(1, 8):
		_particle_textures.append(assets.load_asset("texture.particle.heart_%d" % frame) as Texture2D)


func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	var ticks := safe_delta * TICKS_PER_SECOND
	_elapsed_ticks += ticks
	if not _sound_played and _elapsed_ticks >= SOUND_DELAY_TICKS:
		_sound_played = true
		var audio := get_node_or_null("/root/Audio")
		if audio != null and audio.has_method("play_spatial_sfx"):
			audio.call("play_spatial_sfx", SOUND_ASSET_ID, self, SOUND_WDL_RANGE_UNITS)
	if _flying:
		global_position += _velocity * safe_delta
		rotate_y(deg_to_rad(SPIN_DEGREES_PER_TICK * ticks))
		_remaining_ticks -= ticks
		_emit_accumulator += ticks
		while _emit_accumulator >= 1.0:
			_emit_accumulator -= 1.0
			_emit_particle()
		if _remaining_ticks <= 0.0:
			_flying = false
			if _model != null:
				_model.visible = false
	_update_particles(safe_delta)
	if not _flying and _particles.is_empty() and _sound_played:
		queue_free()


func _emit_particle() -> void:
	if _particle_textures.is_empty() or _particle_textures[0] == null:
		return
	var sprite := WdlParticlesScript.make_sprite("LifeParticle", _particle_textures[0], true)
	var size := PARTICLE_SIZE_BASE + WdlParticlesScript.wdl_random(PARTICLE_SIZE_RANDOM)
	WdlParticlesScript.set_sprite_size(sprite, size)
	get_parent().add_child(sprite)
	sprite.global_position = global_position
	_particles.append({
		"sprite": sprite,
		"age": 0.0,
		"velocity": WdlParticlesScript.velocity(
				WdlParticlesScript.wdl_random(4.0) - 2.0,
				WdlParticlesScript.wdl_random(4.0) - 2.0,
				PARTICLE_FALL_SPEED),
	})


func _update_particles(delta: float) -> void:
	var ticks := delta * TICKS_PER_SECOND
	for index in range(_particles.size() - 1, -1, -1):
		var particle := _particles[index]
		var sprite := particle["sprite"] as Sprite3D
		var age := float(particle["age"]) + ticks
		if sprite == null or not is_instance_valid(sprite) or age >= PARTICLE_LIFETIME_TICKS:
			if sprite != null and is_instance_valid(sprite):
				sprite.queue_free()
			_particles.remove_at(index)
			continue
		particle["age"] = age
		sprite.global_position += (particle["velocity"] as Vector3) * delta
		var frame: int = PARTICLE_FRAMES_BY_AGE[clampi(int(age), 0, PARTICLE_FRAMES_BY_AGE.size() - 1)]
		var texture := _particle_textures[frame - 1]
		if texture != null and sprite.texture != texture:
			WdlParticlesScript.set_sprite_texture(sprite, texture, true)


func _exit_tree() -> void:
	for particle in _particles:
		var sprite := particle["sprite"] as Sprite3D
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_particles.clear()
