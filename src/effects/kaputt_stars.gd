extends Node3D
class_name KaputtStars

## player.wdl CreateEtoilesKaputt / EtoileTourne: twelve EtoilB+9 stars, one
## every 30 degrees, circle Sammy's MDL vertex 16 (the top of his head) at 50
## quants while he dies. Each tick the ring turns 10 degrees, every star spins
## -10 degrees on its own pan and steps one of its 9 frames. The stars stay
## until RestartSammy clears AnimKaputt.
##
## EtoileTourne adds `My.Skill2` after switching My to Sammy, so the intended
## random(64) height offset reads Sammy's unused Skill2 (0) instead: all stars
## share the vertex height.

const STAR_COUNT := 12
const STAR_SPACING_DEGREES := 30.0
const RING_RADIUS_UNITS := 50.0
const RING_TURN_DEGREES_PER_TICK := 10.0
const STAR_SPIN_DEGREES_PER_TICK := -10.0
const STAR_FRAMES := 9
const STAR_FRAMES_PER_TICK := 1.0
const STAR_SCALE := 0.75
const TICKS_PER_SECOND := 16.0
const QUANT := 0.01
const TEXTURE_ASSET_ID := "texture.particle.kaputt_star"

## suricat1.MDL vertex 16 over the 88 kaputt frames (every 4th frame), in model
## units: x forward, y left, z up.
const HEAD_VERTEX_TRACK: Array[Vector3] = [
	Vector3(0.9, -0.7, 12.1), Vector3(-0.9, -1.1, 12.1), Vector3(-1.8, -1.0, 11.3),
	Vector3(-2.8, -0.6, 10.6), Vector3(-4.2, -0.5, 10.0), Vector3(-5.5, -0.5, 9.1),
	Vector3(-6.2, -0.2, 8.7), Vector3(-5.5, 0.1, 7.8), Vector3(-3.4, 0.3, 6.3),
	Vector3(-1.0, 0.4, 4.6), Vector3(-0.1, 0.3, 4.0), Vector3(0.6, 0.0, 3.2),
	Vector3(0.9, 0.1, 2.6), Vector3(1.1, 0.2, 1.9), Vector3(1.3, 0.3, 1.9),
	Vector3(1.3, 0.2, 2.3), Vector3(1.3, 0.3, 2.8), Vector3(1.1, 0.5, 3.3),
	Vector3(1.0, 0.5, 3.3), Vector3(0.8, 0.6, 3.2), Vector3(0.7, 0.7, 3.0),
	Vector3(0.4, 0.8, 3.3), Vector3(1.3, 0.2, 2.5),
]

var _player: Node3D = null
var _stars: Array[Sprite3D] = []
var _ring_angle := 0.0
var _star_spin := 0.0
var _frame_accumulator := 0.0
## Sammy's entity scale (8) and HeightFootPlayer origin offset, in model units.
var _model_scale := 8.0
var _origin_height := 4.4


func setup(player: Node3D, model_scale: float = 8.0, origin_height_units: float = 4.4) -> void:
	_player = player
	_model_scale = model_scale
	_origin_height = origin_height_units


func _ready() -> void:
	var texture: Texture2D = null
	var assets := get_node_or_null("/root/Assets")
	if assets != null:
		texture = assets.load_asset(TEXTURE_ASSET_ID) as Texture2D
	for index in STAR_COUNT:
		var star := Sprite3D.new()
		star.name = "Star%02d" % index
		star.texture = texture
		star.hframes = STAR_FRAMES
		star.frame = 0
		star.pixel_size = QUANT * STAR_SCALE
		star.shaded = false
		star.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		star.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(star)
		_stars.append(star)
	_place_stars()


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		queue_free()
		return
	var ticks := maxf(delta, 0.0) * TICKS_PER_SECOND
	_ring_angle = fposmod(_ring_angle + RING_TURN_DEGREES_PER_TICK * ticks, 360.0)
	_star_spin = fposmod(_star_spin + STAR_SPIN_DEGREES_PER_TICK * ticks, 360.0)
	_frame_accumulator += STAR_FRAMES_PER_TICK * ticks
	var frame_steps := int(floorf(_frame_accumulator))
	_frame_accumulator -= frame_steps
	for star in _stars:
		star.frame = (star.frame + frame_steps) % STAR_FRAMES
	_place_stars()


func get_star_count() -> int:
	return _stars.size()


func get_ring_angle_degrees() -> float:
	return _ring_angle


## World position of MDL vertex 16 at kaputt progress 0..1.
func head_position(progress: float) -> Vector3:
	if _player == null or not is_instance_valid(_player):
		return global_position
	var track_position := clampf(progress, 0.0, 1.0) * float(HEAD_VERTEX_TRACK.size() - 1)
	var index := int(floorf(track_position))
	var next_index := mini(index + 1, HEAD_VERTEX_TRACK.size() - 1)
	var vertex := HEAD_VERTEX_TRACK[index].lerp(HEAD_VERTEX_TRACK[next_index], track_position - index)
	# Model x forward / y left / z up -> player local -Z / -X / +Y.
	var local := Vector3(-vertex.y, vertex.z + _origin_height, -vertex.x) * _model_scale * QUANT
	return _player.global_transform * local


func _place_stars() -> void:
	var progress := 1.0
	if _player != null and is_instance_valid(_player) and _player.has_method("get_death_animation_progress"):
		progress = float(_player.call("get_death_animation_progress"))
	var center := head_position(progress)
	for index in _stars.size():
		var star := _stars[index]
		var pan := deg_to_rad(index * STAR_SPACING_DEGREES + _ring_angle)
		var offset := Vector3(cos(pan), 0.0, -sin(pan)) * RING_RADIUS_UNITS * QUANT
		star.global_position = center + offset
		# Oriented sprites created at pan 0, all spinning together.
		star.global_rotation = Vector3(0.0, deg_to_rad(_star_spin), 0.0)
