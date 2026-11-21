extends RefCounted
class_name WdlParticles

## Shared conversions for ports of A5 particle actions (particul.wdl).
##
## Verified against the engine (particle update/render in sammypolish.exe and
## live particles in the running SamShare.exe): every frame pos += MY_SPEED *
## time, so speeds are quants per tick and `+= x*time` accelerations quants per
## tick^2; MY_AGE counts ticks (1/16 s). Statements without `*time` (e.g.
## `My_Speed.X *= 0.9`) and ticks1-gated emit loops follow the engine frame
## rate, see AcknexEngineTiming.
##
## A bitmap particle is drawn as a screen quad (32768/z * MY_SIZE) >>
## (14 - round(width/320)) pixels wide, so its world size depends on the video
## mode. The reference is the 800x600 mode the original runs in (shift 11,
## camera.arc 60, focal (800+1)/(2 tan 30)): one MY_SIZE unit is 0.0230655
## quants.
##
## `My_Flare` (without MY_BRIGHT, which no Sammy particle sets) is plain
## SRCALPHA/INVSRCALPHA blending at MY_ALPHA 50 -> vertex alpha 250, without
## depth writes; MY_COLOR does not tint bitmap particles.

const TICKS_PER_SECOND := AcknexEngineTiming.TICKS_PER_SECOND
const QUANT_TO_METERS := 0.01
const SPEED_TO_METERS_PER_SECOND := QUANT_TO_METERS * TICKS_PER_SECOND
const ACCEL_TO_METERS_PER_SECOND_SQUARED := SPEED_TO_METERS_PER_SECOND * TICKS_PER_SECOND
## 16 / ((800 + 1) / (2 * tan(30 deg))) quants per MY_SIZE unit (800x600 mode).
const SIZE_TO_METERS := 0.0230655 * QUANT_TO_METERS
const FLARE_ALPHA := 250.0 / 255.0
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


## Per-tick multiplicative damping (`My_Speed.X *= k * time`-style) over `delta` seconds.
static func damping(factor_per_tick: float, delta: float) -> float:
	return pow(factor_per_tick, TICKS_PER_SECOND * delta)


## Per-frame multiplicative damping (`My_Speed.X *= k`, no `time`) over `delta` seconds.
static func frame_damping(factor_per_frame: float, delta: float) -> float:
	return AcknexEngineTiming.frame_factor(factor_per_frame, delta)


## WDL horizontal speed (x, y) and vertical z in quants/tick -> Godot m/s.
static func velocity(speed_x: float, speed_y: float, speed_z: float) -> Vector3:
	return Vector3(speed(speed_x), speed(speed_z), -speed(speed_y))


static func make_sprite(sprite_name: String, texture: Texture2D, flare: bool) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = sprite_name
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
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


## Camera-facing `My_Flare` material: alpha-blended at vertex alpha 250.
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
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.albedo_color = Color(1.0, 1.0, 1.0, FLARE_ALPHA)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The original D3D renderer draws particles bilinear-filtered; nearest
	# sampling drops the thin star rays once a sprite is minified.
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.vertex_color_use_as_albedo = true
	_flare_materials[key] = material
	return material
