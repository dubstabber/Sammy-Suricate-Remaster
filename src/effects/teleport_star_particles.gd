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

@export var star_texture_asset_ids: Array[String] = DEFAULT_STAR_TEXTURES.duplicate()
@export var idle_enabled: bool = true
@export var idle_emit_interval_seconds: float = 4.0 / ACKNEX_TICKS_PER_SECOND
@export var particle_pixel_size: float = 0.01
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


func _emit_particle(origin: Vector3, idle_particle: bool) -> void:
	if _textures.is_empty():
		return
	var sprite := Sprite3D.new()
	sprite.name = "TeleportStar"
	sprite.texture = _textures[randi_range(0, _textures.size() - 1)]
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = particle_pixel_size
	sprite.position = origin
	var start_scale := randf_range(0.65, 1.25) if idle_particle else randf_range(0.85, 1.55)
	sprite.scale = Vector3.ONE * start_scale
	add_child(sprite)

	var horizontal_range := 0.32 if idle_particle else 0.16
	var vertical_min := 0.03 if idle_particle else 0.03
	var vertical_max := 0.13 if idle_particle else 0.08
	_particles.append({
		"sprite": sprite,
		"velocity": Vector3(
				randf_range(-horizontal_range, horizontal_range),
				randf_range(vertical_min, vertical_max),
				randf_range(-horizontal_range, horizontal_range)
		),
		"age": 0.0,
		"lifetime": 1.25 if idle_particle else 1.0,
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
		var lifetime := maxf(float(particle["lifetime"]), 0.001)
		if age >= lifetime:
			sprite.queue_free()
			_particles.remove_at(index)
			continue

		var velocity := particle["velocity"] as Vector3
		velocity.x *= pow(0.85, ACKNEX_TICKS_PER_SECOND * delta)
		velocity.z *= pow(0.85, ACKNEX_TICKS_PER_SECOND * delta)
		velocity.y += 0.035 * ACKNEX_TICKS_PER_SECOND * delta
		sprite.position += velocity * delta

		var remaining_ratio := clampf(1.0 - age / lifetime, 0.0, 1.0)
		var shrink := maxf(remaining_ratio, 0.1)
		sprite.scale = sprite.scale.move_toward(Vector3.ONE * shrink * 0.2, delta * 2.0)
		sprite.modulate.a = remaining_ratio

		particle["age"] = age
		particle["velocity"] = velocity
		_particles[index] = particle
