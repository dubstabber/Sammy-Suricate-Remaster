extends Node3D
class_name CheckpointParticles

const ACKNEX_TICKS_PER_SECOND := 16.0
const WdlParticlesScript := preload("res://src/effects/wdl_particles.gd")
const MAX_AGE_TICKS := 30.0
const MIN_WDL_SIZE := 100.0
const DEFAULT_GREEN_TEXTURES: Array[String] = [
	"texture.particle.checkpoint_green_1",
	"texture.particle.checkpoint_green_2",
]

@export var green_texture_asset_ids: Array[String] = DEFAULT_GREEN_TEXTURES.duplicate()
@export var idle_enabled: bool = true
## mm1.wdl InitRestart: `If (Ticks1 % 4 == 0) emit; waitt 1;`
@export var idle_emit_interval_seconds: float = WdlParticlesScript.ticks1_emit_interval(4, 1.0)
@export var idle_emit_offset: Vector3 = Vector3(0.0, -1.0, 0.0)
@export var auto_free_when_empty: bool = false

var _textures: Array[Texture2D] = []
var _idle_emit_remaining := 0.0
var _particles: Array[Dictionary] = []
var _scheduled_bursts: Array[Dictionary] = []


func _ready() -> void:
	_load_textures()
	_idle_emit_remaining = maxf(idle_emit_interval_seconds, 0.0)


func _process(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	_update_scheduled_bursts(safe_delta)
	if idle_enabled and not _textures.is_empty():
		_idle_emit_remaining -= safe_delta
		while _idle_emit_remaining <= 0.0:
			_emit_particle(Vector3.ZERO, true)
			_idle_emit_remaining += maxf(idle_emit_interval_seconds, 0.001)
	_update_particles(safe_delta)
	if auto_free_when_empty and not idle_enabled and _particles.is_empty() and _scheduled_bursts.is_empty():
		queue_free()


func set_idle_enabled(enabled: bool) -> void:
	idle_enabled = enabled


func is_idle_enabled() -> bool:
	return idle_enabled


func emit_burst(count: int, origin: Vector3 = Vector3.ZERO) -> void:
	for _index in maxi(count, 0):
		_emit_particle(origin, false)


func emit_activation_sequence(origin: Vector3 = Vector3.ZERO) -> void:
	emit_burst(25, origin)
	_schedule_burst(20, 2.0 / ACKNEX_TICKS_PER_SECOND, origin)
	_schedule_burst(15, 6.0 / ACKNEX_TICKS_PER_SECOND, origin)
	_schedule_burst(20, 12.0 / ACKNEX_TICKS_PER_SECOND, origin)


func get_live_particle_count() -> int:
	return _particles.size()


func get_configured_texture_count() -> int:
	return _textures.size()


func _load_textures() -> void:
	_textures.clear()
	var assets := get_node_or_null("/root/Assets")
	if assets == null:
		return
	for asset_id in green_texture_asset_ids:
		var texture := assets.load_asset(asset_id) as Texture2D
		if texture != null:
			_textures.append(texture)


func _schedule_burst(count: int, delay_seconds: float, origin: Vector3) -> void:
	_scheduled_bursts.append({
		"count": maxi(count, 0),
		"delay": maxf(delay_seconds, 0.0),
		"origin": origin,
	})


func _update_scheduled_bursts(delta: float) -> void:
	if delta <= 0.0:
		return
	for index in range(_scheduled_bursts.size() - 1, -1, -1):
		var burst := _scheduled_bursts[index]
		var delay := float(burst["delay"]) - delta
		if delay > 0.0:
			burst["delay"] = delay
			_scheduled_bursts[index] = burst
			continue
		emit_burst(int(burst["count"]), burst["origin"] as Vector3)
		_scheduled_bursts.remove_at(index)


## particul.wdl particle_GemRestart (same function for the idle emitter and
## the activation bursts).
func _emit_particle(origin: Vector3, idle_particle: bool) -> void:
	if _textures.is_empty():
		return
	var texture := _textures[randi_range(0, _textures.size() - 1)]
	var sprite := WdlParticlesScript.make_sprite("CheckpointGreenSpark", texture, true)
	# mm1.wdl InitRestart emits idle sparks at my.z - 100, below the hovering entity.
	sprite.position = origin + (idle_emit_offset if idle_particle else Vector3.ZERO)
	add_child(sprite)
	var size := WdlParticlesScript.wdl_random(2000.0)
	WdlParticlesScript.set_sprite_size(sprite, size)
	_particles.append({
		"sprite": sprite,
		"velocity": WdlParticlesScript.velocity(
				WdlParticlesScript.wdl_random(40.0) - 20.0,
				WdlParticlesScript.wdl_random(40.0) - 20.0,
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
		if age * ACKNEX_TICKS_PER_SECOND >= MAX_AGE_TICKS:
			sprite.queue_free()
			_particles.remove_at(index)
			continue

		var velocity := particle["velocity"] as Vector3
		var damping := WdlParticlesScript.frame_damping(0.9, delta)
		velocity.x *= damping
		velocity.z *= damping
		velocity.y += WdlParticlesScript.acceleration(1.0) * delta
		sprite.position += velocity * delta

		# If (My_size > 100) {my_size -= 50 * time;}
		var size := float(particle["size"])
		if size > MIN_WDL_SIZE:
			size = maxf(size - 50.0 * ticks, MIN_WDL_SIZE)
		WdlParticlesScript.set_sprite_size(sprite, size)

		particle["age"] = age
		particle["size"] = size
		particle["velocity"] = velocity
		_particles[index] = particle
