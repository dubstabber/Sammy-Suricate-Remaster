extends Node3D
class_name GemParticleEffect

const KEY_RULES := preload("res://src/resources/key_diamond_rules.gd")
const ACKNEX_TICKS_PER_SECOND := 16.0
const STAR_LIFETIME_SECONDS := 10.0 / ACKNEX_TICKS_PER_SECOND
const FRAGMENT_LIFETIME_SECONDS := 30.0 / ACKNEX_TICKS_PER_SECOND

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

@export var particle_pixel_size: float = 0.01
@export var auto_free_when_empty: bool = false

var _texture_cache: Dictionary = {}
var _particles: Array[Dictionary] = []


func _process(delta: float) -> void:
	_update_particles(maxf(delta, 0.0))
	if auto_free_when_empty and _particles.is_empty():
		queue_free()


func emit_spawn_burst(key_id: int, origin: Vector3, count: int = 8) -> void:
	_emit_star_burst(key_id, origin, count, 0.24, 0.06, 0.22, 0.85, 1.35)


func emit_trail(key_id: int, origin: Vector3, count: int = 3) -> void:
	_emit_star_burst(key_id, origin, count, 0.18, -0.04, 0.04, 0.55, 0.95)


func emit_collect_burst(key_id: int, origin: Vector3, count: int = 15) -> void:
	_emit_star_burst(key_id, origin, count, 0.32, 0.05, 0.24, 0.9, 1.85)


func emit_explosion(key_id: int, origin: Vector3, count: int = 10) -> void:
	var texture := _load_texture(_fragment_texture_asset_id(key_id))
	if texture == null:
		_emit_star_burst(key_id, origin, count, 0.36, 0.08, 0.32, 1.0, 2.0)
		return
	for _index in maxi(count, 0):
		_emit_particle(
				texture,
				origin,
				Vector3(
						randf_range(-0.55, 0.55),
						randf_range(0.18, 0.85),
						randf_range(-0.55, 0.55)
				),
				FRAGMENT_LIFETIME_SECONDS,
				randf_range(1.15, 2.6),
				Vector3.DOWN * 3.6,
				"GemFragment"
		)


func get_live_particle_count() -> int:
	return _particles.size()


func get_configured_star_texture_count(key_id: int) -> int:
	return _star_textures(key_id).size()


func get_configured_fragment_texture_count() -> int:
	return GEM_FRAGMENT_TEXTURES.size()


func _emit_star_burst(key_id: int, origin: Vector3, count: int, horizontal_range: float, vertical_min: float, vertical_max: float, scale_min: float, scale_max: float) -> void:
	var textures := _star_textures(key_id)
	if textures.is_empty():
		return
	for _index in maxi(count, 0):
		var texture := textures[randi_range(0, textures.size() - 1)]
		_emit_particle(
				texture,
				origin,
				Vector3(
						randf_range(-horizontal_range, horizontal_range),
						randf_range(vertical_min, vertical_max),
						randf_range(-horizontal_range, horizontal_range)
				),
				STAR_LIFETIME_SECONDS,
				randf_range(scale_min, scale_max),
				Vector3.ZERO,
				"GemStar"
		)


func _emit_particle(texture: Texture2D, origin: Vector3, velocity: Vector3, lifetime: float, start_scale: float, acceleration: Vector3, sprite_name: String) -> void:
	if texture == null:
		return
	var sprite := Sprite3D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = particle_pixel_size
	sprite.position = origin
	sprite.scale = Vector3.ONE * start_scale
	add_child(sprite)
	_particles.append({
		"sprite": sprite,
		"velocity": velocity,
		"acceleration": acceleration,
		"age": 0.0,
		"lifetime": maxf(lifetime, 0.001),
		"start_scale": start_scale,
	})


func _update_particles(delta: float) -> void:
	if delta <= 0.0:
		return
	for index in range(_particles.size() - 1, -1, -1):
		var particle := _particles[index]
		var sprite := particle["sprite"] as Sprite3D
		if sprite == null or not is_instance_valid(sprite):
			_particles.remove_at(index)
			continue
		var age := float(particle["age"]) + delta
		var lifetime := float(particle["lifetime"])
		if age >= lifetime:
			sprite.queue_free()
			_particles.remove_at(index)
			continue
		var velocity := particle["velocity"] as Vector3
		velocity += (particle["acceleration"] as Vector3) * delta
		sprite.position += velocity * delta
		var remaining_ratio := clampf(1.0 - age / lifetime, 0.0, 1.0)
		var start_scale := float(particle["start_scale"])
		sprite.scale = Vector3.ONE * maxf(start_scale * remaining_ratio, 0.08)
		sprite.modulate.a = remaining_ratio
		particle["age"] = age
		particle["velocity"] = velocity
		_particles[index] = particle


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
