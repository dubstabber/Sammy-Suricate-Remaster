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
const WdlParticlesScript := preload("res://src/effects/wdl_particles.gd")
const MAX_AGE_TICKS := 22.0
const MAX_WDL_SIZE := 2500.0

@export var smoke_texture_asset_ids: Array[String] = DEFAULT_SMOKE_TEXTURES.duplicate()
@export var idle_enabled: bool = true
## mm1.wdl InitTileDeath: `emit 1; waitt 2;`
@export var idle_emit_interval_seconds: float = AcknexEngineTiming.waitt_interval(2.0)
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


## particul.wdl particle_TileDeath (InitTileDeath emits one every 2 ticks).
func _emit_particle(origin: Vector3) -> void:
	if _textures.is_empty():
		return
	var sprite := WdlParticlesScript.make_sprite("TileDeathSmoke", _textures[0], true)
	sprite.position = origin
	add_child(sprite)
	var size := WdlParticlesScript.wdl_random(1500.0)
	WdlParticlesScript.set_sprite_size(sprite, size)
	_particles.append({
		"sprite": sprite,
		"velocity": WdlParticlesScript.velocity(
				WdlParticlesScript.wdl_random(64.0) - 32.0,
				WdlParticlesScript.wdl_random(64.0) - 32.0,
				WdlParticlesScript.wdl_random(10.0) + 3.0
		),
		"age": 0.0,
		"size": size,
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

		var age := float(particle["age"]) + delta
		var age_ticks := age * ACKNEX_TICKS_PER_SECOND
		if age_ticks >= MAX_AGE_TICKS:
			sprite.queue_free()
			_particles.remove_at(index)
			continue

		var texture_index := _texture_index_for_age_ticks(age_ticks)
		var texture := _textures[mini(texture_index, _textures.size() - 1)]
		if sprite.texture != texture:
			WdlParticlesScript.set_sprite_texture(sprite, texture, true)

		var velocity := particle["velocity"] as Vector3
		var damping := WdlParticlesScript.frame_damping(0.9, delta)
		velocity.x *= damping
		velocity.z *= damping
		velocity.y += WdlParticlesScript.acceleration(1.0) * delta
		sprite.position += velocity * delta

		# If (My_size < 2500) {my_size += 50 * time;}
		var size := float(particle["size"])
		if size < MAX_WDL_SIZE:
			size = minf(size + 50.0 * ticks, MAX_WDL_SIZE)
		WdlParticlesScript.set_sprite_size(sprite, size)

		particle["age"] = age
		particle["size"] = size
		particle["velocity"] = velocity
		_particles[index] = particle


func _texture_index_for_age_ticks(age_ticks: float) -> int:
	var texture_index := 0
	for index in FRAME_TICKS.size():
		if age_ticks >= FRAME_TICKS[index]:
			texture_index = index
	return texture_index
