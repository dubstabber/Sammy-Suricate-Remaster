extends Node3D
class_name TileDeathParticles

const ACKNEX_TICKS_PER_SECOND := 16.0
const DEFAULT_SMOKE_TEXTURES: Array[String] = [
	"texture.particle.tile_death_fumee_b1",
	"texture.particle.tile_death_fumee_b3",
	"texture.particle.tile_death_fumee_b5",
	"texture.particle.tile_death_fumee3",
	"texture.particle.tile_death_fumee5",
	"texture.particle.tile_death_fumee6",
	"texture.particle.tile_death_fumee7",
	"texture.particle.tile_death_fumee8",
	"texture.particle.tile_death_fumee9",
]
const FRAME_TICKS: Array[float] = [0.0, 4.0, 6.0, 7.0, 10.0, 12.0, 15.0, 17.0, 19.0]

@export var smoke_texture_asset_ids: Array[String] = DEFAULT_SMOKE_TEXTURES.duplicate()
@export var idle_enabled: bool = true
@export var idle_emit_interval_seconds: float = 2.0 / ACKNEX_TICKS_PER_SECOND
@export var particle_pixel_size: float = 0.012
@export var auto_free_when_empty: bool = false

var _textures: Array[Texture2D] = []
var _idle_emit_remaining := 0.0
var _particles: Array[Dictionary] = []


func _ready() -> void:
	_load_textures()
	_idle_emit_remaining = maxf(idle_emit_interval_seconds, 0.0)


func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if idle_enabled and not _textures.is_empty():
		_idle_emit_remaining -= safe_delta
		while _idle_emit_remaining <= 0.0:
			_emit_particle(Vector3.ZERO)
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
		_emit_particle(origin)


func get_live_particle_count() -> int:
	return _particles.size()


func get_configured_texture_count() -> int:
	return _textures.size()


func _load_textures() -> void:
	_textures.clear()
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	for asset_id in smoke_texture_asset_ids:
		var texture := assets.load_asset(asset_id) as Texture2D
		if texture != null:
			_textures.append(texture)


func _emit_particle(origin: Vector3) -> void:
	if _textures.is_empty():
		return
	var sprite := Sprite3D.new()
	sprite.name = "TileDeathSmoke"
	sprite.texture = _textures[0]
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = particle_pixel_size
	sprite.position = origin
	sprite.scale = Vector3.ONE * randf_range(0.55, 1.2)
	add_child(sprite)

	_particles.append({
		"sprite": sprite,
		"velocity": Vector3(
				randf_range(-0.32, 0.32),
				randf_range(0.03, 0.13),
				randf_range(-0.32, 0.32)
		),
		"age": 0.0,
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
		var age_ticks := age * ACKNEX_TICKS_PER_SECOND
		if age_ticks >= 22.0:
			sprite.queue_free()
			_particles.remove_at(index)
			continue

		var texture_index := _texture_index_for_age_ticks(age_ticks)
		sprite.texture = _textures[mini(texture_index, _textures.size() - 1)]

		var velocity := particle["velocity"] as Vector3
		velocity.x *= pow(0.9, ACKNEX_TICKS_PER_SECOND * delta)
		velocity.z *= pow(0.9, ACKNEX_TICKS_PER_SECOND * delta)
		velocity.y += 0.01 * ACKNEX_TICKS_PER_SECOND * delta
		sprite.position += velocity * delta

		var grow_target := 1.65
		sprite.scale = sprite.scale.move_toward(Vector3.ONE * grow_target, delta * 0.8)
		sprite.modulate.a = clampf(1.0 - (age_ticks / 22.0), 0.0, 1.0)

		particle["age"] = age
		particle["velocity"] = velocity
		_particles[index] = particle


func _texture_index_for_age_ticks(age_ticks: float) -> int:
	var texture_index := 0
	for index in FRAME_TICKS.size():
		if age_ticks >= FRAME_TICKS[index]:
			texture_index = index
	return texture_index
