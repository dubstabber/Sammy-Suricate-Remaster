extends CanvasLayer
class_name LevelHud

## Original in-game panels (panels.wdl). Positions are the video mode 9
## (1280x960) values from panels.wdl initPosPanels, which match the project's
## 1280x960 internal viewport 1:1. The carried-gem panel stays in
## KeyDiamondPanel.
##
## The wasp and Eye of Truth panels are A5 view entities (3D models placed in
## camera space); they are rendered in a transparent overlay viewport whose
## camera matches the original 60 degree horizontal camera arc.

const BitmapDigitsScript := preload("res://src/ui/bitmap_digits.gd")
const ACKNEX_TICKS_PER_SECOND := 16.0
const ACKNEX_TO_GODOT_SCALE := 0.01
const SCREEN_SIZE := Vector2i(1280, 960)

const SCORE_BACKGROUND := preload("res://assets/textures/hud/fondscor.png")
const SCORE_FONT := preload("res://assets/textures/hud/boink24.png")
const GOAL_FONT := preload("res://assets/textures/hud/lucidd14.png")
const GOAL_WARN_FONT := preload("res://assets/textures/hud/boink20.png")
const LIFE_BACKGROUND := preload("res://assets/textures/hud/fondlife.png")
const HEART_BAR := preload("res://assets/textures/hud/vbarhear.png")
const LIFE_FONT := preload("res://assets/textures/hud/boink22.png")
const BOOST_BAR := preload("res://assets/textures/hud/hbarboos.png")
const BOOST_ICON := preload("res://assets/textures/hud/panboost.png")
const BOOST_GHOST := preload("res://assets/textures/hud/panboos2.png")
const WASP_MODEL := preload("res://assets/models/panwasp/panwasp.gltf")
const WASP_SKIN_FORMAT := "res://assets/models/panwasp/skins/panwasp_skin%d_overlay.png"
const EYE_MODEL := preload("res://assets/models/Paneye/Paneye.gltf")
const EYE_SKIN := preload("res://assets/models/Paneye/skins/Paneye_skin0.png")

# PANFondScore1 / PANScore1: DIGITS 55,3 (score, 5) and 35,32 (ScoreGoal, 5).
const SCORE_PANEL_POSITION := Vector2(1096.0, 5.0)
const SCORE_DIGITS_OFFSET := Vector2(55.0, 3.0)
const GOAL_DIGITS_OFFSET := Vector2(35.0, 32.0)
const SCORE_DIGIT_COUNT := 5
# PanLife: Window -12,0,12,48 on VbarHearts; PanLifeNumber DIGITS 44,20 / 60,20.
const LIFE_PANEL_POSITION := Vector2(16.0, 4.0)
const HEART_WINDOW_OFFSET := Vector2(-12.0, 0.0)
const HEART_WINDOW_SIZE := Vector2(12.0, 48.0)
const LIFE_NUMBER_POSITION := Vector2(4.0, 4.0)
const LIFE_TENS_OFFSET := Vector2(44.0, 20.0)
const LIFE_UNITS_OFFSET := Vector2(60.0, 20.0)
# PANBoost: Window 50,20,150,8 on hbarBoost; PANFondBoost/2/3 icons.
const BOOST_PANEL_POSITION := Vector2(0.0, 898.0)
const BOOST_WINDOW_OFFSET := Vector2(50.0, 20.0)
const BOOST_WINDOW_SIZE := Vector2(150.0, 8.0)
const BOOST_ICON_POSITION := Vector2(46.0, 880.0)
const BOOST_GHOST_POSITIONS: Array[Vector2] = [Vector2(6.0, 880.0), Vector2(12.0, 880.0)]
const BOOST_GHOST_ALPHA := 0.5
# PANNbrAmmo1: DIGITS 0,0,5,fntnbr_life.
const AMMO_DIGITS_POSITION := Vector2(1156.0, 902.0)
const AMMO_DIGIT_COUNT := 5
# View entities (Acknex camera space: X forward, Y left, Z up, quants).
const WASP_VIEW_POSITION := Vector3(100.0, -45.0, -35.0)
const WASP_VIEW_PAN_DEGREES := 90.0
const WASP_SCALE_BY_TYPE: Array[float] = [0.3, 0.23, 0.2, 0.2, 0.25, 0.3, 0.2]
const WASP_SPIN_DEGREES_PER_SECOND := 2.0 * ACKNEX_TICKS_PER_SECOND
const EYE_VIEW_POSITION := Vector3(200.0, -45.0, -72.0)
const VIEW_CAMERA_ARC_DEGREES := 60.0
# mm1.wdl WarnScoreGoal: PANScore2 (big goal digits) for 4 ticks, then back.
const WARN_PHASE_SECONDS := 4.0 / ACKNEX_TICKS_PER_SECOND

@export var player_path: NodePath

var _player: Node
var _score_digits: Control
var _goal_digits: Control
var _goal_warn_digits: Control
var _heart_window: TextureRect
var _heart_atlas: AtlasTexture
var _life_tens: Control
var _life_units: Control
var _boost_nodes: Array[CanvasItem] = []
var _boost_atlas: AtlasTexture
var _ammo_digits: Control
var _view_viewport: SubViewport
var _view_rect: TextureRect
var _flare_viewport: SubViewport
var _flare_rect: TextureRect
var _wasp_pivot: Node3D
var _wasp_model: Node3D
var _wasp_material: StandardMaterial3D
var _wasp_spin_degrees := 0.0
var _displayed_wasp_type := 0
var _eye_pivot: Node3D
var _warn_remaining := 0.0


func _ready() -> void:
	layer = 9
	_build_score_panel()
	_build_life_panel()
	_build_boost_panel()
	_build_ammo_panel()
	_build_view_entities()
	_connect_game()
	_resolve_player()
	_update_hud(0.0)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_resolve_player()
	_update_hud(delta)


## mm1.wdl WarnScoreGoal (guarded by ClignoteScore: no overlapping blinks).
func warn_score_goal() -> void:
	if _warn_remaining > 0.0:
		return
	_warn_remaining = WARN_PHASE_SECONDS * 2.0


func is_score_goal_warning() -> bool:
	return _warn_remaining > WARN_PHASE_SECONDS


func get_score_text() -> String:
	return String(_score_digits.call("get_display_text"))


func get_goal_text() -> String:
	return String(_goal_digits.call("get_display_text"))


func get_lives_text() -> String:
	var units := String(_life_units.call("get_display_text"))
	return (String(_life_tens.call("get_display_text")) + units) if _life_tens.visible else units


func get_ammo_text() -> String:
	return String(_ammo_digits.call("get_display_text")) if _ammo_digits.visible else ""


func get_heart_window_offset() -> float:
	return _heart_atlas.region.position.y


func get_boost_bar_width() -> float:
	return BOOST_WINDOW_SIZE.x - _boost_atlas.region.position.x if is_boost_visible() else 0.0


func is_boost_visible() -> bool:
	return not _boost_nodes.is_empty() and _boost_nodes[0].visible


func is_wasp_panel_visible() -> bool:
	return _wasp_pivot != null and _wasp_pivot.visible


func get_displayed_wasp_type() -> int:
	return _displayed_wasp_type


func is_eye_panel_visible() -> bool:
	return _eye_pivot != null and _eye_pivot.visible


func get_eye_panel_scale() -> float:
	return _eye_pivot.scale.y if _eye_pivot != null else 0.0


func _build_score_panel() -> void:
	_add_sprite("ScoreBackground", SCORE_BACKGROUND, SCORE_PANEL_POSITION)
	_score_digits = _add_digits("ScoreDigits", SCORE_FONT, SCORE_DIGIT_COUNT, SCORE_PANEL_POSITION + SCORE_DIGITS_OFFSET)
	_goal_digits = _add_digits("GoalDigits", GOAL_FONT, SCORE_DIGIT_COUNT, SCORE_PANEL_POSITION + GOAL_DIGITS_OFFSET)
	_goal_warn_digits = _add_digits("GoalWarnDigits", GOAL_WARN_FONT, SCORE_DIGIT_COUNT, SCORE_PANEL_POSITION + GOAL_DIGITS_OFFSET)
	_goal_warn_digits.visible = false


func _build_life_panel() -> void:
	_add_sprite("LifeBackground", LIFE_BACKGROUND, LIFE_PANEL_POSITION)
	_heart_atlas = AtlasTexture.new()
	_heart_atlas.atlas = HEART_BAR
	_heart_atlas.region = Rect2(Vector2(0.0, HEART_WINDOW_SIZE.y), HEART_WINDOW_SIZE)
	_heart_window = TextureRect.new()
	_heart_window.name = "HeartWindow"
	_heart_window.texture = _heart_atlas
	_heart_window.position = LIFE_PANEL_POSITION + HEART_WINDOW_OFFSET
	_heart_window.size = HEART_WINDOW_SIZE
	_heart_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heart_window)
	_life_tens = _add_digits("LifeTens", LIFE_FONT, 1, LIFE_NUMBER_POSITION + LIFE_TENS_OFFSET)
	_life_units = _add_digits("LifeUnits", LIFE_FONT, 1, LIFE_NUMBER_POSITION + LIFE_UNITS_OFFSET)


func _build_boost_panel() -> void:
	_boost_atlas = AtlasTexture.new()
	_boost_atlas.atlas = BOOST_BAR
	_boost_atlas.region = Rect2(Vector2.ZERO, BOOST_WINDOW_SIZE)
	var bar := TextureRect.new()
	bar.name = "BoostBar"
	bar.texture = _boost_atlas
	bar.position = BOOST_PANEL_POSITION + BOOST_WINDOW_OFFSET
	bar.size = BOOST_WINDOW_SIZE
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	_boost_nodes.append(bar)
	for index in BOOST_GHOST_POSITIONS.size():
		var ghost := _add_sprite("BoostGhost%d" % (index + 2), BOOST_GHOST, BOOST_GHOST_POSITIONS[index])
		ghost.modulate.a = BOOST_GHOST_ALPHA
		_boost_nodes.append(ghost)
	_boost_nodes.append(_add_sprite("BoostIcon", BOOST_ICON, BOOST_ICON_POSITION))


func _build_ammo_panel() -> void:
	_ammo_digits = _add_digits("AmmoDigits", LIFE_FONT, AMMO_DIGIT_COUNT, AMMO_DIGITS_POSITION)


## Overlay view entities render into transparent viewports; flare (additive)
## entities get their own viewport composited with additive canvas blending,
## because additive blending inside a transparent viewport writes opaque black.
func _build_view_entities() -> void:
	_view_viewport = _add_view_viewport("ViewEntities")
	_flare_viewport = _add_view_viewport("FlareViewEntities")

	_wasp_pivot = _add_view_entity(_view_viewport, "WaspPanel", WASP_VIEW_POSITION)
	_wasp_model = WASP_MODEL.instantiate() as Node3D
	_wasp_model.name = "PanWasp"
	_wasp_pivot.add_child(_wasp_model)
	_wasp_material = StandardMaterial3D.new()
	_wasp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wasp_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_wasp_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_apply_material(_wasp_model, _wasp_material)

	_eye_pivot = _add_view_entity(_flare_viewport, "EyePanel", EYE_VIEW_POSITION)
	var eye_model := EYE_MODEL.instantiate() as Node3D
	eye_model.name = "PanEye"
	_eye_pivot.add_child(eye_model)
	var eye_material := StandardMaterial3D.new()
	eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	eye_material.albedo_texture = EYE_SKIN
	_apply_material(eye_model, eye_material)

	_view_rect = _add_view_layer("ViewEntityLayer", _view_viewport, null)
	# PanEye uses flare (additive) in 16-bit colour.
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flare_rect = _add_view_layer("FlareViewEntityLayer", _flare_viewport, additive)


func _add_view_viewport(viewport_name: String) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = viewport_name
	viewport.size = SCREEN_SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(viewport)
	var view_camera := Camera3D.new()
	view_camera.name = "ViewCamera"
	view_camera.keep_aspect = Camera3D.KEEP_WIDTH
	view_camera.fov = VIEW_CAMERA_ARC_DEGREES
	view_camera.current = true
	viewport.add_child(view_camera)
	return viewport


func _add_view_layer(layer_name: String, viewport: SubViewport, material: Material) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = layer_name
	rect.texture = viewport.get_texture()
	rect.size = Vector2(SCREEN_SIZE)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = material
	add_child(rect)
	return rect


## Acknex view entity position (X forward, Y left, Z up) in Godot camera space.
func _add_view_entity(viewport: SubViewport, entity_name: String, acknex_camera_position: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = entity_name
	pivot.position = Vector3(-acknex_camera_position.y, acknex_camera_position.z, -acknex_camera_position.x) * ACKNEX_TO_GODOT_SCALE
	viewport.add_child(pivot)
	return pivot


func _apply_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_apply_material(child, material)


func _add_sprite(sprite_name: String, texture: Texture2D, screen_position: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.centered = false
	sprite.position = screen_position
	add_child(sprite)
	return sprite


func _add_digits(digits_name: String, font: Texture2D, digit_count: int, screen_position: Vector2) -> Control:
	var digits := BitmapDigitsScript.new() as Control
	digits.name = digits_name
	digits.set("font_texture", font)
	digits.set("digit_count", digit_count)
	digits.position = screen_position
	add_child(digits)
	return digits


func _connect_game() -> void:
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_signal("score_goal_warning_requested") and not game.is_connected("score_goal_warning_requested", warn_score_goal):
		game.connect("score_goal_warning_requested", warn_score_goal)


func _resolve_player() -> void:
	_player = null
	if not player_path.is_empty():
		_player = get_node_or_null(player_path)
	if _player == null and is_inside_tree():
		_player = get_tree().get_first_node_in_group("player")


func _update_hud(delta: float) -> void:
	var game := get_node_or_null("/root/Game")
	if game != null:
		_score_digits.set("value", int(game.call("get_score_points")))
		var goal := int(game.call("get_score_goal_points"))
		_goal_digits.set("value", goal)
		_goal_warn_digits.set("value", goal)
	_update_warning(delta)
	_update_lives()
	_update_boost()
	_update_wasp(delta)
	_update_eye(game)


func _update_warning(delta: float) -> void:
	_warn_remaining = maxf(0.0, _warn_remaining - maxf(delta, 0.0))
	var warning := is_score_goal_warning()
	_goal_warn_digits.visible = warning
	_goal_digits.visible = not warning


func _update_lives() -> void:
	var window_hearts := 0.0
	var lives := 0
	if _player != null:
		if _player.has_method("get_window_hearts"):
			window_hearts = float(_player.call("get_window_hearts"))
		elif _player.has_method("get_health"):
			window_hearts = float(_player.call("get_health"))
		if _player.has_method("get_lives"):
			lives = int(_player.call("get_lives"))
	# The window shows bitmap rows WindowHearts..WindowHearts+48: hearts fill
	# from the bottom and the dark empty part grows from the top.
	_heart_atlas.region = Rect2(Vector2(0.0, clampf(roundf(window_hearts), 0.0, HEART_WINDOW_SIZE.y)), HEART_WINDOW_SIZE)
	lives = maxi(lives, 0)
	_life_units.set("value", lives % 10)
	_life_tens.set("value", lives / 10)
	_life_tens.visible = lives >= 10


func _update_boost() -> void:
	var capacity := 0.0
	if _player != null and _player.has_method("get_boost_capacity"):
		capacity = float(_player.call("get_boost_capacity"))
	# WindowBoost = 150 - capacity; the red part of hbarBoost is columns 0-149.
	var window_boost := clampf(BOOST_WINDOW_SIZE.x - roundf(capacity), 0.0, BOOST_WINDOW_SIZE.x)
	_boost_atlas.region = Rect2(Vector2(window_boost, 0.0), BOOST_WINDOW_SIZE)
	var visible_boost := window_boost < BOOST_WINDOW_SIZE.x
	for node in _boost_nodes:
		node.visible = visible_boost


func _update_wasp(delta: float) -> void:
	var ammo := 0
	var wasp_type := 0
	if _player != null and _player.has_method("get_wasp_inventory"):
		var inventory: Object = _player.call("get_wasp_inventory")
		if inventory != null:
			ammo = int(inventory.call("get_ammo_count")) if inventory.has_method("get_ammo_count") else 0
			wasp_type = _wasp_type_id(inventory.call("get_current_type") if inventory.has_method("get_current_type") else null)
	var has_ammo := ammo > 0
	_ammo_digits.visible = has_ammo
	_ammo_digits.set("value", ammo)
	_wasp_pivot.visible = has_ammo
	_view_rect.visible = has_ammo
	if not has_ammo:
		return
	if wasp_type != _displayed_wasp_type:
		_displayed_wasp_type = wasp_type
		var skin_index := clampi(wasp_type, 1, WASP_SCALE_BY_TYPE.size()) - 1
		_wasp_material.albedo_texture = load(WASP_SKIN_FORMAT % skin_index) as Texture2D
		_wasp_model.scale = Vector3.ONE * WASP_SCALE_BY_TYPE[skin_index] * ACKNEX_TO_GODOT_SCALE
	# mm1.wdl: panwasp.pan += 2*time while NbrAmmo1 > 0.
	_wasp_spin_degrees = wrapf(_wasp_spin_degrees + WASP_SPIN_DEGREES_PER_SECOND * maxf(delta, 0.0), 0.0, 360.0)
	_wasp_pivot.rotation_degrees = Vector3(0.0, 90.0 + WASP_VIEW_PAN_DEGREES + _wasp_spin_degrees, 0.0)


## WaspType.wdl_type_id (WaspCurrentType 1-7) picks the panwasp skin and scale.
func _wasp_type_id(wasp_type: Variant) -> int:
	if wasp_type is Object and wasp_type != null:
		var type_id: Variant = (wasp_type as Object).get("wdl_type_id")
		if type_id != null and int(type_id) > 0:
			return int(type_id)
	return 1


## mm1.wdl ReduitEyePanel: full size, then scale_Y/Z shrink to 0.02.
func _update_eye(game: Node) -> void:
	var panel_scale := 0.0
	if game != null and game.has_method("get_eye_of_truth_panel_scale"):
		panel_scale = float(game.call("get_eye_of_truth_panel_scale"))
	_eye_pivot.visible = panel_scale > 0.0
	_flare_rect.visible = _eye_pivot.visible
	# Model space: Acknex Y/Z are Godot -Z/Y; the panel faces the camera
	# (Acknex +X turned to Godot -Z).
	_eye_pivot.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	_eye_pivot.scale = Vector3(1.0, maxf(panel_scale, 0.001), maxf(panel_scale, 0.001)) * ACKNEX_TO_GODOT_SCALE
