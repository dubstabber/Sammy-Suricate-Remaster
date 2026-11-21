extends RefCounted
class_name WdlParticles

## Shared conversions for ports of A5 particle actions (particul.wdl).
##
## A5 particle units: MY_SPEED is quants per tick, accelerations (`+= x*time`)
## are quants per tick^2, MY_AGE counts ticks (1/16 s), MY_SIZE is 1/100 of a
## quant. `My_Flare` particles are drawn additively.

const TICKS_PER_SECOND := 16.0
const QUANT_TO_METERS := 0.01
const SPEED_TO_METERS_PER_SECOND := QUANT_TO_METERS * TICKS_PER_SECOND
const ACCEL_TO_METERS_PER_SECOND_SQUARED := SPEED_TO_METERS_PER_SECOND * TICKS_PER_SECOND
const SIZE_TO_METERS := QUANT_TO_METERS / 100.0
const MIN_SIZE_METERS := 0.0005

static var _flare_materials: Dictionary = {}
static var _blend_materials: Dictionary = {}


## WDL random(x): uniform in [0, x).
static func wdl_random(range_value: float) -> float:
	return randf() * range_value


## quants/tick -> m/s.
static func speed(quants_per_tick: float) -> float:
	return quants_per_tick * SPEED_TO_METERS_PER_SECOND


## quants/tick^2 -> m/s^2.
static func acceleration(quants_per_tick_squared: float) -> float:
	return quants_per_tick_squared * ACCEL_TO_METERS_PER_SECOND_SQUARED


## Per-tick multiplicative damping (`My_Speed.X *= k`) over `delta` seconds.
static func damping(factor_per_tick: float, delta: float) -> float:
	return pow(factor_per_tick, TICKS_PER_SECOND * delta)


## WDL horizontal speed (x, y) and vertical z in quants/tick -> Godot m/s.
static func velocity(speed_x: float, speed_y: float, speed_z: float) -> Vector3:
	return Vector3(speed(speed_x), speed(speed_z), -speed(speed_y))


static func make_sprite(sprite_name: String, texture: Texture2D, flare: bool) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = sprite_name
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	set_sprite_texture(sprite, texture, flare)
	return sprite


static func set_sprite_texture(sprite: Sprite3D, texture: Texture2D, flare: bool) -> void:
	sprite.texture = texture
	sprite.material_override = flare_material(texture) if flare else null


## Sets the on-screen size from MY_SIZE (the bitmap's larger side spans it).
static func set_sprite_size(sprite: Sprite3D, wdl_size: float) -> void:
	if sprite.texture == null:
		return
	var texture_extent := float(maxi(sprite.texture.get_width(), sprite.texture.get_height()))
	sprite.pixel_size = maxf(wdl_size * SIZE_TO_METERS, MIN_SIZE_METERS) / maxf(texture_extent, 1.0)


## Additive camera-facing material (A5 `My_Flare`); Sprite3D has no blend mode.
static func flare_material(texture: Texture2D) -> StandardMaterial3D:
	if texture == null:
		return null
	var key := texture.get_instance_id()
	if _flare_materials.has(key):
		return _flare_materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.vertex_color_use_as_albedo = true
	_flare_materials[key] = material
	return material
