extends Sprite3D
class_name TutorialTitle

## Intro2.wdl InitTitle / Title_Hit / PlaceTitle: a tutorial panel (PCX sprite)
## that appears in front of the camera while Sammy is near its origin.
##
## - Trigger: Sammy within Frc(Skill1)*1000 quants (default 300) of the entity
##   origin, which InitTitle lowers by 100 quants. At most three titles show at
##   once (Title1_Syn..Title3_Syn); Bell1 rings when one appears.
## - PlaceTitle keeps it at camera + (Skill2 forward, Skill3 left, Skill4 up)
##   rotated by the camera angles; Facing + Near draw it camera-facing in front
##   of the level.
## - Fade in over Skill5 frames to alpha Skill8, stay while Sammy is in range,
##   hold Skill6 ticks after he leaves, fade out over Skill7 frames. Flag5 shows
##   it only once; Enter dismisses it.

const TICKS_PER_SECOND := 16.0
const FRAMES_PER_SECOND := 100.0
const QUANT := 0.01
const ORIGIN_DROP_UNITS := 100.0
const DEFAULT_TRIGGER_RADIUS_UNITS := 300.0
const MAX_ACTIVE_TITLES := 3
const BELL_SOUND_ASSET_ID := "sfx.title_bell"
const BELL_SOUND_WDL_RANGE_UNITS := 1500.0

enum Phase { IDLE, FADE_IN, STAY, HOLD, FADE_OUT, DONE }

@export var title_id: int = 0
@export var trigger_radius_units: float = DEFAULT_TRIGGER_RADIUS_UNITS
## Acknex camera-space offset: x forward, y left, z up (quants).
@export var camera_offset_units: Vector3 = Vector3(215.0, 0.0, 35.0)
@export var fade_in_frames: float = 1.0
@export var hold_ticks: float = 1.0
@export var fade_out_frames: float = 1.0
@export_range(0.0, 1.0) var target_alpha: float = 1.0
@export var show_once: bool = false

static var _active_titles: Array[Node] = []

var _phase := Phase.IDLE
var _alpha := 0.0
var _hold_remaining := 0.0
var _trigger_origin := Vector3.ZERO


func _ready() -> void:
	add_to_group("tutorial_title")
	_trigger_origin = global_position
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	shaded = false
	double_sided = true
	render_priority = 100
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	_set_alpha(0.0)
	visible = false


func _exit_tree() -> void:
	_release_slot()


func get_phase() -> int:
	return _phase


func get_alpha() -> float:
	return _alpha


func get_trigger_origin() -> Vector3:
	return _trigger_origin


static func active_title_count() -> int:
	return _active_titles.size()


func _process(delta: float) -> void:
	advance(delta, _player_position(), Input.is_physical_key_pressed(KEY_ENTER))


## One frame of Title_Hit; exposed so tests can drive it without a player.
func advance(delta: float, player_position: Variant, dismiss_pressed: bool = false) -> void:
	var safe_delta := maxf(delta, 0.0)
	var in_range := player_position is Vector3 and _in_range(player_position as Vector3)
	match _phase:
		Phase.IDLE:
			if in_range and _claim_slot():
				_phase = Phase.FADE_IN
				_set_alpha(0.0)
				visible = true
				_play_bell()
		Phase.FADE_IN:
			_set_alpha(minf(target_alpha, _alpha + target_alpha * FRAMES_PER_SECOND * safe_delta / maxf(fade_in_frames, 1.0)))
			if _alpha >= target_alpha:
				_phase = Phase.STAY
		Phase.STAY:
			if not in_range:
				_phase = Phase.HOLD
				_hold_remaining = maxf(hold_ticks, 0.0) / TICKS_PER_SECOND
		Phase.HOLD:
			_hold_remaining -= safe_delta
			if _hold_remaining <= 0.0:
				_phase = Phase.FADE_OUT
		Phase.FADE_OUT:
			_set_alpha(maxf(0.0, _alpha - target_alpha * FRAMES_PER_SECOND * safe_delta / maxf(fade_out_frames, 1.0)))
			if _alpha <= 0.0:
				_finish()
	if _phase in [Phase.FADE_IN, Phase.STAY, Phase.HOLD, Phase.FADE_OUT]:
		if dismiss_pressed:
			_finish()
		else:
			_place_in_front_of_camera()


func _in_range(player_position: Vector3) -> bool:
	return player_position.distance_to(_trigger_origin) <= trigger_radius_units * QUANT


func _finish() -> void:
	visible = false
	_set_alpha(0.0)
	_release_slot()
	_phase = Phase.DONE if show_once else Phase.IDLE


func _claim_slot() -> bool:
	_active_titles = _active_titles.filter(func(title: Node) -> bool: return is_instance_valid(title))
	if _active_titles.has(self):
		return true
	if _active_titles.size() >= MAX_ACTIVE_TITLES:
		return false
	_active_titles.append(self)
	return true


func _release_slot() -> void:
	_active_titles.erase(self)


func _set_alpha(value: float) -> void:
	_alpha = clampf(value, 0.0, 1.0)
	modulate.a = _alpha


func _place_in_front_of_camera() -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	# Acknex forward/left/up -> camera-local -Z / -X / +Y.
	var local := Vector3(-camera_offset_units.y, camera_offset_units.z, -camera_offset_units.x) * QUANT
	global_position = camera.global_transform * local


func _player_position() -> Variant:
	if not is_inside_tree():
		return null
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return player.global_position if player != null else null


func _play_bell() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio != null and audio.has_method("play_spatial_sfx"):
		audio.call("play_spatial_sfx", BELL_SOUND_ASSET_ID, self, BELL_SOUND_WDL_RANGE_UNITS)
