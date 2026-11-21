extends Node3D
class_name GemParticleEffect

## Key-gem particles ported from particul.wdl / gems.wdl (all `My_Flare`):
## - trail / spawn: Particle_GemKeys -> particle_<colour>Bmp stars
## - collect: GemCatch -> particle_GemCatch<colour> (waves of 5, 10, 10)
## - expire: GemExplose -> particle_GemExplose<colour> fragments

const KEY_RULES := preload("res://src/resources/key_diamond_rules.gd")
const WdlParticlesScript := preload("res://src/effects/wdl_particles.gd")

const STAR_LIFE_TICKS := 10.0
const CATCH_LIFE_TICKS := 30.0
const EXPLOSION_LIFE_TICKS := 30.0
## skills.wdl TaillePartGems.
const STAR_BASE_SIZE := 750.0
## gems.wdl GemExplose: Set SizePartExplo,2000.
const EXPLOSION_BASE_SIZE := 2000.0
const CATCH_MIN_SIZE := 100.0
const CATCH_SIZE_DECAY_PER_TICK := 50.0
## GemCatch: Emit 5, waitt 2, Emit 10, waitt 4, Emit 10.
const CATCH_WAVES := [[0.0, 5], [2.0, 10], [6.0, 10]]
## GemExplose emits averageFps * 0.3 fragments; the engine runs at fps_max 70.
const EXPLOSION_COUNT := 21

const GEM_STAR_TEXTURES := {
	KEY_RULES.KEY_RED: ["texture.particle.gem_star_1a", "texture.particle.gem_star_1b"],
	KEY_RULES.KEY_YELLOW: ["texture.particle.gem_star_2a", "texture.particle.gem_star_2b"],
	KEY_RULES.KEY_ORANGE: ["texture.particle.gem_star_3a", "texture.particle.gem_star_3b"],
	KEY_RULES.KEY_BLUE: ["texture.particle.gem_star_4a", "texture.particle.gem_star_4b"],
	KEY_RULES.KEY_MAGENTA: ["texture.particle.gem_star_5a", "texture.particle.gem_star_5b"],
	KEY_RULES.KEY_GREEN: ["texture.particle.gem_star_6a", "texture.particle.gem_star_6b"],
}

const GEM_FRAGMENT_TEXTURES := {
	KEY_RULES.KEY_RED: "texture.particle.gem_fragment_1",
	KEY_RULES.KEY_YELLOW: "texture.particle.gem_fragment_2",
	KEY_RULES.KEY_ORANGE: "texture.particle.gem_fragment_3",
	KEY_RULES.KEY_BLUE: "texture.particle.gem_fragment_4",
	KEY_RULES.KEY_MAGENTA: "texture.particle.gem_fragment_5",
	KEY_RULES.KEY_GREEN: "texture.particle.gem_fragment_6",
}

@export var auto_free_when_empty: bool = false

var _texture_cache: Dictionary = {}
var _particles: Array[Dictionary] = []
var _pending_waves: Array[Dictionary] = []


func _process(delta: float) -> void:
	var ticks := maxf(delta, 0.0) * WdlParticlesScript.TICKS_PER_SECOND
	_update_pending_waves(ticks)
	_update_particles(delta, ticks)
	if auto_free_when_empty and _particles.is_empty() and _pending_waves.is_empty():
		queue_free()


func emit_spawn_burst(key_id: int, origin: Vector3, count: int = 8) -> void:
	_emit_stars(key_id, origin, count)


## Particle_GemKeys (AverageFps > 35): 3 star bitmaps every 3 ticks.
func emit_trail(key_id: int, origin: Vector3, count: int = 3) -> void:
	_emit_stars(key_id, origin, count)


## GemCatch: `count` scales the original 5 + 10 + 10 waves (25 = original).
func emit_collect_burst(key_id: int, origin: Vector3, count: int = 25) -> void:
	var spread := WdlParticlesScript.wdl_random(2.0) + 1.0
	var scale := float(maxi(count, 0)) / 25.0
	for wave: Array in CATCH_WAVES:
		var wave_count := roundi(float(wave[1]) * scale)
		if wave_count <= 0:
			continue
		if float(wave[0]) <= 0.0:
			_emit_catch_wave(key_id, origin, wave_count, spread)
		else:
			_pending_waves.append({"key_id": key_id, "origin": origin, "count": wave_count, "spread": spread, "delay": float(wave[0])})


func emit_explosion(key_id: int, origin: Vector3, count: int = EXPLOSION_COUNT) -> void:
	var texture := _load_texture(_fragment_texture_asset_id(key_id))
	if texture == null:
		return
	var spread := WdlParticlesScript.wdl_random(5.0) + 5.0
	for _index in maxi(count, 0):
		_emit_particle(texture, origin, {
			"velocity": WdlParticlesScript.velocity(
					spread * (WdlParticlesScript.wdl_random(6.0) - 3.0),
					spread * (WdlParticlesScript.wdl_random(6.0) - 3.0),
					spread + WdlParticlesScript.wdl_random(30.0)),
			"gravity": WdlParticlesScript.acceleration(4.0),
			"size": WdlParticlesScript.wdl_random(200.0) + EXPLOSION_BASE_SIZE,
			"life": EXPLOSION_LIFE_TICKS,
		}, "GemFragment")


func get_live_particle_count() -> int:
	return _particles.size()


func get_configured_star_texture_count(key_id: int) -> int:
	return _star_textures(key_id).size()


func get_configured_fragment_texture_count() -> int:
	return GEM_FRAGMENT_TEXTURES.size()


## particle_<colour>Bmp: +-3 quants/tick sideways, falling 3-4 quants/tick.
func _emit_stars(key_id: int, origin: Vector3, count: int) -> void:
	var textures := _star_textures(key_id)
	if textures.is_empty():
		return
	for _index in maxi(count, 0):
		_emit_particle(textures[randi_range(0, textures.size() - 1)], origin, {
			"velocity": WdlParticlesScript.velocity(
					WdlParticlesScript.wdl_random(6.0) - 3.0,
					WdlParticlesScript.wdl_random(6.0) - 3.0,
					WdlParticlesScript.wdl_random(1.0) - 4.0),
			"size": WdlParticlesScript.wdl_random(300.0) + STAR_BASE_SIZE,
			"life": STAR_LIFE_TICKS,
		}, "GemStar")


## particle_GemCatch<colour>: a fountain rising V4 + random(20) quants/tick.
func _emit_catch_wave(key_id: int, origin: Vector3, count: int, spread: float) -> void:
	var textures := _star_textures(key_id)
	if textures.is_empty():
		return
	for _index in maxi(count, 0):
		_emit_particle(textures[randi_range(0, textures.size() - 1)], origin, {
			"velocity": WdlParticlesScript.velocity(
					spread * (WdlParticlesScript.wdl_random(2.0) - 1.0),
					spread * (WdlParticlesScript.wdl_random(2.0) - 1.0),
					spread + WdlParticlesScript.wdl_random(20.0)),
			"gravity": WdlParticlesScript.acceleration(1.0),
			"size": WdlParticlesScript.wdl_random(2000.0),
			"size_decay": CATCH_SIZE_DECAY_PER_TICK,
			"min_size": CATCH_MIN_SIZE,
			"life": CATCH_LIFE_TICKS,
		}, "GemStar")


func _emit_particle(texture: Texture2D, origin: Vector3, motion: Dictionary, sprite_name: String) -> void:
	if texture == null:
		return
	var sprite := WdlParticlesScript.make_sprite(sprite_name, texture, true)
	sprite.position = origin
	add_child(sprite)
	var particle := {
		"sprite": sprite,
		"velocity": motion.get("velocity", Vector3.ZERO),
		"gravity": float(motion.get("gravity", 0.0)),
		"size": float(motion.get("size", STAR_BASE_SIZE)),
		"size_decay": float(motion.get("size_decay", 0.0)),
		"min_size": float(motion.get("min_size", 0.0)),
		"age": 0.0,
		"life": float(motion.get("life", STAR_LIFE_TICKS)),
	}
	WdlParticlesScript.set_sprite_size(sprite, float(particle["size"]))
	_particles.append(particle)


func _update_pending_waves(ticks: float) -> void:
	for index in range(_pending_waves.size() - 1, -1, -1):
		var wave := _pending_waves[index]
		wave["delay"] = float(wave["delay"]) - ticks
		if float(wave["delay"]) <= 0.0:
			_pending_waves.remove_at(index)
			_emit_catch_wave(int(wave["key_id"]), wave["origin"] as Vector3, int(wave["count"]), float(wave["spread"]))


func _update_particles(delta: float, ticks: float) -> void:
	if delta <= 0.0:
		return
	for index in range(_particles.size() - 1, -1, -1):
		var particle := _particles[index]
		var sprite := particle["sprite"] as Sprite3D
		if sprite == null or not is_instance_valid(sprite):
			_particles.remove_at(index)
			continue
		var age := float(particle["age"]) + ticks
		if age >= float(particle["life"]):
			sprite.queue_free()
			_particles.remove_at(index)
			continue
		var velocity := particle["velocity"] as Vector3
		velocity.y -= float(particle["gravity"]) * delta
		sprite.position += velocity * delta
		var size_decay := float(particle["size_decay"])
		if size_decay > 0.0 and float(particle["size"]) > float(particle["min_size"]):
			particle["size"] = maxf(float(particle["size"]) - size_decay * ticks, float(particle["min_size"]))
			WdlParticlesScript.set_sprite_size(sprite, float(particle["size"]))
		particle["age"] = age
		particle["velocity"] = velocity


func _star_textures(key_id: int) -> Array[Texture2D]:
	var result: Array[Texture2D] = []
	var asset_ids: Array = GEM_STAR_TEXTURES.get(key_id, [])
	for asset_id in asset_ids:
		var texture := _load_texture(String(asset_id))
		if texture != null:
			result.append(texture)
	return result


func _fragment_texture_asset_id(key_id: int) -> String:
	return String(GEM_FRAGMENT_TEXTURES.get(key_id, ""))


func _load_texture(asset_id: String) -> Texture2D:
	if asset_id.is_empty():
		return null
	if _texture_cache.has(asset_id):
		return _texture_cache[asset_id] as Texture2D
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return null
	var texture := assets.load_asset(asset_id) as Texture2D
	if texture != null:
		_texture_cache[asset_id] = texture
	return texture
