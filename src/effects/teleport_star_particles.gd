extends Node3D
class_name TeleportStarParticles

const DEFAULT_STAR_TEXTURES: Array[String] = [
	"texture.particle.teleport_star_1",
	"texture.particle.teleport_star_2",
	"texture.particle.teleport_star_3",
	"texture.particle.teleport_star_4",
	"texture.particle.teleport_star_5",
]
const ACKNEX_TICKS_PER_SECOND := 16.0
const WdlParticlesScript := preload("res://src/effects/wdl_particles.gd")
# particul.wdl: the star dies once My_Size has decayed to 100.
const MIN_WDL_SIZE := 100.0

@export var star_texture_asset_ids: Array[String] = DEFAULT_STAR_TEXTURES.duplicate()
@export var idle_enabled: bool = true
## mm1.wdl InitTeleport: `If (ticks1 % 4 == 0) emit; waitt 1;`
@export var idle_emit_interval_seconds: float = AcknexEngineTiming.ticks1_emit_interval(4, 1.0)
@export var auto_free_when_empty: bool = false

var _textures: Array[Texture2D] = []
var _idle_emit_remaining := 0.0
var _particles: Array[Dictionary] = []


func _ready() -> void:
	_load_textures()
	_idle_emit_remaining = maxf(idle_emit_interval_seconds, 0.0)


func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if idle_enabled and _textures.size() > 0:
		_idle_emit_remaining -= safe_delta
		while _idle_emit_remaining <= 0.0:
			_emit_particle(Vector3.ZERO, true)
			_idle_emit_remaining += maxf(idle_emit_interval_seconds, 0.001)
	_update_particles(safe_delta)
	if auto_free_when_empty and not idle_enabled and _particles.is_empty():
		queue_free()


func set_idle_enabled(enabled: bool) -> void:
	idle_enabled = enabled


func is_idle_enabled() -> bool:
	return idle_enabled


func emit_burst(count: int, origin: Vector3 = Vector3.ZERO) -> void:
	for _index in maxi(count, 0):
		_emit_particle(origin, false)


func get_live_particle_count() -> int:
	return _particles.size()


func get_configured_texture_count() -> int:
	return _textures.size()


func _load_textures() -> void:
	_textures.clear()
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	for asset_id in star_texture_asset_ids:
		var texture := assets.load_asset(asset_id) as Texture2D
		if texture != null:
			_textures.append(texture)


## particul.wdl particle_Teleport (idle, emitted by InitTeleport) and
## particle_Teleport2 (player teleport transition).
func _emit_particle(origin: Vector3, idle_particle: bool) -> void:
	if _textures.is_empty():
		return
	var sprite := WdlParticlesScript.make_sprite("TeleportStar", _textures[0], true)
	sprite.position = origin
	add_child(sprite)
	var spread := 64.0 if idle_particle else 32.0
	var size := WdlParticlesScript.wdl_random(1500.0) + (1500.0 if idle_particle else 1000.0)
	WdlParticlesScript.set_sprite_size(sprite, size)
	_particles.append({
		"sprite": sprite,
		"velocity": WdlParticlesScript.velocity(
				WdlParticlesScript.wdl_random(spread) - spread * 0.5,
				WdlParticlesScript.wdl_random(spread) - spread * 0.5,
				WdlParticlesScript.wdl_random(10.0 if idle_particle else 5.0) + 3.0
		),
		"age_ticks": 0.0,
		"size": size,
		"map_interval_ticks": 5.0 if idle_particle else 6.0,
		"damping": 0.9 if idle_particle else 0.85,
		"lift": WdlParticlesScript.acceleration(1.2 if idle_particle else 1.1),
		"max_age_ticks": 20.0 if idle_particle else 16.0,
	})


func _update_particles(delta: float) -> void:
	if delta <= 0.0:
		return
	var ticks := delta * ACKNEX_TICKS_PER_SECOND
	for index in range(_particles.size() - 1, -1, -1):
		var particle := _particles[index]
		var sprite := particle["sprite"] as Sprite3D
		if sprite == null or not is_instance_valid(sprite):
			_particles.remove_at(index)
			continue
		var age_ticks := float(particle["age_ticks"])
		var size := float(particle["size"])
		if age_ticks >= float(particle["max_age_ticks"]) or size <= MIN_WDL_SIZE:
			sprite.queue_free()
			_particles.remove_at(index)
			continue
		# `IF (Int(MY_AGE) % 5 == 0)` re-picks StarHit1-5 on every frame of
		# every fifth (sixth) tick, so the stars flicker through their bitmaps.
		if int(age_ticks) % int(particle["map_interval_ticks"]) == 0:
			WdlParticlesScript.set_sprite_texture(sprite, _textures[randi_range(0, _textures.size() - 1)], true)
		var velocity := particle["velocity"] as Vector3
		var damping := WdlParticlesScript.frame_damping(float(particle["damping"]), delta)
		velocity.x *= damping
		velocity.z *= damping
		velocity.y += float(particle["lift"]) * delta
		sprite.position += velocity * delta
		# My_Size += (100 - My_Size) * 0.1 * time
		size = MIN_WDL_SIZE + (size - MIN_WDL_SIZE) * pow(0.9, ticks)
		WdlParticlesScript.set_sprite_size(sprite, size)
		particle["age_ticks"] = age_ticks + ticks
		particle["size"] = size
		particle["velocity"] = velocity
		_particles[index] = particle
